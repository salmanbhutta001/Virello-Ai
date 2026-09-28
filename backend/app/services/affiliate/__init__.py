"""Affiliate provider framework — public interface."""
from .base import (
    AffiliateNotConfigured,
    AffiliateProduct,
    AffiliateProvider,
    AffiliateProviderError,
    AffiliateSyncResult,
    get_affiliate_provider,
    supported_affiliate_providers,
)

__all__ = [
    "AffiliateNotConfigured",
    "AffiliateProduct",
    "AffiliateProvider",
    "AffiliateProviderError",
    "AffiliateSyncResult",
    "get_affiliate_provider",
    "supported_affiliate_providers",
]
