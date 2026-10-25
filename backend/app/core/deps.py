from collections.abc import Callable
from typing import Annotated

from fastapi import Depends, Header
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.enums import UserRole, UserStatus
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.redis import get_redis
from app.core.security import try_decode_token
from app.modules.identity.models import User

bearer_scheme = HTTPBearer(auto_error=False)

DbSession = Annotated[AsyncSession, Depends(get_db)]
RedisDep = Annotated[object, Depends(get_redis)]


async def get_current_user(
    db: DbSession,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
) -> User:
    if credentials is None:
        raise UnauthorizedError()
    payload = try_decode_token(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise UnauthorizedError("Invalid access token")
    user = await db.get(User, payload["sub"])
    if not user or user.status != UserStatus.ACTIVE:
        raise UnauthorizedError("User inactive")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_roles(*roles: UserRole) -> Callable:
    async def _checker(user: CurrentUser) -> User:
        if user.role not in {r.value for r in roles} and user.role not in roles:
            raise ForbiddenError("Insufficient role")
        return user

    return _checker


async def get_optional_idempotency_key(
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> str | None:
    return idempotency_key


async def ensure_unique_idempotency(
    db: AsyncSession,
    model,
    key: str | None,
    field_name: str = "idempotency_key",
):
    if not key:
        return None
    result = await db.execute(select(model).where(getattr(model, field_name) == key))
    existing = result.scalar_one_or_none()
    return existing
