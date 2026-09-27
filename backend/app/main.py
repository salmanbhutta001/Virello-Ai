"""Virello backend — FastAPI. Secure, scalable, audit-logged."""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import init_db
from app.routers import auth, users, campaigns, ai, billing, analytics, admin, ws
from app.routers import analysis as analysis_router
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
from app.routers import collab as collab_router
from app.routers import referrals as referrals_router
from app.routers import ctr as ctr_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()  # dev bootstrap; production uses Alembic migrations
    yield


app = FastAPI(
    title="Virello API",
    description="Your AI Growth Manager — legitimate AI-powered social growth.",
    version="0.1.0",
    lifespan=lifespan,
)

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
app.include_router(billing.router, prefix="/api/v1/billing", tags=["billing"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["analytics"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["admin"])
app.include_router(analysis_router.router, prefix="/api/v1/analysis", tags=["analysis"])
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
app.include_router(collab_router.router, prefix="/api/v1/collab", tags=["collab"])
app.include_router(referrals_router.router, prefix="/api/v1/referrals", tags=["referrals"])
app.include_router(ctr_router.router, prefix="/api/v1/content", tags=["content"])
app.include_router(ws.router, prefix="/api/v1")  # WebSocket: /api/v1/campaigns/{id}/stream


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "virello-api"}
