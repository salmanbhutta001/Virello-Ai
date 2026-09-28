"""Seed the community directory. Run once after migration.

Usage: cd backend && python -m app.data.seed_communities_run
"""
import asyncio
import sys

sys.path.insert(0, ".")

from sqlalchemy import select, func
from app.core.database import SessionLocal
from app.models.community import Community
from app.data.seed_communities import SEED_COMMUNITIES


async def main():
    async with SessionLocal() as db:
        existing = (await db.execute(select(func.count(Community.id)))).scalar() or 0
        if existing > 0:
            print(f"Communities already seeded ({existing} rows). Skipping.")
            return
        for c in SEED_COMMUNITIES:
            db.add(Community(**c))
        await db.commit()
        print(f"Seeded {len(SEED_COMMUNITIES)} communities.")


if __name__ == "__main__":
    asyncio.run(main())
