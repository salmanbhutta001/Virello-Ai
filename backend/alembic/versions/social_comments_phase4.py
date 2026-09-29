"""Social comments (Phase 4): genuine user comments on discovery posts.

Revision ID: social_comments_001
Revises: academy_001
Create Date: 2026-09-29

Additive only:
- post_comments: id (str pk), user_id fk, post_url (indexed),
  text, author_name (snapshot), created_at.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.core import GUID

revision: str = "social_comments_001"
down_revision: Union[str, None] = "academy_001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "post_comments",
        sa.Column("id", sa.String(32), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"),
                  nullable=False, index=True),
        sa.Column("post_url", sa.String(2048), nullable=False, index=True),
        sa.Column("text", sa.String(2000), nullable=False),
        sa.Column("author_name", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("post_comments")
