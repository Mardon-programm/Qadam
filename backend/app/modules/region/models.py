from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.enums import BookingStatus, SeatStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class IntercityTrip(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "intercity_trips"
    __table_args__ = (
        Index("ix_intercity_route_date", "origin_city", "destination_city", "depart_at"),
    )

    driver_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("driver_profiles.id"), nullable=False
    )
    vehicle_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("vehicles.id"), nullable=False
    )
    origin_city: Mapped[str] = mapped_column(String(64), nullable=False)
    destination_city: Mapped[str] = mapped_column(String(64), nullable=False)
    depart_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    price_per_seat: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    seat_count: Mapped[int] = mapped_column(Integer, nullable=False)
    baggage_note: Mapped[str | None] = mapped_column(Text)
    meeting_point: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(32), default="scheduled", nullable=False)


class TripSeat(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Seat state machine: AVAILABLE → HELD → CONFIRMED → OCCUPIED → COMPLETED."""

    __tablename__ = "trip_seats"
    __table_args__ = (
        UniqueConstraint("trip_id", "seat_code", name="uq_trip_seat_code"),
        Index("ix_trip_seats_status", "trip_id", "status"),
    )

    trip_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("intercity_trips.id"), nullable=False
    )
    seat_code: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), default=SeatStatus.AVAILABLE, nullable=False
    )
    held_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    booking_id: Mapped[str | None] = mapped_column(String(36))
    version: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class Booking(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "bookings"
    __table_args__ = (
        Index("ix_bookings_passenger", "passenger_id"),
        UniqueConstraint("idempotency_key", name="uq_booking_idempotency"),
    )

    passenger_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=False
    )
    trip_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("intercity_trips.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(32), default=BookingStatus.HELD, nullable=False
    )
    seat_codes: Mapped[str] = mapped_column(Text, nullable=False)  # comma-separated
    passenger_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    baggage_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    payment_id: Mapped[str | None] = mapped_column(String(36))
    held_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    idempotency_key: Mapped[str | None] = mapped_column(String(128))
