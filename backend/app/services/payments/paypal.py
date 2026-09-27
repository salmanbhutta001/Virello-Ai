"""PayPal provider (PayPal REST API — Orders v2 + Webhooks).

Flow:
  1. create_order -> PayPal order (intent CAPTURE), returns approval_url.
  2. Payer approves on paypal.com, returns to return_url.
  3. Server calls verify(order_id): GET /v2/checkout/orders/{id} — only
     status COMPLETED with a matching amount counts as paid.
  4. Webhooks: POST /v1/notifications/verify-webhook-signature before trusting.

Docs: https://developer.paypal.com/docs/api/orders/v2/
"""
from __future__ import annotations

import json
from decimal import Decimal

from app.core.config import settings
from .base import (
    Money, OrderRequest, OrderResult, PaymentProvider, PaymentProviderError,
    PaymentProviderNotConfigured, RefundResult, Verification, WebhookEvent, _http,
)


class PayPalProvider(PaymentProvider):
    name = "paypal"

    def __init__(self, client_id: str = "", secret: str = "", mode: str = "") -> None:
        self._client_id = client_id or settings.paypal_client_id
        self._secret = secret or settings.paypal_secret
        self._mode = (mode or settings.paypal_mode or "sandbox").lower()
        self._client = None
        self._token: str | None = None

    def _base(self) -> str:
        return "https://api-m.paypal.com" if self._mode == "live" else "https://api-m.sandbox.paypal.com"

    def _check(self) -> None:
        if not self._client_id or not self._secret:
            raise PaymentProviderNotConfigured(
                "paypal: set VIRELLO_PAYPAL_CLIENT_ID and VIRELLO_PAYPAL_SECRET"
            )

    async def _api(self):
        self._check()
        if self._client is None:
            self._client = _http()
        return self._client

    async def _access_token(self) -> str:
        if self._token:
            return self._token
        client = await self._api()
        try:
            resp = await client.post(
                f"{self._base()}/v1/oauth2/token",
                auth=(self._client_id, self._secret),
                data={"grant_type": "client_credentials"},
            )
            resp.raise_for_status()
            self._token = resp.json()["access_token"]
            return self._token
        except Exception as exc:
            raise PaymentProviderError(f"paypal oauth: {exc}") from exc

    async def create_order(self, req: OrderRequest) -> OrderResult:
        client = await self._api()
        token = await self._access_token()
        body = {
            "intent": "CAPTURE",
            "purchase_units": [{
                "reference_id": req.idempotency_key or req.user_id,
                "description": f"Virello {req.kind}"
                               + (f" ({req.plan_slug})" if req.plan_slug else ""),
                "amount": {
                    "currency_code": req.money.currency,
                    "value": f"{req.money.amount:.2f}",
                },
            }],
            "application_context": {
                "return_url": req.return_url,
                "cancel_url": req.cancel_url,
                "brand_name": "Virello",
            },
        }
        try:
            resp = await client.post(
                f"{self._base()}/v2/checkout/orders",
                headers={"authorization": f"Bearer {token}",
                         "PayPal-Request-Id": req.idempotency_key or req.user_id},
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise PaymentProviderError(f"paypal create_order: {exc}") from exc
        approval = next((l["href"] for l in data.get("links", [])
                         if l.get("rel") == "approve"), "")
        return OrderResult(provider=self.name, provider_order_id=data["id"],
                           approval_url=approval)

    async def verify(self, provider_ref: str) -> Verification:
        """Server-side truth: fetch the order and confirm CAPTURE completed."""
        client = await self._api()
        token = await self._access_token()
        try:
            resp = await client.get(
                f"{self._base()}/v2/checkout/orders/{provider_ref}",
                headers={"authorization": f"Bearer {token}"},
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise PaymentProviderError(f"paypal verify: {exc}") from exc
        status = "failed"
        amount = Decimal("0")
        currency = settings.billing_currency
        payer = ""
        if data.get("status") == "APPROVED":
            # Capture it server-side now (idempotent on PayPal's side).
            try:
                cap = await client.post(
                    f"{self._base()}/v2/checkout/orders/{provider_ref}/capture",
                    headers={"authorization": f"Bearer {token}",
                             "PayPal-Request-Id": f"capture-{provider_ref}"},
                    json={},
                )
                cap.raise_for_status()
                data = cap.json()
            except Exception as exc:
                raise PaymentProviderError(f"paypal capture: {exc}") from exc
        if data.get("status") == "COMPLETED":
            units = data.get("purchase_units", [])
            caps = (units[0].get("payments", {}).get("captures", []) if units else [])
            if caps and caps[0].get("status") == "COMPLETED":
                amt = caps[0]["amount"]
                amount = Decimal(str(amt["value"]))
                currency = amt["currency_code"]
                status = "completed"
                payer = ((data.get("payer") or {}).get("payer_id") or "")
        return Verification(provider=self.name, provider_ref=provider_ref,
                            status=status, money=Money(amount, currency),
                            payer_id=payer, raw={"order": data})

    async def refund(self, provider_ref: str, money: Money | None = None) -> RefundResult:
        client = await self._api()
        token = await self._access_token()
        # provider_ref here is the CAPTURE id (stored at verify time).
        body: dict = {}
        if money:
            body["amount"] = {"currency_code": money.currency, "value": f"{money.amount:.2f}"}
        try:
            resp = await client.post(
                f"{self._base()}/v2/payments/captures/{provider_ref}/refund",
                headers={"authorization": f"Bearer {token}"},
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise PaymentProviderError(f"paypal refund: {exc}") from exc
        return RefundResult(provider=self.name,
                            provider_refund_id=data.get("id", ""),
                            status="completed" if data.get("status") == "COMPLETED" else "pending")

    async def parse_webhook(self, headers: dict, body: bytes) -> WebhookEvent:
        """Verify the webhook signature with PayPal before trusting anything."""
        client = await self._api()
        token = await self._access_token()
        payload = json.loads(body.decode())
        verify_body = {
            "auth_algo": headers.get("paypal-auth-algo", ""),
            "cert_url": headers.get("paypal-cert-url", ""),
            "transmission_id": headers.get("paypal-transmission-id", ""),
            "transmission_sig": headers.get("paypal-transmission-sig", ""),
            "transmission_time": headers.get("paypal-transmission-time", ""),
            "webhook_id": settings.paypal_webhook_id,
            "webhook_event": payload,
        }
        try:
            resp = await client.post(
                f"{self._base()}/v1/notifications/verify-webhook-signature",
                headers={"authorization": f"Bearer {token}"},
                json=verify_body,
            )
            resp.raise_for_status()
            ok = resp.json().get("verification_status") == "SUCCESS"
        except Exception as exc:
            raise PaymentProviderError(f"paypal webhook verify: {exc}") from exc
        if not ok:
            raise PaymentProviderError("paypal webhook: invalid signature")
        event_type = payload.get("event_type", "")
        resource = payload.get("resource", {})
        ref = resource.get("id") or resource.get("supplementary_data", {}) \
            .get("related_ids", {}).get("order_id", "")
        amount = resource.get("amount", {})
        status = "completed" if event_type in (
            "PAYMENT.CAPTURE.COMPLETED", "CHECKOUT.ORDER.APPROVED") else "pending"
        return WebhookEvent(
            provider=self.name, event_type=event_type, provider_ref=ref,
            money=Money(Decimal(str(amount.get("value", "0"))),
                        amount.get("currency_code", settings.billing_currency)),
            verified=True, raw=payload)

    async def aclose(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None
