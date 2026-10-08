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
    # Same for ad_campaigns.payment_status (2026-10-03: new column backing
    # the AI Ad Builder Buy flow — paid only after store verification).
    await _ensure_ad_campaigns_columns()
    # Same for share_clicks table (2026-10-03: /s/{code} 500s on prod when
    # the table is missing — click logging must never break the redirect).
    await _ensure_share_clicks_table()
    # Same for referral_codes / referral_events (2026-10-08: prod 500 on
    # POST /api/v1/auth/password/signup — award_referral_credits UPDATEs
    # referral_events, which Alembic never created on prod and create_all
    # missed. Signup must never depend on these tables existing).
    await _ensure_referral_tables()


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


async def _ensure_ad_campaigns_columns() -> None:
    """Add ad_campaigns.payment_status if missing. Idempotent.

    Backs the AI Ad Builder Buy flow (2026-10-03): the column is set to
    "paid" only by the billing verify endpoints after the store confirms
    the matching ad-package purchase. Follows the users/products/video_jobs
    ensure pattern — prod Alembic is unreliable. Never crashes boot.
    """
    import sqlalchemy as sa

    try:
        async with engine.begin() as conn:
            existing = await conn.run_sync(
                lambda c: {col["name"] for col in sa.inspect(c).get_columns("ad_campaigns")}
            )
            if "payment_status" in existing:
                return
            try:
                await conn.execute(sa.text(
                    'ALTER TABLE ad_campaigns ADD COLUMN "payment_status" '
                    "VARCHAR(16) DEFAULT 'unpaid'"
                ))
                print("init_db: added missing ad_campaigns.payment_status")
            except Exception as e:
                print(f"init_db: could not add ad_campaigns.payment_status: {e}")
    except Exception as e:
        print(f"init_db: ad_campaigns column check non-fatal ({type(e).__name__}): {e}")


async def _ensure_share_clicks_table() -> None:
    """Create the share_clicks table if missing. Idempotent.

    Backs GET /s/{code} click logging (2026-10-03): prod returned 500 on
    share links when the table was missing. The handler is now resilient
    (redirect always happens), but the table should exist for the +25
    points attribution to work. Follows the existing ensure pattern —
    prod Alembic is unreliable. Never crashes boot.
    """
    import sqlalchemy as sa

    try:
        async with engine.begin() as conn:
            tables = await conn.run_sync(
                lambda c: sa.inspect(c).get_table_names()
            )
            if "share_clicks" in tables:
                return
            # Create just this table from metadata.
            from app.models.rewards import ShareClick
            await conn.run_sync(
                lambda c: ShareClick.__table__.create(c, checkfirst=True)
            )
            print("init_db: created missing share_clicks table")
    except Exception as e:
        print(f"init_db: share_clicks table check non-fatal ({type(e).__name__}): {e}")


async def _ensure_referral_tables() -> None:
    """Create referral_codes / referral_events if missing. Idempotent.

    Backs POST /api/v1/auth/password/signup (2026-10-08): prod 500'd
    because award_referral_credits UPDATEs referral_events, which no
    Alembic migration ever created on prod. The signup path is also
    hardened to survive the tables being absent, but they should exist
    for the referral loop to work. Follows the existing ensure pattern —
    prod Alembic is unreliable. Never crashes boot.
    """
    import sqlalchemy as sa

    try:
        async with engine.begin() as conn:
            tables = await conn.run_sync(
                lambda c: sa.inspect(c).get_table_names()
            )
            missing = [t for t in ("referral_codes", "referral_events")
                       if t not in tables]
            if not missing:
                return
            from app.models.referrals import ReferralCode, ReferralEvent
            by_name = {"referral_codes": ReferralCode,
                       "referral_events": ReferralEvent}
            for t in missing:
                await conn.run_sync(
                    lambda c, tbl=by_name[t]: tbl.__table__.create(
                        c, checkfirst=True)
                )
            print(f"init_db: created missing tables {missing}")
    except Exception as e:
        print(f"init_db: referral tables check non-fatal ({type(e).__name__}): {e}")
