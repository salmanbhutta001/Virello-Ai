"""Cross-language semantic layer: shared concept IDs, never word-for-word.

The 24 topic slugs (``technology`` … ``marketing``) are the canonical
concept IDs. Every language pack maps those slugs to localized names;
:func:`normalize_label_to_topic` maps a label in ANY supported language
back to the slug. A query in Urdu therefore matches content tagged in
Arabic or English, because both resolve to the same concept ID.

``MultilingualEmbedder`` is the interface for vector similarity.
The default :class:`ConceptEmbedder` is a deterministic, transparent
heuristic over the taxonomy — it is documented as such and is NOT a
neural embedding. If ``sentence-transformers`` with a multilingual
model is installed, :class:`SentenceTransformerEmbedder` becomes the
preferred backend automatically (graceful fallback otherwise).
"""
from __future__ import annotations

import math
import re
from abc import ABC, abstractmethod
from functools import lru_cache

from .packs import get_pack, supported_languages

TOPIC_SLUGS = ["technology", "business", "fashion", "food", "travel",
               "fitness", "education", "music", "gaming", "comedy", "beauty",
               "health", "finance", "sports", "photography", "art",
               "motivation", "parenting", "realestate", "automobiles",
               "pets", "news", "lifestyle", "marketing"]

# English keyword hints mapping free text / hashtags to concept slugs.
# The single source of truth; audience_fingerprint merges Urdu additions.
TOPIC_KEYWORD_HINTS: dict[str, list[str]] = {
    "technology": ["tech", "ai", "software", "app", "digital", "gadget",
                   "computer", "robot", "chip", "startup"],
    "business": ["business", "startup", "entrepreneur", "company", "revenue",
                 "profit", "b2b"],
    "fashion": ["fashion", "style", "outfit", "clothing", "dress", "wear"],
    "food": ["food", "recipe", "cooking", "kitchen", "restaurant", "meal",
             "bake", "chef"],
    "travel": ["travel", "trip", "flight", "hotel", "tour", "vacation",
               "destination"],
    "fitness": ["fitness", "workout", "gym", "exercise", "muscle", "yoga",
                "training"],
    "education": ["education", "learn", "course", "study", "school", "exam",
                  "student", "tutorial"],
    "music": ["music", "song", "singer", "album", "concert", "playlist"],
    "gaming": ["gaming", "game", "gamer", "esports", "playstation", "xbox",
               "mobile game", "pubg"],
    "comedy": ["comedy", "funny", "humor", "joke", "meme", "laugh"],
    "beauty": ["beauty", "makeup", "skincare", "cosmetic", "serum", "glow"],
    "health": ["health", "mental health", "doctor", "nutrition", "wellness"],
    "finance": ["finance", "money", "invest", "stock", "crypto", "bank",
                "trading", "budget"],
    "sports": ["sports", "cricket", "football", "match", "player", "league"],
    "photography": ["photography", "photo", "camera", "lens", "portrait"],
    "art": ["art", "design", "painting", "illustration", "creative"],
    "motivation": ["motivation", "success", "mindset", "inspiration", "goals"],
    "parenting": ["parenting", "kids", "children", "mom", "dad", "baby"],
    "realestate": ["real estate", "property", "house", "plot", "apartment"],
    "automobiles": ["car", "bike", "automobile", "vehicle", "driving"],
    "pets": ["pet", "dog", "cat", "puppy", "kitten"],
    "news": ["news", "breaking", "update", "report", "election"],
    "lifestyle": ["lifestyle", "home", "decor", "minimalist", "routine"],
    "marketing": ["marketing", "brand", "ads", "seo", "social media",
                  "campaign"],
}


@lru_cache(maxsize=1)
def _reverse_topic_index() -> dict[str, str]:
    """Normalized localized topic label -> canonical slug."""
    index: dict[str, str] = {}
    for pack in supported_languages():
        for slug, name in pack.topic_names.items():
            key = _norm(name)
            if key and key not in index:
                index[key] = slug
        # English slug itself is always a valid label.
        for slug in TOPIC_SLUGS:
            index.setdefault(slug, slug)
    return index


def _norm(label: str) -> str:
    return re.sub(r"\s+", " ", (label or "").strip().lower())


def normalize_label_to_topic(label: str) -> str | None:
    """Map a topic label in any supported language to its concept slug."""
    return _reverse_topic_index().get(_norm(label))


def topic_name(slug: str, lang: str = "en") -> str:
    """Localized display name for a concept slug (falls back to slug)."""
    pack = get_pack(lang)
    if pack:
        return pack.topic_name(slug)
    return slug


def concept_ids_for_text(text: str) -> list[str]:
    """Find concept slugs mentioned in text, in ANY supported language.

    Matches localized topic names (word-boundary for spaced scripts).
    No translation involved — labels resolve directly to shared IDs.
    """
    low = (text or "").lower()
    found: list[str] = []
    for label, slug in _reverse_topic_index().items():
        if slug in found or len(label) < 2:
            continue
        if re.search(rf"(?<!\w){re.escape(label)}(?!\w)", low):
            found.append(slug)
        if len(found) >= 8:
            break
    # English keyword hints catch free text like "best pizza recipe".
    for slug, hints in TOPIC_KEYWORD_HINTS.items():
        if slug in found:
            continue
        for h in hints:
            if re.search(rf"(?<!\w){re.escape(h)}(?!\w)", low):
                found.append(slug)
                break
        if len(found) >= 8:
            break
    return found


def hashtag_to_concepts(hashtag: str) -> list[str]:
    """Interpret a hashtag (without #) as concept slugs.

    Tries: the raw tag, the tag with separators restored, localized topic
    labels, and English keyword hints. Never word-for-word translation.
    """
    tag = (hashtag or "").lstrip("#").strip()
    if not tag:
        return []
    found: list[str] = []
    variants = {tag, tag.replace("_", " "), tag.replace("-", " ")}
    for v in variants:
        slug = normalize_label_to_topic(v)
        if slug and slug not in found:
            found.append(slug)
    # Also catch multi-word labels containing the tag, e.g. #skincare.
    low = tag.lower()
    for label, slug in _reverse_topic_index().items():
        if slug not in found and low and low in label.replace(" ", ""):
            found.append(slug)
            if len(found) >= 4:
                break
    # English keyword hints: #skincare -> beauty, #pubg -> gaming.
    for slug, hints in TOPIC_KEYWORD_HINTS.items():
        if slug in found:
            continue
        if any(low == h or low in h.split() for h in hints):
            found.append(slug)
            if len(found) >= 4:
                break
    return found


# ---------------------------------------------------------------------------
# Embeddings
# ---------------------------------------------------------------------------

class MultilingualEmbedder(ABC):
    """Interface: embed text -> vector; cosine similarity between vectors."""

    name: str = "base"
    is_neural: bool = False

    @abstractmethod
    def embed(self, text: str, lang: str = "auto") -> list[float]:
        ...

    def similarity(self, a: list[float], b: list[float]) -> float:
        dot = sum(x * y for x, y in zip(a, b))
        na = math.sqrt(sum(x * x for x in a))
        nb = math.sqrt(sum(y * y for y in b))
        if na == 0 or nb == 0:
            return 0.0
        return max(-1.0, min(1.0, dot / (na * nb)))

    def describe(self) -> dict:
        return {"name": self.name, "is_neural": self.is_neural,
                "note": "heuristic concept vector — not a neural embedding"
                        if not self.is_neural else "neural multilingual model"}


class ConceptEmbedder(MultilingualEmbedder):
    """Deterministic heuristic: L2-normalized vector over the 24 concept
    slugs. A component is 1.0 when the text mentions that concept in any
    supported language, plus 0.5 per extra mention (capped).

    Transparent and reproducible. NOT a neural embedding and NOT a
    substitute for one — semantic nuance beyond the taxonomy is not
    captured. Labeled as heuristic everywhere it is surfaced.
    """

    name = "concept-heuristic-v1"
    is_neural = False

    def embed(self, text: str, lang: str = "auto") -> list[float]:
        concepts = set(concept_ids_for_text(text))
        vec = [1.0 if slug in concepts else 0.0 for slug in TOPIC_SLUGS]
        norm = math.sqrt(sum(v * v for v in vec))
        if norm == 0:
            return vec
        return [round(v / norm, 4) for v in vec]


class SentenceTransformerEmbedder(MultilingualEmbedder):
    """Neural backend: multilingual sentence-transformers model.

    Only instantiated when the library + model are actually available;
    otherwise :func:`get_embedder` falls back to :class:`ConceptEmbedder`.
    """

    name = "multilingual-neural"
    is_neural = True

    def __init__(self, model_name: str):
        from sentence_transformers import SentenceTransformer

        self._model = SentenceTransformer(model_name)
        self.model_name = model_name

    def embed(self, text: str, lang: str = "auto") -> list[float]:
        vec = self._model.encode((text or "")[:2000],
                                 normalize_embeddings=True)
        return [float(x) for x in vec]

    def describe(self) -> dict:
        return {"name": f"{self.name}:{self.model_name}", "is_neural": True}


def sentence_transformers_available() -> bool:
    try:
        import sentence_transformers  # noqa: F401

        return True
    except Exception:
        return False


@lru_cache(maxsize=1)
def get_embedder(model_name: str = "paraphrase-multilingual-MiniLM-L12-v2",
                 ) -> MultilingualEmbedder:
    """Preferred: neural multilingual model when installed; otherwise the
    documented heuristic. The active backend is always reported via
    describe() so callers never mistake heuristic output for neural."""
    if sentence_transformers_available():
        try:
            return SentenceTransformerEmbedder(model_name)
        except Exception:
            pass
    return ConceptEmbedder()


def embedder_status() -> dict:
    emb = get_embedder()
    return {
        **emb.describe(),
        "neural_available": sentence_transformers_available(),
        "pending": ("neural multilingual embeddings — install "
                    "sentence-transformers + download the model")
        if not emb.is_neural else None,
    }
