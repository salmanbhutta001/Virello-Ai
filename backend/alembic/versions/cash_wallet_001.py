"""Cash wallet tables + users.email_verified."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "cash_wallet_001"
down_revision: str | None = "share_earn_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "cash_ledger",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("delta_cents", sa.Integer, nullable=False),
        sa.Column("reason", sa.String(32), nullable=False, index=True),
        sa.Column("ref_id", sa.String(128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
        sa.UniqueConstraint("user_id", "reason", "ref_id",
                            name="uq_cash_user_reason_ref"),
    )
    op.create_table(
        "withdrawals",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("amount_cents", sa.Integer, nullable=False),
        # Payout method: registry id (bank_transfer, easypaisa, jazzcash,
        # paypal, payoneer, crypto_usdt) + validated details JSON.
        sa.Column("method_id", sa.String(32), nullable=False,
                  server_default="bank_transfer"),
        sa.Column("method_details", sa.JSON, nullable=False,
                  server_default=sa.text("'{}'")),
        sa.Column("status", sa.String(16), nullable=False,
                  server_default="pending", index=True),
        sa.Column("admin_note", sa.Text, nullable=True),
        sa.Column("payment_ref", sa.String(128), nullable=True),
        # Status timeline: requested (created_at) -> approved -> paid.
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("age_confirmed", sa.Boolean(), nullable=False,
                  server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
    )
    op.add_column("users",
                  sa.Column("email_verified", sa.Boolean(),
                            server_default=sa.false(), nullable=False))


def downgrade() -> None:
    op.drop_column("users", "email_verified")
    op.drop_table("withdrawals")
    op.drop_table("cash_ledger")
