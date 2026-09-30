"""Alembic: merge the creator_bonus_001 + proof_claims_001 heads.

Commit 0e33c7d branched the migration chain (two heads). With multiple
heads, `alembic upgrade head` fails — and the Dockerfile CMD swallows
that failure (`|| echo 'alembic skipped/failed'`), so production booted
with new code on an old schema (e.g. users.email_verified missing),
500ing every endpoint that touches the users table. This empty merge
restores a single head so upgrades apply cleanly again.
"""
from __future__ import annotations

revision = "merge_heads_001"
down_revision = ("creator_bonus_001", "proof_claims_001")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
