"""TikTok Research API / Commercial Content API connector — OPTIONAL.

Eligibility reality (do not assume universal access):
- The TikTok Research API is restricted to eligible academic researchers /
  organizations in approved regions (US/EU), with an application process.
- The Commercial Content API serves advertising/commerce use cases with its
  own approval.

What it WILL do once approved credentials exist:
- Read PUBLIC content/account metadata and commercial-content intelligence
  within the API's terms (video descriptions, hashtags, aggregate public
  counts — never private user data).

Without TIKTOK_RESEARCH_TOKEN (or commercial API credentials) this
connector reports not_configured and returns zero signals.
"""
from __future__ import annotations

import os

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)


class TikTokConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="tiktok",
        access_method=("TikTok Research API (restricted eligibility) / "
                       "Commercial Content API (approval required)"),
        cost_tier=CostTier.free,
        rate_limit="Per approval tier (research API has daily quotas)",
        geographic_coverage="Per approval (US/EU research; commercial varies)",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.official_api_key,
        confidence_score=0.75,
        confidence_rationale=(
            "Official public content/account metadata and commercial-content "
            "intelligence. Strong for short-video trend signals — when "
            "access is granted."),
        tos_notes=(
            "TikTok Research API Terms / Commercial API terms apply. Access "
            "is NOT universal — treat as optional. Public metadata only; "
            "no scraping of tiktok.com (prohibited); respect data-retention "
            "and research-ethics requirements."),
    )

    def is_configured(self) -> bool:
        return bool(os.environ.get("TIKTOK_RESEARCH_TOKEN")
                    or os.environ.get("TIKTOK_COMMERCIAL_KEY"))

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not self.is_configured():
            return FetchResult(
                status=SourceStatus.not_configured,
                message=("TikTok API access is restricted/approval-based. "
                         "Set TIKTOK_RESEARCH_TOKEN (eligible researchers) "
                         "or TIKTOK_COMMERCIAL_KEY when approved."))
        return FetchResult(
            status=SourceStatus.degraded,
            message=("Token present but the TikTok query path is not yet "
                     "implemented — tracked for a follow-up milestone."))
