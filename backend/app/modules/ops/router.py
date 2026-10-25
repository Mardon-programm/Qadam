"""Ops (internal) panel endpoints.

All routes require OPS role. Covers:
  - User management (list, block/unblock)
  - Driver overview and document queue
  - Ride and booking monitoring
  - Audit log viewer
  - Platform statistics dashboard
  - Ledger / financial snapshot
"""

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import (
    DriverOnlineStatus,
    RideOrderStatus,
    SupportCaseStatus,
    UserRole,
    UserStatus,
    VerificationStatus,
)
from app.core.exceptions import NotFoundError
from app.modules.city.models import RideOrder
from app.modules.identity.models import AuditEvent, User
from app.modules.identity.service import write_audit
from app.modules.ledger.service import wallet_balance
from app.modules.ops.schemas import (
    AuditEventOut,
    BlockUserIn,
    DriverSummary,
    PlatformStatsOut,
    RideSummary,
    UserSummary,
)
from app.modules.region.models import Booking
from app.modules.support.models import SupportCase
from app.modules.trust.models import DriverDocument, DriverProfile

router = APIRouter(
    prefix="/ops",
    tags=["ops"],
    dependencies=[Depends(require_roles(UserRole.OPS))],
)


# ── Users ──────────────────────────────────────────────────────────────────────


@router.get("/users", response_model=list[UserSummary])
async def list_users(
    db: DbSession,
    role: str | None = Query(default=None),
    status: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[UserSummary]:
    stmt = select(User)
    if role:
        stmt = stmt.where(User.role == role)
    if status:
        stmt = stmt.where(User.status == status)
    stmt = stmt.order_by(User.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return [_user_summary(u) for u in result.scalars().all()]


@router.get("/users/{user_id}", response_model=UserSummary)
async def get_user(user_id: str, db: DbSession) -> UserSummary:
    user = await db.get(User, user_id)
    if not user:
        raise NotFoundError("User not found")
    return _user_summary(user)


@router.post("/users/{user_id}/block", response_model=UserSummary)
async def block_user(
    user_id: str,
    body: BlockUserIn,
    db: DbSession,
    current: CurrentUser,
) -> UserSummary:
    user = await db.get(User, user_id)
    if not user:
        raise NotFoundError("User not found")
    user.status = UserStatus.BLOCKED
    await db.flush()
    await write_audit(
        db,
        actor_id=current.id,
        actor_role=current.role,
        action="ops.user.block",
        object_type="user",
        object_id=user_id,
        meta_json=f'{{"reason":"{body.reason}"}}',
    )
    return _user_summary(user)


@router.post("/users/{user_id}/unblock", response_model=UserSummary)
async def unblock_user(
    user_id: str,
    db: DbSession,
    current: CurrentUser,
) -> UserSummary:
    user = await db.get(User, user_id)
    if not user:
        raise NotFoundError("User not found")
    user.status = UserStatus.ACTIVE
    await db.flush()
    await write_audit(
        db,
        actor_id=current.id,
        actor_role=current.role,
        action="ops.user.unblock",
        object_type="user",
        object_id=user_id,
    )
    return _user_summary(user)


# ── Drivers ────────────────────────────────────────────────────────────────────


@router.get("/drivers", response_model=list[DriverSummary])
async def list_drivers(
    db: DbSession,
    verification_status: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[DriverSummary]:
    stmt = select(DriverProfile)
    if verification_status:
        stmt = stmt.where(DriverProfile.verification_status == verification_status)
    stmt = stmt.order_by(DriverProfile.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return [_driver_summary(d) for d in result.scalars().all()]


@router.get("/drivers/pending-docs", response_model=list[DriverSummary])
async def pending_doc_review(db: DbSession) -> list[DriverSummary]:
    """Drivers with at least one document in PENDING review state."""
    subq = (
        select(DriverDocument.driver_id)
        .where(DriverDocument.status == VerificationStatus.PENDING)
        .distinct()
        .scalar_subquery()
    )
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.id.in_(subq))
    )
    return [_driver_summary(d) for d in result.scalars().all()]


# ── Rides ──────────────────────────────────────────────────────────────────────


@router.get("/rides", response_model=list[RideSummary])
async def list_rides(
    db: DbSession,
    status: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[RideSummary]:
    stmt = select(RideOrder)
    if status:
        stmt = stmt.where(RideOrder.status == status)
    stmt = stmt.order_by(RideOrder.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return [_ride_summary(r) for r in result.scalars().all()]


# ── Bookings ───────────────────────────────────────────────────────────────────


@router.get("/bookings")
async def list_bookings(
    db: DbSession,
    status: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[dict]:
    stmt = select(Booking)
    if status:
        stmt = stmt.where(Booking.status == status)
    stmt = stmt.order_by(Booking.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return [
        {
            "id": b.id,
            "passenger_id": b.passenger_id,
            "trip_id": b.trip_id,
            "status": b.status,
            "total_price": b.total_price,
            "currency": b.currency,
            "created_at": b.created_at,
        }
        for b in result.scalars().all()
    ]


# ── Audit log ──────────────────────────────────────────────────────────────────


@router.get("/audit", response_model=list[AuditEventOut])
async def audit_log(
    db: DbSession,
    actor_id: str | None = Query(default=None),
    object_type: str | None = Query(default=None),
    action: str | None = Query(default=None),
    limit: int = Query(default=100, le=500),
    offset: int = Query(default=0, ge=0),
) -> list[AuditEventOut]:
    stmt = select(AuditEvent)
    if actor_id:
        stmt = stmt.where(AuditEvent.actor_id == actor_id)
    if object_type:
        stmt = stmt.where(AuditEvent.object_type == object_type)
    if action:
        stmt = stmt.where(AuditEvent.action == action)
    stmt = stmt.order_by(AuditEvent.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return [_audit_out(e) for e in result.scalars().all()]


# ── Platform stats ─────────────────────────────────────────────────────────────


@router.get("/stats", response_model=PlatformStatsOut)
async def platform_stats(db: DbSession) -> PlatformStatsOut:
    today_start = datetime.now(UTC).replace(hour=0, minute=0, second=0, microsecond=0)

    total_users = (await db.execute(select(func.count(User.id)))).scalar_one()
    total_drivers = (await db.execute(select(func.count(DriverProfile.id)))).scalar_one()
    active_online = (
        await db.execute(
            select(func.count(DriverProfile.id)).where(
                DriverProfile.online_status == DriverOnlineStatus.ONLINE
            )
        )
    ).scalar_one()
    rides_today = (
        await db.execute(
            select(func.count(RideOrder.id)).where(
                RideOrder.created_at >= today_start
            )
        )
    ).scalar_one()
    bookings_today = (
        await db.execute(
            select(func.count(Booking.id)).where(Booking.created_at >= today_start)
        )
    ).scalar_one()
    open_cases = (
        await db.execute(
            select(func.count(SupportCase.id)).where(
                SupportCase.status.in_(
                    [SupportCaseStatus.OPEN, SupportCaseStatus.IN_PROGRESS]
                )
            )
        )
    ).scalar_one()

    return PlatformStatsOut(
        total_users=total_users,
        total_drivers=total_drivers,
        active_drivers_online=active_online,
        rides_today=rides_today,
        bookings_today=bookings_today,
        open_support_cases=open_cases,
    )


# ── Financial snapshot ─────────────────────────────────────────────────────────


@router.get("/finance/platform-balance")
async def platform_balance(db: DbSession) -> dict:
    balance = await wallet_balance(db, "platform:fees")
    return {"account_id": "platform:fees", "balance": balance, "currency": "KGS"}


# ── Helpers ────────────────────────────────────────────────────────────────────


def _user_summary(u: User) -> UserSummary:
    return UserSummary(
        id=u.id,
        phone=u.phone,
        full_name=u.full_name,
        role=u.role,
        status=u.status,
        created_at=u.created_at,
    )


def _driver_summary(d: DriverProfile) -> DriverSummary:
    return DriverSummary(
        id=d.id,
        user_id=d.user_id,
        verification_status=d.verification_status,
        online_status=d.online_status,
        rating=d.rating,
        reliability_score=d.reliability_score,
        can_accept_corporate=d.can_accept_corporate,
    )


def _ride_summary(r: RideOrder) -> RideSummary:
    return RideSummary(
        id=r.id,
        passenger_id=r.passenger_id,
        driver_id=r.driver_id,
        status=r.status,
        city=r.city,
        quoted_price=r.quoted_price,
        final_price=r.final_price,
        created_at=r.created_at,
    )


def _audit_out(e: AuditEvent) -> AuditEventOut:
    return AuditEventOut(
        id=e.id,
        actor_id=e.actor_id,
        actor_role=e.actor_role,
        action=e.action,
        object_type=e.object_type,
        object_id=e.object_id,
        ip_address=e.ip_address,
        created_at=e.created_at,
    )


# ── Reporting ──────────────────────────────────────────────────────────────────


@router.get("/reports/revenue")
async def revenue_report(
    db: DbSession,
    days: int = 30,
) -> dict:
    from app.modules.reporting.service import platform_revenue_summary
    return await platform_revenue_summary(db, days=days)


@router.get("/reports/driver/{driver_id}/earnings")
async def driver_earnings(
    driver_id: str,
    db: DbSession,
    days: int = 30,
) -> dict:
    from app.modules.reporting.service import driver_earnings_summary
    return await driver_earnings_summary(db, driver_id=driver_id, days=days)
