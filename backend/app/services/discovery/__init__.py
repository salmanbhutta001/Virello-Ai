"""Virello organic discovery system.

Virello's own legitimate growth ecosystem: users explicitly opt in to
topics they care about; the matcher surfaces campaigns to genuinely
interested audiences. Growth through real interest — never artificial
engagement. Every interaction recorded is a real user action.
"""
from .service import (
    get_feed, get_my_interests, get_placement_stats, record_interaction,
    request_placement, set_my_interests,
)
from .topics_seed import seed_topics

__all__ = [
    "get_feed", "get_my_interests", "get_placement_stats",
    "record_interaction", "request_placement", "set_my_interests",
    "seed_topics",
]
