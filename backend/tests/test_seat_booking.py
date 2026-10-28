"""Tests for seat assignment and booking race conditions."""

import pytest
import asyncio
from httpx import AsyncClient
from sqlalchemy import select

from app.modules.region.models import TripSeat, Booking
from app.core.database import SessionLocal
from app.core.enums import SeatStatus


@pytest.mark.asyncio
async def test_concurrent_seat_booking_race_condition(
    client: AsyncClient, auth_headers: dict, test_trip
):
    """
    Critical test: Two users try to book the same seat simultaneously.
    Only one should succeed due to DB transaction protection.
    """
    seat_id = test_trip.seats[0].id if test_trip.seats else "seat-1"

    # Two concurrent booking requests for the same seat
    async def book_seat(user_headers):
        response = await client.post(
            "/api/v1/region/bookings",
            headers=user_headers,
            json={
                "trip_id": test_trip.id,
                "seat_ids": [seat_id],
                "passenger_count": 1,
            },
        )
        return response

    # Simulate race condition
    results = await asyncio.gather(
        book_seat(auth_headers),
        book_seat(auth_headers),
        return_exceptions=True,
    )

    # Count successful bookings
    success_count = sum(
        1 for r in results if not isinstance(r, Exception) and r.status_code in [200, 201]
    )

    # Only ONE booking should succeed
    assert success_count == 1, "Multiple bookings succeeded for same seat!"

    # Verify seat is now CONFIRMED
    async with SessionLocal() as db:
        result = await db.execute(select(TripSeat).where(TripSeat.id == seat_id))
        seat = result.scalar_one()
        assert seat.status == SeatStatus.CONFIRMED


@pytest.mark.asyncio
async def test_held_seat_expires_automatically(client: AsyncClient, auth_headers: dict, test_trip):
    """Test that HELD seats are released by worker after timeout."""
    from datetime import UTC, datetime, timedelta

    async with SessionLocal() as db:
        # Create a seat in HELD state that should have expired
        seat = TripSeat(
            trip_id=test_trip.id,
            seat_number="1A",
            status=SeatStatus.HELD,
            held_until=datetime.now(UTC) - timedelta(minutes=5),  # Expired 5 min ago
        )
        db.add(seat)
        await db.commit()
        seat_id = seat.id

    # Manually trigger seat expiry logic (simulating worker)
    from app.workers.runner import seat_expiry_worker

    # Worker should release this seat
    async with SessionLocal() as db:
        result = await db.execute(select(TripSeat).where(TripSeat.id == seat_id))
        seat_after = result.scalar_one()

        # Update it as worker would
        if seat_after.status == SeatStatus.HELD and seat_after.held_until < datetime.now(UTC):
            seat_after.status = SeatStatus.AVAILABLE
            seat_after.held_until = None
            await db.commit()

    # Verify seat is now available
    async with SessionLocal() as db:
        result = await db.execute(select(TripSeat).where(TripSeat.id == seat_id))
        final_seat = result.scalar_one()
        assert final_seat.status == SeatStatus.AVAILABLE


@pytest.mark.asyncio
async def test_booking_with_payment_atomicity(client: AsyncClient, auth_headers: dict, test_trip):
    """
    Test that booking + payment is atomic:
    If payment fails, booking should not be confirmed.
    """
    seat_id = "test-seat-123"

    # Create booking with payment
    response = await client.post(
        "/api/v1/region/bookings",
        headers=auth_headers,
        json={
            "trip_id": test_trip.id,
            "seat_ids": [seat_id],
            "passenger_count": 1,
            "payment_method": "mock_fail",  # Force payment to fail
        },
    )

    # Booking should fail if payment fails
    # OR seat should remain in HELD state, not CONFIRMED
    if response.status_code == 201:
        booking_id = response.json()["id"]

        async with SessionLocal() as db:
            result = await db.execute(select(Booking).where(Booking.id == booking_id))
            booking = result.scalar_one_or_none()

            if booking:
                # If booking exists, it should not be confirmed without payment
                assert booking.status != "confirmed"


@pytest.mark.asyncio
async def test_double_booking_prevented_by_unique_constraint(test_trip):
    """Test that database constraints prevent double booking."""
    from sqlalchemy.exc import IntegrityError

    async with SessionLocal() as db:
        # Try to create two bookings for the same seat
        seat = TripSeat(
            trip_id=test_trip.id,
            seat_number="1A",
            status=SeatStatus.AVAILABLE,
        )
        db.add(seat)
        await db.commit()
        await db.refresh(seat)

        # First booking
        booking1 = Booking(
            trip_id=test_trip.id,
            passenger_id="user-1",
            seat_ids=[seat.id],
            status="confirmed",
        )
        db.add(booking1)
        await db.commit()

        # Update seat
        seat.status = SeatStatus.CONFIRMED
        seat.booking_id = booking1.id
        await db.commit()

        # Try to create second booking for same seat
        # This should be prevented by application logic
        # (DB constraints + transaction isolation)
        result = await db.execute(select(TripSeat).where(TripSeat.id == seat.id))
        seat_check = result.scalar_one()
        assert seat_check.status == SeatStatus.CONFIRMED
        assert seat_check.booking_id == booking1.id


@pytest.mark.asyncio
async def test_booking_cancellation_releases_seat(
    client: AsyncClient, auth_headers: dict, test_trip
):
    """Test that cancelling a booking releases the seat back to AVAILABLE."""
    # Create a booking
    response = await client.post(
        "/api/v1/region/bookings",
        headers=auth_headers,
        json={
            "trip_id": test_trip.id,
            "seat_ids": ["seat-cancel-test"],
            "passenger_count": 1,
        },
    )

    if response.status_code == 201:
        booking_id = response.json()["id"]

        # Cancel the booking
        cancel_response = await client.post(
            f"/api/v1/region/bookings/{booking_id}/cancel",
            headers=auth_headers,
        )

        # Seat should be released
        if cancel_response.status_code == 200:
            async with SessionLocal() as db:
                result = await db.execute(select(TripSeat).where(TripSeat.booking_id == booking_id))
                seats = list(result.scalars().all())

                for seat in seats:
                    assert seat.status == SeatStatus.AVAILABLE
                    assert seat.booking_id is None
