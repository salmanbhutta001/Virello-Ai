"""Image Studio robot — renders post images and thumbnails 100% locally.

Hafiz (2026-10-21): "iska backend me robot bna do. without any API."
Agnes (the previous engine) keeps failing on his account, so the studio
now runs on this robot: pure Pillow composition — no external API, no
keys, nothing that can be "down". The user's prompt becomes the
artwork's headline over a procedurally generated background picked by
style + seed. Output is honest template art (poster/thumbnail style),
labeled provider="local-studio" wherever a provider name is recorded.

Urdu/Arabic prompts render with real shaping (arabic-reshaper +
python-bidi) and bundled Noto Nastaliq / Kufi fonts — never tofu boxes.
All fonts are open-license (Noto, DejaVu) and bundled under
app/assets/fonts/.
"""
from __future__ import annotations

import asyncio
import io
import logging
import random
import re
import uuid
from pathlib import Path

log = logging.getLogger("virello.studio_robot")

FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"

SIZES = {
    "post": (1080, 1080),
    "story": (1080, 1920),
    "thumbnail": (1280, 720),
    "wide": (1200, 630),
}

# (bg_top, bg_bottom, accent, accent2) — rich, scroll-stopping palettes.
_PALETTES = [
    ((26, 16, 54), (88, 28, 135), (236, 72, 153), (99, 102, 241)),    # violet/pink
    ((8, 47, 73), (14, 116, 144), (34, 211, 238), (52, 211, 153)),   # ocean
    ((69, 26, 3), (154, 52, 18), (251, 191, 36), (239, 68, 68)),      # ember
    ((6, 40, 28), (6, 95, 70), (52, 211, 153), (163, 230, 53)),       # emerald
    ((30, 27, 75), (76, 29, 149), (167, 139, 250), (244, 114, 182)),  # indigo dream
    ((51, 10, 32), (134, 25, 72), (251, 113, 133), (253, 186, 116)),  # rose dusk
]

_ARABIC_RE = re.compile(r"[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]")
_URDU_CHARS = set("ڑےھٹڈںؑ")


def _has_arabic(text: str) -> bool:
    return bool(_ARABIC_RE.search(text))


def _is_urdu(text: str) -> bool:
    return any(c in _URDU_CHARS for c in text)


_RAQM: bool | None = None


def _raqm() -> bool:
    """True when Pillow has libraqm (proper complex-text shaping).
    Bundled manylinux wheels include it; checked lazily, once."""
    global _RAQM
    if _RAQM is None:
        try:
            from PIL import features
            _RAQM = bool(features.check("raqm"))
        except Exception:
            _RAQM = False
    return _RAQM


def _shape(text: str) -> str:
    """Fallback joining for non-raqm builds (no-op for Latin). Modern
    builds use native raqm shaping instead — see _put/_measure."""
    if not _has_arabic(text):
        return text
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
        return get_display(arabic_reshaper.reshape(text))
    except Exception:
        return text


def _lang(text: str) -> str:
    return "ur" if _is_urdu(text) else "ar"


def _measure(draw, text: str, font, rtl: bool) -> float:
    if rtl and _raqm():
        return draw.textlength(text, font=font, direction="rtl",
                               language=_lang(text))
    probe = _shape(text) if rtl else text
    return draw.textlength(probe, font=font)


def _put(draw, x, y, text: str, font, fill, rtl: bool) -> None:
    if rtl and _raqm():
        draw.text((x, y), text, font=font, fill=fill, direction="rtl",
                  language=_lang(text), anchor="ra")
    elif rtl:
        draw.text((x, y), _shape(text), font=font, fill=fill)
    else:
        draw.text((x, y), text, font=font, fill=fill)


_font_cache: dict[tuple[str, int], object] = {}


def _font(kind: str, size: int):
    from PIL import ImageFont
    key = (kind, size)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(str(FONT_DIR / kind), size)
    return _font_cache[key]


def _font_for(text: str, *, bold_headline: bool) -> str:
    if _has_arabic(text) and not _raqm():
        # Non-raqm fallback: DejaVu carries the legacy presentation
        # forms the reshaper emits; Nastaliq/Kufi do not.
        return "fallback-bold.ttf"
    if _is_urdu(text):
        return "urdu-bold.ttf" if bold_headline else "urdu-regular.ttf"
    if _has_arabic(text):
        return "arabic-bold.ttf"
    return "headline.ttf" if bold_headline else "subtitle.ttf"


def _wrap(draw, text: str, font, max_width: int) -> list[str]:
    rtl = _has_arabic(text)
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if _measure(draw, trial, font, rtl) <= max_width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def _gradient(size, top, bottom, rng):
    """Diagonal two-stop gradient with soft color blobs on top."""
    from PIL import Image, ImageDraw, ImageFilter
    w, h = size
    base = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(base)
    steps = 256
    for i in range(steps):
        t = i / (steps - 1)
        c = tuple(int(top[j] + (bottom[j] - top[j]) * t) for j in range(3))
        y0 = int(h * i / steps)
        y1 = int(h * (i + 1) / steps) + 1
        d.rectangle([0, y0, w, y1], fill=c)
    # Soft blobs in shifted hues of the palette bottom/accent.
    blob_layer = Image.new("RGB", (w, h), (0, 0, 0))
    bd = ImageDraw.Draw(blob_layer)
    for _ in range(5):
        cx, cy = rng.randint(-w // 4, w), rng.randint(-h // 4, h)
        r = rng.randint(w // 4, w // 2)
        col = tuple(rng.randint(30, 110) for _ in range(3))
        bd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    blob_layer = blob_layer.filter(ImageFilter.GaussianBlur(w // 6))
    from PIL import ImageChops
    base = ImageChops.screen(base, blob_layer)
    return base


def _decorate(img, style: str, accent, accent2, rng):
    """Style-specific vector decoration, drawn at low alpha."""
    from PIL import Image, ImageDraw
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = (*accent, 90)
    a2 = (*accent2, 70)
    if style == "cartoon":
        # Halftone dots, top-right.
        step = max(26, w // 28)
        for yy in range(step, h // 3, step):
            for xx in range(w // 2, w, step):
                r = step // 6
                d.ellipse([xx - r, yy - r, xx + r, yy + r], fill=a2)
        # Bold corner circles.
        d.ellipse([-w // 6, h - w // 5, w // 6, h + w // 8],
                  outline=(*accent, 160), width=max(6, w // 90))
        d.ellipse([w - w // 7, -w // 8, w + w // 6, w // 5],
                  outline=(*accent2, 140), width=max(6, w // 90))
    elif style == "3d":
        # Perspective floor grid.
        horizon = int(h * 0.72)
        for i in range(9):
            y = horizon + int((h - horizon) * (i / 9) ** 1.6)
            d.line([0, y, w, y], fill=a2, width=2)
        for i in range(-6, 7):
            d.line([w // 2 + i * w // 12, horizon, w // 2 + i * w // 4, h],
                   fill=a2, width=2)
        # Glossy orbs.
        for _ in range(3):
            cx, cy = rng.randint(0, w), rng.randint(0, int(h * 0.5))
            r = rng.randint(w // 14, w // 8)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
            d.ellipse([cx - r // 2, cy - r // 2, cx, cy], fill=(*accent2, 60))
    else:  # realistic — soft rings + light flecks
        for _ in range(3):
            cx, cy = rng.randint(0, w), rng.randint(0, h)
            r = rng.randint(w // 8, w // 4)
            d.ellipse([cx - r, cy - r, cx + r, cy + r],
                      outline=(*accent, 60), width=max(4, w // 160))
        for _ in range(26):
            cx, cy = rng.randint(0, w), rng.randint(0, h)
            r = rng.randint(2, 5)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*accent2, 130))
    img.paste(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"),
              (0, 0))
    return img


def _vignette(img, strength: int = 90):
    from PIL import Image, ImageDraw, ImageFilter
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([-w // 3, -h // 3, w + w // 3, h + h // 3], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(w // 5))
    black = Image.new("RGB", (w, h), (0, 0, 0))
    dark = Image.composite(img, black, mask.point(lambda v: 255 - int((255 - v) * strength / 255)))
    return dark


def _line_factor(font_kind: str, rtl: bool) -> float:
    if font_kind.startswith("urdu"):
        return 1.95  # Nastaliq is tall
    if rtl:
        return 1.5
    return 1.18


def _split_prompt(prompt: str) -> tuple[str, str]:
    text = " ".join(prompt.strip().split())
    if len(text) <= 68:
        return text, ""
    cut = text.rfind(" ", 0, 68)
    head = text[:cut] if cut > 20 else text[:68]
    tail = text[len(head):].strip()
    return head, tail[:110]


def render_image(prompt: str, style: str = "realistic", seed: int = 0,
                 width: int = 1080, height: int = 1080) -> bytes:
    """Render one studio image locally and return PNG bytes."""
    from PIL import ImageDraw
    style = style if style in ("realistic", "cartoon", "3d") else "realistic"
    rng = random.Random(f"{prompt}|{style}|{seed}" if seed else None)
    top, bottom, accent, accent2 = _PALETTES[rng.randrange(len(_PALETTES))]

    img = _gradient((width, height), top, bottom, rng)
    img = _decorate(img, style, accent, accent2, rng)
    img = _vignette(img)
    d = ImageDraw.Draw(img, "RGBA")

    margin = int(width * 0.08)
    max_w = width - 2 * margin
    rtl = _has_arabic(prompt)

    # Kicker chip.
    kicker = "VIRELLO AI • IMAGE STUDIO"
    kf = _font("subtitle.ttf", max(20, width // 34))
    kw = d.textlength(kicker, font=kf)
    pad = width // 60
    d.rounded_rectangle([margin, margin, margin + kw + 2 * pad,
                         margin + kf.size + 2 * pad],
                        radius=(kf.size + 2 * pad) // 2,
                        fill=(*accent, 220))
    d.text((margin + pad, margin + pad - 2), kicker, font=kf,
           fill=(255, 255, 255))

    head, tail = _split_prompt(prompt)
    head_font_kind = _font_for(head, bold_headline=True)

    # Auto-fit the headline: shrink until it fits the middle band.
    size = width // 7
    lines: list[str] = []
    while size > 30:
        f = _font(head_font_kind, size)
        lines = _wrap(d, head, f, max_w)
        line_h = int(size * _line_factor(head_font_kind, rtl))
        if len(lines) <= 4 and len(lines) * line_h <= height * 0.52:
            break
        size -= 6
    hf = _font(head_font_kind, size)
    line_h = int(size * _line_factor(head_font_kind, rtl))
    block_h = len(lines) * line_h
    y = int(height * 0.30) if not tail else int(height * 0.26)
    if y + block_h > height * 0.78:
        y = max(margin * 2, int(height * 0.78) - block_h)
    for ln in lines:
        if rtl:
            _put(d, width - margin + 3, y + 3, ln, hf, (0, 0, 0, 140), rtl)
            _put(d, width - margin, y, ln, hf, (255, 255, 255), rtl)
        else:
            d.text((margin + 3, y + 3), ln, font=hf, fill=(0, 0, 0, 140))
            d.text((margin, y), ln, font=hf, fill=(255, 255, 255))
        y += line_h

    # Accent rule + subtitle.
    y += height // 40
    rule_w = width // 6
    rule_x = width - margin - rule_w if rtl else margin
    d.rounded_rectangle([rule_x, y, rule_x + rule_w, y + max(6, height // 130)],
                        radius=4, fill=(*accent2, 255))
    if tail:
        sf_kind = _font_for(tail, bold_headline=False)
        ssize = max(24, width // 26)
        sf = _font(sf_kind, ssize)
        s_lines = _wrap(d, tail, sf, max_w)[:2]
        s_lh = int(ssize * _line_factor(sf_kind, rtl))
        y += height // 30
        for ln in s_lines:
            if rtl:
                _put(d, width - margin, y, ln, sf, (235, 235, 245), rtl)
            else:
                d.text((margin, y), ln, font=sf, fill=(235, 235, 245))
            y += s_lh

    # Footer credit.
    ff = _font("subtitle.ttf", max(18, width // 44))
    credit = "Created with Virello AI"
    cw = d.textlength(credit, font=ff)
    d.text((width - margin - cw, height - margin - ff.size), credit,
           font=ff, fill=(255, 255, 255, 170))

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


async def generate_studio_image(prompt: str, style: str = "realistic",
                                seed: int = 0, *,
                                size: str = "post") -> str:
    """Render locally (CPU work off the event loop) and store on
    Cloudinary — returns the public image URL."""
    from app.curation.cloudinary_store import upload_image
    w, h = SIZES.get(size, SIZES["post"])
    data = await asyncio.to_thread(
        render_image, prompt, style, seed, w, h)
    url = await upload_image(
        data, f"studio_{uuid.uuid4().hex[:12]}", folder="virello/studio")
    log.info("studio robot rendered %dx%d style=%s -> %s", w, h, style, url)
    return url
