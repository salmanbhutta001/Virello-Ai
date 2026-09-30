"""Shoppable posts: tagged products on feed posts + click tracking.

PostProduct tags Amazon ASINs on discovery placements (reward +25 on
opt-in via rewards.award_post_with_products); ShopClick logs every
outbound tap through GET /shop/go/{asin} (owner earns +2 via
rewards.award_product_click).

NOTE: down_revision targets rewards_001 directly (not the current
academy_001 head), so this creates a second Alembic head. Running
`alembic upgrade head` still upgrades both heads; a merge revision can
join them later if a single head is wanted.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "shoppable_001"
down_revision: str | None = "rewards_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "post_products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("post_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("discovery_placements.id"),
                  nullable=False, index=True),
        sa.Column("asin", sa.String(10), nullable=False, index=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now()),
        sa.UniqueConstraint("post_id", "asin", name="uq_post_product_asin"),
    )
    op.create_table(
        "shop_clicks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("asin", sa.String(10), nullable=False, index=True),
        sa.Column("post_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("discovery_placements.id"),
                  nullable=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=True, index=True),
        sa.Column("ip_hash", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
    )


def downgrade() -> None:
    op.drop_table("shop_clicks")
    op.drop_table("post_products")
