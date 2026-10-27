"""Subscription service — driver plan management."""

from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import SubscriptionPlan, SubscriptionStatus
from app.core.exceptions import ConflictError, NotFoundError
from app.modules.subscriptions.models import Subscription

PLAN_PRICES: dict[str, Decimal] = {
    SubscriptionPlan.FLEX: Decimal("0.00"),  # Commission-based, no fixed fee
    SubscriptionPlan.PRO_DAILY: Decimal("100.00"),
    SubscriptionPlan.PRO_MONTHLY: Decimal("2500.00"),
}


async def get_active_subscription(db: AsyncSession, driver_id: str) -> Subscription | None:
    result = await db.execute(
        select(Subscription).where(
            and_(
                Subscription.driver_id == driver_id,
                Subscription.status == SubscriptionStatus.ACTIVE,
            )
        )
    )
    return result.scalar_one_or_none()


async def subscribe(
    db: AsyncSession,
    *,
    driver_id: str,
    plan: str,
) -> Subscription:
    if plan not in {p.value for p in SubscriptionPlan}:
        raise ConflictError(f"Unknown plan: {plan}")

    existing = await get_active_subscription(db, driver_id)
    if existing:
        raise ConflictError("Driver already has an active subscription")

    now = datetime.now(UTC)
    ends_at: datetime | None = None
    if plan == SubscriptionPlan.PRO_DAILY:
        ends_at = now + timedelta(days=1)
    elif plan == SubscriptionPlan.PRO_MONTHLY:
        ends_at = now + timedelta(days=30)

    sub = Subscription(
        driver_id=driver_id,
        plan=plan,
        status=SubscriptionStatus.ACTIVE,
        price=PLAN_PRICES[plan],
        starts_at=now,
        ends_at=ends_at,
    )
    db.add(sub)
    await db.flush()
    return sub


async def pause_subscription(
    db: AsyncSession,
    *,
    driver_id: str,
    reason: str = "driver_request",
) -> Subscription:
    sub = await get_active_subscription(db, driver_id)
    if not sub:
        raise NotFoundError("No active subscription found")
    sub.status = SubscriptionStatus.PAUSED
    sub.paused_at = datetime.now(UTC)
    sub.pause_reason = reason
    await db.flush()
    return sub


async def resume_subscription(
    db: AsyncSession,
    *,
    driver_id: str,
) -> Subscription:
    result = await db.execute(
        select(Subscription).where(
            and_(
                Subscription.driver_id == driver_id,
                Subscription.status == SubscriptionStatus.PAUSED,
            )
        )
    )
    sub = result.scalar_one_or_none()
    if not sub:
        raise NotFoundError("No paused subscription found")
    sub.status = SubscriptionStatus.ACTIVE
    sub.paused_at = None
    sub.pause_reason = None
    await db.flush()
    return sub


async def cancel_subscription(
    db: AsyncSession,
    *,
    driver_id: str,
) -> Subscription:
    result = await db.execute(
        select(Subscription).where(
            and_(
                Subscription.driver_id == driver_id,
                Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.PAUSED]),
            )
        )
    )
    sub = result.scalar_one_or_none()
    if not sub:
        raise NotFoundError("No active subscription to cancel")
    sub.status = SubscriptionStatus.CANCELLED
    await db.flush()
    return sub
