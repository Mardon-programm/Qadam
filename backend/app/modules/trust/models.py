from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.enums import DriverOnlineStatus, VerificationStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class DriverProfile(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "driver_profiles"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_driver_profiles_user"),
        Index("ix_driver_online", "online_status"),
        Index("ix_driver_verification", "verification_status"),
    )

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    verification_status: Mapped[str] = mapped_column(
        String(32), default=VerificationStatus.DRAFT, nullable=False
    )
    online_status: Mapped[str] = mapped_column(
        String(32), default=DriverOnlineStatus.OFFLINE, nullable=False
    )
    rating: Mapped[Decimal] = mapped_column(Numeric(3, 2), default=Decimal("5.00"))
    rating_count: Mapped[int] = mapped_column(default=0, nullable=False)
    reliability_score: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("100.00"))
    active_vehicle_id: Mapped[str | None] = mapped_column(String(36))
    last_lat: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    last_lng: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    last_location_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    can_accept_corporate: Mapped[bool] = mapped_column(Boolean, default=False)
    blocked_reason: Mapped[str | None] = mapped_column(Text)


class Vehicle(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "vehicles"
    __table_args__ = (
        UniqueConstraint("plate_number", name="uq_vehicles_plate"),
        Index("ix_vehicles_driver", "driver_id"),
    )

    driver_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("driver_profiles.id"), nullable=False
    )
    make: Mapped[str] = mapped_column(String(64), nullable=False)
    model: Mapped[str] = mapped_column(String(64), nullable=False)
    color: Mapped[str | None] = mapped_column(String(32))
    plate_number: Mapped[str] = mapped_column(String(32), nullable=False)
    year: Mapped[int | None]
    seats: Mapped[int] = mapped_column(default=4, nullable=False)
    vehicle_class: Mapped[str] = mapped_column(String(32), default="economy")
    business_approved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), default=VerificationStatus.PENDING, nullable=False
    )


class DriverDocument(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "driver_documents"
    __table_args__ = (
        Index("ix_docs_driver", "driver_id"),
        Index("ix_docs_expires", "expires_on"),
    )

    driver_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("driver_profiles.id"), nullable=False
    )
    vehicle_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("vehicles.id"))
    doc_type: Mapped[str] = mapped_column(String(64), nullable=False)
    document_number: Mapped[str | None] = mapped_column(String(128))
    storage_url: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        String(32), default=VerificationStatus.PENDING, nullable=False
    )
    expires_on: Mapped[date | None] = mapped_column(Date)
    reviewed_by: Mapped[str | None] = mapped_column(String(36))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    rejection_reason: Mapped[str | None] = mapped_column(Text)
