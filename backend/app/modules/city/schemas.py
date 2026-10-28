from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class QuoteIn(BaseModel):
    pickup_address: str
    pickup_lat: float
    pickup_lng: float
    dropoff_address: str
    dropoff_lat: float
    dropoff_lng: float
    surge: float = 1.0


class QuoteOut(BaseModel):
    distance_km: Decimal
    duration_min: Decimal
    quoted_price: Decimal
    currency: str = "KGS"
    surge_multiplier: Decimal
    traffic_multiplier: Decimal = Decimal("1")
    demand_multiplier: Decimal = Decimal("1")
    congestion: str = "unknown"
    route_source: str = "estimate"
    route_geometry: list[list[float]] = Field(default_factory=list)
    platform_fee_estimate: Decimal
    driver_net_estimate: Decimal


class CreateRideIn(QuoteIn):
    idempotency_key: str | None = None


class RideOut(BaseModel):
    id: str
    status: str
    pickup_address: str
    dropoff_address: str
    quoted_price: Decimal | None
    final_price: Decimal | None
    surge_multiplier: Decimal
    driver_net_estimate: Decimal | None
    platform_fee_estimate: Decimal | None
    distance_km: Decimal | None
    duration_min: Decimal | None
    eta_min: int | None
    driver_id: str | None
    currency: str
    created_at: datetime | None = None
    completed_at: datetime | None = None


class DriverLocationIn(BaseModel):
    lat: float
    lng: float


class AcceptOfferIn(BaseModel):
    offer_id: str | None = None


class CancelRideIn(BaseModel):
    reason: str = Field(default="user_cancelled")
