from decimal import Decimal

from sqlalchemy import Index, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.enums import PaymentStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class Payment(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "payments"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="uq_payments_idempotency"),
        UniqueConstraint("provider", "external_id", name="uq_payments_provider_ext"),
        Index("ix_payments_status", "status"),
        Index("ix_payments_ref", "reference_type", "reference_id"),
    )

    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    external_id: Mapped[str | None] = mapped_column(String(128))
    status: Mapped[str] = mapped_column(
        String(32), default=PaymentStatus.CREATED, nullable=False
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    payer_user_id: Mapped[str | None] = mapped_column(String(36))
    reference_type: Mapped[str] = mapped_column(String(64), nullable=False)
    reference_id: Mapped[str] = mapped_column(String(36), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    raw_payload: Mapped[str | None] = mapped_column(Text)
    failure_reason: Mapped[str | None] = mapped_column(Text)


class PaymentEvent(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Idempotent webhook / provider event log."""

    __tablename__ = "payment_events"
    __table_args__ = (
        UniqueConstraint("provider", "event_id", name="uq_payment_event"),
    )

    payment_id: Mapped[str | None] = mapped_column(String(36))
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    event_id: Mapped[str] = mapped_column(String(128), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    processed: Mapped[bool] = mapped_column(default=False, nullable=False)
    payload: Mapped[str | None] = mapped_column(Text)
