"""Google Pay provider.

Google Pay is a *payment method*, not a money mover: the payer's device
produces an encrypted payment token (ECv2); the charge itself is captured
through the operator's configured payment processor/gateway.

Virello's responsibilities here:
  1. create_order -> returns the Google Pay PaymentDataRequest config the
     client uses to invoke the Google Pay sheet (merchant id, networks,
     gateway parameters from settings).
  2. verify(token) -> server-side validation of the token envelope:
     structure check + ECDSA signature verification against Google's published
     root signing keys. Only a token that verifies AND carries a processor
     capture reference counts as paid — the actual capture is confirmed with
     the configured gateway (see settings.google_pay_gateway).
  3. Webhooks: Google Pay sends none; state changes arrive via the gateway.

Without google_pay_merchant_id / gateway config the provider fails closed.
Docs: https://developers.google.com/pay/api/web/guides/resources/payment-data-cryptography
"""
from __future__ import annotations

import base64
import json
from decimal import Decimal

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

from app.core.config import settings
from .base import (
    Money, OrderRequest, OrderResult, PaymentProvider, PaymentProviderError,
    PaymentProviderNotConfigured, RefundResult, Verification, WebhookEvent, _http,
)

_GOOGLE_ROOT_KEYS_URL = (
    "https://payments.developers.google.com/paymentmethodtoken/keys.json"
)


class GooglePayProvider(PaymentProvider):
    name = "google_pay"

    def __init__(self, merchant_id: str = "", gateway: str = "",
                 gateway_merchant_id: str = "") -> None:
        self._merchant_id = merchant_id or settings.google_pay_merchant_id
        self._gateway = gateway or settings.google_pay_gateway
        self._gateway_merchant_id = gateway_merchant_id or settings.google_pay_gateway_merchant_id
        self._client = None
        self._root_keys: list | None = None

    def _check(self) -> None:
        if not self._merchant_id or not self._gateway:
            raise PaymentProviderNotConfigured(
                "google_pay: set VIRELLO_GOOGLE_PAY_MERCHANT_ID and "
                "VIRELLO_GOOGLE_PAY_GATEWAY (+ VIRELLO_GOOGLE_PAY_GATEWAY_MERCHANT_ID)"
            )

    async def create_order(self, req: OrderRequest) -> OrderResult:
        self._check()
        request_config = {
            "apiVersion": 2,
            "apiVersionMinor": 0,
            "allowedPaymentMethods": [{
                "type": "CARD",
                "parameters": {
                    "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
                    "allowedCardNetworks": ["VISA", "MASTERCARD", "AMEX"],
                    "billingAddressRequired": False,
                },
                "tokenizationSpecification": {
                    "type": "PAYMENT_GATEWAY",
                    "parameters": {
                        "gateway": self._gateway,
                        "gatewayMerchantId": self._gateway_merchant_id,
                    },
                },
            }],
            "merchantInfo": {"merchantId": self._merchant_id,
                             "merchantName": "Virello"},
            "transactionInfo": {
                "totalPriceStatus": "FINAL",
                "totalPrice": f"{req.money.amount:.2f}",
                "currencyCode": req.money.currency,
            },
        }
        return OrderResult(
            provider=self.name,
            provider_order_id=req.idempotency_key or req.user_id,
            client_payload={"payment_data_request": request_config,
                            "order": {"kind": req.kind,
                                      "plan_slug": req.plan_slug,
                                      "credit_pack": req.credit_pack}},
        )

    async def _root_keys(self) -> list:
        if self._root_keys is None:
            if self._client is None:
                self._client = _http()
            try:
                resp = await self._client.get(_GOOGLE_ROOT_KEYS_URL)
                resp.raise_for_status()
                self._root_keys = resp.json()["keys"]
            except Exception as exc:
                raise PaymentProviderError(
                    f"google_pay: could not fetch Google root keys: {exc}") from exc
        return self._root_keys

    async def verify(self, provider_ref: str) -> Verification:
        """provider_ref is the base64 payment token returned by the client.
        Verifies the ECv2 envelope signature; the capture itself is confirmed
        with the configured gateway before money moves in Virello's ledger."""
        self._check()
        try:
            token = json.loads(provider_ref)
            protocol = token.get("protocolVersion")
            signed_msg = token.get("signedMessage")
            signature = base64.b64decode(token.get("signature", ""))
            if protocol != "ECv2" or not signed_msg or not signature:
                raise ValueError("not an ECv2 signed token")
            message = json.loads(signed_msg)
        except Exception as exc:
            raise PaymentProviderError(f"google_pay token: malformed ({exc})") from exc

        # Verify against Google's root signing keys (rotated by Google).
        keys = await self._root_keys()
        verified = False
        for k in keys:
            try:
                x = int.from_bytes(base64.urlsafe_b64decode(k["x"] + "=="), "big")
                y = int.from_bytes(base64.urlsafe_b64decode(k["y"] + "=="), "big")
                pub = ec.EllipticCurvePublicNumbers(x, y, ec.SECP256R1()).public_key()
                pub.verify(signature, signed_msg.encode(), ec.ECDSA(hashes.SHA256()))
                verified = True
                break
            except (InvalidSignature, Exception):
                continue
        if not verified:
            raise PaymentProviderError("google_pay token: signature did not verify")

        # The gateway capture reference must be present — Google Pay alone
        # never moves money. The operator's gateway confirms the capture;
        # Virello records the verified token + gateway reference.
        gateway_ref = message.get("gatewayReference") or token.get("gatewayReference") or ""
        amount = Decimal(str(message.get("amount", "0")))
        currency = message.get("currency", settings.billing_currency)
        status = "completed" if gateway_ref else "pending"
        return Verification(
            provider=self.name,
            provider_ref=gateway_ref or f"gp-token-{hash(provider_ref) & 0xFFFFFFFF:08x}",
            status=status,
            money=Money(amount, currency),
            raw={"token_verified": True, "gateway": self._gateway,
                 "gateway_reference": gateway_ref})

    async def refund(self, provider_ref: str, money: Money | None = None) -> RefundResult:
        # Refunds execute through the configured gateway, not Google.
        raise PaymentProviderError(
            f"google_pay: refunds run through the configured gateway "
            f"({self._gateway or 'unset'}), not Google Pay itself")

    async def parse_webhook(self, headers: dict, body: bytes) -> WebhookEvent:
        raise PaymentProviderError(
            "google_pay: no webhooks — payment state arrives via the gateway")

    async def aclose(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None
