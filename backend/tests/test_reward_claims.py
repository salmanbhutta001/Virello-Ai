"""Proof-based reward claims + per-post cash badges.

Hafiz's pivot: share rewards are PROOF-BASED — upload a screenshot of the
shared post, wait for admin approval; only then is cash credited. Every
post card carries a small "+$0.05" badge (per-post reward_cents, default
from the rewards.default_post_reward_cents setting).

Covers:
- POST /api/v1/uploads/proof (image only, <=5MB, owner/admin-only serving)
- POST /api/v1/rewards/claim (share: proof REQUIRED, creates pending claim)
- GET /api/v1/rewards/claims (my claims, with admin notes)
- GET /api/v1/admin/reward-claims (pending first, user email, post preview)
- POST /api/v1/admin/reward-claims/{id}/approve -> credited once, idempotent
- POST /api/v1/admin/reward-claims/{id}/reject -> reason required, pays 0
- PATCH /api/v1/admin/posts/{id} {reward_cents} -> per-post badge amount
- Auto-approve types skip the queue (still logged as claims)
- Guards: 403 for non-admins, 422 proof_required/reason_required,
  404 unknown post/claim, 409 duplicate claim.
"""
from __future__ import annotations

import uuid
from datetime import timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import create_token
from app.main import app
from app.models.core import Campaign, CampaignGoal, GrowthMode, User
from app.models.growth import DiscoveryPlacement
from app.models.rewards import PointsLedger, RewardClaim
from app.models.wallet import CashLedger
from app.services import reward_claims as claims_svc


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


async def _mk_user(is_admin: bool = False) -> tuple[str, str]:
    async with SessionLocal() as db:
        email = f"claim_{uuid.uuid4().hex[:8]}@test.com"
        u = User(email=email, name="Claim Tester", preferred_language="en",
                 is_admin=is_admin)
        db.add(u)
        await db.commit()
        await db.refresh(u)
        return str(u.id), email


@pytest_asyncio.fixture
async def admin_uid(monkeypatch):
    uid, email = await _mk_user(is_admin=True)
    # Admin Panel is email-allowlisted (Hafiz 2026-09-30): point the
    # allowlist at this test admin so require_admin passes.
    monkeypatch.setattr(settings, "admin_emails", email)
    return uid


@pytest_asyncio.fixture
async def user_uid():
    uid, _ = await _mk_user(is_admin=False)
    return uid


@pytest_asyncio.fixture
async def other_uid():
    uid, _ = await _mk_user(is_admin=False)
    return uid


def _auth(uid: str) -> dict:
    token = create_token(uid, timedelta(minutes=30), "access")
    return {"Authorization": f"Bearer {token}"}


async def _mk_placement(user_uid: str, reward_cents: int | None = None) -> str:
    async with SessionLocal() as db:
        camp = Campaign(
            user_id=uuid.UUID(user_uid),
            title="Test post",
            post_url=f"https://example.com/p/{uuid.uuid4().hex[:8]}",
            platform="tiktok",
            goal=CampaignGoal.reach,
            mode=GrowthMode.organic,
        )
        db.add(camp)
        await db.flush()
        pl = DiscoveryPlacement(campaign_id=camp.id, topics=["tech"],
                                status="approved", reward_cents=reward_cents)
        db.add(pl)
        await db.commit()
        await db.refresh(pl)
        return str(pl.id)


async def _file_share_claim(user_uid: str, placement_id: str,
                            proof_url: str = "https://example.com/p.jpg"
                            ) -> str:
    async with SessionLocal() as db:
        c = await claims_svc.file_claim(
            db, uuid.UUID(user_uid), "share", ref_id=placement_id,
            proof_url=proof_url)
        return str(c.id)


async def _cash(uid: str) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(CashLedger.delta_cents), 0))
            .where(CashLedger.user_id == uuid.UUID(uid)))).scalar() or 0


async def _points(uid: str) -> int:
    async with SessionLocal() as db:
        return (await db.execute(
            select(func.coalesce(func.sum(PointsLedger.delta), 0))
            .where(PointsLedger.user_id == uuid.UUID(uid)))).scalar() or 0


_PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100  # tiny fake PNG (magic + filler)


async def _upload_proof(client, uid: str) -> str:
    r = await client.post("/api/v1/uploads/proof",
                          files={"file": ("shot.png", _PNG, "image/png")},
                          headers=_auth(uid))
    assert r.status_code == 200, r.text
    return r.json()["url"]


async def _claim_via_http(client, uid: str, pid: str,
                          proof_url: str | None) -> httpx.Response:
    body = {"claim_type": "share", "post_id": pid}
    if proof_url is not None:
        body["proof_url"] = proof_url
    return await client.post("/api/v1/rewards/claim", json=body,
                             headers=_auth(uid))


# ------------------------------------------------------------ proof upload
async def test_proof_upload_image_ok(client, user_uid):
    r = await client.post("/api/v1/uploads/proof",
                          files={"file": ("shot.png", _PNG, "image/png")},
                          headers=_auth(user_uid))
    assert r.status_code == 200, r.text
    assert r.json()["url"].startswith("/api/v1/uploads/proofs/")


async def test_proof_upload_rejects_non_image(client, user_uid):
    r = await client.post("/api/v1/uploads/proof",
                          files={"file": ("note.txt", b"hello",
                                          "text/plain")},
                          headers=_auth(user_uid))
    assert r.status_code == 400, r.text


async def test_proof_upload_rejects_oversize(client, user_uid):
    big = b"\x89PNG\r\n\x1a\n" + b"\x00" * (5 * 1024 * 1024 + 1)
    r = await client.post("/api/v1/uploads/proof",
                          files={"file": ("big.png", big, "image/png")},
                          headers=_auth(user_uid))
    assert r.status_code == 400, r.text


async def test_proof_upload_requires_auth(client):
    r = await client.post("/api/v1/uploads/proof",
                          files={"file": ("shot.png", _PNG, "image/png")})
    assert r.status_code in (401, 403), r.text


async def test_proof_serving_owner_or_admin_only(client, user_uid, other_uid,
                                                 admin_uid):
    url = await _upload_proof(client, user_uid)
    r = await client.get(url, headers=_auth(other_uid))
    assert r.status_code == 403, r.text
    r = await client.get(url, headers=_auth(user_uid))
    assert r.status_code == 200, r.text
    r = await client.get(url, headers=_auth(admin_uid))
    assert r.status_code == 200, r.text


# ------------------------------------------------------------ filing claims
async def test_share_claim_requires_proof_422(client, user_uid):
    pid = await _mk_placement(user_uid)
    r = await _claim_via_http(client, user_uid, pid, None)
    assert r.status_code == 422, r.text
    assert r.json()["detail"] == "proof_required"


async def test_share_claim_unknown_post_404(client, user_uid):
    proof = await _upload_proof(client, user_uid)
    r = await _claim_via_http(client, user_uid, str(uuid.uuid4()), proof)
    assert r.status_code == 404, r.text
    assert r.json()["detail"] == "post_not_found"


async def test_share_claim_pending_no_credit_yet(client, user_uid):
    pid = await _mk_placement(user_uid)
    proof = await _upload_proof(client, user_uid)
    cash_before = await _cash(user_uid)
    r = await _claim_via_http(client, user_uid, pid, proof)
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["status"] == "pending"
    assert data["amount_cents"] == 5          # default badge: +$0.05
    assert data["amount_display"] == "$0.05"
    assert data["proof_url"] == proof
    assert "Under review" in data["message"]
    assert await _cash(user_uid) == cash_before  # nothing credited yet


async def test_duplicate_share_claim_409(client, user_uid):
    pid = await _mk_placement(user_uid)
    proof = await _upload_proof(client, user_uid)
    r1 = await _claim_via_http(client, user_uid, pid, proof)
    assert r1.status_code == 200, r1.text
    r2 = await _claim_via_http(client, user_uid, pid, proof)
    assert r2.status_code == 409, r2.text
    assert r2.json()["detail"] == "already_claimed"


async def test_non_share_type_not_user_fileable(client, user_uid):
    r = await client.post("/api/v1/rewards/claim",
                          json={"claim_type": "streak", "ref_id": "x"},
                          headers=_auth(user_uid))
    assert r.status_code == 400, r.text
    assert r.json()["detail"] == "claim_type_not_user_fileable"


# ------------------------------------------------------------------ approve
async def test_approve_credits_cash_ledger_once(client, admin_uid, user_uid):
    pid = await _mk_placement(user_uid, reward_cents=250)
    cid = await _file_share_claim(user_uid, pid)
    h_admin = _auth(admin_uid)
    r = await client.post(f"/api/v1/admin/reward-claims/{cid}/approve",
                          json={"admin_note": "verified"}, headers=h_admin)
    assert r.status_code == 200, r.text
    claim = r.json()["claim"]
    assert claim["status"] == "approved"
    assert claim["admin_note"] == "verified"
    assert claim["amount_cents"] == 250     # per-post badge amount
    async with SessionLocal() as db:
        cash = (await db.execute(select(CashLedger).where(
            CashLedger.user_id == uuid.UUID(user_uid),
            CashLedger.reason == "claim_share"))).scalars().all()
        assert sum(c.delta_cents for c in cash) == 250
    # second approve: idempotent (200), ledger unchanged
    r = await client.post(f"/api/v1/admin/reward-claims/{cid}/approve",
                          json={}, headers=h_admin)
    assert r.status_code == 200, r.text
    assert r.json()["claim"]["status"] == "approved"
    async with SessionLocal() as db:
        cash = (await db.execute(select(CashLedger).where(
            CashLedger.user_id == uuid.UUID(user_uid),
            CashLedger.reason == "claim_share"))).scalars().all()
        assert sum(c.delta_cents for c in cash) == 250


async def test_approve_unknown_claim_404(client, admin_uid):
    r = await client.post(
        f"/api/v1/admin/reward-claims/{uuid.uuid4()}/approve",
        json={}, headers=_auth(admin_uid))
    assert r.status_code == 404, r.text


# ------------------------------------------------------------------ reject
async def test_reject_requires_reason_and_pays_nothing(client, admin_uid,
                                                       user_uid):
    pid = await _mk_placement(user_uid)
    cid = await _file_share_claim(user_uid, pid)
    h_admin = _auth(admin_uid)
    r = await client.post(f"/api/v1/admin/reward-claims/{cid}/reject",
                          json={"reason": ""}, headers=h_admin)
    assert r.status_code == 422, r.text
    r = await client.post(f"/api/v1/admin/reward-claims/{cid}/reject",
                          json={"reason": "blurry screenshot"},
                          headers=h_admin)
    assert r.status_code == 200, r.text
    claim = r.json()["claim"]
    assert claim["status"] == "rejected"
    assert claim["admin_note"] == "blurry screenshot"
    async with SessionLocal() as db:
        cash = (await db.execute(select(CashLedger).where(
            CashLedger.user_id == uuid.UUID(user_uid)))).scalars().all()
        assert cash == []
        pts = (await db.execute(select(PointsLedger).where(
            PointsLedger.user_id == uuid.UUID(user_uid)))).scalars().all()
        assert pts == []
    # a rejected claim may be re-filed with a clearer screenshot:
    # it is resubmitted in place (same id, back to pending)
    cid2 = await _file_share_claim(
        user_uid, pid, proof_url="https://example.com/p2.jpg")
    assert cid2 == cid
    async with SessionLocal() as db:
        c = (await db.execute(select(RewardClaim).where(
            RewardClaim.id == uuid.UUID(cid2)))).scalar_one()
        assert c.status == "pending"
        assert c.proof_url == "https://example.com/p2.jpg"


# ------------------------------------------------------------------ list
async def test_admin_claims_pending_first(client, admin_uid, user_uid):
    pid = await _mk_placement(user_uid)
    id1 = await _file_share_claim(user_uid, pid)
    id2 = await _file_share_claim(
        user_uid, await _mk_placement(user_uid),
        proof_url="https://example.com/p2.jpg")
    h_admin = _auth(admin_uid)
    # decide the second one -> it must sort after the pending one
    r = await client.post(f"/api/v1/admin/reward-claims/{id2}/approve",
                          json={"admin_note": "looks good"}, headers=h_admin)
    assert r.status_code == 200, r.text
    r = await client.get("/api/v1/admin/reward-claims", headers=h_admin)
    assert r.status_code == 200, r.text
    items = r.json()["claims"]
    ids = [i["id"] for i in items]
    assert id1 in ids and id2 in ids
    assert ids.index(id1) < ids.index(id2)  # pending first
    mine = next(i for i in items if i["id"] == id1)
    assert "@test.com" in mine["user_email"]
    assert mine["proof_url"] == "https://example.com/p.jpg"
    assert mine["post"]["title"] == "Test post"
    assert mine["post"]["post_url"].startswith("https://example.com/p/")


async def test_admin_claims_forbidden(client, user_uid):
    pid = await _mk_placement(user_uid)
    cid = await _file_share_claim(user_uid, pid)
    h = _auth(user_uid)
    assert (await client.get("/api/v1/admin/reward-claims",
                             headers=h)).status_code == 403
    assert (await client.post(
        f"/api/v1/admin/reward-claims/{cid}/approve", json={},
        headers=h)).status_code == 403
    assert (await client.post(
        f"/api/v1/admin/reward-claims/{cid}/reject",
        json={"reason": "x"}, headers=h)).status_code == 403
    assert (await client.patch(
        f"/api/v1/admin/posts/{pid}", json={"reward_cents": 9},
        headers=h)).status_code == 403


# ------------------------------------------------------------ post reward
async def test_admin_post_reward(client, admin_uid, user_uid):
    pid = await _mk_placement(user_uid)
    h = _auth(admin_uid)
    r = await client.patch(f"/api/v1/admin/posts/{pid}",
                           json={"reward_cents": 500}, headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["reward_cents"] == 500
    assert r.json()["reward_display"] == "+$5.00"
    async with SessionLocal() as db:
        p = (await db.execute(select(DiscoveryPlacement).where(
            DiscoveryPlacement.id == uuid.UUID(pid)))).scalar_one()
        assert p.reward_cents == 500
    # share claims now pay the per-post badge
    cid = await _file_share_claim(user_uid, pid)
    r = await client.post(f"/api/v1/admin/reward-claims/{cid}/approve",
                          json={}, headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["claim"]["amount_cents"] == 500


async def test_admin_post_reward_guards(client, admin_uid, user_uid):
    pid = await _mk_placement(user_uid)
    h_admin, h_user = _auth(admin_uid), _auth(user_uid)
    r = await client.patch(f"/api/v1/admin/posts/{pid}",
                           json={"reward_cents": 100}, headers=h_user)
    assert r.status_code == 403
    r = await client.patch(f"/api/v1/admin/posts/{pid}",
                           json={"reward_cents": -1}, headers=h_admin)
    assert r.status_code == 422
    r = await client.patch(f"/api/v1/admin/posts/{uuid.uuid4()}",
                           json={"reward_cents": 100}, headers=h_admin)
    assert r.status_code == 404


# ------------------------------------------------------------ auto-approve
async def test_auto_approve_types_skip_queue(user_uid):
    """Auto-approve types are instantly approved + credited, still logged
    as claims. Filed server-side, never self-filed by the user."""
    pts_before = await _points(user_uid)
    async with SessionLocal() as db:
        claim = await claims_svc.file_claim(
            db, uuid.UUID(user_uid), "streak", ref_id="streak:auto-1",
            points=5, user_fileable_only=False)
        assert claim.status == "approved"
        assert claim.decided_at is not None
    assert await _points(user_uid) == pts_before + 5
    async with SessionLocal() as db:
        row = (await db.execute(select(PointsLedger).where(
            PointsLedger.user_id == uuid.UUID(user_uid),
            PointsLedger.reason == "claim_streak"))).scalar_one()
        assert row.ref_id == str(claim.id)


async def test_share_never_auto_approves(user_uid):
    async with SessionLocal() as db:
        cfg = await claims_svc.get_auto_approve(db)
        assert cfg["share"] is False
        assert cfg["streak"] is True
        assert cfg["post"] is True


# ------------------------------------------------------------ my claims + rules
async def test_my_claims_lists_with_admin_notes(client, admin_uid, user_uid):
    pid = await _mk_placement(user_uid)
    cid = await _file_share_claim(user_uid, pid)
    await client.post(f"/api/v1/admin/reward-claims/{cid}/reject",
                      json={"reason": "try a clearer screenshot"},
                      headers=_auth(admin_uid))
    r = await client.get("/api/v1/rewards/claims", headers=_auth(user_uid))
    assert r.status_code == 200, r.text
    claims = r.json()["claims"]
    assert len(claims) == 1
    assert claims[0]["status"] == "rejected"
    assert claims[0]["admin_note"] == "try a clearer screenshot"


async def test_rules_expose_badge_defaults(client):
    r = await client.get("/api/v1/rewards/rules")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["default_post_reward_cents"] == 5
    assert data["auto_approve"]["share"] is False
