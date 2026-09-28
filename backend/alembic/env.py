"""Alembic env for Virello — async engine + autogenerate-capable metadata.

The app's real DATABASE_URL comes from the VIRELLO_DATABASE_URL env var
(via app.core.config.settings); alembic.ini's sqlalchemy.url is only a
fallback default.
"""
import asyncio
import os
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# Import every model module so Base.metadata covers the whole schema.
import app.models.billing  # noqa: F401
import app.models.core  # noqa: F401
import app.models.growth  # noqa: F401
import app.models.growth_engine  # noqa: F401
import app.models.social_metrics  # noqa: F401
import app.models.ads  # noqa: F401
import app.models.ad_delivery  # noqa: F401  (phase 2 sponsored delivery)
import app.models.ad_attribution  # noqa: F401  (phase 4 conversion attribution)
import app.models.social  # noqa: F401  (follow graph for the Following tab)
import app.models.audience_sources  # noqa: F401  (audience intelligence graph)
import app.models.collab  # noqa: F401  (creator collab match)
import app.models.community  # noqa: F401  (community directory)
from app.core.database import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Real DB URL wins over alembic.ini.
db_url = os.getenv("VIRELLO_DATABASE_URL")
if db_url:
    config.set_main_option("sqlalchemy.url", db_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    """Run migrations in 'online' mode with the app's async engine style."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
