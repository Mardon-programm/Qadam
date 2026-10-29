import json
import random
import string
from urllib.parse import urlencode

import httpx
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

    settings = get_settings()
    provider = (settings.sms_provider or "console").lower()

    if provider == "console":
        print(f"[QADAM SMS] OTP for {phone}: {code}")
    elif provider == "http":
        await _send_sms_http(phone, code, settings)
    elif provider == "twilio":
        await _send_sms_twilio(phone, code, settings)
    else:
        print(f"[QADAM SMS] unknown provider {provider}; OTP for {phone}: {code}")

    return code, settings.otp_ttl_seconds


async def _send_sms_http(phone: str, code: str, settings) -> None:
    url = settings.sms_http_url
    if not url:
        print(f"[QADAM SMS] sms_http_url not set; OTP for {phone}: {code}")
        return
    method = (settings.sms_http_method or "POST").upper()
    headers = {}
    if settings.sms_http_headers:
        try:
            headers = json.loads(settings.sms_http_headers)
        except Exception:
            headers = {}
    body_template = settings.sms_http_body or ""
    body_str = body_template.replace("{phone}", phone).replace("{code}", code)
    # Try JSON first
    try:
        payload = json.loads(body_str)
        async with httpx.AsyncClient(timeout=10) as client:
            if method == "GET":
                await client.get(url, params=payload, headers=headers)
            else:
                await client.request(method, url, json=payload, headers=headers)
        return
    except (json.JSONDecodeError, ValueError):
        pass
    async with httpx.AsyncClient(timeout=10) as client:
        if method == "GET":
            await client.get(url, params={"phone": phone, "code": code}, headers=headers)
        else:
            await client.request(method, url, content=body_str, headers=headers)


async def _send_sms_twilio(phone: str, code: str, settings) -> None:
    sid = settings.twilio_account_sid
    token = settings.twilio_auth_token
    frm = settings.twilio_from
    if not (sid and token and frm):
        print(f"[QADAM SMS] Twilio not configured; OTP for {phone}: {code}")
        return
    url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
    data = {"To": phone, "From": frm, "Body": f"Qadam код: {code}"}
    async with httpx.AsyncClient(timeout=10) as client:
        await client.post(url, data=data, auth=(sid, token))


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
