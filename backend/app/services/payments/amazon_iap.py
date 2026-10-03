"""Amazon Appstore IAP — server-side receipt verification (RVS).

The mobile app (amazon flavor) sends the Amazon receipt ID + Amazon user ID
to POST /api/v1/billing/amazon/verify; this module checks the receipt
against Amazon's Receipt Verification Service and returns the parsed
receipt. Money movement and plan/credit activation still flow through the
shared ledger (apply_verified_purchase) — this module never touches
money itself.

RVS endpoints (no auth needed; HTTPS GET):
  Production: https://appstore-sdk.amazon.com/version/1.0/verifyReceiptId/developer/{developerSecret}/user/{userId}/receiptId/{receiptId}
  Sandbox:    https://appstore-sdk.amazon.com/sandbox/version/1.0/verifyReceiptId/developer/{developerSecret}/user/{userId}/receiptId/{receiptId}

The developer secret comes from the Amazon Developer Console
(Appstore > Shared Key / developer secret). Set VIRELLO_AMAZON_DEVELOPER_SECRET
in the backend env. Sandbox mode is auto-selected via VIRELLO_AMAZON_SANDBOX=true
(or when the receipt verification indicates a test receipt).
"""
from __future__ import annotations

import httpx
from fastapi import HTTPException

from app.core.config import settings

# Amazon SKU -> (kind, plan_slug | credit_pack | ad_package).
# These SKUs must match the In-App Items created in the Amazon
# Developer Console (and the Flutter app's AmazonBilling SKU set).
# Ad packages are CONSUMABLE in-app items (one per Paid Boost package),
# separate from the credit packs — see google_play.py for the rationale.
AMAZON_SKUS: dict[str, tuple[str, str]] = {
    "virello_credits_1000": ("credits", "starter"),
    "virello_credits_5000": ("credits", "growth"),
    "virello_credits_20000": ("credits", "scale"),
    "virello_pro_monthly": ("subscription", "pro"),
    "virello_scale_monthly": ("subscription", "scale"),
    "virello_ad_starter": ("ad_package", "starter"),
    "virello_ad_growth": ("ad_package", "growth"),
    "virello_ad_pro": ("ad_package", "pro"),
    "virello_ad_scale": ("ad_package", "scale"),
}

_RVS_PROD = "https://appstore-sdk.amazon.com/version/1.0/verifyReceiptId"
_RVS_SANDBOX = "https://appstore-sdk.amazon.com/sandbox/version/1.0/verifyReceiptId"


def _developer_secret() -> str:
    secret = (settings.amazon_developer_secret or "").strip()
    if not secret:
        raise HTTPException(503, "amazon iap not configured")
    return secret


def verify_amazon_receipt(receipt_id: str, user_id: str) -> dict:
    """Ask Amazon RVS whether this receipt is real and paid.

    Returns the parsed RVS JSON. Raises HTTPException:
      402 — receipt canceled (cancelDate present)
      404 — receipt not found / invalid
      409 — receipt already canceled at Amazon
      503 — backend not configured (no developer secret)
    """
    secret = _developer_secret()
    base = _RVS_SANDBOX if settings.amazon_sandbox else _RVS_PROD
    url = f"{base}/developer/{secret}/user/{user_id}/receiptId/{receipt_id}"
    try:
        resp = httpx.get(url, timeout=15.0)
    except Exception as exc:
        raise HTTPException(502, f"amazon rvs unreachable: {exc}")
    if resp.status_code == 400:
        raise HTTPException(404, "amazon receipt invalid")
    if resp.status_code == 496:
        raise HTTPException(503, "amazon developer secret invalid")
    if resp.status_code == 497:
        raise HTTPException(404, "amazon user id invalid")
    if resp.status_code != 200:
        raise HTTPException(502, f"amazon rvs error {resp.status_code}")
    data = resp.json()
    # RVS returns cancelDate when the purchase was canceled/refunded —
    # it must never grant credits or plans.
    if data.get("cancelDate"):
        raise HTTPException(402, "amazon receipt canceled")
    return data


def amazon_receipt_used(receipt: dict, kind: str) -> bool:
    """True when Amazon already marks the receipt consumed/fulfilled.

    For consumables Amazon returns no explicit consumed flag via RVS;
    fulfillment is tracked by our own idempotency (provider_ref), same
    as the Play path. This helper exists for symmetry and future use.
    """
    return False
