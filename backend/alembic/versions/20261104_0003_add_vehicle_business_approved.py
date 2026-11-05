"""add business_approved to vehicles

Revision ID: 0003_add_vehicle_business_approved
Revises: 0002_add_user_fields
Create Date: 2026-11-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0003_add_vehicle_business_approved"
down_revision: Union[str, None] = "0002_add_user_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = {c["name"] for c in inspector.get_columns("vehicles")}
    if "business_approved" not in existing:
        op.add_column("vehicles", sa.Column("business_approved", sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade() -> None:
    op.drop_column("vehicles", "business_approved")
