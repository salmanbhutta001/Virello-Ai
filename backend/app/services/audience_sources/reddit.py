"""Reddit Data API connector (official API, OAuth required).

Reddit's public JSON endpoints (e.g. /r/<sub>/.json) are now restricted and
require authentication; unauthenticated scraping-style access violates
Reddit's terms. This connector implements the OFFICIAL Reddit Data API
flow (OAuth2, script or web app credentials) and reads ONLY public
subreddit signals: hot/top post titles in relevant communities.

Commercial-use requirement: Reddit's Data API Terms require a commercial
agreement for most commercial use cases. This connector documents that and
returns read-only public-community signals — never user profiling, never
per-user data.

Without REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET / REDDIT_REFRESH_TOKEN the
connector reports not_configured.
"""
from __future__ import annotations

import base64
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

_UA = "virello-audience-intelligence/1.0 (by u/virello)"


class RedditConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="reddit",
        access_method="Official Reddit Data API (OAuth2)",
        cost_tier=CostTier.freemium,
        rate_limit="~60 req/min authenticated (600 per 10 min window)",
        geographic_coverage="Global (community-based, not geo-targeted)",
        freshness=Freshness.realtime,
        permitted_use=PermittedUse.official_api_key,
        confidence_score=0.7,
        confidence_rationale=(
            "Public community discussion signals: post titles and flairs in "
            "relevant subreddits. Strong for topic resonance, but community-"
            "skewed and not representative of the general population."),
        tos_notes=(
            "Reddit Data API Terms + Developer Terms apply. Commercial use "
            "generally requires a Reddit commercial agreement. Read-only "
            "public community signals; no user profiling, no storing of "
            "personal data, respect rate limits and robots rules."),
    )

    def _creds(self) -> tuple[str, str, str]:
        return (os.environ.get("REDDIT_CLIENT_ID", ""),
                os.environ.get("REDDIT_CLIENT_SECRET", ""),
                os.environ.get("REDDIT_REFRESH_TOKEN", ""))

    def is_configured(self) -> bool:
        cid, secret, refresh = self._creds()
        return bool(cid and secret and refresh) and _HTTPX

    def _token(self, cid: str, secret: str, refresh: str) -> str:
        basic = base64.b64encode(f"{cid}:{secret}".encode()).decode()
        r = httpx.post(
            "https://www.reddit.com/api/v1/access_token",
            headers={"Authorization": f"Basic {basic}",
                     "User-Agent": _UA},
            data={"grant_type": "refresh_token",
                  "refresh_token": refresh},
            timeout=20)
        r.raise_for_status()
        return r.json()["access_token"]

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not self.is_configured():
            return FetchResult(
                status=SourceStatus.not_configured,
                message=("REDDIT_CLIENT_ID/SECRET/REFRESH_TOKEN not set — "
                         "connector inactive."))
        # Map taxonomy topics to relevant public subreddits (curated, no
        # user data involved).
        sub_map = {
            "technology": ["technology", "gadgets"],
            "gaming": ["gaming", "mobilegaming"],
            "finance": ["personalfinance", "investing"],
            "fitness": ["fitness", "bodyweightfitness"],
            "food": ["food", "recipes"],
            "beauty": ["beauty", "skincareaddiction"],
            "fashion": ["fashion", "streetwear"],
            "travel": ["travel", "solotravel"],
            "sports": ["sports", "soccer"],
            "music": ["music", "listentothis"],
            "education": ["education", "learnprogramming"],
            "business": ["business", "entrepreneur"],
            "marketing": ["marketing", "socialmedia"],
        }
        topics = (topics or [])[:5] or ["technology"]
        try:
            cid, secret, refresh = self._creds()
            token = self._token(cid, secret, refresh)
            headers = {"Authorization": f"Bearer {token}",
                       "User-Agent": _UA}
            signals: list[InterestSignal] = []
            for topic in topics:
                subs = sub_map.get(topic.lower(), [topic.lower()])
                kw: list[str] = []
                for sub in subs[:2]:
                    r = httpx.get(
                        f"https://oauth.reddit.com/r/{sub}/hot",
                        headers=headers,
                        params={"limit": 15},
                        timeout=20)
                    if r.status_code != 200:
                        continue
                    for child in r.json().get("data", {}).get("children", []):
                        d = child.get("data", {})
                        title = str(d.get("title", ""))
                        for w in title.lower().split():
                            w = "".join(ch for ch in w if ch.isalnum())
                            if len(w) > 3 and w not in kw:
                                kw.append(w)
                            if len(kw) >= 12:
                                break
                if not kw:
                    continue
                signals.append(InterestSignal(
                    topic=topic.lower(),
                    keywords=[topic] + kw[:11],
                    geography="",
                    volume_hint=None,
                    volume_label="volume unavailable",
                    trend_direction="unknown",
                    source="reddit",
                ))
                if len(signals) >= limit:
                    break
            return FetchResult(status=SourceStatus.ready, signals=signals,
                               message=f"{len(signals)} topics from Reddit Data API")
        except Exception as exc:
            return FetchResult(status=SourceStatus.degraded,
                               message=f"Reddit fetch failed: {exc}")
