"""Corporate schemas for request/response validation."""

from decimal import Decimal

from pydantic import BaseModel, Field


# ── Account schemas ────────────────────────────────────────────────────────


class CorporateAccountCreate(BaseModel):
    legal_name: str = Field(..., min_length=1, max_length=255)
    tax_id: str | None = Field(None, max_length=64)
    monthly_budget: Decimal | None = None
    currency: str = Field(default="KGS", max_length=8)


class CorporateAccountUpdate(BaseModel):
    legal_name: str | None = Field(None, min_length=1, max_length=255)
    tax_id: str | None = None
    monthly_budget: Decimal | None = None
    status: str | None = Field(None, max_length=32)


class CorporateAccountResponse(BaseModel):
    id: str
    legal_name: str
    tax_id: str | None
    status: str
    monthly_budget: Decimal | None
    currency: str
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}


# ── Member schemas ─────────────────────────────────────────────────────────


class CorporateMemberCreate(BaseModel):
    user_id: str
    member_role: str = Field(default="employee", max_length=32)
    trip_limit: Decimal | None = None


class CorporateMemberUpdate(BaseModel):
    member_role: str | None = Field(None, max_length=32)
    trip_limit: Decimal | None = None
    status: str | None = Field(None, max_length=32)


class CorporateMemberResponse(BaseModel):
    id: str
    account_id: str
    user_id: str
    member_role: str
    trip_limit: Decimal | None
    status: str
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}


# ── Stats schemas ──────────────────────────────────────────────────────────


class CorporateStatsResponse(BaseModel):
    total_members: int
    active_members: int
    total_trips: int
    total_spent: Decimal
    budget_remaining: Decimal | None
