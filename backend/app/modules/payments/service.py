import json
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.enums import PaymentStatus
from app.core.exceptions import ConflictError, NotFoundError
from app.modules.payments.models import Payment, PaymentEvent


async def create_payment(
    db: AsyncSession,
    *,
    amount: Decimal,
    payer_user_id: str,
    reference_type: str,
    reference_id: str,
    idempotency_key: str,
    currency: str = "KGS",
) -> Payment:
    existing = await db.execute(select(Payment).where(Payment.idempotency_key == idempotency_key))
    found = existing.scalar_one_or_none()
    if found:
        return found

    settings = get_settings()
    payment = Payment(
        provider=settings.payment_provider,
        status=PaymentStatus.CREATED,
        amount=amount,
        currency=currency,
        payer_user_id=payer_user_id,
        reference_type=reference_type,
        reference_id=reference_id,
        idempotency_key=idempotency_key,
    )
    db.add(payment)
    await db.flush()

    if settings.payment_provider == "mock":
        payment.status = PaymentStatus.PENDING
        payment.external_id = f"mock_{uuid4().hex[:16]}"
        await db.flush()

    return payment


async def apply_provider_event(
    db: AsyncSession,
    *,
    provider: str,
    event_id: str,
    event_type: str,
    external_id: str,
    payload: dict,
) -> Payment:
    """Idempotent webhook processing — same event_id never applied twice."""
    existing_event = await db.execute(
        select(PaymentEvent).where(
            PaymentEvent.provider == provider,
            PaymentEvent.event_id == event_id,
        )
    )
    prior = existing_event.scalar_one_or_none()
    if prior and prior.processed:
        payment = await db.get(Payment, prior.payment_id) if prior.payment_id else None
        if payment:
            return payment
        raise ConflictError("Event already processed without payment link")

    result = await db.execute(
        select(Payment).where(
            Payment.provider == provider,
            Payment.external_id == external_id,
        )
    )
    payment = result.scalar_one_or_none()
    if not payment:
        raise NotFoundError("Payment not found for provider event")

    event = prior or PaymentEvent(
        payment_id=payment.id,
        provider=provider,
        event_id=event_id,
        event_type=event_type,
        payload=json.dumps(payload),
    )
    if not prior:
        db.add(event)

    if event_type in {"payment.succeeded", "succeeded"}:
        payment.status = PaymentStatus.SUCCEEDED
    elif event_type in {"payment.failed", "failed"}:
        payment.status = PaymentStatus.FAILED
        payment.failure_reason = str(payload.get("reason", "provider_failed"))
    else:
        raise ConflictError(f"Unsupported event type: {event_type}")

    event.processed = True
    event.payment_id = payment.id
    await db.flush()
    return payment


async def mock_complete_payment(db: AsyncSession, payment_id: str) -> Payment:
    """Dev helper: simulate successful provider callback."""
    payment = await db.get(Payment, payment_id)
    if not payment:
        raise NotFoundError("Payment not found")
    if payment.status == PaymentStatus.SUCCEEDED:
        return payment
    return await apply_provider_event(
        db,
        provider=payment.provider,
        event_id=f"evt_{payment.id}",
        event_type="payment.succeeded",
        external_id=payment.external_id or "",
        payload={"mock": True},
    )
