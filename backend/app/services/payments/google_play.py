"""Google Play Billing — server-side purchase verification.

Unlike the redirect providers (PayPal / Payoneer / Google Pay), Play
purchases happen inside the Play Store app. The mobile app sends the
purchase token to POST /api/v1/billing/play/verify; this module checks
the token against the Play Developer API and returns the raw purchase
record. Money movement and plan/credit activation still flow through
the shared ledger (apply_verified_purchase) — this module never
touches money itself.
"""
from __future__ import annotations

import json

from fastapi import HTTPException

from app.core.config import settings

# Play product id -> (kind, plan_slug | credit_pack).
# These IDs must match the products created in Play Console
# (and the Flutter app's PlayBillingService.productIds).
PLAY_PRODUCT_IDS: dict[str, tuple[str, str]] = {
    "virello_credits_1000": ("credits", "starter"),
    "virello_credits_5000": ("credits", "growth"),
    "virello_credits_20000": ("credits", "scale"),
    "virello_pro_monthly": ("subscription", "pro"),
    "virello_scale_monthly": ("subscription", "scale"),
}


def _play_service():
    """Build the Play Developer API client from the service-account JSON.

    Raises 503 when not configured — honest, exactly like the other
    payment providers.
    """
    raw = (settings.play_service_account_json or "").strip()
    if not raw:
        raise HTTPException(503, "play billing not configured")
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        info = json.loads(raw)
        creds = service_account.Credentials.from_service_account_info(
            info,
            scopes=["https://www.googleapis.com/auth/androidpublisher"],
        )
        return build("androidpublisher", "v3", credentials=creds,
                     cache_discovery=False)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(503, f"play billing misconfigured: {exc}")


def verify_play_token(product_id: str, purchase_token: str, kind: str) -> dict:
    """Ask Google Play whether this purchase token is real and paid.

    Returns the raw Play purchase resource. Raises HTTPException:
      402 — purchaseState != 0 (not actually purchased at Google)
      502 — Play API error (bad/expired token, network, ...)
    The caller decides idempotency (already-consumed tokens with a local
    completed transaction are replays, not errors).
    """
    service = _play_service()
    package = (settings.play_package_name or "").strip() or "com.virello.virello"
    try:
        if kind == "credits":
            play = service.purchases().products().get(
                packageName=package, productId=product_id,
                token=purchase_token).execute()
        else:
            play = service.purchases().subscriptions().get(
                packageName=package, subscriptionId=product_id,
                token=purchase_token).execute()
    except Exception as exc:
        raise HTTPException(502, f"play verification failed: {exc}")
    if play.get("purchaseState", 1) != 0:
        raise HTTPException(402, "purchase not completed at Google Play")
    return play


def play_token_used(play: dict, kind: str) -> bool:
    """True when Google already marks this token consumed/acknowledged."""
    if kind == "credits":
        return play.get("consumptionState", 0) == 1
    return play.get("acknowledgementState", 0) == 1
