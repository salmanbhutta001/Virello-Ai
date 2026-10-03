"""Async database: engine, session factory, FastAPI dependency, dev init.

Postgres (asyncpg) in production; SQLite (aiosqlite) for local dev —
pick via VIRELLO_DATABASE_URL.
"""
from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.models.core import Base

connect_args: dict = {}
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_async_engine(
    settings.database_url,
    connect_args=connect_args,
    pool_pre_ping=True,
)

SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session


async def init_db() -> None:
    """Create tables. Dev bootstrap — production uses Alembic migrations.

    Tolerant of "already exists" errors (e.g. orphaned PG enum types from
    partial runs): production must never crash on startup because a type
    or table is already there. Alembic owns the schema in prod.
    """
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except Exception as e:
        # Log and continue — tables/types may already exist. Alembic
        # migrations are the source of truth in production.
        print(f"init_db: non-fatal ({type(e).__name__}): {e}")
    # Belt-and-suspenders: ensure critical users-table columns exist even
    # if Alembic is wedged (2026-09-30 login 500: password_hash etc. were
    # missing on prod because no migration ever added them). Idempotent.
    await _ensure_users_columns()
    # Same for products trend columns (2026-10-01: trending_001 never
    # applied on prod; without these every product query 500s).
    await _ensure_products_trend_columns()
    # Same for video_jobs.agnes_id (2026-10-03: created as VARCHAR(128) by
    # create_all, but Agnes returns longer IDs -> widen to TEXT).
    await _ensure_video_jobs_columns()


async def _ensure_users_columns() -> None:
    """Add any missing columns to the users table. Runs on every startup."""
    import sqlalchemy as sa

    cols = [
        ("suspended", "BOOLEAN", "false"),
        ("email_verified", "BOOLEAN", "false"),
        ("password_hash", "VARCHAR(255)", None),
        ("password_updated_at", "TIMESTAMP WITH TIME ZONE", None),
        ("preferred_language", "VARCHAR(16)", "'en'"),
        ("all_relevant_languages", "BOOLEAN", "false"),
        ("credits", "INTEGER", "300"),
    ]
    try:
        async with engine.begin() as conn:
            existing = await conn.run_sync(
                lambda c: {col["name"] for col in sa.inspect(c).get_columns("users")}
            )
            for name, ctype, default in cols:
                if name in existing:
                    continue
                ddl = f'ALTER TABLE users ADD COLUMN "{name}" {ctype}'
                if default is not None:
                    ddl += f" DEFAULT {default}"
                try:
                    await conn.execute(sa.text(ddl))
                    print(f"init_db: added missing users.{name}")
                except Exception as e:
                    print(f"init_db: could not add users.{name}: {e}")
    except Exception as e:
        print(f"init_db: column check non-fatal ({type(e).__name__}): {e}")


async def _ensure_products_trend_columns() -> None:
    """Add missing trend columns to the products table. Idempotent.

    Production Alembic has multiple roots and never cleanly applies, so
    the trending_001 migration's columns are ensured here like the users
    table columns above. Runs on every startup; never crashes boot.
    """
    import sqlalchemy as sa

    cols = [
        ("trend_score", "INTEGER", "0"),
        ("trend_signals", "TEXT", "''"),
        ("trending_as_of", "TIMESTAMP WITH TIME ZONE", None),
    ]
    try:
        async with engine.begin() as conn:
            existing = await conn.run_sync(
                lambda c: {col["name"] for col in sa.inspect(c).get_columns("products")}
            )
            for name, ctype, default in cols:
                if name in existing:
                    continue
                ddl = f'ALTER TABLE products ADD COLUMN "{name}" {ctype}'
                if default is not None:
                    ddl += f" DEFAULT {default}"
                try:
                    await conn.execute(sa.text(ddl))
                    print(f"init_db: added missing products.{name}")
                except Exception as e:
                    print(f"init_db: could not add products.{name}: {e}")
            if "trend_score" not in existing:
                try:
                    await conn.execute(
                        sa.text('CREATE INDEX IF NOT EXISTS ix_products_trend_score ON products (trend_score)')
                    )
                except Exception as e:
                    print(f"init_db: could not create trend index: {e}")
    except Exception as e:
        print(f"init_db: products trend column check non-fatal ({type(e).__name__}): {e}")


async def _ensure_video_jobs_columns() -> None:
    """Widen video_jobs.agnes_id to TEXT if still VARCHAR. Idempotent.

    Production Alembic does not reliably apply migrations, so the
    video_jobs_002 alter is ensured here like the users/products columns
    above. Runs on every startup; never crashes boot.
    """
    import sqlalchemy as sa

    try:
        async with engine.begin() as conn:
            cols = await conn.run_sync(
                lambda c: {col["name"]: col for col in sa.inspect(c).get_columns("video_jobs")}
            )
            agnes = cols.get("agnes_id")
            if agnes is None:
                return  # table not created yet; create_all above handles it
            ctype = str(agnes["type"]).upper()
            if "VARCHAR(128)" in ctype or ctype == "VARCHAR":
                try:
                    await conn.execute(
                        sa.text("ALTER TABLE video_jobs ALTER COLUMN agnes_id TYPE TEXT")
                    )
                    print("init_db: widened video_jobs.agnes_id to TEXT")
                except Exception as e:
                    print(f"init_db: could not widen video_jobs.agnes_id: {e}")
    except Exception as e:
        print(f"init_db: video_jobs column check non-fatal ({type(e).__name__}): {e}")
