"""trend_image_cache: resolved display images for trending topics."""
from alembic import op
import sqlalchemy as sa


revision: str = "trend_images_001"
down_revision: str | None = "curation_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trend_image_cache",
        sa.Column("topic_key", sa.String(256), primary_key=True),
        sa.Column("image_url", sa.Text(), nullable=False),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("trend_image_cache")
