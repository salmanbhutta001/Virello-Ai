"""Daily blog scheduler (APScheduler, Asia/Karachi).

Wired into the FastAPI lifespan in app/main.py next to the curation
scheduler. Never crashes the app: any failure to start is logged and
the API boots normally.
"""
from __future__ import annotations

import logging

from app.blog import config

log = logging.getLogger("virello.blog.scheduler")

_JOB_ID = "virello-daily-blog"


async def _job() -> None:
    from app.blog.generator import generate_article
    from app.core.database import SessionLocal

    log.info("blog job starting")
    try:
        async with SessionLocal() as db:
            result = await generate_article(db)
        log.info("blog job finished: %s", result)
    except Exception:
        log.exception("blog job crashed")


def start_blog_scheduler():
    """Start the daily job. Returns the scheduler, or None when disabled /
    unavailable (never raises)."""
    if not config.blog_enabled():
        log.info("blog scheduler disabled (VIRELLO_BLOG_AUTONOMOUS=false)")
        return None
    try:
        from apscheduler.schedulers.asyncio import AsyncIOScheduler
        from apscheduler.triggers.cron import CronTrigger
    except ImportError:
        log.warning("apscheduler not installed — blog scheduler not started")
        return None
    try:
        sched = AsyncIOScheduler(timezone="Asia/Karachi")
        sched.add_job(
            _job,
            CronTrigger(hour=config.blog_hour(),
                        minute=config.blog_minute()),
            id=_JOB_ID,
            max_instances=1,
            coalesce=True,
            misfire_grace_time=3600,
            replace_existing=True,
        )
        sched.start()
        log.info("blog scheduler started (daily %02d:%02d Asia/Karachi)",
                 config.blog_hour(), config.blog_minute())
        return sched
    except Exception:
        log.exception("blog scheduler failed to start")
        return None


def stop_blog_scheduler(sched) -> None:
    try:
        if sched is not None:
            sched.shutdown(wait=False)
    except Exception:
        log.exception("blog scheduler shutdown failed")
