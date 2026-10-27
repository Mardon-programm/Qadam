from datetime import UTC, date, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import DriverOnlineStatus, VerificationStatus
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.modules.trust.models import DriverDocument, DriverProfile, Vehicle

REQUIRED_DOC_TYPES = {
    "driver_license",
    "vehicle_registration",
    "taxi_license",
}


async def get_or_create_driver_profile(
    db: AsyncSession, user_id: str
) -> DriverProfile:
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == user_id)
    )
    profile = result.scalar_one_or_none()
    if profile:
        return profile
    profile = DriverProfile(user_id=user_id)
    db.add(profile)
    await db.flush()
    return profile


async def documents_allow_online(db: AsyncSession, driver: DriverProfile) -> bool:
    if driver.verification_status != VerificationStatus.APPROVED:
        return False
    if not driver.active_vehicle_id:
        return False
    vehicle = await db.get(Vehicle, driver.active_vehicle_id)
    if not vehicle or vehicle.status != VerificationStatus.APPROVED:
        return False

    docs = await db.execute(
        select(DriverDocument).where(DriverDocument.driver_id == driver.id)
    )
    by_type = {d.doc_type: d for d in docs.scalars().all()}
    today = date.today()
    for required in REQUIRED_DOC_TYPES:
        doc = by_type.get(required)
        if not doc or doc.status != VerificationStatus.APPROVED:
            return False
        if doc.expires_on and doc.expires_on < today:
            return False
    return True


async def set_online(
    db: AsyncSession, *, driver: DriverProfile, online: bool
) -> DriverProfile:
    if online:
        if not await documents_allow_online(db, driver):
            raise ForbiddenError(
                "Cannot go online: documents/license verification incomplete or expired"
            )
        driver.online_status = DriverOnlineStatus.ONLINE
    else:
        if driver.online_status == DriverOnlineStatus.BUSY:
            raise ConflictError("Cannot go offline during an active ride")
        driver.online_status = DriverOnlineStatus.OFFLINE
    await db.flush()
    return driver


async def refresh_driver_verification(
    db: AsyncSession, driver: DriverProfile
) -> DriverProfile:
    """Recompute driver verification from documents + active vehicle.

    A driver is APPROVED only when every required document is approved
    (and not expired) *and* the active vehicle is approved. If anything is
    rejected the driver is REJECTED, otherwise PENDING.
    """
    docs = await db.execute(
        select(DriverDocument).where(DriverDocument.driver_id == driver.id)
    )
    by_type = {d.doc_type: d for d in docs.scalars().all()}
    today = date.today()

    docs_ok = True
    any_rejected = False
    for required in REQUIRED_DOC_TYPES:
        doc = by_type.get(required)
        if not doc or doc.status != VerificationStatus.APPROVED:
            docs_ok = False
        if doc and doc.status == VerificationStatus.REJECTED:
            any_rejected = True
        if doc and doc.expires_on and doc.expires_on < today:
            docs_ok = False
    if any(d.status == VerificationStatus.REJECTED for d in by_type.values()):
        any_rejected = True

    vehicle_ok = False
    if driver.active_vehicle_id:
        vehicle = await db.get(Vehicle, driver.active_vehicle_id)
        vehicle_ok = bool(vehicle and vehicle.status == VerificationStatus.APPROVED)
        if vehicle and vehicle.status == VerificationStatus.REJECTED:
            any_rejected = True

    if docs_ok and vehicle_ok:
        driver.verification_status = VerificationStatus.APPROVED
    elif any_rejected:
        driver.verification_status = VerificationStatus.REJECTED
    else:
        driver.verification_status = VerificationStatus.PENDING
    await db.flush()
    return driver


async def review_document(
    db: AsyncSession,
    *,
    document_id: str,
    reviewer_id: str,
    approve: bool,
    rejection_reason: str | None = None,
) -> DriverDocument:
    doc = await db.get(DriverDocument, document_id)
    if not doc:
        raise NotFoundError("Document not found")
    doc.status = (
        VerificationStatus.APPROVED if approve else VerificationStatus.REJECTED
    )
    doc.reviewed_by = reviewer_id
    doc.reviewed_at = datetime.now(UTC)
    doc.rejection_reason = None if approve else rejection_reason
    await db.flush()

    driver = await db.get(DriverProfile, doc.driver_id)
    if driver:
        await refresh_driver_verification(db, driver)
    return doc


async def review_vehicle(
    db: AsyncSession,
    *,
    vehicle_id: str,
    approve: bool,
) -> Vehicle:
    vehicle = await db.get(Vehicle, vehicle_id)
    if not vehicle:
        raise NotFoundError("Vehicle not found")
    vehicle.status = (
        VerificationStatus.APPROVED if approve else VerificationStatus.REJECTED
    )
    await db.flush()

    driver = await db.get(DriverProfile, vehicle.driver_id)
    if driver:
        # First approved vehicle automatically becomes the active one.
        if approve and not driver.active_vehicle_id:
            driver.active_vehicle_id = vehicle.id
        await refresh_driver_verification(db, driver)
    return vehicle
