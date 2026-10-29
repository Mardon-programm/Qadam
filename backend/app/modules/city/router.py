from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import DriverOnlineStatus, RideOrderStatus, UserRole
from app.core.exceptions import NotFoundError
from app.modules.city import service
from app.modules.city.models import RideOffer, RideOrder
from app.modules.city.schemas import (
    CancelRideIn,
    CreateRideIn,
    DriverInfoOut,
    QuoteIn,
    QuoteOut,
    RideOut,
)
from app.modules.identity.models import User
from app.modules.ledger.service import post_ride_completion
from app.modules.trust.models import DriverProfile, Vehicle
from app.modules.trust.service import get_or_create_driver_profile

router = APIRouter(prefix="/city", tags=["city"])


async def _ride_out_full(db: DbSession, order: RideOrder) -> RideOut:
    driver_info = None
    driver_lat = None
    driver_lng = None
    if order.driver_id:
        driver = await db.get(DriverProfile, order.driver_id)
        if driver:
            if driver.last_lat is not None:
                driver_lat = float(driver.last_lat)
            if driver.last_lng is not None:
                driver_lng = float(driver.last_lng)
            user = await db.get(User, driver.user_id)
            vehicle = None
            if driver.active_vehicle_id:
                vehicle = await db.get(Vehicle, driver.active_vehicle_id)
            elif order.vehicle_id:
                vehicle = await db.get(Vehicle, order.vehicle_id)
            driver_info = DriverInfoOut(
                full_name=user.full_name if user else None,
                phone=user.phone if user else None,
                rating=str(driver.rating) if driver.rating is not None else None,
                vehicle_make=vehicle.make if vehicle else None,
                vehicle_model=vehicle.model if vehicle else None,
                vehicle_color=vehicle.color if vehicle else None,
                vehicle_plate=vehicle.plate_number if vehicle else None,
            )
    return RideOut(
        id=order.id,
        status=order.status,
        pickup_address=order.pickup_address,
        dropoff_address=order.dropoff_address,
        quoted_price=order.quoted_price,
        final_price=order.final_price,
        surge_multiplier=order.surge_multiplier,
        driver_net_estimate=order.driver_net_estimate,
        platform_fee_estimate=order.platform_fee_estimate,
        distance_km=order.distance_km,
        duration_min=order.duration_min,
        eta_min=order.eta_min,
        driver_id=order.driver_id,
        currency=order.currency,
        created_at=order.created_at,
        completed_at=order.completed_at,
        driver=driver_info,
        driver_lat=driver_lat,
        driver_lng=driver_lng,
    )


def _ride_out(order: RideOrder) -> RideOut:
    return RideOut(
        id=order.id,
        status=order.status,
        pickup_address=order.pickup_address,
        dropoff_address=order.dropoff_address,
        quoted_price=order.quoted_price,
        final_price=order.final_price,
        surge_multiplier=order.surge_multiplier,
        driver_net_estimate=order.driver_net_estimate,
        platform_fee_estimate=order.platform_fee_estimate,
        distance_km=order.distance_km,
        duration_min=order.duration_min,
        eta_min=order.eta_min,
        driver_id=order.driver_id,
        currency=order.currency,
        created_at=order.created_at,
        completed_at=order.completed_at,
    )


@router.post("/quote", response_model=QuoteOut)
async def quote(body: QuoteIn, db: DbSession) -> QuoteOut:
    data = await service.create_quote(
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        dropoff_lat=body.dropoff_lat,
        dropoff_lng=body.dropoff_lng,
        surge=body.surge,
        db=db,
    )
    return QuoteOut(currency="KGS", **data)


@router.post(
    "/rides",
    response_model=RideOut,
    dependencies=[Depends(require_roles(UserRole.PASSENGER, UserRole.OPS))],
)
async def create_ride(
    body: CreateRideIn,
    db: DbSession,
    user: CurrentUser,
) -> RideOut:
    order = await service.create_ride_order(
        db,
        passenger_id=user.id,
        pickup_address=body.pickup_address,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        dropoff_address=body.dropoff_address,
        dropoff_lat=body.dropoff_lat,
        dropoff_lng=body.dropoff_lng,
        surge=body.surge,
        idempotency_key=body.idempotency_key,
    )
    await service.offer_to_drivers(db, order)
    return await _ride_out_full(db, order)


@router.get("/rides", response_model=list[RideOut])
async def my_rides(db: DbSession, user: CurrentUser, limit: int = 50) -> list[RideOut]:
    """Passenger ride history, newest first."""
    result = await db.execute(
        select(RideOrder)
        .where(RideOrder.passenger_id == user.id)
        .order_by(RideOrder.created_at.desc())
        .limit(max(1, min(limit, 100)))
    )
    orders = result.scalars().all()
    out = []
    for order in orders:
        out.append(await _ride_out_full(db, order))
    return out


@router.get("/rides/{ride_id}", response_model=RideOut)
async def get_ride(ride_id: str, db: DbSession, user: CurrentUser) -> RideOut:
    order = await db.get(RideOrder, ride_id)
    if not order:
        raise NotFoundError("Ride not found")
    if user.role == UserRole.PASSENGER and order.passenger_id != user.id:
        raise NotFoundError("Ride not found")
    return await _ride_out_full(db, order)


@router.post(
    "/rides/{ride_id}/accept",
    response_model=RideOut,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def accept_ride(ride_id: str, db: DbSession, user: CurrentUser) -> RideOut:
    driver = await get_or_create_driver_profile(db, user.id)
    order = await service.accept_ride(db, order_id=ride_id, driver=driver)
    return await _ride_out_full(db, order)


@router.post(
    "/rides/{ride_id}/start",
    response_model=RideOut,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def start(ride_id: str, db: DbSession, user: CurrentUser) -> RideOut:
    driver = await get_or_create_driver_profile(db, user.id)
    current = await db.get(RideOrder, ride_id)
    if current and current.status == RideOrderStatus.ASSIGNED:
        await service.transition_ride(
            db,
            order_id=ride_id,
            actor_driver_id=driver.id,
            new_status=RideOrderStatus.DRIVER_ARRIVING,
        )
        await service.transition_ride(
            db,
            order_id=ride_id,
            actor_driver_id=driver.id,
            new_status=RideOrderStatus.DRIVER_ARRIVED,
        )
    order = await service.transition_ride(
        db,
        order_id=ride_id,
        actor_driver_id=driver.id,
        new_status=RideOrderStatus.IN_PROGRESS,
    )
    return await _ride_out_full(db, order)


@router.post(
    "/rides/{ride_id}/complete",
    response_model=RideOut,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def complete(ride_id: str, db: DbSession, user: CurrentUser) -> RideOut:
    driver = await get_or_create_driver_profile(db, user.id)
    order = await service.transition_ride(
        db,
        order_id=ride_id,
        actor_driver_id=driver.id,
        new_status=RideOrderStatus.COMPLETED,
    )
    if not order.ledger_posted and order.final_price is not None:
        await post_ride_completion(
            db,
            ride_id=order.id,
            driver_id=driver.id,
            passenger_id=order.passenger_id,
            gross=order.final_price,
            platform_fee=order.platform_fee_estimate or 0,
            driver_net=order.driver_net_estimate or 0,
        )
        order.ledger_posted = True
        driver.online_status = DriverOnlineStatus.ONLINE
        await db.flush()
    return await _ride_out_full(db, order)


@router.post("/rides/{ride_id}/cancel", response_model=RideOut)
async def cancel(
    ride_id: str,
    body: CancelRideIn,
    db: DbSession,
    user: CurrentUser,
) -> RideOut:
    driver_id = None
    passenger_id = None
    if user.role == UserRole.PASSENGER:
        passenger_id = user.id
    elif user.role == UserRole.DRIVER:
        driver = await get_or_create_driver_profile(db, user.id)
        driver_id = driver.id
    order = await service.cancel_ride(
        db,
        order_id=ride_id,
        cancelled_by=user.role,
        reason=body.reason or "user_cancelled",
        passenger_id=passenger_id,
        driver_id=driver_id,
    )
    return await _ride_out_full(db, order)


@router.get(
    "/driver/offers",
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def my_offers(db: DbSession, user: CurrentUser):
    driver = await get_or_create_driver_profile(db, user.id)
    result = await db.execute(
        select(RideOffer, RideOrder)
        .join(RideOrder, RideOrder.id == RideOffer.ride_order_id)
        .where(
            RideOffer.driver_id == driver.id,
            RideOffer.status == "offered",
        )
        .order_by(RideOffer.created_at.desc())
    )
    return [
        {
            "id": offer.id,
            "ride_order_id": offer.ride_order_id,
            "eta_min": offer.eta_min,
            "net_estimate": offer.net_estimate,
            "expires_at": offer.expires_at,
            "pickup_address": order.pickup_address,
            "pickup_lat": float(order.pickup_lat),
            "pickup_lng": float(order.pickup_lng),
            "dropoff_address": order.dropoff_address,
            "dropoff_lat": float(order.dropoff_lat),
            "dropoff_lng": float(order.dropoff_lng),
            "quoted_price": order.quoted_price,
            "distance_km": order.distance_km,
            "duration_min": order.duration_min,
        }
        for offer, order in result.all()
    ]


@router.get(
    "/driver/active-ride",
    response_model=RideOut | None,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def active_ride(db: DbSession, user: CurrentUser) -> RideOut | None:
    driver = await get_or_create_driver_profile(db, user.id)
    result = await db.execute(
        select(RideOrder)
        .where(
            RideOrder.driver_id == driver.id,
            RideOrder.status.in_(
                [
                    RideOrderStatus.ASSIGNED,
                    RideOrderStatus.DRIVER_ARRIVING,
                    RideOrderStatus.DRIVER_ARRIVED,
                    RideOrderStatus.IN_PROGRESS,
                ]
            ),
        )
        .order_by(RideOrder.assigned_at.desc())
        .limit(1)
    )
    order = result.scalar_one_or_none()
    return _ride_out(order) if order else None
