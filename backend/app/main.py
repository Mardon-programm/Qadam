"""Qadam FastAPI application entry point."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.core.exceptions import AppError
from app.core.redis import close_redis, get_redis


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Startup
    from app.core.database import ensure_database

    await ensure_database()
    await get_redis()
    yield
    # Shutdown
    await close_redis()
    from app.core.osrm import close_osrm

    await close_osrm()


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description="Qadam transport platform API",
        docs_url="/docs" if settings.is_dev else None,
        redoc_url="/redoc" if settings.is_dev else None,
        lifespan=lifespan,
    )

    # ── CORS ──────────────────────────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Global exception handler ───────────────────────────────────────────────
    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=exc.detail)

    # ── Routers ────────────────────────────────────────────────────────────────
    from app.modules.city.router import router as city_router
    from app.modules.corporate.router import router as corporate_router
    from app.modules.identity.router import router as identity_router
    from app.modules.ops.router import router as ops_router
    from app.modules.payments.router import router as payments_router
    from app.modules.region.router import router as region_router
    from app.modules.subscriptions.router import router as subscriptions_router
    from app.modules.support.router import router as support_router
    from app.modules.trust.router import ops_router as trust_ops_router
    from app.modules.trust.router import router as trust_router

    api_prefix = "/api/v1"
    app.include_router(identity_router, prefix=api_prefix)
    app.include_router(city_router, prefix=api_prefix)
    app.include_router(trust_router, prefix=api_prefix)
    app.include_router(trust_ops_router, prefix=api_prefix)
    app.include_router(region_router, prefix=api_prefix)
    app.include_router(subscriptions_router, prefix=api_prefix)
    app.include_router(support_router, prefix=api_prefix)
    app.include_router(payments_router, prefix=api_prefix)
    app.include_router(ops_router, prefix=api_prefix)
    app.include_router(corporate_router, prefix=api_prefix)

    # ── Health check ───────────────────────────────────────────────────────────
    @app.get("/health", tags=["health"])
    async def health() -> dict:
        from app.core.database import database_mode

        return {
            "status": "ok",
            "service": settings.app_name,
            "database": database_mode,
        }

    return app


app = create_app()
