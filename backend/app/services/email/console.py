"""Dev default: log the email instead of sending. Never fails."""
import logging

from .base import EmailProvider

log = logging.getLogger("virello.email")


class ConsoleProvider(EmailProvider):
    name = "console"

    async def send(self, to: str, subject: str, html: str, text: str) -> dict:
        log.info("[email:console] to=%s subject=%s\n%s", to, subject, text)
        return {"provider": self.name, "logged": True}
