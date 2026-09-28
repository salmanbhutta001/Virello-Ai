"""AI Core foundation (Phase 0): conversation memory + cross-module context.

Revision ID: ai_core_001
Revises: community_dir_001
Create Date: 2026-09-29

Additive only:
- ai_conversations: id (uuid pk), user_id fk, title, created_at, updated_at.
- ai_messages: id (uuid pk), conversation_id fk, role, content, intent,
  module, meta (json), created_at.
- ai_contexts: id (uuid pk), user_id fk unique, summary, entities (json),
  preferences (json), updated_at.
- ai_intent_logs: id (uuid pk), user_id fk, conversation_id fk nullable,
  raw_input, intent, confidence, module, created_at.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.core import GUID

revision: str = "ai_core_001"
down_revision: Union[str, None] = "community_dir_001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ai_conversations",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("title", sa.String(255), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "ai_messages",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("conversation_id", GUID(), sa.ForeignKey("ai_conversations.id"),
                 nullable=False, index=True),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("content", sa.Text(), nullable=False, server_default=""),
        sa.Column("intent", sa.String(64), nullable=True),
        sa.Column("module", sa.String(64), nullable=True),
        sa.Column("meta", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False, index=True),
    )
    op.create_table(
        "ai_contexts",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"),
                 nullable=False, unique=True, index=True),
        sa.Column("summary", sa.Text(), nullable=False, server_default=""),
        sa.Column("entities", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column("preferences", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "ai_intent_logs",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("conversation_id", GUID(), sa.ForeignKey("ai_conversations.id"),
                 nullable=True),
        sa.Column("raw_input", sa.Text(), nullable=False, server_default=""),
        sa.Column("intent", sa.String(64), nullable=False, index=True),
        sa.Column("confidence", sa.Float(), nullable=False, server_default="0"),
        sa.Column("module", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                 server_default=sa.func.now(), nullable=False, index=True),
    )


def downgrade() -> None:
    op.drop_table("ai_intent_logs")
    op.drop_table("ai_contexts")
    op.drop_table("ai_messages")
    op.drop_table("ai_conversations")
