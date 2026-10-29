from redis.asyncio import Redis

from app.core.config import get_settings

_redis: Redis | None = None


async def get_redis():
    global _redis
    if _redis is None:
        try:
            import redis.asyncio as _r

            client = _r.Redis.from_url(get_settings().redis_url, decode_responses=True)
            await client.ping()
            _redis = client
        except Exception:
            _redis = None
    return _redis


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
