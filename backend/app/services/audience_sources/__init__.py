"""Multi-source audience intelligence connectors (legitimate sources only)."""
from app.services.audience_sources.base import (
    AudienceSourceConnector, CostTier, FetchResult, Freshness, InterestSignal,
    PermittedUse, SourceMetadata, SourceStatus,
)
from app.services.audience_sources.registry import (
    all_connectors, describe_all, get_connector,
)

__all__ = [
    "AudienceSourceConnector", "CostTier", "FetchResult", "Freshness",
    "InterestSignal", "PermittedUse", "SourceMetadata", "SourceStatus",
    "all_connectors", "describe_all", "get_connector",
]
