"""Generic SMTP fallback (e.g. Gmail SMTP, Brevo SMTP relay).
stdlib smtplib + STARTTLS, run in a thread so the event loop never blocks."""
import asyncio
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from .base import EmailProvider


class SmtpProvider(EmailProvider):
    name = "smtp"

    def __init__(self, host: str, port: int, username: str, password: str,
                 from_addr: str, use_tls: bool = True):
        if not host or not username:
            raise ValueError("SMTP_HOST and SMTP_USER are required")
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.from_addr = from_addr
        self.use_tls = use_tls

    def _send_sync(self, to: str, subject: str, html: str, text: str) -> None:
        msg = MIMEMultipart("alternative")
        msg["From"] = self.from_addr
        msg["To"] = to
        msg["Subject"] = subject
        msg.attach(MIMEText(text, "plain", "utf-8"))
        msg.attach(MIMEText(html, "html", "utf-8"))
        with smtplib.SMTP(self.host, self.port, timeout=15) as server:
            if self.use_tls:
                server.starttls()
            server.login(self.username, self.password)
            server.sendmail(self.from_addr, [to], msg.as_string())

    async def send(self, to: str, subject: str, html: str, text: str) -> dict:
        await asyncio.to_thread(self._send_sync, to, subject, html, text)
        return {"provider": self.name}
