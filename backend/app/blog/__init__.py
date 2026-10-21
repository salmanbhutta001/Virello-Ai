"""Virello blog engine — fully backend-resident (Hafiz, 2026-10-21).

The daily article is researched, written, illustrated and published by
the backend itself (APScheduler + the configured AI provider + Pollinations
images on Cloudinary). No Muse, no cron, no website redeploy: the website
reads articles from the public API.

Honesty rules (same as the old curator cron):
- An article is published ONLY from a real AI provider response — the
  labeled dev/fallback output is never published.
- 1400+ words, real depth, no virality promises, no fake-engagement
  advice; 1-2 genuine Amazon affiliate links woven in where they fit.
- Any failed gate (provider down, too short, bad structure, image
  failed) SKIPS the day and logs why — nothing half-ready goes live.
"""
