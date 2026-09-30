"""Add missing users-table columns (password auth, 2026-09-30).

The users table was created early via init_db/create_all; later model
columns (password_hash, suspended, email_verified, ...) never got a
migration, so production SELECTs that touch them 500 (e.g. POST
/api/v1/auth/password/login). This migration adds any missing columns
idempotently.
"""
from alembic import op
import sqlalchemy as sa

revision = "users_password_auth_001"
down_revision = "merge_heads_001"
branch_labels = None
depends_on = None

# (name, type, nullable, server_default)
_COLUMNS = [
    ("suspended", sa.Boolean(), False, "false"),
    ("email_verified", sa.Boolean(), False, "false"),
    ("password_hash", sa.String(255), True, None),
    ("password_updated_at", sa.DateTime(timezone=True), True, None),
    ("preferred_language", sa.String(16), False, "'en'"),
    ("content_languages", sa.JSON(), True, None),
    ("all_relevant_languages", sa.Boolean(), False, "false"),
    ("credits", sa.Integer(), False, "300"),
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
