"""Referral loop (free organic growth strategy #5).

A user shares their personal referral code/link. A new user signs up with
that code -> a referral_event is recorded as ``pending`` -> when the new
user's signup is verified (OTP verify / password signup complete), both
the referrer and the referred user receive AI credits via the append-only
credit_ledger (idempotent per referred user).

Hard rules (non-negotiable):
- self-referral is blocked (same user, same email);
- a new user can only ever generate ONE referral_event;
- credits are paid ONLY for verified signups, never twice.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID, _uuid


class ReferralCode(Base):
    """One permanent, shareable code per user."""

    __tablename__ = "referral_codes"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True)
    code: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class ReferralEvent(Base):
    """A new user who signed up with somebody's referral code.

    ``referred_user_id`` is unique: one user can only ever be referred once,
    and credits move pending -> credited exactly once.
    """

    __tablename__ = "referral_events"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    code_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("referral_codes.id"), index=True)
    referrer_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), index=True)
    referred_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True)
    # pending | credited
    status: Mapped[str] = mapped_column(String(16), default="pending")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    credited_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
