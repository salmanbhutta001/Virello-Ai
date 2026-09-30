"""Discovery adapters — turn the live web into verified candidates.

Each adapter returns only products it actually saw: (ASIN, title, main
photo URL). On bot-blocking, HTTP errors, timeouts, or parse failures it
returns [] and records the reason — it NEVER fabricates a candidate.

Adapters:
- AmazonSearchAdapter: amazon.com search pages (browser User-Agent).
  Amazon aggressively bot-blocks datacenter IPs; expect frequent skips.
- Candidate queue (DB): curation_candidates rows from any source
  ("curator_agent", "manual", "amazon_search"). This is the reliable path —
  the existing hourly curator pipeline can keep feeding it.
"""
from __future__ import annotations

import html as htmlmod
import logging
import re
import urllib.parse
from dataclasses import dataclass, field

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.curation import config
from app.curation.models import CurationCandidate

log = logging.getLogger("virello.curation.discovery")

ASIN_RE = re.compile(r"/dp/([A-Z0-9]{10})(?:[/?]|$)")
DATA_ASIN_RE = re.compile(r'<div data-asin="([A-Z0-9]{10})"')
TITLE_RE = re.compile(r'aria-label="Go to detail page for &quot;(.+?)&quot;',
                      re.DOTALL)
H2_RE = re.compile(r"<h2[^>]*>.*?<span[^>]*>(.*?)</span>", re.S)
IMG_RE = re.compile(r'srcset="(https://m\.media-amazon\.com/images/I/[^"\s]+)')


@dataclass
class Candidate:
    asin: str
    title: str
    department: str
    main_image_url: str
    source: str = "amazon_search"
    note: str = ""


def parse_amazon_search(html: str, department: str,
                        limit: int = 6) -> list[Candidate]:
    """Parse an amazon.com search result page. Pure function — unit-tested
    on fixture HTML. Skips blocks without a verifiable title+photo."""
    out: list[Candidate] = []
    seen: set[str] = set()
    divs = list(DATA_ASIN_RE.finditer(html))
    for i, m in enumerate(divs):
        asin = m.group(1)
        if asin in seen:
            continue
        end = divs[i + 1].start() if i + 1 < len(divs) else m.start() + 12000
        seg = html[m.start():end]
        title: str | None = None
        tm = TITLE_RE.search(seg)
        if tm:
            title = htmlmod.unescape(tm.group(1)).strip()
            # Trim Amazon's aria-label suffixes (" Not eligible for Prime...",
            # " Best Seller." etc.) — keep the product name.
            title = re.split(r"\.\s+(Not eligible|Best Seller|Add to cart)",
                             title)[0].strip().rstrip(".")
            title = re.sub(r"\s+", " ", title)
        else:
            h2 = H2_RE.search(seg)
            if h2:
                title = htmlmod.unescape(
                    re.sub(r"<[^>]+>", " ", h2.group(1))).strip()
                title = re.sub(r"\s+", " ", title)
        if not title or len(title) < 8:
            continue
        im = IMG_RE.search(seg)
        if not im:
            continue
        seen.add(asin)
        out.append(Candidate(
            asin=asin,
            title=title[:200],
            department=department,
            main_image_url=im.group(1),
            source="amazon_search",
        ))
        if len(out) >= limit:
            break
    return out


class AmazonSearchAdapter:
    """Best-effort adapter. Datacenter IPs are routinely served bot-checks;
    that is a normal, logged skip — not an error to retry aggressively."""

    def __init__(self, timeout: float = 25.0):
        self.timeout = timeout
        self.last_error: str = ""

    async def discover(self, department: str, query_index: int = 0,
                       limit: int = 4) -> list[Candidate]:
        queries = config.DEPARTMENT_QUERIES.get(department, [department])
        query = queries[query_index % len(queries)]
        url = ("https://www.amazon.com/s?k="
               + urllib.parse.quote_plus(query))
        headers = {
            "User-Agent": config.BROWSER_UA,
            "Accept-Language": "en-US,en;q=0.9",
            "Accept": "text/html,application/xhtml+xml",
        }
        try:
            async with httpx.AsyncClient(timeout=self.timeout,
                                         follow_redirects=True) as client:
                r = await client.get(url, headers=headers)
        except Exception as e:  # network failure — skip honestly
            self.last_error = f"network: {type(e).__name__}"
            log.info("amazon discover %s: %s", department, self.last_error)
            return []
        if r.status_code != 200:
            self.last_error = f"http {r.status_code}"
            log.info("amazon discover %s: %s", department, self.last_error)
            return []
        body = r.text
        if re.search(r"captcha|Robot Check|Enter the characters",
                     body, re.I):
            self.last_error = "bot-check page"
            log.info("amazon discover %s: served bot-check, skipping",
                     department)
            return []
        cands = parse_amazon_search(body, department, limit=limit)
        if not cands:
            self.last_error = "no parseable product blocks"
            log.info("amazon discover %s: %s", department, self.last_error)
        return cands


# ---------------------------------------------------------------------------
# Candidate queue (DB) — open feeder, no code changes needed for new sources.
# ---------------------------------------------------------------------------

async def add_candidate(db: AsyncSession, *, asin: str, title: str,
                        department: str, source: str,
                        main_image_url: str = "",
                        note: str = "") -> CurationCandidate:
    """Insert or refresh a candidate (ASIN-unique). Used by adapters and by
    the existing curator pipeline / admin tooling."""
    asin = asin.strip().upper()
    row = (await db.execute(
        select(CurationCandidate).where(CurationCandidate.asin == asin)
    )).scalar_one_or_none()
    if row is None:
        row = CurationCandidate(
            asin=asin, title=title.strip()[:200], department=department,
            source=source, main_image_url=main_image_url, note=note[:255],
            status="pending",
        )
        db.add(row)
    else:
        row.title = title.strip()[:200]
        row.department = department
        row.source = source
        if main_image_url:
            row.main_image_url = main_image_url
        if row.status == "skipped" and note:
            row.status = "pending"  # allow re-try with a note
        row.note = note[:255]
    await db.flush()
    return row


async def pending_candidates(db: AsyncSession, department: str,
                             limit: int = 5) -> list[CurationCandidate]:
    rows = (await db.execute(
        select(CurationCandidate)
        .where(CurationCandidate.department == department,
               CurationCandidate.status == "pending")
        .order_by(CurationCandidate.created_at.asc())
        .limit(limit)
    )).scalars().all()
    return list(rows)


async def mark_candidate(db: AsyncSession, asin: str, status: str,
                         note: str = "") -> None:
    row = (await db.execute(
        select(CurationCandidate).where(CurationCandidate.asin == asin.upper())
    )).scalar_one_or_none()
    if row is not None:
        row.status = status
        if note:
            row.note = note[:255]
        await db.flush()


@dataclass
class DiscoveryResult:
    candidates: list[Candidate] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
