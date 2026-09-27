"""SSRF-safe HTTP fetcher: oEmbed (per platform) + OpenGraph fallback."""
from __future__ import annotations

import asyncio
import ipaddress
import re
from dataclasses import dataclass, field
from urllib.parse import urlparse, quote_plus

import httpx

MAX_REDIRECTS = 3
TIMEOUT_S = 8.0
MAX_BYTES = 2 * 1024 * 1024  # 2 MB cap per fetch

# Platforms with working no-auth oEmbed endpoints.
OEMBED = {
    "youtube": "https://www.youtube.com/oembed?url={url}&format=json",
    "tiktok": "https://www.tiktok.com/oembed?url={url}",
}

_OG_PROP = re.compile(
    r'<meta[^>]+(?:property|name)=["\'](?:og:|twitter:)([^"\']+)["\']'
    r'[^>]+content=["\']([^"\']*)["\']', re.IGNORECASE)
_OG_PROP_REV = re.compile(
    r'<meta[^>]+content=["\']([^"\']*)["\']'
    r'[^>]+(?:property|name)=["\'](?:og:|twitter:)([^"\']+)["\']', re.IGNORECASE)


@dataclass
class FetchResult:
    level: str = "minimal"            # oembed | opengraph | minimal
    title: str = ""
    author: str = ""
    description: str = ""
    thumbnail_url: str = ""
    media_type: str = "unknown"       # video | photo | rich | link | unknown
    oembed_type: str = ""


# Explicit SSRF blocklist. We do NOT use ip.is_private because Python also
# flags the benchmarking range 198.18.0.0/15 as "private", and sandboxed
# environments legitimately route egress through it.
_BLOCKED_NETS = [
    ipaddress.ip_network("0.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),        # RFC1918
    ipaddress.ip_network("100.64.0.0/10"),     # carrier-grade NAT
    ipaddress.ip_network("127.0.0.0/8"),       # loopback
    ipaddress.ip_network("169.254.0.0/16"),    # link-local (cloud metadata!)
    ipaddress.ip_network("172.16.0.0/12"),     # RFC1918
    ipaddress.ip_network("192.168.0.0/16"),    # RFC1918
    ipaddress.ip_network("224.0.0.0/4"),       # multicast
    ipaddress.ip_network("240.0.0.0/4"),       # reserved
    ipaddress.ip_network("::/128"),            # unspecified v6
    ipaddress.ip_network("::1/128"),           # loopback v6
    ipaddress.ip_network("fe80::/10"),         # link-local v6
    ipaddress.ip_network("fc00::/7"),          # unique-local v6
]


def _is_public_ip(ip_str: str) -> bool:
    try:
        ip = ipaddress.ip_address(ip_str)
    except ValueError:
        return False
    for net in _BLOCKED_NETS:
        if ip.version != net.version:
            continue
        if ip in net:
            return False
    return True


async def _url_is_safe(url: str) -> bool:
    """True only for http/https URLs resolving to public IPs."""
    try:
        parsed = urlparse(url)
    except Exception:
        return False
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        return False
    if parsed.username or parsed.password:
        return False
    try:
        loop = asyncio.get_running_loop()
        infos = await loop.getaddrinfo(parsed.hostname, parsed.port or 443,
                                       type=__import__("socket").SOCK_STREAM)
    except Exception:
        return False
    ips = {info[4][0] for info in infos}
    return bool(ips) and all(_is_public_ip(ip) for ip in ips)


async def _safe_get(client: httpx.AsyncClient, url: str) -> httpx.Response | None:
    """GET with manual redirect handling; every hop is re-validated."""
    current = url
    for _ in range(MAX_REDIRECTS + 1):
        if not await _url_is_safe(current):
            return None
        try:
            resp = await client.get(current, follow_redirects=False)
        except (httpx.HTTPError, OSError):
            return None
        if resp.status_code in (301, 302, 303, 307, 308):
            location = resp.headers.get("location", "")
            if not location:
                return None
            # Resolve relative redirects.
            if location.startswith("/"):
                p = urlparse(current)
                location = f"{p.scheme}://{p.netloc}{location}"
            current = location
            continue
        if resp.status_code != 200:
            return None
        return resp
    return None


def _parse_og(html: str) -> dict:
    tags: dict[str, str] = {}
    for m in _OG_PROP.finditer(html):
        tags[m.group(1).lower()] = m.group(2)
    for m in _OG_PROP_REV.finditer(html):
        tags[m.group(2).lower()] = m.group(1)
    return tags


def _client() -> httpx.AsyncClient:
    # Explicit proxy wiring (trust_env=False): httpx chokes on bracketed
    # IPv6 entries like [::1] in no_proxy. We read the proxy ourselves.
    # TLS uses the OS CA store (not certifi) so intercepting egress proxies
    # whose CA is installed system-wide keep working; SSL_CERT_FILE wins.
    import os
    import ssl
    proxy = (os.environ.get("https_proxy") or os.environ.get("HTTPS_PROXY")
             or os.environ.get("http_proxy") or os.environ.get("HTTP_PROXY"))
    cafile = os.environ.get("SSL_CERT_FILE")
    ctx = ssl.create_default_context(cafile=cafile) if cafile \
        else ssl.create_default_context()
    return httpx.AsyncClient(
        trust_env=False,
        proxy=proxy or None,
        verify=ctx,
        timeout=httpx.Timeout(TIMEOUT_S, connect=5.0),
        headers={"User-Agent": "VirelloBot/1.0 (+https://virello.app/bot)"},
    )


async def fetch_post(url: str, platform: str) -> FetchResult:
    """Best-effort fetch: oEmbed first, then OpenGraph, else minimal."""
    result = FetchResult()
    if not await _url_is_safe(url):
        return result

    async with _client() as client:
        # 1) oEmbed where supported without auth.
        template = OEMBED.get(platform)
        if template:
            oembed_url = template.format(url=quote_plus(url))
            if await _url_is_safe(oembed_url):
                try:
                    resp = await client.get(oembed_url)
                    if resp.status_code == 200:
                        data = resp.json()
                        result.level = "oembed"
                        result.title = str(data.get("title", ""))[:512]
                        result.author = str(data.get("author_name", ""))[:256]
                        result.thumbnail_url = str(
                            data.get("thumbnail_url", ""))[:2048]
                        result.oembed_type = str(data.get("type", ""))
                        result.media_type = {
                            "video": "video", "photo": "photo",
                            "rich": "rich", "link": "link",
                        }.get(result.oembed_type, "unknown")
                        return result
                except (httpx.HTTPError, ValueError):
                    pass

        # 2) OpenGraph / Twitter card meta tags.
        resp = await _safe_get(client, url)
        if resp is not None:
            try:
                body = b""
                async for chunk in resp.aiter_bytes(65536):
                    body += chunk
                    if len(body) > MAX_BYTES:
                        break
                tags = _parse_og(body.decode("utf-8", errors="ignore"))
                if tags:
                    result.level = "opengraph"
                    result.title = tags.get("title", "")[:512]
                    result.description = tags.get("description", "")[:2000]
                    result.thumbnail_url = tags.get("image", "")[:2048]
                    result.media_type = (
                        "video" if tags.get("video") or tags.get("type") == "video"
                        else "photo" if tags.get("image") else "link")
                    return result
            except (httpx.HTTPError, OSError):
                pass

    return result  # minimal: URL + platform only
