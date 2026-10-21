"""Blog settings + topic rotation — all via VIRELLO_ env vars."""
from __future__ import annotations

import os

#: Categories the website blog filter knows (Hafiz's rule set).
CATEGORIES = ["AI Growth Tactics", "AI Growth", "Content", "Analytics",
              "Safety"]

#: Rotating topic briefs. The generator picks the next brief by counting
#: published AI posts, and is told every existing title so it never
#: repeats an article. (theme, category, product-department hint)
TOPICS: list[tuple[str, str, str]] = [
    ("How AI content analysis actually improves a post before publishing — what it looks at, what it cannot judge", "AI Growth", "tech"),
    ("Instagram growth in 2026: what the platform actually rewards now, based on how ranking really works", "AI Growth Tactics", "phones"),
    ("TikTok posting strategy: hooks, watch time and honest expectations for new creators", "AI Growth Tactics", "phones"),
    ("A creator's desk setup that genuinely helps you publish every day (gear, lighting, workflow)", "Content", "tech"),
    ("Reading your analytics without fooling yourself: the five numbers that matter and the vanity metrics to ignore", "Analytics", "computers"),
    ("Staying safe while growing: scams, fake growth services and account-security habits that protect creators", "Safety", "software"),
    ("YouTube Shorts vs long videos: an honest guide to choosing where your effort goes", "AI Growth Tactics", "tech"),
    ("Captions and hashtags in 2026: what still works, what is folklore", "Content", "phones"),
    ("Inside Virello: how the Free AI Post Score estimates a post before you publish it", "AI Growth", "tech"),
    ("The first 30 days of a new account: a realistic, week-by-week plan with no shortcuts", "AI Growth Tactics", "phones"),
    ("Repurposing one good idea into a week of posts across platforms", "Content", "tech"),
    ("Why consistency beats intensity: the mathematics of posting schedules", "Analytics", "office"),
    ("AI tools for creators: where automation genuinely helps and where it quietly hurts trust", "AI Growth", "software"),
    ("X (Twitter) for creators: threads, replies and building an audience in public", "AI Growth Tactics", "phones"),
    ("Lighting and audio on a budget: the upgrades viewers actually notice", "Content", "tech"),
    ("Understanding reach drops: how to diagnose a quiet week without panicking", "Analytics", "computers"),
]

MIN_WORDS = 1400


def blog_enabled() -> bool:
    return os.environ.get("VIRELLO_BLOG_AUTONOMOUS", "true").strip().lower() in (
        "1", "true", "yes", "on")


def blog_hour() -> int:
    try:
        return min(23, max(0, int(os.environ.get("VIRELLO_BLOG_HOUR", "9"))))
    except ValueError:
        return 9


def blog_minute() -> int:
    try:
        return min(59, max(0, int(os.environ.get("VIRELLO_BLOG_MINUTE", "6"))))
    except ValueError:
        return 6
