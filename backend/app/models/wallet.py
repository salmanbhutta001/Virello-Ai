"""Cash wallet: integer-cents cash ledger + manual-bank-transfer withdrawals.

Money is ALWAYS integer cents — never floats. Cash is earned ONLY from
revenue-linked actions (share via your link, verified share-link clicks,
clicks on products you tagged). Points stay engagement-only.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.schema import UniqueConstraint

from app.core.database import Base
from app.models.core import GUID, _uuid

# Withdrawal statuses
WD_PENDING = "pending"
WD_APPROVED = "approved"
WD_PAID = "paid"
WD_REJECTED = "rejected"


class CashLedger(Base):
    """Append-only cash ledger. delta_cents is an INT (can be negative)."""

    __tablename__ = "cash_ledger"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    delta_cents: Mapped[int] = mapped_column(Integer)
    reason: Mapped[str] = mapped_column(String(32), index=True)
    ref_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)

    __table_args__ = (
        UniqueConstraint("user_id", "reason", "ref_id",
                         name="uq_cash_user_reason_ref"),
    )


class Withdrawal(Base):
    """A cash-out request. Paid MANUALLY by the founder after admin
    approval — no third-party payout service."""

    __tablename__ = "withdrawals"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id"), index=True)
    amount_cents: Mapped[int] = mapped_column(Integer)
    # Payout method registry id, e.g. "bank_transfer", "easypaisa".
    method_id: Mapped[str] = mapped_column(String(32),
                                           default="bank_transfer")
    # Validated details JSON, e.g. {"bank_name": ..., "iban": ...}.
    # Only ever shown to the owner and admins — NEVER on the payout wall.
    method_details: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(16), default=WD_PENDING,
                                        index=True)
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    payment_ref: Mapped[str | None] = mapped_column(String(128), nullable=True)
    # Compliance: the user ticked "I confirm I am 18 years or older" on the
    # withdrawal form. Withdrawals are blocked until this is true.
    age_confirmed: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True)
    # Status timeline: requested (created_at) -> approved_at -> paid_at.
    approved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True)
