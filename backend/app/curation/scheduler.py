"""Hourly curation scheduler (APScheduler, Asia/Karachi).

Wired into the FastAPI lifespan in app/main.py. Never crashes the app:
any failure to start is logged and the API boots normally.

The job opens its own DB session (it runs outside any request) and calls
run_curation_cycle(). Overlapping runs are prevented (max_instances=1);
a missed run while the process was down is NOT backfilled (coalesce).
"""
from __future__ import annotations

import logging

from app.curation import config

log = logging.getLogger("virello.curation.scheduler")

_JOB_ID = "virello-hourly-curation"


async def _job() -> None:
    from app.core.database import SessionLocal
    from app.curation.service import run_curation_cycle

    log.info("curation job starting")
    try:
        async with SessionLocal() as db:
            report = await run_curation_cycle(db)
        log.info("curation job finished: %s (%s/%s departments, %s created)",
                 report.get("status"),
                 report.get("departments_covered"),
                 len(config.DEPARTMENTS),
                 report.get("products_created"))
    except Exception:
        log.exception("curation job crashed")


def start_curation_scheduler():
    """Start the hourly job. Returns the scheduler, or None when disabled /
    unavailable (never raises)."""
    if not config.curation_enabled():
        log.info("curation scheduler disabled "
                 "(VIRELLO_CURATION_AUTONOMOUS=false)")
        return None
    try:
        from apscheduler.schedulers.asyncio import AsyncIOScheduler
        from apscheduler.triggers.interval import IntervalTrigger
    except ImportError:
        log.warning("apscheduler not installed — curation scheduler not "
                    "started (add apscheduler to requirements)")
        return None
    try:
        sched = AsyncIOScheduler(timezone="Asia/Karachi")
        sched.add_job(
            _job,
            IntervalTrigger(hours=config.curation_interval_hours()),
            id=_JOB_ID,
            max_instances=1,
            coalesce=True,
            misfire_grace_time=1800,
            replace_existing=True,
        )
        sched.start()
        log.info("curation scheduler started (every %sh, Asia/Karachi)",
                 config.curation_interval_hours())
        return sched
    except Exception:
        log.exception("curation scheduler failed to start")
        return None


def stop_curation_scheduler(sched) -> None:
    try:
        if sched is not None:
            sched.shutdown(wait=False)
    except Exception:
        log.exception("curation scheduler shutdown failed")
