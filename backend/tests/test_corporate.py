"""Tests for Corporate module."""

import pytest
from httpx import AsyncClient

from app.core.enums import UserRole


@pytest.mark.asyncio
async def test_create_corporate_account(client: AsyncClient, auth_headers: dict):
    """Test creating a corporate account."""
    response = await client.post(
        "/api/v1/corporate/accounts",
        headers=auth_headers,
        json={
            "legal_name": "Test Corp LLC",
            "tax_id": "123456789",
            "monthly_budget": 100000.00,
            "currency": "KGS",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["legal_name"] == "Test Corp LLC"
    assert data["tax_id"] == "123456789"
    assert data["status"] == "active"


@pytest.mark.asyncio
async def test_add_corporate_member(client: AsyncClient, auth_headers: dict, test_user):
    """Test adding a member to corporate account."""
    # Create account
    account_resp = await client.post(
        "/api/v1/corporate/accounts",
        headers=auth_headers,
        json={"legal_name": "Test Corp", "monthly_budget": 50000},
    )
    account_id = account_resp.json()["id"]

    # Add member
    response = await client.post(
        f"/api/v1/corporate/accounts/{account_id}/members",
        headers=auth_headers,
        json={
            "user_id": test_user.id,
            "member_role": "employee",
            "trip_limit": 5000.00,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["user_id"] == test_user.id
    assert data["member_role"] == "employee"
    assert data["status"] == "active"


@pytest.mark.asyncio
async def test_corporate_stats(client: AsyncClient, auth_headers: dict):
    """Test getting corporate account statistics."""
    # Create account
    account_resp = await client.post(
        "/api/v1/corporate/accounts",
        headers=auth_headers,
        json={"legal_name": "Stats Test Corp"},
    )
    account_id = account_resp.json()["id"]

    # Get stats
    response = await client.get(
        f"/api/v1/corporate/accounts/{account_id}/stats",
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert "total_members" in data
    assert "active_members" in data
    assert "total_trips" in data
    assert data["total_members"] == 0


@pytest.mark.asyncio
async def test_duplicate_member_rejected(client: AsyncClient, auth_headers: dict, test_user):
    """Test that adding the same member twice is rejected."""
    account_resp = await client.post(
        "/api/v1/corporate/accounts",
        headers=auth_headers,
        json={"legal_name": "Dup Test Corp"},
    )
    account_id = account_resp.json()["id"]

    # Add member first time
    await client.post(
        f"/api/v1/corporate/accounts/{account_id}/members",
        headers=auth_headers,
        json={"user_id": test_user.id},
    )

    # Try adding same member again
    response = await client.post(
        f"/api/v1/corporate/accounts/{account_id}/members",
        headers=auth_headers,
        json={"user_id": test_user.id},
    )
    assert response.status_code == 400
