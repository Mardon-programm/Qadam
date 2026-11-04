"""add password_hash, nickname, photo_url to users

Revision ID: 0002_add_user_fields
Revises: 0001_initial
Create Date: 2026-11-04 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002_add_user_fields"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("password_hash", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("nickname", sa.String(64), nullable=True))
    op.add_column("users", sa.Column("photo_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "photo_url")
    op.drop_column("users", "nickname")
    op.drop_column("users", "password_hash")
