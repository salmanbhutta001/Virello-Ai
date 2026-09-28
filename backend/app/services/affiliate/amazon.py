"""Amazon Associates provider (stub — key-gated, never synthetic).

Real integration requires Amazon Product Advertising API 5.0 credentials
(access key, secret key, partner tag, region/host) supplied via Secure
Vault. Until then every method reports ``not_configured`` and returns
zero data — no synthetic products, prices, or availability, ever.

Policy notes (documented, not bypassed):
- PA-API 5.0 is the ONLY permitted Amazon product-data source. Scraping
  amazon.* pages is prohibited by Amazon's ToS and is never attempted here.
- Every affiliate link rendered in Virello's UI must carry the disclosure
  "Affiliate link — we may earn a commission" (FTC + Amazon Associates
  Operating Agreement).
"""
from __future__ import annotations

import os

from .base import (
    AffiliateNotConfigured,
    AffiliateProduct,
    AffiliateProvider,
    AffiliateSyncResult,
)


def _creds() -> dict[str, str]:
    return {
        "access_key": os.environ.get("VIRELLO_AMAZON_PAAPI_KEY", ""),
        "secret_key": os.environ.get("VIRELLO_AMAZON_PAAPI_SECRET", ""),
        # Partner Tag (Store ID) — public identifier, safe as env default.
        # Hafiz's approved Associate tag.
        "partner_tag": os.environ.get("VIRELLO_AMAZON_PARTNER_TAG", "topitems0c1-20"),
        "region": os.environ.get("VIRELLO_AMAZON_PAAPI_REGION", "us-east-1"),
    }


class AmazonAffiliateProvider(AffiliateProvider):
    name = "amazon"

    def is_configured(self) -> bool:
        """Full PA-API data access needs all three credentials."""
        c = _creds()
        return bool(c["access_key"] and c["secret_key"] and c["partner_tag"])

    def can_build_links(self) -> bool:
        """Affiliate link building needs only the Partner Tag."""
        return bool(_creds()["partner_tag"])

    async def search_products(self, query: str, limit: int = 10) -> list[AffiliateProduct]:
        # Key-gated: no credentials → zero results, never synthetic.
        return []

    async def get_product(self, external_id: str) -> AffiliateProduct | None:
        return None

    def build_affiliate_url(self, external_id: str) -> str:
        # Link building needs only the Partner Tag — no PA-API keys required.
        # Format: https://www.amazon.com/dp/{ASIN}?tag={partner_tag}
        c = _creds()
        if not c["partner_tag"]:
            raise AffiliateNotConfigured(
                "Amazon Partner Tag missing. Configure "
                "VIRELLO_AMAZON_PARTNER_TAG via Secure Vault."
            )
        tag = c["partner_tag"]
        asin = external_id.strip().upper()
        return f"https://www.amazon.com/dp/{asin}?tag={tag}"

    async def sync_product(self, product_id: str, external_id: str) -> AffiliateSyncResult:
        if not self.is_configured():
            return AffiliateSyncResult(
                status="not_configured",
                product_id=product_id,
                message=("Amazon PA-API credentials not configured. Price/stock "
                         "sync needs VIRELLO_AMAZON_PAAPI_KEY / SECRET / "
                         "PARTNER_TAG via Secure Vault."),
            )
        # Real PA-API GetItems call lands here once credentials exist.
        return AffiliateSyncResult(
            status="error",
            product_id=product_id,
            message="PA-API client not implemented yet.",
        )
