from fastapi import APIRouter, Request

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession, RedisDep
from app.modules.identity import otp, service
from app.modules.identity.schemas import (
    LoginDriverIn,
    MeOut,
    OTPRequestIn,
    OTPRequestOut,
    OTPVerifyIn,
    RegisterDriverIn,
    RefreshIn,
    TokenOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/otp/request", response_model=OTPRequestOut)
async def request_otp(body: OTPRequestIn, redis: RedisDep) -> OTPRequestOut:
    code, ttl = await otp.request_otp(redis, body.phone)  # type: ignore[arg-type]
    settings = get_settings()
    # In console mode (no real SMS) return the code so the app can auto-fill it.
    # This keeps registration working without an SMS provider; switch to a real
    # provider (sms_provider=http/twilio) for production-grade verification.
    expose = settings.is_dev or settings.sms_provider == "console"
    return OTPRequestOut(
        sent=True,
        expires_in_seconds=ttl,
        debug_code=code if expose else None,
    )


@router.post("/otp/verify", response_model=TokenOut)
async def verify_otp(
    body: OTPVerifyIn,
    request: Request,
    db: DbSession,
    redis: RedisDep,
) -> TokenOut:
    await otp.verify_otp(redis, body.phone, body.code)  # type: ignore[arg-type]
    user = await service.get_or_create_user(
        db,
        phone=body.phone,
        role=body.role,
        full_name=body.full_name,
        nickname=body.nickname,
        locale=body.locale,
    )
    tokens = await service.issue_tokens(
        db,
        user,
        user_agent=request.headers.get("user-agent"),
        ip_address=request.client.host if request.client else None,
    )
    await service.write_audit(
        db,
        actor_id=user.id,
        actor_role=user.role,
        action="auth.login",
        object_type="user",
        object_id=user.id,
        ip_address=request.client.host if request.client else None,
    )
    return TokenOut(**tokens)


@router.post("/register/driver", response_model=TokenOut)
async def register_driver(
    body: RegisterDriverIn, request: Request, db: DbSession
) -> TokenOut:
    user = await service.register_driver(
        db,
        phone=body.phone,
        full_name=body.full_name,
        password=body.password,
        photo_url=body.photo_url,
    )
    tokens = await service.issue_tokens(
        db,
        user,
        user_agent=request.headers.get("user-agent"),
        ip_address=request.client.host if request.client else None,
    )
    await service.write_audit(
        db,
        actor_id=user.id,
        actor_role=user.role,
        action="auth.register_driver",
        object_type="user",
        object_id=user.id,
        ip_address=request.client.host if request.client else None,
    )
    return TokenOut(**tokens)


@router.post("/login/driver", response_model=TokenOut)
async def login_driver(
    body: LoginDriverIn, request: Request, db: DbSession
) -> TokenOut:
    user = await service.login_driver(
        db,
        phone=body.phone,
        full_name=body.full_name,
        password=body.password,
    )
    tokens = await service.issue_tokens(
        db,
        user,
        user_agent=request.headers.get("user-agent"),
        ip_address=request.client.host if request.client else None,
    )
    await service.write_audit(
        db,
        actor_id=user.id,
        actor_role=user.role,
        action="auth.login_driver",
        object_type="user",
        object_id=user.id,
        ip_address=request.client.host if request.client else None,
    )
    return TokenOut(**tokens)


@router.post("/refresh", response_model=TokenOut)
async def refresh(body: RefreshIn, db: DbSession) -> TokenOut:
    tokens = await service.refresh_tokens(db, body.refresh_token)
    return TokenOut(**tokens)


@router.get("/me", response_model=MeOut)
async def me(user: CurrentUser) -> MeOut:
    return MeOut(
        id=user.id,
        phone=user.phone,
        full_name=user.full_name,
        nickname=user.nickname,
        photo_url=user.photo_url,
        role=user.role,
        locale=user.locale,
        status=user.status,
    )
