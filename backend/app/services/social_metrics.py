"""Provider-agnostic social-platform metrics ingestion (prep layer).

The AI Growth Engine's Performance agent currently measures Virello's own
Discovery interactions (view/save/visit/dismiss). This module is the honest
plumbing for OFFICIAL platform numbers (Instagram/Facebook via connected
accounts, or values the creator copies from the platform's own dashboard).

Nothing here fabricates data:
- `SocialMetricsProvider` implementations fetch or receive metrics; every
  result is validated and carries an explicit `source`.
- `ManualMetricsProvider` takes numbers the creator pasted from the official
  platform dashboard — clearly labeled `manual:official-dashboard`.
- `MetaMetricsProvider` is a DORMANT STUB: it raises
  `SocialMetricsNotConnected` until Meta/Instagram OAuth is actually wired.
  No live Graph API calls exist here.
- `blend_platform_metrics()` is the pure function the Performance agent will
  call later. It keeps Virello's own discovery numbers and official platform
  numbers STRICTLY SEPARATED — it never merges them into one ambiguous
  figure, because they measure different things.

Hook point (for the growth-engine owner, do NOT wire here):
    # in app/services/growth_engine.py::learn(), when snapshots exist:
    # blended = blend_platform_metrics(discovery_totals, platform_snapshots)
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime, timezone

METRIC_KEYS = ("views", "likes", "comments", "shares", "saves", "reach",
               "followers_delta")

# Hard sanity ceilings — reject values that are numerically impossible for a
# human-entered dashboard figure (protects against typos like 10**12).
_MAX_VALUE = 10_000_000_000  # 10B


class SocialMetricsError(Exception):
    """Base error for the social-metrics layer."""


class SocialMetricsValidationError(SocialMetricsError):
    """A metrics payload failed validation (negative, non-numeric, …)."""


class SocialMetricsNotConnected(SocialMetricsError):
    """The requested provider has no connected account yet."""


def validate_metrics(metrics: dict) -> dict:
    """Validate a raw metrics mapping and return a normalized copy.

    Raises SocialMetricsValidationError for missing/non-numeric/negative or
    absurdly large values. Missing keys default to 0.
    """
    if not isinstance(metrics, dict):
        raise SocialMetricsValidationError("metrics must be a JSON object")
    out: dict[str, int] = {}
    for key in METRIC_KEYS:
        raw = metrics.get(key, 0)
        if isinstance(raw, bool) or not isinstance(raw, (int, float)):
            raise SocialMetricsValidationError(
                f"metric '{key}' must be a number, got {type(raw).__name__}")
        value = int(raw)
        if value < 0:
            raise SocialMetricsValidationError(
                f"metric '{key}' must be >= 0, got {value}")
        if value > _MAX_VALUE:
            raise SocialMetricsValidationError(
                f"metric '{key}'={value} is impossibly large (>{_MAX_VALUE})")
        out[key] = value
    # Sanity: reach should not exceed views by a silly factor; likes+comments
    # +shares+saves should not exceed views by a silly factor. These are
    # *warnings-as-errors* because manual entry typos are the main risk.
    if out["views"] > 0:
        if out["reach"] > out["views"] * 100:
            raise SocialMetricsValidationError(
                "reach is >100x views — please re-check the dashboard figures")
        interactions = out["likes"] + out["comments"] + out["shares"] + out["saves"]
        if interactions > out["views"] * 100:
            raise SocialMetricsValidationError(
                "likes+comments+shares+saves is >100x views — please re-check")
    return out


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class SocialMetricsProvider(ABC):
    """ABC for official platform metrics sources."""

    name: str = "base"

    @abstractmethod
    async def fetch_metrics(self, account_ref: str, post_ref: str) -> dict:
        """Return a validated metrics dict with keys from METRIC_KEYS plus
        `source` and `captured_at`."""


class ManualMetricsProvider(SocialMetricsProvider):
    """Metrics the creator pasted from the platform's OFFICIAL dashboard.

    This is real data — just transported by hand. The source label keeps it
    honest about how it arrived.
    """

    name = "manual"
    SOURCE = "manual:official-dashboard"

    def __init__(self, metrics: dict):
        self._metrics = metrics

    async def fetch_metrics(self, account_ref: str = "",
                            post_ref: str = "") -> dict:
        data = validate_metrics(self._metrics)
        data["source"] = self.SOURCE
        data["captured_at"] = _utcnow_iso()
        data["account_ref"] = account_ref or None
        data["post_ref"] = post_ref or None
        return data


class MetaMetricsProvider(SocialMetricsProvider):
    """STUB — dormant until Meta/Instagram OAuth is wired.

    The user's Instagram connection is not completed, so no Graph API calls
    are implemented. Calling fetch_metrics now raises SocialMetricsNotConnected
    with a clear, user-facing message instead of pretending to return data.
    """

    name = "meta"
    SOURCE = "meta:graph-api"

    def __init__(self, access_token: str | None = None):
        self._access_token = access_token

    async def fetch_metrics(self, account_ref: str, post_ref: str) -> dict:
        raise SocialMetricsNotConnected(
            "Connect the Meta/Instagram account first")


def blend_platform_metrics(discovery_totals: dict, snapshots: list[dict]) -> dict:
    """Combine Virello discovery totals with official platform snapshots.

    Pure function. Returns clearly separated buckets — never one ambiguous
    merged number. Later snapshots override earlier ones per platform; the
    `platform` bucket keeps the latest snapshot per platform.

    discovery_totals: {"views": n, "saves": n, "visits": n, "dismissals": n}
    snapshots: list of validated metric dicts (each with platform, source,
               captured_at, and METRIC_KEYS values)
    """
    discovery = {k: int(discovery_totals.get(k, 0) or 0)
                 for k in ("views", "saves", "visits", "dismissals")}
    by_platform: dict[str, dict] = {}
    for snap in snapshots:
        platform = str(snap.get("platform", "unknown"))
        by_platform[platform] = {
            key: int(snap.get(key, 0) or 0) for key in METRIC_KEYS
        }
        by_platform[platform]["source"] = str(snap.get("source", "unknown"))
        by_platform[platform]["captured_at"] = snap.get("captured_at")
    platform_totals = {key: sum(p.get(key, 0) for p in by_platform.values())
                       for key in METRIC_KEYS}
    return {
        "discovery": discovery,      # Virello's own genuine interactions
        "platform": platform_totals,  # official numbers, per latest snapshots
        "platform_by_source": by_platform,
        "disclaimer": ("'discovery' counts genuine interactions inside Virello's "
                       "own Discovery Platform. 'platform' counts official numbers "
                       "from connected social accounts or figures the creator "
                       "supplied from the platform's official dashboard. The two "
                       "are never merged into one number."),
    }
