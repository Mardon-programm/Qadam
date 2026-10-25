"""Reporting service — financial and operational summaries.

Used by:
  - Ops panel for platform-wide P&L snapshots
  - Corporate accounts for their own spend reports
  - Driver wallet history
"""

from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import LedgerDirection, RideOrderStatus
from app.modules.city.models import RideOrder
from app.modules.ledger.models import LedgerEntry, Payout
from app.modules.region.models import Booking


async def driver_earnings_summary(
    db: AsyncSession,
    *,
    driver_id: str,
    days: int = 30,
) -> dict:
    """Return earnings, fees, payouts, and net balance for a driver."""
    since = datetime.now(UTC) - timedelta(days=days)
    account_id = f"driver:{driver_id}"

    result = await db.execute(
        select(LedgerEntry).where(
            and_(
                LedgerEntry.account_id == account_id,
                LedgerEntry.created_at >= since,
            )
        )
    )
    entries = list(result.scalars().all())

    earned = sum(e.amount for e in entries if e.direction == LedgerDirection.CREDIT)
    debited = sum(e.amount for e in entries if e.direction == LedgerDirection.DEBIT)

    # Payouts in the period
    payout_result = await db.execute(
        select(func.sum(Payout.amount)).where(
            and_(
                Payout.driver_id == driver_id,
                Payout.status == "succeeded",
                Payout.created_at >= since,
            )
        )
    )
    paid_out = payout_result.scalar_one_or_none() or Decimal("0.00")

    return {
        "driver_id": driver_id,
        "period_days": days,
        "gross_earned": earned,
        "debited": debited,
        "net_balance": earned - debited,
        "paid_out": paid_out,
        "available_for_payout": earned - debited - paid_out,
        "currency": "KGS",
    }


async def platform_revenue_summary(
    db: AsyncSession,
    *,
    days: int = 30,
) -> dict:
    """Platform fee credits in the period (gross revenue proxy)."""
    since = datetime.now(UTC) - timedelta(days=days)
    result = await db.execute(
        select(func.sum(LedgerEntry.amount)).where(
            and_(
                LedgerEntry.account_id == "platform:fees",
                LedgerEntry.direction == LedgerDirection.CREDIT,
                LedgerEntry.created_at >= since,
            )
        )
    )
    revenue = result.scalar_one_or_none() or Decimal("0.00")

    ride_count = (
        await db.execute(
            select(func.count(RideOrder.id)).where(
                and_(
                    RideOrder.status == RideOrderStatus.COMPLETED,
                    RideOrder.completed_at >= since,
                )
            )
        )
    ).scalar_one()

    return {
        "period_days": days,
        "platform_fee_revenue": revenue,
        "completed_rides": ride_count,
        "currency": "KGS",
    }


async def corporate_spend_report(
    db: AsyncSession,
    *,
    account_id: str,
    days: int = 30,
) -> dict:
    """Spend summary for a corporate account — based on completed bookings
    and ride orders linked to corporate members."""
    since = datetime.now(UTC) - timedelta(days=days)

    # Bookings by corporate members (simplistic: look at ledger entries for
    # passengers who are corporate members — refined once corporate_members
    # table is joined)
    result = await db.execute(
        select(func.sum(Booking.total_price)).where(
            and_(
                Booking.status == "completed",
                Booking.created_at >= since,
            )
        )
    )
    booking_spend = result.scalar_one_or_none() or Decimal("0.00")

    return {
        "account_id": account_id,
        "period_days": days,
        "booking_spend": booking_spend,
        "currency": "KGS",
    }
