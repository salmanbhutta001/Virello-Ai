"""Live-chat support tickets (deterministic support brain)."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "support_ticket_001"
down_revision: str | None = "trend_images_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "support_ticket",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("subject", sa.String(255), nullable=False,
                  server_default=""),
        sa.Column("message", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="open", index=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
    )


def downgrade() -> None:
    op.drop_table("support_ticket")
