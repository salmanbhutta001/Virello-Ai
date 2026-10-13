"""image_jobs: DB-backed AI image generation jobs (multi-worker safe).

Mirrors video_jobs_001: POST /create/image-agnes now returns a job_id
immediately and a background task performs the Agnes call, so polling
GET /create/image-jobs/{job_id} works no matter which uvicorn worker
handles the request.

NOTE: production also runs Base.metadata.create_all at boot (init_db),
so this table is created even if Alembic is wedged — same belt-and-
suspenders as video_jobs.
"""
from alembic import op
import sqlalchemy as sa

from app.models.core import GUID


revision: str = "image_jobs_001"
down_revision: str | None = "merge_heads_002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "image_jobs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"),
                  nullable=False),
        sa.Column("prompt", sa.Text(), nullable=False),
        sa.Column("style", sa.String(20), nullable=False,
                  server_default="realistic"),
        sa.Column("seed", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="pending"),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_image_jobs_user_id", "image_jobs", ["user_id"])
    op.create_index("ix_image_jobs_status", "image_jobs", ["status"])


def downgrade() -> None:
    op.drop_index("ix_image_jobs_status", table_name="image_jobs")
    op.drop_index("ix_image_jobs_user_id", table_name="image_jobs")
    op.drop_table("image_jobs")
