"""Payment schemas."""

from decimal import Decimal

from pydantic import BaseModel


class PaymentCreateIn(BaseModel):
    amount: Decimal
    reference_type: str
    reference_id: str
    idempotency_key: str
    currency: str = "KGS"


class PaymentOut(BaseModel):
    id: str
    provider: str
    external_id: str | None
    status: str
    amount: Decimal
    currency: str
    reference_type: str
    reference_id: str


class WebhookEventIn(BaseModel):
    event_id: str
    event_type: str
    external_id: str
    payload: dict = {}


class MockCompleteIn(BaseModel):
    payment_id: str
