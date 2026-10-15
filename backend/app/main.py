"""Virello backend — FastAPI. Secure, scalable, audit-logged."""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.core.database import init_db
from app.curation import routes as curation_routes  # registers curation models
from app.routers import auth, users, campaigns, ai, billing, analytics, admin, ws, support
from app.routers import rewards as rewards_router
from app.routers import notifications as notifications_router
from app.routers import wallet as wallet_router
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
from app.routers import shop as shop_router
from app.routers import video as video_router
from app.routers import trending as trending_router
from app.routers import media as media_router
from app.routers import distribution as distribution_router


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


# Permanent public legal pages (Hafiz 2026-10-03: APKPure/Uptodown/Aptoide
# listings require a non-expiring Privacy Policy URL).
_PRIVACY_HTML = """<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Privacy Policy — Virello AI</title>
<style>body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:800px;
margin:0 auto;padding:24px;line-height:1.6;color:#222}h1{color:#d6336c}
h2{color:#333;margin-top:32px}p,li{color:#444}.updated{color:#888;font-size:14px}</style>
</head><body><h1>Privacy Policy — Virello AI</h1>
<p class="updated">Last updated: October 8, 2026</p>
<p><strong>App:</strong> Virello AI &nbsp;|&nbsp; <strong>Developer:</strong> Hafiz Muhmmad Salman</p>
<p>Virello AI ("we", "our", "us") is an AI-powered social media growth platform.
This Privacy Policy explains what data we collect, how we use it, and your rights.</p>
<h2>1. Data We Collect</h2><ul>
<li><strong>Account data:</strong> email address and name when you sign up or log in
(including via Google or Apple sign-in).</li>
<li><strong>Content you create:</strong> text prompts, images, and videos you generate
with our AI tools.</li>
<li><strong>Usage data:</strong> app interactions, feature usage, and campaign
performance analytics to improve the service.</li>
<li><strong>Device data:</strong> device model, OS version, and app version for
compatibility and crash diagnostics.</li>
<li><strong>Purchase data:</strong> subscription and in-app purchase records processed
securely by Google Play Billing or Amazon Appstore (we never see your full payment
card details).</li></ul>
<h2>2. How We Use Data</h2><ul>
<li>To provide and improve the app's features (AI generation, campaigns, shop, academy).</li>
<li>To process subscriptions and reward points.</li>
<li>To send important service notifications.</li>
<li>To detect fraud and keep the platform safe.</li></ul>
<p>We do <strong>not</strong> sell your personal data. We do not use fake engagement,
bots, or resold traffic.</p>
<h2>3. Third-Party Services</h2><ul>
<li><strong>Google Play Billing / Amazon Appstore:</strong> process payments under
their own privacy policies.</li>
<li><strong>Amazon Associates:</strong> product links in the Shop carry our affiliate
tag; Amazon handles any purchase under its own policy.</li>
<li><strong>AI providers:</strong> prompts you submit may be processed by our AI
service providers to generate content.</li>
<li><strong>Cloudinary:</strong> hosts product and user-uploaded images.</li></ul>
<h2>4. Data Storage &amp; Security</h2>
<p>Data is stored on secure servers with encryption in transit (HTTPS). Access is
limited to authorized personnel only.</p>
<h2>5. Your Rights</h2>
<p>You may request access, correction, or deletion of your personal data at any time
by contacting us at the email below. Deleting your account removes your personal
data from our active systems.</p>
<h2>6. Children's Privacy</h2>
<p>Virello AI is not directed at children under 13. We do not knowingly collect data
from children under 13.</p>
<h2>7. Changes</h2>
<p>We may update this policy; the "Last updated" date will reflect changes. Continued
use of the app after changes means you accept the updated policy.</p>
<h2>8. Contact</h2>
<p><strong>Developer:</strong> Hafiz Muhmmad Salman<br>
<strong>App:</strong> Virello AI<br>
For privacy questions or data requests: <strong>alif01fiverr@gmail.com</strong></p>
<p class="updated">© 2026 Hafiz Muhmmad Salman — Virello AI. All rights reserved.</p>
</body></html>"""


@app.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
async def privacy_policy():
    """Public permanent Privacy Policy page for store listings."""
    return HTMLResponse(content=_PRIVACY_HTML)

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
app.include_router(rewards_router.router, prefix="/api/v1/rewards", tags=["rewards"])
# Share-to-earn public redirect links live at the root: /s/{code}
app.include_router(rewards_router.share_redirect_router, tags=["share"])
app.include_router(wallet_router.router, prefix="/api/v1/wallet", tags=["wallet"])
app.include_router(wallet_router.admin_router, prefix="/api/v1/admin", tags=["admin-wallet"])
app.include_router(notifications_router.router, prefix="/api/v1/notifications",
                   tags=["notifications"])
app.include_router(shop_router.router, prefix="/api/v1", tags=["shop"])
# User posts: edit/delete own feed posts (DiscoveryPlacement), owner-only.
from app.routers import posts as posts_router
app.include_router(posts_router.router, prefix="/api/v1/posts", tags=["posts"])
app.include_router(
    video_router.router, prefix="/api/v1/video", tags=["video"]
)  # AI video proxy (Create Hub online mode)
app.include_router(
    trending_router.router, prefix="/api/v1", tags=["trending"]
)  # Trending topics (website "Trending Now" + app)
app.include_router(
    media_router.router, prefix="/api/v1/media", tags=["media"]
)  # Creator Hub: real AI image + caption generation
app.include_router(
    distribution_router.router, prefix="/api/v1/distribution", tags=["distribution"]
)  # Distribution Engine v1: cross-platform repurposing

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
