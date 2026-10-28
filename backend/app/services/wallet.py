"""Cash wallet: integer-cents earnings, withdrawals, points conversion.

MONEY IS ALWAYS INTEGER CENTS — never floats. Every rate below is
admin-configurable via the ``cash.rules`` system setting; the defaults are
Hafiz's final rate card.

Sustainability note (Hafiz): the cash side is a sales funnel. Rough math —
~5-10% click->sale conversion x ~$1 average affiliate commission ~= $0.05
to $0.10 of sustainable spend per verified click. Daily caps bound the
exposure to roughly $2.50 per user per day before volume bonuses. If the
funnel economics change, retune the rates in cash.rules — no code change.

Story line: "Post karo -> points. Share karo, bikwao -> cash."
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import uuid
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import desc, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.billing import SystemSetting
from app.models.core import User
from app.models.notifications import UserNotification
from app.models.rewards import PointsLedger, ShareClick
from app.models.wallet import (WD_APPROVED, WD_PAID, WD_PENDING, WD_REJECTED,
                               CashLedger, Withdrawal)

SHARE_BASE_URL = os.environ.get(
    "VIRELLO_PUBLIC_BASE_URL", "https://virello-api-production.up.railway.app"
).rstrip("/")

# Final rate card (Hafiz). All values integer cents, caps per day.
# share:              $0.05 x 20/day  = $1.00/day max
# share_click:        $0.03 x 50/day  = $1.50/day max
# product_click:      $0.03 x 50/day
# volume bonus:       100 verified clicks / rolling 7d -> +$2.00
#                     500 verified clicks / rolling 7d -> +$10.00
# weekly top seller:  $10.00 cash | monthly top seller: $50.00 cash
DEFAULT_CASH_RULES: dict = {
    "share_cents": 5,
    "share_daily_cap": 20,
    "share_click_cents": 3,
    "share_click_daily_cap": 50,
    "product_click_cents": 3,
    "product_click_daily_cap": 50,
    "volume_thresholds": [
        {"clicks": 100, "cents": 200},
        {"clicks": 500, "cents": 1000},
    ],
    "weekly_top_seller_cents": 1000,
    "monthly_top_seller_cents": 5000,
    "min_withdraw_cents": 1000,          # $10.00
    "points_to_cash_per_1000_cents": 200,  # 500 pts = $1.00
    "min_convert_points": 1000,
}

RULES_SETTING_KEY = "cash.rules"
SETTLE_WEEK_KEY = "cash.last_settled_seller_week"
SETTLE_MONTH_KEY = "cash.last_settled_seller_month"

KHI = ZoneInfo("Asia/Karachi")

SHARE_REASON = "share"
SHARE_CLICK_REASON = "share_click"
PRODUCT_CLICK_REASON = "product_click"
VOLUME_BONUS_REASON = "volume_bonus"
WEEKLY_SELLER_REASON = "weekly_top_seller"
MONTHLY_SELLER_REASON = "monthly_top_seller"


class WalletError(Exception):
    """Carries a machine-readable code the router maps to HTTP 422."""

    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


# ------------------------------------------------------------ small helpers
def fmt_cents(cents: int) -> str:
    """$X.XX with pure integer math — never floats."""
    sign = "-" if cents < 0 else ""
    c = abs(int(cents))
    return f"{sign}${c // 100}.{c % 100:02d}"


def _today() -> date:
    return datetime.now(KHI).date()


def _utcnow_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


# ------------------------------------------------------------ earning rules
async def get_cash_rules(db: AsyncSession) -> dict:
    row = (await db.execute(
        select(SystemSetting).where(SystemSetting.key == RULES_SETTING_KEY)
    )).scalar_one_or_none()
    rules = dict(DEFAULT_CASH_RULES)
    if row and isinstance(row.value, dict):
        rules.update(row.value)
    return rules


async def update_cash_rules(db: AsyncSession, patch: dict) -> dict:
    rules = await get_cash_rules(db)
    for k, v in (patch or {}).items():
        if k == "volume_thresholds":
            if not isinstance(v, list):
                raise WalletError("invalid_rules")
            clean = []
            for t in v:
                clicks = int(t.get("clicks", 0))
                cents = int(t.get("cents", 0))
                if clicks <= 0 or cents <= 0:
                    raise WalletError("invalid_rules")
                clean.append({"clicks": clicks, "cents": cents})
            rules[k] = sorted(clean, key=lambda t: t["clicks"])
        elif k in rules and k != "volume_thresholds":
            iv = int(v)
            if iv < 0:
                raise WalletError("invalid_rules")
            rules[k] = iv
        # unknown keys are ignored — never stored
    row = (await db.execute(
        select(SystemSetting).where(SystemSetting.key == RULES_SETTING_KEY)
    )).scalar_one_or_none()
    if row is None:
        row = SystemSetting(key=RULES_SETTING_KEY, value=rules)
        db.add(row)
    else:
        row.value = rules
    await db.commit()
    return rules


# ------------------------------------------------------------ cash ledger
async def _count_cash_today(db: AsyncSession, user_id: uuid.UUID,
                            reason: str) -> int:
    return (await db.execute(
        select(func.count()).select_from(CashLedger).where(
            CashLedger.user_id == user_id,
            CashLedger.reason == reason,
            CashLedger.delta_cents > 0,
            func.date(CashLedger.created_at) == _today(),
        ))).scalar() or 0


async def _cash_award_capped(db: AsyncSession, user_id: uuid.UUID,
                            cents: int, reason: str, ref: str,
                            n_today: int, cap: int) -> int:
    if cents <= 0:
        return 0
    if n_today >= cap:
        return 0
    try:
        db.add(CashLedger(user_id=user_id, delta_cents=cents,
                          reason=reason, ref_id=ref))
        await db.commit()
        return cents
    except IntegrityError:
        await db.rollback()
        return 0


async def cash_balance(db: AsyncSession, user_id: uuid.UUID) -> int:
    return (await db.execute(
        select(func.coalesce(func.sum(CashLedger.delta_cents), 0)).where(
            CashLedger.user_id == user_id))).scalar() or 0


async def cash_history(db: AsyncSession, user_id: uuid.UUID,
                       limit: int = 50) -> list[dict]:
    rows = (await db.execute(
        select(CashLedger).where(CashLedger.user_id == user_id)
        .order_by(desc(CashLedger.created_at)).limit(limit))).scalars().all()
    return [{
        "id": str(r.id),
        "delta_cents": r.delta_cents,
        "delta_display": fmt_cents(r.delta_cents),
        "reason": r.reason,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    } for r in rows]


# ------------------------------------------------------------ share codes
def _share_secret() -> bytes:
    from app.core.config import settings
    return settings.jwt_secret.encode()


def make_share_code(user_id: uuid.UUID, asin: str) -> str:
    """Signed, non-guessable share code encoding the sharer + ASIN."""
    payload = json.dumps({"u": str(user_id), "a": asin,
                          "r": secrets.token_hex(8)}).encode()
    b = base64.urlsafe_b64encode(payload).rstrip(b"=").decode()
    sig = hmac.new(_share_secret(), b.encode(),
                   hashlib.sha256).hexdigest()[:32]
    return f"{b}.{sig}"


def verify_share_code(code: str) -> tuple[uuid.UUID, str] | None:
    """Returns (sharer_id, asin) or None when tampered/malformed."""
    try:
        b, sig = code.rsplit(".", 1)
        exp = hmac.new(_share_secret(), b.encode(),
                       hashlib.sha256).hexdigest()[:32]
        if not hmac.compare_digest(exp, sig):
            return None
        pad = "=" * (-len(b) % 4)
        payload = json.loads(base64.urlsafe_b64decode(b + pad))
        return uuid.UUID(payload["u"]), str(payload["a"]).upper()
    except Exception:
        return None


def share_url_for(code: str) -> str:
    return f"{SHARE_BASE_URL}/s/{code}"


# ------------------------------------------------------------ cash earning
# NOTE: the old auto-credit path for share rewards (award_share_cash) was
# REMOVED in the proof-based pivot (Hafiz): share rewards are now filed as
# claims with a screenshot proof and credited only after admin approval
# (see app.services.reward_claims). The share_cents rate below is kept for
# the admin-visible rate card but no longer auto-pays anything.
async def award_share_click_cash(db: AsyncSession, sharer_id: uuid.UUID,
                                 viewer_key: str,
                                 viewer_user_id: uuid.UUID | None,
                                 asin: str, code: str) -> int:
    """Cash per verified share-link visit. No self-click cash.
    Dedupe (viewer, code, day) is structural via ref_id."""
    if viewer_user_id is not None and viewer_user_id == sharer_id:
        return 0
    rules = await get_cash_rules(db)
    ref = f"shareclick:{code}:{viewer_key}:{_today().isoformat()}"
    n_today = await _count_cash_today(db, sharer_id, SHARE_CLICK_REASON)
    earned = await _cash_award_capped(db, sharer_id,
                                     rules["share_click_cents"],
                                     SHARE_CLICK_REASON, ref,
                                     n_today, rules["share_click_daily_cap"])
    if earned:
        try:
            await _check_volume_bonus(db, sharer_id)
        except Exception:
            pass
    # Opportunistic top-seller settlement: two cheap watermark SELECTs per
    # click; completed periods settle at most once each.
    try:
        now_utc = datetime.now(timezone.utc)
        khi_now = now_utc.astimezone(KHI)
        this_monday = khi_now.date() - timedelta(days=khi_now.weekday())
        last_w = _week_label(
            _monday_noon(this_monday - timedelta(days=7)))
        y, m = khi_now.year, khi_now.month - 1
        if m == 0:
            y, m = y - 1, 12
        last_m = f"{y}-{m:02d}"
        if await _get_setting(db, SETTLE_WEEK_KEY) != last_w \
                or await _get_setting(db, SETTLE_MONTH_KEY) != last_m:
            await settle_seller_periods(db, now_utc)
    except Exception:
        pass
    return earned


async def award_product_click_cash(db: AsyncSession, owner_id: uuid.UUID,
                                   clicker_id: uuid.UUID | None,
                                   asin: str) -> int:
    """Cash to the tagger per verified click on their tagged product.
    No self-click cash. Dedupe (clicker, asin, day) is structural."""
    if clicker_id is not None and clicker_id == owner_id:
        return 0
    rules = await get_cash_rules(db)
    clicker = f"user:{clicker_id}" if clicker_id else "user:anon"
    ref = f"productclick:{clicker}:{asin}:{_today().isoformat()}"
    n_today = await _count_cash_today(db, owner_id, PRODUCT_CLICK_REASON)
    return await _cash_award_capped(db, owner_id,
                                   rules["product_click_cents"],
                                   PRODUCT_CLICK_REASON, ref,
                                   n_today, rules["product_click_daily_cap"])


async def _verified_clicks_7d(db: AsyncSession, user_id: uuid.UUID) -> int:
    since = _utcnow_naive() - timedelta(days=7)
    return (await db.execute(
        select(func.count()).select_from(ShareClick).where(
            ShareClick.sharer_user_id == user_id,
            ShareClick.created_at >= since))).scalar() or 0


async def _check_volume_bonus(db: AsyncSession, user_id: uuid.UUID) -> None:
    """Volume bonus: N verified share-clicks in rolling 7 days -> +cash.
    Idempotent per threshold per ISO week via ref_id."""
    rules = await get_cash_rules(db)
    clicks = await _verified_clicks_7d(db, user_id)
    week = _week_label(datetime.now(timezone.utc))
    for t in rules.get("volume_thresholds", []):
        if clicks >= int(t["clicks"]):
            ref = f"volumebonus:{t['clicks']}:{week}"
            await _cash_award_capped(db, user_id, int(t["cents"]),
                                    VOLUME_BONUS_REASON, ref, 0, 1)


async def get_volume_progress(db: AsyncSession, user_id: uuid.UUID) -> dict:
    rules = await get_cash_rules(db)
    clicks = await _verified_clicks_7d(db, user_id)
    week = _week_label(datetime.now(timezone.utc))
    out = []
    for t in rules.get("volume_thresholds", []):
        thr = int(t["clicks"])
        ref = f"volumebonus:{thr}:{week}"
        paid = (await db.execute(select(CashLedger.id).where(
            CashLedger.user_id == user_id,
            CashLedger.reason == VOLUME_BONUS_REASON,
            CashLedger.ref_id == ref))).scalar_one_or_none() is not None
        out.append({"clicks": thr, "cents": int(t["cents"]),
                    "achieved": clicks >= thr, "paid": paid,
                    "progress": f"{min(clicks, thr)}/{thr}"})
    return {"clicks_7d": clicks, "thresholds": out}


async def get_share_stats(db: AsyncSession, user_id: uuid.UUID) -> dict:
    clicks = (await db.execute(
        select(func.count()).select_from(ShareClick).where(
            ShareClick.sharer_user_id == user_id))).scalar() or 0
    earned = (await db.execute(
        select(func.coalesce(func.sum(CashLedger.delta_cents), 0)).where(
            CashLedger.user_id == user_id,
            CashLedger.reason.in_(
                [SHARE_REASON, SHARE_CLICK_REASON,
                 PRODUCT_CLICK_REASON, VOLUME_BONUS_REASON]),
            CashLedger.delta_cents > 0))).scalar() or 0
    shared = (await db.execute(
        select(func.count()).select_from(CashLedger).where(
            CashLedger.user_id == user_id,
            CashLedger.reason == SHARE_REASON,
            CashLedger.delta_cents > 0))).scalar() or 0
    return {
        "products_shared": int(shared),
        "share_clicks": int(clicks),
        "cents_from_shares": int(earned),
        "cash_display": fmt_cents(int(earned)),
    }


# ------------------------------------------------------------ top sellers
def _week_label(now: datetime) -> str:
    khi = now.astimezone(KHI)
    iso_year, iso_week, _ = khi.isocalendar()
    return f"{iso_year}-W{iso_week:02d}"


def _month_label(now: datetime) -> str:
    khi = now.astimezone(KHI)
    return f"{khi.year}-{khi.month:02d}"


def _week_window(now: datetime) -> tuple[datetime, datetime]:
    khi = now.astimezone(KHI)
    start_khi = (khi - timedelta(days=khi.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0)
    end_khi = start_khi + timedelta(days=7)
    return (start_khi.astimezone(timezone.utc).replace(tzinfo=None),
            end_khi.astimezone(timezone.utc).replace(tzinfo=None))


def _month_window(now: datetime) -> tuple[datetime, datetime]:
    khi = now.astimezone(KHI)
    start_khi = khi.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if start_khi.month == 12:
        end_khi = start_khi.replace(year=start_khi.year + 1, month=1)
    else:
        end_khi = start_khi.replace(month=start_khi.month + 1)
    return (start_khi.astimezone(timezone.utc).replace(tzinfo=None),
            end_khi.astimezone(timezone.utc).replace(tzinfo=None))


async def _click_counts(db: AsyncSession, start: datetime, end: datetime,
                        limit: int = 20) -> list[tuple[uuid.UUID, int]]:
    rows = (await db.execute(
        select(ShareClick.sharer_user_id, func.count().label("c"))
        .where(ShareClick.created_at >= start, ShareClick.created_at < end)
        .group_by(ShareClick.sharer_user_id)
        .order_by(desc("c"), ShareClick.sharer_user_id)
        .limit(limit))).all()
    return [(r[0], int(r[1])) for r in rows]


async def get_seller_leaderboard(db: AsyncSession,
                                 period: str = "week") -> dict:
    """Top Sellers: ranked by VERIFIED share-link clicks (not points).
    Separate from the posters leaderboard."""
    now = datetime.now(timezone.utc)
    rules = await get_cash_rules(db)
    try:
        await settle_seller_periods(db, now)
    except Exception:
        pass
    if period == "month":
        start, end = _month_window(now)
        label = _month_label(now)
        prize_cents = rules["monthly_top_seller_cents"]
    else:
        period = "week"
        start, end = _week_window(now)
        label = _week_label(now)
        prize_cents = rules["weekly_top_seller_cents"]
    counts = await _click_counts(db, start, end)
    board = []
    for sharer_id, clicks in counts:
        name = (await db.execute(
            select(User.name).where(User.id == sharer_id)
        )).scalar_one_or_none()
        board.append({"user_id": str(sharer_id),
                      "name": name or "Virello seller",
                      "verified_clicks": clicks})
    return {
        "leaderboard": board,
        "period": {
            "scope": period,
            "label": label,
            "starts_at": start.isoformat(),
            "ends_at": end.isoformat(),
            "prize_cents": prize_cents,
            "prize_display": fmt_cents(prize_cents),
            "timezone": "Asia/Karachi",
        },
    }


async def _get_setting(db: AsyncSession, key: str):
    row = (await db.execute(
        select(SystemSetting).where(SystemSetting.key == key)
    )).scalar_one_or_none()
    # SystemSetting.value is a JSON column — return the stored value as-is
    # (str labels for settle keys, lists for method flags).
    return row.value if row is not None else None


async def _set_setting(db: AsyncSession, key: str, value) -> None:
    row = (await db.execute(
        select(SystemSetting).where(SystemSetting.key == key)
    )).scalar_one_or_none()
    if row is None:
        db.add(SystemSetting(key=key, value=value))
    else:
        row.value = value
    await db.commit()


async def settle_seller_periods(db: AsyncSession,
                                now: datetime | None = None) -> dict:
    """Pay WEEKLY/MONTHLY TOP SELLER cash prizes for COMPLETED periods.
    Watermarked in system_settings so each period pays exactly once; the
    ledger unique constraint makes even concurrent runs safe.
    Only pays when the period has at least one verified click."""
    now = now or datetime.now(timezone.utc)
    khi_now = now.astimezone(KHI)
    rules = await get_cash_rules(db)
    paid: dict = {"weekly": [], "monthly": []}

    # ---- weekly: completed weeks newer than the watermark, oldest first
    last_w = await _get_setting(db, SETTLE_WEEK_KEY)
    this_monday = khi_now.date() - timedelta(days=khi_now.weekday())
    weeks: list[date] = []
    ws = this_monday - timedelta(days=7)
    while (last_w is None or _week_label(_monday_noon(ws)) > last_w) \
            and len(weeks) < 8:
        weeks.append(ws)
        ws -= timedelta(days=7)
    for ws in reversed(weeks):
        start, end = _week_window(_monday_noon(ws))
        top = await _click_counts(db, start, end, limit=1)
        label = _week_label(_monday_noon(ws))
        if top and top[0][1] > 0:
            sharer_id, clicks = top[0]
            ref = f"topseller:weekly:{label}"
            got = await _cash_award_capped(
                db, sharer_id, rules["weekly_top_seller_cents"],
                WEEKLY_SELLER_REASON, ref, 0, 1)
            paid["weekly"].append({"user_id": str(sharer_id),
                                   "clicks": clicks, "cents": got,
                                   "period": label})
        await _set_setting(db, SETTLE_WEEK_KEY, label)

    # ---- monthly: completed months newer than the watermark
    last_m = await _get_setting(db, SETTLE_MONTH_KEY)
    months: list[tuple[int, int]] = []
    y, m = khi_now.year, khi_now.month - 1
    if m == 0:
        y, m = y - 1, 12
    while (last_m is None or f"{y}-{m:02d}" > last_m) and len(months) < 6:
        months.append((y, m))
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    for y, m in reversed(months):
        label = f"{y}-{m:02d}"
        start = datetime(y, m, 1, tzinfo=KHI).astimezone(
            timezone.utc).replace(tzinfo=None)
        if m == 12:
            end = datetime(y + 1, 1, 1, tzinfo=KHI).astimezone(
                timezone.utc).replace(tzinfo=None)
        else:
            end = datetime(y, m + 1, 1, tzinfo=KHI).astimezone(
                timezone.utc).replace(tzinfo=None)
        top = await _click_counts(db, start, end, limit=1)
        if top and top[0][1] > 0:
            sharer_id, clicks = top[0]
            ref = f"topseller:monthly:{label}"
            got = await _cash_award_capped(
                db, sharer_id, rules["monthly_top_seller_cents"],
                MONTHLY_SELLER_REASON, ref, 0, 1)
            paid["monthly"].append({"user_id": str(sharer_id),
                                    "clicks": clicks, "cents": got,
                                    "period": label})
        await _set_setting(db, SETTLE_MONTH_KEY, label)
    return paid


def _monday_noon(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, 12, 0, tzinfo=KHI)


async def get_seller_winners(db: AsyncSession, limit: int = 12) -> list[dict]:
    rows = (await db.execute(
        select(CashLedger).where(CashLedger.reason.in_(
            [WEEKLY_SELLER_REASON, MONTHLY_SELLER_REASON]),
            CashLedger.delta_cents > 0)
        .order_by(desc(CashLedger.created_at)).limit(limit))).scalars().all()
    out = []
    for r in rows:
        name = (await db.execute(
            select(User.name).where(User.id == r.user_id)
        )).scalar_one_or_none()
        out.append({
            "user_id": str(r.user_id),
            "name": name or "Virello seller",
            "cents": r.delta_cents,
            "display": fmt_cents(r.delta_cents),
            "scope": "weekly" if r.reason == WEEKLY_SELLER_REASON
            else "monthly",
            "period": (r.ref_id or "").split(":")[-1],
            "paid_at": r.created_at.isoformat() if r.created_at else None,
        })
    return out


# ------------------------------------------------------------ withdrawals
def profile_is_completed(user: User) -> bool:
    """A profile counts as completed when the user set a real display name
    (not the 'Virello user' placeholder from OTP upsert)."""
    name = (user.name or "").strip()
    return bool(name) and name.lower() != "virello user"


async def withdrawal_eligibility(db: AsyncSession,
                                 user: User) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    if not bool(getattr(user, "email_verified", False)):
        reasons.append("email_not_verified")
    created = user.created_at
    if created is not None:
        c = created.replace(tzinfo=None) if created.tzinfo else created
        age_days = (_utcnow_naive() - c).days
        if age_days < 7:
            reasons.append("account_too_new")
    if not profile_is_completed(user):
        reasons.append("profile_incomplete")
    return (not reasons), reasons


# ------------------------------------------------------------ payout methods
# Withdrawal method registry. Icons on mobile are simple custom glyphs
# (no trademark logos). Each method declares its required fields; the
# server validates them on every withdrawal request.
METHOD_REGISTRY: dict[str, dict] = {
    "bank_transfer": {
        "label": "Bank Transfer",
        "icon": "bank",
        "fields": [
            {"name": "bank_name", "label": "Bank name", "required": True,
             "kind": "text"},
            {"name": "account_title", "label": "Account title",
             "required": True, "kind": "text"},
            {"name": "iban", "label": "IBAN / Account number",
             "required": True, "kind": "text"},
        ],
    },
    "easypaisa": {
        "label": "Easypaisa",
        "icon": "mobile",
        "fields": [
            {"name": "mobile_number", "label": "Mobile number",
             "required": True, "kind": "phone"},
            {"name": "account_title", "label": "Account title",
             "required": True, "kind": "text"},
        ],
    },
    "jazzcash": {
        "label": "JazzCash",
        "icon": "mobile",
        "fields": [
            {"name": "mobile_number", "label": "Mobile number",
             "required": True, "kind": "phone"},
            {"name": "account_title", "label": "Account title",
             "required": True, "kind": "text"},
        ],
    },
    "paypal": {
        "label": "PayPal",
        "icon": "globe",
        "fields": [
            {"name": "email", "label": "PayPal email", "required": True,
             "kind": "email"},
        ],
    },
    "payoneer": {
        "label": "Payoneer",
        "icon": "globe",
        "fields": [
            {"name": "email", "label": "Payoneer email", "required": True,
             "kind": "email"},
        ],
    },
    "crypto_usdt": {
        "label": "Crypto (USDT)",
        "icon": "coin",
        "fields": [
            {"name": "wallet_address", "label": "USDT wallet address",
             "required": True, "kind": "text"},
            {"name": "network", "label": "Network", "required": True,
             "kind": "select",
             "options": ["TRC20", "ERC20", "BEP20"]},
        ],
    },
}
# Methods enabled by default. Admin toggles the rest via the earnings API.
METHODS_DEFAULT_ENABLED = ["bank_transfer", "easypaisa", "jazzcash"]
METHODS_SETTINGS_KEY = "cash.methods_enabled"


async def get_method_configs(db: AsyncSession) -> dict:
    """Registry + admin enabled flags. Only enabled methods are
    withdrawable; the mobile picker renders fields from this."""
    enabled = await _get_setting(db, METHODS_SETTINGS_KEY)
    if not isinstance(enabled, list):
        enabled = list(METHODS_DEFAULT_ENABLED)
        await _set_setting(db, METHODS_SETTINGS_KEY, enabled)
    enabled_set = set(enabled)
    methods = []
    for method_id, spec in METHOD_REGISTRY.items():
        methods.append({
            "id": method_id,
            "label": spec["label"],
            "icon": spec["icon"],
            "enabled": method_id in enabled_set,
            "fields": spec["fields"],
        })
    return {"methods": methods}


async def set_method_enabled(db: AsyncSession, method_id: str,
                             enabled: bool) -> dict:
    if method_id not in METHOD_REGISTRY:
        raise WalletError("unknown_method")
    configs = await get_method_configs(db)
    current = [m["id"] for m in configs["methods"] if m["enabled"]]
    if enabled and method_id not in current:
        current.append(method_id)
    elif not enabled and method_id in current:
        current.remove(method_id)
    await _set_setting(db, METHODS_SETTINGS_KEY, current)
    return await get_method_configs(db)


def validate_withdrawal_method(method_id: str,
                               details: dict | None,
                               enabled: list[str]) -> dict:
    """Server-side per-method field validation. Returns the cleaned
    details dict. Raises WalletError on any problem."""
    spec = METHOD_REGISTRY.get(method_id or "")
    if spec is None:
        raise WalletError("unknown_method")
    if method_id not in set(enabled):
        raise WalletError("method_disabled")
    details = details or {}
    clean: dict[str, str] = {}
    missing: list[str] = []
    for field in spec["fields"]:
        raw = str(details.get(field["name"]) or "").strip()
        if field["required"] and not raw:
            missing.append(field["name"])
            continue
        if field["kind"] == "email" and raw and "@" not in raw:
            raise WalletError("invalid_method:bad_email")
        if field["kind"] == "select" and raw \
                and raw not in field.get("options", []):
            raise WalletError("invalid_method:bad_option")
        clean[field["name"]] = raw
    if missing:
        raise WalletError("invalid_method:missing:" + ",".join(missing))
    return clean


async def request_withdrawal(db: AsyncSession, user: User,
                             amount_cents: int, method_id: str,
                             method_details: dict | None,
                             age_confirmed: bool = False) -> Withdrawal:
    rules = await get_cash_rules(db)
    if not age_confirmed:
        # Compliance: 18+ confirmation is mandatory for cash withdrawals.
        raise WalletError("age_not_confirmed")
    if not isinstance(amount_cents, int) or \
            amount_cents < rules["min_withdraw_cents"]:
        raise WalletError("below_minimum")
    configs = await get_method_configs(db)
    enabled = [m["id"] for m in configs["methods"] if m["enabled"]]
    clean_details = validate_withdrawal_method(
        method_id, method_details, enabled)
    ok, reasons = await withdrawal_eligibility(db, user)
    if not ok:
        raise WalletError("ineligible:" + ",".join(reasons))
    pending = (await db.execute(select(Withdrawal.id).where(
        Withdrawal.user_id == user.id,
        Withdrawal.status == WD_PENDING).limit(1))).scalar_one_or_none()
    if pending is not None:
        raise WalletError("pending_exists")
    bal = await cash_balance(db, user.id)
    if bal < amount_cents:
        raise WalletError("insufficient_balance")
    w = Withdrawal(user_id=user.id, amount_cents=amount_cents,
                   method_id=method_id, method_details=clean_details,
                   status=WD_PENDING, age_confirmed=True)
    db.add(w)
    await db.flush()
    # Debit at request time (hold): the balance can never be double-spent.
    # A rejection credits it back; approval just flips the status.
    db.add(CashLedger(user_id=user.id, delta_cents=-amount_cents,
                      reason="withdrawal", ref_id=f"withdrawal:{w.id}"))
    await db.commit()
    await db.refresh(w)
    return w


async def _get_withdrawal(db: AsyncSession,
                          withdrawal_id: uuid.UUID) -> Withdrawal | None:
    return (await db.execute(
        select(Withdrawal).where(Withdrawal.id == withdrawal_id)
    )).scalar_one_or_none()


async def approve_withdrawal(db: AsyncSession,
                             withdrawal_id: uuid.UUID,
                             admin_note: str | None = None) -> Withdrawal:
    w = await _get_withdrawal(db, withdrawal_id)
    if w is None:
        raise WalletError("not_found")
    if w.status != WD_PENDING:
        raise WalletError("invalid_transition")
    w.status = WD_APPROVED
    w.admin_note = (admin_note or "").strip() or None
    w.approved_at = _utcnow_naive()
    await db.commit()
    await db.refresh(w)
    await notify_user(
        db, w.user_id, "withdrawal_approved",
        "Withdrawal approved",
        f"Your {fmt_cents(w.amount_cents)} withdrawal was approved — "
        "the transfer is in progress.",
        {"withdrawal_id": str(w.id), "amount_cents": w.amount_cents})
    return w


async def reject_withdrawal(db: AsyncSession, withdrawal_id: uuid.UUID,
                            note: str | None) -> Withdrawal:
    w = await _get_withdrawal(db, withdrawal_id)
    if w is None:
        raise WalletError("not_found")
    if w.status != WD_PENDING:
        raise WalletError("invalid_transition")
    w.status = WD_REJECTED
    w.admin_note = (note or "").strip() or None
    # Refund the held amount.
    db.add(CashLedger(user_id=w.user_id, delta_cents=w.amount_cents,
                      reason="withdrawal_refund",
                      ref_id=f"withdrawal:{w.id}:refund"))
    await db.commit()
    await db.refresh(w)
    await notify_user(
        db, w.user_id, "withdrawal_rejected",
        "Withdrawal not approved",
        f"Your {fmt_cents(w.amount_cents)} withdrawal was not approved"
        + (f": {w.admin_note}" if w.admin_note else ".")
        + " The amount was returned to your cash balance.",
        {"withdrawal_id": str(w.id), "amount_cents": w.amount_cents})
    return w


async def mark_withdrawal_paid(db: AsyncSession, withdrawal_id: uuid.UUID,
                               payment_ref: str | None) -> Withdrawal:
    w = await _get_withdrawal(db, withdrawal_id)
    if w is None:
        raise WalletError("not_found")
    if w.status != WD_APPROVED:
        raise WalletError("invalid_transition")
    w.status = WD_PAID
    w.payment_ref = (payment_ref or "").strip() or None
    w.paid_at = _utcnow_naive()
    await db.commit()
    await db.refresh(w)
    # The payout wall reads paid rows directly — no seeding, no fakes.
    await notify_user(
        db, w.user_id, "withdrawal_paid",
        "Withdrawal paid",
        f"Your {fmt_cents(w.amount_cents)} withdrawal has been paid.",
        {"withdrawal_id": str(w.id), "amount_cents": w.amount_cents})
    return w


async def list_withdrawals(db: AsyncSession, user_id: uuid.UUID,
                           limit: int = 50) -> list[dict]:
    rows = (await db.execute(
        select(Withdrawal).where(Withdrawal.user_id == user_id)
        .order_by(desc(Withdrawal.created_at)).limit(limit))).scalars().all()
    return [_withdrawal_to_dict(w) for w in rows]


async def admin_list_withdrawals(db: AsyncSession,
                                 status: str | None = None,
                                 limit: int = 100) -> list[dict]:
    q = select(Withdrawal)
    if status:
        q = q.where(Withdrawal.status == status)
    # pending first, then newest
    q = q.order_by((Withdrawal.status != WD_PENDING),
                   desc(Withdrawal.created_at)).limit(limit)
    rows = (await db.execute(q)).scalars().all()
    out = []
    for w in rows:
        d = _withdrawal_to_dict(w)
        email = (await db.execute(
            select(User.email).where(User.id == w.user_id)
        )).scalar_one_or_none()
        d["user_email"] = email
        out.append(d)
    return out


def _withdrawal_to_dict(w: Withdrawal) -> dict:
    return {
        "id": str(w.id),
        "user_id": str(w.user_id),
        "amount_cents": w.amount_cents,
        "amount_display": fmt_cents(w.amount_cents),
        "method_id": w.method_id,
        # Full details go only to the owner and admins — never the wall.
        "method_details": dict(w.method_details or {}),
        "status": w.status,
        "admin_note": w.admin_note,
        "payment_ref": w.payment_ref,
        "age_confirmed": bool(w.age_confirmed),
        # Status timeline: requested (created_at) -> approved -> paid.
        "created_at": w.created_at.isoformat() if w.created_at else None,
        "approved_at": w.approved_at.isoformat() if w.approved_at else None,
        "paid_at": w.paid_at.isoformat() if w.paid_at else None,
    }


# ------------------------------------------------------------ notifications
async def notify_user(db: AsyncSession, user_id: uuid.UUID, kind: str,
                      title: str, body: str,
                      data: dict | None = None) -> None:
    """Persist a personal in-app notification (withdrawal events, …)."""
    db.add(UserNotification(user_id=user_id, kind=kind, title=title,
                            body=body, data=data or {}))
    await db.commit()


async def list_notifications(db: AsyncSession, user_id: uuid.UUID,
                             limit: int = 50) -> list[dict]:
    rows = (await db.execute(
        select(UserNotification).where(
            UserNotification.user_id == user_id)
        .order_by(desc(UserNotification.created_at)).limit(limit)
    )).scalars().all()
    return [{
        "id": str(n.id), "kind": n.kind, "title": n.title, "body": n.body,
        "data": dict(n.data or {}), "read": bool(n.read),
        "created_at": n.created_at.isoformat() if n.created_at else None,
    } for n in rows]


async def mark_notification_read(db: AsyncSession, user_id: uuid.UUID,
                                 notification_id: uuid.UUID) -> bool:
    n = (await db.execute(select(UserNotification).where(
        UserNotification.id == notification_id,
        UserNotification.user_id == user_id))).scalar_one_or_none()
    if n is None:
        return False
    n.read = True
    await db.commit()
    return True


# ------------------------------------------------------------ payout wall
# HONESTY RULE: this wall lists ONLY withdrawals an admin genuinely marked
# paid. Never seed it with fake/demo entries — fake payout proofs are
# fraud. Zero payouts -> the mobile app shows "Be the first to cash out!".
def mask_name(name: str | None) -> str:
    """'Ahmed Khan' -> 'Ahmed K.'. Never leaks full names, and the wall
    never sees account numbers, emails, or wallet addresses."""
    name = (name or "").strip()
    if not name or name.lower() in ("virello user", "user"):
        return "A Virello member"
    parts = name.split()
    if len(parts) >= 2 and parts[1]:
        return f"{parts[0]} {parts[1][0].upper()}."
    return parts[0]


async def get_payout_wall(db: AsyncSession, limit: int = 20,
                          offset: int = 0) -> dict:
    limit = max(1, min(limit, 50))
    offset = max(0, offset)
    rows = (await db.execute(
        select(Withdrawal, User.name)
        .join(User, User.id == Withdrawal.user_id)
        .where(Withdrawal.status == WD_PAID)
        .order_by(desc(Withdrawal.paid_at)).limit(limit).offset(offset)
    )).all()
    total = (await db.execute(
        select(func.count()).select_from(Withdrawal)
        .where(Withdrawal.status == WD_PAID))).scalar() or 0
    payouts = [{
        "masked_name": mask_name(name),
        "amount_cents": w.amount_cents,
        "amount_display": fmt_cents(w.amount_cents),
        "method_id": w.method_id,
        "paid_at": w.paid_at.isoformat() if w.paid_at else None,
    } for w, name in rows]
    return {"payouts": payouts, "total": total,
            "limit": limit, "offset": offset}


# ------------------------------------------------------------ points -> cash
async def convert_points_to_cash(db: AsyncSession, user_id: uuid.UUID,
                                 points: int) -> dict:
    """Convert points into withdrawable cash. Single DB transaction: the
    points debit and the cash credit commit together — both or neither."""
    from app.services import rewards as rewards_svc  # local: no import cycle
    rules = await get_cash_rules(db)
    if not isinstance(points, int) or points < rules["min_convert_points"]:
        raise WalletError("below_minimum")
    bal = await rewards_svc.get_balance(db, user_id)
    if bal["balance"] < points:
        raise WalletError("insufficient_points")
    cents = points * rules["points_to_cash_per_1000_cents"] // 1000
    if cents <= 0:
        raise WalletError("zero_value")
    conv_id = uuid.uuid4().hex
    db.add(PointsLedger(user_id=user_id, delta=-points,
                        reason="points_to_cash",
                        ref_id=f"pts2cash:{conv_id}"))
    db.add(CashLedger(user_id=user_id, delta_cents=cents,
                      reason="points_conversion",
                      ref_id=f"pts2cash:{conv_id}"))
    await db.commit()
    return {"points_debited": points, "cash_credited_cents": cents,
            "cash_display": fmt_cents(cents)}
