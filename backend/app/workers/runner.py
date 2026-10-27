"""Qadam async worker runner.

Responsibilities:
  1. Notification dispatcher  — polls Redis outbox list, calls SMS/push adapters.
  2. Seat hold expiry         — periodically releases expired HELD seats back to AVAILABLE.
  3. Offer timeout cleanup    — marks stale ride offers as expired.
  4. Subscription expiry      — marks ended PRO subscriptions as EXPIRED.
  5. Document expiry check    — notifies drivers of expiring documents.
  6. Payout processing        — processes pending driver payouts.

Run via:  python -m app.workers.runner
"""

import asyncio
import json
import logging
import signal
from datetime import UTC, datetime

from sqlalchemy import and_, select

from app.core.database import SessionLocal
from app.core.enums import SeatStatus, SubscriptionStatus
from app.core.redis import close_redis, get_redis
from app.modules.notifications.service import (
    OUTBOX_KEY,
    send_push,
    send_sms,
)
from app.modules.region.models import TripSeat
from app.modules.subscriptions.models import Subscription

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-5s %(name)s — %(message)s",
)
logger = logging.getLogger("qadam.worker")

_running = True


def _handle_stop(signum, frame):
    global _running
    logger.info("Worker received signal %s — shutting down gracefully", signum)
    _running = False


signal.signal(signal.SIGTERM, _handle_stop)
signal.signal(signal.SIGINT, _handle_stop)


# ── Notification dispatcher ────────────────────────────────────────────────────


async def notification_worker() -> None:
    """BLPOP from Redis outbox and dispatch each notification."""
    redis = await get_redis()
    logger.info("Notification worker started")
    while _running:
        try:
            # BLPOP blocks up to 2 seconds then returns None (allows clean shutdown)
            item = await redis.blpop(OUTBOX_KEY, timeout=2)
            if item is None:
                continue
            _, raw = item
            job = json.loads(raw)

            channel = job.get("channel", "push")
            user_id = job.get("user_id")
            title = job.get("title", "")
            body = job.get("body", "")
            data = job.get("data", {})

            if channel == "push":
                # In production look up device_token from user settings table.
                # Here we log for dev visibility.
                await send_push(
                    device_token=f"stub_token_{user_id}",
                    title=title,
                    body=body,
                    data=data,
                )
            elif channel == "sms":
                phone = data.get("phone", "")
                if phone:
                    await send_sms(phone, body)
            else:
                logger.debug("in_app notification for user %s: %s", user_id, title)

        except Exception as exc:
            logger.exception("Notification dispatch error: %s", exc)
            await asyncio.sleep(1)


# ── Seat hold expiry ───────────────────────────────────────────────────────────


async def seat_expiry_worker() -> None:
    """Every 60 s release HELD seats whose hold_until has passed."""
    logger.info("Seat expiry worker started")
    while _running:
        try:
            async with SessionLocal() as db:
                now = datetime.now(UTC)
                result = await db.execute(
                    select(TripSeat).where(
                        and_(
                            TripSeat.status == SeatStatus.HELD,
                            TripSeat.held_until < now,  # type: ignore[operator]
                        )
                    )
                )
                expired = list(result.scalars().all())
                if expired:
                    for seat in expired:
                        seat.status = SeatStatus.AVAILABLE
                        seat.held_until = None
                        seat.booking_id = None
                    await db.commit()
                    logger.info("Released %d expired seat holds", len(expired))
        except Exception as exc:
            logger.exception("Seat expiry worker error: %s", exc)
        await asyncio.sleep(60)


# ── Subscription expiry ────────────────────────────────────────────────────────


async def subscription_expiry_worker() -> None:
    """Every 5 minutes mark expired PRO subscriptions."""
    logger.info("Subscription expiry worker started")
    while _running:
        try:
            async with SessionLocal() as db:
                now = datetime.now(UTC)
                result = await db.execute(
                    select(Subscription).where(
                        and_(
                            Subscription.status == SubscriptionStatus.ACTIVE,
                            Subscription.ends_at.is_not(None),
                            Subscription.ends_at < now,  # type: ignore[operator]
                        )
                    )
                )
                expired = list(result.scalars().all())
                if expired:
                    for sub in expired:
                        sub.status = SubscriptionStatus.EXPIRED
                    await db.commit()
                    logger.info("Expired %d subscriptions", len(expired))
        except Exception as exc:
            logger.exception("Subscription expiry worker error: %s", exc)
        await asyncio.sleep(300)


# ── Offer timeout ──────────────────────────────────────────────────────────────


async def offer_timeout_worker() -> None:
    """Every 30 s expire stale ride offers and revert orders to SEARCHING."""
    from app.core.enums import RideOrderStatus
    from app.modules.city.models import RideOffer, RideOrder

    logger.info("Offer timeout worker started")
    while _running:
        try:
            async with SessionLocal() as db:
                now = datetime.now(UTC)
                result = await db.execute(
                    select(RideOffer).where(
                        and_(
                            RideOffer.status == "offered",
                            RideOffer.expires_at < now,  # type: ignore[operator]
                        )
                    )
                )
                stale = list(result.scalars().all())
                if stale:
                    expired_order_ids = set()
                    for offer in stale:
                        offer.status = "expired"
                        expired_order_ids.add(offer.ride_order_id)

                    # Revert orders that have no accepted offer back to SEARCHING
                    for order_id in expired_order_ids:
                        order_result = await db.execute(
                            select(RideOrder).where(
                                and_(
                                    RideOrder.id == order_id,
                                    RideOrder.status == RideOrderStatus.OFFERED,
                                )
                            )
                        )
                        order = order_result.scalar_one_or_none()
                        if order:
                            order.status = RideOrderStatus.SEARCHING

                    await db.commit()
                    logger.debug("Expired %d stale offers", len(stale))
        except Exception as exc:
            logger.exception("Offer timeout worker error: %s", exc)
        await asyncio.sleep(30)


# ── Document expiry checker ────────────────────────────────────────────────────


async def document_expiry_worker() -> None:
    """Every 24 hours check for expiring driver documents and notify them."""
    from datetime import timedelta

    from app.modules.notifications.service import enqueue_notification
    from app.modules.trust.models import DriverDocument

    logger.info("Document expiry worker started")
    while _running:
        try:
            async with SessionLocal() as db:
                now = datetime.now(UTC)
                warn_date = now + timedelta(days=30)  # Warn 30 days before expiry

                result = await db.execute(
                    select(DriverDocument).where(
                        and_(
                            DriverDocument.expires_at.is_not(None),
                            DriverDocument.expires_at < warn_date,  # type: ignore[operator]
                            DriverDocument.expires_at > now,  # type: ignore[operator]
                            DriverDocument.verification_status == "approved",
                        )
                    )
                )
                expiring = list(result.scalars().all())

                if expiring:
                    redis = await get_redis()
                    for doc in expiring:
                        days_left = (doc.expires_at - now).days  # type: ignore
                        await enqueue_notification(
                            redis,
                            user_id=doc.driver_id,
                            title="Документ истекает",
                            body=(
                                f"Ваш документ {doc.document_type} истекает через "
                                f"{days_left} дней. Пожалуйста, обновите его."
                            ),
                            channel="push",
                        )
                    logger.info("Notified %d drivers about expiring documents", len(expiring))
        except Exception as exc:
            logger.exception("Document expiry worker error: %s", exc)

        # Run once per day
        await asyncio.sleep(86400)


# ── Payout processor ───────────────────────────────────────────────────────────


async def payout_worker() -> None:
    """Every hour process pending driver payouts."""
    logger.info("Payout worker started")

    while _running:
        try:
            async with SessionLocal() as _db:
                # TODO: Implement payout processing logic
                # 1. Get drivers with pending payouts
                # 2. Calculate total payout amount
                # 3. Create payout batch
                # 4. Submit to payment provider
                # 5. Update payout status
                pass
        except Exception as exc:
            logger.exception("Payout worker error: %s", exc)

        await asyncio.sleep(3600)  # Run every hour


# ── Entry point ────────────────────────────────────────────────────────────────


async def main() -> None:
    logger.info("Qadam worker starting…")
    await asyncio.gather(
        notification_worker(),
        seat_expiry_worker(),
        subscription_expiry_worker(),
        offer_timeout_worker(),
        document_expiry_worker(),
        payout_worker(),
    )
    await close_redis()
    logger.info("Qadam worker stopped")


if __name__ == "__main__":
    asyncio.run(main())
