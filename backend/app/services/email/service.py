"""Email service: provider selection + safe payment-receipt sending.

send_payment_receipt NEVER raises — a failed email must never break a
purchase. It logs and returns False on any failure.
"""
import logging
import os

from .base import EmailProvider
from .brevo import BrevoProvider
from .console import ConsoleProvider
from .smtp import SmtpProvider
from .templates import payment_receipt

log = logging.getLogger("virello.email")


def _parse_from(raw: str) -> tuple[str, str]:
    # "Virello <noreply@virello.app>" -> ("Virello", "noreply@virello.app")
    raw = (raw or "").strip()
    if "<" in raw and raw.endswith(">"):
        name, addr = raw.rsplit("<", 1)
        return name.strip().strip('"') or "Virello", addr[:-1].strip()
    return "Virello", raw or "noreply@virello.app"


def get_email_provider() -> EmailProvider:
    which = os.environ.get("EMAIL_PROVIDER", "console").lower()
    if which == "brevo":
        sender_name, sender_email = _parse_from(os.environ.get("EMAIL_FROM", ""))
        return BrevoProvider(
            api_key=os.environ.get("BREVO_API_KEY", ""),
            sender_email=sender_email,
            sender_name=sender_name,
        )
    if which == "smtp":
        return SmtpProvider(
            host=os.environ.get("SMTP_HOST", ""),
            port=int(os.environ.get("SMTP_PORT", "587")),
            username=os.environ.get("SMTP_USER", ""),
            password=os.environ.get("SMTP_PASS", ""),
            from_addr=os.environ.get("EMAIL_FROM", "noreply@virello.app"),
        )
    return ConsoleProvider()


async def send_payment_receipt(user, txn, item_name: str) -> bool:
    """Email the user a greeting + payment receipt. Never raises."""
    try:
        to = (getattr(user, "email", "") or "").strip()
        if not to:
            log.warning("payment receipt skipped: user has no email")
            return False
        name = (getattr(user, "name", "") or "").strip() or to.split("@")[0]
        language = (getattr(user, "locale", "") or "en").lower()
        created = getattr(txn, "created_at", None)
        date_str = created.strftime("%Y-%m-%d %H:%M UTC") if created else ""
        subject, html, text = payment_receipt(
            user_name=name,
            language=language,
            item_name=item_name,
            amount=float(getattr(txn, "amount", 0) or 0),
            currency=(getattr(txn, "currency", "") or "USD"),
            provider=getattr(txn, "provider", ""),
            txn_ref=str(getattr(txn, "provider_ref", "") or getattr(txn, "id", "")),
            date_str=date_str,
        )
        provider = get_email_provider()
        await provider.send(to=to, subject=subject, html=html, text=text)
        log.info("payment receipt sent to %s via %s", to, provider.name)
        return True
    except Exception:  # noqa: BLE001 — email must never break a purchase
        log.exception("payment receipt failed")
        return False
