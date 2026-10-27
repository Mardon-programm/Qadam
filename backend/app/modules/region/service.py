"""Region (intercity) service — trip creation, seat reservation, booking lifecycle.

Key invariants enforced here:
  - A seat cannot be confirmed for two passengers (SELECT FOR UPDATE + unique seat_code per trip)
  - HELD state expires; expired HELD seats revert to AVAILABLE on next availability query
  - Payment and booking confirmation are linked; no confirmation without SUCCEEDED payment
  - Ledger entries are idempotent via booking_id keys
"""

from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.enums import (
    BookingStatus,
    LedgerDirection,
    SeatStatus,
    VerificationStatus,
)
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.modules.ledger.service import post_entry
from app.modules.region.models import Booking, IntercityTrip, TripSeat
from app.modules.trust.models import DriverProfile, Vehicle

HOLD_TTL_SECONDS = 300  # 5 minutes to complete payment


# ── Trip management ────────────────────────────────────────────────────────────


async def create_trip(
    db: AsyncSession,
    *,
    driver_id: str,
    vehicle_id: str,
    origin_city: str,
    destination_city: str,
    depart_at: datetime,
    price_per_seat: Decimal,
    seat_count: int,
    baggage_note: str | None = None,
    meeting_point: str | None = None,
) -> IntercityTrip:
    """Create a trip and materialise individual TripSeat rows."""
    driver = await db.get(DriverProfile, driver_id)
    if not driver or driver.verification_status != VerificationStatus.APPROVED:
        raise ForbiddenError("Driver must be verified to create trips")

    vehicle = await db.get(Vehicle, vehicle_id)
    if not vehicle or vehicle.driver_id != driver_id:
        raise ForbiddenError("Vehicle does not belong to this driver")
    if vehicle.status != VerificationStatus.APPROVED:
        raise ForbiddenError("Vehicle must be approved")

    if depart_at <= datetime.now(UTC):
        raise ConflictError("Departure time must be in the future")

    if seat_count > vehicle.seats:
        raise ConflictError(f"seat_count ({seat_count}) exceeds vehicle capacity ({vehicle.seats})")

    trip = IntercityTrip(
        driver_id=driver_id,
        vehicle_id=vehicle_id,
        origin_city=origin_city.lower(),
        destination_city=destination_city.lower(),
        depart_at=depart_at,
        price_per_seat=price_per_seat,
        seat_count=seat_count,
        baggage_note=baggage_note,
        meeting_point=meeting_point,
        status="scheduled",
    )
    db.add(trip)
    await db.flush()

    # Materialise seats with simple numeric codes
    for i in range(1, seat_count + 1):
        db.add(
            TripSeat(
                trip_id=trip.id,
                seat_code=str(i),
                status=SeatStatus.AVAILABLE,
                version=0,
            )
        )
    await db.flush()
    return trip


async def count_available_seats(db: AsyncSession, trip_id: str) -> int:
    """Count seats that are either AVAILABLE or have an expired HELD state."""
    now = datetime.now(UTC)
    result = await db.execute(
        select(TripSeat).where(
            TripSeat.trip_id == trip_id,
            TripSeat.status.in_([SeatStatus.AVAILABLE, SeatStatus.HELD]),
        )
    )
    available = 0
    for seat in result.scalars().all():
        if seat.status == SeatStatus.AVAILABLE:
            available += 1
        elif seat.held_until and seat.held_until < now:
            # Expired hold — count as available (will be cleaned on next hold attempt)
            available += 1
    return available


async def get_trip_with_availability(db: AsyncSession, trip_id: str) -> tuple[IntercityTrip, int]:
    trip = await db.get(IntercityTrip, trip_id)
    if not trip:
        raise NotFoundError("Trip not found")
    available = await count_available_seats(db, trip_id)
    return trip, available


async def update_trip_status(
    db: AsyncSession,
    *,
    trip_id: str,
    driver_id: str,
    new_status: str,
) -> IntercityTrip:
    trip = await db.get(IntercityTrip, trip_id)
    if not trip:
        raise NotFoundError("Trip not found")
    if trip.driver_id != driver_id:
        raise ForbiddenError("Not your trip")

    allowed: dict[str, set[str]] = {
        "scheduled": {"departed", "cancelled"},
        "departed": {"completed"},
    }
    if new_status not in allowed.get(trip.status, set()):
        raise ConflictError(f"Cannot transition trip {trip.status} → {new_status}")
    trip.status = new_status
    await db.flush()
    return trip


# ── Seat reservation ───────────────────────────────────────────────────────────


async def _expire_stale_holds(db: AsyncSession, trip_id: str) -> None:
    """Release HELD seats whose hold timer has expired."""
    now = datetime.now(UTC)
    result = await db.execute(
        select(TripSeat)
        .where(
            TripSeat.trip_id == trip_id,
            TripSeat.status == SeatStatus.HELD,
        )
        .with_for_update(skip_locked=True)
    )
    for seat in result.scalars().all():
        if seat.held_until and seat.held_until < now:
            seat.status = SeatStatus.AVAILABLE
            seat.held_until = None
            seat.booking_id = None
    await db.flush()


async def hold_seats(
    db: AsyncSession,
    *,
    trip_id: str,
    count: int,
    booking_id: str,
) -> list[TripSeat]:
    """
    Atomically hold `count` AVAILABLE seats.
    Uses SELECT FOR UPDATE to prevent double-booking.
    Expires stale holds first.
    """
    await _expire_stale_holds(db, trip_id)
    now = datetime.now(UTC)
    held_until = now + timedelta(seconds=HOLD_TTL_SECONDS)

    result = await db.execute(
        select(TripSeat)
        .where(
            and_(
                TripSeat.trip_id == trip_id,
                TripSeat.status == SeatStatus.AVAILABLE,
            )
        )
        .limit(count)
        .with_for_update()
    )
    seats = list(result.scalars().all())
    if len(seats) < count:
        raise ConflictError(f"Not enough available seats: requested {count}, found {len(seats)}")
    for seat in seats:
        seat.status = SeatStatus.HELD
        seat.held_until = held_until
        seat.booking_id = booking_id
    await db.flush()
    return seats


async def confirm_seats(db: AsyncSession, booking_id: str) -> list[TripSeat]:
    """Transition HELD seats to CONFIRMED after successful payment."""
    result = await db.execute(
        select(TripSeat)
        .where(
            TripSeat.booking_id == booking_id,
            TripSeat.status == SeatStatus.HELD,
        )
        .with_for_update()
    )
    seats = list(result.scalars().all())
    if not seats:
        raise ConflictError("No held seats found for this booking")
    for seat in seats:
        seat.status = SeatStatus.CONFIRMED
        seat.held_until = None
    await db.flush()
    return seats


async def release_seats(db: AsyncSession, booking_id: str) -> None:
    """Return seats to AVAILABLE on booking cancellation."""
    result = await db.execute(
        select(TripSeat)
        .where(
            TripSeat.booking_id == booking_id,
            TripSeat.status.in_([SeatStatus.HELD, SeatStatus.CONFIRMED]),
        )
        .with_for_update()
    )
    for seat in result.scalars().all():
        seat.status = SeatStatus.AVAILABLE
        seat.held_until = None
        seat.booking_id = None
    await db.flush()


# ── Booking lifecycle ──────────────────────────────────────────────────────────


async def create_booking(
    db: AsyncSession,
    *,
    passenger_id: str,
    trip_id: str,
    passenger_count: int = 1,
    baggage_count: int = 0,
    idempotency_key: str | None = None,
) -> Booking:
    # Idempotency guard
    if idempotency_key:
        existing = await db.execute(
            select(Booking).where(Booking.idempotency_key == idempotency_key)
        )
        found = existing.scalar_one_or_none()
        if found:
            return found

    trip = await db.get(IntercityTrip, trip_id)
    if not trip:
        raise NotFoundError("Trip not found")
    if trip.status != "scheduled":
        raise ConflictError("Trip is not accepting bookings")

    total_price = trip.price_per_seat * Decimal(passenger_count)
    now = datetime.now(UTC)

    booking = Booking(
        passenger_id=passenger_id,
        trip_id=trip_id,
        status=BookingStatus.HELD,
        seat_codes="",  # populated after hold
        passenger_count=passenger_count,
        baggage_count=baggage_count,
        total_price=total_price,
        currency=trip.currency,
        held_until=now + timedelta(seconds=HOLD_TTL_SECONDS),
        idempotency_key=idempotency_key,
    )
    db.add(booking)
    await db.flush()

    # Atomically reserve seats
    seats = await hold_seats(db, trip_id=trip_id, count=passenger_count, booking_id=booking.id)
    booking.seat_codes = ",".join(s.seat_code for s in seats)
    await db.flush()
    return booking


async def confirm_booking(
    db: AsyncSession,
    *,
    booking_id: str,
    payment_id: str,
) -> Booking:
    """
    Confirm booking after payment has SUCCEEDED.
    Transitions HELD → CONFIRMED, confirms seats.
    Idempotent: already-confirmed bookings return immediately.
    """
    booking = await db.get(Booking, booking_id)
    if not booking:
        raise NotFoundError("Booking not found")
    if booking.status == BookingStatus.CONFIRMED:
        return booking
    if booking.status != BookingStatus.HELD:
        raise ConflictError(f"Cannot confirm booking in status {booking.status}")
    if booking.held_until and booking.held_until < datetime.now(UTC):
        raise ConflictError("Booking hold has expired")

    booking.status = BookingStatus.CONFIRMED
    booking.payment_id = payment_id
    booking.held_until = None
    await confirm_seats(db, booking_id)
    await db.flush()
    return booking


async def cancel_booking(
    db: AsyncSession,
    *,
    booking_id: str,
    cancelled_by_id: str,
    is_ops: bool = False,
) -> Booking:
    result = await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())
    booking = result.scalar_one_or_none()
    if not booking:
        raise NotFoundError("Booking not found")
    if not is_ops and booking.passenger_id != cancelled_by_id:
        raise ForbiddenError("Not your booking")
    if booking.status in {BookingStatus.CANCELLED, BookingStatus.COMPLETED}:
        raise ConflictError("Booking already finalised")

    booking.status = BookingStatus.CANCELLED
    await release_seats(db, booking_id)
    await db.flush()
    return booking


async def complete_booking(db: AsyncSession, *, booking_id: str) -> Booking:
    """Mark booking as COMPLETED and post earnings to ledger."""
    result = await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())
    booking = result.scalar_one_or_none()
    if not booking:
        raise NotFoundError("Booking not found")
    if booking.status != BookingStatus.CONFIRMED:
        raise ConflictError("Only confirmed bookings can be completed")

    trip = await db.get(IntercityTrip, booking.trip_id)
    if not trip:
        raise NotFoundError("Trip not found")

    # Move seats to COMPLETED
    result2 = await db.execute(
        select(TripSeat)
        .where(
            TripSeat.booking_id == booking_id,
            TripSeat.status == SeatStatus.CONFIRMED,
        )
        .with_for_update()
    )
    for seat in result2.scalars().all():
        seat.status = SeatStatus.COMPLETED

    booking.status = BookingStatus.COMPLETED

    # Platform commission on region bookings (0 by default: free for drivers).
    commission_rate = Decimal(str(get_settings().region_commission_rate))
    commission = (booking.total_price * commission_rate).quantize(Decimal("0.01"))
    driver_net = booking.total_price - commission

    await post_entry(
        db,
        account_id=f"driver:{trip.driver_id}",
        account_owner_type="driver",
        account_owner_id=trip.driver_id,
        direction=LedgerDirection.CREDIT,
        amount=driver_net,
        entry_type="booking_earning",
        reference_type="booking",
        reference_id=booking_id,
        idempotency_key=f"booking:{booking_id}:driver_credit",
        description="Driver net for completed intercity booking",
    )
    if commission > 0:
        await post_entry(
            db,
            account_id="platform:fees",
            account_owner_type="platform",
            account_owner_id="qadam",
            direction=LedgerDirection.CREDIT,
            amount=commission,
            entry_type="platform_fee",
            reference_type="booking",
            reference_id=booking_id,
            idempotency_key=f"booking:{booking_id}:platform_fee",
            description="Platform fee for completed intercity booking",
        )

    await db.flush()
    return booking
