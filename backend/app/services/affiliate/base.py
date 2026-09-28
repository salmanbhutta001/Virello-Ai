"""Affiliate provider framework (Phase 4): key-gated, never synthetic.

Design principles (same as the audience_sources connectors):
- Every provider declares whether it is configured. Missing credentials
  → ``status="not_configured"`` and zero data — never synthetic products,
  prices, or availability.
- Affiliate links are outbound merchant links. Virello never takes payment
  for affiliate products; the product detail UI must show the FTC/Amazon
  disclosure ("Affiliate link — we may earn a commission").
- Real price/stock sync requires the provider's official API (e.g. Amazon
  PA-API 5.0) with credentials supplied via Secure Vault. Scraping
  merchant pages is forbidden.

This module ships the architecture: the ABC + an Amazon stub. The daily
AI curation agent (post-Phase 4) will use ``get_provider("amazon")`` once
PA-API credentials are configured.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class AffiliateProduct:
    """Normalized affiliate product from a provider API. Every field comes
    from the provider response — never invented."""
    provider: str                      # "amazon"
    external_id: str                    # ASIN for Amazon
    title: str
    price_cents: int | None = None     # None = price unavailable
    currency: str = "USD"
    image_urls: list[str] = field(default_factory=list)
    detail_url: str = ""               # merchant page (before tagging)
    affiliate_url: str = ""            # tagged affiliate link
    availability: str = "unknown"      # "in_stock" | "out_of_stock" | "unknown"


@dataclass
class AffiliateSyncResult:
    """Result of re-syncing a Virello product's price/stock from the
    provider API."""
    status: str                        # "synced" | "not_configured" | "error"
    product_id: str = ""
    price_cents: int | None = None
    stock_changed: bool = False
    message: str = ""


class AffiliateProvider(ABC):
    """Every affiliate backend implements this."""

    name: str = "base"

    @abstractmethod
    def is_configured(self) -> bool:
        """True only when the provider's API credentials are present."""

    @abstractmethod
    async def search_products(self, query: str, limit: int = 10) -> list[AffiliateProduct]:
        """Search the provider catalog. Returns [] when not configured."""

    @abstractmethod
    async def get_product(self, external_id: str) -> AffiliateProduct | None:
        """Fetch one product by provider id (ASIN). None when not
        configured or not found."""

    @abstractmethod
    def build_affiliate_url(self, external_id: str) -> str:
        """Build the tagged affiliate link for an external id. Raises
        AffiliateNotConfigured when credentials are missing."""

    @abstractmethod
    async def sync_product(self, product_id: str, external_id: str) -> AffiliateSyncResult:
        """Re-sync price/stock for a Virello product from the provider API.
        Returns status="not_configured" when credentials are missing."""


class AffiliateNotConfigured(Exception):
    """Provider selected but credentials missing. Fail closed."""


class AffiliateProviderError(Exception):
    """Provider API call failed (network / API error)."""


def get_affiliate_provider(name: str) -> AffiliateProvider:
    selected = (name or "").lower()
    if selected == "amazon":
        from .amazon import AmazonAffiliateProvider
        return AmazonAffiliateProvider()
    raise AffiliateProviderError(f"Unsupported affiliate provider: {name!r}")


def supported_affiliate_providers() -> list[str]:
    return ["amazon"]
