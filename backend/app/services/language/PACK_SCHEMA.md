# Language Pack Schema

A language pack is one YAML file: `packs/<iso_639_1>.yaml`.
Adding a language = adding one file. No code changes.

```yaml
iso_639_1: ur                 # required, short code (zh_Hans / zh_Hant for Chinese)
iso_639_3: urd                # optional ISO 639-3
name_en: Urdu                 # required, English name
name_native: اردو              # required, native name
scripts: [Arabic]             # required; Unicode script names from detector
rtl: true                     # required
regions: [PK, IN]             # optional ISO country hints
ui_status: full               # full | partial  (UI translation coverage)
pack_quality: curated         # curated | draft (draft = needs native-speaker review)
stopwords: [...]              # common function words (detection signal)
detection_keywords: [...]     # common words incl. greetings (detection signal)
topic_names:                  # required: ALL 24 canonical slugs ->
  technology: ٹیکنالوجی        #   localized display names. Slugs are the
  ...                         #   shared concept IDs; matching never translates.
transliteration_variants: [roman_urdu]  # optional, e.g. hinglish, arabizi
transliteration_keywords: [...]         # romanized words (Latin-script detection)
related_languages:            # optional: {code, reason} for audience expansion
  - {code: hi, reason: "shared everyday vocabulary"}
notes: "..."                  # optional free text
```

Conventions:
- `topic_names` MUST cover all 24 slugs: technology, business, fashion,
  food, travel, fitness, education, music, gaming, comedy, beauty, health,
  finance, sports, photography, art, motivation, parenting, realestate,
  automobiles, pets, news, lifestyle, marketing.
- Register programmatically with `add_language_pack(dict)` — it validates,
  writes the YAML, and reloads the registry.
- Detection keyword lists are signals, not translations: they help the
  detector; semantic matching always goes through concept slugs.
