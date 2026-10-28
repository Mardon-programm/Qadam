"""Pytest configuration and fixtures for Qadam backend tests."""

import os
from collections.abc import AsyncGenerator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

# Point tests at the dev database (already migrated via alembic) before importing app
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://qadam:qadam_dev_password@localhost:5433/qadam",
)
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
os.environ.setdefault("SECRET_KEY", "test-only-secret-key-at-least-32-chars!")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("PAYMENT_PROVIDER", "mock")
os.environ.setdefault("SMS_PROVIDER", "console")
# Keep unit tests offline: routing falls back to the deterministic estimator.
os.environ.setdefault("OSRM_URL", "http://127.0.0.1:9")

from app.core.database import Base, engine, SessionLocal  # noqa: E402
import app.core.redis as redis_module  # noqa: E402
from app.core.redis import get_redis, close_redis  # noqa: E402
from app.main import app  # noqa: E402


TABLES = [
    "audit_events",
    "corporate_members",
    "corporate_accounts",
    "support_cases",
    "subscriptions",
    "payouts",
    "ledger_entries",
    "payment_events",
    "payments",
    "bookings",
    "trip_seats",
    "intercity_trips",
    "ride_offers",
    "ride_orders",
    "driver_documents",
    "vehicles",
    "driver_profiles",
    "refresh_sessions",
    "users",
]


@pytest_asyncio.fixture(autouse=True)
async def isolate_tests():
    """Clean Redis and all data tables before each test; reset redis singleton
    so each test gets a fresh connection bound to its own event loop."""
    # Reset singleton so a new connection is created for this test's loop
    redis_module._redis = None
    redis = await get_redis()
    await redis.flushdb()

    async with engine.begin() as conn:
        await conn.execute(text("TRUNCATE " + ", ".join(TABLES) + " RESTART IDENTITY CASCADE"))
    yield
    await close_redis()
    redis_module._redis = None


@pytest_asyncio.fixture()
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as c:
        yield c


@pytest_asyncio.fixture()
async def ops_token(client: AsyncClient) -> str:
    """Bootstrap an OPS token using the configured bootstrap phone."""
    resp = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": "+996700000001", "role": "ops"},
    )
    assert resp.status_code == 200, resp.text
    code = resp.json()["debug_code"]

    resp = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "+996700000001", "code": code, "role": "ops"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]


@pytest_asyncio.fixture()
async def passenger_token(client: AsyncClient) -> str:
    resp = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": "+996700111111", "role": "passenger"},
    )
    assert resp.status_code == 200, resp.text
    code = resp.json()["debug_code"]
    resp = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "+996700111111", "code": code, "role": "passenger"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]


@pytest_asyncio.fixture()
async def driver_token(client: AsyncClient) -> str:
    resp = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": "+996700222222", "role": "driver"},
    )
    assert resp.status_code == 200, resp.text
    code = resp.json()["debug_code"]
    resp = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "+996700222222", "code": code, "role": "driver"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]


@pytest_asyncio.fixture()
async def auth_headers(client: AsyncClient, passenger_token: str) -> dict:
    """Authorization header for the default passenger test account."""
    return {"Authorization": f"Bearer {passenger_token}"}


@pytest_asyncio.fixture()
async def test_user(client: AsyncClient, passenger_token: str):
    """The passenger row created by the passenger_token fixture."""
    from sqlalchemy import select

    from app.modules.identity.models import User

    async with SessionLocal() as db:
        result = await db.execute(select(User).where(User.phone == "+996700111111"))
        return result.scalar_one()
