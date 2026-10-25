"""City (ride) module tests — quote, create ride, cancel."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_quote_no_auth(client: AsyncClient):
    """Price quote endpoint is public."""
    resp = await client.post(
        "/api/v1/city/quote",
        json={
            "pickup_address": "Bishkek, ул. Чуй 1",
            "pickup_lat": 42.871,
            "pickup_lng": 74.591,
            "dropoff_address": "Bishkek, ул. Манаса 40",
            "dropoff_lat": 42.882,
            "dropoff_lng": 74.612,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert float(data["quoted_price"]) >= 80  # min fare
    assert data["currency"] == "KGS"
    assert float(data["surge_multiplier"]) == 1.0


@pytest.mark.asyncio
async def test_create_ride_as_passenger(client: AsyncClient, passenger_token: str):
    resp = await client.post(
        "/api/v1/city/rides",
        json={
            "pickup_address": "Bishkek, ул. Чуй 1",
            "pickup_lat": 42.871,
            "pickup_lng": 74.591,
            "dropoff_address": "Bishkek, ЦГПБ",
            "dropoff_lat": 42.882,
            "dropoff_lng": 74.612,
        },
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert resp.status_code == 200
    ride = resp.json()
    assert ride["status"] in {"searching", "offered"}
    assert ride["quoted_price"] is not None
    return ride["id"]


@pytest.mark.asyncio
async def test_create_ride_duplicate_idempotency(client: AsyncClient, passenger_token: str):
    payload = {
        "pickup_address": "A",
        "pickup_lat": 42.87,
        "pickup_lng": 74.59,
        "dropoff_address": "B",
        "dropoff_lat": 42.88,
        "dropoff_lng": 74.61,
        "idempotency_key": "test-idem-key-001",
    }
    resp1 = await client.post(
        "/api/v1/city/rides",
        json=payload,
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    resp2 = await client.post(
        "/api/v1/city/rides",
        json=payload,
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert resp1.status_code == 200
    assert resp2.status_code == 200
    assert resp1.json()["id"] == resp2.json()["id"]


@pytest.mark.asyncio
async def test_cancel_ride(client: AsyncClient, passenger_token: str):
    # Create a ride first
    resp = await client.post(
        "/api/v1/city/rides",
        json={
            "pickup_address": "A",
            "pickup_lat": 42.87,
            "pickup_lng": 74.59,
            "dropoff_address": "B",
            "dropoff_lat": 42.88,
            "dropoff_lng": 74.61,
        },
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    ride_id = resp.json()["id"]

    # Cancel it
    cancel_resp = await client.post(
        f"/api/v1/city/rides/{ride_id}/cancel",
        json={"reason": "changed_mind"},
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "cancelled"
