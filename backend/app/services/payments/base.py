"""Payment provider interface, value objects and factory."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from decimal import Decimal

import httpx

from app.core.config import settings


class PaymentProviderError(Exception):
    """Provider call failed (network / API error)."""


class PaymentProviderNotConfigured(Exception):
    """Provider selected but credentials missing. Fail closed."""


@dataclass(frozen=True)
class Money:
    amount: Decimal
    currency: str = "USD"


@dataclass
class OrderRequest:
    user_id: str
    kind: str                      # "subscription" | "credits"
    money: Money
    plan_slug: str = ""            # for kind == "subscription"
    credit_pack: str = ""          # for kind == "credits"
    return_url: str = ""
    cancel_url: str = ""
    idempotency_key: str = ""
    metadata: dict = field(default_factory=dict)


@dataclass
class OrderResult:
    provider: str
    provider_order_id: str
    approval_url: str = ""         # where the payer approves (PayPal/Payoneer)
    client_payload: dict = field(default_factory=dict)  # e.g. Google Pay request config


@dataclass
class Verification:
    """Result of SERVER-SIDE verification. Only status == 'completed'
    (with matching amount) may move money."""
    provider: str
    provider_ref: str
    status: str                    # completed | pending | failed
    money: Money
    payer_id: str = ""
    raw: dict = field(default_factory=dict)


@dataclass
class RefundResult:
    provider: str
    provider_refund_id: str
    status: str                    # completed | pending | failed


@dataclass
class WebhookEvent:
    provider: str
    event_type: str                # e.g. "payment.completed"
    provider_ref: str
    money: Money
    verified: bool = False
    raw: dict = field(default_factory=dict)


class PaymentProvider(ABC):
    """Every payment backend implements this."""

    name: str = "base"

    @abstractmethod
    async def create_order(self, req: OrderRequest) -> OrderResult:
        """Create a provider-side order / billing request."""

    @abstractmethod
    async def verify(self, provider_ref: str) -> Verification:
        """Server-side truth: ask the provider whether money moved."""

    @abstractmethod
    async def refund(self, provider_ref: str, money: Money | None = None) -> RefundResult:
        ...

    @abstractmethod
    async def parse_webhook(self, headers: dict, body: bytes) -> WebhookEvent:
        """Verify the webhook signature and normalize the event.
        Must raise PaymentProviderError when the signature is invalid."""

    async def aclose(self) -> None:
        ...


def _http() -> httpx.AsyncClient:
    # Explicit proxy wiring (trust_env=False): httpx chokes on bracketed
    # IPv6 entries like [::1] in no_proxy. We read the proxy ourselves.
    # TLS uses the OS CA store (not certifi) so intercepting egress proxies
    # whose CA is installed system-wide keep working; SSL_CERT_FILE wins.
    import os
    import ssl
    proxy = (os.environ.get("https_proxy") or os.environ.get("HTTPS_PROXY")
             or os.environ.get("http_proxy") or os.environ.get("HTTP_PROXY"))
    cafile = os.environ.get("SSL_CERT_FILE")
    ctx = ssl.create_default_context(cafile=cafile) if cafile \
        else ssl.create_default_context()
    return httpx.AsyncClient(
        trust_env=False,
        proxy=proxy or None,
        verify=ctx,
        timeout=httpx.Timeout(30.0, connect=10.0),
    )


def supported_providers() -> list[str]:
    return ["paypal", "payoneer", "google_pay"]


def get_payment_provider(name: str) -> PaymentProvider:
    selected = (name or "").lower()
    if selected == "paypal":
        from .paypal import PayPalProvider
        return PayPalProvider()
    if selected == "payoneer":
        from .payoneer import PayoneerProvider
        return PayoneerProvider()
    if selected == "google_pay":
        from .google_pay import GooglePayProvider
        return GooglePayProvider()
    raise PaymentProviderError(f"Unsupported payment provider: {name!r}")
