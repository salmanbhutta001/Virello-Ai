"""Core data model — mirrors mobile lib/data/models.dart."""
import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import CHAR, JSON, DateTime, Enum as SAEnum, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.types import TypeDecorator


class GUID(TypeDecorator):
    """Backend-agnostic UUID: native UUID on Postgres, CHAR(36) elsewhere (SQLite dev)."""

    impl = CHAR(36)
    cache_ok = True

    def load_dialect_impl(self, dialect):  # type: ignore[override]
        if dialect.name == "postgresql":
            return PG_UUID(as_uuid=True)
        return CHAR(36)

    def process_bind_param(self, value, dialect):  # type: ignore[override]
        return str(value) if value is not None else None

    def process_result_value(self, value, dialect):  # type: ignore[override]
        if value is None:
            return None
        return value if isinstance(value, uuid.UUID) else uuid.UUID(str(value))


class Base(DeclarativeBase):
    pass


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class CampaignGoal(str, Enum):
    reach = "reach"
    engagement = "engagement"
    profile_visits = "profile_visits"
    website_traffic = "website_traffic"
    leads = "leads"
    customers = "customers"


class GrowthMode(str, Enum):
    organic = "organic"
    paid = "paid"


class CampaignStatus(str, Enum):
    analyzing = "analyzing"
    strategizing = "strategizing"
    launching = "launching"
    live = "live"
    optimizing = "optimizing"
    paused = "paused"
    completed = "completed"


class Plan(str, Enum):
    free = "free"
    pro = "pro"
    scale = "scale"


class User(Base):
    __tablename__ = "users"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str | None] = mapped_column(String(255))
    locale: Mapped[str] = mapped_column(String(8), default="en")
    # Multilingual preferences: UI/content default, extra content
    # languages, and "match me in all relevant languages".
    preferred_language: Mapped[str] = mapped_column(String(16), default="en")
    content_languages: Mapped[list] = mapped_column(JSON, default=list)
    all_relevant_languages: Mapped[bool] = mapped_column(default=False)
    plan: Mapped[Plan] = mapped_column(SAEnum(Plan), default=Plan.free)
    credits: Mapped[int] = mapped_column(Integer, default=300)  # free starter credits
    is_admin: Mapped[bool] = mapped_column(default=False)
    suspended: Mapped[bool] = mapped_column(default=False)
    # True once the user proves email ownership (OTP verify) or signs in
    # via a provider (Google/Apple) that already verified the email.
    email_verified: Mapped[bool] = mapped_column(default=False)
    # Email+password auth (optional; NULL = OTP / OAuth only).
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    password_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UserActivity(Base):
    """App-visit events for the admin analytics dashboard.

    Written by the mobile app (POST /api/v1/analytics/track) when a signed-in
    user opens the app. Powers DAU/WAU/MAU + daily/weekly/monthly reports.
    The user's email is already stored on users.email at signup (email OTP or
    Google/Apple OAuth upsert), so the admin users list doubles as the
    saved-emails report — no separate email table needed.
    """
    __tablename__ = "user_activity"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    # app_open | login
    event: Mapped[str] = mapped_column(String(32), index=True, default="app_open")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)


class SupportTicket(Base):
    """Live-chat support ticket (deterministic support brain creates these).

    Human handoff queue: open → in_progress → closed.
    """
    __tablename__ = "support_ticket"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    subject: Mapped[str] = mapped_column(String(255), default="")
    message: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(16), default="open", index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)


class SocialConnection(Base):
    """OAuth-only platform connections. Tokens encrypted at rest. No passwords ever."""
    __tablename__ = "social_connections"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    platform: Mapped[str] = mapped_column(String(32))  # tiktok | instagram | youtube | x
    platform_user_id: Mapped[str] = mapped_column(String(128))
    encrypted_token: Mapped[str] = mapped_column(Text)  # Fernet/KMS encrypted OAuth token
    scopes: Mapped[str] = mapped_column(String(512), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Campaign(Base):
    __tablename__ = "campaigns"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    post_url: Mapped[str] = mapped_column(String(1024))
    platform: Mapped[str] = mapped_column(String(32))
    goal: Mapped[CampaignGoal] = mapped_column(SAEnum(CampaignGoal))
    mode: Mapped[GrowthMode] = mapped_column(SAEnum(GrowthMode))
    markets: Mapped[str] = mapped_column(String(255), default="worldwide")  # csv
    status: Mapped[CampaignStatus] = mapped_column(SAEnum(CampaignStatus), default=CampaignStatus.analyzing)
    budget_usd: Mapped[float] = mapped_column(Float, default=0)  # hard cap, paid mode
    spend_usd: Mapped[float] = mapped_column(Float, default=0)
    duration_days: Mapped[int] = mapped_column(Integer, default=7)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AgentRun(Base):
    """Every AI agent execution — auditable, with honesty validation result."""
    __tablename__ = "agent_runs"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("campaigns.id"), index=True)
    agent: Mapped[str] = mapped_column(String(64))  # one of the 10 agents
    input_summary: Mapped[str] = mapped_column(Text, default="")
    output_summary: Mapped[str] = mapped_column(Text, default="")
    output: Mapped[dict] = mapped_column(JSON, default=dict)  # provider, model, tokens, dev flag
    honesty_passed: Mapped[bool] = mapped_column(default=True)
    credits_used: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MetricDaily(Base):
    __tablename__ = "metrics_daily"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("campaigns.id"), index=True)
    day: Mapped[str] = mapped_column(String(10), index=True)  # YYYY-MM-DD
    reach: Mapped[int] = mapped_column(Integer, default=0)
    impressions: Mapped[int] = mapped_column(Integer, default=0)
    engagement: Mapped[int] = mapped_column(Integer, default=0)
    clicks: Mapped[int] = mapped_column(Integer, default=0)
    profile_visits: Mapped[int] = mapped_column(Integer, default=0)
    conversions: Mapped[int] = mapped_column(Integer, default=0)
    spend_usd: Mapped[float] = mapped_column(Float, default=0)


class FraudFlag(Base):
    __tablename__ = "fraud_flags"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("campaigns.id"), index=True)
    reason: Mapped[str] = mapped_column(String(512))
    resolved: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AuditLog(Base):
    """Every budget-affecting or campaign-mutating action."""
    __tablename__ = "audit_logs"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    action: Mapped[str] = mapped_column(String(128), index=True)
    details: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Subscription(Base):
    __tablename__ = "subscriptions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), unique=True)
    provider: Mapped[str] = mapped_column(String(32), default="")  # paypal | payoneer | google_pay
    provider_ref: Mapped[str] = mapped_column(String(128), default="")  # provider-side id
    plan: Mapped[Plan] = mapped_column(SAEnum(Plan), default=Plan.free)
    status: Mapped[str] = mapped_column(String(32), default="active")
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
