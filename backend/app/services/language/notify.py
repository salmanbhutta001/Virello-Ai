"""Multilingual notification templates.

Renders event notifications in the recipient's preferred language.
Honesty rules:
- Only languages with a real template are rendered; anything else falls
  back to English AND the response flags ``fallback_used=True``.
- ``params`` are values (names, numbers) substituted in — never
  machine-translated prose. Meaning is never invented.
- This pass ships EN + UR fully and AR for core events; every other
  language honestly falls back until a native speaker provides text.

There is no push-delivery provider wired yet; these templates feed the
Broadcast store and any future delivery channel unchanged.
"""
from __future__ import annotations

from .packs import is_supported

DEFAULT_LANG = "en"

# event -> lang -> {title, body}. {placeholders} are runtime values only.
TEMPLATES: dict[str, dict[str, dict[str, str]]] = {
    "campaign_approved": {
        "en": {"title": "Campaign approved",
               "body": "Your campaign “{name}” was approved and is now "
                       "eligible for delivery within your approved budget."},
        "ur": {"title": "مہم منظور ہو گئی",
               "body": "آپ کی مہم ”{name}“ منظور ہو گئی ہے اور اب آپ کے "
                       "منظور شدہ بجٹ کے اندر ڈیلیوری کے لیے اہل ہے۔"},
        "ar": {"title": "تمت الموافقة على الحملة",
               "body": "تمت الموافقة على حملتك «{name}» وهي الآن مؤهلة "
                       "للعرض ضمن ميزانيتك المعتمدة."},
    },
    "campaign_rejected": {
        "en": {"title": "Campaign needs changes",
               "body": "Your campaign “{name}” was not approved: {reason} "
                       "You can edit and resubmit it anytime."},
        "ur": {"title": "مہم میں تبدیلی درکار ہے",
               "body": "آپ کی مہم ”{name}“ منظور نہیں ہوئی: {reason} آپ اس "
                       "میں ترمیم کر کے دوبارہ جمع کرا سکتے ہیں۔"},
    },
    "optimization_applied": {
        "en": {"title": "AI optimization applied",
               "body": "The AI growth agent adjusted “{name}”: {summary} "
                       "Every change is logged and reversible."},
        "ur": {"title": "AI اصلاح نافذ کر دی گئی",
               "body": "AI گروتھ ایجنٹ نے ”{name}“ میں تبدیلی کی: {summary} "
                       "ہر تبدیلی لاگ ہوتی ہے اور واپس لی جا سکتی ہے۔"},
    },
    "fraud_paused": {
        "en": {"title": "Campaign auto-paused for safety",
               "body": "“{name}” was paused after suspicious activity was "
                       "detected. No further spend will occur until you "
                       "review it."},
        "ur": {"title": "حفاظت کے لیے مہم خودکار طور پر روک دی گئی",
               "body": "مشکوک سرگرمی کی نشاندہی پر ”{name}“ روک دی گئی ہے۔ "
                       "آپ کے جائزے تک کوئی مزید خرچ نہیں ہوگا۔"},
    },
    "budget_low": {
        "en": {"title": "Campaign budget almost used",
               "body": "“{name}” has used {pct}% of its approved budget. "
                       "Delivery will stop at 100% — it can never overspend."},
        "ur": {"title": "مہم کا بجٹ ختم ہونے والا ہے",
               "body": "”{name}“ اپنا {pct}% منظور شدہ بجٹ استعمال کر چکی "
                       "ہے۔ 100% پر ڈیلیوری رک جائے گی — اس سے زیادہ خرچ "
                       "کبھی نہیں ہوگا۔"},
    },
    "weekly_summary": {
        "en": {"title": "Your weekly growth summary",
               "body": "{views} genuine views and {saves} saves across your "
                       "campaigns this week. Estimates are labeled; only "
                       "measured events are reported."},
        "ur": {"title": "آپ کی ہفتہ وار گروتھ سمری",
               "body": "اس ہفتے آپ کی مہمات پر {views} حقیقی ویوز اور "
                       "{saves} سیوز۔ تخمینے واضح طور پر لیبل کیے جاتے ہیں؛ "
                       "صرف ناپے گئے ایونٹس رپورٹ ہوتے ہیں۔"},
    },
    "credits_added": {
        "en": {"title": "Credits added",
               "body": "{amount} credits were added to your account. "
                       "Your new balance is {balance}."},
        "ur": {"title": "کریڈٹس شامل کر دیے گئے",
               "body": "آپ کے اکاؤنٹ میں {amount} کریڈٹس شامل کر دیے گئے "
                       "ہیں۔ آپ کا نیا بیلنس {balance} ہے۔"},
    },
    "welcome": {
        "en": {"title": "Welcome to Virello",
               "body": "Paste a post, choose a goal, set an optional "
                       "budget — and let the AI grow it. Legitimate reach "
                       "only: no bots, no fake engagement, ever."},
        "ur": {"title": "Virello میں خوش آمدید",
               "body": "پوسٹ پیسٹ کریں، ہدف منتخب کریں، اختیاری بجٹ مقرر "
                       "کریں — اور AI کو بڑھنے دیں۔ صرف جائز رسائی: نہ بوٹس، "
                       "نہ جعلی انگیجمنٹ، کبھی نہیں۔"},
        "ar": {"title": "مرحباً بك في Virello",
               "body": "الصق منشوراً، اختر هدفاً، حدد ميزانية اختيارية — "
                       "ودع الذكاء الاصطناعي ينمّيه. وصول شرعي فقط: لا روبوتات "
                       "ولا تفاعل مزيّف، أبداً."},
    },
}


def available_template_languages(event: str) -> list[str]:
    return [l for l in TEMPLATES.get(event, {})]


def render_notification(event: str, lang: str | None = None,
                        params: dict | None = None) -> dict:
    """Render {title, body} for an event in the requested language.

    Falls back to English with fallback_used=True when the language has
    no template. Raises KeyError for unknown events (programmer error,
    not user input).
    """
    if event not in TEMPLATES:
        raise KeyError(f"unknown notification event: {event}")
    params = params or {}
    want = (lang or DEFAULT_LANG).strip().lower()
    tpl = TEMPLATES[event].get(want)
    fallback_used = False
    language_used = want
    if tpl is None:
        # Try base language for variants (zh_Hant -> zh_Hans has none;
        # fall through to English honestly).
        tpl = TEMPLATES[event].get(DEFAULT_LANG)
        fallback_used = True
        language_used = DEFAULT_LANG
    title = tpl["title"]
    body = tpl["body"]
    for k, v in params.items():
        title = title.replace("{" + k + "}", str(v))
        body = body.replace("{" + k + "}", str(v))
    return {
        "event": event,
        "title": title,
        "body": body,
        "language_requested": want if is_supported(want) else want,
        "language_used": language_used,
        "fallback_used": fallback_used,
        "missing_translation": fallback_used,
    }


def localize_for_user(event: str, user, params: dict | None = None) -> dict:
    """Render for a user object honoring preferred_language."""
    lang = getattr(user, "preferred_language", None) or getattr(
        user, "locale", None) or DEFAULT_LANG
    return render_notification(event, lang, params)
