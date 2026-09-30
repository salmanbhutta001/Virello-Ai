"""Share-to-earn click log."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "share_earn_001"
# Multi-head with shoppable_001 is acceptable: `alembic upgrade head`
# covers both branches. Chained on rewards_001 to avoid coupling.
down_revision: str | None = "rewards_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "share_clicks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(128), nullable=False, index=True),
        sa.Column("sharer_user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("asin", sa.String(10), nullable=False, index=True),
        sa.Column("viewer_user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=True),
        sa.Column("viewer_ip_hash", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
    )


def downgrade() -> None:
    op.drop_table("share_clicks")
