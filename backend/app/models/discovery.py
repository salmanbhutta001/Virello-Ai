"""Discovery data models — cached display images for trending topics."""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.core import Base


class TrendImageCache(Base):
    """Resolved display image per trending topic (topic_key -> image URL).

    Resolution order (see app.services.discovery.trend_images):
      1. Real Wikipedia pageimage (truthful photo).
      2. Stylized thematic illustration (generated; abstract only — never a
         photorealistic depiction of a real person).

    Cached so topics are resolved once, not on every Trending load.
    """
    __tablename__ = "trend_image_cache"

    topic_key: Mapped[str] = mapped_column(String(256), primary_key=True)
    image_url: Mapped[str] = mapped_column(Text, nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)  # 'wikipedia' | 'generated'
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
