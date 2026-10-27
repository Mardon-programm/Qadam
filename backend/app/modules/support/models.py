from sqlalchemy import Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.enums import SupportCaseStatus
from app.core.models_base import TimestampMixin, UUIDPrimaryKeyMixin


class SupportCase(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "support_cases"
    __table_args__ = (
        Index("ix_support_status", "status"),
        Index("ix_support_user", "user_id"),
    )

    user_id: Mapped[str] = mapped_column(String(36), nullable=False)
    case_type: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(32), default=SupportCaseStatus.OPEN, nullable=False)
    subject: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    reference_type: Mapped[str | None] = mapped_column(String(64))
    reference_id: Mapped[str | None] = mapped_column(String(36))
    assignee_id: Mapped[str | None] = mapped_column(String(36))
    resolution: Mapped[str | None] = mapped_column(Text)
