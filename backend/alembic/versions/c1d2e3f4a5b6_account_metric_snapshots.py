"""account-level metric snapshots (metrics agent backend).

Revision ID: c1d2e3f4a5b6
Revises: ai_core_001
Create Date: 2026-10-15

Additive only:
- account_metric_snapshots: id (GUID pk), user_id FK -> users.id (index),
  platform (index), account_ref, metrics (JSON, METRIC_KEYS shape),
  source (e.g. "instagram:account-insights"), period_days (default 7),
  captured_at (index). Written by the MetricsAgent worker via
  POST /api/v1/social-metrics/account/snapshot (service-token auth);
  read by the dashboard via /account/latest and /account/timeseries.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

import app.models.core


# revision identifiers, used by Alembic.
revision: str = 'c1d2e3f4a5b6'
down_revision: Union[str, Sequence[str], None] = 'ai_core_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'account_metric_snapshots',
        sa.Column('id', app.models.core.GUID(length=36), primary_key=True),
        sa.Column('user_id', app.models.core.GUID(length=36),
                  sa.ForeignKey('users.id', ondelete='CASCADE'),
                  nullable=False, index=True),
        sa.Column('platform', sa.String(32), nullable=False, index=True),
        sa.Column('account_ref', sa.String(255), nullable=False, default=''),
        sa.Column('metrics', sa.JSON(), nullable=False, default=dict),
        sa.Column('source', sa.String(64), nullable=False, default=''),
        sa.Column('period_days', sa.Integer(), nullable=False, default=7),
        sa.Column('captured_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now(), index=True),
    )


def downgrade() -> None:
    op.drop_table('account_metric_snapshots')
