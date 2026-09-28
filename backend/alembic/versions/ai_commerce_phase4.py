"""AI Commerce (Phase 4): product catalog, shareable pages, leads, orders.

Revision ID: ai_commerce_001
Revises: ai_core_001
Create Date: 2026-09-29

Additive only:
- products: id (uuid pk), creator_id fk, title, description, price_cents,
  currency, category, image_urls (json), stock_qty, is_active, views,
  created_at, updated_at.
- product_pages: id (uuid pk), product_id fk unique, slug unique, views,
  created_at.
- commerce_leads: id (uuid pk), product_id fk, user_id fk nullable,
  source, status, created_at.
- commerce_orders: id (uuid pk), product_id fk, buyer_id fk,
  amount_cents, currency, payment_provider, provider_txn_id,
  transaction_id fk nullable, status, created_at, updated_at.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from app.models.core import GUID

revision: str = "ai_commerce_001"
down_revision: Union[str, None] = "ai_core_001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "products",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("creator_id", GUID(), sa.ForeignKey("users.id"),
                  nullable=False, index=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("price_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(8), nullable=False, server_default="USD"),
        sa.Column("category", sa.String(64), nullable=False,
                  server_default="all", index=True),
        sa.Column("image_urls", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("stock_qty", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False,
                  server_default=sa.true(), index=True),
        sa.Column("views", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("affiliate_url", sa.Text(), nullable=True),
        sa.Column("affiliate_provider", sa.String(32), nullable=True),
        sa.Column("is_affiliate", sa.Boolean(), nullable=False,
                  server_default=sa.false(), index=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "product_pages",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("product_id", GUID(), sa.ForeignKey("products.id"),
                  nullable=False, unique=True, index=True),
        sa.Column("slug", sa.String(128), nullable=False, unique=True, index=True),
        sa.Column("views", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "commerce_leads",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("product_id", GUID(), sa.ForeignKey("products.id"),
                  nullable=False, index=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id"),
                  nullable=True, index=True),
        sa.Column("source", sa.String(32), nullable=False, server_default="shop"),
        sa.Column("status", sa.String(32), nullable=False, server_default="new"),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "commerce_orders",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("product_id", GUID(), sa.ForeignKey("products.id"),
                  nullable=False, index=True),
        sa.Column("buyer_id", GUID(), sa.ForeignKey("users.id"),
                  nullable=False, index=True),
        sa.Column("amount_cents", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(8), nullable=False, server_default="USD"),
        sa.Column("payment_provider", sa.String(32), nullable=False,
                  server_default=""),
        sa.Column("provider_txn_id", sa.String(128), nullable=False,
                  server_default=""),
        sa.Column("transaction_id", GUID(), sa.ForeignKey("transactions.id"),
                  nullable=True, index=True),
        sa.Column("status", sa.String(32), nullable=False,
                  server_default="created", index=True),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("commerce_orders")
    op.drop_table("commerce_leads")
    op.drop_table("product_pages")
    op.drop_table("products")
