"""Schemas for Qadam Region (intercity) module."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field

# ── Trip schemas ──────────────────────────────────────────────────────────────


class TripCreateIn(BaseModel):
    origin_city: str
    destination_city: str
    depart_at: datetime
    price_per_seat: Decimal = Field(..., gt=0)
    seat_count: int = Field(..., ge=1, le=20)
    baggage_note: str | None = None
    meeting_point: str | None = None


class TripOut(BaseModel):
    id: str
    driver_id: str
    vehicle_id: str
    origin_city: str
    destination_city: str
    depart_at: datetime
    price_per_seat: Decimal
    currency: str
    seat_count: int
    available_seats: int
    baggage_note: str | None
    meeting_point: str | None
    status: str


class TripStatusIn(BaseModel):
    status: str = Field(
        ...,
        pattern="^(scheduled|departed|completed|cancelled)$",
    )


# ── Booking schemas ───────────────────────────────────────────────────────────


class BookingCreateIn(BaseModel):
    trip_id: str
    passenger_count: int = Field(default=1, ge=1, le=8)
    baggage_count: int = Field(default=0, ge=0)
    idempotency_key: str | None = None


class BookingOut(BaseModel):
    id: str
    trip_id: str
    passenger_id: str
    status: str
    seat_codes: list[str]
    passenger_count: int
    baggage_count: int
    total_price: Decimal
    currency: str
    payment_id: str | None
    held_until: datetime | None
    created_at: datetime | None = None
    origin_city: str | None = None
    destination_city: str | None = None
    depart_at: datetime | None = None


class BookingCancelIn(BaseModel):
    reason: str = "passenger_cancelled"


# ── Seat schemas ──────────────────────────────────────────────────────────────


class SeatOut(BaseModel):
    seat_code: str
    status: str
