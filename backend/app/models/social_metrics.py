"""Official social-platform metric snapshots.

A snapshot is ONE recording of a campaign's official platform numbers at a
point in time — either fetched via a connected account (later) or manually
entered by the creator from the platform's own dashboard (now).

These are NOT Virello-generated numbers and never feed the engine's
genuine-engagement accounting silently: `source` records exactly where each
figure came from, and the growth engine keeps platform totals strictly
separate from its own discovery-interaction totals.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class SocialMetricSnapshot(Base):
    """One official-metrics reading for a campaign.

    Owner scoping flows through campaign.user_id (enforced in the router).
    """

    __tablename__ = "social_metric_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("campaigns.id", ondelete="CASCADE"), index=True)
    platform: Mapped[str] = mapped_column(String(32), index=True)
    # instagram | facebook | tiktok | youtube | other
    account_ref: Mapped[str] = mapped_column(String(255), default="")
    post_ref: Mapped[str] = mapped_column(String(255), default="")
    metrics: Mapped[dict] = mapped_column(JSON, default=dict)
    # {"views": int, "likes": int, "comments": int, "shares": int,
    #  "saves": int, "reach": int, "followers_delta": int}
    source: Mapped[str] = mapped_column(String(64), default="")
    # "manual:official-dashboard" | "meta:graph-api" | …
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)


class AccountMetricSnapshot(Base):
    """One account-level official-metrics reading for a user + platform.

    Unlike SocialMetricSnapshot (per-campaign), this captures the whole
    connected account's official numbers (e.g. Instagram account insights)
    for a window of `period_days` days. Written by the MetricsAgent worker
    (service-token auth); read by the dashboard.

    Owner scoping flows through user_id. `source` records exactly where each
    figure came from (e.g. "instagram:account-insights") — Virello never
    fabricates platform metrics.

    metrics uses the METRIC_KEYS shape:
    {"views", "likes", "comments", "shares", "saves", "reach",
     "followers_delta", "profile_views", "accounts_engaged"}
    - "profile_views": Instagram `profile_visits` (visit events, not people).
    - "accounts_engaged": Instagram `engaged_accounts` (estimated accounts
      that interacted: likes, saves, comments, shares, replies).
    """

    __tablename__ = "account_metric_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True)
    platform: Mapped[str] = mapped_column(String(32), index=True)
    # instagram | facebook | tiktok | youtube | other
    account_ref: Mapped[str] = mapped_column(String(255), default="")
    # e.g. the IG username the numbers belong to
    metrics: Mapped[dict] = mapped_column(JSON, default=dict)
    source: Mapped[str] = mapped_column(String(64), default="")
    # "instagram:account-insights" | "facebook:page-insights" | …
    period_days: Mapped[int] = mapped_column(Integer, default=7)
    # the insights window the numbers cover (days)
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)
