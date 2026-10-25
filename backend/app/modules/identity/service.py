from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.enums import UserRole, UserStatus
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    try_decode_token,
)
from app.modules.identity.models import AuditEvent, RefreshSession, User


async def get_or_create_user(
    db: AsyncSession,
    *,
    phone: str,
    role: str,
    full_name: str | None = None,
    locale: str = "ru",
) -> User:
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if user:
        if user.status == UserStatus.BLOCKED:
            raise ForbiddenError("Account is blocked")
        if full_name and not user.full_name:
            user.full_name = full_name
        user.is_phone_verified = True
        user.last_login_at = datetime.now(UTC)
        # Role upgrade only for empty passenger → requested role on first verify
        if user.role == UserRole.PASSENGER and role in {
            UserRole.DRIVER,
            UserRole.OPS,
        }:
            # Ops role cannot be self-claimed except bootstrap phone
            if role == UserRole.OPS:
                settings = get_settings()
                if phone != settings.ops_bootstrap_phone:
                    raise ForbiddenError("Ops role requires invitation")
            user.role = role
        return user

    if role == UserRole.OPS:
        settings = get_settings()
        if phone != settings.ops_bootstrap_phone:
            raise ForbiddenError("Ops role requires invitation")

    user = User(
        phone=phone,
        full_name=full_name
        or (get_settings().ops_bootstrap_name if role == UserRole.OPS else None),
        locale=locale if locale in get_settings().locale_list else "ru",
        role=role,
        status=UserStatus.ACTIVE,
        is_phone_verified=True,
        last_login_at=datetime.now(UTC),
    )
    db.add(user)
    await db.flush()
    return user


async def issue_tokens(
    db: AsyncSession,
    user: User,
    *,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> dict[str, str]:
    access = create_access_token(user.id, role=user.role)
    refresh = create_refresh_token(user.id, role=user.role)
    payload = decode_token(refresh)
    settings = get_settings()
    session = RefreshSession(
        user_id=user.id,
        jti=payload["jti"],
        expires_at=datetime.now(UTC)
        + timedelta(days=settings.refresh_token_ttl_days),
        user_agent=user_agent,
        ip_address=ip_address,
    )
    db.add(session)
    return {
        "access_token": access,
        "refresh_token": refresh,
        "user_id": user.id,
        "role": user.role,
        "phone": user.phone,
    }


async def refresh_tokens(db: AsyncSession, refresh_token: str) -> dict[str, str]:
    payload = try_decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise UnauthorizedError("Invalid refresh token")

    result = await db.execute(
        select(RefreshSession).where(
            RefreshSession.jti == payload["jti"],
            RefreshSession.revoked.is_(False),
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise UnauthorizedError("Refresh session revoked or missing")

    user = await db.get(User, payload["sub"])
    if not user or user.status != UserStatus.ACTIVE:
        raise UnauthorizedError("User inactive")

    session.revoked = True
    return await issue_tokens(db, user)


async def write_audit(
    db: AsyncSession,
    *,
    actor_id: str | None,
    actor_role: str | None,
    action: str,
    object_type: str,
    object_id: str | None = None,
    meta_json: str | None = None,
    ip_address: str | None = None,
) -> None:
    db.add(
        AuditEvent(
            actor_id=actor_id,
            actor_role=actor_role,
            action=action,
            object_type=object_type,
            object_id=object_id,
            meta_json=meta_json,
            ip_address=ip_address,
        )
    )
