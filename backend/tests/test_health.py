"""Smoke tests — health check and basic auth flow."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_otp_request_and_verify(client: AsyncClient):
    # Request OTP
    resp = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": "+996701000001", "role": "passenger"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["sent"] is True
    assert "debug_code" in data  # dev mode

    # Verify OTP
    resp2 = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "+996701000001", "code": data["debug_code"], "role": "passenger"},
    )
    assert resp2.status_code == 200
    tokens = resp2.json()
    assert "access_token" in tokens
    assert tokens["role"] == "passenger"


@pytest.mark.asyncio
async def test_me_authenticated(client: AsyncClient, passenger_token: str):
    resp = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert resp.status_code == 200
    me = resp.json()
    assert me["role"] == "passenger"


@pytest.mark.asyncio
async def test_me_unauthenticated(client: AsyncClient):
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_ops_stats(client: AsyncClient, ops_token: str):
    resp = await client.get(
        "/api/v1/ops/stats",
        headers={"Authorization": f"Bearer {ops_token}"},
    )
    assert resp.status_code == 200
    stats = resp.json()
    assert "total_users" in stats
