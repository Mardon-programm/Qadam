"""Trust module tests — driver profile, vehicle, documents."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_driver_profile_created_on_first_access(
    client: AsyncClient, driver_token: str
):
    resp = await client.get(
        "/api/v1/driver/profile",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert resp.status_code == 200
    profile = resp.json()
    assert profile["verification_status"] == "draft"
    assert profile["online_status"] == "offline"


@pytest.mark.asyncio
async def test_add_vehicle(client: AsyncClient, driver_token: str):
    resp = await client.post(
        "/api/v1/driver/vehicles",
        json={
            "make": "Toyota",
            "model": "Camry",
            "color": "White",
            "plate_number": "B001AA",
            "year": 2020,
            "seats": 4,
        },
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert resp.status_code == 201
    v = resp.json()
    assert v["plate_number"] == "B001AA"
    assert v["status"] == "pending"


@pytest.mark.asyncio
async def test_upload_document(client: AsyncClient, driver_token: str):
    resp = await client.post(
        "/api/v1/driver/documents",
        json={
            "doc_type": "driver_license",
            "document_number": "KG-123456",
            "expires_on": "2027-12-31",
        },
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert resp.status_code == 201
    doc = resp.json()
    assert doc["doc_type"] == "driver_license"
    assert doc["status"] == "pending"


@pytest.mark.asyncio
async def test_cannot_go_online_without_verification(
    client: AsyncClient, driver_token: str
):
    resp = await client.post(
        "/api/v1/driver/online",
        json={"online": True},
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert resp.status_code == 403
