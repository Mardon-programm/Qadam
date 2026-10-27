import asyncio
import logging
from collections.abc import AsyncGenerator

from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    """SQLAlchemy declarative base for all domain models."""


settings = get_settings()

# "primary" while the configured database answers, "sqlite-fallback" after a
# failover. Exposed by /health so a misconfigured deploy is easy to spot.
database_mode: str = "primary"
active_database_url: str = settings.database_url


def _create_engine(url: str) -> AsyncEngine:
    if url.startswith("sqlite"):
        engine = create_async_engine(url, echo=settings.app_debug)

        @event.listens_for(engine.sync_engine, "connect")
        def _set_sqlite_pragmas(dbapi_connection, _record):  # type: ignore[no-untyped-def]
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.execute("PRAGMA busy_timeout=5000")
            cursor.close()

        return engine

    return create_async_engine(
        url,
        echo=settings.app_debug,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
    )


def _create_sessionmaker(bind: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(
        bind=bind,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
    )


engine = _create_engine(active_database_url)
SessionLocal = _create_sessionmaker(engine)


async def ensure_database() -> str:
    """Verify the database is reachable, falling back to SQLite if it is not.

    Render can start the container without a working ``DATABASE_URL`` (the
    setting then points at localhost), which made every login fail with HTTP
    500. The fallback keeps login/registration usable, but its data lives in
    the container and is lost on redeploy — a real Postgres URL is still the
    production setup. Failures are logged and reported via ``/health``.
    """
    global engine, SessionLocal, active_database_url, database_mode

    try:
        async with asyncio.timeout(settings.database_connect_timeout_seconds):
            async with engine.connect() as connection:
                await connection.execute(text("SELECT 1"))
        database_mode = "primary"
        return database_mode
    except Exception as exc:
        if not settings.database_fallback_enabled:
            raise
        logger.error(
            "Database %s is unreachable (%s: %s)",
            engine.url.render_as_string(hide_password=True),
            type(exc).__name__,
            exc,
        )

    await engine.dispose()
    engine = _create_engine(settings.fallback_database_url)
    SessionLocal = _create_sessionmaker(engine)
    active_database_url = settings.fallback_database_url
    database_mode = "sqlite-fallback"

    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    logger.warning(
        "Using ephemeral SQLite fallback at %s — data is lost on redeploy. "
        "Set DATABASE_URL to a persistent Postgres database.",
        settings.fallback_database_url,
    )
    return database_mode


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
