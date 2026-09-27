"""Celery app. Eager mode (VIRELLO_CELERY_EAGER=true) runs tasks inline — no Redis needed."""
from celery import Celery

from app.core.config import settings

celery = Celery("virello", broker=settings.redis_url, backend=settings.redis_url)
celery.conf.update(
    task_always_eager=settings.celery_eager,
    task_eager_propagates=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    beat_schedule={
        # Production: monitor live campaigns every 5 min (analytics -> optimization loop).
        "monitor-live-campaigns": {
            "task": "virello.pipeline.monitor_live",
            "schedule": 300.0,
        },
        # AI Growth Engine: run due measure -> learn -> optimize rounds every 15 min.
        "growth-engine-tick": {
            "task": "virello.growth.tick",
            "schedule": 900.0,
        },
        # Ads Distribution & Optimization Agent: reweight active ad campaigns
        # from measured genuine events every hour (guarded internally to
        # OPTIMIZE_INTERVAL_HOURS per campaign).
        "ads-optimization-tick": {
            "task": "virello.ads.optimize_tick",
            "schedule": 3600.0,
        },
    },
)
