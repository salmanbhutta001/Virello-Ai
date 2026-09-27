"""Multilingual language detection for every analyzed content item.

Three independent signals are combined into one calibrated score —
Unicode script profile, the offline ``langdetect`` library, and per-pack
keyword dictionaries (plus transliteration dictionaries for Latin-script
South-Asian text such as Roman Urdu / Hinglish, which must NEVER be
mislabeled as English).

Honesty rules:
- confidence < CONFIDENCE_THRESHOLD -> ``detection_uncertain=True`` and
  the API/UI must surface it; meaning is never silently invented.
- Empty or undecipherable text -> primary ``"unknown"``.
- langdetect is seeded for determinism.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from .packs import get_pack, supported_languages

CONFIDENCE_THRESHOLD = 0.50
UNCERTAIN_MARGIN = 0.10

# Languages whose orthography has no word spaces: substring matching.
_SUBSTRING_LANGS = {"th", "zh_Hans", "zh_Hant", "ja"}

# Strong romanized evidence overrides langdetect (which is unreliable on
# romanized South-Asian text, e.g. "mein" reads as Indonesian).
TRANSLIT_OVERRIDE_HITS = 3

# langdetect guesses that are known-confusable with romanized South-Asian
# text: when we override one of these, it is discounted entirely. Any other
# overridden guess (e.g. English) remains legitimate mixed-language evidence.
_UNRELIABLE_ROMANIZED = {"id", "ms"}

try:
    from langdetect import DetectorFactory, detect_langs

    DetectorFactory.seed = 0
    _LANGDETECT_OK = True
except Exception:  # pragma: no cover - library missing
    _LANGDETECT_OK = False

# --- Unicode script ranges -------------------------------------------------
_SCRIPT_RANGES: list[tuple[str, list[tuple[int, int]]]] = [
    ("Latin", [(0x0041, 0x007A), (0x00C0, 0x024F), (0x1E00, 0x1EFF)]),
    ("Arabic", [(0x0600, 0x06FF), (0x0750, 0x077F), (0xFB50, 0xFDFF),
                (0xFE70, 0xFEFF)]),
    ("Devanagari", [(0x0900, 0x097F)]),
    ("Bengali", [(0x0980, 0x09FF)]),
    ("Gurmukhi", [(0x0A00, 0x0A7F)]),
    ("Gujarati", [(0x0A80, 0x0AFF)]),
    ("Tamil", [(0x0B80, 0x0BFF)]),
    ("Telugu", [(0x0C00, 0x0C7F)]),
    ("Kannada", [(0x0C80, 0x0CFF)]),
    ("Malayalam", [(0x0D00, 0x0D7F)]),
    ("Thai", [(0x0E00, 0x0E7F)]),
    ("Cyrillic", [(0x0400, 0x04FF)]),
    ("Greek", [(0x0370, 0x03FF)]),
    ("Hebrew", [(0x0590, 0x05FF)]),
    ("Han", [(0x4E00, 0x9FFF)]),
    ("Hiragana", [(0x3040, 0x309F)]),
    ("Katakana", [(0x30A0, 0x30FF)]),
    ("Hangul", [(0xAC00, 0xD7AF), (0x1100, 0x11FF)]),
]

# Script -> candidate pack codes (before keyword disambiguation).
_SCRIPT_CANDIDATES: dict[str, list[str]] = {
    "Arabic": ["ur", "ar", "fa", "ps", "sd"],
    "Devanagari": ["hi", "mr", "ne"],
    "Bengali": ["bn"],
    "Gurmukhi": ["pa"],
    "Gujarati": ["gu"],
    "Tamil": ["ta"],
    "Telugu": ["te"],
    "Kannada": ["kn"],
    "Malayalam": ["ml"],
    "Thai": ["th"],
    "Cyrillic": ["ru", "uk"],
    "Greek": ["el"],
    "Hebrew": ["he"],
    "Han": ["zh_Hans", "zh_Hant"],
    "Hiragana": ["ja"],
    "Katakana": ["ja"],
    "Hangul": ["ko"],
}

# Characters that only appear in one Arabic-script language here.
_ARABIC_MARKERS: dict[str, set[str]] = {
    "ur": set("ٹڈڑںھےۃ"),
    "sd": set("ٻڄڃڳڻ"),
    "ps": set("ځڅډړږښګڼۍ"),
}
_UKRAINIAN_MARKERS = set("іїєґІЇЄҐ")
_TRADITIONAL_MARKERS = set("傳統們這學國會時來説語門")

W_SCRIPT = 0.30
W_LANGDETECT = 0.30
W_KEYWORD = 0.25
W_TRANSLIT = 0.15


@dataclass
class DetectionResult:
    primary: str = "unknown"
    script: str = "unknown"
    confidence: float = 0.0
    alternatives: list[dict] = field(default_factory=list)
    is_mixed_language: bool = False
    contains_transliteration: bool = False
    transliteration_variant: str = ""
    detection_uncertain: bool = True
    method_notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "primary": self.primary,
            "script": self.script,
            "confidence": round(self.confidence, 3),
            "alternatives": self.alternatives,
            "is_mixed_language": self.is_mixed_language,
            "contains_transliteration": self.contains_transliteration,
            "transliteration_variant": self.transliteration_variant,
            "detection_uncertain": self.detection_uncertain,
            "method_notes": self.method_notes,
        }


def script_profile(text: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for ch in text:
        o = ord(ch)
        for name, ranges in _SCRIPT_RANGES:
            if any(lo <= o <= hi for lo, hi in ranges):
                counts[name] = counts.get(name, 0) + 1
                break
    return counts


def _word_hits(text_low: str, words: list[str],
               substring_ok: bool = False) -> int:
    """Count dictionary word hits. Single characters are ignored unless
    the language has no word spaces (substring_ok) — they are noise in
    spaced scripts (e.g. Persian 'و' matches inside Arabic words)."""
    hits = 0
    for w in words:
        w = w.lower().strip()
        if not w:
            continue
        if substring_ok:
            if w in text_low:
                hits += 1
        elif len(w) >= 2 and re.search(rf"(?<!\w){re.escape(w)}(?!\w)",
                                       text_low):
            hits += 1
    return hits


def detect(text: str) -> DetectionResult:
    """Detect language; never raises, never invents meaning."""
    text = (text or "").strip()
    res = DetectionResult()
    if not text:
        res.method_notes = ["empty text"]
        return res

    profile = script_profile(text)
    total_letters = sum(profile.values())
    if total_letters == 0:
        res.method_notes = ["no alphabetic characters"]
        return res
    dominant = max(profile, key=profile.get)
    res.script = dominant
    notes = [f"dominant script: {dominant}"]

    candidates = _SCRIPT_CANDIDATES.get(dominant)
    if dominant == "Latin":
        candidates = [p.code for p in supported_languages()
                      if "Latin" in p.scripts]
    elif candidates is None:
        candidates = []

    # Arabic-script disambiguation via unique characters.
    marker_boost: dict[str, float] = {}
    if dominant == "Arabic":
        for code, chars in _ARABIC_MARKERS.items():
            if any(c in text for c in chars):
                marker_boost[code] = 1.0
                notes.append(f"script markers unique to {code}")
    if dominant == "Cyrillic" and any(c in text for c in _UKRAINIAN_MARKERS):
        marker_boost["uk"] = 1.0
        notes.append("Ukrainian-specific Cyrillic letters")
    if dominant == "Han":
        if any(c in text for c in _TRADITIONAL_MARKERS):
            marker_boost["zh_Hant"] = 1.0
            notes.append("Traditional-only Han characters")

    # langdetect signal (seeded, offline).
    ld_probs: dict[str, float] = {}
    if _LANGDETECT_OK and len(text) >= 10:
        try:
            for lp in detect_langs(text):
                code = {"zh-cn": "zh_Hans", "zh-tw": "zh_Hant"}.get(
                    lp.lang, lp.lang)
                if get_pack(code):
                    ld_probs[code] = max(ld_probs.get(code, 0.0), lp.prob)
            notes.append("langdetect applied (seeded, offline)")
        except Exception:
            notes.append("langdetect failed; continuing without it")
    else:
        notes.append("langdetect skipped (short text or unavailable)")

    # Keyword + transliteration signals.
    text_low = text.lower()
    scores: dict[str, float] = {}
    kw_hit_counts: dict[str, int] = {}
    translit_hits: dict[str, int] = {}
    latin = dominant == "Latin"
    for code in candidates:
        pack = get_pack(code)
        if pack is None:
            continue
        sub = code in _SUBSTRING_LANGS
        kw_hits = _word_hits(text_low, pack.detection_keywords, sub)
        kw_hit_counts[code] = kw_hits
        kw_norm = min(1.0, kw_hits / 6.0)
        ld_s = ld_probs.get(code, 0.0)
        tr_s = 0.0
        if latin and pack.transliteration_keywords:
            th = _word_hits(text_low, pack.transliteration_keywords)
            translit_hits[code] = th
            tr_s = min(1.0, th / 8.0)
        s = (W_SCRIPT * 1.0 + W_LANGDETECT * ld_s
             + W_KEYWORD * kw_norm + W_TRANSLIT * tr_s
             + marker_boost.get(code, 0.0) * 0.5)
        scores[code] = s

    if not scores:
        res.method_notes = notes + ["no candidate languages for script"]
        return res

    ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
    primary, top = ranked[0]

    # Transliteration verdict: strong romanized evidence overrides a
    # langdetect-only verdict (langdetect misreads Roman Urdu as
    # Indonesian/Malay, Hinglish as English, etc.).
    tr_sorted = sorted(translit_hits.items(), key=lambda kv: kv[1],
                       reverse=True)
    tr_code, tr_n = tr_sorted[0] if tr_sorted else (None, 0)
    if latin and tr_code and tr_n >= 2:
        res.contains_transliteration = True
        pack = get_pack(tr_code)
        res.transliteration_variant = (
            (pack.transliteration_variants or ["romanized"])[0]
            if pack else "romanized")
        notes.append(f"transliteration detected: {res.transliteration_variant}")
    overridden: str | None = None
    translit_tie = False
    # Genuine tie (Roman Urdu vs Hinglish share the vocabulary): flag it
    # rather than pretending certainty. Evaluated whenever the
    # transliteration signal is strong — even when langdetect happens to
    # agree with the tied winner — because the shared vocabulary makes
    # the verdict genuinely ambiguous.
    tied_codes: list[str] = []
    if latin and tr_code and tr_n >= TRANSLIT_OVERRIDE_HITS:
        tied_codes = [c for c, n in tr_sorted
                      if n >= tr_n - 1 and c != tr_code]
        if tied_codes:
            translit_tie = True
    if (latin and tr_code and tr_n >= TRANSLIT_OVERRIDE_HITS
            and tr_code != primary):
        overridden = primary
        primary = tr_code
        # langdetect is documented-unreliable on romanized South-Asian
        # text, so the overridden guess is discounted, not averaged in.
        top = min(1.0, 0.55 + 0.05 * tr_n)
        notes.append("romanized text resolved via transliteration "
                     "dictionary (langdetect unreliable here)")
    if translit_tie:
        # Tie-break honestly: prefer the tied candidate with more hits on
        # words that are NOT shared with the other tied candidates
        # (e.g. "mohabbat"/"haal" are Urdu-marked; "pyaar" Hindi-marked).
        # The verdict stays flagged uncertain either way.
        contenders = [tr_code] + tied_codes
        dicts = {c: {w.lower() for w in (get_pack(c).transliteration_keywords
                                         or [])} for c in contenders}
        best, best_n = tr_code, -1
        for c in contenders:
            others = set().union(*(d for k, d in dicts.items() if k != c))
            uniq = [w for w in dicts[c] if w not in others]
            n = _word_hits(text_low, uniq)
            if n > best_n:
                best, best_n = c, n
        if best != primary:
            overridden = primary
            primary = best
            top = min(1.0, 0.55 + 0.05 * tr_n)
        notes.append("transliteration tie between "
                     + ", ".join(contenders) + " — flagged uncertain")

    res.primary = primary
    res.confidence = round(min(1.0, top), 3)
    res.alternatives = [
        {"code": c, "score": round(min(1.0, s), 3)}
        for c, s in ranked
        if c != primary and c != overridden and s >= 0.25][:3]

    # Mixed-language: independent evidence for a second language.
    second_codes = set()
    ld_top2 = sorted(ld_probs.values(), reverse=True)[:2]
    if len(ld_top2) == 2 and ld_top2[1] >= 0.30:
        second_codes.add("langdetect")
    if ld_probs:
        ld_top_code = max(ld_probs, key=lambda c: ld_probs[c])
        # langdetect disagrees with the (transliteration-resolved) primary:
        # likely a second language is present. An overridden guess is only
        # discounted when it is a known romanization-confusable; otherwise
        # (e.g. English) it is genuine mixed-language evidence.
        if (ld_top_code != primary and ld_probs[ld_top_code] >= 0.35
                and not (ld_top_code == overridden
                         and ld_top_code in _UNRELIABLE_ROMANIZED)):
            second_codes.add(ld_top_code)
    primary_pack = get_pack(primary)
    primary_tr = set((primary_pack.transliteration_keywords or [])
                     if primary_pack else [])
    for c, n in translit_hits.items():
        # Cognates shared with the primary language don't count as a
        # second language (e.g. Roman Urdu / Hinglish overlap).
        if c != primary and n >= 2 and primary_pack is not None:
            pack_c = get_pack(c)
            uniq = [w for w in (pack_c.transliteration_keywords or [])
                    if w.lower() not in primary_tr]
            if _word_hits(text_low, uniq) >= 2:
                second_codes.add(c)
    for c, n in kw_hit_counts.items():
        if c != primary and n >= 3:
            second_codes.add(c)
    script_fracs = sorted(
        (n / total_letters for n in profile.values()), reverse=True)
    if len(script_fracs) > 1 and script_fracs[1] >= 0.20:
        second_codes.add("second-script")
    res.is_mixed_language = len(second_codes) > 0
    if res.is_mixed_language:
        notes.append("independent evidence for a second language: "
                     + ", ".join(sorted(second_codes)))

    second = res.alternatives[0]["score"] if res.alternatives else 0.0
    margin = res.confidence - second
    res.detection_uncertain = (
        res.confidence < CONFIDENCE_THRESHOLD or margin < UNCERTAIN_MARGIN
        or translit_tie)
    # Gibberish guard: no dictionary evidence anywhere and langdetect
    # itself unsure -> keep the best guess but flag uncertain.
    if (not res.detection_uncertain and overridden is None
            and sum(kw_hit_counts.values()) == 0
            and max(ld_probs.values(), default=0.0) < 0.85):
        res.detection_uncertain = True
        notes.append("no dictionary evidence; statistical guess only")
    if res.detection_uncertain:
        notes.append("low confidence — flagged uncertain, not guessed")
    res.method_notes = notes
    return res


def detect_primary_code(text: str) -> str:
    """Drop-in replacement for the old heuristic detect_language()."""
    return detect(text).primary
