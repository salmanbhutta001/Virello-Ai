"""Google Ads API connector — OPTIONAL / not_configured until credentials exist.

What it WILL do once configured:
- Read audience insights via the Google Ads API (official): audience
  attributes, interest/topic segments, and trend insights for the
  advertiser's own account context.

Requirements (all mandatory, none assumed):
- Google Ads developer token (approved)
- OAuth2 credentials with access to a Google Ads account
- GOOGLE_ADS_DEVELOPER_TOKEN, GOOGLE_ADS_CLIENT_ID,
  GOOGLE_ADS_CLIENT_SECRET, GOOGLE_ADS_REFRESH_TOKEN env vars

Until all are present this connector reports not_configured and returns
zero signals. It never claims to work without credentials.
"""
from __future__ import annotations

import os

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)


class GoogleAdsConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="google_ads",
        access_method="Official Google Ads API (developer token + OAuth2)",
        cost_tier=CostTier.freemium,
        rate_limit="API units-based; generous for reporting workloads",
        geographic_coverage="Global (account-based targeting data)",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.official_api_key,
        confidence_score=0.9,
        confidence_rationale=(
            "First-party official audience insights (attributes, interests, "
            "topics) from Google's ads platform. Highest confidence among "
            "third-party sources — when credentials exist."),
        tos_notes=(
            "Google Ads API Terms + Required Minimum Functionality apply. "
            "Read-only insights; data belongs to the advertiser's account "
            "context. Never expose account-private data to other users."),
    )

    _REQUIRED = ("GOOGLE_ADS_DEVELOPER_TOKEN", "GOOGLE_ADS_CLIENT_ID",
                 "GOOGLE_ADS_CLIENT_SECRET", "GOOGLE_ADS_REFRESH_TOKEN")

    def is_configured(self) -> bool:
        return all(os.environ.get(k) for k in self._REQUIRED)

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not self.is_configured():
            missing = [k for k in self._REQUIRED if not os.environ.get(k)]
            return FetchResult(
                status=SourceStatus.not_configured,
                message=("Google Ads API credentials missing: "
                         + ", ".join(missing)))
        # Credentialed path intentionally not implemented in this milestone:
        # activating it requires an approved developer token and account
        # context review. The interface is stable so it can be completed
        # without changing callers.
        return FetchResult(
            status=SourceStatus.degraded,
            message=("Credentials present but the Google Ads insights query "
                     "path is not yet implemented — tracked for a follow-up "
                     "milestone."))
