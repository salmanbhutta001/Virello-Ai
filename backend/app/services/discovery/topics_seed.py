"""Curated discovery taxonomy (English + Urdu). Seeded on first use."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.growth import Topic

TOPICS: list[tuple[str, str, str]] = [
    ("technology", "Technology", "ٹیکنالوجی"),
    ("business", "Business", "کاروبار"),
    ("fashion", "Fashion", "فیشن"),
    ("food", "Food & Recipes", "کھانے"),
    ("travel", "Travel", "سفر"),
    ("fitness", "Fitness", "فٹنس"),
    ("education", "Education", "تعلیم"),
    ("music", "Music", "موسیقی"),
    ("gaming", "Gaming", "گیمنگ"),
    ("comedy", "Comedy", "مزاح"),
    ("beauty", "Beauty", "خوبصورتی"),
    ("health", "Health", "صحت"),
    ("finance", "Finance", "مالیات"),
    ("sports", "Sports", "کھیل"),
    ("photography", "Photography", "فوٹوگرافی"),
    ("art", "Art & Design", "فن"),
    ("motivation", "Motivation", "حوصلہ افزائی"),
    ("parenting", "Parenting", "والدین"),
    ("realestate", "Real Estate", "جائیداد"),
    ("automobiles", "Automobiles", "گاڑیاں"),
    ("pets", "Pets", "پالتو جانور"),
    ("news", "News", "خبریں"),
    ("lifestyle", "Lifestyle", "طرز زندگی"),
    ("marketing", "Marketing", "مارکیٹنگ"),
]


async def seed_topics(db: AsyncSession) -> int:
    existing = {r[0] for r in (await db.execute(select(Topic.slug))).all()}
    added = 0
    for slug, en, ur in TOPICS:
        if slug not in existing:
            db.add(Topic(slug=slug, name_en=en, name_ur=ur))
            added += 1
    if added:
        await db.commit()
    return added
