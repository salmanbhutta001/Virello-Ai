"""Pinterest connector (official API, key required).

Uses the Pinterest API v5: keyword search suggestions and the Trends-style
interest signals where the app's approved scopes permit. Pinterest's
advertising ecosystem officially supports interest targeting and actalike
audiences — this connector only READS public interest/keyword metadata to
inform segment definitions; it never touches user-level data.

Without PINTEREST_ACCESS_TOKEN the connector reports not_configured.
"""
from __future__ import annotations

import os

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)

try:
    import httpx
    _HTTPX = True
except Exception:  # pragma: no cover
    _HTTPX = False


def _http() -> "httpx.Client":
    """httpx client that survives bracketed IPv6 entries in no_proxy.

    Same pattern as payments/base.py: httpx chokes on entries like [::1]
    in no_proxy, so we bypass env parsing (trust_env=False) and wire the
    egress proxy explicitly.
    """
    proxy = (os.environ.get("https_proxy") or os.environ.get("HTTPS_PROXY")
             or os.environ.get("http_proxy") or os.environ.get("HTTP_PROXY"))
    import ssl
    cafile = os.environ.get("SSL_CERT_FILE")
    ctx = ssl.create_default_context(cafile=cafile) if cafile \
        else ssl.create_default_context()
    return httpx.Client(trust_env=False, proxy=proxy or None, verify=ctx,
                        timeout=20)

_API = "https://api.pinterest.com/v5"


class PinterestConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="pinterest",
        access_method="Official Pinterest API v5 (OAuth access token)",
        cost_tier=CostTier.free,
        rate_limit="~1000 req/day default (per app, scope-dependent)",
        geographic_coverage="Global; strongest US/EU coverage",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.official_api_key,
        confidence_score=0.7,
        confidence_rationale=(
            "Keyword and interest metadata from Pinterest's official API. "
            "Strong for lifestyle/home/beauty/fashion intent topics; "
            "coverage varies by market."),
        tos_notes=(
            "Pinterest Developer Guidelines apply. Read-only interest/"
            "keyword metadata; no user-level data. Pinterest's ads platform "
            "(separate) officially supports interest + actalike targeting."),
    )

    def _token(self) -> str:
        return os.environ.get("PINTEREST_ACCESS_TOKEN", "")

    def is_configured(self) -> bool:
        return bool(self._token()) and _HTTPX

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not self.is_configured():
            return FetchResult(
                status=SourceStatus.not_configured,
                message="PINTEREST_ACCESS_TOKEN is not set — connector inactive.")
        topics = (topics or [])[:5] or ["home decor"]
        headers = {"Authorization": f"Bearer {self._token()}"}
        signals: list[InterestSignal] = []
        auth_failed = False
        try:
            client = _http()
            for topic in topics:
                r = client.get(
                    f"{_API}/keywords/search",
                    headers=headers,
                    params={"query": topic, "page_size": 10})
                if r.status_code in (401, 403):
                    # Never hide an auth failure as "ready, 0 topics".
                    auth_failed = True
                    break
                if r.status_code != 200:
                    continue
                kws = [topic]
                for item in r.json().get("items", []):
                    kw = str(item.get("keyword", "")).strip().lower()
                    if kw and kw not in kws:
                        kws.append(kw)
                if len(kws) < 2:
                    continue
                signals.append(InterestSignal(
                    topic=topic.lower().replace(" ", "_"),
                    keywords=kws[:10],
                    geography=(geography or "").upper(),
                    volume_hint=None,
                    volume_label="volume unavailable",
                    trend_direction="unknown",
                    source="pinterest",
                ))
                if len(signals) >= limit:
                    break
            client.close()
            if auth_failed:
                return FetchResult(
                    status=SourceStatus.degraded,
                    message=("Pinterest rejected the access token (401/403) — "
                             "the token may be expired or the app may still be "
                             "pending trial access. Regenerate the token after "
                             "trial approval."))
            return FetchResult(status=SourceStatus.ready, signals=signals,
                               message=f"{len(signals)} topics from Pinterest API")
        except Exception as exc:
            return FetchResult(status=SourceStatus.degraded,
                               message=f"Pinterest fetch failed: {exc}")
