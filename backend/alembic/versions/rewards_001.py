"""Virello Points rewards ledger (append-only)."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "rewards_001"
down_revision: str | None = "support_ticket_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "points_ledger",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("delta", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reason", sa.String(64), nullable=False, index=True),
        sa.Column("ref_id", sa.String(128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
        sa.UniqueConstraint("user_id", "reason", "ref_id",
                            name="uq_points_user_reason_ref"),
    )


def downgrade() -> None:
    op.drop_table("points_ledger")
