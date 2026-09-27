"""Email provider abstraction. Free-first: Brevo (300/day, no card),
generic SMTP fallback, console/log for dev. Nothing paid."""
from abc import ABC, abstractmethod


class EmailProvider(ABC):
    name = "base"

    @abstractmethod
    async def send(self, to: str, subject: str, html: str, text: str) -> dict:
        """Send one email. Returns provider info dict. Raises on failure."""
