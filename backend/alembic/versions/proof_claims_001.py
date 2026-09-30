"""Alembic: proof-based reward claims + per-post cash badge.

- discovery_placements.reward_cents (nullable; NULL = fall back to the
  rewards.default_post_reward_cents setting, default 5 cents). Shown on
  every post card as a small "+$0.05" badge; used as the claim amount.
- reward_claims table: user-filed reward claims with optional screenshot
  proof. share claims wait for admin approval; other types auto-approve
  per the rewards.auto_approve setting (still logged as claims).
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "proof_claims_001"
down_revision: str | None = "notifications_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "discovery_placements",
        sa.Column("reward_cents", sa.Integer(), nullable=True),
    )
    op.create_table(
        "reward_claims",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("claim_type", sa.String(32), nullable=False, index=True),
        # share | post | streak | like_received | comment_received |
        # volume_bonus | winner
        sa.Column("ref_id", sa.String(128), nullable=True, index=True),
        # placement id, period label, ...
        sa.Column("amount_cents", sa.Integer(), nullable=True),
        sa.Column("points", sa.Integer(), nullable=True),
        # exactly one of amount_cents / points is set
        sa.Column("proof_url", sa.String(512), nullable=True),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="pending", index=True),
        # pending | approved | rejected
        sa.Column("admin_note", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("user_id", "claim_type", "ref_id",
                            name="uq_reward_claims_user_type_ref"),
    )


def downgrade() -> None:
    op.drop_table("reward_claims")
    op.drop_column("discovery_placements", "reward_cents")
