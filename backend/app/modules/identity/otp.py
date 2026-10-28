import random
import string

from redis.asyncio import Redis

from app.core.config import get_settings
from app.core.exceptions import RateLimitError, UnauthorizedError


def _otp_key(phone: str) -> str:
    return f"otp:{phone}"


def _rate_key(phone: str) -> str:
    return f"otp:rate:{phone}"


def generate_otp(length: int) -> str:
    return "".join(random.choices(string.digits, k=length))


async def request_otp(redis: Redis, phone: str) -> tuple[str, int]:
    settings = get_settings()
    rate = await redis.incr(_rate_key(phone))
    if rate == 1:
        await redis.expire(_rate_key(phone), 3600)
    if rate > settings.otp_rate_limit_per_phone:
        ttl = await redis.ttl(_rate_key(phone))
        raise RateLimitError(
            "Too many code requests for this phone number",
            retry_after_seconds=ttl if ttl and ttl > 0 else 3600,
        )

    code = generate_otp(settings.otp_length)
    await redis.setex(_otp_key(phone), settings.otp_ttl_seconds, code)

    # Console SMS provider — production swaps to real SMS gateway
    if settings.sms_provider == "console":
        print(f"[QADAM SMS] OTP for {phone}: {code}")

    return code, settings.otp_ttl_seconds


async def verify_otp(redis: Redis, phone: str, code: str) -> None:
    settings = get_settings()
    attempts_key = f"otp:attempts:{phone}"
    attempts = await redis.incr(attempts_key)
    if attempts == 1:
        await redis.expire(attempts_key, settings.otp_ttl_seconds)
    if attempts > settings.otp_max_attempts:
        await redis.delete(_otp_key(phone))
        raise RateLimitError(
            "Too many code attempts",
            retry_after_seconds=settings.otp_ttl_seconds,
        )

    stored = await redis.get(_otp_key(phone))
    if not stored or stored != code:
        raise UnauthorizedError("Invalid or expired OTP")

    await redis.delete(_otp_key(phone))
    await redis.delete(attempts_key)
