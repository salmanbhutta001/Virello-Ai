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

from sqlalchemy import JSON, DateTime, ForeignKey, String, func
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
