"""Corporate API endpoints."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.modules.corporate import service
from app.modules.corporate.schemas import (
    CorporateAccountCreate,
    CorporateAccountResponse,
    CorporateAccountUpdate,
    CorporateMemberCreate,
    CorporateMemberResponse,
    CorporateMemberUpdate,
    CorporateStatsResponse,
)
from app.modules.identity.models import User

router = APIRouter(prefix="/corporate", tags=["corporate"])


# ── Accounts ───────────────────────────────────────────────────────────────


@router.post("/accounts", response_model=CorporateAccountResponse, status_code=201)
async def create_corporate_account(
    data: CorporateAccountCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new corporate account."""
    account = await service.create_account(db, data)
    return account


@router.get("/accounts/{account_id}", response_model=CorporateAccountResponse)
async def get_corporate_account(
    account_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get corporate account details."""
    account = await service.get_account(db, account_id)
    return account


@router.patch("/accounts/{account_id}", response_model=CorporateAccountResponse)
async def update_corporate_account(
    account_id: str,
    data: CorporateAccountUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update corporate account."""
    account = await service.update_account(db, account_id, data)
    return account


@router.get("/accounts", response_model=list[CorporateAccountResponse])
async def list_corporate_accounts(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List corporate accounts."""
    accounts = await service.list_accounts(db, skip, limit)
    return accounts


# ── Members ────────────────────────────────────────────────────────────────


@router.post(
    "/accounts/{account_id}/members",
    response_model=CorporateMemberResponse,
    status_code=201,
)
async def add_corporate_member(
    account_id: str,
    data: CorporateMemberCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add a member to corporate account."""
    member = await service.add_member(db, account_id, data)
    return member


@router.patch("/members/{member_id}", response_model=CorporateMemberResponse)
async def update_corporate_member(
    member_id: str,
    data: CorporateMemberUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update corporate member."""
    member = await service.update_member(db, member_id, data)
    return member


@router.get(
    "/accounts/{account_id}/members",
    response_model=list[CorporateMemberResponse],
)
async def list_corporate_members(
    account_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List members of corporate account."""
    members = await service.list_members(db, account_id, skip, limit)
    return members


# ── Statistics ─────────────────────────────────────────────────────────────


@router.get("/accounts/{account_id}/stats", response_model=CorporateStatsResponse)
async def get_corporate_stats(
    account_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get corporate account statistics."""
    stats = await service.get_account_stats(db, account_id)
    return stats
