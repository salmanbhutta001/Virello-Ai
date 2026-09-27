"""Admin Dashboard API — the operator's control plane.

Covers: users, subscriptions, payments, credits, campaigns, AI usage,
content moderation (fraud flags), analytics, pricing/plans, countries,
notifications (broadcasts), system settings.

Access: `require_admin` — only users with is_admin=True. In production this
must sit behind the real JWT auth (never dev_noauth).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.billing import Broadcast, CountryConfig, PlanConfig, SystemSetting, Transaction
from app.models.core import (
    AgentRun, AuditLog, Campaign, CampaignStatus, FraudFlag, Subscription, User,
    UserActivity,
)
from app.services.payments.ledger import grant_credits

router = APIRouter()


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(403, "Admin access required")
    return user


# ---------------------------------------------------------------- overview
@router.get("/overview")
async def overview(db: AsyncSession = Depends(get_db),
                   _admin: User = Depends(require_admin)) -> dict:
    users = (await db.execute(select(func.count()).select_from(User))).scalar()
    campaigns = (await db.execute(select(func.count()).select_from(Campaign))).scalar()
    revenue = (await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.status == "completed", Transaction.kind != "refund")
    )).scalar()
    open_flags = (await db.execute(
        select(func.count()).select_from(FraudFlag).where(FraudFlag.resolved.is_(False))
    )).scalar()
    live = (await db.execute(
        select(func.count()).select_from(Campaign).where(
            Campaign.status == CampaignStatus.live))).scalar()
    return {"users": users, "campaigns": campaigns, "live_campaigns": live,
            "revenue_usd": float(revenue or 0), "open_fraud_flags": open_flags}


# ---------------------------------------------------------------- user analytics
# Daily / weekly / monthly visit reports for the admin dashboard.
# Source of truth: user_activity rows (app_open + login events written by the
# mobile app). Emails need no separate table — users.email is saved at signup
# (email OTP or Google/Apple OAuth upsert), so /admin/users is the email report.
_RANGE_WINDOWS = {
    "daily": (14, "day"),
    "weekly": (8 * 7, "week"),
    "monthly": (6 * 31, "month"),
}


@router.get("/analytics")
async def user_analytics(range: str = "daily",
                         db: AsyncSession = Depends(get_db),
                         _admin: User = Depends(require_admin)) -> dict:
    """Active users, new signups and visits per bucket + DAU/WAU/MAU summary."""
    if range not in _RANGE_WINDOWS:
        raise HTTPException(400, "range must be daily | weekly | monthly")
    days, grain = _RANGE_WINDOWS[range]
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days)

    day_col = func.date(UserActivity.created_at)
    act_rows = (await db.execute(
        select(day_col.label("d"),
               func.count(func.distinct(UserActivity.user_id)).label("active"),
               func.count().label("visits"))
        .where(UserActivity.created_at >= start,
               UserActivity.event.in_(["app_open", "login"]))
        .group_by(day_col)
    )).all()
    signup_rows = (await db.execute(
        select(func.date(User.created_at).label("d"), func.count().label("n"))
        .where(User.created_at >= start)
        .group_by(func.date(User.created_at))
    )).all()

    per_day: dict[str, dict] = {}
    for d, active, visits in act_rows:
        per_day[str(d)] = {"active": active or 0, "visits": visits or 0,
                           "signups": 0}
    for d, n in signup_rows:
        per_day.setdefault(str(d), {"active": 0, "visits": 0, "signups": 0})
        per_day[str(d)]["signups"] = n or 0

    # Bucket days into the requested grain.
    buckets: dict[str, dict] = {}

    def bucket_key(day: datetime) -> tuple[str, str]:
        if grain == "day":
            return day.strftime("%Y-%m-%d"), day.strftime("%b %d")
        if grain == "week":
            monday = day - timedelta(days=day.weekday())
            return monday.strftime("%Y-%m-%d"), monday.strftime("%b %d")
        first = day.replace(day=1)
        return first.strftime("%Y-%m"), first.strftime("%b %Y")

    day_cursor = start.date()
    end_day = now.date()
    # Seed every bucket in the window so charts never have gaps.
    while day_cursor <= end_day:
        key, label = bucket_key(
            datetime(day_cursor.year, day_cursor.month, day_cursor.day))
        buckets.setdefault(key, {"label": label, "active": 0,
                                 "visits": 0, "signups": 0, "revenue": 0.0})
        day_cursor += timedelta(days=1)
    for d_str, vals in per_day.items():
        day = datetime.strptime(d_str, "%Y-%m-%d")
        key, _ = bucket_key(day)
        b = buckets.get(key)
        if b is None:
            continue
        # "active" is not additive across days; take the max day in the bucket
        # as the honest representative figure.
        b["active"] = max(b["active"], vals["active"])
        b["visits"] += vals["visits"]
        b["signups"] += vals["signups"]

    # ---- sales: revenue from paid services (completed transactions) ----
    rev_rows = (await db.execute(
        select(func.date(Transaction.created_at).label("d"),
               func.sum(Transaction.amount).label("rev"))
        .where(Transaction.created_at >= start,
               Transaction.status == "completed",
               Transaction.kind.in_(["subscription", "credits"]),
               Transaction.currency == "USD")
        .group_by(func.date(Transaction.created_at))
    )).all()
    for d, rev in rev_rows:
        day = datetime.strptime(str(d), "%Y-%m-%d")
        key, _ = bucket_key(day)
        b = buckets.get(key)
        if b is not None:
            b["revenue"] = round(b["revenue"] + float(rev or 0), 2)

    kind_rows = (await db.execute(
        select(Transaction.kind,
               func.count().label("n"),
               func.coalesce(func.sum(Transaction.amount), 0).label("rev"))
        .where(Transaction.status == "completed",
               Transaction.currency == "USD")
        .group_by(Transaction.kind)
    )).all()
    by_kind = {kind: round(float(rev or 0), 2) for kind, n, rev in kind_rows}
    orders_by_kind = {kind: (n or 0) for kind, n, rev in kind_rows}
    gross = by_kind.get("subscription", 0.0) + by_kind.get("credits", 0.0)
    refunds_total = by_kind.get("refund", 0.0)
    non_usd = (await db.execute(
        select(func.count()).select_from(Transaction).where(
            Transaction.status == "completed",
            Transaction.currency != "USD"))).scalar() or 0

    async def distinct_active(since_days: int) -> int:
        q = await db.execute(
            select(func.count(func.distinct(UserActivity.user_id))).where(
                UserActivity.created_at >= now - timedelta(days=since_days),
                UserActivity.event.in_(["app_open", "login"])))
        return q.scalar() or 0

    total_users = (await db.execute(
        select(func.count()).select_from(User))).scalar() or 0
    total_visits = (await db.execute(
        select(func.count()).select_from(UserActivity))).scalar() or 0

    return {
        "range": range,
        "dau": await distinct_active(1),
        "wau": await distinct_active(7),
        "mau": await distinct_active(30),
        "total_users": total_users,
        "total_visits": total_visits,
        "series": [
            {"key": k, "label": v["label"], "active": v["active"],
             "visits": v["visits"], "signups": v["signups"],
             "revenue": v.get("revenue", 0.0)}
            for k, v in sorted(buckets.items())
        ],
        "sales": {
            "currency": "USD",
            "total_revenue": round(gross, 2),
            "refunds_total": round(refunds_total, 2),
            "net_revenue": round(gross - refunds_total, 2),
            "orders_count": (orders_by_kind.get("subscription", 0)
                             + orders_by_kind.get("credits", 0)),
            "non_usd_count": non_usd,
            "by_kind": by_kind,
            "revenue_series": [
                {"key": k, "label": v["label"],
                 "revenue": round(v.get("revenue", 0.0), 2)}
                for k, v in sorted(buckets.items())
            ],
        },
    }


# ---------------------------------------------------------------- users
@router.get("/users")
async def list_users(q: str = "", limit: int = 50,
                     db: AsyncSession = Depends(get_db),
                     _admin: User = Depends(require_admin)) -> dict:
    last_active_sq = (
        select(func.max(UserActivity.created_at))
        .where(UserActivity.user_id == User.id)
        .correlate(User)
        .scalar_subquery()
    )
    stmt = select(User, last_active_sq.label("last_active")).order_by(
        User.created_at.desc()).limit(min(limit, 200))
    if q:
        stmt = stmt.where(User.email.ilike(f"%{q}%"))
    rows = (await db.execute(stmt)).all()
    return {"users": [
        {"id": str(u.id), "email": u.email, "name": u.name, "plan": u.plan.value,
         "credits": u.credits, "is_admin": u.is_admin, "suspended": u.suspended,
         "created_at": u.created_at.isoformat() if u.created_at else None,
         "last_active": last_active.isoformat() if last_active else None}
        for u, last_active in rows]}


@router.post("/users/{user_id}/suspend")
async def suspend_user(user_id: str, db: AsyncSession = Depends(get_db),
                       admin: User = Depends(require_admin)) -> dict:
    u = (await db.execute(select(User).where(User.id == uuid.UUID(user_id)))).scalar_one_or_none()
    if not u:
        raise HTTPException(404, "User not found")
    u.suspended = True
    db.add(AuditLog(user_id=admin.id, action="admin.user.suspend",
                    details=f"target={user_id}"))
    await db.commit()
    return {"ok": True, "suspended": True}


@router.post("/users/{user_id}/unsuspend")
async def unsuspend_user(user_id: str, db: AsyncSession = Depends(get_db),
                         admin: User = Depends(require_admin)) -> dict:
    u = (await db.execute(select(User).where(User.id == uuid.UUID(user_id)))).scalar_one_or_none()
    if not u:
        raise HTTPException(404, "User not found")
    u.suspended = False
    db.add(AuditLog(user_id=admin.id, action="admin.user.unsuspend",
                    details=f"target={user_id}"))
    await db.commit()
    return {"ok": True, "suspended": False}


@router.post("/users/{user_id}/make-admin")
async def make_admin(user_id: str, db: AsyncSession = Depends(get_db),
                     admin: User = Depends(require_admin)) -> dict:
    u = (await db.execute(select(User).where(User.id == uuid.UUID(user_id)))).scalar_one_or_none()
    if not u:
        raise HTTPException(404, "User not found")
    u.is_admin = True
    db.add(AuditLog(user_id=admin.id, action="admin.user.make_admin",
                    details=f"target={user_id}"))
    await db.commit()
    return {"ok": True, "is_admin": True}


# ---------------------------------------------------------------- subscriptions / payments / credits
@router.get("/subscriptions")
async def list_subscriptions(db: AsyncSession = Depends(get_db),
                             _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(Subscription).limit(200))).scalars().all()
    return {"subscriptions": [
        {"id": str(s.id), "user_id": str(s.user_id), "plan": s.plan.value,
         "status": s.status, "provider": s.provider,
         "provider_ref": s.provider_ref,
         "current_period_end": s.current_period_end.isoformat()
         if s.current_period_end else None} for s in rows]}


@router.get("/transactions")
async def list_transactions(status: str = "", limit: int = 100,
                            db: AsyncSession = Depends(get_db),
                            _admin: User = Depends(require_admin)) -> dict:
    stmt = select(Transaction).order_by(Transaction.created_at.desc()).limit(min(limit, 500))
    if status:
        stmt = stmt.where(Transaction.status == status)
    rows = (await db.execute(stmt)).scalars().all()
    return {"transactions": [
        {"id": str(t.id), "user_id": str(t.user_id), "provider": t.provider,
         "provider_ref": t.provider_ref, "kind": t.kind,
         "amount": float(t.amount), "currency": t.currency,
         "status": t.status, "created_at": t.created_at.isoformat()} for t in rows]}


class CreditAdjust(BaseModel):
    delta: int
    reason: str = "admin_adjustment"


@router.post("/users/{user_id}/credits")
async def adjust_credits(user_id: str, body: CreditAdjust,
                         db: AsyncSession = Depends(get_db),
                         admin: User = Depends(require_admin)) -> dict:
    balance = await grant_credits(db, uuid.UUID(user_id), body.delta,
                                  f"admin:{body.reason}")
    db.add(AuditLog(user_id=admin.id, action="admin.credits.adjust",
                    details=f"target={user_id} delta={body.delta}"))
    await db.commit()
    return {"ok": True, "balance": balance}


# ---------------------------------------------------------------- campaigns
@router.get("/campaigns")
async def list_campaigns(status: str = "", limit: int = 100,
                         db: AsyncSession = Depends(get_db),
                         _admin: User = Depends(require_admin)) -> dict:
    stmt = select(Campaign).order_by(Campaign.created_at.desc()).limit(min(limit, 200))
    if status:
        stmt = stmt.where(Campaign.status == status)
    rows = (await db.execute(stmt)).scalars().all()
    return {"campaigns": [
        {"id": str(c.id), "user_id": str(c.user_id), "title": c.title,
         "platform": c.platform, "goal": c.goal.value, "mode": c.mode.value,
         "status": c.status.value, "budget_usd": c.budget_usd,
         "spend_usd": c.spend_usd} for c in rows]}


@router.post("/campaigns/{campaign_id}/pause")
async def admin_pause_campaign(campaign_id: str, db: AsyncSession = Depends(get_db),
                               admin: User = Depends(require_admin)) -> dict:
    c = (await db.execute(select(Campaign).where(
        Campaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if not c:
        raise HTTPException(404, "Campaign not found")
    c.status = CampaignStatus.paused
    db.add(AuditLog(user_id=admin.id, action="admin.campaign.pause",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    return {"ok": True, "status": "paused"}


# ---------------------------------------------------------------- AI usage
@router.get("/ai-usage")
async def ai_usage(db: AsyncSession = Depends(get_db),
                   _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(AgentRun))).scalars().all()
    total_in, total_out, by_agent = 0, 0, {}
    for r in rows:
        out = r.output or {}
        total_in += int(out.get("input_tokens", 0))
        total_out += int(out.get("output_tokens", 0))
        agg = by_agent.setdefault(r.agent, {"runs": 0, "input_tokens": 0,
                                            "output_tokens": 0, "providers": set()})
        agg["runs"] += 1
        agg["input_tokens"] += int(out.get("input_tokens", 0))
        agg["output_tokens"] += int(out.get("output_tokens", 0))
        if out.get("provider"):
            agg["providers"].add(out["provider"])
    for agg in by_agent.values():
        agg["providers"] = sorted(agg["providers"])
    return {"total_runs": len(rows), "total_input_tokens": total_in,
            "total_output_tokens": total_out, "by_agent": by_agent}


# ---------------------------------------------------------------- moderation / fraud
@router.get("/fraud-flags")
async def list_fraud_flags(open_only: bool = True,
                           db: AsyncSession = Depends(get_db),
                           _admin: User = Depends(require_admin)) -> dict:
    stmt = select(FraudFlag).order_by(FraudFlag.created_at.desc()).limit(200)
    if open_only:
        stmt = stmt.where(FraudFlag.resolved.is_(False))
    rows = (await db.execute(stmt)).scalars().all()
    return {"flags": [
        {"id": str(f.id), "campaign_id": str(f.campaign_id),
         "reason": f.reason, "resolved": f.resolved,
         "created_at": f.created_at.isoformat()} for f in rows]}


@router.post("/fraud-flags/{flag_id}/resolve")
async def resolve_flag(flag_id: str, db: AsyncSession = Depends(get_db),
                       admin: User = Depends(require_admin)) -> dict:
    f = (await db.execute(select(FraudFlag).where(
        FraudFlag.id == uuid.UUID(flag_id)))).scalar_one_or_none()
    if not f:
        raise HTTPException(404, "Flag not found")
    f.resolved = True
    db.add(AuditLog(user_id=admin.id, action="admin.fraud.resolve",
                    details=f"flag={flag_id}"))
    await db.commit()
    return {"ok": True, "resolved": True}


# ---------------------------------------------------------------- plans & pricing
class PlanIn(BaseModel):
    name: str
    price_usd: float = 0
    currency: str = "USD"
    ai_credits_monthly: int = 0
    campaigns_limit: int = 3
    active: bool = True
    sort: int = 0


@router.get("/plans")
async def admin_plans(db: AsyncSession = Depends(get_db),
                      _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(PlanConfig).order_by(PlanConfig.sort))).scalars().all()
    return {"plans": [{"slug": p.slug, "name": p.name,
                       "price_usd": float(p.price_usd), "currency": p.currency,
                       "ai_credits_monthly": p.ai_credits_monthly,
                       "campaigns_limit": p.campaigns_limit,
                       "active": p.active, "sort": p.sort} for p in rows]}


@router.put("/plans/{slug}")
async def upsert_plan(slug: str, body: PlanIn, db: AsyncSession = Depends(get_db),
                      admin: User = Depends(require_admin)) -> dict:
    p = (await db.execute(select(PlanConfig).where(PlanConfig.slug == slug))).scalar_one_or_none()
    if p is None:
        p = PlanConfig(slug=slug)
        db.add(p)
    p.name = body.name
    p.price_usd = body.price_usd
    p.currency = body.currency
    p.ai_credits_monthly = body.ai_credits_monthly
    p.campaigns_limit = body.campaigns_limit
    p.active = body.active
    p.sort = body.sort
    db.add(AuditLog(user_id=admin.id, action="admin.plan.upsert",
                    details=f"plan={slug} price={body.price_usd}"))
    await db.commit()
    return {"ok": True, "slug": slug}


# ---------------------------------------------------------------- countries
class CountryIn(BaseModel):
    name: str = ""
    enabled: bool = True
    currency: str = "USD"


@router.get("/countries")
async def list_countries(db: AsyncSession = Depends(get_db),
                         _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(CountryConfig))).scalars().all()
    return {"countries": [{"code": c.code, "name": c.name,
                           "enabled": c.enabled, "currency": c.currency}
                          for c in rows]}


@router.put("/countries/{code}")
async def upsert_country(code: str, body: CountryIn,
                         db: AsyncSession = Depends(get_db),
                         admin: User = Depends(require_admin)) -> dict:
    code = code.lower()
    c = (await db.execute(select(CountryConfig).where(
        CountryConfig.code == code))).scalar_one_or_none()
    if c is None:
        c = CountryConfig(code=code, name=body.name or code.upper())
        db.add(c)
    if body.name:
        c.name = body.name
    c.enabled = body.enabled
    c.currency = body.currency
    db.add(AuditLog(user_id=admin.id, action="admin.country.upsert",
                    details=f"country={code} enabled={body.enabled}"))
    await db.commit()
    return {"ok": True, "code": code}


# ---------------------------------------------------------------- notifications
class BroadcastIn(BaseModel):
    title: str
    body: str
    audience: str = "all"  # all | free | paid
    translations: dict = {}  # {lang_code: {title, body}}


@router.post("/broadcasts")
async def broadcast(body: BroadcastIn, db: AsyncSession = Depends(get_db),
                    admin: User = Depends(require_admin)) -> dict:
    from app.services import language as lang_svc
    clean_translations = {}
    for code, tpl in (body.translations or {}).items():
        code = str(code).strip().lower()
        if not lang_svc.is_supported(code):
            raise HTTPException(400, f"Unsupported language: {code}.")
        if isinstance(tpl, dict) and tpl.get("title") and tpl.get("body"):
            clean_translations[code] = {
                "title": str(tpl["title"])[:128],
                "body": str(tpl["body"])[:5000],
            }
    b = Broadcast(title=body.title, body=body.body,
                  audience=body.audience, created_by=admin.id,
                  translations=clean_translations)
    db.add(b)
    db.add(AuditLog(user_id=admin.id, action="admin.broadcast",
                    details=f"audience={body.audience} title={body.title[:60]}"))
    await db.commit()
    await db.refresh(b)
    return {"ok": True, "id": str(b.id)}


@router.get("/broadcasts")
async def list_broadcasts(db: AsyncSession = Depends(get_db),
                          _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(Broadcast).order_by(
        Broadcast.created_at.desc()).limit(50))).scalars().all()
    return {"broadcasts": [
        {"id": str(b.id), "title": b.title, "audience": b.audience,
         "translations": b.translations or {},
         "created_at": b.created_at.isoformat()} for b in rows]}


# ---------------------------------------------------------------- system settings
class SettingIn(BaseModel):
    value: dict = {}


@router.get("/settings")
async def list_settings(db: AsyncSession = Depends(get_db),
                        _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(SystemSetting))).scalars().all()
    return {"settings": {s.key: s.value for s in rows}}


@router.put("/settings/{key}")
async def put_setting(key: str, body: SettingIn, db: AsyncSession = Depends(get_db),
                      admin: User = Depends(require_admin)) -> dict:
    s = (await db.execute(select(SystemSetting).where(
        SystemSetting.key == key))).scalar_one_or_none()
    if s is None:
        s = SystemSetting(key=key)
        db.add(s)
    s.value = body.value
    db.add(AuditLog(user_id=admin.id, action="admin.setting.put",
                    details=f"key={key}"))
    await db.commit()
    return {"ok": True, "key": key}


# ---------------------------------------------------------------- audit
@router.get("/audit-logs")
async def audit_logs(limit: int = 100, db: AsyncSession = Depends(get_db),
                     _admin: User = Depends(require_admin)) -> dict:
    rows = (await db.execute(select(AuditLog).order_by(
        AuditLog.created_at.desc()).limit(min(limit, 500)))).scalars().all()
    return {"logs": [
        {"id": str(l.id), "user_id": str(l.user_id) if l.user_id else None,
         "action": l.action, "details": l.details,
         "created_at": l.created_at.isoformat()} for l in rows]}


@router.get("/analytics/summary")
async def analytics_summary(db: AsyncSession = Depends(get_db),
                            _admin: User = Depends(require_admin)) -> dict:
    """Platform-wide analytics for the dashboard (real rows, no promises)."""
    now = datetime.now(timezone.utc)
    rows = (await db.execute(select(Campaign))).scalars().all()
    by_status: dict[str, int] = {}
    by_goal: dict[str, int] = {}
    for c in rows:
        by_status[c.status.value] = by_status.get(c.status.value, 0) + 1
        by_goal[c.goal.value] = by_goal.get(c.goal.value, 0) + 1
    return {"generated_at": now.isoformat(), "campaigns_by_status": by_status,
            "campaigns_by_goal": by_goal}


# ---------------------------------------------------------------- discovery moderation
class DiscoveryReviewIn(BaseModel):
    note: str = ""


@router.get("/discovery/queue")
async def discovery_queue(db: AsyncSession = Depends(get_db),
                          _admin: User = Depends(require_admin)) -> dict:
    from app.models.growth import DiscoveryPlacement
    stmt = (select(DiscoveryPlacement, Campaign)
            .join(Campaign, Campaign.id == DiscoveryPlacement.campaign_id)
            .where(DiscoveryPlacement.status == "pending")
            .order_by(DiscoveryPlacement.created_at.desc()).limit(100))
    rows = (await db.execute(stmt)).all()
    return {"queue": [
        {"placement_id": str(p.id), "campaign_id": str(c.id),
         "title": c.title, "platform": c.platform, "user_id": str(c.user_id),
         "topics": p.topics, "status": p.status,
         "created_at": p.created_at.isoformat()} for p, c in rows]}


@router.post("/discovery/{placement_id}/approve")
async def discovery_approve(placement_id: str, body: DiscoveryReviewIn,
                            db: AsyncSession = Depends(get_db),
                            admin: User = Depends(require_admin)) -> dict:
    from datetime import timezone as _tz
    from app.models.growth import DiscoveryPlacement
    p = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.id == uuid.UUID(placement_id)))).scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Placement not found")
    p.status = "approved"
    p.review_note = body.note or "approved by admin"
    p.reviewed_at = datetime.now(_tz.utc)
    db.add(AuditLog(user_id=admin.id, action="admin.discovery.approve",
                    details=f"placement={placement_id}"))
    await db.commit()
    return {"ok": True, "status": "approved"}


@router.post("/discovery/{placement_id}/reject")
async def discovery_reject(placement_id: str, body: DiscoveryReviewIn,
                           db: AsyncSession = Depends(get_db),
                           admin: User = Depends(require_admin)) -> dict:
    from datetime import timezone as _tz
    from app.models.growth import DiscoveryPlacement
    p = (await db.execute(select(DiscoveryPlacement).where(
        DiscoveryPlacement.id == uuid.UUID(placement_id)))).scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Placement not found")
    p.status = "rejected"
    p.review_note = body.note or "rejected by admin"
    p.reviewed_at = datetime.now(_tz.utc)
    db.add(AuditLog(user_id=admin.id, action="admin.discovery.reject",
                    details=f"placement={placement_id}"))
    await db.commit()
    return {"ok": True, "status": "rejected"}


# ---------------------------------------------------------------- ads phase 1: segments
class AdminSegmentIn(BaseModel):
    name: str
    description: str = ""
    topics: list[str] = []
    languages: list[str] = []
    hashtags: list[str] = []
    categories: list[str] = []


def _admin_seg_json(s) -> dict:
    return {"id": str(s.id), "name": s.name, "description": s.description,
            "rule": s.rule, "signals_used": s.signals_used,
            "size_estimate": s.size_estimate, "languages": s.languages,
            "topics": s.topics, "is_active": s.is_active,
            "created_by": s.created_by, "explanation": s.explanation}


@router.get("/ads/segments")
async def ads_segments(db: AsyncSession = Depends(get_db),
                       _admin: User = Depends(require_admin)) -> dict:
    from app.models.ads import AudienceSegment
    rows = (await db.execute(select(AudienceSegment).order_by(
        AudienceSegment.name))).scalars().all()
    return {"segments": [_admin_seg_json(s) for s in rows]}


@router.post("/ads/segments", status_code=201)
async def ads_create_segment(body: AdminSegmentIn,
                             db: AsyncSession = Depends(get_db),
                             admin: User = Depends(require_admin)) -> dict:
    from app.models.ads import AudienceSegment  # noqa: F401
    from app.services import audience_intelligence as ai_svc
    try:
        seg = ai_svc.build_segment(
            name=body.name.strip()[:128],
            description=body.description.strip()[:1024],
            topics=[t.strip().lower() for t in body.topics],
            languages=[l.strip().lower() for l in body.languages],
            hashtags=[h.strip().lower().lstrip("#") for h in body.hashtags],
            categories=[c.strip().lower() for c in body.categories],
            created_by="admin")
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    seg.size_estimate = await ai_svc.estimate_segment_size(
        db, seg.topics, seg.languages)
    db.add(seg)
    db.add(AuditLog(user_id=admin.id, action="admin.ads.segment.create",
                    details=f"name={seg.name} topics={seg.topics}"))
    await db.commit()
    await db.refresh(seg)
    return {"segment": _admin_seg_json(seg)}


@router.post("/ads/segments/{segment_id}/deactivate")
async def ads_deactivate_segment(segment_id: str,
                                 db: AsyncSession = Depends(get_db),
                                 admin: User = Depends(require_admin)) -> dict:
    from app.models.ads import AudienceSegment
    s = (await db.execute(select(AudienceSegment).where(
        AudienceSegment.id == uuid.UUID(segment_id)))).scalar_one_or_none()
    if not s:
        raise HTTPException(404, "Segment not found")
    s.is_active = False
    db.add(AuditLog(user_id=admin.id, action="admin.ads.segment.deactivate",
                    details=f"segment={segment_id}"))
    await db.commit()
    return {"ok": True, "is_active": False}


@router.post("/ads/segments/seed")
async def ads_seed_segments(db: AsyncSession = Depends(get_db),
                            admin: User = Depends(require_admin)) -> dict:
    from app.services import audience_intelligence as ai_svc
    created = await ai_svc.seed_default_segments(db)
    db.add(AuditLog(user_id=admin.id, action="admin.ads.segment.seed",
                    details=f"created={len(created)}"))
    await db.commit()
    return {"ok": True, "created": len(created)}


# ---------------------------------------------------------------- ads phase 1: campaign review queue
@router.get("/ads/review-queue")
async def ads_review_queue(db: AsyncSession = Depends(get_db),
                           _admin: User = Depends(require_admin)) -> dict:
    from app.models.ads import AdCampaign, AdCampaignStatus
    rows = (await db.execute(select(AdCampaign).where(
        AdCampaign.status == AdCampaignStatus.pending_approval)
        .order_by(AdCampaign.created_at.desc()).limit(100))).scalars().all()
    return {"queue": [
        {"id": str(c.id), "owner_id": str(c.owner_id),
         "objective": c.objective.value, "status": c.status.value,
         "budget": c.budget, "duration_days": c.duration_days,
         "topics": c.topics, "languages": c.languages,
         "segment_ids": c.segment_ids, "estimate": c.estimate,
         "content_ref": c.content_ref[:200],
         "created_at": c.created_at.isoformat() if c.created_at else None}
        for c in rows]}


@router.post("/ads/campaigns/{campaign_id}/approve")
async def ads_admin_approve(campaign_id: str, db: AsyncSession = Depends(get_db),
                            admin: User = Depends(require_admin)) -> dict:
    from app.models.ads import AdCampaign, AdCampaignStatus, AdDecision
    c = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if not c:
        raise HTTPException(404, "Ad campaign not found")
    if c.status != AdCampaignStatus.pending_approval:
        raise HTTPException(400, "Only pending_approval campaigns can be approved.")
    c.status = AdCampaignStatus.approved
    db.add(AdDecision(campaign_id=c.id, agent="system", action="admin_approved",
                      details={"reasons": [f"Approved by admin {admin.email}."],
                               "metrics": {}, "disclaimer": ""}))
    db.add(AuditLog(user_id=admin.id, action="admin.ads.approve",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    return {"ok": True, "status": "approved"}


@router.post("/ads/campaigns/{campaign_id}/reject")
async def ads_admin_reject(campaign_id: str, db: AsyncSession = Depends(get_db),
                           admin: User = Depends(require_admin)) -> dict:
    from app.models.ads import AdCampaign, AdCampaignStatus, AdDecision
    c = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if not c:
        raise HTTPException(404, "Ad campaign not found")
    if c.status not in (AdCampaignStatus.draft, AdCampaignStatus.pending_approval):
        raise HTTPException(400, "Only draft/pending campaigns can be rejected.")
    c.status = AdCampaignStatus.rejected
    db.add(AdDecision(campaign_id=c.id, agent="system", action="admin_rejected",
                      details={"reasons": [f"Rejected by admin {admin.email}."],
                               "metrics": {}, "disclaimer": ""}))
    db.add(AuditLog(user_id=admin.id, action="admin.ads.reject",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    return {"ok": True, "status": "rejected"}


# ---------------------------------------------------------------- ads phase 2: sponsored delivery
@router.get("/ads/launch-queue")
async def ads_launch_queue(db: AsyncSession = Depends(get_db),
                           _admin: User = Depends(require_admin)) -> dict:
    """Approved campaigns that have no active placement yet — awaiting the
    advertiser's launch step."""
    from app.models.ad_delivery import AdPlacement, PlacementStatus
    from app.models.ads import AdCampaign, AdCampaignStatus
    from app.services import ad_distribution as _dist
    rows = (await db.execute(select(AdCampaign).where(
        AdCampaign.status == AdCampaignStatus.approved)
        .order_by(AdCampaign.created_at.desc()).limit(100))).scalars().all()
    queue = []
    for c in rows:
        active = (await db.execute(select(func.count()).select_from(
            AdPlacement).where(
                AdPlacement.campaign_id == c.id,
                AdPlacement.status == PlacementStatus.active))).scalar() or 0
        if active:
            continue
        budget = await _dist._get_budget(db, c.id)
        queue.append({
            "id": str(c.id), "owner_id": str(c.owner_id),
            "objective": c.objective.value, "status": c.status.value,
            "budget": c.budget, "duration_days": c.duration_days,
            "topics": c.topics, "languages": c.languages,
            "segment_ids": c.segment_ids,
            "budget_row": budget is not None,
            "content_ref": c.content_ref[:200],
            "created_at": c.created_at.isoformat() if c.created_at else None})
    return {"queue": queue}


@router.get("/ads/campaigns/{campaign_id}/delivery")
async def ads_delivery_overview(campaign_id: str,
                                db: AsyncSession = Depends(get_db),
                                admin: User = Depends(require_admin)) -> dict:
    """Admin delivery overview per campaign: genuine events, spend, pacing,
    per-placement breakdown."""
    from app.services import ad_distribution as _dist
    try:
        stats = await _dist.delivery_stats(db, uuid.UUID(campaign_id))
    except ValueError:
        raise HTTPException(404, "Ad campaign not found")
    db.add(AuditLog(user_id=admin.id, action="admin.ads.delivery.view",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    return stats


@router.post("/ads/placements/{placement_id}/pause")
async def ads_pause_placement(placement_id: str,
                              db: AsyncSession = Depends(get_db),
                              admin: User = Depends(require_admin)) -> dict:
    from app.models.ad_delivery import AdPlacement, PlacementStatus
    p = (await db.execute(select(AdPlacement).where(
        AdPlacement.id == uuid.UUID(placement_id)))).scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Placement not found")
    p.status = PlacementStatus.paused
    db.add(AuditLog(user_id=admin.id, action="admin.ads.placement.pause",
                    details=f"placement={placement_id} "
                            f"campaign={p.campaign_id}"))
    await db.commit()
    return {"ok": True, "status": "paused"}


@router.post("/ads/placements/{placement_id}/resume")
async def ads_resume_placement(placement_id: str,
                               db: AsyncSession = Depends(get_db),
                               admin: User = Depends(require_admin)) -> dict:
    from app.models.ad_delivery import AdPlacement, PlacementStatus
    p = (await db.execute(select(AdPlacement).where(
        AdPlacement.id == uuid.UUID(placement_id)))).scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Placement not found")
    p.status = PlacementStatus.active
    db.add(AuditLog(user_id=admin.id, action="admin.ads.placement.resume",
                    details=f"placement={placement_id} "
                            f"campaign={p.campaign_id}"))
    await db.commit()
    return {"ok": True, "status": "active"}

# ---------------------------------------------------------------- ads phase 3: optimization runs + safety queue

#: Decisions that mark a safety-pause lifecycle transition. The queue looks
#: at the most recent of THESE (rather than the raw latest decision) so a
#: same-second launch/audit row can never mask a safety pause.
_SAFETY_RELEVANT = {"auto_paused_safety", "safety_cleared",
                    "safety_keep_paused", "resumed"}


async def _latest_safety_decision(db, campaign_id):
    from app.models.ads import AdDecision
    rows = (await db.execute(select(AdDecision).where(
        AdDecision.campaign_id == uuid.UUID(str(campaign_id)),
        AdDecision.action.in_(_SAFETY_RELEVANT))
        .order_by(AdDecision.created_at.desc()))).scalars().all()
    return rows[0] if rows else None

def _opt_run_json(r) -> dict:
    return {
        "id": str(r.id), "campaign_id": str(r.campaign_id),
        "status": r.status.value, "triggered_by": r.triggered_by,
        "started_at": r.started_at.isoformat() if r.started_at else None,
        "ended_at": r.ended_at.isoformat() if r.ended_at else None,
        "summary": r.summary,
    }


@router.get("/ads/optimization-runs")
async def ads_optimization_runs(limit: int = 100,
                                db: AsyncSession = Depends(get_db),
                                admin: User = Depends(require_admin)) -> dict:
    """Admin: optimization run history across all ad campaigns."""
    from app.models.ad_optimization import AdOptimizationRun
    rows = (await db.execute(select(AdOptimizationRun)
        .order_by(AdOptimizationRun.started_at.desc()).limit(min(limit, 200))
    )).scalars().all()
    db.add(AuditLog(user_id=admin.id, action="admin.ads.optimization.view",
                    details=f"limit={limit}"))
    await db.commit()
    return {"runs": [_opt_run_json(r) for r in rows],
            "disclaimer": "Optimization is estimated guidance only — never "
                          "guaranteed outcomes."}


@router.get("/ads/safety-queue")
async def ads_safety_queue(db: AsyncSession = Depends(get_db),
                           _admin: User = Depends(require_admin)) -> dict:
    """Admin: campaigns the optimizer auto-paused over suspicious traffic,
    awaiting review. Each entry carries the fraud reasons so the decision
    is reviewable, never a black box."""
    from app.models.ads import AdCampaign, AdCampaignStatus, AdDecision
    rows = (await db.execute(select(AdCampaign).where(
        AdCampaign.status == AdCampaignStatus.paused)
        .order_by(AdCampaign.updated_at.desc()).limit(100))).scalars().all()
    queue = []
    for c in rows:
        latest = await _latest_safety_decision(db, c.id)
        from app.services import growth_agents as agents_svc
        if latest is None or \
                latest.agent not in agents_svc.ALL_GROWTH_AGENTS or \
                latest.action != "auto_paused_safety":
            continue
        details = latest.details or {}
        queue.append({
            "id": str(c.id), "owner_id": str(c.owner_id),
            "objective": c.objective.value, "status": c.status.value,
            "budget": c.budget, "topics": c.topics,
            "fraud_reasons": details.get("reasons", []),
            "metrics": details.get("metrics", {}),
            "paused_at": latest.created_at.isoformat()
            if latest.created_at else None,
        })
    return {"queue": queue,
            "note": "Campaigns auto-paused by the optimizer over suspicious "
                    "traffic. Review the fraud reasons, then resume or keep "
                    "paused."}


@router.post("/ads/campaigns/{campaign_id}/resume-safety")
async def ads_resume_safety(campaign_id: str,
                            db: AsyncSession = Depends(get_db),
                            admin: User = Depends(require_admin)) -> dict:
    """Admin: clear a safety pause — the campaign and the placements the
    optimizer paused resume delivery. Audited."""
    from app.models.ad_delivery import AdPlacement, PlacementStatus
    from app.models.ads import AdCampaign, AdCampaignStatus, AdDecision
    c = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if c is None:
        raise HTTPException(404, "Ad campaign not found")
    latest = await _latest_safety_decision(db, c.id)
    if latest is None or latest.action != "auto_paused_safety":
        raise HTTPException(400, "This campaign is not safety-paused.")
    paused_placements = (latest.details or {}).get("metrics", {}).get(
        "paused_placements", [])
    resumed: list[str] = []
    if paused_placements:
        rows = (await db.execute(select(AdPlacement).where(
            AdPlacement.campaign_id == c.id))).scalars().all()
        for p in rows:
            if str(p.id) in set(paused_placements):
                p.status = PlacementStatus.active
                resumed.append(str(p.id))
    c.status = AdCampaignStatus.active
    db.add(AdDecision(
        campaign_id=c.id, agent="system", action="safety_cleared",
        # Explicit microsecond timestamp: the safety pause row uses the DB's
        # second-resolution default, and the admin action can land in the
        # same second — explicit ordering keeps the queue deterministic.
        created_at=datetime.now(timezone.utc),
        details={"reasons": [f"Admin {admin.email} reviewed the fraud "
                             "signals and resumed delivery."],
                 "metrics": {"resumed_placements": resumed},
                 "disclaimer": ""}))
    db.add(AuditLog(user_id=admin.id, action="admin.ads.safety.resume",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    return {"ok": True, "status": "active", "resumed_placements": resumed}


@router.post("/ads/campaigns/{campaign_id}/keep-paused")
async def ads_keep_paused(campaign_id: str,
                          db: AsyncSession = Depends(get_db),
                          admin: User = Depends(require_admin)) -> dict:
    """Admin: confirm a safety pause stays in force. Audited — the queue
    entry moves out because the decision is now a deliberate human one."""
    from app.models.ads import AdCampaign, AdDecision
    c = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if c is None:
        raise HTTPException(404, "Ad campaign not found")
    latest = await _latest_safety_decision(db, c.id)
    if latest is None or latest.action != "auto_paused_safety":
        raise HTTPException(400, "This campaign is not safety-paused.")
    db.add(AdDecision(
        campaign_id=c.id, agent="system", action="safety_keep_paused",
        # Explicit microsecond timestamp — see safety_cleared above.
        created_at=datetime.now(timezone.utc),
        details={"reasons": [f"Admin {admin.email} reviewed the fraud "
                             "signals and chose to keep delivery paused."],
                 "metrics": {}, "disclaimer": ""}))
    db.add(AuditLog(user_id=admin.id, action="admin.ads.safety.keep_paused",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    return {"ok": True, "status": c.status.value}

# ---------------------------------------------------------------- ads phase 4: conversion attribution

class ConversionAdjustIn(BaseModel):
    value: float | None = None  # corrected revenue (advertiser-confirmed)
    reason: str = ""  # required: why the manual correction is legitimate


@router.get("/ads/campaigns/{campaign_id}/attribution")
async def ads_attribution_overview(campaign_id: str,
                                   db: AsyncSession = Depends(get_db),
                                   admin: User = Depends(require_admin)) -> dict:
    """Admin: conversion / attribution overview per campaign — the same
    last-click attribution the owner sees, plus the landing-event source
    breakdown and raw conversion rows. Audited."""
    from app.models.ad_attribution import (
        AdClickId, AdLandingEvent, LandingEventSource)
    from app.models.ads import AdCampaign
    from app.services import ad_attribution as _attr
    c = (await db.execute(select(AdCampaign).where(
        AdCampaign.id == uuid.UUID(campaign_id)))).scalar_one_or_none()
    if c is None:
        raise HTTPException(404, "Ad campaign not found")
    stats = await _attr.attribution_stats(db, c.id)
    # Landing-event source breakdown (pixel / webhook / api).
    breakdown = {s.value: 0 for s in LandingEventSource}
    rows = (await db.execute(
        select(AdLandingEvent.source, func.count())
        .select_from(AdLandingEvent)
        .join(AdClickId, AdClickId.id == AdLandingEvent.click_id)
        .where(AdClickId.campaign_id == c.id)
        .group_by(AdLandingEvent.source))).all()
    for source, count in rows:
        breakdown[source.value if hasattr(source, "value") else source] = count
    db.add(AuditLog(user_id=admin.id, action="admin.ads.attribution.view",
                    details=f"campaign={campaign_id}"))
    await db.commit()
    stats["landing_event_sources"] = breakdown
    stats["revenue_disclaimer"] = _attr.REVENUE_DISCLAIMER
    return stats


@router.get("/ads/landing-events")
async def ads_landing_events(campaign_id: str = "", source: str = "",
                             limit: int = 100,
                             db: AsyncSession = Depends(get_db),
                             admin: User = Depends(require_admin)) -> dict:
    """Admin: raw landing events with optional campaign / source filters and
    the source breakdown. Audited."""
    from app.models.ad_attribution import AdClickId, AdLandingEvent, LandingEventSource
    q = select(AdLandingEvent, AdClickId.campaign_id).join(
        AdClickId, AdClickId.id == AdLandingEvent.click_id)
    if campaign_id:
        q = q.where(AdClickId.campaign_id == uuid.UUID(campaign_id))
    if source:
        try:
            q = q.where(AdLandingEvent.source == LandingEventSource(source))
        except ValueError:
            raise HTTPException(
                400, f"source must be one of "
                     f"{[s.value for s in LandingEventSource]}")
    rows = (await db.execute(q.order_by(
        AdLandingEvent.occurred_at.desc()).limit(min(limit, 500)))).all()

    breakdown = {s.value: 0 for s in LandingEventSource}
    for ev, _cid in rows:
        breakdown[ev.source.value] += 1

    db.add(AuditLog(user_id=admin.id,
                    action="admin.ads.landing_events.view",
                    details=f"campaign={campaign_id or '*'} "
                            f"source={source or '*'} limit={limit}"))
    await db.commit()
    return {
        "events": [{
            "id": str(ev.id), "click_id": ev.click_id,
            "campaign_id": str(cid),
            "event_type": ev.event_type.value, "value": ev.value,
            "currency": ev.currency, "source": ev.source.value,
            "occurred_at": ev.occurred_at.isoformat()
            if ev.occurred_at else None,
            "meta": ev.meta} for ev, cid in rows],
        "source_breakdown": breakdown,
        "disclaimer": "Landing events are advertiser-reported; values are "
                      "advertiser-reported / measured revenue, not "
                      "platform-verified sales.",
    }


@router.post("/ads/conversions/{conversion_id}/adjust")
async def ads_adjust_conversion(conversion_id: str, body: ConversionAdjustIn,
                                db: AsyncSession = Depends(get_db),
                                admin: User = Depends(require_admin)) -> dict:
    """Admin: manual conversion value correction (e.g. the advertiser's
    finance team confirms a different revenue figure). A reason is REQUIRED
    and the correction is written to BOTH the attribution audit trail
    (AdDecision, agent="attribution") and the admin AuditLog."""
    from app.models.ad_attribution import AdConversion
    from app.models.ads import AdDecision
    from app.services import ad_attribution as _attr
    if not (body.reason or "").strip():
        raise HTTPException(400, "A reason is required for manual "
                                 "conversion adjustments.")
    conv = (await db.execute(select(AdConversion).where(
        AdConversion.id == uuid.UUID(conversion_id)))).scalar_one_or_none()
    if conv is None:
        raise HTTPException(404, "Conversion not found")
    try:
        new_value = _attr._validate_value(body.value)  # noqa: SLF001
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    old_value = conv.value
    conv.value = new_value
    db.add(AdDecision(
        campaign_id=conv.campaign_id, agent="attribution",
        action="admin_adjusted",
        details={
            "reasons": [
                f"Admin {admin.email} manually corrected the conversion "
                f"value: {body.reason.strip()}"],
            "metrics": {"conversion_id": str(conv.id),
                        "old_value": old_value, "new_value": new_value,
                        "event_type": conv.event_type},
            "disclaimer": _attr.REVENUE_DISCLAIMER,
        }))
    db.add(AuditLog(user_id=admin.id, action="admin.ads.conversion.adjust",
                    details=f"conversion={conversion_id} "
                            f"old={old_value} new={new_value} "
                            f"reason={body.reason.strip()[:200]}"))
    await db.commit()
    return {"ok": True, "conversion_id": str(conv.id),
            "old_value": old_value, "new_value": new_value}
