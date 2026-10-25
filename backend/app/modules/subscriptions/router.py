"""Subscription endpoints for drivers."""

from fastapi import APIRouter, Depends

from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import UserRole
from app.modules.subscriptions import service
from app.modules.subscriptions.schemas import PauseIn, SubscribeIn, SubscriptionOut
from app.modules.trust.service import get_or_create_driver_profile

router = APIRouter(
    prefix="/subscriptions",
    tags=["subscriptions"],
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)


def _out(sub) -> SubscriptionOut:
    return SubscriptionOut(
        id=sub.id,
        driver_id=sub.driver_id,
        plan=sub.plan,
        status=sub.status,
        price=sub.price,
        currency=sub.currency,
        starts_at=sub.starts_at,
        ends_at=sub.ends_at,
        paused_at=sub.paused_at,
        pause_reason=sub.pause_reason,
    )


@router.get("/current", response_model=SubscriptionOut | None)
async def get_current(db: DbSession, user: CurrentUser) -> SubscriptionOut | None:
    driver = await get_or_create_driver_profile(db, user.id)
    sub = await service.get_active_subscription(db, driver.id)
    return _out(sub) if sub else None


@router.post("", response_model=SubscriptionOut, status_code=201)
async def subscribe(
    body: SubscribeIn,
    db: DbSession,
    user: CurrentUser,
) -> SubscriptionOut:
    driver = await get_or_create_driver_profile(db, user.id)
    sub = await service.subscribe(db, driver_id=driver.id, plan=body.plan)
    return _out(sub)


@router.post("/pause", response_model=SubscriptionOut)
async def pause(
    body: PauseIn,
    db: DbSession,
    user: CurrentUser,
) -> SubscriptionOut:
    driver = await get_or_create_driver_profile(db, user.id)
    sub = await service.pause_subscription(db, driver_id=driver.id, reason=body.reason)
    return _out(sub)


@router.post("/resume", response_model=SubscriptionOut)
async def resume(db: DbSession, user: CurrentUser) -> SubscriptionOut:
    driver = await get_or_create_driver_profile(db, user.id)
    sub = await service.resume_subscription(db, driver_id=driver.id)
    return _out(sub)


@router.post("/cancel", response_model=SubscriptionOut)
async def cancel(db: DbSession, user: CurrentUser) -> SubscriptionOut:
    driver = await get_or_create_driver_profile(db, user.id)
    sub = await service.cancel_subscription(db, driver_id=driver.id)
    return _out(sub)
