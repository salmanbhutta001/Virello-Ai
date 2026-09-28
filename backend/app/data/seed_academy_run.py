"""Seed the AI Academy lessons. Run once after migration.

Usage: cd backend && python -m app.data.seed_academy_run
"""
import asyncio
import sys

sys.path.insert(0, ".")

from sqlalchemy import select, func
from app.core.database import SessionLocal
from app.models.academy import Lesson
from app.data.seed_academy import SEED_LESSONS


async def main():
    async with SessionLocal() as db:
        existing = (await db.execute(select(func.count(Lesson.id)))).scalar() or 0
        if existing > 0:
            print(f"Academy lessons already seeded ({existing} rows). Skipping.")
            return
        for lesson in SEED_LESSONS:
            db.add(Lesson(**lesson))
        await db.commit()
        print(f"Seeded {len(SEED_LESSONS)} academy lessons.")


if __name__ == "__main__":
    asyncio.run(main())
