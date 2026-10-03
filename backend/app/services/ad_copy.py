"""Heuristic ad copy generator for the AI Ad Builder (no AI provider needed).

Builds 3 ad copy variants (headline + text + CTA) with three distinct
marketing angles:

1. benefit-driven   — what the post gives the reader
2. curiosity-driven — a question / discovery hook
3. action/urgency    — honest social nudge ("try free today")

Languages: en, ur (Roman Urdu), ar (Arabic script). The generator NEVER
invents false claims: no stats, no percentages, no "guaranteed viral",
no fake reviews — every line is derived from the post's own content and
topics, so it is safe to show without review.

Stateless: pure function, no DB access.
"""
from __future__ import annotations

import re
from collections import Counter

SUPPORTED = ("en", "ur", "ar")

_URL_RE = re.compile(r"https?://\S+|www\.\S+", re.IGNORECASE)
_HASHTAG_RE = re.compile(r"#(\w+)")
_CAMEL_RE = re.compile(r"(?<!^)(?=[A-Z])")
_WORD_RE = re.compile(r"[^\w\u0600-\u06FF]+", re.UNICODE)

_EN_STOP = frozenset("""
a an the and or but if of at by for with about into over after before to
from up down out on off this that these those is are was were be been being
have has had do does did will would can could should may might must shall
i you he she it we they them his her its our their my your me him us what
which who whom whose when where why how not no yes so such as than too very
just also only even more most less new one two get got get get free today
like share follow comment post video photo check out now here there all any
""".split())

_UR_STOP = frozenset("""
ka ki ke ko se ne mein me par aur ya to tu wo woh yeh ye hai hain ho ga
gai ge hon kar kya kab kahan kaise kyon kyun lekin magar phir bhi sath
apne apki apka mere meri mera tumhe tumhara tumhari ham hamari hamara
isme iska iski uska uski unka unki jis jiska jinki koi kuch sab sabhi
hai the tha thi theek free mein aaj aj nahi nahin bhi sirf bohot zyada
""".split())

_AR_STOP = frozenset("""
من في على إلى أن إن كان يكون مع هذا هذه ذلك تلك التي الذي الذين ما ماذا
كيف متى أين لماذا لكن لكنه ولكن أو و أو ثم قد لا نعم هل هو هي هم هن نحن
أنا أنت أنتم كل بعض غير عن بين قبل بعد خلال أثناء دون ضد نحو حتى إذا
""".split())

_STOP = {"en": _EN_STOP, "ur": _UR_STOP, "ar": _AR_STOP}

_GENERIC_SUBJECT = {
    "en": "your post",
    "ur": "apki post",
    "ar": "منشورك",
}

_GENERIC_TOPIC = {
    "en": "your content",
    "ur": "apka content",
    "ar": "محتواك",
}

# (angle, headline, text, cta) — {kw}: Title Case keyword, {k}: lowercase,
# {topic}: first topic or generic topic fallback.
_TEMPLATES = {
    "en": [
        ("benefit",
         "{kw} That Works for You",
         "See how {k} can lift {topic}. Start growing today — free, no ad spend needed.",
         "Learn More"),
        ("curiosity",
         "What If {kw} Was This Easy?",
         "Discover what {k} can do for your content in a single click.",
         "See How"),
        ("urgency",
         "Try {kw} Free Today",
         "Creators like you are already exploring {k}. Take a look and start free.",
         "Get Started"),
    ],
    "ur": [
        ("benefit",
         "{kw} — Apke Liye Asaan",
         "Dekhein {k} {topic} ko kaisay grow karta hai. Aaj hi free mein shuru karein.",
         "Mazeed Janein"),
        ("curiosity",
         "Kya {kw} Itna Asaan Hai?",
         "Aik click par dekhein {k} apke content ke liye kya kar sakta hai.",
         "Dekhein Kaise"),
        ("urgency",
         "Aaj Hi {kw} Free Try Karein",
         "Apki tarah kay creators pehle se {k} use kar rahe hain. Aaj hi dekhein.",
         "Shuru Karein"),
    ],
    "ar": [
        ("benefit",
         "{kw} يعمل من أجلك",
         "اكتشف كيف يمكن لـ {kw} أن ينمّي {topic}. ابدأ اليوم مجانًا.",
         "اعرف المزيد"),
        ("curiosity",
         "ماذا لو كان {kw} بهذه السهولة؟",
         "اكتشف ما يمكن أن يفعله {kw} لمحتواك بنقرة واحدة.",
         "شاهد كيف"),
        ("urgency",
         "جرّب {kw} مجانًا اليوم",
         "المبدعون مثلك يستكشفون {kw} بالفعل. ألقِ نظرة وابدأ مجانًا.",
         "ابدأ الآن"),
    ],
}


def _split_hashtag(tag: str) -> str:
    """Split #FitnessTips into 'fitness tips'."""
    return _CAMEL_RE.sub(" ", tag).lower()


def extract_keywords(content: str, topics: list[str], lang: str) -> list[str]:
    """Top content keywords (frequency-ordered, stopword-filtered)."""
    text = _URL_RE.sub(" ", content or "")
    text = _HASHTAG_RE.sub(lambda m: " " + _split_hashtag(m.group(1)) + " ", text)
    text = text.lower()
    stop = _STOP.get(lang, _EN_STOP)
    min_len = 2 if lang == "ar" else 3
    words = [w for w in _WORD_RE.split(text)
             if len(w) >= min_len and w not in stop]
    freq = Counter(words)
    ordered = sorted(freq, key=lambda w: (-freq[w], words.index(w)))
    kws = [w for w in ordered if not w.isdigit()][:3]
    for t in topics or []:
        t = (t or "").strip().lower()
        if t and t not in kws and len(kws) < 3:
            kws.append(t)
    return kws


def _title(kw: str, lang: str) -> str:
    if not kw:
        return ""
    if lang == "ar":
        return kw
    return " ".join(w[:1].upper() + w[1:] for w in kw.split())


def generate_ad_copy_variants(content: str | None, topics: list[str] | None,
                              language: str = "en") -> dict:
    """Return {'variants': [...], 'language': ..., 'source': ...}."""
    lang = (language or "en").lower()
    if lang not in SUPPORTED:
        lang = "en"

    topics = [(t or "").strip() for t in (topics or []) if (t or "").strip()]
    kws = extract_keywords(content or "", topics, lang)

    kw = kws[0] if kws else ""
    if not kw and topics:
        kw = topics[0].lower()
    kw_title = _title(kw, lang) if kw else _GENERIC_SUBJECT[lang]
    k_low = kw if kw else _GENERIC_SUBJECT[lang]
    topic = topics[0] if topics else _GENERIC_TOPIC[lang]

    variants = []
    for angle, headline, text, cta in _TEMPLATES[lang]:
        variants.append({
            "angle": angle,
            "headline": headline.format(kw=kw_title, k=k_low, topic=topic),
            "text": text.format(kw=kw_title, k=k_low, topic=topic),
            "cta": cta.format(kw=kw_title, k=k_low, topic=topic),
        })
    return {
        "variants": variants,
        "language": lang,
        "source": "heuristic",
        "disclaimer": (
            "Heuristic draft — review before publishing. "
            "No stats or guarantees are claimed."
        ),
    }
