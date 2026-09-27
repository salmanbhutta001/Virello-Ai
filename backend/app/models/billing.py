"""Billing + admin-domain models: transactions, credit ledger, plans,
country config, system settings, broadcasts.

Payments are provider-abstracted (PayPal / Payoneer / Google Pay).
Every money movement lands in `transactions` (idempotent) and every
credit movement in `credit_ledger` — the Admin Dashboard reads both.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Transaction(Base):
    """Immutable money-movement record. Idempotent on (provider, provider_ref)
    and on idempotency_key so webhooks/retries can never double-charge."""

    __tablename__ = "transactions"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    provider: Mapped[str] = mapped_column(String(32))  # paypal | payoneer | google_pay
    provider_ref: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    kind: Mapped[str] = mapped_column(String(32))  # subscription | credits | refund
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(8), default="USD")
    status: Mapped[str] = mapped_column(String(32), default="pending")
    # completed | pending | failed | refunded
    idempotency_key: Mapped[str] = mapped_column(String(128), unique=True)
    raw: Mapped[dict] = mapped_column(JSON, default=dict)  # provider payload refs
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CreditLedger(Base):
    """Every AI-credit movement, with running balance. Append-only."""

    __tablename__ = "credit_ledger"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    delta: Mapped[int] = mapped_column(Integer)  # +purchase/grant, -usage
    balance_after: Mapped[int] = mapped_column(Integer)
    reason: Mapped[str] = mapped_column(String(128))
    transaction_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("transactions.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class PlanConfig(Base):
    """DB-driven plans/pricing — editable from the Admin Dashboard."""

    __tablename__ = "plans"
    slug: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(64))
    price_usd: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    currency: Mapped[str] = mapped_column(String(8), default="USD")
    ai_credits_monthly: Mapped[int] = mapped_column(Integer, default=0)
    campaigns_limit: Mapped[int] = mapped_column(Integer, default=3)
    active: Mapped[bool] = mapped_column(default=True)
    sort: Mapped[int] = mapped_column(Integer, default=0)


class CountryConfig(Base):
    """Per-country availability, currency and pricing overrides."""

    __tablename__ = "countries"
    code: Mapped[str] = mapped_column(String(8), primary_key=True)  # ISO alpha-2
    name: Mapped[str] = mapped_column(String(64))
    enabled: Mapped[bool] = mapped_column(default=True)
    currency: Mapped[str] = mapped_column(String(8), default="USD")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SystemSetting(Base):
    """Key-value system settings, editable from the Admin Dashboard."""

    __tablename__ = "system_settings"
    key: Mapped[str] = mapped_column(String(128), primary_key=True)
    value: Mapped[dict] = mapped_column(JSON, default=dict)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class Broadcast(Base):
    """Admin → users notifications."""

    __tablename__ = "broadcasts"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String(128))
    body: Mapped[str] = mapped_column(Text)
    audience: Mapped[str] = mapped_column(String(32), default="all")  # all | free | paid
    # {lang_code: {title, body}} — admin-provided translations. Clients
    # fall back to title/body when the user's language is missing.
    translations: Mapped[dict] = mapped_column(JSON, default=dict)
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
