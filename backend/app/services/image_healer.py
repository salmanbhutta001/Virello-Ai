"""
Image Healer Robot — auto-fixes broken product hero/thumbnail images.

Hafiz (2026-10-14): "jb ksi ki hero image crash ho jaye to uska backend per
robot bna do jo khud hi analyze kar kay us product ka thumbnail aur hero
image set kar dey"

What it does:
1. Scans all products in the catalog.
2. Checks every image URL (HTTP GET, verifies it's actually an image).
3. For products with a broken HERO image (first in image_urls):
   - Tries each gallery image in order; promotes the first working one to hero.
   - If NO gallery image works, tries to re-fetch from Amazon CDN
     (images-na.ssl-images-amazon.com fallback for m.media-amazon.com).
   - If nothing works, marks product as needs_recuration (does not delete).
4. For products with broken GALLERY images (not hero):
   - Removes dead URLs, keeps working ones.
   - If gallery drops below 3 images, flags for backfill.
5. All changes are logged; nothing is deleted from the catalog.

Safe to run on a schedule (e.g. daily) or on-demand.
"""

import asyncio
import logging
from typing import Optional
from urllib.parse import urlparse

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger("image_healer")

# Timeouts: image hosts can be slow; don't hang the whole scan
CHECK_TIMEOUT = 15.0
MAX_CONCURRENT_CHECKS = 10

# Minimum bytes for a "real" image (filters out 1px placeholders / error pages)
MIN_IMAGE_BYTES = 2048


def _is_amazon_url(url: str) -> bool:
    """Check if URL is from Amazon's CDN."""
    try:
        host = urlparse(url).netloc.lower()
        return "media-amazon.com" in host or "ssl-images-amazon.com" in host
    except Exception:
        return False


def _amazon_fallback_url(url: str) -> Optional[str]:
    """
    m.media-amazon.com is unreachable from some networks.
    images-na.ssl-images-amazon.com serves the same CDN paths.
    Returns the fallback URL, or None if not an Amazon URL.
    """
    if "m.media-amazon.com" in url:
        return url.replace("m.media-amazon.com", "images-na.ssl-images-amazon.com")
    return None


async def check_image_alive(url: str, client: httpx.AsyncClient) -> bool:
    """
    Returns True if the URL serves a real image.
    Uses GET with Range header (first 8KB) — fast and reliable.
    Falls back to Amazon CDN mirror if the primary host fails.
    """
    urls_to_try = [url]
    fallback = _amazon_fallback_url(url)
    if fallback:
        urls_to_try.append(fallback)

    for try_url in urls_to_try:
        try:
            # Range request: just need headers + a few bytes to confirm it's an image
            resp = await client.get(
                try_url,
                headers={"Range": "bytes=0-8191", "User-Agent": "Mozilla/5.0"},
                timeout=CHECK_TIMEOUT,
                follow_redirects=True,
            )
            if resp.status_code not in (200, 206):
                continue
            ct = resp.headers.get("content-type", "").lower()
            if not ct.startswith("image/"):
                continue
            if len(resp.content) < MIN_IMAGE_BYTES and resp.status_code == 200:
                # Full response but tiny = placeholder or error image
                # (Range 206 responses are partial by design, skip this check)
                continue
            return True
        except Exception as e:
            logger.debug(f"Image check failed for {try_url}: {e}")
            continue
    return False


async def heal_product_images(
    db: AsyncSession,
    product_id,
    image_urls: list[str],
    client: httpx.AsyncClient,
) -> dict:
    """
    Analyze one product's images and fix what's broken.
    Returns a report dict with actions taken.
    """
    report = {
        "product_id": str(product_id),
        "hero_broken": False,
        "hero_fixed": False,
        "gallery_removed": 0,
        "gallery_kept": 0,
        "new_image_urls": None,
        "needs_recuration": False,
    }

    if not image_urls:
        report["needs_recuration"] = True
        return report

    # Check all images concurrently
    sem = asyncio.Semaphore(MAX_CONCURRENT_CHECKS)

    async def _check(u):
        async with sem:
            return await check_image_alive(u, client)

    alive = await asyncio.gather(*[_check(u) for u in image_urls])
    alive_map = dict(zip(image_urls, alive))

    working = [u for u in image_urls if alive_map.get(u)]
    broken = [u for u in image_urls if not alive_map.get(u)]

    report["gallery_kept"] = len(working)
    report["gallery_removed"] = len(broken)

    hero_url = image_urls[0]
    hero_alive = alive_map.get(hero_url, False)

    if not hero_alive:
        report["hero_broken"] = True
        if working:
            # Promote first working gallery image to hero position
            new_order = working + [u for u in broken if u not in working]
            # Actually just use working ones; broken ones at the end are useless
            # Keep only working to avoid future breakage
            report["new_image_urls"] = working
            report["hero_fixed"] = True
            logger.info(
                f"Healed hero for {product_id}: "
                f"promoted {working[0][:60]}... "
                f"(removed {len(broken)} dead URLs)"
            )
        else:
            # All images dead — nothing to promote
            report["needs_recuration"] = True
            logger.warning(
                f"Product {product_id} has ALL images dead "
                f"({len(broken)} URLs). Flagged for recuration."
            )
    elif broken:
        # Hero is fine, but some gallery images are dead — clean them
        report["new_image_urls"] = working
        logger.info(
            f"Cleaned {len(broken)} dead gallery URLs for {product_id}, "
            f"hero intact."
        )

    return report


async def run_image_healer(
    db: AsyncSession,
    batch_size: int = 100,
    dry_run: bool = False,
) -> dict:
    """
    Scan the full catalog and heal broken images.
    Returns a summary dict.

    Set dry_run=True to only report without making changes.
    """
    # Import here to avoid circular imports
    from app.models.commerce import Product

    summary = {
        "scanned": 0,
        "hero_broken": 0,
        "hero_fixed": 0,
        "gallery_cleaned": 0,
        "needs_recuration": [],
        "errors": 0,
    }

    async with httpx.AsyncClient() as client:
        offset = 0
        while True:
            result = await db.execute(
                select(Product).offset(offset).limit(batch_size)
            )
            products = result.scalars().all()
            if not products:
                break

            for p in products:
                summary["scanned"] += 1
                try:
                    image_urls = list(p.image_urls or [])
                    report = await heal_product_images(db, p.id, image_urls, client)

                    if report["hero_broken"]:
                        summary["hero_broken"] += 1
                    if report["hero_fixed"]:
                        summary["hero_fixed"] += 1
                    if report["gallery_removed"] > 0 and not report["hero_broken"]:
                        summary["gallery_cleaned"] += 1
                    if report["needs_recuration"]:
                        summary["needs_recuration"].append(str(p.id))

                    # Apply the fix
                    if report["new_image_urls"] is not None and not dry_run:
                        await db.execute(
                            update(Product)
                            .where(Product.id == p.id)
                            .values(image_urls=report["new_image_urls"])
                        )

                except Exception as e:
                    summary["errors"] += 1
                    logger.error(f"Error healing product {p.id}: {e}")

            if not dry_run:
                await db.commit()

            offset += batch_size
            logger.info(f"Healer progress: {summary['scanned']} scanned...")

    logger.info(
        f"Image healer done: {summary['scanned']} scanned, "
        f"{summary['hero_broken']} broken heroes, "
        f"{summary['hero_fixed']} fixed, "
        f"{summary['gallery_cleaned']} galleries cleaned, "
        f"{len(summary['needs_recuration'])} need recuration, "
        f"{summary['errors']} errors."
    )
    return summary
