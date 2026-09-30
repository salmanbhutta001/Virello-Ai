"""Curator service: shared listing logic + the hourly orchestrator.

curate_product() is the single internal listing path — the public
POST /api/v1/commerce/products/curate router calls it too, so the API and
the autonomous loop can never drift apart.

run_curation_cycle() is the hourly job: for each of the 26 departments it
ensures >=1 listed product, discovers real candidates, builds gallery-first
image sets, and lists them. Quality over filler: it skips rather than
listing junk.
"""
from __future__ import annotations

import asyncio
import logging
import re
import secrets
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.curation import config
from app.curation.discovery import (
    AmazonSearchAdapter,
    Candidate,
    add_candidate,
    mark_candidate,
    pending_candidates,
)
from app.curation.gallery import build_gallery
from app.curation.models import CurationRun
from app.models.commerce import PRODUCT_CATEGORIES, Product, ProductPage
from app.models.core import User

log = logging.getLogger("virello.curation.service")

MAX_NEW_PER_DEPARTMENT_PER_RUN = 2  # 1 required + up to 1 extra by quality


def slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60]
    return f"{slug or 'product'}-{secrets.token_hex(3)}"


async def curate_product(
    db: AsyncSession,
    *,
    asin: str,
    title: str,
    description: str = "",
    category: str = "all",
    price_cents: int = 0,
    currency: str = "USD",
    image_urls: list[str] | None = None,
    creator: User,
) -> dict:
    """List one affiliate product (idempotent by ASIN).

    Returns {"asin", "product_id", "title", "created": bool,
             "updated": [...], "skipped": bool}.
    Never deletes. Unknown price stays 0 ("Check price on Amazon").
    """
    from app.services.affiliate.amazon import AmazonAffiliateProvider

    provider = AmazonAffiliateProvider()
    asin = asin.strip().upper()
    affiliate_url = provider.build_affiliate_url(asin)
    image_urls = [u.strip() for u in (image_urls or []) if u.strip()][:10]

    existing = (
        await db.execute(select(Product).where(Product.affiliate_url == affiliate_url))
    ).scalar_one_or_none()
    if existing is not None:
        updated: list[str] = []
        if image_urls and not (existing.image_urls or []):
            existing.image_urls = image_urls
            updated.append("image_urls")
        await db.flush()
        return {"asin": asin, "product_id": str(existing.id),
                "title": existing.title, "created": False,
                "updated": updated, "skipped": not updated}

    category = (category or "all").lower()
    if category not in PRODUCT_CATEGORIES:
        category = "all"
    product = Product(
        creator_id=creator.id,
        title=title.strip()[:200],
        description=(description or "").strip(),
        price_cents=int(price_cents or 0),
        currency=(currency or "USD").upper(),
        category=category,
        image_urls=image_urls,
        stock_qty=0,  # affiliate: stock tracked by Amazon, not us
        is_active=True,
        is_affiliate=True,
        affiliate_url=affiliate_url,
        affiliate_provider="amazon",
    )
    db.add(product)
    await db.flush()
    slug = slugify(product.title)
    for _ in range(3):
        exists = (
            await db.execute(select(ProductPage.id).where(ProductPage.slug == slug))
        ).scalar_one_or_none()
        if exists is None:
            break
        slug = slugify(product.title)
    db.add(ProductPage(product_id=product.id, slug=slug))
    await db.flush()
    return {"asin": asin, "product_id": str(product.id),
            "title": product.title, "created": True,
            "updated": [], "skipped": False}


async def department_counts(db: AsyncSession) -> dict[str, int]:
    rows = (await db.execute(
        select(Product.category, func.count(Product.id))
        .where(Product.is_affiliate.is_(True), Product.is_active.is_(True))
        .group_by(Product.category)
    )).all()
    return {str(cat): int(n) for cat, n in rows}


def _append_log(lines: list[str]) -> None:
    try:
        with open(config.log_path(), "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    except OSError as e:
        log.warning("curation log append failed: %s", e)


async def run_curation_cycle(db: AsyncSession) -> dict:
    """One full hourly pass. Returns a JSON-serializable report (also saved
    to curation_runs and appended to the log file)."""
    started = datetime.now(timezone.utc)
    email = config.curator_creator_email()
    report: dict = {
        "started_at": started.isoformat(),
        "creator": config.mask_email(email),
        "departments": {},
        "errors": [],
    }

    run = CurationRun(status="running",
                      departments_total=len(config.DEPARTMENTS))
    db.add(run)
    await db.flush()

    from app.services.affiliate.amazon import AmazonAffiliateProvider
    provider = AmazonAffiliateProvider()
    if not provider.can_build_links():
        msg = "Amazon partner tag not configured — cycle aborted"
        report["errors"].append(msg)
        return await _finish(db, run, report, status="error")

    creator = None
    if email:
        creator = (await db.execute(
            select(User).where(User.email == email))).scalar_one_or_none()
    if creator is None:
        msg = ("creator account not found for "
               f"{config.mask_email(email) or 'unset email'} — listings skipped")
        report["errors"].append(msg)
        log.warning("curation: %s", msg)
        return await _finish(db, run, report, status="error")

    counts = await department_counts(db)
    # Rotation index so departments don't query the same terms every hour.
    done_runs = (await db.execute(
        select(func.count(CurationRun.id)))).scalar() or 0
    adapter = AmazonSearchAdapter()
    covered = 0
    created_total = 0

    for dept in config.DEPARTMENTS:
        have = counts.get(dept, 0)
        need = max(0, 1 - have)
        dept_info: dict = {"existing": have, "needed": need,
                           "created": [], "skipped": [], "notes": []}
        if need == 0:
            covered += 1
            report["departments"][dept] = dept_info
            continue

        # 1) Pending candidates from the queue (any source) first.
        cands: list[Candidate] = []
        for row in await pending_candidates(db, dept, limit=need):
            if row.title and row.main_image_url:
                cands.append(Candidate(
                    asin=row.asin, title=row.title, department=dept,
                    main_image_url=row.main_image_url, source=row.source))
            else:
                await mark_candidate(db, row.asin, "skipped",
                                     "missing title or main photo")
                dept_info["skipped"].append(row.asin)

        # 2) Amazon adapter for the remainder (best-effort; often blocked).
        if len(cands) < need:
            found = await adapter.discover(
                dept, query_index=done_runs,
                limit=need - len(cands))
            for c in found:
                await add_candidate(
                    db, asin=c.asin, title=c.title, department=dept,
                    source=c.source, main_image_url=c.main_image_url)
            cands.extend(found)
            if adapter.last_error and not found:
                dept_info["notes"].append(
                    f"amazon adapter: {adapter.last_error}")

        # 3) Gallery-first listing, capped per department per run.
        for cand in cands[:MAX_NEW_PER_DEPARTMENT_PER_RUN]:
            gal = await build_gallery(cand.asin, cand.main_image_url)
            if not gal["ok"]:
                await mark_candidate(db, cand.asin, "skipped",
                                     "; ".join(gal["notes"])[:240])
                dept_info["skipped"].append(cand.asin)
                dept_info["notes"].append(
                    f"{cand.asin}: gallery incomplete — skipped")
                continue
            try:
                res = await curate_product(
                    db, asin=cand.asin, title=cand.title,
                    description="", category=dept,
                    price_cents=0, currency="USD",
                    image_urls=gal["image_urls"], creator=creator)
            except Exception as e:
                dept_info["skipped"].append(cand.asin)
                dept_info["notes"].append(
                    f"{cand.asin}: listing failed ({type(e).__name__})")
                log.warning("curation listing failed %s: %s", cand.asin, e)
                continue
            await mark_candidate(db, cand.asin, "listed",
                                 "auto-listed by curation cycle")
            created_total += 1
            dept_info["created"].append({
                "asin": cand.asin, "title": cand.title,
                "real_angles": gal.get("real", 1),
                "generated_angles": gal.get("generated", 0),
                "review": "visual-fidelity not auto-verified",
            })

        if dept_info["created"]:
            covered += 1
        report["departments"][dept] = dept_info

    await db.commit()
    # Autonomous gallery publishing: push new self-hosted gallery images
    # to GitHub so auto-deploy serves them. Runs in a thread (blocking
    # git/network I/O), only when this cycle built new galleries, and can
    # never fail the cycle.
    if created_total > 0:
        try:
            from app.curation.git_push import push_new_galleries
            push_report = await asyncio.to_thread(
                push_new_galleries, str(config.gallery_dir()))
        except Exception as e:  # never fails the cycle
            log.warning("curation git push crashed: %s", type(e).__name__)
            push_report = {"pushed": False, "new_files": 0,
                           "reason": type(e).__name__}
        report["git_push"] = push_report
    status = ("ok" if covered == len(config.DEPARTMENTS)
              else "partial" if covered else "error")
    return await _finish(db, run, report, status=status,
                         covered=covered, created=created_total)


async def _finish(db: AsyncSession, run: CurationRun, report: dict,
                  status: str, covered: int = 0,
                  created: int = 0) -> dict:
    finished = datetime.now(timezone.utc)
    report["finished_at"] = finished.isoformat()
    report["status"] = status
    report["departments_covered"] = covered
    report["products_created"] = created
    run.status = status
    run.finished_at = finished
    run.departments_covered = covered
    run.products_created = created
    run.details = report
    await db.commit()

    lines = [
        f"[{finished.isoformat()}] curation cycle: {status} "
        f"({covered}/{len(config.DEPARTMENTS)} departments, "
        f"{created} created, creator={report.get('creator')})",
    ]
    for dept, info in report.get("departments", {}).items():
        n_created = len(info.get("created", []))
        n_skip = len(info.get("skipped", []))
        if n_created or n_skip or info.get("notes"):
            asins = ",".join(c["asin"] for c in info["created"])
            lines.append(
                f"  {dept}: existing={info['existing']} "
                f"created={n_created} [{asins}] skipped={n_skip}")
            lines.extend(f"    note: {n}" for n in info.get("notes", []))
    lines.extend(f"  error: {e}" for e in report.get("errors", []))
    _append_log(lines)
    log.info("curation cycle finished: %s", lines[0])
    return report
