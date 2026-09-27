"""Google Trends connector.

Access: ``pytrends`` (community library over Google's public Trends
endpoints). Google tolerates this usage; the OFFICIAL alternative for
production is the public Google Trends datasets on BigQuery
(``bigquery-public-data.google_trends``), which this connector documents
as the upgrade path. No API key required.

Signals: interest-over-time (0-100 normalized index — a REAL number from
Google, so volume_hint is set), related rising queries, interest-by-region.

Privacy: fully aggregate public search-interest data. No users, no
profiling. Never presented as audience size — it is search interest only.
"""
from __future__ import annotations

from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)

try:
    from pytrends.request import TrendReq
    _PYTRENDS = True
except Exception:  # pragma: no cover - optional dependency
    TrendReq = None  # type: ignore
    _PYTRENDS = False


class GoogleTrendsConnector(AudienceSourceConnector):
    metadata = SourceMetadata(
        source_name="google_trends",
        access_method=("pytrends over public Google Trends endpoints "
                       "(official alternative: BigQuery public "
                       "google_trends datasets)"),
        cost_tier=CostTier.free,
        rate_limit=("Unofficial: ~50-100 req/day per IP before soft "
                    "throttling; BigQuery public datasets: 1 TB/month free"),
        geographic_coverage="Global; per-country incl. PK, US, UK",
        freshness=Freshness.daily,
        permitted_use=PermittedUse.public_api,
        confidence_score=0.85,
        confidence_rationale=(
            "Direct from Google's search-interest index; normalized 0-100 "
            "per query window. Relative, not absolute — good for trend "
            "direction and regional comparison, not audience sizing."),
        tos_notes=(
            "pytrends hits public endpoints Google exposes to browsers; "
            "respect rate limits. For production scale use the official "
            "BigQuery public datasets."),
    )

    def is_configured(self) -> bool:
        return _PYTRENDS

    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        if not _PYTRENDS:
            return FetchResult(
                status=SourceStatus.not_configured, message=(
                    "pytrends is not installed in this environment."))
        topics = [t for t in (topics or [])][:5] or ["digital marketing"]
        geo = (geography or "").upper() or "US"
        try:
            pt = TrendReq(hl="en-US", tz=0, timeout=(10, 25))
            pt.build_payload(topics, timeframe="today 3-m", geo=geo)
            iot = pt.interest_over_time()
            signals: list[InterestSignal] = []
            for topic in topics:
                if topic not in iot.columns:
                    continue
                series = iot[topic].dropna()
                if series.empty:
                    continue
                avg_idx = float(series.mean())
                first, last = float(series.iloc[0]), float(series.iloc[-1])
                if last > first * 1.25:
                    direction = "rising"
                elif last < first * 0.75:
                    direction = "falling"
                else:
                    direction = "stable"
                kw = [topic]
                try:
                    rq = pt.related_queries()
                    rising = (rq.get(topic) or {}).get("rising")
                    if rising is not None and hasattr(rising, "iterrows"):
                        for _, row in list(rising.iterrows())[:5]:
                            q = str(row.get("query", "")).strip()
                            if q:
                                kw.append(q)
                except Exception:
                    pass
                signals.append(InterestSignal(
                    topic=topic.lower().replace(" ", "_"),
                    keywords=kw[:6],
                    geography=geo,
                    language="en",
                    volume_hint=round(avg_idx, 1),
                    volume_label=("Google Trends interest index (0-100 avg, "
                                  f"{geo}, 90d) — relative search interest, "
                                  "not audience size"),
                    trend_direction=direction,
                    source="google_trends",
                ))
                if len(signals) >= limit:
                    break
            return FetchResult(status=SourceStatus.ready, signals=signals,
                               message=f"{len(signals)} topics from Google Trends ({geo})")
        except Exception as exc:
            return FetchResult(
                status=SourceStatus.degraded, message=f"Google Trends fetch failed: {exc}")
