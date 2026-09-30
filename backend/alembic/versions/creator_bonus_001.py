"""Alembic: DiscoveryPlacement.created_with (Create & Earn loop)."""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "creator_bonus_001"
down_revision = "shoppable_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("discovery_placements",
                  sa.Column("created_with", sa.String(16), nullable=True))


def downgrade() -> None:
    op.drop_column("discovery_placements", "created_with")
