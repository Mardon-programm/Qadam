from decimal import Decimal

from sqlalchemy import Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class CorporateAccount(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "corporate_accounts"
    __table_args__ = (UniqueConstraint("legal_name", name="uq_corporate_legal_name"),)

    legal_name: Mapped[str] = mapped_column(String(255), nullable=False)
    tax_id: Mapped[str | None] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(32), default="active", nullable=False)
    monthly_budget: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    currency: Mapped[str] = mapped_column(String(8), default="KGS", nullable=False)


class CorporateMember(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "corporate_members"
    __table_args__ = (
        UniqueConstraint("account_id", "user_id", name="uq_corporate_member"),
    )

    account_id: Mapped[str] = mapped_column(String(36), nullable=False)
    user_id: Mapped[str] = mapped_column(String(36), nullable=False)
    member_role: Mapped[str] = mapped_column(String(32), default="employee", nullable=False)
    trip_limit: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(String(32), default="active", nullable=False)
