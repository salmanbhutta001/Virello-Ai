"""Virello Points: append-only rewards ledger.

Users earn points for genuine activity (posting to the discovery feed,
receiving likes/comments, streaks, daily login, profile completion,
referrals) and can redeem them for Grow credits. Points are NEVER bought,
faked, or granted without a real triggering event.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.core import GUID


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class PointsLedger(Base):
    """One row per points movement. Append-only; balance = SUM(delta).

    Idempotency: (user_id, reason, ref_id) is unique, so the same event
    can never pay twice. Cap-suppressed awards are recorded with
    delta=0 and reason="cap_skipped" for audit (excluded from history).
    """

    __tablename__ = "points_ledger"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    delta: Mapped[int] = mapped_column(Integer, default=0)
    reason: Mapped[str] = mapped_column(String(64), index=True)
    # post_created | streak | like_received | comment_received |
    # profile_completed | daily_login | referral | redeem | admin_adjust |
    # cap_skipped
    ref_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)

    __table_args__ = (
        UniqueConstraint("user_id", "reason", "ref_id",
                         name="uq_points_user_reason_ref"),
    )


class RewardClaim(Base):
    """Proof-based reward claim. share claims require a screenshot proof
    (the shared post on the user's social media) and wait for admin
    approval; other types auto-approve per the rewards.auto_approve
    setting (still logged as a claim).

    Exactly one of amount_cents / points is set. Idempotency:
    (user_id, claim_type, ref_id) is unique and a claim can only move
    out of "pending" once, so the ledger is credited at most once per
    claim even if approve is called twice.
    """

    __tablename__ = "reward_claims"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    claim_type: Mapped[str] = mapped_column(String(32), index=True)
    # share | post | streak | like_received | comment_received |
    # volume_bonus | winner
    ref_id: Mapped[str | None] = mapped_column(String(128), nullable=True,
                                              index=True)
    # placement id for post/share claims, period label for recurring ones
    amount_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    points: Mapped[int | None] = mapped_column(Integer, nullable=True)
    proof_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="pending",
                                        index=True)
    # pending | approved | rejected
    admin_note: Mapped[str | None] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)
    decided_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("user_id", "claim_type", "ref_id",
                         name="uq_reward_claims_user_type_ref"),
    )


class ShareClick(Base):
    """A verified visit through a user's share link (GET /s/{code}).

    One row per visit; rewards dedupe by (viewer, code, day) structurally.
    viewer_user_id is set only when the visitor presents a valid token
    (e.g. in-app browser); otherwise identification is by IP hash.
    """

    __tablename__ = "share_clicks"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    code: Mapped[str] = mapped_column(String(128), index=True)
    sharer_user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    asin: Mapped[str] = mapped_column(String(10), index=True)
    viewer_user_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id"), nullable=True)
    viewer_ip_hash: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)
