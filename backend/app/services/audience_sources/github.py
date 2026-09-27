"""GitHub public repository search connector (open API, key optional).

Uses the official GitHub REST API ``/search/repositories`` to read PUBLIC
repository metadata: names, descriptions, topics, star counts. Star counts
are real numbers → volume_hint is set and labeled as repo popularity (a
developer-attention signal, not audience size).

Rate limits: 10 req/min unauthenticated; 30 req/min with a token (set
GITHUB_TOKEN to raise the limit). Never attempts to read private data.
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


class GitHubConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="github",
        access_method="Official GitHub REST API (public; token optional)",
        cost_tier=CostTier.free,
        rate_limit=("10 search req/min unauthenticated; 30/min with "
                    "GITHUB_TOKEN"),
        geographic_coverage="Global (developer community)",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.public_api,
        confidence_score=0.65,
        confidence_rationale=(
            "Public repo topics + real star counts. Strong for tech/developer "
            "topic signals; not representative beyond the developer "
            "community."),
        tos_notes=(
            "GitHub API Terms of Service apply. Public data only; respect "
            "rate limits; do not circumvent access controls."),
    )

    def is_configured(self) -> bool:
        return _HTTPX

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not _HTTPX:
            return FetchResult(status=SourceStatus.not_configured,
                               message="httpx is not available.")
        topics = (topics or [])[:5] or ["machine-learning"]
        headers = {"Accept": "application/vnd.github+json",
                   "User-Agent": "virello-audience/1.0"}
        token = os.environ.get("GITHUB_TOKEN", "")
        if token:
            headers["Authorization"] = f"Bearer {token}"
        signals: list[InterestSignal] = []
        try:
            for topic in topics:
                r = httpx.get(
                    "https://api.github.com/search/repositories",
                    headers=headers,
                    params={"q": topic, "sort": "stars",
                            "order": "desc", "per_page": 10},
                    timeout=20)
                if r.status_code != 200:
                    continue
                data = r.json()
                total = int(data.get("total_count", 0) or 0)
                kws = [topic]
                stars = 0
                for repo in data.get("items", [])[:10]:
                    for t in (repo.get("topics") or [])[:4]:
                        if t not in kws:
                            kws.append(t)
                    try:
                        stars += int(repo.get("stargazers_count", 0) or 0)
                    except (TypeError, ValueError):
                        pass
                signals.append(InterestSignal(
                    topic=topic.lower().replace(" ", "-"),
                    keywords=kws[:10],
                    volume_hint=float(total) if total else None,
                    volume_label=(f"{total:,} public repos matching "
                                  f"'{topic}' — developer attention signal, "
                                  f"not audience size" if total else
                                  "volume unavailable"),
                    trend_direction="unknown",
                    source="github",
                ))
                if len(signals) >= limit:
                    break
            if not signals:
                return FetchResult(status=SourceStatus.degraded,
                                   message="GitHub API returned no data.")
            return FetchResult(status=SourceStatus.ready, signals=signals,
                               message=f"{len(signals)} topics from GitHub")
        except Exception as exc:
            return FetchResult(status=SourceStatus.degraded,
                               message=f"GitHub fetch failed: {exc}")
