"""Autonomous curation tables: candidate queue + run history."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "curation_001"
down_revision: str | None = "wishlist_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "curation_candidates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("asin", sa.String(16), unique=True, nullable=False, index=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("department", sa.String(64), nullable=False, index=True),
        sa.Column("source", sa.String(32), nullable=False,
                  server_default="amazon_search"),
        sa.Column("main_image_url", sa.Text(), nullable=False,
                  server_default=""),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="pending", index=True),
        sa.Column("note", sa.String(255), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
    )
    op.create_table(
        "curation_runs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("started_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="running", index=True),
        sa.Column("departments_total", sa.Integer(), nullable=False,
                  server_default="0"),
        sa.Column("departments_covered", sa.Integer(), nullable=False,
                  server_default="0"),
        sa.Column("products_created", sa.Integer(), nullable=False,
                  server_default="0"),
        sa.Column("details", sa.JSON(), nullable=False,
                  server_default=sa.text("'{}'::json")),
    )


def downgrade() -> None:
    op.drop_table("curation_runs")
    op.drop_table("curation_candidates")
