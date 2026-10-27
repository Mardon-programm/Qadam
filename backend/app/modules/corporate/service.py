"""Corporate business logic."""

from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError
from app.modules.corporate.models import CorporateAccount, CorporateMember
from app.modules.corporate.schemas import (
    CorporateAccountCreate,
    CorporateAccountUpdate,
    CorporateMemberCreate,
    CorporateMemberUpdate,
)


async def create_account(
    db: AsyncSession,
    data: CorporateAccountCreate,
) -> CorporateAccount:
    """Create corporate account."""
    account = CorporateAccount(
        legal_name=data.legal_name,
        tax_id=data.tax_id,
        monthly_budget=data.monthly_budget,
        currency=data.currency,
        status="active",
    )
    db.add(account)
    await db.commit()
    await db.refresh(account)
    return account


async def get_account(db: AsyncSession, account_id: str) -> CorporateAccount:
    """Get account by ID."""
    result = await db.execute(select(CorporateAccount).where(CorporateAccount.id == account_id))
    account = result.scalar_one_or_none()
    if not account:
        raise AppError("Corporate account not found", 404)
    return account


async def update_account(
    db: AsyncSession,
    account_id: str,
    data: CorporateAccountUpdate,
) -> CorporateAccount:
    """Update corporate account."""
    account = await get_account(db, account_id)

    if data.legal_name is not None:
        account.legal_name = data.legal_name
    if data.tax_id is not None:
        account.tax_id = data.tax_id
    if data.monthly_budget is not None:
        account.monthly_budget = data.monthly_budget
    if data.status is not None:
        account.status = data.status

    await db.commit()
    await db.refresh(account)
    return account


async def list_accounts(db: AsyncSession, skip: int = 0, limit: int = 50):
    """List corporate accounts."""
    result = await db.execute(
        select(CorporateAccount)
        .order_by(CorporateAccount.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


# ── Members ────────────────────────────────────────────────────────────────


async def add_member(
    db: AsyncSession,
    account_id: str,
    data: CorporateMemberCreate,
) -> CorporateMember:
    """Add member to corporate account."""
    # Verify account exists
    await get_account(db, account_id)

    # Check if already member
    result = await db.execute(
        select(CorporateMember).where(
            CorporateMember.account_id == account_id,
            CorporateMember.user_id == data.user_id,
        )
    )
    if result.scalar_one_or_none():
        raise AppError("User is already a member of this account", 400)

    member = CorporateMember(
        account_id=account_id,
        user_id=data.user_id,
        member_role=data.member_role,
        trip_limit=data.trip_limit,
        status="active",
    )
    db.add(member)
    await db.commit()
    await db.refresh(member)
    return member


async def update_member(
    db: AsyncSession,
    member_id: str,
    data: CorporateMemberUpdate,
) -> CorporateMember:
    """Update corporate member."""
    result = await db.execute(select(CorporateMember).where(CorporateMember.id == member_id))
    member = result.scalar_one_or_none()
    if not member:
        raise AppError("Corporate member not found", 404)

    if data.member_role is not None:
        member.member_role = data.member_role
    if data.trip_limit is not None:
        member.trip_limit = data.trip_limit
    if data.status is not None:
        member.status = data.status

    await db.commit()
    await db.refresh(member)
    return member


async def list_members(
    db: AsyncSession,
    account_id: str,
    skip: int = 0,
    limit: int = 50,
):
    """List members of corporate account."""
    result = await db.execute(
        select(CorporateMember)
        .where(CorporateMember.account_id == account_id)
        .order_by(CorporateMember.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


async def get_account_stats(db: AsyncSession, account_id: str) -> dict:
    """Get corporate account statistics."""
    await get_account(db, account_id)

    # Count members
    total_members_result = await db.execute(
        select(func.count(CorporateMember.id)).where(CorporateMember.account_id == account_id)
    )
    total_members = total_members_result.scalar() or 0

    active_members_result = await db.execute(
        select(func.count(CorporateMember.id)).where(
            CorporateMember.account_id == account_id,
            CorporateMember.status == "active",
        )
    )
    active_members = active_members_result.scalar() or 0

    # TODO: Calculate trip stats when trip linking is implemented
    return {
        "total_members": total_members,
        "active_members": active_members,
        "total_trips": 0,
        "total_spent": Decimal("0.00"),
        "budget_remaining": None,
    }
