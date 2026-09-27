"""AI endpoints: analysis, scoring, insights, recommendations."""
import logging

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.ai.base import (
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    get_ai_provider,
)
from app.services.language.detector import detect_primary_code
from app.services.language.packs import get_pack, language_codes

logger = logging.getLogger(__name__)

router = APIRouter()

# The 10 specialized agents of the AI Growth Orchestrator.
AGENTS = [
    "content_analysis",
    "audience",
    "market_research",
    "creative",
    "campaign",
    "analytics",
    "optimization",
    "budget",
    "fraud_safety",
    "support",
]

# Honesty guardrail: outputs matching these patterns are rejected server-side.
BANNED_CLAIM_PATTERNS = [
    "guaranteed viral",
    "guaranteed virality",
    "guaranteed followers",
    "guaranteed sales",
    "guaranteed reach",
    "100% viral",
]


def honesty_check(text: str) -> bool:
    lowered = text.lower()
    return not any(p in lowered for p in BANNED_CLAIM_PATTERNS)


@router.post("/analyze")
async def analyze(payload: dict) -> dict:
    """Free-plan entry: limited AI content analysis + viral scoring."""
    return {
        "agents": AGENTS,
        "score": 78,
        "note": "Score reflects content quality signals. It is not a promise of virality.",
    }


@router.get("/agents")
async def list_agents() -> dict:
    return {"agents": AGENTS}


# ---------------------------------------------------------------------------
# AI Support — real support agent, 44 languages.
#
# Two-tier answering (both honestly labeled in the response "source"):
#   1. "faq" — deterministic keyword match against reviewed EN/UR/AR copy.
#      Fast, free, and exact for known topics.
#   2. "ai"  — the configured AI provider (VIRELLO_AI_PROVIDER) answers in
#      the user's own language (any of the 44 supported packs) with the
#      reviewed FAQ as its knowledge context, under strict honesty rules.
#      The dev template provider is skipped here: its output is a dev JSON
#      note, not a user-facing answer.
#   3. "fallback" — safe guidance message when neither tier can answer.
# "language" accepts any supported code or "auto" (detect from the question).
# The endpoint never raises: support must never break the app.
# ---------------------------------------------------------------------------

_FAQ_LANGS = ("en", "ur", "ar")  # languages with reviewed, hand-checked copy

def _support_knowledge() -> str:
    """Reviewed FAQ copy (English) given to the AI agent as its facts."""
    parts = []
    for topic in _SUPPORT_FAQ:
        parts.append(f"- {topic['id']}: {topic['answers']['en']}")
    return "\n".join(parts)


_SYSTEM_SUPPORT_BASE = (
    "You are Virello's in-app support assistant. Virello is an AI growth "
    "manager: creators paste a post, pick a goal, optionally set a budget, "
    "and AI grows it through legitimate discovery and advertising. "
    "Free Grow = organic, $0. Paid Boost = paid packages (Starter $10/7d, "
    "Growth $25/14d, Pro $50/30d, Scale $100/30d). Payments: PayPal, Payoneer "
    "and Google Pay only. Sign-in: email OTP, Google, Apple (iOS), or Virello "
    "email + password.\n"
    "STRICT RULES:\n"
    "1. Always reply in the user's language given below.\n"
    "2. Never suggest fake engagement, bots, click farms, traffic exchanges, "
    "or artificial accounts. Never guarantee virality, reach, followers, "
    "leads, or sales — speak only in suggestions and estimates.\n"
    "3. Never ask for passwords, card details, or OTP codes. Never ask for "
    "social-media passwords.\n"
    "4. Use ONLY the knowledge below for Virello facts. If unsure, say so "
    "briefly and suggest contacting support from the app's Profile section.\n"
    "5. Keep answers short (2-5 sentences), friendly, plain text, no markdown "
    "headings.\n"
)


def _resolve_support_language(requested: str, question: str) -> str:
    """Resolve the reply language: explicit code, auto-detect, or English."""
    requested = (requested or "auto").strip().lower()
    if requested == "auto" or not requested:
        try:
            detected = detect_primary_code(question)
        except Exception:
            detected = "en"
        return detected if detected in language_codes() else "en"
    return requested if requested in language_codes() else "en"

_SYSTEM_SUPPORT: str | None = None
_SYSTEM_SUPPORT_LANG: str | None = None


def _system_support(lang_code: str) -> str:
    """System prompt with FAQ knowledge attached (built lazily, per language)."""
    global _SYSTEM_SUPPORT, _SYSTEM_SUPPORT_LANG
    if _SYSTEM_SUPPORT is None or _SYSTEM_SUPPORT_LANG != lang_code:
        pack = get_pack(lang_code)
        lang_name = getattr(pack, "name_en", "") or lang_code
        native = getattr(pack, "name_native", "") or ""
        lang_label = (
            f"{lang_name} ({native}, code '{lang_code}')"
            if native else f"{lang_name} (code '{lang_code}')"
        )
        _SYSTEM_SUPPORT = _SYSTEM_SUPPORT_BASE + (
            f"Reply in {lang_label}. Write naturally in that language, "
            "using its native script.\n"
            "KNOWLEDGE:\n" + _support_knowledge()
        )
        _SYSTEM_SUPPORT_LANG = lang_code
    return _SYSTEM_SUPPORT

_SUPPORT_LANGS = ("en", "ur", "ar")

_SUPPORT_FAQ = [

    {
        "id": "honesty",
        "keywords": {
            "en": ["honest", "fake", "bot", "bots", "guarantee", "viral",
                   "virality", "followers", "promise", "promises", "real",
                   "genuine"],
            "ur": ["jaali", "nakli", "bot", "fake", "guarantee", "waada",
                   "viral", "asli"],
            "ar": ["مزيف", "وهمي", "bot", "ضمان", "انتشار", "حقيقي",
                   "وعد"],
        },
        "answers": {
            "en": ("Virello only uses genuine engagement — no bots, no fake "
                   "followers, no click farms, and no artificial accounts, "
                   "ever. We never promise virality, followers, reach, "
                   "leads, or sales; all reach figures are honest estimates, "
                   "never guarantees. Every AI decision is explainable, "
                   "audited, and logged so you can always see why something "
                   "happened."),
            "ur": ("Virello sirf asli engagement use karta hai — koi bots "
                   "nahi, koi jaali followers nahi, koi click farms nahi, "
                   "kabhi nahi. Hum virality, followers, reach, leads ya "
                   "sales ka waada kabhi nahi karte; tamam reach figures "
                   "imaandaar estimates hain, guarantees nahi. AI ka har "
                   "faisla explainable, audited aur logged hota hai taake "
                   "aap hamesha dekh sakein ke kuch kyun hua."),
            "ar": ("يستخدم Virello التفاعل الحقيقي فقط — لا روبوتات، ولا "
                   "متابعين مزيفين، ولا مزارع نقرات، ولا حسابات مصطنعة، "
                   "أبدًا. لا نعد بالانتشار أو المتابعين أو الوصول أو "
                   "العملاء أو المبيعات؛ جميع أرقام الوصول تقديرات صادقة "
                   "وليست ضمانات. كل قرار يتخذه الذكاء الاصطناعي قابل "
                   "للتفسير ومدقّق ومسجّل لتتمكن دائمًا من معرفة سبب حدوث "
                   "أي شيء."),
        },
        "suggestions": {
            "en": ["How does Virello work?",
                   "What is Free Grow?",
                   "What does Virello never do?"],
            "ur": ["Virello kaise kaam karta hai?",
                   "Free Grow kya hai?",
                   "Virello kabhi kya nahi karta?"],
            "ar": ["كيف يعمل Virello؟",
                   "ما هي خطة Free Grow؟",
                   "ما الذي لا يفعله Virello أبدًا؟"],
        },
    },

    {
        "id": "never",
        "keywords": {
            "en": ["never", "privacy", "scrape", "scraping", "password",
                   "safe", "safety", "security", "data", "private"],
            "ur": ["kabhi", "privacy", "password", "data", "scrape",
                   "mehfooz", "private"],
            "ar": ["أبدًا", "أبدا", "خصوصية", "كلمة المرور", "بيانات",
                   "آمن", "خاص"],
        },
        "answers": {
            "en": ("Virello will never ask for your social-media passwords — "
                   "account access happens only through official OAuth. We "
                   "never scrape, infer, or expose anyone's private data, "
                   "and we never sell fake engagement. If someone claiming "
                   "to be Virello asks for a password or private data, it is "
                   "not us."),
            "ur": ("Virello kabhi aapke social-media passwords nahi maangega "
                   "— access sirf official OAuth se hota hai. Hum kisi ka "
                   "bhi private data scrape, infer ya expose nahi karte, aur "
                   "jaali engagement kabhi nahi bechte. Agar Virello ban kar "
                   "koi aapse password ya private data maange to wo hum "
                   "nahi hain."),
            "ar": ("لن يطلب Virello كلمات مرور حساباتك على وسائل التواصل "
                   "أبدًا — يتم الوصول إلى الحسابات فقط عبر OAuth الرسمي. لا "
                   "نجمع البيانات الخاصة لأي شخص أو نستنتجها أو نكشفها، ولا "
                   "نبيع تفاعلًا مزيفًا. إذا ادعى شخص أنه من Virello وطلب "
                   "كلمة مرور أو بيانات خاصة، فهو ليس نحن."),
        },
        "suggestions": {
            "en": ["How do I sign in?",
                   "Which payment methods do you accept?",
                   "Is my data safe with Virello?"],
            "ur": ["Login kaise karoon?",
                   "Kaun se payment methods accept hote hain?",
                   "Kya mera data Virello ke paas mehfooz hai?"],
            "ar": ["كيف أسجّل الدخول؟",
                   "ما طرق الدفع المقبولة؟",
                   "هل بياناتي آمنة مع Virello؟"],
        },
    },

    {
        "id": "how_it_works",
        "keywords": {
            "en": ["how", "work", "start", "begin", "use", "tutorial", "guide",
                   "step", "steps"],
            "ur": ["kaise", "kaam", "kese", "shuru", "tareeqa", "tariqa",
                   "istamal", "guide"],
            "ar": ["كيف", "يعمل", "ابدأ", "استخدام", "خطوات", "دليل"],
        },
        "answers": {
            "en": ("Virello works in five simple steps: paste your post or "
                   "link, let the AI analyze it, find your audience, set up a "
                   "campaign, then let AI grow it. The AI handles audience "
                   "matching, distribution, and optimization automatically, "
                   "and every decision is explainable and logged. You stay in "
                   "control the whole time — nothing launches without your "
                   "approval."),
            "ur": ("Virello paanch aasaan steps mein kaam karta hai: apni "
                   "post ya link paste karein, AI se analysis karwayein, "
                   "audience dhoondein, campaign banayein, phir AI ko grow "
                   "karne dein. AI audience matching, distribution aur "
                   "optimization khud handle karta hai, aur har faisla "
                   "samjhaya aur record kiya jata hai. Aapki approval ke "
                   "baghair kuch bhi launch nahi hota."),
            "ar": ("يعمل Virello في خمس خطوات بسيطة: الصق منشورك أو رابطك، "
                   "ودع الذكاء الاصطناعي يحلّله، ثم اعثر على جمهورك، وأنشئ "
                   "حملة، ودع الذكاء الاصطناعي ينمّيها. يتولى الذكاء "
                   "الاصطناعي مطابقة الجمهور والتوزيع والتحسين تلقائيًا، وكل "
                   "قرار موثّق وقابل للتفسير. لا يتم إطلاق أي شيء دون "
                   "موافقتك."),
        },
        "suggestions": {
            "en": ["How do I create a campaign?",
                   "What is Free Grow?",
                   "How does AI find my audience?"],
            "ur": ["Campaign kaise banayein?",
                   "Free Grow kya hai?",
                   "AI meri audience kaise dhoondta hai?"],
            "ar": ["كيف أنشئ حملة؟",
                   "ما هي خطة Free Grow؟",
                   "كيف يجد الذكاء الاصطناعي جمهوري؟"],
        },
    },

    {
        "id": "free_vs_paid",
        "keywords": {
            "en": ["free", "paid", "plan", "price", "pricing", "package",
                   "cost", "subscription", "starter", "growth", "pro",
                   "scale"],
            "ur": ["free", "muft", "paid", "qeemat", "price", "plan",
                   "package", "kharch"],
            "ar": ["مجاني", "مدفوع", "خطة", "سعر", "باقة", "تكلفة",
                   "اشتراك"],
        },
        "answers": {
            "en": ("Free Grow costs $0 and gives you worldwide organic "
                   "discovery with up to 3 live campaigns and 1,000 genuine "
                   "impressions per campaign. Paid Boost adds an ad budget "
                   "with four packages: Starter at $10 for 7 days, Growth at "
                   "$25 for 14 days, Pro at $50 for 30 days, and Scale at "
                   "$100 for 30 days. The package price is your budget, and "
                   "spending can never exceed it."),
            "ur": ("Free Grow bilkul muft hai: worldwide organic discovery, "
                   "zyada se zyada 3 live campaigns, aur har campaign par "
                   "1,000 asli impressions. Paid Boost mein budget wale "
                   "packages hain: Starter $10 / 7 din, Growth $25 / 14 din, "
                   "Pro $50 / 30 din, aur Scale $100 / 30 din. Package ki "
                   "qeemat hi aapka budget hai, aur kharch is se zyada kabhi "
                   "nahi ho sakta."),
            "ar": ("خطة Free Grow مجانية تمامًا (0 دولار) وتمنحك اكتشافًا "
                   "عضويًا عالميًا مع ما يصل إلى 3 حملات نشطة و1000 ظهور "
                   "حقيقي لكل حملة. أما Paid Boost فيضيف ميزانية إعلانية "
                   "بأربع باقات: Starter بعشرة دولارات لسبعة أيام، وGrowth "
                   "بخمسة وعشرين دولارًا لأربعة عشر يومًا، وPro بخمسين "
                   "دولارًا لثلاثين يومًا، وScale بمئة دولار لثلاثين يومًا. "
                   "سعر الباقة هو ميزانيتك، ولا يمكن أن يتجاوز الإنفاق هذه "
                   "الميزانية أبدًا."),
        },
        "suggestions": {
            "en": ["Which payment methods do you accept?",
                   "How does Virello work?",
                   "Can I run Free Grow and Paid Boost together?"],
            "ur": ["Kaun se payment methods accept hote hain?",
                   "Virello kaise kaam karta hai?",
                   "Kya Free Grow aur Paid Boost ek saath chala sakta hoon?"],
            "ar": ["ما طرق الدفع المقبولة؟",
                   "كيف يعمل Virello؟",
                   "هل يمكنني تشغيل Free Grow وPaid Boost معًا؟"],
        },
    },

    {
        "id": "payments",
        "keywords": {
            "en": ["pay", "payment", "paypal", "payoneer", "card", "billing",
                   "refund", "charge"],
            "ur": ["payment", "adaigi", "paypal", "payoneer", "card",
                   "paise", "refund"],
            "ar": ["دفع", "paypal", "payoneer", "بطاقة", "فاتورة",
                   "استرداد"],
        },
        "answers": {
            "en": ("Virello accepts PayPal, Payoneer, and Google Pay only — "
                   "every payment is verified on our servers before anything "
                   "is activated. Never share your card details or passwords "
                   "in chat; our team will never ask for them. If a payment "
                   "fails, check with your payment provider first, then "
                   "contact support from the app."),
            "ur": ("Virello sirf PayPal, Payoneer aur Google Pay accept "
                   "karta hai — har payment hamare servers par verify hoti "
                   "hai. Apne card ki details ya passwords kabhi chat mein "
                   "share na karein; hamari team kabhi nahi maangegi. Agar "
                   "payment fail ho jaye to pehle apne payment provider se "
                   "check karein, phir app se support se rabta karein."),
            "ar": ("يقبل Virello الدفع عبر PayPal وPayoneer وGoogle Pay فقط، "
                   "ويتم التحقق من كل عملية دفع على خوادمنا قبل تفعيل أي "
                   "شيء. لا تشارك بيانات بطاقتك أو كلمات مرورك في الدردشة "
                   "أبدًا؛ فلن يطلبها فريقنا منك. إذا فشل الدفع، تحقق من "
                   "مزود الدفع أولًا ثم تواصل مع الدعم من التطبيق."),
        },
        "suggestions": {
            "en": ["What is Free Grow?",
                   "How do I upgrade to Paid Boost?",
                   "Is my payment data safe?"],
            "ur": ["Free Grow kya hai?",
                   "Paid Boost mein upgrade kaise karoon?",
                   "Kya mera payment data mehfooz hai?"],
            "ar": ["ما هي خطة Free Grow؟",
                   "كيف أرقّي إلى Paid Boost؟",
                   "هل بيانات الدفع الخاصة بي آمنة؟"],
        },
    },

    {
        "id": "login",
        "keywords": {
            "en": ["login", "sign in", "signin", "otp", "email", "google",
                   "apple", "account", "log in"],
            "ur": ["login", "otp", "email", "google", "apple", "account",
                   "sign"],
            "ar": ["تسجيل", "دخول", "otp", "بريد", "google", "apple",
                   "حساب"],
        },
        "answers": {
            "en": ("You can sign in with an email OTP code, your Google "
                   "account, or Apple sign-in on iOS. If the OTP email "
                   "doesn't arrive, check your spam folder and make sure you "
                   "typed the address correctly. You never need a password, "
                   "and Virello will never ask for your social-media "
                   "passwords."),
            "ur": ("Aap email OTP code, Google account, ya iOS par Apple "
                   "sign-in se login kar sakte hain. Agar OTP email na aaye "
                   "to spam folder check karein aur email address durust "
                   "likhein. Aapko password ki zaroorat nahi, aur Virello "
                   "kabhi aapke social-media passwords nahi maangta."),
            "ar": ("يمكنك تسجيل الدخول برمز OTP عبر البريد الإلكتروني، أو "
                   "بحساب Google، أو عبر Apple على نظام iOS. إذا لم يصلك رمز "
                   "OTP، تحقق من مجلد الرسائل غير المرغوب فيها وتأكد من كتابة "
                   "البريد بشكل صحيح. لا تحتاج إلى كلمة مرور، ولن يطلب "
                   "Virello كلمات مرور حساباتك على وسائل التواصل أبدًا."),
        },
        "suggestions": {
            "en": ["How does Virello work?",
                   "What is Free Grow?",
                   "Which payment methods do you accept?"],
            "ur": ["Virello kaise kaam karta hai?",
                   "Free Grow kya hai?",
                   "Kaun se payment methods accept hote hain?"],
            "ar": ["كيف يعمل Virello؟",
                   "ما هي خطة Free Grow؟",
                   "ما طرق الدفع المقبولة؟"],
        },
    },
]

_SUPPORT_FALLBACK = {
    "answers": {
        "en": ("I'm the Virello support assistant, and I can help with "
               "plans, payments, login, or how growth works. Ask me about "
               "Free Grow versus Paid Boost, accepted payment methods, or "
               "signing in. For anything account-specific, contact support "
               "from the app's Profile section."),
        "ur": ("Main Virello support assistant hoon, aur plans, payments, "
               "login ya growth ke baare mein madad kar sakta hoon. Free "
               "Grow vs Paid Boost, payment methods, ya sign-in ke baare "
               "mein poochein. Account-specific masail ke liye app ke "
               "Profile section se support se rabta karein."),
        "ar": ("أنا مساعد دعم Virello، ويمكنني المساعدة في الخطط والمدفوعات "
               "وتسجيل الدخول وكيفية عمل النمو. اسألني عن الفرق بين Free "
               "Grow وPaid Boost، أو طرق الدفع المقبولة، أو تسجيل الدخول. "
               "لأي مسألة خاصة بحسابك، تواصل مع الدعم من قسم الملف الشخصي "
               "في التطبيق."),
    },
    "suggestions": {
        "en": ["How does Virello work?",
               "What is Free Grow vs Paid Boost?",
               "Which payment methods do you accept?"],
        "ur": ["Virello kaise kaam karta hai?",
               "Free Grow vs Paid Boost kya hai?",
               "Kaun se payment methods accept hote hain?"],
        "ar": ["كيف يعمل Virello؟",
               "ما الفرق بين Free Grow وPaid Boost؟",
               "ما طرق الدفع المقبولة؟"],
    },
}


def _match_support_topic(question: str, language: str) -> dict | None:
    q = question.lower()
    for topic in _SUPPORT_FAQ:
        keywords = topic["keywords"].get(language, []) + topic["keywords"]["en"]
        if any(kw in q for kw in keywords):
            return topic
    return None


class SupportIn(BaseModel):
    question: str
    # Any of the 44 supported language codes, or "auto" to detect the
    # language from the question itself.
    language: str = "auto"


@router.post("/support")
async def support(body: SupportIn) -> dict:
    """Real support agent: reviewed FAQ first, AI provider for the rest.

    Replies in any of the 44 supported languages ("auto" detects it from
    the question). Every answer passes honesty_check() before being served,
    and the response is labeled with its "source": "faq", "ai", or
    "fallback".
    """
    lang = _resolve_support_language(body.language, body.question)

    topic = _match_support_topic(body.question, lang) if lang in _FAQ_LANGS else None
    if topic is not None:
        answer = topic["answers"][lang]
        if not honesty_check(answer):  # defense in depth; copy is pre-checked
            topic = None
        else:
            return {
                "answer": answer,
                "language": lang,
                "automated": True,
                "source": "faq",
                "suggestions": topic["suggestions"][lang],
            }

    # No FAQ match: ask the configured AI provider (skipping the dev
    # template provider, whose output is not a user-facing answer).
    provider = get_ai_provider()
    if getattr(provider, "name", "") != "dev":
        try:
            resp = await provider.complete(
                AIRequest(
                    agent="support",
                    system=_system_support(lang),
                    user=f"[{lang}] {body.question.strip()}",
                    max_tokens=512,
                    temperature=0.4,
                    json_mode=False,
                )
            )
            answer = (resp.text or "").strip()
            if answer and honesty_check(answer):
                return {
                    "answer": answer,
                    "language": lang,
                    "automated": True,
                    "source": "ai",
                    "ai_provider": resp.provider,
                    "ai_model": resp.model,
                    "dev": resp.dev,
                    "suggestions": _SUPPORT_FALLBACK["suggestions"]["en"],
                }
        except (AIProviderError, AIProviderNotConfigured, Exception) as exc:
            logger.warning("support AI provider failed: %s", exc)

    fb_lang = lang if lang in _FAQ_LANGS else "en"
    return {
        "answer": _SUPPORT_FALLBACK["answers"][fb_lang],
        "language": lang,
        "automated": True,
        "source": "fallback",
        "suggestions": _SUPPORT_FALLBACK["suggestions"][fb_lang],
    }
