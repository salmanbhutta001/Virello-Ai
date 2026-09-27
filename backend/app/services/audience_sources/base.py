"""Connector framework for Virello's multi-source Audience Intelligence Engine.

Design principles (non-negotiable):
- Every connector aggregates PUBLIC / officially-permitted signals into
  audience SEGMENTS (topic/interest cohorts). No personal identity lists,
  no user profiling, no private data — ever.
- Every connector declares full metadata: source name, access method, cost
  tier, rate limits, geographic coverage, freshness, permitted-use
  classification, confidence score with a documented rationale, and ToS notes.
- Connectors NEVER fabricate numbers. ``InterestSignal.volume_hint`` is set
  ONLY when the source returns a real number; otherwise it stays None and the
  API labels it "volume unavailable".
- When a source needs credentials that are not configured, the connector
  reports ``status="not_configured"`` and returns zero signals — never
  synthetic data.
- Scraping platforms that prohibit it is forbidden. Each connector documents
  its policy boundary in ``tos_notes``.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum


class CostTier(str, Enum):
    free = "free"
    freemium = "freemium"
    paid = "paid"


class PermittedUse(str, Enum):
    """How Virello is allowed to use this source."""
    public_api = "public_api"          # open public API, no key needed
    official_api_key = "official_api_key"  # official API, key/OAuth required
    open_dataset = "open_dataset"      # published open dataset / dump
    opt_in_only = "opt_in_only"        # only with explicit user consent


class Freshness(str, Enum):
    realtime = "realtime"
    daily = "daily"
    weekly = "weekly"
    monthly = "monthly"


class SourceStatus(str, Enum):
    ready = "ready"                    # configured (or keyless) and usable
    not_configured = "not_configured"  # needs credentials that are absent
    degraded = "degraded"              # configured but last fetch failed
    disabled = "disabled"              # administratively turned off


@dataclass
class InterestSignal:
    """One normalized audience-interest signal from a connector.

    ``volume_hint``: ONLY a real number from the source (search index,
    pageviews, etc.). None means "volume unavailable" — never an estimate
    invented by us.
    ``trend_direction``: "rising" | "stable" | "falling" | "unknown".
    """
    topic: str
    keywords: list[str] = field(default_factory=list)
    geography: str = ""                # ISO country code or "" for global
    language: str = ""                 # ISO 639-1 or "" for unknown
    volume_hint: float | None = None
    volume_label: str = "volume unavailable"
    trend_direction: str = "unknown"
    source: str = ""
    fetched_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "topic": self.topic,
            "keywords": list(self.keywords),
            "geography": self.geography,
            "language": self.language,
            "volume_hint": self.volume_hint,
            "volume_label": self.volume_label,
            "trend_direction": self.trend_direction,
            "source": self.source,
            "fetched_at": self.fetched_at.isoformat(),
        }


@dataclass
class SourceMetadata:
    source_name: str
    access_method: str
    cost_tier: CostTier
    rate_limit: str                    # human-readable, e.g. "10k req/day"
    geographic_coverage: str
    freshness: Freshness
    permitted_use: PermittedUse
    confidence_score: float             # 0..1
    confidence_rationale: str
    tos_notes: str


@dataclass
class FetchResult:
    status: SourceStatus
    signals: list[InterestSignal] = field(default_factory=list)
    message: str = ""
    fetched_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "status": self.status.value,
            "signals": [s.to_dict() for s in self.signals],
            "signal_count": len(self.signals),
            "message": self.message,
            "fetched_at": self.fetched_at.isoformat(),
        }


class AudienceSourceConnector(ABC):
    """Base class every audience-intelligence source must implement."""

    metadata: SourceMetadata

    @abstractmethod
    def is_configured(self) -> bool:
        """True when the connector can actually fetch (keys present or
        keyless public access)."""

    @abstractmethod
    def fetch_signals(self, topics: list[str] | None = None,
                      geography: str = "",
                      limit: int = 20) -> FetchResult:
        """Return normalized interest signals. Must never raise on missing
        credentials — return ``not_configured`` instead. Must never return
        fabricated signals."""

    def describe(self) -> dict:
        m = self.metadata
        return {
            "source_name": m.source_name,
            "access_method": m.access_method,
            "cost_tier": m.cost_tier.value,
            "rate_limit": m.rate_limit,
            "geographic_coverage": m.geographic_coverage,
            "freshness": m.freshness.value,
            "permitted_use": m.permitted_use.value,
            "confidence_score": m.confidence_score,
            "confidence_rationale": m.confidence_rationale,
            "tos_notes": m.tos_notes,
            "status": (SourceStatus.ready if self.is_configured()
                       else SourceStatus.not_configured).value,
        }
