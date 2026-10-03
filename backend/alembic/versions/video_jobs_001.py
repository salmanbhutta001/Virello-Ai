"""video_jobs: DB-backed AI video generation jobs (multi-worker safe)."""
from alembic import op
import sqlalchemy as sa

from app.models.core import GUID


revision: str = "video_jobs_001"
down_revision: str | None = "trending_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "video_jobs",
        sa.Column("job_id", sa.String(12), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"),
                  nullable=False),
        sa.Column("agnes_id", sa.String(128), nullable=True),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="submitted"),
        sa.Column("video_url", sa.Text(), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_video_jobs_user_id", "video_jobs", ["user_id"])
    op.create_index("ix_video_jobs_status", "video_jobs", ["status"])


def downgrade() -> None:
    op.drop_index("ix_video_jobs_status", table_name="video_jobs")
    op.drop_index("ix_video_jobs_user_id", table_name="video_jobs")
    op.drop_table("video_jobs")
