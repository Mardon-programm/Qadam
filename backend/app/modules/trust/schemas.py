from datetime import date
from decimal import Decimal

from pydantic import BaseModel, Field


class VehicleIn(BaseModel):
    make: str
    model: str
    color: str | None = None
    plate_number: str
    year: int | None = None
    seats: int = 4
    vehicle_class: str = "economy"


class VehicleOut(BaseModel):
    id: str
    make: str
    model: str
    color: str | None
    plate_number: str
    seats: int
    vehicle_class: str
    status: str


class DocumentIn(BaseModel):
    doc_type: str
    document_number: str | None = None
    storage_url: str | None = None
    expires_on: date | None = None
    vehicle_id: str | None = None


class DocumentOut(BaseModel):
    id: str
    doc_type: str
    document_number: str | None
    status: str
    expires_on: date | None
    rejection_reason: str | None


class DriverProfileOut(BaseModel):
    id: str
    verification_status: str
    online_status: str
    rating: Decimal
    active_vehicle_id: str | None
    can_accept_corporate: bool


class OnlineIn(BaseModel):
    online: bool


class LocationIn(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)


class ReviewDocumentIn(BaseModel):
    approve: bool
    rejection_reason: str | None = None


class ReviewVehicleIn(BaseModel):
    approve: bool
    rejection_reason: str | None = None
