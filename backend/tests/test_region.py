"""Region (intercity) module tests — seat reservation invariants."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_search_trips_empty(client: AsyncClient, passenger_token: str):
    resp = await client.get(
        "/api/v1/region/trips",
        params={"origin": "bishkek", "destination": "osh"},
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


@pytest.mark.asyncio
async def test_support_case_flow(client: AsyncClient, passenger_token: str):
    """Open a support case, verify it appears in my list."""
    resp = await client.post(
        "/api/v1/support",
        json={
            "case_type": "payment_issue",
            "subject": "Payment not processed",
            "description": "I was charged but ride was cancelled.",
        },
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert resp.status_code == 201
    case = resp.json()
    assert case["status"] == "open"

    # Should appear in my cases
    list_resp = await client.get(
        "/api/v1/support/my",
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert list_resp.status_code == 200
    ids = [c["id"] for c in list_resp.json()]
    assert case["id"] in ids
