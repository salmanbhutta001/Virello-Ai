"""YouTube Data API v3 connector (official API, key required).

POLICY BOUNDARY (YouTube API Services ToS — read carefully):
- This connector uses ONLY the official YouTube Data API v3 with a valid
  API key. It reads PUBLIC video/channel metadata: titles, descriptions,
  tags, category IDs, topic details, and aggregate public statistics
  (viewCount/likeCount as published by YouTube).
- It does NOT scrape youtube.com. Scraping is prohibited by YouTube's ToS.
- It does NOT aggregate or derive non-public audience information. Per
  YouTube's policies, API data must not be used to infer or profile
  individual users, and audience composition must not be reverse-engineered.
- Signals produced here are CONTENT signals (what topics/tags/categories
  are attached to public videos) — never "who watches what".

Without YOUTUBE_API_KEY the connector reports not_configured and returns
zero signals (never synthetic data).
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

_API = "https://www.googleapis.com/youtube/v3"


class YouTubeConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="youtube",
        access_method="Official YouTube Data API v3 (API key)",
        cost_tier=CostTier.freemium,
        rate_limit="10,000 quota units/day free (search=100 units; videos.list=1)",
        geographic_coverage="Global (regionCode parameter)",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.official_api_key,
        confidence_score=0.8,
        confidence_rationale=(
            "Official public metadata: video tags, categories, topicDetails "
            "and published aggregate counts. Content-side signals only; "
            "YouTube prohibits deriving audience composition from API data."),
        tos_notes=(
            "YouTube API Services ToS + Developer Policies apply. No "
            "scraping; no storing API data beyond permitted retention; no "
            "user profiling or audience-composition inference. Quota must "
            "be monitored; audit compliance annually."),
    )

    def _key(self) -> str:
        return os.environ.get("YOUTUBE_API_KEY", "")

    def is_configured(self) -> bool:
        return bool(self._key()) and _HTTPX

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not self.is_configured():
            return FetchResult(
                status=SourceStatus.not_configured,
                message="YOUTUBE_API_KEY is not set — connector inactive.")
        topics = (topics or [])[:5] or ["technology"]
        region = (geography or "US").upper()
        signals: list[InterestSignal] = []
        try:
            for topic in topics:
                r = httpx.get(
                    f"{_API}/search",
                    params={"part": "snippet", "q": topic, "type": "video",
                            "maxResults": 10, "regionCode": region,
                            "key": self._key()},
                    timeout=20)
                if r.status_code != 200:
                    continue
                vids = [it["id"]["videoId"] for it in
                        r.json().get("items", []) if it.get("id")]
                if not vids:
                    continue
                v = httpx.get(
                    f"{_API}/videos",
                    params={"part": "snippet,statistics,topicDetails",
                            "id": ",".join(vids), "key": self._key()},
                    timeout=20)
                if v.status_code != 200:
                    continue
                tags: list[str] = []
                cats: set[str] = set()
                views = 0
                for item in v.json().get("items", []):
                    sn = item.get("snippet", {})
                    tags += [t.lower() for t in (sn.get("tags") or [])][:8]
                    if sn.get("categoryId"):
                        cats.add(str(sn["categoryId"]))
                    try:
                        views += int(item.get("statistics", {})
                                     .get("viewCount", 0))
                    except (TypeError, ValueError):
                        pass
                kw = [topic] + sorted(set(tags))[:8]
                signals.append(InterestSignal(
                    topic=topic.lower().replace(" ", "_"),
                    keywords=kw[:10],
                    geography=region,
                    volume_hint=float(views) if views else None,
                    volume_label=(f"Aggregate public viewCount across sampled "
                                  f"videos ({region}) — content popularity, "
                                  f"not audience size" if views else
                                  "volume unavailable"),
                    trend_direction="unknown",
                    source="youtube",
                ))
                if len(signals) >= limit:
                    break
            return FetchResult(status=SourceStatus.ready, signals=signals,
                               message=f"{len(signals)} topics from YouTube Data API")
        except Exception as exc:
            return FetchResult(status=SourceStatus.degraded,
                               message=f"YouTube fetch failed: {exc}")
