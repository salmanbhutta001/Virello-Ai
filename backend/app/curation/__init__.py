"""Autonomous product curation for Virello Shop (backend-native).

Runs hourly inside the API process (APScheduler, Asia/Karachi): discovers
real trending products per Amazon department, builds gallery-first image
sets (real main photo + generated alternate angles), and lists them via the
internal curate service. No external agent needed after deploy.

Honesty contract (same as the rest of commerce):
- No invented ASINs, titles, prices, or images. Discovery adapters return
  only what they actually parsed from a live page; on bot-blocking or any
  error they return [] and log the reason.
- Gallery-first: a product is listed only with a complete 3-image gallery.
- price_cents=0 when the price is unknown ("Check price on Amazon").
- Never deletes products; the curate path is append-only (ASIN-deduped).
- Automated gallery checks verify file integrity only (valid JPEG, sane
  dimensions) — they cannot confirm the angle depicts the same product.
  Human review is recommended (see RAILWAY_SETUP.md).
"""
