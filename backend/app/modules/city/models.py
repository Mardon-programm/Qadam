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
from app.core.enums import RideOrderStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class RideOrder(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "ride_orders"
    __table_args__ = (
        Index("ix_ride_status", "status"),
        Index("ix_ride_passenger", "passenger_id"),
        Index("ix_ride_driver", "driver_id"),
        # At most one active assignment per order is enforced in service;
        # unique partial assignment is represented by driver_id + status checks.
    )

    passenger_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=False
    )
    driver_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("driver_profiles.id")
    )
    vehicle_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("vehicles.id"))
    status: Mapped[str] = mapped_column(
        String(32), default=RideOrderStatus.CREATED, nullable=False
    )
    city: Mapped[str] = mapped_column(String(64), default="bishkek", nullable=False)

    pickup_address: Mapped[str] = mapped_column(Text, nullable=False)
    pickup_lat: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    pickup_lng: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    dropoff_address: Mapped[str] = mapped_column(Text, nullable=False)
    dropoff_lat: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    dropoff_lng: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)

    distance_km: Mapped[Decimal | None] = mapped_column(Numeric(10, 3))
    duration_min: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    eta_min: Mapped[int | None] = mapped_column(Integer)

    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    quoted_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    final_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    surge_multiplier: Mapped[Decimal] = mapped_column(
        Numeric(4, 2), default=Decimal("1.00"), nullable=False
    )
    driver_net_estimate: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    platform_fee_estimate: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))

    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancel_reason: Mapped[str | None] = mapped_column(Text)
    cancelled_by: Mapped[str | None] = mapped_column(String(32))

    # Protects against double completion / double accrual
    ledger_posted: Mapped[bool] = mapped_column(default=False, nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String(128), unique=True)


class RideOffer(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Sequential offer to a driver while searching."""

    __tablename__ = "ride_offers"
    __table_args__ = (
        UniqueConstraint("ride_order_id", "driver_id", name="uq_offer_ride_driver"),
        Index("ix_offers_status", "status"),
    )

    ride_order_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("ride_orders.id"), nullable=False
    )
    driver_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("driver_profiles.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(32), default="offered", nullable=False)
    eta_min: Mapped[int | None] = mapped_column(Integer)
    net_estimate: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
