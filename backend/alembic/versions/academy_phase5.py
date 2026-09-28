"""AI Academy (Phase 5): lessons + per-user lesson progress.

Revision ID: academy_001
Revises: ai_commerce_001
Create Date: 2026-09-29

Additive only:
- lessons: id (uuid pk), title, description, category, level, language,
  content_json, quiz_json (nullable), order_index, is_published, created_at.
- lesson_progress: id (uuid pk), user_id fk, lesson_id fk,
  uq_progress_user_lesson, status, quiz_score (nullable),
  completed_at (nullable), updated_at.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.core import GUID

revision: str = "academy_001"
down_revision: Union[str, None] = "ai_commerce_001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "lessons",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("category", sa.String(32), nullable=False,
                  server_default="content", index=True),
        sa.Column("level", sa.String(16), nullable=False,
                  server_default="beginner"),
        sa.Column("language", sa.String(8), nullable=False, server_default="en"),
        sa.Column("content_json", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column("quiz_json", sa.JSON(), nullable=True),
        sa.Column("order_index", sa.Integer(), nullable=False,
                  server_default="0", index=True),
        sa.Column("is_published", sa.Boolean(), nullable=False,
                  server_default=sa.true(), index=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "lesson_progress",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"),
                 nullable=False, index=True),
        sa.Column("lesson_id", GUID(), sa.ForeignKey("lessons.id"),
                 nullable=False, index=True),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="started"),
        sa.Column("quiz_score", sa.Float(), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "lesson_id",
                            name="uq_progress_user_lesson"),
    )


def downgrade() -> None:
    op.drop_table("lesson_progress")
    op.drop_table("lessons")
