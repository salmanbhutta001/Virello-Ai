"""Connector registry — single place to list every audience-intelligence source."""
from __future__ import annotations

from app.services.audience_sources.base import AudienceSourceConnector
from app.services.audience_sources.github import GitHubConnector
from app.services.audience_sources.google_ads import GoogleAdsConnector
from app.services.audience_sources.google_trends import GoogleTrendsConnector
from app.services.audience_sources.open_datasets import OpenDatasetsConnector
from app.services.audience_sources.pinterest import PinterestConnector
from app.services.audience_sources.reddit import RedditConnector
from app.services.audience_sources.rss_news import RssNewsConnector
from app.services.audience_sources.tiktok import TikTokConnector
from app.services.audience_sources.wikipedia import WikipediaConnector
from app.services.audience_sources.youtube import YouTubeConnector


def all_connectors() -> list[AudienceSourceConnector]:
    return [
        GoogleTrendsConnector(),
        YouTubeConnector(),
        RedditConnector(),
        PinterestConnector(),
        RssNewsConnector(),
        WikipediaConnector(),
        GitHubConnector(),
        OpenDatasetsConnector(),
        GoogleAdsConnector(),
        TikTokConnector(),
    ]


def get_connector(name: str) -> AudienceSourceConnector | None:
    for c in all_connectors():
        if c.metadata.source_name == name:
            return c
    return None


def describe_all() -> list[dict]:
    """Metadata + live status for every connector (for GET /sources)."""
    return [c.describe() for c in all_connectors()]
