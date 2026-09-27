"""Wikimedia Pageviews connector (open data, no key required).

Uses the official Wikimedia Pageviews API
(https://wikimedia.org/api/rest_v1/) to read aggregate article view counts
— legitimate open data published by the Wikimedia Foundation. Pageviews are
REAL numbers, so volume_hint is set and labeled as article views (a public
attention signal, not audience size and not a reach estimate).

Privacy: fully aggregate, no users involved.
"""
from __future__ import annotations

from datetime import date, timedelta

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)

try:
    import httpx
    _HTTPX = True
except Exception:  # pragma: no cover
    _HTTPX = False

_API = "https://wikimedia.org/api/rest_v1"

# Curated mapping from taxonomy topic -> representative Wikipedia articles.
_TOPIC_ARTICLES: dict[str, list[str]] = {
    "technology": ["Artificial_intelligence", "Smartphone", "ChatGPT"],
    "gaming": ["Video_game", "Minecraft", "PUBG:_Battlegrounds"],
    "finance": ["Stock_market", "Cryptocurrency", "Bitcoin"],
    "fitness": ["Physical_fitness", "Weight_loss", "Yoga"],
    "food": ["Pizza", "Biryani", "Recipe"],
    "beauty": ["Cosmetics", "Skin_care", "Makeup"],
    "fashion": ["Fashion", "Streetwear", "Sneakers"],
    "travel": ["Tourism", "Dubai", "Pakistan"],
    "sports": ["Cricket", "Football", "Olympic_Games"],
    "music": ["Music", "K-pop", "Coke_Studio_(Pakistan)"],
    "education": ["Education", "Online_learning", "University"],
    "business": ["Business", "Startup_company", "E-commerce"],
    "health": ["Health", "Mental_health", "Nutrition"],
    "news": ["News", "Current_events", "Politics"],
    "marketing": ["Marketing", "Digital_marketing", "Advertising"],
}


class WikipediaConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="wikipedia",
        access_method="Official Wikimedia Pageviews REST API (no key)",
        cost_tier=CostTier.free,
        rate_limit="High (generous; cache aggressively, ≤100 req/day typical)",
        geographic_coverage="Global (+ per-country pageview splits available)",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.open_dataset,
        confidence_score=0.75,
        confidence_rationale=(
            "Real aggregate article view counts from Wikimedia. Good public-"
            "attention signal; views are article reads, not people, and not "
            "a reach estimate."),
        tos_notes=(
            "Wikimedia open data under CC/open terms. Aggregate counts only; "
            "identify the client via User-Agent."),
    )

    def is_configured(self) -> bool:
        return _HTTPX

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not _HTTPX:
            return FetchResult(status=SourceStatus.not_configured,
                               message="httpx is not available.")
        topics = [t.lower() for t in (topics or [])][:5] or ["technology"]
        end = date.today() - timedelta(days=2)
        start = end - timedelta(days=30)
        fmt = "%Y%m%d"
        signals: list[InterestSignal] = []
        try:
            for topic in topics:
                articles = _TOPIC_ARTICLES.get(topic, [topic.title()])
                total = 0
                kws = [topic]
                for art in articles[:3]:
                    r = httpx.get(
                        f"{_API}/metrics/pageviews/per-article/en.wikipedia/"
                        f"all-access/user/{art}/daily/"
                        f"{start.strftime(fmt)}/{end.strftime(fmt)}",
                        headers={"User-Agent": "virello-audience/1.0"},
                        timeout=20)
                    if r.status_code != 200:
                        continue
                    views = sum(i.get("views", 0) for i in
                                r.json().get("items", []))
                    total += views
                    kws.append(art.replace("_", " ").lower())
                if total <= 0:
                    continue
                signals.append(InterestSignal(
                    topic=topic,
                    keywords=kws[:6],
                    geography=(geography or "").upper(),
                    volume_hint=float(total),
                    volume_label=(f"{total:,} Wikipedia article views (30d, "
                                  f"en.wikipedia) — public attention signal, "
                                  f"not audience size"),
                    trend_direction="unknown",
                    source="wikipedia",
                ))
                if len(signals) >= limit:
                    break
            if not signals:
                return FetchResult(status=SourceStatus.degraded,
                                   message="Wikimedia API returned no data.")
            return FetchResult(status=SourceStatus.ready, signals=signals,
                               message=f"{len(signals)} topics from Wikimedia Pageviews")
        except Exception as exc:
            return FetchResult(status=SourceStatus.degraded,
                               message=f"Wikimedia fetch failed: {exc}")
