"""Seed script for trending topics.

Run: python -m app.data.seed_trending_topics
Idempotent: skips topics whose title already exists.

All summaries are ORIGINAL — written fresh, not copied from Wikipedia,
Google Trends, or any other source.
"""
from __future__ import annotations

import asyncio
import sys

sys.path.insert(0, ".")

from sqlalchemy import select

from app.core.database import AsyncSessionLocal, init_db
from app.models.trending import TrendingTopic

SEED_TOPICS = [
    {
        "title": "AI Video Generation Tools",
        "category": "technology",
        "summary": (
            "Text-to-video AI has moved from novelty to practical tool. Creators "
            "are using it for B-roll, product demos, and short-form content that "
            "would have needed a full shoot last year. The quality jump in 2026 "
            "means audiences often can't tell the difference."
        ),
        "ai_insight": "Post a side-by-side: your old editing workflow vs the AI version — time saved is the hook.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 95,
    },
    {
        "title": "Sustainable Fashion",
        "category": "fashion",
        "summary": (
            "Thrift flips, capsule wardrobes, and repair-over-replace content keeps "
            "growing as clothing prices rise. Viewers respond most to honest cost "
            "breakdowns — showing the real math of sustainable choices beats "
            "preachy messaging every time."
        ),
        "ai_insight": "Film a 'cost per wear' breakdown of one outfit — numbers outperform opinions.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 88,
    },
    {
        "title": "Home Workout Routines",
        "category": "fitness",
        "summary": (
            "No-equipment workouts remain evergreen, but the format has shifted: "
            "short follow-along routines under 10 minutes dominate saves and "
            "shares. Bodyweight strength progressions get more engagement than "
            "generic cardio compilations."
        ),
        "ai_insight": "Structure it as day 1 vs day 30 — transformation arcs drive follows.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 85,
    },
    {
        "title": "Personal Finance Apps",
        "category": "finance",
        "summary": (
            "Budgeting and micro-investing apps are trending as younger audiences "
            "look for control over small amounts of money. Content that shows a "
            "real screen recording of setting up a budget beats talking-head "
            "advice — people want to see the taps, not hear theory."
        ),
        "ai_insight": "Screen-record your actual setup with real numbers blurred — authenticity converts.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 82,
    },
    {
        "title": "Plant-Based Recipes",
        "category": "food",
        "summary": (
            "High-protein plant-based meals are the current wave — the audience "
            "isn't fully vegan, just curious. Recipes under 15 minutes with "
            "pantry staples get saved at far higher rates than elaborate "
            "weekend-project dishes."
        ),
        "ai_insight": "Lead with the protein grams in the first 2 seconds — that's the search intent.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 80,
    },
    {
        "title": "Remote Work Tools",
        "category": "technology",
        "summary": (
            "Async collaboration stacks are having a moment as distributed teams "
            "become the default. The content that performs best isn't tool lists — "
            "it's 'my actual workflow' walkthroughs showing how someone strings "
            "three or four tools together across a real workday."
        ),
        "ai_insight": "Show your real Monday morning routine, tools and all — process beats product lists.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 78,
    },
    {
        "title": "Urban Gardening",
        "category": "home",
        "summary": (
            "Balcony and windowsill growing keeps climbing as food prices push "
            "people toward small-scale self-sufficiency. Beginner-friendly "
            "content wins: 'what I grew in 30 days with $20' outperforms "
            "expert-level hydroponic builds for reach."
        ),
        "ai_insight": "Document week 1 to harvest in one timelapse — progress content is inherently bingeable.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 75,
    },
    {
        "title": "Digital Detox Challenges",
        "category": "lifestyle",
        "summary": (
            "Screen-time reduction challenges resurface every few months, and each "
            "wave is bigger. The twist now: creators track it with data — posting "
            "their actual screen-time graphs before and after. The numbers make "
            "it credible instead of performative."
        ),
        "ai_insight": "Post your real screen-time screenshot on day 1 — vulnerability is the engagement driver.",
        "image_url": "",
        "source": "web trends",
        "trend_score": 72,
    },
]


async def seed() -> None:
    await init_db()
    async with AsyncSessionLocal() as db:
        added = 0
        for item in SEED_TOPICS:
            existing = await db.execute(
                select(TrendingTopic).where(TrendingTopic.title == item["title"])
            )
            if existing.scalar_one_or_none() is not None:
                print(f"SKIP (exists): {item['title']}")
                continue
            db.add(TrendingTopic(**item))
            added += 1
            print(f"ADD: {item['title']}")
        await db.commit()
    print(f"Done: {added} new topics seeded.")


if __name__ == "__main__":
    asyncio.run(seed())
