"""Merge the three Alembic heads into one (2026-10-05).

The migration chain had branched into three heads
(creator_bonus_001, proof_claims_001, users_avatar_cover_001), which makes
`alembic upgrade head` ambiguous and blocks production migrations.
This empty merge restores a single head.
"""
from alembic import op
import sqlalchemy as sa

revision = "merge_heads_002"
down_revision = ("creator_bonus_001", "proof_claims_001", "users_avatar_cover_001")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
