"""Region (intercity) HTTP endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import UserRole
from app.core.exceptions import NotFoundError
from app.modules.region import service
from app.modules.region.models import Booking, IntercityTrip, TripSeat
from app.modules.region.schemas import (
    BookingCancelIn,
    BookingCreateIn,
    BookingOut,
    SeatOut,
    TripCreateIn,
    TripOut,
    TripStatusIn,
)
from app.modules.trust.service import get_or_create_driver_profile

router = APIRouter(prefix="/region", tags=["region"])


# ── Trip search ────────────────────────────────────────────────────────────────


@router.get("/trips", response_model=list[TripOut])
async def search_trips(
    db: DbSession,
    user: CurrentUser,
    origin: str = "",
    destination: str = "",
) -> list[TripOut]:
    stmt = select(IntercityTrip).where(IntercityTrip.status == "scheduled")
    if origin:
        stmt = stmt.where(IntercityTrip.origin_city == origin.lower())
    if destination:
        stmt = stmt.where(IntercityTrip.destination_city == destination.lower())
    stmt = stmt.order_by(IntercityTrip.depart_at)
    result = await db.execute(stmt)
    trips = result.scalars().all()

    out: list[TripOut] = []
    for trip in trips:
        available = await service.count_available_seats(db, trip.id)
        out.append(_trip_out(trip, available))
    return out


@router.get("/trips/{trip_id}", response_model=TripOut)
async def get_trip(trip_id: str, db: DbSession, user: CurrentUser) -> TripOut:
    trip, available = await service.get_trip_with_availability(db, trip_id)
    return _trip_out(trip, available)


@router.get("/trips/{trip_id}/seats", response_model=list[SeatOut])
async def get_seats(trip_id: str, db: DbSession, user: CurrentUser) -> list[SeatOut]:
    trip = await db.get(IntercityTrip, trip_id)
    if not trip:
        raise NotFoundError("Trip not found")
    result = await db.execute(select(TripSeat).where(TripSeat.trip_id == trip_id))
    return [SeatOut(seat_code=s.seat_code, status=s.status) for s in result.scalars().all()]


# ── Driver trip management ─────────────────────────────────────────────────────


@router.post(
    "/trips",
    response_model=TripOut,
    status_code=201,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def create_trip(
    body: TripCreateIn,
    db: DbSession,
    user: CurrentUser,
) -> TripOut:
    driver = await get_or_create_driver_profile(db, user.id)
    trip = await service.create_trip(
        db,
        driver_id=driver.id,
        vehicle_id=driver.active_vehicle_id or "",
        origin_city=body.origin_city,
        destination_city=body.destination_city,
        depart_at=body.depart_at,
        price_per_seat=body.price_per_seat,
        seat_count=body.seat_count,
        baggage_note=body.baggage_note,
        meeting_point=body.meeting_point,
    )
    return _trip_out(trip, trip.seat_count)


@router.patch(
    "/trips/{trip_id}/status",
    response_model=TripOut,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def update_trip_status(
    trip_id: str,
    body: TripStatusIn,
    db: DbSession,
    user: CurrentUser,
) -> TripOut:
    driver = await get_or_create_driver_profile(db, user.id)
    trip = await service.update_trip_status(
        db, trip_id=trip_id, driver_id=driver.id, new_status=body.status
    )
    available = await service.count_available_seats(db, trip.id)
    return _trip_out(trip, available)


@router.get(
    "/driver/trips",
    response_model=list[TripOut],
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def my_trips(db: DbSession, user: CurrentUser) -> list[TripOut]:
    driver = await get_or_create_driver_profile(db, user.id)
    result = await db.execute(
        select(IntercityTrip)
        .where(IntercityTrip.driver_id == driver.id)
        .order_by(IntercityTrip.depart_at.desc())
    )
    out: list[TripOut] = []
    for trip in result.scalars().all():
        available = await service.count_available_seats(db, trip.id)
        out.append(_trip_out(trip, available))
    return out


# ── Passenger booking ──────────────────────────────────────────────────────────


@router.post(
    "/bookings",
    response_model=BookingOut,
    status_code=201,
    dependencies=[Depends(require_roles(UserRole.PASSENGER, UserRole.CORPORATE))],
)
async def create_booking(
    body: BookingCreateIn,
    db: DbSession,
    user: CurrentUser,
) -> BookingOut:
    booking = await service.create_booking(
        db,
        passenger_id=user.id,
        trip_id=body.trip_id,
        passenger_count=body.passenger_count,
        baggage_count=body.baggage_count,
        idempotency_key=body.idempotency_key,
    )
    return _booking_out(booking)


@router.get(
    "/bookings",
    response_model=list[BookingOut],
    dependencies=[Depends(require_roles(UserRole.PASSENGER, UserRole.CORPORATE))],
)
async def my_bookings(db: DbSession, user: CurrentUser) -> list[BookingOut]:
    result = await db.execute(
        select(Booking, IntercityTrip)
        .outerjoin(IntercityTrip, IntercityTrip.id == Booking.trip_id)
        .where(Booking.passenger_id == user.id)
        .order_by(Booking.created_at.desc())
    )
    return [_booking_out(booking, trip=trip) for booking, trip in result.all()]


@router.get(
    "/bookings/{booking_id}",
    response_model=BookingOut,
)
async def get_booking(
    booking_id: str,
    db: DbSession,
    user: CurrentUser,
) -> BookingOut:
    booking = await db.get(Booking, booking_id)
    if not booking:
        raise NotFoundError("Booking not found")
    # Passengers see only their own; ops can see all
    if user.role == UserRole.PASSENGER and booking.passenger_id != user.id:
        raise NotFoundError("Booking not found")
    return _booking_out(booking)


@router.post(
    "/bookings/{booking_id}/cancel",
    response_model=BookingOut,
)
async def cancel_booking(
    booking_id: str,
    body: BookingCancelIn,
    db: DbSession,
    user: CurrentUser,
) -> BookingOut:
    is_ops = user.role == UserRole.OPS
    booking = await service.cancel_booking(
        db,
        booking_id=booking_id,
        cancelled_by_id=user.id,
        is_ops=is_ops,
    )
    return _booking_out(booking)


@router.post(
    "/bookings/{booking_id}/complete",
    response_model=BookingOut,
    dependencies=[Depends(require_roles(UserRole.OPS, UserRole.DRIVER))],
)
async def complete_booking(
    booking_id: str,
    db: DbSession,
) -> BookingOut:
    booking = await service.complete_booking(db, booking_id=booking_id)
    return _booking_out(booking)


# ── Helpers ────────────────────────────────────────────────────────────────────


def _trip_out(trip: IntercityTrip, available_seats: int) -> TripOut:
    return TripOut(
        id=trip.id,
        driver_id=trip.driver_id,
        vehicle_id=trip.vehicle_id,
        origin_city=trip.origin_city,
        destination_city=trip.destination_city,
        depart_at=trip.depart_at,
        price_per_seat=trip.price_per_seat,
        currency=trip.currency,
        seat_count=trip.seat_count,
        available_seats=available_seats,
        baggage_note=trip.baggage_note,
        meeting_point=trip.meeting_point,
        status=trip.status,
    )


def _booking_out(booking: Booking, trip: IntercityTrip | None = None) -> BookingOut:
    seat_list = [s for s in booking.seat_codes.split(",") if s] if booking.seat_codes else []
    return BookingOut(
        id=booking.id,
        trip_id=booking.trip_id,
        passenger_id=booking.passenger_id,
        status=booking.status,
        seat_codes=seat_list,
        passenger_count=booking.passenger_count,
        baggage_count=booking.baggage_count,
        total_price=booking.total_price,
        currency=booking.currency,
        payment_id=booking.payment_id,
        held_until=booking.held_until,
        created_at=booking.created_at,
        origin_city=trip.origin_city if trip else None,
        destination_city=trip.destination_city if trip else None,
        depart_at=trip.depart_at if trip else None,
    )
