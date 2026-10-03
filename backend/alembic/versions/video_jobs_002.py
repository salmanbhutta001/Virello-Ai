"""video_jobs: widen agnes_id to Text (Agnes returns IDs longer than 128 chars)."""
from alembic import op
import sqlalchemy as sa


revision: str = "video_jobs_002"
down_revision: str | None = "video_jobs_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("video_jobs", "agnes_id", type_=sa.Text(),
                    existing_type=sa.String(128), nullable=True)


def downgrade() -> None:
    op.alter_column("video_jobs", "agnes_id", type_=sa.String(128),
                    existing_type=sa.Text(), nullable=True)
