"""Payment endpoints.

Covers:
  - Passenger: initiate payment for a ride or booking
  - Webhook: provider callback (idempotent)
  - Dev helper: mock-complete a pending payment
  - Wallet balance for driver
"""

import hmac
import hashlib
import json

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession, require_roles
from app.core.enums import UserRole
from app.core.exceptions import NotFoundError
from app.modules.ledger.service import wallet_balance
from app.modules.payments import service
from app.modules.payments.models import Payment
from app.modules.payments.schemas import (
    MockCompleteIn,
    PaymentCreateIn,
    PaymentOut,
    WebhookEventIn,
)
from app.modules.trust.service import get_or_create_driver_profile

router = APIRouter(prefix="/payments", tags=["payments"])


def _out(p: Payment) -> PaymentOut:
    return PaymentOut(
        id=p.id,
        provider=p.provider,
        external_id=p.external_id,
        status=p.status,
        amount=p.amount,
        currency=p.currency,
        reference_type=p.reference_type,
        reference_id=p.reference_id,
    )


@router.post("", response_model=PaymentOut, status_code=201)
async def create_payment(
    body: PaymentCreateIn,
    db: DbSession,
    user: CurrentUser,
) -> PaymentOut:
    payment = await service.create_payment(
        db,
        amount=body.amount,
        payer_user_id=user.id,
        reference_type=body.reference_type,
        reference_id=body.reference_id,
        idempotency_key=body.idempotency_key,
        currency=body.currency,
    )
    return _out(payment)


@router.get("/{payment_id}", response_model=PaymentOut)
async def get_payment(
    payment_id: str,
    db: DbSession,
    user: CurrentUser,
) -> PaymentOut:
    payment = await db.get(Payment, payment_id)
    if not payment:
        raise NotFoundError("Payment not found")
    # Passengers see only their own payments
    if user.role == UserRole.PASSENGER and payment.payer_user_id != user.id:
        raise NotFoundError("Payment not found")
    return _out(payment)


@router.post("/webhook/provider")
async def provider_webhook(
    body: WebhookEventIn,
    request: Request,
    db: DbSession,
    x_signature: str | None = Header(default=None, alias="X-Signature"),
) -> dict:
    """
    Idempotent webhook handler for payment provider callbacks.
    Validates HMAC-SHA256 signature when configured.
    """
    settings = get_settings()
    if settings.payment_webhook_secret != "dev-webhook-secret":
        raw = await request.body()
        expected = hmac.new(
            settings.payment_webhook_secret.encode(),
            raw,
            hashlib.sha256,
        ).hexdigest()
        if not x_signature or not hmac.compare_digest(x_signature, expected):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid webhook signature",
            )

    await service.apply_provider_event(
        db,
        provider=settings.payment_provider,
        event_id=body.event_id,
        event_type=body.event_type,
        external_id=body.external_id,
        payload=body.payload,
    )
    return {"received": True}


@router.post(
    "/mock/complete",
    response_model=PaymentOut,
    dependencies=[Depends(require_roles(UserRole.OPS))],
)
async def mock_complete(body: MockCompleteIn, db: DbSession) -> PaymentOut:
    """Dev/ops helper: mark a pending mock payment as succeeded."""
    payment = await service.mock_complete_payment(db, body.payment_id)
    return _out(payment)


@router.get(
    "/wallet/balance",
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def driver_wallet(db: DbSession, user: CurrentUser) -> dict:
    driver = await get_or_create_driver_profile(db, user.id)
    balance = await wallet_balance(db, f"driver:{driver.id}")
    return {"account_id": f"driver:{driver.id}", "balance": balance, "currency": "KGS"}


@router.get(
    "/wallet/history",
    dependencies=[Depends(require_roles(UserRole.DRIVER))],
)
async def driver_wallet_history(
    db: DbSession,
    user: CurrentUser,
    days: int = 30,
) -> dict:
    from app.modules.reporting.service import driver_earnings_summary
    from app.modules.trust.service import get_or_create_driver_profile as _get_driver

    driver = await _get_driver(db, user.id)
    return await driver_earnings_summary(db, driver_id=driver.id, days=days)
