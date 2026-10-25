"""Subscription schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class SubscriptionOut(BaseModel):
    id: str
    driver_id: str
    plan: str
    status: str
    price: Decimal
    currency: str
    starts_at: datetime
    ends_at: datetime | None
    paused_at: datetime | None
    pause_reason: str | None


class SubscribeIn(BaseModel):
    plan: str  # flex | pro_daily | pro_monthly


class PauseIn(BaseModel):
    reason: str = "driver_request"
