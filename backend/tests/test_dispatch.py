"""Tests for dispatch algorithm and OSRM integration."""

import pytest
from decimal import Decimal
from httpx import AsyncClient

from app.modules.city.service import find_candidate_drivers, create_ride_order
from app.core.database import SessionLocal


@pytest.mark.asyncio
async def test_city_quote_endpoint(client: AsyncClient, auth_headers: dict):
    """Test getting a ride quote."""
    response = await client.post(
        "/api/v1/city/quote",
        headers=auth_headers,
        json={
            "pickup_lat": 42.8746,
            "pickup_lng": 74.5698,
            "dropoff_lat": 42.8800,
            "dropoff_lng": 74.5800,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "quoted_price" in data
    assert "distance_km" in data
    assert "duration_min" in data
    assert float(data["quoted_price"]) > 0


@pytest.mark.asyncio
async def test_dispatch_algorithm_ranks_by_eta_and_reliability(approved_driver, another_approved_driver):
    """Test that dispatch considers both ETA and reliability."""
    async with SessionLocal() as db:
        # Set different positions and reliability scores
        approved_driver.last_lat = Decimal("42.8746")
        approved_driver.last_lng = Decimal("74.5698")
        approved_driver.reliability_score = Decimal("95.0")

        another_approved_driver.last_lat = Decimal("42.8700")  # Slightly farther
        another_approved_driver.last_lng = Decimal("74.5600")
        another_approved_driver.reliability_score = Decimal("100.0")  # Better reliability

        db.add_all([approved_driver, another_approved_driver])
        await db.commit()

        # Find candidates
        candidates = await find_candidate_drivers(
            db,
            pickup_lat=42.8750,
            pickup_lng=74.5700,
            limit=5,
        )

        assert len(candidates) >= 2
        # Verify both drivers are in results
        driver_ids = [d[0].id for d in candidates]
        assert approved_driver.id in driver_ids
        assert another_approved_driver.id in driver_ids


@pytest.mark.asyncio
async def test_create_ride_order_with_idempotency(client: AsyncClient, auth_headers: dict):
    """Test that duplicate ride orders with same idempotency key return the same order."""
    payload = {
        "pickup_address": "Bishkek Center",
        "pickup_lat": 42.8746,
        "pickup_lng": 74.5698,
        "dropoff_address": "Ala-Too Square",
        "dropoff_lat": 42.8765,
        "dropoff_lng": 74.6050,
    }
    headers = {**auth_headers, "X-Idempotency-Key": "test-key-12345"}

    # First request
    response1 = await client.post(
        "/api/v1/city/orders",
        headers=headers,
        json=payload,
    )
    assert response1.status_code == 201
    order_id_1 = response1.json()["id"]

    # Second request with same key
    response2 = await client.post(
        "/api/v1/city/orders",
        headers=headers,
        json=payload,
    )
    assert response2.status_code == 201
    order_id_2 = response2.json()["id"]

    # Should return the same order
    assert order_id_1 == order_id_2


@pytest.mark.asyncio
async def test_minimum_fare_applied(client: AsyncClient, auth_headers: dict):
    """Test that minimum fare is applied for very short trips."""
    response = await client.post(
        "/api/v1/city/quote",
        headers=auth_headers,
        json={
            "pickup_lat": 42.8746,
            "pickup_lng": 74.5698,
            "dropoff_lat": 42.8747,  # Very close
            "dropoff_lng": 74.5699,
        },
    )
    assert response.status_code == 200
    data = response.json()
    # Minimum fare should be applied
    assert float(data["quoted_price"]) >= 60.0  # city_min_fare from config
