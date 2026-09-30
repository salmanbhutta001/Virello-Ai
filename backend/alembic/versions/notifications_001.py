"""Alembic: personal user_notifications table (withdrawal events, etc.)."""
from __future__ import annotations

import uuid

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "notifications_001"
down_revision = "cash_wallet_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_notifications",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  default=uuid.uuid4),
        sa.Column("user_id", UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("kind", sa.String(48), nullable=False, index=True),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("body", sa.Text, nullable=False),
        sa.Column("data", sa.JSON, nullable=False,
                  server_default=sa.text("'{}'")),
        sa.Column("read", sa.Boolean, nullable=False,
                  server_default=sa.false()),
        sa.Column("created_at", sa.DateTime, nullable=False,
                  server_default=sa.func.now(), index=True),
    )


def downgrade() -> None:
    op.drop_table("user_notifications")
