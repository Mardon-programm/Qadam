from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, Index, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.enums import SubscriptionPlan, SubscriptionStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class Subscription(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "subscriptions"
    __table_args__ = (Index("ix_subscriptions_driver", "driver_id", "status"),)

    driver_id: Mapped[str] = mapped_column(String(36), nullable=False)
    plan: Mapped[str] = mapped_column(
        String(32), default=SubscriptionPlan.FLEX, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(32), default=SubscriptionStatus.ACTIVE, nullable=False
    )
    price: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0"))
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    paused_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    pause_reason: Mapped[str | None] = mapped_column(String(255))
