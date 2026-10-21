"""Container-start seed entry: python -m app.blog.seed_run (idempotent)."""
import asyncio

from app.blog.seed import seed_blog_posts
from app.core.database import SessionLocal, init_db


async def _main() -> None:
    await init_db()
    async with SessionLocal() as db:
        await seed_blog_posts(db)


if __name__ == "__main__":
    asyncio.run(_main())
