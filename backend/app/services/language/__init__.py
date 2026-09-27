"""Virello multilingual language layer."""
from .detector import DetectionResult, detect, detect_primary_code
from .expansion import recommend_languages
from .notify import (TEMPLATES, available_template_languages,
                     localize_for_user, render_notification)
from .packs import (LanguagePack, add_language_pack, describe_languages,
                    get_pack, is_supported, language_codes, reload_packs,
                    supported_languages)
from .semantics import (ConceptEmbedder, MultilingualEmbedder,
                        TOPIC_KEYWORD_HINTS, concept_ids_for_text,
                        embedder_status, get_embedder, hashtag_to_concepts,
                        normalize_label_to_topic,
                        sentence_transformers_available, topic_name)

__all__ = [
    "DetectionResult", "detect", "detect_primary_code", "recommend_languages",
    "TEMPLATES", "available_template_languages", "localize_for_user",
    "render_notification",
    "LanguagePack", "add_language_pack", "describe_languages", "get_pack",
    "is_supported", "language_codes", "reload_packs", "supported_languages",
    "ConceptEmbedder", "MultilingualEmbedder", "TOPIC_KEYWORD_HINTS",
    "concept_ids_for_text",
    "embedder_status", "get_embedder", "hashtag_to_concepts",
    "normalize_label_to_topic", "sentence_transformers_available",
    "topic_name",
]
