"""Add product trend scoring for the genuinely-trending rail.

trend_score: 0-100, assigned by the curator from real research
  (bestseller ranks, review velocity, trend data). 0 = not scored.
trend_signals: short honest note, e.g. "amazon bestseller #3 in LED strips".
trending_as_of: when the score was last validated — the trending sort
  time-decays the score so the rail keeps updating.
"""
from alembic import op
import sqlalchemy as sa

revision = "trending_001"
down_revision = "users_password_auth_001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("products",
                  sa.Column("trend_score", sa.Integer(), server_default="0", nullable=False))
    op.add_column("products",
                  sa.Column("trend_signals", sa.Text(), server_default="", nullable=False))
    op.add_column("products", sa.Column("trending_as_of", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_products_trend_score", "products", ["trend_score"])


def downgrade():
    op.drop_index("ix_products_trend_score", table_name="products")
    op.drop_column("products", "trending_as_of")
    op.drop_column("products", "trend_signals")
    op.drop_column("products", "trend_score")
