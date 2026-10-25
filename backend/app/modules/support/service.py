"""Support case service."""

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import SupportCaseStatus
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.modules.support.models import SupportCase


async def open_case(
    db: AsyncSession,
    *,
    user_id: str,
    case_type: str,
    subject: str,
    description: str,
    reference_type: str | None = None,
    reference_id: str | None = None,
) -> SupportCase:
    case = SupportCase(
        user_id=user_id,
        case_type=case_type,
        status=SupportCaseStatus.OPEN,
        subject=subject,
        description=description,
        reference_type=reference_type,
        reference_id=reference_id,
    )
    db.add(case)
    await db.flush()
    return case


async def assign_case(
    db: AsyncSession,
    *,
    case_id: str,
    assignee_id: str,
) -> SupportCase:
    case = await db.get(SupportCase, case_id)
    if not case:
        raise NotFoundError("Case not found")
    if case.status in {SupportCaseStatus.RESOLVED, SupportCaseStatus.CLOSED}:
        raise ConflictError("Case is already closed")
    case.assignee_id = assignee_id
    case.status = SupportCaseStatus.IN_PROGRESS
    await db.flush()
    return case


async def resolve_case(
    db: AsyncSession,
    *,
    case_id: str,
    resolution: str,
    assignee_id: str | None = None,
) -> SupportCase:
    case = await db.get(SupportCase, case_id)
    if not case:
        raise NotFoundError("Case not found")
    if case.status == SupportCaseStatus.CLOSED:
        raise ConflictError("Case is already closed")
    case.status = SupportCaseStatus.RESOLVED
    case.resolution = resolution
    if assignee_id:
        case.assignee_id = assignee_id
    await db.flush()
    return case


async def close_case(db: AsyncSession, case_id: str) -> SupportCase:
    case = await db.get(SupportCase, case_id)
    if not case:
        raise NotFoundError("Case not found")
    case.status = SupportCaseStatus.CLOSED
    await db.flush()
    return case


async def list_cases(
    db: AsyncSession,
    *,
    user_id: str | None = None,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[SupportCase]:
    stmt = select(SupportCase)
    if user_id:
        stmt = stmt.where(SupportCase.user_id == user_id)
    if status:
        stmt = stmt.where(SupportCase.status == status)
    stmt = stmt.order_by(SupportCase.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(stmt)
    return list(result.scalars().all())
