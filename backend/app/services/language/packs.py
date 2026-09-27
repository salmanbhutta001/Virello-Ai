"""Language-pack registry: data-driven multilingual support.

A language pack is a YAML file under ``packs/`` (see PACK_SCHEMA.md).
Adding a language = adding one YAML file; no code changes required.

Conventions:
- Public language codes are ISO 639-1 (``ur``, ``hi``) except Chinese,
  which uses ``zh_Hans`` / ``zh_Hant`` (langdetect reports ``zh-cn`` /
  ``zh-tw``; see detector mapping).
- ``topic_names`` maps the 24 canonical topic slugs (shared concept IDs)
  to localized display names. Cross-language matching always goes through
  the slug — never through translated keywords.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache

import yaml

_PACKS_DIR = os.path.join(os.path.dirname(__file__), "packs")

# langdetect codes -> our pack codes.
_LANGDETECT_ALIASES = {
    "zh-cn": "zh_Hans",
    "zh-tw": "zh_Hant",
}


@dataclass
class RelatedLanguage:
    code: str
    reason: str


@dataclass
class LanguagePack:
    iso_639_1: str
    iso_639_3: str = ""
    name_en: str = ""
    name_native: str = ""
    scripts: list[str] = field(default_factory=list)
    rtl: bool = False
    regions: list[str] = field(default_factory=list)
    ui_status: str = "partial"  # full | partial
    pack_quality: str = "draft"  # curated | draft
    stopwords: list[str] = field(default_factory=list)
    detection_keywords: list[str] = field(default_factory=list)
    topic_names: dict[str, str] = field(default_factory=dict)
    transliteration_variants: list[str] = field(default_factory=list)
    transliteration_keywords: list[str] = field(default_factory=list)
    related_languages: list[dict] = field(default_factory=list)
    notes: str = ""

    @property
    def code(self) -> str:
        return self.iso_639_1

    def topic_name(self, slug: str) -> str:
        return self.topic_names.get(slug, slug)

    def related(self) -> list[RelatedLanguage]:
        return [RelatedLanguage(code=r.get("code", ""),
                                reason=r.get("reason", ""))
                for r in self.related_languages if r.get("code")]


def _load_pack_file(path: str) -> LanguagePack:
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    known = {f.name for f in LanguagePack.__dataclass_fields__.values()}
    return LanguagePack(**{k: v for k, v in data.items() if k in known})


@lru_cache(maxsize=1)
def _registry() -> dict[str, LanguagePack]:
    packs: dict[str, LanguagePack] = {}
    if not os.path.isdir(_PACKS_DIR):
        return packs
    for fname in sorted(os.listdir(_PACKS_DIR)):
        if not fname.endswith((".yaml", ".yml")):
            continue
        try:
            pack = _load_pack_file(os.path.join(_PACKS_DIR, fname))
        except Exception:
            continue  # a broken pack file must never crash the registry
        if pack.iso_639_1:
            packs[pack.iso_639_1] = pack
    return packs


def reload_packs() -> None:
    """Clear the registry cache (used by tests after add_language_pack)."""
    _registry.cache_clear()


def get_pack(code: str) -> LanguagePack | None:
    """Fetch a pack by ISO 639-1 code (or langdetect alias)."""
    code = _LANGDETECT_ALIASES.get((code or "").lower(), code or "")
    return _registry().get(code)


def supported_languages() -> list[LanguagePack]:
    """All registered packs, sorted by code."""
    return [_registry()[c] for c in sorted(_registry())]


def language_codes() -> list[str]:
    return sorted(_registry())


def is_supported(code: str) -> bool:
    return get_pack(code) is not None


def add_language_pack(data: dict) -> LanguagePack:
    """Register a new language from a dict matching PACK_SCHEMA.md.

    Writes ``packs/<iso_639_1>.yaml`` and reloads the registry — this is
    the supported way to add a language without touching code.
    """
    code = (data.get("iso_639_1") or "").strip()
    if not code or len(code) > 8 or not code.replace("_", "").isalnum():
        raise ValueError("iso_639_1 must be a short alphanumeric code")
    if not isinstance(data.get("topic_names"), dict):
        raise ValueError("topic_names must be a dict of topic-slug -> name")
    os.makedirs(_PACKS_DIR, exist_ok=True)
    path = os.path.join(_PACKS_DIR, f"{code}.yaml")
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, allow_unicode=True, sort_keys=False,
                       default_flow_style=False)
    reload_packs()
    pack = get_pack(code)
    if pack is None:  # pragma: no cover - defensive
        raise RuntimeError("pack failed to load after writing")
    return pack


def describe_languages() -> list[dict]:
    """Public metadata for the language selector UI."""
    out = []
    for p in supported_languages():
        out.append({
            "code": p.code,
            "iso_639_3": p.iso_639_3,
            "name_en": p.name_en,
            "name_native": p.name_native,
            "scripts": list(p.scripts),
            "rtl": p.rtl,
            "regions": list(p.regions),
            "ui_status": p.ui_status,
            "pack_quality": p.pack_quality,
        })
    return out
