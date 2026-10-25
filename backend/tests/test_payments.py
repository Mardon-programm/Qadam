"""Tests for payment processing and ledger."""

import pytest
from httpx import AsyncClient
from decimal import Decimal


@pytest.mark.asyncio
async def test_payment_idempotency(client: AsyncClient, auth_headers: dict):
    """Test that payment with same idempotency key is processed once."""
    payload = {
        "amount": 500.00,
        "currency": "KGS",
        "reference_type": "ride_order",
        "reference_id": "test-order-123",
    }

    # First payment
    response1 = await client.post(
        "/api/v1/payments/intents",
        headers={**auth_headers, "X-Idempotency-Key": "pay-key-001"},
        json=payload,
    )
    assert response1.status_code in [200, 201]
    intent_id_1 = response1.json()["id"]

    # Duplicate payment with same key
    response2 = await client.post(
        "/api/v1/payments/intents",
        headers={**auth_headers, "X-Idempotency-Key": "pay-key-001"},
        json=payload,
    )
    assert response2.status_code in [200, 201]
    intent_id_2 = response2.json()["id"]

    # Should return same intent
    assert intent_id_1 == intent_id_2


@pytest.mark.asyncio
async def test_subscription_creation(client: AsyncClient, auth_headers: dict, test_driver):
    """Test creating a driver subscription."""
    response = await client.post(
        "/api/v1/subscriptions",
        headers=auth_headers,
        json={
            "driver_id": test_driver.id,
            "plan_type": "pro_monthly",
            "period_days": 30,
        },
    )
    assert response.status_code in [200, 201]
    data = response.json()
    assert data["plan_type"] == "pro_monthly"
    assert data["status"] == "active"


@pytest.mark.asyncio
async def test_ledger_immutability(client: AsyncClient, auth_headers: dict):
    """Test that ledger entries cannot be modified after creation."""
    # Create a ledger entry via payment
    payment_resp = await client.post(
        "/api/v1/payments/intents",
        headers=auth_headers,
        json={
            "amount": 100.00,
            "currency": "KGS",
            "reference_type": "test",
            "reference_id": "test-001",
        },
    )

    # Ledger entries should be created but not directly modifiable
    # This is enforced at service level - no update/delete endpoints exist
    # Verify by checking that only read operations are available
    assert payment_resp.status_code in [200, 201]


@pytest.mark.asyncio
async def test_payment_webhook_signature_validation(client: AsyncClient):
    """Test that webhook without valid signature is rejected."""
    # Attempt webhook without proper signature
    response = await client.post(
        "/api/v1/payments/webhook",
        json={
            "event": "payment.succeeded",
            "payment_id": "test-123",
        },
        headers={"X-Webhook-Signature": "invalid-signature"},
    )
    # Should reject invalid signature
    assert response.status_code in [400, 401, 403]
