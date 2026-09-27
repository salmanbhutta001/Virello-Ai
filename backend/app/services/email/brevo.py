"""Brevo transactional email API (free tier: 300 emails/day, no card).

POST https://api.brevo.com/v3/smtp/email
Headers: {"api-key": <BREVO_API_KEY>}
Body: {sender: {email, name}, to: [{email}], subject, htmlContent, textContent}
"""
import httpx

from .base import EmailProvider


class BrevoProvider(EmailProvider):
    name = "brevo"

    def __init__(self, api_key: str, sender_email: str, sender_name: str = "Virello"):
        if not api_key:
            raise ValueError("BREVO_API_KEY is required for the Brevo provider")
        self.api_key = api_key
        self.sender_email = sender_email
        self.sender_name = sender_name

    async def send(self, to: str, subject: str, html: str, text: str) -> dict:
        payload = {
            "sender": {"email": self.sender_email, "name": self.sender_name},
            "to": [{"email": to}],
            "subject": subject,
            "htmlContent": html,
            "textContent": text,
        }
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                "https://api.brevo.com/v3/smtp/email",
                headers={"api-key": self.api_key,
                         "Content-Type": "application/json",
                         "Accept": "application/json"},
                json=payload,
            )
        if resp.status_code >= 400:
            raise RuntimeError(
                f"Brevo send failed: HTTP {resp.status_code} {resp.text[:200]}")
        return {"provider": self.name, "message_id": resp.json().get("messageId")}
