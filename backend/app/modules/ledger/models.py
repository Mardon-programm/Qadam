from decimal import Decimal

from sqlalchemy import Index, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.enums import LedgerDirection, PayoutStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class LedgerEntry(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Immutable journal entry. Never update amount/direction after insert."""

    __tablename__ = "ledger_entries"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="uq_ledger_idempotency"),
        Index("ix_ledger_account", "account_id"),
        Index("ix_ledger_ref", "reference_type", "reference_id"),
    )

    account_id: Mapped[str] = mapped_column(String(64), nullable=False)
    account_owner_type: Mapped[str] = mapped_column(String(32), nullable=False)
    account_owner_id: Mapped[str] = mapped_column(String(36), nullable=False)
    direction: Mapped[str] = mapped_column(String(16), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    entry_type: Mapped[str] = mapped_column(String(64), nullable=False)
    reference_type: Mapped[str] = mapped_column(String(64), nullable=False)
    reference_id: Mapped[str] = mapped_column(String(36), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    # Soft-delete forbidden; corrections are reverse entries.


class Payout(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "payouts"
    __table_args__ = (Index("ix_payouts_driver", "driver_id"),)

    driver_id: Mapped[str] = mapped_column(String(36), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), default=PayoutStatus.PENDING, nullable=False
    )
    provider_ref: Mapped[str | None] = mapped_column(String(128))
    failure_reason: Mapped[str | None] = mapped_column(Text)


# Convenience re-export for type checkers / imports
LedgerDirectionType = LedgerDirection
