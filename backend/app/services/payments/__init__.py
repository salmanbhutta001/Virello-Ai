"""Virello payments — provider-abstracted, no Stripe.

Supported providers: PayPal, Payoneer, Google Pay.
Every provider implements the same interface; the billing router and the
Admin Dashboard never touch provider SDKs directly.

Security rules (non-negotiable):
  - The client NEVER decides that money moved. Only server-side verification
    (provider API lookup or verified webhook) completes a transaction.
  - Webhooks are signature-verified before any state change.
  - All writes are idempotent: (provider, provider_ref) and idempotency_key
    are unique, so retries and duplicate webhooks cannot double-charge.
"""
from .base import (
    Money,
    OrderRequest,
    OrderResult,
    PaymentProvider,
    PaymentProviderError,
    PaymentProviderNotConfigured,
    RefundResult,
    Verification,
    WebhookEvent,
    get_payment_provider,
    supported_providers,
)

__all__ = [
    "Money",
    "OrderRequest",
    "OrderResult",
    "PaymentProvider",
    "PaymentProviderError",
    "PaymentProviderNotConfigured",
    "RefundResult",
    "Verification",
    "WebhookEvent",
    "get_payment_provider",
    "supported_providers",
]
