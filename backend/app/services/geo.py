"""Audience geography: country list, region presets, AI suggestions.

Design rules (Virello legitimacy boundary):
- Geography is *declared or content-derived only*. We never infer a user's
  location from private signals. The AI suggestion below is built from the
  post's *language*, *topics/entities*, and the *declared* ``geography``
  field of matched audience segments — never from per-user data.
- Suggestions are explainable (every country carries a reason) and the
  advertiser always approves the final selection before any spend.
- Estimates that depend on geography are labeled as estimates, with the
  exact documented formula in ``campaign_builder.estimate_reach``.
"""
from __future__ import annotations

# ISO 3166-1 alpha-2, English short names. Used for validation and the
# country picker. (code, name_en)
COUNTRIES: list[tuple[str, str]] = [
    ("AF", "Afghanistan"), ("AL", "Albania"), ("DZ", "Algeria"),
    ("AD", "Andorra"), ("AO", "Angola"), ("AG", "Antigua and Barbuda"),
    ("AR", "Argentina"), ("AM", "Armenia"), ("AU", "Australia"),
    ("AT", "Austria"), ("AZ", "Azerbaijan"), ("BS", "Bahamas"),
    ("BH", "Bahrain"), ("BD", "Bangladesh"), ("BB", "Barbados"),
    ("BY", "Belarus"), ("BE", "Belgium"), ("BZ", "Belize"),
    ("BJ", "Benin"), ("BT", "Bhutan"), ("BO", "Bolivia"),
    ("BA", "Bosnia and Herzegovina"), ("BW", "Botswana"), ("BR", "Brazil"),
    ("BN", "Brunei"), ("BG", "Bulgaria"), ("BF", "Burkina Faso"),
    ("BI", "Burundi"), ("KH", "Cambodia"), ("CM", "Cameroon"),
    ("CA", "Canada"), ("CV", "Cabo Verde"), ("CF", "Central African Republic"),
    ("TD", "Chad"), ("CL", "Chile"), ("CN", "China"), ("CO", "Colombia"),
    ("KM", "Comoros"), ("CG", "Congo"), ("CD", "DR Congo"),
    ("CR", "Costa Rica"), ("CI", "Côte d'Ivoire"), ("HR", "Croatia"),
    ("CU", "Cuba"), ("CY", "Cyprus"), ("CZ", "Czechia"),
    ("DK", "Denmark"), ("DJ", "Djibouti"), ("DM", "Dominica"),
    ("DO", "Dominican Republic"), ("EC", "Ecuador"), ("EG", "Egypt"),
    ("SV", "El Salvador"), ("GQ", "Equatorial Guinea"), ("ER", "Eritrea"),
    ("EE", "Estonia"), ("SZ", "Eswatini"), ("ET", "Ethiopia"),
    ("FJ", "Fiji"), ("FI", "Finland"), ("FR", "France"), ("GA", "Gabon"),
    ("GM", "Gambia"), ("GE", "Georgia"), ("DE", "Germany"), ("GH", "Ghana"),
    ("GR", "Greece"), ("GD", "Grenada"), ("GT", "Guatemala"),
    ("GN", "Guinea"), ("GW", "Guinea-Bissau"), ("GY", "Guyana"),
    ("HT", "Haiti"), ("HN", "Honduras"), ("HU", "Hungary"),
    ("IS", "Iceland"), ("IN", "India"), ("ID", "Indonesia"),
    ("IR", "Iran"), ("IQ", "Iraq"), ("IE", "Ireland"), ("IL", "Israel"),
    ("IT", "Italy"), ("JM", "Jamaica"), ("JP", "Japan"), ("JO", "Jordan"),
    ("KZ", "Kazakhstan"), ("KE", "Kenya"), ("KI", "Kiribati"),
    ("KP", "North Korea"), ("KR", "South Korea"), ("KW", "Kuwait"),
    ("KG", "Kyrgyzstan"), ("LA", "Laos"), ("LV", "Latvia"),
    ("LB", "Lebanon"), ("LS", "Lesotho"), ("LR", "Liberia"),
    ("LY", "Libya"), ("LI", "Liechtenstein"), ("LT", "Lithuania"),
    ("LU", "Luxembourg"), ("MG", "Madagascar"), ("MW", "Malawi"),
    ("MY", "Malaysia"), ("MV", "Maldives"), ("ML", "Mali"),
    ("MT", "Malta"), ("MH", "Marshall Islands"), ("MR", "Mauritania"),
    ("MU", "Mauritius"), ("MX", "Mexico"), ("FM", "Micronesia"),
    ("MD", "Moldova"), ("MC", "Monaco"), ("MN", "Mongolia"),
    ("ME", "Montenegro"), ("MA", "Morocco"), ("MZ", "Mozambique"),
    ("MM", "Myanmar"), ("NA", "Namibia"), ("NR", "Nauru"),
    ("NP", "Nepal"), ("NL", "Netherlands"), ("NZ", "New Zealand"),
    ("NI", "Nicaragua"), ("NE", "Niger"), ("NG", "Nigeria"),
    ("MK", "North Macedonia"), ("NO", "Norway"), ("OM", "Oman"),
    ("PK", "Pakistan"), ("PW", "Palau"), ("PS", "Palestine"),
    ("PA", "Panama"), ("PG", "Papua New Guinea"), ("PY", "Paraguay"),
    ("PE", "Peru"), ("PH", "Philippines"), ("PL", "Poland"),
    ("PT", "Portugal"), ("QA", "Qatar"), ("RO", "Romania"),
    ("RU", "Russia"), ("RW", "Rwanda"), ("KN", "Saint Kitts and Nevis"),
    ("LC", "Saint Lucia"), ("VC", "Saint Vincent and the Grenadines"),
    ("WS", "Samoa"), ("SM", "San Marino"), ("ST", "São Tomé and Príncipe"),
    ("SA", "Saudi Arabia"), ("SN", "Senegal"), ("RS", "Serbia"),
    ("SC", "Seychelles"), ("SL", "Sierra Leone"), ("SG", "Singapore"),
    ("SK", "Slovakia"), ("SI", "Slovenia"), ("SB", "Solomon Islands"),
    ("SO", "Somalia"), ("ZA", "South Africa"), ("SS", "South Sudan"),
    ("ES", "Spain"), ("LK", "Sri Lanka"), ("SD", "Sudan"),
    ("SR", "Suriname"), ("SE", "Sweden"), ("CH", "Switzerland"),
    ("SY", "Syria"), ("TW", "Taiwan"), ("TJ", "Tajikistan"),
    ("TZ", "Tanzania"), ("TH", "Thailand"), ("TL", "Timor-Leste"),
    ("TG", "Togo"), ("TO", "Tonga"), ("TT", "Trinidad and Tobago"),
    ("TN", "Tunisia"), ("TR", "Türkiye"), ("TM", "Turkmenistan"),
    ("TV", "Tuvalu"), ("UG", "Uganda"), ("UA", "Ukraine"),
    ("AE", "United Arab Emirates"), ("GB", "United Kingdom"),
    ("US", "United States"), ("UY", "Uruguay"), ("UZ", "Uzbekistan"),
    ("VU", "Vanuatu"), ("VA", "Vatican City"), ("VE", "Venezuela"),
    ("VN", "Vietnam"), ("YE", "Yemen"), ("ZM", "Zambia"),
    ("ZW", "Zimbabwe"), ("HK", "Hong Kong"), ("MO", "Macao"),
    ("AX", "Åland Islands"), ("AS", "American Samoa"), ("AI", "Anguilla"),
    ("AQ", "Antarctica"), ("AW", "Aruba"), ("BM", "Bermuda"),
    ("BQ", "Bonaire"), ("BV", "Bouvet Island"),
    ("IO", "British Indian Ocean Territory"),
    ("VG", "British Virgin Islands"), ("CC", "Cocos Islands"),
    ("CK", "Cook Islands"), ("CW", "Curaçao"), ("FK", "Falkland Islands"),
    ("FO", "Faroe Islands"), ("GF", "French Guiana"),
    ("PF", "French Polynesia"), ("TF", "French Southern Territories"),
    ("GI", "Gibraltar"), ("GL", "Greenland"), ("GP", "Guadeloupe"),
    ("GU", "Guam"), ("GG", "Guernsey"), ("HM", "Heard Island"),
    ("IM", "Isle of Man"), ("JE", "Jersey"), ("KY", "Cayman Islands"),
    ("MP", "Northern Mariana Islands"), ("MQ", "Martinique"),
    ("YT", "Mayotte"), ("MS", "Montserrat"), ("NC", "New Caledonia"),
    ("NU", "Niue"), ("NF", "Norfolk Island"), ("PN", "Pitcairn Islands"),
    ("PR", "Puerto Rico"), ("RE", "Réunion"), ("BL", "Saint Barthélemy"),
    ("SH", "Saint Helena"), ("MF", "Saint Martin (French)"),
    ("PM", "Saint Pierre and Miquelon"), ("SX", "Sint Maarten (Dutch)"),
    ("GS", "South Georgia"), ("SJ", "Svalbard"), ("TK", "Tokelau"),
    ("TC", "Turks and Caicos"), ("VI", "U.S. Virgin Islands"),
    ("UM", "U.S. Minor Outlying Islands"), ("WF", "Wallis and Futuna"),
    ("EH", "Western Sahara"),
]

COUNTRY_CODES: frozenset[str] = frozenset(c for c, _ in COUNTRIES)
COUNTRY_NAMES: dict[str, str] = dict(COUNTRIES)

# Quick region presets for the campaign picker (keys are API-stable).
REGION_PRESETS: dict[str, dict] = {
    "usa_uk": {"name_en": "USA + UK", "countries": ["US", "GB"]},
    "north_america": {"name_en": "North America",
                      "countries": ["US", "CA", "MX"]},
    "gulf": {"name_en": "Gulf", "countries": ["SA", "AE", "QA", "KW", "BH", "OM"]},
    "mena": {"name_en": "Middle East & North Africa",
             "countries": ["SA", "AE", "QA", "KW", "BH", "OM", "EG", "JO",
                           "MA", "DZ", "TN", "IQ"]},
    "south_asia": {"name_en": "South Asia",
                   "countries": ["PK", "IN", "BD", "LK", "NP"]},
    "europe": {"name_en": "Europe",
               "countries": ["GB", "IE", "DE", "FR", "IT", "ES", "PT", "NL",
                             "BE", "CH", "AT", "SE", "NO", "DK", "FI", "PL"]},
    "southeast_asia": {"name_en": "Southeast Asia",
                       "countries": ["ID", "MY", "SG", "TH", "PH", "VN"]},
    "east_asia": {"name_en": "East Asia",
                  "countries": ["JP", "KR", "TW", "HK", "CN"]},
    "oceania": {"name_en": "Oceania", "countries": ["AU", "NZ"]},
    "latin_america": {"name_en": "Latin America",
                      "countries": ["BR", "MX", "AR", "CO", "CL", "PE"]},
    "africa": {"name_en": "Africa",
               "countries": ["NG", "ZA", "EG", "KE", "GH"]},
}

# Content language -> likely audience countries. Deterministic heuristic,
# documented as such: language alone never proves where a viewer lives,
# it only suggests where the language is widely used.
_LANGUAGE_GEO_HINTS: dict[str, list[tuple[str, str]]] = {
    "ur": [("PK", "Urdu is the national language of Pakistan"),
            ("IN", "Large Urdu-speaking audience in India")],
    "ar": [("SA", "Arabic content — Saudi Arabia is a major Arabic-speaking market"),
            ("AE", "Large Arabic-speaking audience in the UAE"),
            ("EG", "Egypt has the largest Arabic-speaking population")],
    "hi": [("IN", "Hindi is widely spoken across India")],
    "es": [("ES", "Spanish content — Spain"),
            ("MX", "Mexico has the largest Spanish-speaking population")],
    "en": [("US", "English content — United States is the largest English-speaking market"),
            ("GB", "United Kingdom is a major English-speaking market")],
    "fr": [("FR", "French content — France"),
            ("CA", "Large French-speaking audience in Canada")],
    "pt": [("BR", "Portuguese content — Brazil"),
            ("PT", "Portugal")],
    "de": [("DE", "German content — Germany")],
    "tr": [("TR", "Turkish content — Türkiye")],
    "fa": [("IR", "Persian content — Iran")],
    "bn": [("BD", "Bengali content — Bangladesh"),
            ("IN", "Large Bengali-speaking audience in India")],
    "pa": [("PK", "Punjabi is widely spoken in Pakistan"),
            ("IN", "Large Punjabi-speaking audience in India")],
    "id": [("ID", "Indonesian content — Indonesia")],
    "ms": [("MY", "Malay content — Malaysia")],
    "it": [("IT", "Italian content — Italy")],
    "ru": [("RU", "Russian content — Russia")],
    "ja": [("JP", "Japanese content — Japan")],
    "ko": [("KR", "Korean content — South Korea")],
    "zh": [("CN", "Chinese content — China"),
            ("TW", "Taiwan"), ("HK", "Hong Kong"), ("SG", "Singapore")],
    "nl": [("NL", "Dutch content — Netherlands")],
    "sv": [("SE", "Swedish content — Sweden")],
    "no": [("NO", "Norwegian content — Norway")],
    "da": [("DK", "Danish content — Denmark")],
    "fi": [("FI", "Finnish content — Finland")],
    "pl": [("PL", "Polish content — Poland")],
    "uk": [("UA", "Ukrainian content — Ukraine")],
    "vi": [("VN", "Vietnamese content — Vietnam")],
    "th": [("TH", "Thai content — Thailand")],
    "tl": [("PH", "Tagalog content — Philippines")],
    "fil": [("PH", "Filipino content — Philippines")],
}

GEO_MODES = ("ai_recommended", "worldwide", "custom")
MAX_CUSTOM_COUNTRIES = 50


def validate_countries(codes: list[str] | None) -> list[str]:
    """Normalize + validate ISO country codes. Raises ValueError."""
    if not codes:
        raise ValueError("Select at least one country.")
    seen: list[str] = []
    for raw in codes:
        code = str(raw or "").strip().upper()
        if not code:
            continue
        if code not in COUNTRY_CODES:
            raise ValueError(f"Unknown country code: {raw}.")
        if code not in seen:
            seen.append(code)
    if not seen:
        raise ValueError("Select at least one country.")
    if len(seen) > MAX_CUSTOM_COUNTRIES:
        raise ValueError(
            f"Too many countries (max {MAX_CUSTOM_COUNTRIES}).")
    return seen


def validate_geo_mode(mode: str | None) -> str:
    m = (mode or "ai_recommended").strip().lower()
    if m not in GEO_MODES:
        raise ValueError(
            f"geo_mode must be one of {', '.join(GEO_MODES)}.")
    return m


def suggest_geography(signals: dict, matches: list[dict],
                      max_countries: int = 6) -> dict:
    """Deterministic AI geography suggestion from content signals.

    Sources (all legitimate, explainable):
    1. content language(s) → widely-spoken countries (heuristic, labeled);
    2. matched segments' declared ``geography`` (never inferred per-user);
    3. topic entities naming a country are NOT auto-trusted (kept out —
       entity text is unreliable for geography).
    Returns {"countries": [...], "reasons": [...]}.
    """
    countries: list[str] = []
    reasons: list[str] = []

    langs: list[str] = []
    primary = (signals.get("language") or "").strip().lower()
    if primary and primary != "unknown":
        langs.append(primary)
    for alt in signals.get("languages") or []:
        a = str(alt).strip().lower()
        if a and a != "unknown" and a not in langs:
            langs.append(a)

    for lang in langs[:2]:
        for code, why in _LANGUAGE_GEO_HINTS.get(lang, [])[:3]:
            if code not in countries and len(countries) < max_countries:
                countries.append(code)
                reasons.append(f"{COUNTRY_NAMES[code]}: {why}.")

    for m in matches[:5]:
        geo = str(m.get("geography") or "").strip().upper()
        name = m.get("name", "segment")
        if geo and geo in COUNTRY_CODES and geo not in countries \
                and len(countries) < max_countries:
            countries.append(geo)
            reasons.append(
                f"{COUNTRY_NAMES[geo]}: matched audience segment "
                f"“{name}” is focused there.")

    if not countries:
        # No signal at all — say so honestly instead of inventing one.
        return {"countries": [], "reasons": [
            "No language or segment geography signal was strong enough to "
            "suggest specific countries — worldwide delivery is the honest "
            "default for this post."]}
    return {"countries": countries, "reasons": reasons}


def countries_payload() -> dict:
    """Public picker payload: full country list + region presets."""
    return {
        "countries": [{"code": c, "name_en": n} for c, n in COUNTRIES],
        "region_presets": {
            key: {"name_en": p["name_en"], "countries": list(p["countries"])}
            for key, p in REGION_PRESETS.items()
        },
    }


# ---------------------------------------------------------------- geo engine
# The geo-aware AI agent engine resolves every campaign to an *effective
# country set* and delivers only into it. Geography is always declared or
# content-derived (post language, matched segments' declared geography) —
# per-user location is never inferred, never stored, never used.

def resolve_effective_countries(geo_mode: str | None,
                                geo_countries: list[str] | None = None,
                                suggested_geography: dict | None = None,
                                signals: dict | None = None,
                                matches: list[dict] | None = None) -> dict:
    """Resolve a campaign's geography to an effective country set.

    - ``ai_recommended`` → the stored ``suggested_geography`` countries;
      when nothing was stored yet, the deterministic AI suggestion is
      computed from ``signals``/``matches`` as a fallback.
    - ``worldwide`` → all countries (no filtering).
    - ``custom`` → the advertiser-approved ``geo_countries`` (validated;
      unknown codes raise ValueError).

    When ai_recommended yields no confident country at all, worldwide is
    the honest default (said explicitly in the reasons).

    Returns {"mode", "countries", "worldwide", "reasons"}.
    """
    mode = validate_geo_mode(geo_mode)
    if mode == "worldwide":
        return {
            "mode": mode,
            "countries": sorted(COUNTRY_CODES),
            "worldwide": True,
            "reasons": ["Worldwide delivery — all countries are eligible."],
        }
    if mode == "custom":
        countries = validate_countries(list(geo_countries or []))
        names = ", ".join(COUNTRY_NAMES[c] for c in countries)
        return {
            "mode": mode,
            "countries": countries,
            "worldwide": False,
            "reasons": [f"Advertiser-approved country selection: {names}."],
        }
    # ai_recommended
    stored = suggested_geography or {}
    countries = [str(c).upper() for c in (stored.get("countries") or [])
                 if str(c).upper() in COUNTRY_CODES]
    reasons = list(stored.get("reasons") or [])
    if not countries and (signals or matches):
        fallback = suggest_geography(signals or {}, matches or [])
        countries = list(fallback["countries"])
        reasons = list(fallback["reasons"])
    if not countries:
        return {
            "mode": "worldwide",
            "countries": sorted(COUNTRY_CODES),
            "worldwide": True,
            "reasons": ["AI found no confident geography signal for this "
                        "post, so worldwide delivery is the honest default — "
                        "no countries were invented."],
        }
    return {"mode": mode, "countries": countries, "worldwide": False,
            "reasons": reasons}


def geo_targeting_summary(geo_mode: str | None,
                          geo_countries: list[str] | None,
                          lang: str = "en", max_shown: int = 2) -> str:
    """One-line targeting label, e.g. 'Targeting: Pakistan, UAE +3 more'.

    ``lang`` = "en" | "ur". Country names stay in English (ISO short names);
    only the template is localized.
    """
    mode = (geo_mode or "").strip().lower()
    codes = [c for c in (geo_countries or []) if c]
    template = "Targeting: {}" if lang != "ur" else "ہدف بندی: {}"
    everywhere = "Worldwide" if lang != "ur" else "دنیا بھر"
    if mode == "worldwide" or not codes:
        return template.format(everywhere)
    names = [COUNTRY_NAMES.get(str(c).upper(), str(c)) for c in codes]
    shown = names[:max_shown]
    rest = len(names) - len(shown)
    label = ", ".join(shown)
    if rest > 0:
        label += f" +{rest} more" if lang != "ur" else f" +{rest} مزید"
    return template.format(label)


def geo_context(campaign) -> dict:
    """Defensive audit/display block for a campaign's geography.

    Never raises: a corrupt stored selection is reported as geo_error so
    the audit trail records the problem instead of crashing the agent.
    """
    try:
        res = resolve_effective_countries(
            getattr(campaign, "geo_mode", None),
            list(getattr(campaign, "geo_countries", None) or []),
            getattr(campaign, "suggested_geography", None) or {})
        return {
            "geo_mode": res["mode"],
            "geo_worldwide": res["worldwide"],
            "geo_countries": ([] if res["worldwide"]
                              else list(res["countries"])),
            "geo_summary": geo_targeting_summary(
                res["mode"], res["countries"]),
            "geo_summary_ur": geo_targeting_summary(
                res["mode"], res["countries"], lang="ur"),
            "geo_reasons": list(res["reasons"])[:6],
        }
    except ValueError as exc:
        return {
            "geo_mode": getattr(campaign, "geo_mode", None),
            "geo_worldwide": False,
            "geo_countries": [],
            "geo_summary": "Targeting: Worldwide",
            "geo_summary_ur": "ہدف بندی: دنیا بھر",
            "geo_reasons": [],
            "geo_error": str(exc),
        }
