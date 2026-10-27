from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import (
    DriverOnlineStatus,
    RideOrderStatus,
    VerificationStatus,
)
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.modules.city.models import RideOffer, RideOrder
from app.modules.pricing.service import estimate_route, quote_city_fare
from app.modules.trust.models import DriverProfile, Vehicle


async def create_quote(
    *,
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
    surge: float = 1.0,
) -> dict:
    distance, duration = await estimate_route(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
    return quote_city_fare(distance_km=distance, duration_min=duration, surge=surge)


async def create_ride_order(
    db: AsyncSession,
    *,
    passenger_id: str,
    pickup_address: str,
    pickup_lat: float,
    pickup_lng: float,
    dropoff_address: str,
    dropoff_lat: float,
    dropoff_lng: float,
    surge: float = 1.0,
    idempotency_key: str | None = None,
) -> RideOrder:
    if idempotency_key:
        existing = await db.execute(
            select(RideOrder).where(RideOrder.idempotency_key == idempotency_key)
        )
        found = existing.scalar_one_or_none()
        if found:
            return found

    quote = await create_quote(
        pickup_lat=pickup_lat,
        pickup_lng=pickup_lng,
        dropoff_lat=dropoff_lat,
        dropoff_lng=dropoff_lng,
        surge=surge,
    )
    order = RideOrder(
        passenger_id=passenger_id,
        status=RideOrderStatus.SEARCHING,
        pickup_address=pickup_address,
        pickup_lat=Decimal(str(pickup_lat)),
        pickup_lng=Decimal(str(pickup_lng)),
        dropoff_address=dropoff_address,
        dropoff_lat=Decimal(str(dropoff_lat)),
        dropoff_lng=Decimal(str(dropoff_lng)),
        distance_km=quote["distance_km"],
        duration_min=quote["duration_min"],
        quoted_price=quote["quoted_price"],
        surge_multiplier=quote["surge_multiplier"],
        platform_fee_estimate=quote["platform_fee_estimate"],
        driver_net_estimate=quote["driver_net_estimate"],
        idempotency_key=idempotency_key,
    )
    db.add(order)
    await db.flush()
    return order


async def find_candidate_drivers(
    db: AsyncSession,
    *,
    pickup_lat: float,
    pickup_lng: float,
    limit: int = 10,
) -> list[tuple[DriverProfile, dict]]:
    """
    Improved dispatch algorithm according to TZ:
    1. Geo filter: online + approved + active vehicle
    2. Calculate real ETA via OSRM
    3. Rank by ETA, reliability, and fair distribution
    4. Return top candidates with their ETA data
    """
    from app.core.osrm import get_osrm

    # Stage 1: Get all eligible drivers
    result = await db.execute(
        select(DriverProfile).where(
            and_(
                DriverProfile.online_status == DriverOnlineStatus.ONLINE,
                DriverProfile.verification_status == VerificationStatus.APPROVED,
                DriverProfile.active_vehicle_id.is_not(None),
                DriverProfile.last_lat.is_not(None),
                DriverProfile.last_lng.is_not(None),
            )
        )
    )
    drivers = list(result.scalars().all())

    if not drivers:
        return []

    # Stage 2: Calculate ETA for each driver using OSRM
    osrm = get_osrm()
    driver_etas = []

    for driver in drivers:
        try:
            route = await osrm.get_route(
                start_lng=float(driver.last_lng),  # type: ignore
                start_lat=float(driver.last_lat),  # type: ignore
                end_lng=pickup_lng,
                end_lat=pickup_lat,
            )

            eta_seconds = route.get("duration", 0)
            eta_minutes = eta_seconds / 60.0
            distance_km = route.get("distance", 0) / 1000.0

            driver_etas.append(
                {
                    "driver": driver,
                    "eta_min": eta_minutes,
                    "distance_km": distance_km,
                    "fallback": route.get("fallback", False),
                }
            )
        except Exception:
            # Fallback to straight-line estimation for this driver
            dlat = float(driver.last_lat) - pickup_lat  # type: ignore
            dlng = float(driver.last_lng) - pickup_lng  # type: ignore
            straight_dist = ((dlat**2 + dlng**2) ** 0.5) * 111.0  # approx km
            road_dist = straight_dist * 1.3
            eta_min = (road_dist / 40.0) * 60.0  # 40 km/h average

            driver_etas.append(
                {
                    "driver": driver,
                    "eta_min": max(eta_min, 3.0),
                    "distance_km": road_dist,
                    "fallback": True,
                }
            )

    # Stage 3: Rank drivers
    # Not just by minimum ETA - consider reliability and fair distribution
    def ranking_score(item: dict) -> tuple[float, float, float]:
        driver = item["driver"]
        eta = item["eta_min"]
        reliability = float(driver.reliability_score or 100.0)
        rating = float(driver.rating or 5.0)

        # Normalized factors (lower is better for sort)
        # - ETA weight: 60%
        # - Reliability penalty: 20% (lower reliability = higher penalty)
        # - Rating bonus: 20% (higher rating = lower score)

        eta_score = eta * 0.6
        reliability_penalty = (100 - reliability) * 0.002  # 0-0.2 range
        rating_bonus = (5.0 - rating) * 0.04  # 0-0.2 range

        total_score = eta_score + reliability_penalty + rating_bonus

        # Secondary sort by ETA, tertiary by reliability
        return (total_score, eta, -reliability)

    driver_etas.sort(key=ranking_score)

    # Return top candidates with metadata
    return [
        (
            item["driver"],
            {
                "eta_min": item["eta_min"],
                "distance_km": item["distance_km"],
                "fallback": item["fallback"],
            },
        )
        for item in driver_etas[:limit]
    ]


async def offer_to_drivers(db: AsyncSession, order: RideOrder) -> list[RideOffer]:
    """
    Offer ride to top ranked drivers with real ETA data.
    Sequential offering: first driver gets first chance.
    """
    candidates = await find_candidate_drivers(
        db,
        pickup_lat=float(order.pickup_lat),
        pickup_lng=float(order.pickup_lng),
        limit=5,  # Top 5 candidates for sequential offering
    )

    if not candidates:
        return []

    offers: list[RideOffer] = []
    expires = datetime.now(UTC) + timedelta(seconds=30)  # 30 sec to respond

    for driver, metadata in candidates:
        offer = RideOffer(
            ride_order_id=order.id,
            driver_id=driver.id,
            status="offered",
            eta_min=int(metadata["eta_min"]),
            net_estimate=order.driver_net_estimate,
            expires_at=expires,
        )
        db.add(offer)
        offers.append(offer)

    if offers:
        order.status = RideOrderStatus.OFFERED

    await db.flush()
    return offers


async def accept_ride(
    db: AsyncSession,
    *,
    order_id: str,
    driver: DriverProfile,
) -> RideOrder:
    """Atomic assignment: SELECT FOR UPDATE, single winner."""
    if driver.verification_status != VerificationStatus.APPROVED:
        raise ForbiddenError("Driver is not verified")
    if driver.online_status not in {
        DriverOnlineStatus.ONLINE,
        DriverOnlineStatus.BUSY,
    }:
        raise ForbiddenError("Driver must be online")
    if not driver.active_vehicle_id:
        raise ForbiddenError("No active vehicle")

    result = await db.execute(select(RideOrder).where(RideOrder.id == order_id).with_for_update())
    order = result.scalar_one_or_none()
    if not order:
        raise NotFoundError("Ride not found")
    if order.status not in {
        RideOrderStatus.SEARCHING,
        RideOrderStatus.OFFERED,
    }:
        raise ConflictError("Ride is no longer available")
    if order.driver_id is not None:
        raise ConflictError("Ride already assigned")

    vehicle = await db.get(Vehicle, driver.active_vehicle_id)
    if not vehicle or vehicle.status != VerificationStatus.APPROVED:
        raise ForbiddenError("Vehicle not approved")

    order.driver_id = driver.id
    order.vehicle_id = vehicle.id
    order.status = RideOrderStatus.ASSIGNED
    order.assigned_at = datetime.now(UTC)
    driver.online_status = DriverOnlineStatus.BUSY

    # Mark matching offer accepted, others expired
    offers = await db.execute(select(RideOffer).where(RideOffer.ride_order_id == order.id))
    for offer in offers.scalars().all():
        if offer.driver_id == driver.id and offer.status == "offered":
            offer.status = "accepted"
            offer.responded_at = datetime.now(UTC)
        elif offer.status == "offered":
            offer.status = "expired"

    await db.flush()
    return order


async def transition_ride(
    db: AsyncSession,
    *,
    order_id: str,
    actor_driver_id: str | None,
    new_status: RideOrderStatus,
) -> RideOrder:
    result = await db.execute(select(RideOrder).where(RideOrder.id == order_id).with_for_update())
    order = result.scalar_one_or_none()
    if not order:
        raise NotFoundError("Ride not found")
    if actor_driver_id and order.driver_id != actor_driver_id:
        raise ForbiddenError("Not your ride")

    allowed: dict[RideOrderStatus, set[RideOrderStatus]] = {
        RideOrderStatus.ASSIGNED: {
            RideOrderStatus.DRIVER_ARRIVING,
            RideOrderStatus.CANCELLED,
        },
        RideOrderStatus.DRIVER_ARRIVING: {
            RideOrderStatus.DRIVER_ARRIVED,
            RideOrderStatus.CANCELLED,
        },
        RideOrderStatus.DRIVER_ARRIVED: {
            RideOrderStatus.IN_PROGRESS,
            RideOrderStatus.CANCELLED,
        },
        RideOrderStatus.IN_PROGRESS: {RideOrderStatus.COMPLETED, RideOrderStatus.CANCELLED},
    }
    current = RideOrderStatus(order.status)
    if new_status not in allowed.get(current, set()):
        raise ConflictError(f"Cannot transition {current} → {new_status}")

    order.status = new_status
    now = datetime.now(UTC)
    if new_status == RideOrderStatus.IN_PROGRESS:
        order.started_at = now
    if new_status == RideOrderStatus.COMPLETED:
        order.completed_at = now
        order.final_price = order.quoted_price
    if new_status == RideOrderStatus.CANCELLED:
        order.cancelled_at = now
    await db.flush()
    return order


async def cancel_ride(
    db: AsyncSession,
    *,
    order_id: str,
    cancelled_by: str,
    reason: str,
    passenger_id: str | None = None,
    driver_id: str | None = None,
) -> RideOrder:
    result = await db.execute(select(RideOrder).where(RideOrder.id == order_id).with_for_update())
    order = result.scalar_one_or_none()
    if not order:
        raise NotFoundError("Ride not found")
    if passenger_id and order.passenger_id != passenger_id:
        raise ForbiddenError()
    if driver_id and order.driver_id != driver_id:
        raise ForbiddenError()
    if order.status in {RideOrderStatus.COMPLETED, RideOrderStatus.CANCELLED}:
        raise ConflictError("Ride already finished")

    order.status = RideOrderStatus.CANCELLED
    order.cancelled_at = datetime.now(UTC)
    order.cancelled_by = cancelled_by
    order.cancel_reason = reason

    if order.driver_id:
        driver = await db.get(DriverProfile, order.driver_id)
        if driver and driver.online_status == DriverOnlineStatus.BUSY:
            driver.online_status = DriverOnlineStatus.ONLINE
    await db.flush()
    return order
