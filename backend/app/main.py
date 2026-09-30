"""Virello backend — FastAPI. Secure, scalable, audit-logged."""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import init_db
from app.curation import routes as curation_routes  # registers curation models
from app.routers import auth, users, campaigns, ai, billing, analytics, admin, ws, support
from app.routers import analysis as analysis_router
from app.routers import viral_lab as viral_lab_router
from app.routers import create as create_router
from app.routers import audience as audience_router
from app.routers import languages as languages_router
from app.routers import ads as ads_router
from app.routers import discovery as discovery_router
from app.routers import growth_engine as growth_router
from app.routers import social_metrics as social_metrics_router
from app.routers import social as social_router
from app.routers import uploads as uploads_router
from app.routers import content as content_router
from app.routers import seeding as seeding_router
from app.routers import communities as communities_router
from app.routers import collab as collab_router
from app.routers import referrals as referrals_router
from app.routers import ai_core as ai_core_router
from app.routers import commerce as commerce_router
from app.routers import ctr as ctr_router
from app.routers import academy as academy_router
from app.routers import entertain as entertain_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()  # dev bootstrap; production uses Alembic migrations
    # Autonomous hourly product curation — must never crash the app.
    _sched = None
    try:
        from app.curation.scheduler import start_curation_scheduler
        _sched = start_curation_scheduler()
    except Exception:
        import logging
        logging.getLogger("virello").exception(
            "curation scheduler wiring failed; continuing without it")
    try:
        yield
    finally:
        try:
            from app.curation.scheduler import stop_curation_scheduler
            stop_curation_scheduler(_sched)
        except Exception:
            pass


app = FastAPI(
    title="Virello API",
    description="Your AI Growth Manager — legitimate AI-powered social growth.",
    version="0.1.0",
    lifespan=lifespan,
)

# Product gallery images.
# GET /gallery/{filename} is served by the curation routes: volume-first
# (VIRELLO_GALLERY_DIR, e.g. Railway /data/gallery), falling back to the
# git-committed backend/app/static/gallery. No auth needed for display.
# GET /api/v1/curation/status is the admin-only curation monitor.
app.include_router(curation_routes.router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
app.include_router(campaigns.router, prefix="/api/v1/campaigns", tags=["campaigns"])
app.include_router(ai.router, prefix="/api/v1/ai", tags=["ai"])
app.include_router(support.router, prefix="/api/v1/support", tags=["support"])
app.include_router(billing.router, prefix="/api/v1/billing", tags=["billing"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["analytics"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["admin"])
app.include_router(analysis_router.router, prefix="/api/v1/analysis", tags=["analysis"])
app.include_router(viral_lab_router.router, prefix="/api/v1/analysis", tags=["viral-lab"])
app.include_router(create_router.router, prefix="/api/v1/create", tags=["create"])
app.include_router(discovery_router.router, prefix="/api/v1/discovery", tags=["discovery"])
app.include_router(audience_router.router, prefix="/api/v1/audience", tags=["audience"])
app.include_router(languages_router.router, prefix="/api/v1/languages", tags=["languages"])
app.include_router(ads_router.router, prefix="/api/v1/ads", tags=["ads"])
app.include_router(growth_router.router, prefix="/api/v1/growth", tags=["growth-engine"])
app.include_router(social_metrics_router.router, prefix="/api/v1/social-metrics",
                   tags=["social-metrics"])
app.include_router(social_router.router, prefix="/api/v1/social",
                   tags=["social"])
app.include_router(uploads_router.router, prefix="/api/v1/uploads", tags=["uploads"])
app.include_router(content_router.router, prefix="/api/v1/content", tags=["content"])
app.include_router(seeding_router.router, prefix="/api/v1/seeding", tags=["seeding"])
app.include_router(communities_router.router, prefix="/api/v1", tags=["communities"])
app.include_router(collab_router.router, prefix="/api/v1/collab", tags=["collab"])
app.include_router(referrals_router.router, prefix="/api/v1/referrals", tags=["referrals"])
app.include_router(ai_core_router.router, prefix="/api/v1", tags=["ai-core"])
app.include_router(academy_router.router, prefix="/api/v1", tags=["academy"])
app.include_router(entertain_router.router, prefix="/api/v1", tags=["entertain"])
app.include_router(commerce_router.router, prefix="/api/v1", tags=["commerce"])
app.include_router(ctr_router.router, prefix="/api/v1/content", tags=["content"])
app.include_router(ws.router, prefix="/api/v1")  # WebSocket: /api/v1/campaigns/{id}/stream


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "virello-api"}


@app.get("/c/{campaign_id}")
async def campaign_redirect(campaign_id: str):
    """Public trackable campaign link.

    No auth — this is a shareable URL. Logs one genuine click in
    MetricDaily, then 302-redirects to the campaign's real post_url.
    Only real HTTP visits are counted. Bots hitting /health etc are
    not counted (this endpoint only).
    """
    import uuid as uuid_mod
    from fastapi.responses import RedirectResponse
    from sqlalchemy import select
    from app.core.database import SessionLocal
    from app.models.core import Campaign, MetricDaily
    from datetime import date

    try:
        cid = uuid_mod.UUID(campaign_id)
    except ValueError:
        from fastapi import HTTPException
        raise HTTPException(404, "Not found")

    async with SessionLocal() as db:
        res = await db.execute(
            select(Campaign).where(Campaign.id == cid)
        )
        campaign = res.scalar_one_or_none()
        if campaign is None:
            from fastapi import HTTPException
            raise HTTPException(404, "Not found")

        # Log one genuine click for today
        today = date.today().isoformat()
        mres = await db.execute(
            select(MetricDaily).where(
                MetricDaily.campaign_id == cid,
                MetricDaily.day == today,
            )
        )
        metric = mres.scalar_one_or_none()
        if metric is None:
            metric = MetricDaily(campaign_id=cid, day=today)
            db.add(metric)
        metric.clicks = (metric.clicks or 0) + 1
        metric.reach = (metric.reach or 0) + 1
        await db.commit()

        return RedirectResponse(url=campaign.post_url, status_code=302)
