"""community directory: curated public groups by niche

Revision ID: community_dir_001
Revises: f8a9b0c1d2e3
Create Date: 2026-09-28

Additive only:
- communities: id (uuid pk), platform, name, url, category, topics,
  description, member_count, language, is_verified, created_at.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.core import GUID

revision: str = "community_dir_001"
down_revision: Union[str, None] = "6a7b8c9d0e1f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "communities",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("platform", sa.String(32), nullable=False, index=True),
        sa.Column("name", sa.String(255), nullable=False, index=True),
        sa.Column("url", sa.String(1024), nullable=False),
        sa.Column("category", sa.String(64), nullable=False, index=True),
        sa.Column("topics", sa.Text(), nullable=False, server_default=""),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("member_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("language", sa.String(16), nullable=False, server_default="en"),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("communities")
