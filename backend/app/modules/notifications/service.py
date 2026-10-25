"""Notification service — outbox-pattern push/SMS dispatcher.

Architecture:
  - `enqueue()` writes a pending notification to Redis (outbox list).
  - The worker runner polls the list and calls the appropriate provider.
  - SMS: console logger in dev; real gateway in production.
  - Push: FCM/APNs adapter stub — replace with real SDK calls.

The outbox key is `notifications:outbox` — a Redis list that workers BLPOP from.
"""

import json
import logging
from enum import StrEnum

from redis.asyncio import Redis

logger = logging.getLogger("qadam.notifications")

OUTBOX_KEY = "notifications:outbox"


class Channel(StrEnum):
    SMS = "sms"
    PUSH = "push"
    IN_APP = "in_app"


async def enqueue(
    redis: Redis,
    *,
    user_id: str,
    channel: Channel,
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """Push a notification job onto the Redis outbox list."""
    payload = json.dumps(
        {
            "user_id": user_id,
            "channel": channel,
            "title": title,
            "body": body,
            "data": data or {},
        }
    )
    await redis.rpush(OUTBOX_KEY, payload)


async def send_sms(phone: str, message: str, provider: str = "console") -> None:
    """Send an SMS.  Console provider logs to stdout; swap for real gateway."""
    if provider == "console":
        logger.info("[SMS] → %s: %s", phone, message)
        return
    # TODO: integrate real SMS gateway (e.g. SMS.KZ, Megacom)
    raise NotImplementedError(f"SMS provider '{provider}' not implemented")


async def send_push(
    device_token: str,
    *,
    title: str,
    body: str,
    data: dict | None = None,
    platform: str = "android",
) -> None:
    """Send a push notification.  Stub implementation — replace with FCM/APNs."""
    logger.info(
        "[PUSH/%s] → %s | %s: %s | data=%s",
        platform.upper(),
        device_token[:8] + "...",
        title,
        body,
        data,
    )
    # TODO: integrate FCM (google-cloud-firestore / httpx call to FCM v1 API)
    #       and APNs (httpx2 + JWT for iOS tokens)


# ── Convenience helpers used by other modules ──────────────────────────────────


async def notify_ride_assigned(redis: Redis, *, passenger_id: str, driver_name: str, eta_min: int) -> None:
    await enqueue(
        redis,
        user_id=passenger_id,
        channel=Channel.PUSH,
        title="Водитель назначен",
        body=f"{driver_name} едет к вам. Ожидаемое время: {eta_min} мин.",
        data={"event": "ride.assigned"},
    )


async def notify_ride_completed(redis: Redis, *, passenger_id: str, amount: str) -> None:
    await enqueue(
        redis,
        user_id=passenger_id,
        channel=Channel.PUSH,
        title="Поездка завершена",
        body=f"Спасибо за поездку! Сумма: {amount} сом.",
        data={"event": "ride.completed"},
    )


async def notify_ride_cancelled(redis: Redis, *, user_id: str, by_whom: str) -> None:
    await enqueue(
        redis,
        user_id=user_id,
        channel=Channel.PUSH,
        title="Поездка отменена",
        body=f"Поездка была отменена ({by_whom}).",
        data={"event": "ride.cancelled"},
    )


async def notify_booking_confirmed(redis: Redis, *, passenger_id: str, trip_info: str) -> None:
    await enqueue(
        redis,
        user_id=passenger_id,
        channel=Channel.PUSH,
        title="Бронь подтверждена",
        body=f"Ваше место в рейсе {trip_info} забронировано.",
        data={"event": "booking.confirmed"},
    )


async def notify_document_reviewed(
    redis: Redis,
    *,
    driver_user_id: str,
    doc_type: str,
    approved: bool,
) -> None:
    status_text = "одобрен" if approved else "отклонён"
    await enqueue(
        redis,
        user_id=driver_user_id,
        channel=Channel.PUSH,
        title="Документ проверен",
        body=f"Ваш документ «{doc_type}» {status_text}.",
        data={"event": "document.reviewed", "approved": approved},
    )
