"""Trust & Driver management endpoints.

Covers:
  - Driver profile retrieval
  - Vehicle CRUD
  - Document upload / listing
  - Online / offline toggle
  - Driver location heartbeat
  - Ops: document review, driver block/unblock
"""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import DriverOnlineStatus, UserRole, VerificationStatus
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.modules.trust import service
from app.modules.trust.models import DriverDocument, DriverProfile, Vehicle
from app.modules.trust.schemas import (
    DocumentIn,
    DocumentOut,
    DriverProfileOut,
    LocationIn,
    OnlineIn,
    ReviewDocumentIn,
    VehicleIn,
    VehicleOut,
)

router = APIRouter(prefix="/driver", tags=["driver"])
ops_router = APIRouter(prefix="/ops/driver", tags=["ops-driver"])


# ── Driver profile ─────────────────────────────────────────────────────────────


@router.get("/profile", response_model=DriverProfileOut)
async def get_my_profile(
    db: DbSession,
    user: CurrentUser,
) -> DriverProfileOut:
    profile = await service.get_or_create_driver_profile(db, user.id)
    return _profile_out(profile)


# ── Vehicles ───────────────────────────────────────────────────────────────────


@router.get(
    "/vehicles",
    response_model=list[VehicleOut],
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def list_vehicles(db: DbSession, user: CurrentUser) -> list[VehicleOut]:
    profile = await service.get_or_create_driver_profile(db, user.id)
    result = await db.execute(
        select(Vehicle).where(Vehicle.driver_id == profile.id)
    )
    return [_vehicle_out(v) for v in result.scalars().all()]


@router.post(
    "/vehicles",
    response_model=VehicleOut,
    status_code=201,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def add_vehicle(
    body: VehicleIn,
    db: DbSession,
    user: CurrentUser,
) -> VehicleOut:
    profile = await service.get_or_create_driver_profile(db, user.id)
    vehicle = Vehicle(
        driver_id=profile.id,
        make=body.make,
        model=body.model,
        color=body.color,
        plate_number=body.plate_number.upper().replace(" ", ""),
        year=body.year,
        seats=body.seats,
        vehicle_class=body.vehicle_class,
        status=VerificationStatus.PENDING,
    )
    db.add(vehicle)
    await db.flush()
    # Auto-set as active vehicle if driver has none
    if not profile.active_vehicle_id:
        profile.active_vehicle_id = vehicle.id
    await db.flush()
    return _vehicle_out(vehicle)


@router.put(
    "/vehicles/{vehicle_id}/activate",
    response_model=VehicleOut,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def activate_vehicle(
    vehicle_id: str,
    db: DbSession,
    user: CurrentUser,
) -> VehicleOut:
    profile = await service.get_or_create_driver_profile(db, user.id)
    vehicle = await db.get(Vehicle, vehicle_id)
    if not vehicle or vehicle.driver_id != profile.id:
        raise NotFoundError("Vehicle not found")
    if vehicle.status != VerificationStatus.APPROVED:
        raise ForbiddenError("Vehicle must be approved before activation")
    if profile.online_status == DriverOnlineStatus.BUSY:
        raise ConflictError("Cannot change vehicle during active ride")
    profile.active_vehicle_id = vehicle.id
    await db.flush()
    return _vehicle_out(vehicle)


# ── Documents ──────────────────────────────────────────────────────────────────


@router.get(
    "/documents",
    response_model=list[DocumentOut],
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def list_documents(db: DbSession, user: CurrentUser) -> list[DocumentOut]:
    profile = await service.get_or_create_driver_profile(db, user.id)
    result = await db.execute(
        select(DriverDocument).where(DriverDocument.driver_id == profile.id)
    )
    return [_doc_out(d) for d in result.scalars().all()]


@router.post(
    "/documents",
    response_model=DocumentOut,
    status_code=201,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def upload_document(
    body: DocumentIn,
    db: DbSession,
    user: CurrentUser,
) -> DocumentOut:
    profile = await service.get_or_create_driver_profile(db, user.id)
    doc = DriverDocument(
        driver_id=profile.id,
        vehicle_id=body.vehicle_id,
        doc_type=body.doc_type,
        document_number=body.document_number,
        storage_url=body.storage_url,
        expires_on=body.expires_on,
        status=VerificationStatus.PENDING,
    )
    db.add(doc)
    await db.flush()
    return _doc_out(doc)


# ── Online status & location ───────────────────────────────────────────────────


@router.post(
    "/online",
    response_model=DriverProfileOut,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def set_online(
    body: OnlineIn,
    db: DbSession,
    user: CurrentUser,
) -> DriverProfileOut:
    profile = await service.get_or_create_driver_profile(db, user.id)
    updated = await service.set_online(db, driver=profile, online=body.online)
    return _profile_out(updated)


@router.post(
    "/location",
    status_code=204,
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def update_location(
    body: LocationIn,
    db: DbSession,
    user: CurrentUser,
) -> None:
    profile = await service.get_or_create_driver_profile(db, user.id)
    profile.last_lat = body.lat  # type: ignore[assignment]
    profile.last_lng = body.lng  # type: ignore[assignment]
    profile.last_location_at = datetime.now(UTC)
    await db.flush()


# ── Ops: document review ───────────────────────────────────────────────────────


@ops_router.post(
    "/documents/{document_id}/review",
    response_model=DocumentOut,
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def review_document(
    document_id: str,
    body: ReviewDocumentIn,
    db: DbSession,
    user: CurrentUser,
) -> DocumentOut:
    doc = await service.review_document(
        db,
        document_id=document_id,
        reviewer_id=user.id,
        approve=body.approve,
        rejection_reason=body.rejection_reason,
    )
    return _doc_out(doc)


@ops_router.get(
    "/{driver_id}/documents",
    response_model=list[DocumentOut],
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def ops_list_driver_documents(
    driver_id: str,
    db: DbSession,
) -> list[DocumentOut]:
    result = await db.execute(
        select(DriverDocument).where(DriverDocument.driver_id == driver_id)
    )
    return [_doc_out(d) for d in result.scalars().all()]


@ops_router.post(
    "/{driver_id}/block",
    response_model=DriverProfileOut,
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def block_driver(
    driver_id: str,
    db: DbSession,
    user: CurrentUser,
    reason: str = "ops_decision",
) -> DriverProfileOut:
    profile = await db.get(DriverProfile, driver_id)
    if not profile:
        raise NotFoundError("Driver profile not found")
    profile.verification_status = VerificationStatus.REJECTED
    profile.online_status = DriverOnlineStatus.OFFLINE
    profile.blocked_reason = reason
    await db.flush()
    return _profile_out(profile)


@ops_router.post(
    "/{driver_id}/unblock",
    response_model=DriverProfileOut,
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def unblock_driver(
    driver_id: str,
    db: DbSession,
) -> DriverProfileOut:
    profile = await db.get(DriverProfile, driver_id)
    if not profile:
        raise NotFoundError("Driver profile not found")
    profile.verification_status = VerificationStatus.PENDING
    profile.blocked_reason = None
    await db.flush()
    return _profile_out(profile)


# ── Helpers ────────────────────────────────────────────────────────────────────


def _profile_out(p: DriverProfile) -> DriverProfileOut:
    return DriverProfileOut(
        id=p.id,
        verification_status=p.verification_status,
        online_status=p.online_status,
        rating=p.rating,
        active_vehicle_id=p.active_vehicle_id,
        can_accept_corporate=p.can_accept_corporate,
    )


def _vehicle_out(v: Vehicle) -> VehicleOut:
    return VehicleOut(
        id=v.id,
        make=v.make,
        model=v.model,
        color=v.color,
        plate_number=v.plate_number,
        seats=v.seats,
        vehicle_class=v.vehicle_class,
        status=v.status,
    )


def _doc_out(d: DriverDocument) -> DocumentOut:
    return DocumentOut(
        id=d.id,
        doc_type=d.doc_type,
        document_number=d.document_number,
        status=d.status,
        expires_on=d.expires_on,
        rejection_reason=d.rejection_reason,
    )
