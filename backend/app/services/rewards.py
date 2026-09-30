"""Virello Points rewards engine.

Earning rules (all abuse-proof by construction):
- post_created:      +10 per feed post, max 5 rewarded posts/day,
                     idempotent per campaign (re-share never pays twice).
- streak:            consecutive days with >=1 post: day2 +5, day3 +10,
                     day4 +15, day5+ +25 (capped).
- like_received:     +1 per genuine like on the user's post, max 50/post/day,
                     no points for liking your own post.
- comment_received:  +2 per genuine comment, max 20/post/day, no self-comments.
- profile_completed: +20 once.
- daily_login:       +2 once/day.
- referral:          +50 to the referrer when the referred user verifies.
- redeem:            points -> Grow credits at the admin-set rate
                     (default 100 pts = 10 credits), minimum 100 pts.

Idempotency: (user_id, reason, ref_id) is unique — the same event never
pays twice, even under retries or double taps. Cap-suppressed awards are
recorded as delta=0 rows with reason="cap_skipped" (audit trail only;
excluded from user-facing history).
"""
from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import desc, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.billing import SystemSetting
from app.models.core import Campaign, User
from app.models.rewards import PointsLedger, ShareClick
from app.services.payments.ledger import grant_credits

log = logging.getLogger(__name__)

# ------------------------------------------------------------------ rules
LEVELS: list[tuple[str, int]] = [
    ("Sprout", 0),
    ("Rising", 100),
    ("Creator", 500),
    ("Star", 1500),
    ("Icon", 5000),
]

POST_POINTS = 10
POST_DAILY_CAP = 5
POST_WITH_PRODUCTS_POINTS = 25  # shoppable post: tagged with >=1 product
POST_REASONS = ("post_created", "post_with_products")
STREAK_BONUS = {2: 5, 3: 10, 4: 15}
STREAK_BONUS_CAP = 25  # day 5 and beyond
LIKE_POINTS = 1
LIKE_DAILY_CAP_PER_POST = 50
COMMENT_POINTS = 2
COMMENT_DAILY_CAP_PER_POST = 20
PRODUCT_CLICK_POINTS = 3  # cash cents now — see wallet.award_product_click_cash
PRODUCT_CLICK_DAILY_CAP = 50  # per recipient per day (cash; kept for reference)
PROFILE_POINTS = 20
LOGIN_POINTS = 2
REFERRAL_POINTS = 50
REDEEM_MIN_POINTS = 100
DEFAULT_REDEEM_RATE = 100  # points per 10 Grow credits
REDEEM_RATE_SETTING = "rewards.redeem_rate"

# Volume bonus (points-only): verified share-link clicks in rolling 7 days.
# Replaces the old cash volume bonus ($2.00/$10.00) — no cash, no withdrawal.
VOLUME_BONUS_POINTS_TIERS = [
    {"clicks": 100, "points": 1000},
    {"clicks": 500, "points": 5000},
]
VOLUME_BONUS_REASON = "volume_bonus"

# Top seller prizes (points-only, replaces $10/$50 cash).
# 500 pts = $1.00 rate: $10 -> 5000 pts, $50 -> 25000 pts.
WEEKLY_TOP_SELLER_POINTS = 5000
MONTHLY_TOP_SELLER_POINTS = 25000

# Stable rule ids for the mobile "How to earn" list (mobile localizes text).
RULES = [
    {"id": "post_created", "points": POST_POINTS,
     "per": "post", "daily_cap": POST_DAILY_CAP,
     "description": "Share a post to the community feed"},
    {"id": "streak", "points": STREAK_BONUS_CAP,
     "per": "day", "daily_cap": None,
     "description": "Post on consecutive days (up to +25/day from day 5)"},
    {"id": "like_received", "points": LIKE_POINTS,
     "per": "like", "daily_cap": LIKE_DAILY_CAP_PER_POST,
     "description": "Get likes on your posts (max 50/post/day)"},
    {"id": "comment_received", "points": COMMENT_POINTS,
     "per": "comment", "daily_cap": COMMENT_DAILY_CAP_PER_POST,
     "description": "Get comments on your posts (max 20/post/day)"},
    {"id": "profile_completed", "points": PROFILE_POINTS,
     "per": "once", "daily_cap": None,
     "description": "Complete your profile"},
    {"id": "daily_login", "points": LOGIN_POINTS,
     "per": "day", "daily_cap": None,
     "description": "Open the app daily"},
    {"id": "referral", "points": REFERRAL_POINTS,
     "per": "referral", "daily_cap": None,
     "description": "Invite a friend who verifies their account"},
    {"id": "redeem", "points": None,
     "per": "100 points = 10 credits", "daily_cap": None,
     "description": "Redeem points for Grow credits (min 100 points)"},
    {"id": "weekly_contest", "points": 500,
     "per": "week", "daily_cap": None,
     "description": "Top 3 of the weekly leaderboard win bonus points (500/300/150)"},
    {"id": "monthly_contest", "points": 2000,
     "per": "month", "daily_cap": None,
     "description": "Top 3 of the monthly leaderboard win bonus points (2000/1000/500)"},
]


def _today() -> date:
    return datetime.now(timezone.utc).date()


def _day_start() -> datetime:
    return datetime.combine(_today(), datetime.min.time(),
                            tzinfo=timezone.utc)


async def _insert(db: AsyncSession, user_id: uuid.UUID, delta: int,
                 reason: str, ref_id: str | None) -> bool:
    """Insert one ledger row. False when the (user, reason, ref) already
    exists — the event already paid. Never raises for duplicates."""
    try:
        db.add(PointsLedger(user_id=user_id, delta=delta,
                            reason=reason, ref_id=ref_id))
        await db.commit()
        return True
    except IntegrityError:
        await db.rollback()
        return False


async def award(db: AsyncSession, user_id: uuid.UUID, delta: int,
               reason: str, ref_id: str | None = None) -> int:
    """Unconditional award with idempotency. Returns points granted."""
    ok = await _insert(db, user_id, delta, reason, ref_id)
    # Lightweight settlement check: a pure date compare, DB work at most
    # once per day per worker. Idempotent, so races are harmless.
    await _maybe_settle(db)
    return delta if ok else 0


async def _count_today(db: AsyncSession, user_id: uuid.UUID,
                      reason: str | tuple[str, ...],
                      ref_prefix: str | None = None) -> int:
    reason_crit = (PointsLedger.reason.in_(reason)
                   if isinstance(reason, tuple)
                   else PointsLedger.reason == reason)
    stmt = (select(func.count()).select_from(PointsLedger)
            .where(PointsLedger.user_id == user_id,
                   reason_crit,
                   PointsLedger.delta > 0,
                   PointsLedger.created_at >= _day_start()))
    if ref_prefix:
        stmt = stmt.where(PointsLedger.ref_id.like(f"{ref_prefix}%"))
    return (await db.execute(stmt)).scalar() or 0


async def _award_capped(db: AsyncSession, user_id: uuid.UUID, delta: int,
                       reason: str, ref_id: str,
                       cap_count: int, cap_limit: int) -> int:
    """Award honoring a per-day cap. Silently skips (audit-logged) at cap."""
    if cap_count >= cap_limit:
        # Audit trail only — no user error, no retry storm.
        await _insert(db, user_id, 0, "cap_skipped", ref_id)
        log.info("points cap hit: user=%s reason=%s ref=%s",
                 user_id, reason, ref_id)
        return 0
    return await award(db, user_id, delta, reason, ref_id)


# ------------------------------------------------------------ earning hooks
async def award_post_created(db: AsyncSession, user_id: uuid.UUID,
                            campaign_id: uuid.UUID) -> int:
    """+10 for sharing a post to the feed. Max 5 rewarded posts/day
    (shared with shoppable posts)."""
    ref = str(campaign_id)
    n_today = await _count_today(db, user_id, POST_REASONS)
    granted = await _award_capped(db, user_id, POST_POINTS, "post_created",
                                 ref, n_today, POST_DAILY_CAP)
    if granted:
        granted += await award_streak(db, user_id)
    return granted


async def award_post_with_products(db: AsyncSession, user_id: uuid.UUID,
                                  campaign_id: uuid.UUID) -> int:
    """+25 for a feed post tagged with >=1 real catalog product.
    Shares the 5/day post cap with plain posts."""
    ref = str(campaign_id)
    n_today = await _count_today(db, user_id, POST_REASONS)
    granted = await _award_capped(db, user_id, POST_WITH_PRODUCTS_POINTS,
                                 "post_with_products", ref,
                                 n_today, POST_DAILY_CAP)
    if granted:
        granted += await award_streak(db, user_id)
    return granted


async def award_streak(db: AsyncSession, user_id: uuid.UUID) -> int:
    """Consecutive-day posting bonus. Idempotent per day."""
    rows = (await db.execute(
        select(func.date(PointsLedger.created_at).label("d"))
        .where(PointsLedger.user_id == user_id,
               PointsLedger.reason.in_(POST_REASONS),
               PointsLedger.delta > 0)
        .distinct())).scalars().all()
    # func.date() returns a date on Postgres but a "YYYY-MM-DD" string on
    # SQLite — normalize to date either way.
    days = set()
    for r in rows:
        if isinstance(r, datetime):
            days.add(r.date())
        elif isinstance(r, date):
            days.add(r)
        elif isinstance(r, str):
            try:
                days.add(date.fromisoformat(r[:10]))
            except ValueError:
                continue
    streak, d = 0, _today()
    while d in days:
        streak += 1
        d -= timedelta(days=1)
    if streak < 2:
        return 0
    bonus = STREAK_BONUS.get(streak, STREAK_BONUS_CAP)
    return await award(db, user_id, bonus, "streak", _today().isoformat())


async def award_like_received(db: AsyncSession, campaign_id: uuid.UUID,
                             liker_id: uuid.UUID,
                             interaction_id: uuid.UUID) -> int:
    """+1 to the post owner per genuine like. No self-like points."""
    campaign = (await db.execute(select(Campaign).where(
        Campaign.id == campaign_id))).scalar_one_or_none()
    if campaign is None:
        return 0
    owner = campaign.user_id
    if owner == liker_id:
        return 0
    ref = f"like:{campaign_id}:{interaction_id}"
    n_today = await _count_today(db, owner, "like_received",
                                f"like:{campaign_id}:")
    return await _award_capped(db, owner, LIKE_POINTS, "like_received",
                               ref, n_today, LIKE_DAILY_CAP_PER_POST)


async def award_comment_received(db: AsyncSession, post_url: str,
                                commenter_id: uuid.UUID,
                                comment_id: str) -> int:
    """+2 to the post owner per genuine comment. No self-comment points."""
    campaign = (await db.execute(select(Campaign).where(
        Campaign.post_url == post_url))).scalar_one_or_none()
    if campaign is None:
        return 0  # external post we cannot attribute — no points invented
    owner = campaign.user_id
    if owner == commenter_id:
        return 0
    ref = f"comment:{campaign.id}:{comment_id}"
    n_today = await _count_today(db, owner, "comment_received",
                                f"comment:{campaign.id}:")
    return await _award_capped(db, owner, COMMENT_POINTS, "comment_received",
                               ref, n_today, COMMENT_DAILY_CAP_PER_POST)


async def award_daily_login(db: AsyncSession, user_id: uuid.UUID) -> int:
    return await award(db, user_id, LOGIN_POINTS, "daily_login",
                      _today().isoformat())


async def award_profile_completed(db: AsyncSession, user_id: uuid.UUID,
                                 name: str | None,
                                 preferred_language: str | None) -> int:
    """+20 once, when the profile has a real name and a language set.
    The 'Virello user' placeholder from OTP upsert does not count."""
    real_name = bool(name and name.strip()
                     and name.strip().lower() != "virello user")
    if not (real_name and preferred_language):
        return 0
    return await award(db, user_id, PROFILE_POINTS, "profile_completed",
                      "once")


async def award_referral(db: AsyncSession, referrer_id: uuid.UUID,
                        event_id: uuid.UUID) -> int:
    return await award(db, referrer_id, REFERRAL_POINTS, "referral",
                      str(event_id))


# ------------------------------------------------------------------ levels
def level_for(lifetime: int) -> tuple[str, str | None, float]:
    """(current level, next level or None, progress 0..1 toward next)."""
    current, nxt = LEVELS[0][0], None
    for i, (name, minimum) in enumerate(LEVELS):
        if lifetime >= minimum:
            current = name
            nxt = LEVELS[i + 1][0] if i + 1 < len(LEVELS) else None
        else:
            break
    if nxt is None:
        return current, None, 1.0
    cur_min = next(m for n, m in LEVELS if n == current)
    nxt_min = next(m for n, m in LEVELS if n == nxt)
    progress = (lifetime - cur_min) / max(1, nxt_min - cur_min)
    return current, nxt, round(min(1.0, max(0.0, progress)), 3)


async def get_balance(db: AsyncSession, user_id: uuid.UUID) -> dict:
    balance = (await db.execute(
        select(func.coalesce(func.sum(PointsLedger.delta), 0))
        .where(PointsLedger.user_id == user_id))).scalar() or 0
    lifetime = (await db.execute(
        select(func.coalesce(func.sum(PointsLedger.delta), 0))
        .where(PointsLedger.user_id == user_id,
               PointsLedger.delta > 0))).scalar() or 0
    level, next_level, progress = level_for(int(lifetime))
    return {
        "balance": int(balance),
        "lifetime": int(lifetime),
        "level": level,
        "next_level": next_level,
        "progress": progress,
    }


# ------------------------------------------------------------------ redeem
async def redeem_rate(db: AsyncSession) -> int:
    """Points per 10 Grow credits. Admin-overridable via system settings
    (stored as JSON: {"rate": 100}, a bare number also works)."""
    row = (await db.execute(select(SystemSetting).where(
        SystemSetting.key == REDEEM_RATE_SETTING))).scalar_one_or_none()
    v = row.value if row is not None else None
    try:
        if isinstance(v, dict):
            v = v.get("rate", v.get("value"))
        rate = int(v)  # type: ignore[arg-type]
        return rate if rate > 0 else DEFAULT_REDEEM_RATE
    except (TypeError, ValueError):
        return DEFAULT_REDEEM_RATE


async def redeem(db: AsyncSession, user_id: uuid.UUID, points: int) -> dict:
    """Convert points to Grow credits. Raises ValueError on bad input."""
    if points < REDEEM_MIN_POINTS:
        raise ValueError(f"Minimum redemption is {REDEEM_MIN_POINTS} points")
    bal = await get_balance(db, user_id)
    if bal["balance"] < points:
        raise ValueError("Insufficient points")
    rate = await redeem_rate(db)
    credits = points * 10 // rate
    if credits <= 0:
        raise ValueError("Redemption yields no credits at the current rate")
    ref = uuid.uuid4().hex
    ok = await _insert(db, user_id, -points, "redeem", ref)
    if not ok:  # practically impossible with a uuid ref
        raise ValueError("Redemption already processed")
    new_credits = await grant_credits(db, user_id, credits, "rewards:redeem")
    return {
        "ok": True,
        "points_redeemed": points,
        "credits_added": credits,
        "points_balance": bal["balance"] - points,
        "credits_balance": new_credits,
    }


# ------------------------------------------------- Create & Earn loop
# Grow credits are spendable on Create-page AI generations too. Costs live
# in settings (admin-tunable); level discounts apply server-side at
# deduction. The loop: create -> post -> earn -> convert -> create again.
CREATE_COSTS_SETTING = "create.costs"
DEFAULT_CREATE_COSTS: dict[str, int] = {
    # Named in the product spec:
    "image": 5, "video": 20, "script": 3, "story": 5,
    # Other backend text endpoints (small, admin-tunable):
    "ideas": 1, "captions": 2, "hooks": 1,
}
# Level -> % off generation costs. Sprout pays full price.
LEVEL_DISCOUNTS: dict[str, int] = {
    "Rising": 5, "Creator": 10, "Star": 15, "Icon": 20,
}
# Bonus points when a post is created from Virello-made content
# (mobile sends created_with="virello" on the placement request).
CREATOR_BONUS_POINTS = 5
CREATOR_BONUS_REASON = "creator_bonus"


class GenerationError(Exception):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


async def get_create_costs(db: AsyncSession) -> dict[str, int]:
    """Admin-tunable per-generation credit costs."""
    row = (await db.execute(select(SystemSetting).where(
        SystemSetting.key == CREATE_COSTS_SETTING))).scalar_one_or_none()
    v = row.value if row is not None else None
    costs = dict(DEFAULT_CREATE_COSTS)
    if isinstance(v, dict):
        for k, val in v.items():
            try:
                iv = int(val)
                if iv >= 0:
                    costs[str(k)] = iv
            except (TypeError, ValueError):
                continue
    return costs


async def update_create_costs(db: AsyncSession,
                              patch: dict) -> dict[str, int]:
    costs = await get_create_costs(db)
    for k, val in (patch or {}).items():
        try:
            iv = int(val)
        except (TypeError, ValueError):
            raise GenerationError("invalid_cost")
        if iv < 0:
            raise GenerationError("invalid_cost")
        costs[str(k)] = iv
    row = (await db.execute(select(SystemSetting).where(
        SystemSetting.key == CREATE_COSTS_SETTING))).scalar_one_or_none()
    if row is None:
        row = SystemSetting(key=CREATE_COSTS_SETTING, value=costs)
        db.add(row)
    else:
        row.value = costs
    await db.commit()
    return costs


def _discounted_cost(base: int, discount_pct: int) -> int:
    if base <= 0:
        return 0
    charged = int(base * (100 - discount_pct) / 100 + 0.5)
    return max(1, charged)


async def generation_cost(db: AsyncSession, user_id: uuid.UUID,
                          kind: str) -> dict:
    """What this generation costs THIS user: base cost, their level
    discount, and the final charge. Never raises for unknown kinds —
    unknown kinds cost the 'script' default."""
    from app.models.core import User as _User
    costs = await get_create_costs(db)
    base = int(costs.get(kind, costs.get("script", 3)))
    bal = await get_balance(db, user_id)
    level = bal["level"]
    discount_pct = LEVEL_DISCOUNTS.get(level, 0)
    user = (await db.execute(select(_User).where(
        _User.id == user_id))).scalar_one()
    return {
        "kind": kind,
        "base_credits": base,
        "level": level,
        "discount_pct": discount_pct,
        "charged_credits": _discounted_cost(base, discount_pct),
        "credits_balance": int(user.credits or 0),
    }


async def charge_generation(db: AsyncSession, user_id: uuid.UUID,
                            kind: str) -> dict:
    """Deduct credits for an AI generation (level discount applied).
    Raises GenerationError("insufficient_credits") when the balance is
    too low — the router turns this into 402 + a Rewards deep link."""
    from app.services.payments.ledger import spend_credits
    info = await generation_cost(db, user_id, kind)
    if info["credits_balance"] < info["charged_credits"]:
        raise GenerationError("insufficient_credits")
    try:
        new_bal = await spend_credits(
            db, user_id, info["charged_credits"], f"create:{kind}")
    except ValueError:
        raise GenerationError("insufficient_credits")
    info["credits_balance"] = int(new_bal)
    return info


async def award_creator_bonus(db: AsyncSession, user_id: uuid.UUID,
                              placement_id: uuid.UUID) -> int:
    """+5 bonus points for posting Virello-made content. Idempotent per
    placement (unique ref); separate from the 5/day post cap."""
    return await award(db, user_id, CREATOR_BONUS_POINTS,
                       CREATOR_BONUS_REASON, f"creator_bonus:{placement_id}")


# ------------------------------------------------------------ contests
# Weekly race: Monday 00:00 -> Sunday 23:59 Asia/Karachi.
# Monthly race: calendar month Asia/Karachi.
# Prizes are paid in points via ledger rows; settlement is idempotent
# (unique ref per period+rank) and watermarked so a period never pays twice.
KHI = ZoneInfo("Asia/Karachi")

WEEKLY_PRIZES = {1: 500, 2: 300, 3: 150}
MONTHLY_PRIZES = {1: 2000, 2: 1000, 3: 500}
WEEKLY_WINNER_REASON = "weekly_winner"
MONTHLY_WINNER_REASON = "monthly_winner"
_LAST_SETTLED_WEEK_KEY = "rewards.last_settled_week"
_LAST_SETTLED_MONTH_KEY = "rewards.last_settled_month"

_last_settle_check: date | None = None  # process-local, once per day


def _khi(now: datetime | None = None) -> datetime:
    base = now if now is not None else datetime.now(timezone.utc)
    if base.tzinfo is None:
        base = base.replace(tzinfo=timezone.utc)
    return base.astimezone(KHI)


def week_label(d: date) -> str:
    y, w, _ = d.isocalendar()
    return f"{y}-W{w:02d}"


def month_label(d: date) -> str:
    return f"{d.year}-{d.month:02d}"


def week_bounds(d: date) -> tuple[datetime, datetime]:
    """(start, end) of the ISO week containing d, as aware datetimes."""
    monday = d - timedelta(days=d.weekday())
    start = datetime(monday.year, monday.month, monday.day, tzinfo=KHI)
    return start, start + timedelta(days=7)


def month_bounds(d: date) -> tuple[datetime, datetime]:
    start = datetime(d.year, d.month, 1, tzinfo=KHI)
    if d.month == 12:
        end = datetime(d.year + 1, 1, 1, tzinfo=KHI)
    else:
        end = datetime(d.year, d.month + 1, 1, tzinfo=KHI)
    return start, end


async def _get_setting(db: AsyncSession, key: str) -> str | None:
    row = (await db.execute(select(SystemSetting).where(
        SystemSetting.key == key))).scalar_one_or_none()
    if row is None or not isinstance(row.value, dict):
        return None
    v = row.value.get("label")
    return str(v) if v else None


async def _set_setting(db: AsyncSession, key: str, label: str) -> None:
    row = (await db.execute(select(SystemSetting).where(
        SystemSetting.key == key))).scalar_one_or_none()
    if row is None:
        row = SystemSetting(key=key, value={"label": label})
        db.add(row)
    else:
        row.value = {"label": label}
    await db.commit()


def _display_name(name: str | None, email: str | None) -> str:
    return ((name or "").strip()
            or (email or "").split("@")[0]
            or "Virello user")


async def _period_top(db: AsyncSession, start: datetime, end: datetime,
                     limit: int = 3) -> list[tuple[uuid.UUID, str, int]]:
    """Top earners in [start, end). Genuine, non-suspended users only."""
    rows = (await db.execute(
        select(PointsLedger.user_id,
               func.coalesce(func.sum(PointsLedger.delta), 0).label("pts"))
        .where(PointsLedger.created_at >= start,
               PointsLedger.created_at < end,
               PointsLedger.delta > 0)
        .group_by(PointsLedger.user_id)
        .order_by(func.sum(PointsLedger.delta).desc(),
                  PointsLedger.user_id)
        .limit(max(1, limit)))).all()
    if not rows:
        return []
    users = (await db.execute(select(User).where(
        User.id.in_([r[0] for r in rows]),
        User.suspended.is_(False)))).scalars().all()
    by_id = {u.id: u for u in users}
    out = []
    for uid, pts in rows:
        u = by_id.get(uid)
        if u is None:
            continue  # suspended/deleted: no prize, never invented
        out.append((uid, _display_name(u.name, u.email), int(pts)))
    return out


async def _settle_week(db: AsyncSession, monday: date) -> str:
    start, end = week_bounds(monday)
    label = week_label(monday)
    top = await _period_top(db, start, end, 3)
    for rank, (uid, _name, _pts) in enumerate(top, start=1):
        await award(db, uid, WEEKLY_PRIZES[rank], WEEKLY_WINNER_REASON,
                    f"winner:weekly:{label}:rank{rank}")
    return label


async def _settle_month(db: AsyncSession, year: int, month: int) -> str:
    start, end = month_bounds(date(year, month, 1))
    label = f"{year}-{month:02d}"
    top = await _period_top(db, start, end, 3)
    for rank, (uid, _name, _pts) in enumerate(top, start=1):
        await award(db, uid, MONTHLY_PRIZES[rank], MONTHLY_WINNER_REASON,
                    f"winner:monthly:{label}:rank{rank}")
    return label


async def settle_periods(db: AsyncSession,
                        now: datetime | None = None) -> dict:
    """Settle every completed, not-yet-settled contest period.

    Watermarked in system_settings so each period pays exactly once;
    the ledger unique constraint makes even concurrent runs safe.
    `now` is injectable for tests.
    """
    khi = _khi(now)
    today = khi.date()
    settled: dict[str, list[str]] = {"weekly": [], "monthly": []}

    # ---- weekly: completed weeks newer than the watermark, oldest first
    last_w = await _get_setting(db, _LAST_SETTLED_WEEK_KEY)
    this_monday = today - timedelta(days=today.weekday())
    weeks: list[date] = []
    ws = this_monday - timedelta(days=7)
    while (last_w is None or week_label(ws) > last_w) and len(weeks) < 8:
        weeks.append(ws)
        ws -= timedelta(days=7)
    for ws in reversed(weeks):
        label = await _settle_week(db, ws)
        await _set_setting(db, _LAST_SETTLED_WEEK_KEY, label)
        settled["weekly"].append(label)

    # ---- monthly: completed months newer than the watermark, oldest first
    last_m = await _get_setting(db, _LAST_SETTLED_MONTH_KEY)
    months: list[tuple[int, int]] = []
    y, m = today.year, today.month - 1
    if m == 0:
        y, m = y - 1, 12
    while ((last_m is None or f"{y}-{m:02d}" > last_m)
           and len(months) < 6):
        months.append((y, m))
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    for y, m in reversed(months):
        label = await _settle_month(db, y, m)
        await _set_setting(db, _LAST_SETTLED_MONTH_KEY, label)
        settled["monthly"].append(label)
    return settled


async def _maybe_settle(db: AsyncSession) -> None:
    """Cheap once-a-day settlement trigger. Pure date compare first."""
    global _last_settle_check
    today = _khi().date()
    if _last_settle_check == today:
        return
    _last_settle_check = today
    try:
        await settle_periods(db)
    except Exception:
        log.exception("rewards: period settlement failed")


async def get_winners(db: AsyncSession, limit: int = 30) -> list[dict]:
    """Recent winning periods, newest first. Real users only."""
    await _maybe_settle(db)
    rows = (await db.execute(
        select(PointsLedger, User.name, User.email)
        .join(User, User.id == PointsLedger.user_id)
        .where(PointsLedger.reason.in_(
            [WEEKLY_WINNER_REASON, MONTHLY_WINNER_REASON]),
            PointsLedger.delta > 0)
        .order_by(desc(PointsLedger.created_at))
        .limit(max(1, min(limit, 100))))).all()
    out = []
    for pl, name, email in rows:
        # ref: winner:weekly:2026-W40:rank1
        parts = (pl.ref_id or "").split(":")
        contest = parts[1] if len(parts) > 1 else "weekly"
        period = parts[2] if len(parts) > 2 else ""
        rank = 0
        if len(parts) > 3 and parts[3].startswith("rank"):
            try:
                rank = int(parts[3][4:])
            except ValueError:
                rank = 0
        out.append({
            "contest": contest,
            "period": period,
            "rank": rank,
            "username": _display_name(name, email),
            "prize": pl.delta,
            "awarded_at": (pl.created_at.isoformat()
                           if pl.created_at else None),
        })
    return out


async def leaderboard(db: AsyncSession, limit: int = 20,
                     period: str = "rolling") -> dict:
    """Top earners. period: rolling (last 7d) | week (current contest week)
    | month (current contest month). Includes period info + prizes so the
    app can render the race with a countdown."""
    await _maybe_settle(db)
    if period not in ("rolling", "week", "month"):
        raise ValueError("period must be rolling, week or month")
    now_utc = datetime.now(timezone.utc)
    khi = _khi(now_utc)
    prizes: list[int] | None = None
    if period == "week":
        start, wend = week_bounds(khi.date())
        label, ends_at = week_label(khi.date()), wend
        prizes = [WEEKLY_PRIZES[1], WEEKLY_PRIZES[2], WEEKLY_PRIZES[3]]
        rows = await _period_top(db, start, now_utc, limit)
    elif period == "month":
        start, mend = month_bounds(khi.date())
        label, ends_at = month_label(khi.date()), mend
        prizes = [MONTHLY_PRIZES[1], MONTHLY_PRIZES[2], MONTHLY_PRIZES[3]]
        rows = await _period_top(db, start, now_utc, limit)
    else:
        start = now_utc - timedelta(days=7)
        label, ends_at = "last-7-days", None
        rows = await _period_top(db, start, now_utc, limit)
    return {
        "leaderboard": [{"username": n, "points": p} for _, n, p in rows],
        "period": {
            "scope": period,
            "label": label,
            "starts_at": start.isoformat(),
            "ends_at": ends_at.isoformat() if ends_at else None,
            "prizes": prizes,
            "timezone": "Asia/Karachi",
        },
    }


# ------------------------------------------------------------------ share-click points (replaces cash)
SHARE_CLICK_POINTS = 3
SHARE_CLICK_DAILY_CAP = 50


async def _verified_clicks_7d(db: AsyncSession,
                              user_id: uuid.UUID) -> int:
    """Verified share-link clicks in rolling 7 days."""
    from datetime import timedelta
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    return (await db.execute(
        select(func.count()).select_from(ShareClick).where(
            ShareClick.sharer_user_id == user_id,
            ShareClick.created_at >= cutoff))).scalar() or 0


async def _check_volume_bonus_points(db: AsyncSession,
                                     user_id: uuid.UUID) -> None:
    """Volume bonus: N verified share-clicks in rolling 7 days -> +points.
    Idempotent per threshold per ISO week via ref_id."""
    clicks = await _verified_clicks_7d(db, user_id)
    week = datetime.now(timezone.utc).strftime("%G-W%V")
    for t in VOLUME_BONUS_POINTS_TIERS:
        if clicks >= int(t["clicks"]):
            ref = f"volumebonus:{t['clicks']}:{week}"
            await award(db, user_id, int(t["points"]),
                        VOLUME_BONUS_REASON, ref)


async def get_volume_progress_points(db: AsyncSession,
                                     user_id: uuid.UUID) -> dict:
    """Volume-bonus progress in POINTS (no cash)."""
    clicks = await _verified_clicks_7d(db, user_id)
    week = datetime.now(timezone.utc).strftime("%G-W%V")
    out = []
    for t in VOLUME_BONUS_POINTS_TIERS:
        thr = int(t["clicks"])
        pts = int(t["points"])
        ref = f"volumebonus:{thr}:{week}"
        paid = (await db.execute(select(PointsLedger.id).where(
            PointsLedger.user_id == user_id,
            PointsLedger.reason == VOLUME_BONUS_REASON,
            PointsLedger.ref_id == ref))).scalar_one_or_none() is not None
        out.append({"clicks": thr, "points": pts,
                    "achieved": clicks >= thr, "paid": paid,
                    "progress": f"{min(clicks, thr)}/{thr}"})
    return {"clicks_7d": clicks, "thresholds": out}


async def award_share_click_points(db: AsyncSession, sharer_id: uuid.UUID,
                                   viewer_key: str,
                                   viewer_user_id: uuid.UUID | None,
                                   asin: str, code: str) -> int:
    """Points per verified share-link visit. No self-click points.
    Dedupe (viewer, code, day) is structural via ref_id."""
    if viewer_user_id is not None and viewer_user_id == sharer_id:
        return 0
    ref = f"shareclick:{code}:{viewer_key}:{datetime.now(timezone.utc).date().isoformat()}"
    # Count today's share-click points for cap
    today_start = datetime.combine(datetime.now(timezone.utc).date(),
                                   datetime.min.time(),
                                   tzinfo=timezone.utc)
    n_today = (await db.execute(select(func.count()).select_from(
        PointsLedger).where(
            PointsLedger.user_id == sharer_id,
            PointsLedger.reason == "share_click",
            PointsLedger.created_at >= today_start,
            PointsLedger.delta > 0))).scalar() or 0
    if n_today >= SHARE_CLICK_DAILY_CAP:
        return 0
    earned = await award(db, sharer_id, SHARE_CLICK_POINTS,
                         "share_click", ref)
    if earned:
        try:
            await _check_volume_bonus_points(db, sharer_id)
        except Exception:
            pass
    return earned
