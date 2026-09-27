"""Virello post/link analysis engine.

Pipeline: safe_fetch -> extract -> score -> cache (post_analyses).

The fetcher is SSRF-hardened: only http/https, every redirect hop is
re-validated, resolved IPs must be public (no private/loopback/link-local),
timeouts + size caps on everything.
"""
from .service import analyze_post, get_cached_analysis

__all__ = ["analyze_post", "get_cached_analysis"]
