"""Add users.avatar_url + users.cover_url (Edit Profile, 2026-10-05).

The mobile Edit Profile sheet uploads avatar/cover photos and PATCHes
/users/me with avatar_url/cover_url, but the columns never existed so the
backend silently dropped them. This migration adds them idempotently.
"""
from alembic import op
import sqlalchemy as sa

revision = "users_avatar_cover_001"
down_revision = "video_jobs_002"
branch_labels = None
depends_on = None

_COLUMNS = [
    ("avatar_url", sa.String(1024), True, None),
    ("cover_url", sa.String(1024), True, None),
]


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    existing = {c["name"] for c in insp.get_columns("users")}
    for name, coltype, nullable, default in _COLUMNS:
        if name in existing:
            continue
        op.add_column(
            "users",
            sa.Column(
                name,
                coltype,
                nullable=nullable,
                server_default=sa.text(default) if default else None,
            ),
        )


def downgrade() -> None:
    for name, _, _, _ in _COLUMNS:
        try:
            op.drop_column("users", name)
        except Exception:
            pass
