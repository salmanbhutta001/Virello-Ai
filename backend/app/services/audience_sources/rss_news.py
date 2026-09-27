"""RSS / news-feed connector (public RSS, no key required).

Aggregates PUBLIC RSS feeds (BBC, Dawn, TechCrunch, etc.) via feedparser
and extracts topic keywords from headlines. RSS is an explicitly public
syndication format — reading it is legitimate. No scraping of article
bodies, no paywall bypass; headlines + metadata only.

Signals are news-cycle topic resonances, labeled as such. Volume is not
available (headline counts are not audience size) → volume_hint stays None.
"""
from __future__ import annotations

import re
from collections import Counter

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)

try:
    import feedparser
    _FEEDPARSER = True
except Exception:  # pragma: no cover
    _FEEDPARSER = False

FEEDS: list[tuple[str, str]] = [
    ("BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml"),
    ("BBC Technology", "https://feeds.bbci.co.uk/news/technology/rss.xml"),
    ("Dawn Pakistan", "https://www.dawn.com/feeds/home"),
    ("TechCrunch", "https://techcrunch.com/feed/"),
    ("The Verge", "https://www.theverge.com/rss/index.xml"),
]

_STOP = {
    "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "with",
    "from", "by", "at", "as", "is", "are", "was", "were", "be", "has",
    "have", "it", "its", "this", "that", "will", "new", "over", "after",
    "says", "amid", "into", "out",
}

_WORD = re.compile(r"[a-z]{4,20}")


class RssNewsConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="rss_news",
        access_method="Public RSS feeds via feedparser (headlines only)",
        cost_tier=CostTier.free,
        rate_limit="Publisher-friendly: poll each feed ≤ 4x/day",
        geographic_coverage="Global (feed-dependent; Dawn = PK focus)",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.public_api,
        confidence_score=0.6,
        confidence_rationale=(
            "Headline keyword frequencies from reputable public feeds. Good "
            "for news-cycle topic resonance; not a measure of audience size "
            "or lasting interest."),
        tos_notes=(
            "RSS is public syndication. Headlines + metadata only; no full-"
            "article scraping, no paywall bypass. Respect publishers' "
            "crawl-delay guidance."),
    )

    def is_configured(self) -> bool:
        return _FEEDPARSER

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not _FEEDPARSER:
            return FetchResult(
                status=SourceStatus.not_configured,
                message="feedparser is not installed in this environment.")
        wanted = {t.lower() for t in (topics or [])}
        counter: Counter[str] = Counter()
        per_topic: dict[str, Counter[str]] = {}
        ok_feeds = 0
        for name, url in FEEDS:
            try:
                feed = feedparser.parse(url)
                entries = getattr(feed, "entries", [])[:25]
                if not entries:
                    continue
                ok_feeds += 1
                for e in entries:
                    title = str(getattr(e, "title", "")).lower()
                    words = [w for w in _WORD.findall(title)
                             if w not in _STOP]
                    counter.update(words)
                    for t in wanted:
                        if t in title:
                            per_topic.setdefault(t, Counter()).update(words)
            except Exception:
                continue
        if ok_feeds == 0:
            return FetchResult(status=SourceStatus.degraded,
                               message="No RSS feeds reachable right now.")
        signals: list[InterestSignal] = []
        if wanted:
            for t in sorted(wanted):
                kws = [w for w, _ in per_topic.get(t, Counter()).most_common(8)]
                if not kws:
                    continue
                signals.append(InterestSignal(
                    topic=t, keywords=[t] + kws[:7],
                    geography=(geography or "").upper(),
                    volume_hint=None, volume_label="volume unavailable",
                    trend_direction="stable", source="rss_news"))
        else:
            for word, _ in counter.most_common(limit):
                signals.append(InterestSignal(
                    topic=word, keywords=[word],
                    geography=(geography or "").upper(),
                    volume_hint=None, volume_label="volume unavailable",
                    trend_direction="stable", source="rss_news"))
        return FetchResult(
            status=SourceStatus.ready, signals=signals[:limit],
            message=f"Headline topics from {ok_feeds} public RSS feeds")
