"""Payoneer provider.

Payoneer is payout-first; for collections Virello uses Payoneer's partner
"request a payment" (billing service) flow:

  1. create_order -> billing request; payer gets a payment link / instructions.
  2. Payer completes payment on Payoneer's side.
  3. Payoneer sends a signed server-to-server callback -> parse_webhook verifies
     the signature before trusting anything.
  4. verify() re-checks the billing request status server-side.

The exact REST paths differ by partnership/integration type, so the API base
(and paths) come from settings — set them from your Payoneer partner docs.
Without credentials the provider fails closed (PaymentProviderNotConfigured).
"""
from __future__ import annotations

import hashlib
import hmac
import json
from decimal import Decimal

from app.core.config import settings
from .base import (
    Money, OrderRequest, OrderResult, PaymentProvider, PaymentProviderError,
    PaymentProviderNotConfigured, RefundResult, Verification, WebhookEvent, _http,
)


class PayoneerProvider(PaymentProvider):
    name = "payoneer"

    def __init__(self, api_base: str = "", api_key: str = "", api_secret: str = "") -> None:
        self._base = (api_base or settings.payoneer_api_base).rstrip("/")
        self._key = api_key or settings.payoneer_api_key
        self._secret = api_secret or settings.payoneer_api_secret
        self._client = None

    def _check(self) -> None:
        if not self._base or not self._key or not self._secret:
            raise PaymentProviderNotConfigured(
                "payoneer: set VIRELLO_PAYONEER_API_BASE, VIRELLO_PAYONEER_API_KEY and "
                "VIRELLO_PAYONEER_API_SECRET from your Payoneer partner documentation"
            )

    async def _api(self):
        self._check()
        if self._client is None:
            self._client = _http()
        return self._client

    def _auth_headers(self, body: str) -> dict:
        sig = hmac.new(self._secret.encode(), body.encode(), hashlib.sha256).hexdigest()
        return {"authorization": f"Bearer {self._key}",
                "x-payoneer-signature": sig,
                "content-type": "application/json"}

    async def create_order(self, req: OrderRequest) -> OrderResult:
        client = await self._api()
        body = json.dumps({
            "reference": req.idempotency_key or req.user_id,
            "description": f"Virello {req.kind}"
                           + (f" ({req.plan_slug})" if req.plan_slug else ""),
            "amount": {"value": f"{req.money.amount:.2f}",
                       "currency": req.money.currency},
            "return_url": req.return_url,
            "cancel_url": req.cancel_url,
        })
        try:
            resp = await client.post(f"{self._base}/billing/requests",
                                     headers=self._auth_headers(body),
                                     content=body.encode())
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise PaymentProviderError(f"payoneer create_order: {exc}") from exc
        return OrderResult(provider=self.name,
                           provider_order_id=str(data.get("id", "")),
                           approval_url=data.get("payment_url", ""),
                           client_payload={"billing_request": data})

    async def verify(self, provider_ref: str) -> Verification:
        client = await self._api()
        try:
            resp = await client.get(f"{self._base}/billing/requests/{provider_ref}",
                                    headers={"authorization": f"Bearer {self._key}"})
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise PaymentProviderError(f"payoneer verify: {exc}") from exc
        status = "completed" if data.get("status") in ("PAID", "COMPLETED") else (
            "pending" if data.get("status") in ("PENDING", "SENT") else "failed")
        amt = data.get("amount", {})
        return Verification(
            provider=self.name, provider_ref=provider_ref, status=status,
            money=Money(Decimal(str(amt.get("value", "0"))),
                        amt.get("currency", settings.billing_currency)),
            raw=data)

    async def refund(self, provider_ref: str, money: Money | None = None) -> RefundResult:
        client = await self._api()
        body = json.dumps({"reason": "virello_refund",
                           **({"amount": {"value": f"{money.amount:.2f}",
                                          "currency": money.currency}} if money else {})})
        try:
            resp = await client.post(f"{self._base}/billing/requests/{provider_ref}/refund",
                                     headers=self._auth_headers(body),
                                     content=body.encode())
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            raise PaymentProviderError(f"payoneer refund: {exc}") from exc
        return RefundResult(provider=self.name,
                            provider_refund_id=str(data.get("id", "")),
                            status="completed" if data.get("status") in
                            ("REFUNDED", "COMPLETED") else "pending")

    async def parse_webhook(self, headers: dict, body: bytes) -> WebhookEvent:
        raw = body.decode()
        expected = hmac.new(self._secret.encode(), raw.encode(),
                            hashlib.sha256).hexdigest()
        provided = headers.get("x-payoneer-signature", "")
        if not hmac.compare_digest(expected, provided):
            raise PaymentProviderError("payoneer webhook: invalid signature")
        payload = json.loads(raw)
        status = payload.get("status", "")
        return WebhookEvent(
            provider=self.name,
            event_type=f"billing.{status.lower()}",
            provider_ref=str(payload.get("id", "")),
            money=Money(Decimal(str(payload.get("amount", {}).get("value", "0"))),
                        payload.get("amount", {}).get("currency",
                                                      settings.billing_currency)),
            verified=True, raw=payload)

    async def aclose(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None
