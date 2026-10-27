from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import LedgerDirection
from app.core.exceptions import ConflictError
from app.modules.ledger.models import LedgerEntry


async def post_entry(
    db: AsyncSession,
    *,
    account_id: str,
    account_owner_type: str,
    account_owner_id: str,
    direction: LedgerDirection,
    amount: Decimal,
    entry_type: str,
    reference_type: str,
    reference_id: str,
    idempotency_key: str,
    description: str | None = None,
    currency: str = "KGS",
) -> LedgerEntry:
    if amount <= 0:
        raise ConflictError("Ledger amount must be positive")

    existing = await db.execute(
        select(LedgerEntry).where(LedgerEntry.idempotency_key == idempotency_key)
    )
    found = existing.scalar_one_or_none()
    if found:
        return found

    entry = LedgerEntry(
        account_id=account_id,
        account_owner_type=account_owner_type,
        account_owner_id=account_owner_id,
        direction=direction.value,
        amount=amount,
        currency=currency,
        entry_type=entry_type,
        reference_type=reference_type,
        reference_id=reference_id,
        idempotency_key=idempotency_key,
        description=description,
    )
    db.add(entry)
    await db.flush()
    return entry


async def post_ride_completion(
    db: AsyncSession,
    *,
    ride_id: str,
    driver_id: str,
    passenger_id: str,
    gross: Decimal,
    platform_fee: Decimal,
    driver_net: Decimal,
) -> list[LedgerEntry]:
    """
    Double-entry style journal for a completed city ride.
    Idempotent via ride_id keys — completed trip cannot accrue twice.
    """
    entries = [
        await post_entry(
            db,
            account_id=f"driver:{driver_id}",
            account_owner_type="driver",
            account_owner_id=driver_id,
            direction=LedgerDirection.CREDIT,
            amount=driver_net,
            entry_type="ride_earning",
            reference_type="ride_order",
            reference_id=ride_id,
            idempotency_key=f"ride:{ride_id}:driver_credit",
            description="Driver net for completed ride",
        ),
    ]
    # Platform fee is optional: with 0% commission there is nothing to post.
    if platform_fee > 0:
        entries.append(
            await post_entry(
                db,
                account_id="platform:fees",
                account_owner_type="platform",
                account_owner_id="qadam",
                direction=LedgerDirection.CREDIT,
                amount=platform_fee,
                entry_type="platform_fee",
                reference_type="ride_order",
                reference_id=ride_id,
                idempotency_key=f"ride:{ride_id}:platform_fee",
                description="Platform fee for completed ride",
            )
        )
    entries.append(
        await post_entry(
            db,
            account_id=f"passenger:{passenger_id}",
            account_owner_type="passenger",
            account_owner_id=passenger_id,
            direction=LedgerDirection.DEBIT,
            amount=gross,
            entry_type="ride_charge",
            reference_type="ride_order",
            reference_id=ride_id,
            idempotency_key=f"ride:{ride_id}:passenger_debit",
            description="Passenger charge for completed ride",
        )
    )
    return entries


async def wallet_balance(db: AsyncSession, account_id: str) -> Decimal:
    result = await db.execute(
        select(LedgerEntry).where(LedgerEntry.account_id == account_id)
    )
    balance = Decimal("0.00")
    for entry in result.scalars().all():
        if entry.direction == LedgerDirection.CREDIT:
            balance += entry.amount
        else:
            balance -= entry.amount
    return balance
