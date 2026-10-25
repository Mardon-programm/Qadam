"""Ops / admin panel schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class UserSummary(BaseModel):
    id: str
    phone: str
    full_name: str | None
    role: str
    status: str
    created_at: datetime


class DriverSummary(BaseModel):
    id: str
    user_id: str
    verification_status: str
    online_status: str
    rating: Decimal
    reliability_score: Decimal
    can_accept_corporate: bool


class RideSummary(BaseModel):
    id: str
    passenger_id: str
    driver_id: str | None
    status: str
    city: str
    quoted_price: Decimal | None
    final_price: Decimal | None
    created_at: datetime


class AuditEventOut(BaseModel):
    id: str
    actor_id: str | None
    actor_role: str | None
    action: str
    object_type: str
    object_id: str | None
    ip_address: str | None
    created_at: datetime


class PlatformStatsOut(BaseModel):
    total_users: int
    total_drivers: int
    active_drivers_online: int
    rides_today: int
    bookings_today: int
    open_support_cases: int


class BlockUserIn(BaseModel):
    reason: str = "ops_decision"
