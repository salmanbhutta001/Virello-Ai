"""Trending Topics orchestrator: the robot that keeps topics fresh.

run_trending_update():
    1. analyze_trends()            -> judged candidate topics
    2. for each NEW topic:           generate original content + image, INSERT
    3. for each EXISTING topic seen: refresh trend_score, UPDATE
    4. commit, log a summary, return counts

Idempotent: reruns never duplicate rows (title match is case-insensitive).

SCHEDULING (every 6 hours):
    Railway cron job:
        0 */6 * * *  cd /app && python -m app.services.trending_orchestrator
    or system cron on a VPS:
        0 */6 * * *  cd ~/workspace/virello-app/backend && \
                     /usr/bin/python3 -m app.services.trending_orchestrator
    or call POST /api/v1/trending/refresh (admin) from any scheduler.

Run manually:  python -m app.services.trending_orchestrator
"""
from __future__ import annotations

import asyncio
import logging
import sys

from sqlalchemy import func, select

log = logging.getLogger("virello.trending.orchestrator")


async def run_trending_update(max_new: int = 8) -> dict:
    """Run one robot cycle. Returns {"added", "updated", "candidates"}.

    - New topics (title not in DB): full content + image generation, INSERT.
    - Existing topics (title already in DB): trend_score refreshed toward
      the fresh signal, source noted, UPDATE.
    - Caps new inserts at max_new per cycle to bound AI/image cost.
    """
    from app.core.database import AsyncSessionLocal, init_db
    from app.models.trending import TrendingTopic
    from app.services.trending_images import generate_topic_image
    from app.services.trending_robot import analyze_trends, generate_topic_content

    await init_db()
    candidates = await analyze_trends()

    added, updated = 0, 0
    async with AsyncSessionLocal() as db:
        res = await db.execute(select(TrendingTopic.id, TrendingTopic.title))
        existing = {str(t).strip().lower(): i for i, t in res.all()}

        for cand in candidates:
            key = cand.title.strip().lower()
            if key not in existing:
                if added >= max_new:
                    continue
                try:
                    content = await generate_topic_content(cand)
                    image_url = await generate_topic_image(cand.title, content["category"])
                except Exception as exc:
                    log.warning("orchestrator: skipping %r: %s", cand.title, exc)
                    continue
                topic = TrendingTopic(
                    title=cand.title.strip(),
                    category=content["category"],
                    summary=content["summary"],
                    ai_insight=content["ai_insight"],
                    image_url=image_url,
                    source=f"robot:{cand.source}",
                    trend_score=content["trend_score"],
                )
                db.add(topic)
                added += 1
                log.info("orchestrator: ADDED %r (score %d)", cand.title, cand.score)
            else:
                topic_id = existing[key]
                topic = await db.get(TrendingTopic, topic_id)
                if topic is not None:
                    # Blend: fresh signal moves the score, keeps history smooth.
                    old = topic.trend_score or 0
                    topic.trend_score = int(round(0.6 * old + 0.4 * cand.score))
                    topic.source = f"robot:{cand.source}"
                    updated += 1

        await db.commit()

    summary = {"added": added, "updated": updated, "candidates": len(candidates)}
    log.info("orchestrator: done %s", summary)
    return summary


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
    result = asyncio.run(run_trending_update())
    print(result)


if __name__ == "__main__":
    sys.path.insert(0, ".")
    main()
