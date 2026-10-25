"""Support case endpoints."""

from fastapi import APIRouter, Depends, Query

from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import UserRole
from app.core.exceptions import NotFoundError
from app.modules.support import service
from app.modules.support.schemas import ResolveIn, SupportCaseIn, SupportCaseOut

router = APIRouter(prefix="/support", tags=["support"])


def _out(c) -> SupportCaseOut:
    return SupportCaseOut(
        id=c.id,
        user_id=c.user_id,
        case_type=c.case_type,
        status=c.status,
        subject=c.subject,
        description=c.description,
        reference_type=c.reference_type,
        reference_id=c.reference_id,
        assignee_id=c.assignee_id,
        resolution=c.resolution,
    )


@router.post("", response_model=SupportCaseOut, status_code=201)
async def open_case(
    body: SupportCaseIn,
    db: DbSession,
    user: CurrentUser,
) -> SupportCaseOut:
    case = await service.open_case(
        db,
        user_id=user.id,
        case_type=body.case_type,
        subject=body.subject,
        description=body.description,
        reference_type=body.reference_type,
        reference_id=body.reference_id,
    )
    return _out(case)


@router.get("/my", response_model=list[SupportCaseOut])
async def my_cases(
    db: DbSession,
    user: CurrentUser,
    status: str | None = Query(default=None),
) -> list[SupportCaseOut]:
    cases = await service.list_cases(db, user_id=user.id, status=status)
    return [_out(c) for c in cases]


@router.get(
    "",
    response_model=list[SupportCaseOut],
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def list_all_cases(
    db: DbSession,
    status: str | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[SupportCaseOut]:
    cases = await service.list_cases(db, status=status, limit=limit, offset=offset)
    return [_out(c) for c in cases]


@router.post(
    "/{case_id}/resolve",
    response_model=SupportCaseOut,
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def resolve(
    case_id: str,
    body: ResolveIn,
    db: DbSession,
    user: CurrentUser,
) -> SupportCaseOut:
    case = await service.resolve_case(
        db,
        case_id=case_id,
        resolution=body.resolution,
        assignee_id=body.assignee_id or user.id,
    )
    return _out(case)


@router.post(
    "/{case_id}/close",
    response_model=SupportCaseOut,
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def close(case_id: str, db: DbSession) -> SupportCaseOut:
    case = await service.close_case(db, case_id)
    return _out(case)
