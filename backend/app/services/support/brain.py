"""Live Chat Support brain — deterministic, self-contained.

HARD RULE: this module must NEVER call the Muse agent, any external AI
provider, or any external runtime. Every answer comes from the reviewed
knowledge base below plus real server-side tool results (plan, campaigns,
support tickets). Deterministic word-token keyword classification only —
the same approach as app/services/ai_core/router.py.

Intents map to reviewed copy in EN/UR/AR. Anything unknown gets an honest
"I don't have that answer yet" fallback plus a ticket offer. Facts are
never invented.
"""
from __future__ import annotations

import logging
import re
import uuid

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Intent vocabulary
# ---------------------------------------------------------------------------
GREETING = "greeting"
HOW_IT_WORKS = "how_it_works"
FREE_GROW = "free_grow"
PAID_BOOST = "paid_boost"
PACKAGES_PRICING = "packages_pricing"
BILLING_GOOGLE_PLAY = "billing_google_play"
PAYMENT_SAFETY = "payment_safety"
CREDITS = "credits"
REFUNDS = "refunds"
LOGIN_OTP = "login_otp"
LOGIN_PASSWORD = "login_password"
LOGIN_GOOGLE_APPLE = "login_google_apple"
PLANS_COMPARE = "plans_compare"
FEATURES_HOME = "features_home"
FEATURES_DISCOVER = "features_discover"
FEATURES_CREATE = "features_create"
FEATURES_GROW = "features_grow"
FEATURES_SHOP = "features_shop"
FEATURES_ACADEMY = "features_academy"
TROUBLESHOOTING_CRASH = "troubleshooting_crash"
TROUBLESHOOTING_LOGIN = "troubleshooting_login"
ACCOUNT_DELETE = "account_delete"
AFFILIATE_DISCLOSURE = "affiliate_disclosure"
ORDER_STATUS = "order_status"
HUMAN_AGENT = "human_agent"
CONTACT = "contact"
HONESTY_POLICY = "honesty_policy"
LANGUAGE_CHANGE = "language_change"
UNKNOWN = "unknown"

INTENTS = (
    GREETING,
    HOW_IT_WORKS,
    FREE_GROW,
    PAID_BOOST,
    PACKAGES_PRICING,
    BILLING_GOOGLE_PLAY,
    PAYMENT_SAFETY,
    CREDITS,
    REFUNDS,
    LOGIN_OTP,
    LOGIN_PASSWORD,
    LOGIN_GOOGLE_APPLE,
    PLANS_COMPARE,
    FEATURES_HOME,
    FEATURES_DISCOVER,
    FEATURES_CREATE,
    FEATURES_GROW,
    FEATURES_SHOP,
    FEATURES_ACADEMY,
    TROUBLESHOOTING_CRASH,
    TROUBLESHOOTING_LOGIN,
    ACCOUNT_DELETE,
    AFFILIATE_DISCLOSURE,
    ORDER_STATUS,
    HUMAN_AGENT,
    CONTACT,
    HONESTY_POLICY,
    LANGUAGE_CHANGE,
    UNKNOWN,
)

METHOD = "support-keyword-v1"

# Languages with reviewed, hand-checked copy. Everything else → English.
LANGS = ("en", "ur", "ar")

CONFIDENCE_THRESHOLD = 0.45

# ---------------------------------------------------------------------------
# Tokenizer — mirror of app/services/ai_core/router.py (unicode-aware,
# keeps Arabic script).
# ---------------------------------------------------------------------------
_WORD_RE = re.compile(r"[^\w\u0600-\u06FF]+", re.UNICODE)
_AR_PUNCT_RE = re.compile(r"[؟،؛«»…—–]")


def _tokens(text: str) -> set[str]:
    """Word tokens (unicode-aware, keeps Arabic script).

    Mirrors app/services/ai_core/router.py, plus splits Arabic
    punctuation (؟ ، ؛) so "الباقات؟" tokenizes as "الباقات".
    """
    text = _AR_PUNCT_RE.sub(" ", (text or "").lower())
    return {t for t in _WORD_RE.split(text) if t}


# ---------------------------------------------------------------------------
# Keyword sets per intent per language (EN + Roman Urdu + Urdu script + AR).
# Matched against word tokens; multi-word phrases matched as substrings.
# ---------------------------------------------------------------------------
_KEYWORDS: dict[str, dict[str, tuple[str, ...]]] = {
    GREETING: {
        "en": ("hello", "hi", "hey", "salam", "salaam", "greetings",
               "good morning", "good evening", "good afternoon", "assalamualaikum"),
        "ur": ("salam", "salaam", "assalamualaikum", "hello", "hi",
               "kaise ho", "kia haal", "سلام", "السلام علیکم"),
        "ar": ("مرحبا", "اهلا", "السلام عليكم", "صباح الخير", "مساء الخير"),
    },
    HOW_IT_WORKS: {
        "en": ("how does", "how it works", "how to", "work", "working",
               "explain", "what is virello", "what's virello", "about virello",
               "guide", "tutorial", "start"),
        "ur": ("kaise kaam", "kam karta", "kaam karta", "samjhao", "samjhain",
               "kya hai", "کیسے کام", "کام کرتا", "سمجھائیں", "کیا ہے",
               "shuru", "shuru karoon", "shuru karun", "start karoon",
               "kaise shuru"),
        "ar": ("كيف يعمل", "اشرح", "ما هو", "شرح", "دليل"),
    },
    FREE_GROW: {
        "en": ("free grow", "free plan", "free tier", "free version", "free",
               "organic", "muft", "no cost", "zero cost"),
        "ur": ("free", "muft", "مفت", "muft wala", "bina paisay", "بغیر پیسے"),
        "ar": ("مجاني", "مجانية", "خطة مجانية", "بدون مقابل"),
    },
    PAID_BOOST: {
        "en": ("paid boost", "paid", "boost", "advertise", "advertising",
               "ads", "sponsored", "promotion", "promote", "upgrade"),
        "ur": ("paid", "boost", "advertise", "پیسے والا", "اشتہار"),
        "ar": ("مدفوع", "إعلان", "حملة مدفوعة", "ترقية"),
    },
    PACKAGES_PRICING: {
        "en": ("package", "packages", "pricing", "price", "prices", "cost",
               "how much", "starter", "growth", "scale", "$10", "$25", "$50",
               "$100", "plans"),
        "ur": ("package", "packages", "qeemat", "قیمت", "kitne ka",
               "kitne ke", "daam", "دام"),
        "ar": ("باقة", "باقات", "سعر", "أسعار", "تكلفة", "كم سعر"),
    },
    BILLING_GOOGLE_PLAY: {
        "en": ("billing", "google play", "play store", "playstore", "pay",
               "payment", "payments", "purchase", "buy", "bought",
               "subscription", "subscribe", "charged", "charge", "invoice",
               "receipt"),
        "ur": ("payment", "billing", "google play", "adaigi", "ادائیگی",
               "paisay katay", "پیسے کٹے", "subscribe", "سبسکرائب"),
        "ar": ("دفع", "الدفع", "فاتورة", "اشتراك", "شراء", "إيصال", "خصم",
               "أدفع", "ادفع"),
    },
    PAYMENT_SAFETY: {
        # Safety words + payment+safety combos so "Is my payment safe?"
        # beats BILLING_GOOGLE_PLAY outright instead of tying on "payment".
        "en": ("safe", "safety", "secure", "security", "protected",
               "protection", "payment safe", "payments safe",
               "is my payment", "is it safe", "safe to pay",
               "secure payment", "payment secure", "payment security"),
        "ur": ("mehfooz", "محفوظ", "mehfooz hai", "payment mehfooz",
               "ادائیگی محفوظ", "safe"),
        "ar": ("آمن", "آمنة", "أمان", "حماية", "الدفع آمن", "دفع آمن"),
    },
    CREDITS: {
        "en": ("credit", "credits", "coins", "balance", "top up", "topup",
               "recharge", "my balance"),
        "ur": ("credit", "credits", "کریڈٹ", "balance", "بیلنس"),
        "ar": ("رصيد", "نقاط", "ائتمان", "شحن"),
    },
    REFUNDS: {
        "en": ("refund", "refunds", "chargeback", "money back", "return",
               "returned", "cancel payment"),
        "ur": ("refund", "paisa wapas", "پیسہ واپس", "رقم کی واپسی", "واپس"),
        "ar": ("استرداد", "استرجاع", "إعادة المبلغ"),
    },
    LOGIN_OTP: {
        "en": ("otp", "one time", "verification code", "email code",
               "didn't receive", "did not receive", "no code", "code not",
               "resend", "didn't get", "did not get", "didn't get the code",
               "did not get the code", "haven't received",
               "never received"),
        "ur": ("otp", "code", "کوڈ", "nahi aaya", "نہیں آیا", "dobara bhejo",
               "دوبارہ بھیجو"),
        "ar": ("رمز", "تحقق", "كود", "لم يصلني", "إعادة إرسال"),
    },
    LOGIN_PASSWORD: {
        "en": ("password", "forgot", "reset", "change password",
               "bhool", "locked out", "wrong password"),
        "ur": ("password", "پاسورڈ", "bhool gaya", "بھول گیا", "reset karo",
               "ری سیٹ"),
        "ar": ("كلمة المرور", "نسيت", "إعادة تعيين", "تغيير كلمة المرور"),
    },
    LOGIN_GOOGLE_APPLE: {
        "en": ("google", "apple", "sign in with", "oauth", "social login",
               "gmail", "log in with google", "login with google",
               "log in with apple", "login with apple"),
        "ur": ("google", "apple", "گوگل", "ایپل"),
        "ar": ("google", "apple", "جوجل", "أبل", "تسجيل الدخول عبر"),
    },
    PLANS_COMPARE: {
        "en": ("compare", "vs", "versus", "difference", "differences",
               "which plan", "best plan", "free vs", "which is better"),
        "ur": ("compare", "farq", "فرق", "kaun sa", "کون سا", "behtar",
               "بہتر"),
        "ar": ("قارن", "فرق", "أيهما", "أفضل خطة", "الفرق بين"),
    },
    FEATURES_HOME: {
        "en": ("home", "homepage", "home screen", "home tab", "main screen"),
        "ur": ("home", "ہوم", "home screen", "ہوم اسکرین"),
        "ar": ("الرئيسية", "الشاشة الرئيسية", "الصفحة الرئيسية"),
    },
    FEATURES_DISCOVER: {
        "en": ("discover", "trending", "explore", "feed", "for you",
               "trending tab"),
        "ur": ("discover", "trending", "ٹریڈنگ", "ٹرینڈنگ", "explore",
               "ایکسپلور"),
        "ar": ("اكتشف", "رائج", "استكشاف", "الخلاصة"),
    },
    FEATURES_CREATE: {
        "en": ("create", "editor", "teleprompter", "template", "templates",
               "video tools", "edit video", "make video"),
        "ur": ("create", "video banao", "ویڈیو", "اسکرپٹ", "template",
               "ٹیمپلیٹ"),
        "ar": ("إنشاء", "فيديو", "سكربت", "قوالب", "تحرير"),
    },
    FEATURES_GROW: {
        "en": ("grow", "campaign", "campaigns", "audience", "viral lab",
               "analyze", "my campaign"),
        "ur": ("grow", "campaign", "مہم", "audience", "آڈینس", "meri campaign"),
        "ar": ("نمو", "حملة", "حملات", "جمهور", "حلل", "حملاتي", "عرض"),
    },
    FEATURES_SHOP: {
        "en": ("shop", "product", "products", "amazon", "buy", "order",
               "store", "shopping", "deal", "shop safe"),
        "ur": ("shop", "dukkan", "دکان", "kharido", "خریداری", "product",
               "پروڈکٹ", "shop mehfooz"),
        "ar": ("تسوق", "متجر", "أمازون", "منتج", "منتجات", "شراء",
               "ما هو المتجر", "متجر آمن"),
    },
    FEATURES_ACADEMY: {
        "en": ("academy", "lesson", "lessons", "learn", "course", "courses",
               "quiz", "study"),
        "ur": ("academy", "lesson", "سبق", "seekho", "سیکھو", "course",
               "کورس"),
        "ar": ("أكاديمية", "دروس", "درس", "تعلم", "دورة", "اختبار"),
    },
    TROUBLESHOOTING_CRASH: {
        "en": ("crash", "crashes", "crashed", "freeze", "freezes", "frozen",
               "not opening", "force close", "stuck", "bug", "error",
               "hangs", "slow", "won't open", "will not open",
               "doesn't open", "does not open", "can't open",
               "cannot open"),
        "ur": ("crash", "کریش", "khul nahi", "نہیں کھلتی", "band ho jata",
               "بند ہو جاتی", "atak", "اٹک", "error", "ایرر", "nahi khul",
               "nahin khul", "نہیں کھل"),
        "ar": ("تعطل", "يتعطل", "لا يفتح", "متجمد", "خطأ", "بطيء"),
    },
    TROUBLESHOOTING_LOGIN: {
        "en": ("can't login", "cannot login", "cant login", "login problem",
               "login issue", "signin issue", "stuck at login",
               "unable to login", "won't let me in", "can't log in",
               "cannot log in", "cant log in", "couldn't log in", "log in",
               "how do i log in", "how to log in", "how can i log in",
               "how to sign in", "how do i sign in"),
        "ur": ("login nahi", "لاگ ان", "login nahi ho raha",
               "لاگ ان نہیں ہو رہا", "andar nahi", "login kaise",
               "kaise login", "login kese", "kese login",
               "sign in kaise", "لاگ ان کیسے"),
        "ar": ("لا أستطيع الدخول", "مشكلة تسجيل الدخول", "تعذر الدخول",
               "كيف أسجل الدخول", "كيفية تسجيل الدخول", "كيف ادخل"),
    },
    ACCOUNT_DELETE: {
        "en": ("delete account", "delete my", "remove account", "deactivate",
               "close account", "erase data", "delete data"),
        "ur": ("account delete", "اکاؤنٹ", "delete karo", "ڈیلیٹ",
               "khatam karo", "ختم کرو"),
        "ar": ("حذف الحساب", "إغلاق الحساب", "حذف بياناتي", "إلغاء الحساب"),
    },
    AFFILIATE_DISCLOSURE: {
        "en": ("affiliate", "commission", "sponsored", "disclosure",
               "do you earn", "mushtahar"),
        "ur": ("affiliate", "commission", "کمیشن", "sponsored", "مشتہر"),
        "ar": ("عمولة", "إعلان مدعوم", "مشتہر", "رابط تابع", "روابط",
               "تابعة", "الروابط التابعة"),
    },
    ORDER_STATUS: {
        "en": ("order", "orders", "delivery", "delivered", "shipped",
               "shipping", "tracking", "arrived", "parcel", "package arrived"),
        "ur": ("order", "delivery", "ڈیلیوری", "parcel", "پارسل", "track karo",
               "ٹریک"),
        "ar": ("طلب", "شحن", "تتبع", "طرد", "وصل الطلب", "التوصيل"),
    },
    HUMAN_AGENT: {
        "en": ("human", "agent", "person", "real person", "talk to someone",
               "support team", "representative", "someone real", "staff"),
        "ur": ("insan", "insaan", "انسان", "banda", "بندہ", "numainda",
               "نمائندہ", "koi banda", "اصل بندہ"),
        "ar": ("إنسان", "موظف", "ممثل", "شخص حقيقي", "فريق الدعم",
               "التحدث مع شخص"),
    },
    CONTACT: {
        "en": ("contact", "email", "phone", "number", "whatsapp", "reach",
               "get in touch", "call", "support email"),
        "ur": ("contact", "rabta", "رابطہ", "email", "ای میل", "phone",
               "فون", "number", "نمبر"),
        "ar": ("اتصل", "تواصل", "بريد إلكتروني", "هاتف", "رقم", "واتساب"),
    },
    HONESTY_POLICY: {
        "en": ("honest", "honesty", "fake", "bots", "fake engagement",
               "guarantee", "guaranteed", "scam", "real or fake", "trust",
               "click farm", "traffic exchange"),
        "ur": ("fake", "جعلی", "bots", "بوٹس", "guarantee", "گارنٹی",
               "jhoota", "جھوٹا", "dhoka", "دھوکہ"),
        "ar": ("مزيف", "احتيال", "ضمان", "مضمون", "روبوتات", "حقيقي أم مزيف"),
    },
    LANGUAGE_CHANGE: {
        "en": ("language", "urdu", "arabic", "english", "change language",
               "switch language", "translate"),
        "ur": ("language", "zuban", "زبان", "urdu", "اردو", "arabic",
               "عربی", "english", "انگریزی"),
        "ar": ("لغة", "تغيير اللغة", "الأردية", "العربية", "الإنجليزية",
               "بالأردية", "بالعربية"),
    },
}


def _score_intent(tokens: set[str], lowered: str, intent: str,
                  language: str) -> int:
    """Keyword hits for one intent (word tokens + multi-word phrases).

    Arabic tokens also match with the definite article stripped, so
    "الباقات" matches the "باقات" keyword.
    """
    langs = _KEYWORDS.get(intent, {})
    kws = langs.get(language, ()) + langs.get("en", ())
    ext = set(tokens)
    for t in tokens:
        if t.startswith("ال") and len(t) > 3:
            ext.add(t[2:])
    hits = 0
    for kw in kws:
        if " " in kw:
            if kw in lowered:  # multi-word phrases: substring on lowered text
                hits += 1
        elif kw in ext:
            hits += 1
    return hits


def _confidence(hits: int) -> float:
    if hits <= 0:
        return 0.0
    return round(min(0.95, 0.45 + 0.15 * hits), 2)


# Pronoun / follow-up tokens: with prior history, these reuse the last
# assistant topic instead of classifying fresh.
_PRONOUNS = {
    "uski", "iska", "iske", "iski", "ise", "isay", "usko", "usne",
    "yeh", "ye", "woh", "wo", "us",
    "it", "its", "this", "that", "they", "them",
    "price", "prices", "qeemat",
    "اس", "اسکا", "اسکی", "اسے", "یہ", "وہ",
    "قیمت", "سعر",
}

# Explicit ticket-request phrases → auto-create a support ticket.
_TICKET_PHRASES = (
    "create ticket", "create a ticket", "open ticket", "open a ticket",
    "make a ticket", "make ticket", "raise ticket",
    "file a ticket", "ticket bana", "ticket banayein", "ticket banao",
    "ticket khol", "ticket kholo", "ticket create",
    "انشئ تذكرة", "إنشاء تذكرة", "تذكرة دعم",
)


def _wants_ticket(lowered: str) -> bool:
    return any(p in lowered for p in _TICKET_PHRASES)

# ---------------------------------------------------------------------------
# Reviewed knowledge base — hand-checked copy in EN/UR/AR.
#
# CORRECT FACTS ONLY:
# - Google Play Billing for digital goods (credits, subscriptions). NO
#   PayPal / Payoneer / manual transfers (removed 2026-09-29).
# - Free Grow = $0 organic worldwide, winds down near 1,000-impression cap.
# - Paid Boost packages: Starter $10/7d, Growth $25/14d, Pro $50/30d,
#   Scale $100/30d. No manual budgeting.
# - Sign-in: email + password, Google, Apple (iOS only). OTP codes are
#   only sent for password resets — never for sign-in.
# - Shop = Amazon affiliate links, always labeled "Sponsored" (مشتہر);
#   "Check price on Amazon" when no live price.
# - Academy = free lessons. Never fake engagement/bots/virality guarantees.
# Placeholders: {plan_line}, {campaigns_line}, {ticket_line}.
# ---------------------------------------------------------------------------
ANSWERS: dict[str, dict[str, str]] = {
    GREETING: {
        "en": ("Hello! Welcome to Virello. I can help with plans, payments, "
               "login, or how the app works — just ask me anything."),
        "ur": ("Assalam-o-Alaikum! Virello mein khush aamdeed. Main plans, "
               "payments, login ya app ke istemal mein aapki madad kar "
               "sakta hoon — bas poochein."),
        "ar": ("مرحبًا بك في Virello! يمكنني مساعدتك في الخطط والمدفوعات "
               "وتسجيل الدخول وكيفية استخدام التطبيق — فقط اسألني."),
    },
    HOW_IT_WORKS: {
        "en": ("Virello is simple: paste your post, pick a goal, optionally "
               "set a budget, and let it grow. Free Grow promotes your "
               "content organically worldwide at $0. Paid Boost runs paid "
               "campaigns within the spending limit you approve. Everything "
               "stays legitimate — no fake engagement, bots, or traffic "
               "exchanges."),
        "ur": ("Virello bohat aasan hai: apni post paste karein, goal "
               "chunein, chahein to budget lagayein, aur grow hone dein. "
               "Free Grow aapke content ko duniya bhar mein organic tareeqe "
               "se $0 mein promote karta hai. Paid Boost aapki manzoor-shuda "
               "limit ke andar paid campaigns chalata hai. Sab kuch jaiz "
               "tareeqe se hota hai — koi fake engagement, bots ya traffic "
               "exchange nahi."),
        "ar": ("Virello بسيط: الصق منشورك، واختر هدفًا، وحدد ميزانية إن "
               "أردت، ودعه ينمو. تروج خطة Free Grow لمحتواك بشكل عضوي حول "
               "العالم مجانًا. بينما تدير Paid Boost حملات مدفوعة ضمن حد "
               "الإنفاق الذي توافق عليه. كل شيء يتم بطرق مشروعة — لا تفاعل "
               "مزيف ولا روبوتات ولا تبادل زيارات."),
    },
    FREE_GROW: {
        "en": ("Free Grow is our free plan: organic promotion worldwide for "
               "$0, with no payment needed. It winds down naturally near the "
               "1,000-impression cap per campaign. When you need more reach, "
               "you can upgrade to a Paid Boost package."),
        "ur": ("Free Grow hamara muft plan hai: $0 mein duniya bhar mein "
               "organic promotion, baghair kisi payment ke. Har campaign "
               "1,000 impressions ki limit ke qareeb aahista ruk jati hai. "
               "Jab zyada reach chahiye ho to Paid Boost package mein "
               "upgrade kar sakte hain."),
        "ar": ("Free Grow هي خطتنا المجانية: ترويج عضوي حول العالم مقابل 0 "
               "دولار دون الحاجة لأي دفع. تتوقف الحملة تدريجيًا عند الاقتراب "
               "من حد 1,000 مشاهدة. وعندما تحتاج إلى وصول أكبر، يمكنك الترقية "
               "إلى إحدى باقات Paid Boost."),
    },
    PAID_BOOST: {
        "en": ("Paid Boost runs paid campaigns for you, always within the "
               "budget and targeting you approve. Packages: Starter $10 for "
               "7 days, Growth $25 for 14 days, Pro $50 for 30 days, Scale "
               "$100 for 30 days. There is no manual budgeting — the "
               "package you pick is the spending cap."),
        "ur": ("Paid Boost aapke liye paid campaigns chalata hai, hamesha "
               "aapki manzoor-shuda budget aur targeting ke andar. Packages: "
               "Starter $10 (7 din), Growth $25 (14 din), Pro $50 (30 din), "
               "Scale $100 (30 din). Manual budget lagane ki zaroorat nahi — "
               "jo package chunein wahi spending limit hai."),
        "ar": ("تدير Paid Boost حملات مدفوعة لك، دائمًا ضمن الميزانية "
               "والاستهداف اللذين توافق عليهما. الباقات: Starter بـ10 "
               "دولارات لمدة 7 أيام، وGrowth بـ25 دولارًا لمدة 14 يومًا، "
               "وPro بـ50 دولارًا لمدة 30 يومًا، وScale بـ100 دولار لمدة 30 "
               "يومًا. لا حاجة لضبط الميزانية يدويًا — الباقة التي تختارها هي "
               "حد الإنفاق."),
    },
    PACKAGES_PRICING: {
        "en": ("Our packages: Starter $10/7 days, Growth $25/14 days (most "
               "popular), Pro $50/30 days, and Scale $100/30 days. Free Grow "
               "is always $0. Every payment goes through Google Play Billing "
               "and is verified securely on our servers."),
        "ur": ("Hamare packages: Starter $10/7 din, Growth $25/14 din (sab "
               "se maqbool), Pro $50/30 din, aur Scale $100/30 din. Free "
               "Grow hamesha $0 hai. Har payment Google Play Billing se hoti "
               "hai aur hamare servers par mehfooz tareeqe se verify hoti "
               "hai."),
        "ar": ("باقاتنا: Starter بـ10 دولارات/7 أيام، وGrowth بـ25 دولارًا/14 "
               "يومًا (الأكثر شعبية)، وPro بـ50 دولارًا/30 يومًا، وScale "
               "بـ100 دولار/30 يومًا. خطة Free Grow مجانية دائمًا. تتم جميع "
               "المدفوعات عبر Google Play Billing ويتم التحقق منها بأمان على "
               "خوادمنا."),
    },
    BILLING_GOOGLE_PLAY: {
        "en": ("Virello uses Google Play Billing for all digital purchases — "
               "credits, subscriptions, and premium features. Google "
               "processes your payment, so we never see or store your card "
               "details. If a purchase doesn't activate, check your Play "
               "Store receipt first, then contact support with the order "
               "number."),
        "ur": ("Virello tamam digital khareedari ke liye Google Play Billing "
               "istemal karta hai — credits, subscriptions aur premium "
               "features. Aapki payment Google process karta hai, is liye "
               "hum aapke card ki details kabhi dekhte ya save nahi karte. "
               "Agar khareedari activate na ho to pehle apni Play Store "
               "receipt check karein, phir order number ke sath support se "
               "rabta karein."),
        "ar": ("يستخدم Virello خدمة Google Play Billing لجميع المشتريات "
               "الرقمية — الأرصدة والاشتراكات والمزايا المميزة. تعالج Google "
               "دفعتك، لذلك لا نرى بيانات بطاقتك ولا نخزنها أبدًا. إذا لم يتم "
               "تفعيل عملية شراء، تحقق أولًا من إيصال متجر Play ثم تواصل مع "
               "الدعم مرفقًا رقم الطلب."),
    },
    PAYMENT_SAFETY: {
        "en": ("Yes — paying in Virello is safe. All digital purchases go "
               "through Google Play Billing: Google processes your payment, "
               "so Virello never sees or stores your card details, and every "
               "purchase is verified securely on our servers. Refunds follow "
               "Google Play's refund policy. And remember: Virello will "
               "never ask for your social-media passwords or your OTP codes "
               "— keep those private."),
        "ur": ("Jee haan — Virello mein payment bilkul mehfooz hai. Tamam "
               "digital khareedari Google Play Billing se hoti hai: Google "
               "aapki payment process karta hai, is liye Virello aapke card "
               "ki details kabhi dekhta ya save nahi karta, aur har "
               "khareedari hamare servers par mehfooz tareeqe se verify hoti "
               "hai. Refunds Google Play ki refund policy ke mutabiq hote "
               "hain. Aur yaad rakhein: Virello aapke social-media passwords "
               "ya OTP codes kabhi nahi maangta — inhein private rakhein."),
        "ar": ("نعم — الدفع في Virello آمن. تتم جميع المشتريات الرقمية عبر "
               "Google Play Billing: تعالج Google دفعتك، لذلك لا ترى Virello "
               "بيانات بطاقتك ولا تخزنها أبدًا، ويتم التحقق من كل عملية شراء "
               "بأمان على خوادمنا. تخضع المبالغ المستردة لسياسة الاسترداد "
               "الخاصة بـGoogle Play. وتذكر: لن تطلب Virello أبدًا كلمات "
               "مرور حساباتك على وسائل التواصل أو رموز OTP — حافظ عليها "
               "سرية."),
    },
    CREDITS: {
        "en": ("Credits are Virello's currency for premium features and "
               "processing. New accounts start with 300 free starter "
               "credits, and you can top up anytime through Google Play "
               "Billing. {plan_line}"),
        "ur": ("Credits Virello ki currency hain premium features aur "
               "processing ke liye. Naye accounts ko 300 muft starter "
               "credits milte hain, aur aap Google Play Billing se kabhi "
               "bhi top-up kar sakte hain. {plan_line}"),
        "ar": ("الأرصدة هي عملة Virello للمزايا المميزة والمعالجة. تحصل "
               "الحسابات الجديدة على 300 رصيد مجاني للبداية، ويمكنك الشحن "
               "في أي وقت عبر Google Play Billing. {plan_line}"),
    },
    REFUNDS: {
        "en": ("Refunds follow Google Play's refund policy, since all "
               "payments go through Google Play Billing. You can request one "
               "from your Play Store order history. If Google Play declines "
               "it and you believe that's a mistake, create a support "
               "ticket and we'll review your case."),
        "ur": ("Refunds Google Play ki refund policy ke mutabiq hote hain, "
               "kyunke tamam payments Google Play Billing se hoti hain. "
               "Aap apni Play Store order history se refund request kar "
               "sakte hain. Agar Google Play inkar kar de aur aapko lagta "
               "hai ke ghalti hui hai, to support ticket banayein — hum "
               "aapka case review karein ge."),
        "ar": ("تخضع المبالغ المستردة لسياسة الاسترداد الخاصة بـGoogle Play، "
               "لأن جميع المدفوعات تتم عبر Google Play Billing. يمكنك طلب "
               "الاسترداد من سجل طلباتك في متجر Play. إذا رفض Google Play "
               "الطلب وكنت تعتقد أن ذلك خطأ، أنشئ تذكرة دعم وسنراجع حالتك."),
    },
    LOGIN_OTP: {
        "en": ("Virello doesn't sign you in with one-time codes — use your "
               "email + password, Google, or Apple sign-in (iOS) on the "
               "sign-in screen instead. OTP codes are only sent when you "
               "reset your password via 'Forgot password'. If that code "
               "didn't arrive, check your spam folder and request a new "
               "one. Never share OTP codes with anyone."),
        "ur": ("Virello one-time codes se sign-in nahi karata — sign-in "
               "screen par apne email + password, Google, ya Apple sign-in "
               "(iOS) se login karein. OTP codes sirf 'Forgot password' se "
               "password reset par bheje jate hain. Agar wo code na aaye to "
               "spam folder check karein aur naya code mangwayein. OTP "
               "codes kabhi kisi se share na karein."),
        "ar": ("لا يسجّل Virello الدخول برموز لمرة واحدة — سجّل الدخول "
               "بالبريد وكلمة المرور أو عبر Google أو Apple (iOS) من شاشة "
               "تسجيل الدخول. تُرسل رموز OTP فقط عند إعادة تعيين كلمة "
               "المرور عبر «نسيت كلمة المرور». إذا لم يصلك الرمز، تحقق من "
               "مجلد الرسائل غير المرغوب فيها واطلب رمزًا جديدًا. لا "
               "تشارك رموز OTP مع أي شخص أبدًا."),
    },
    LOGIN_PASSWORD: {
        "en": ("If you signed up with email + password, tap 'Forgot "
               "password' on the sign-in screen to reset it with an email "
               "code. Passwords must be 8–72 characters long. After several "
               "wrong attempts, sign-in locks briefly for 15 minutes as a "
               "safety measure."),
        "ur": ("Agar aapne email + password se account banaya tha, to "
               "sign-in screen par 'Forgot password' dabayein aur email code "
               "se reset karein. Password 8–72 characters ka hona chahiye. "
               "Kayee ghalat koshishon ke baad sign-in 15 minute ke liye "
               "aarzi tor par lock ho jata hai."),
        "ar": ("إذا سجلت بالبريد الإلكتروني وكلمة المرور، اضغط 'نسيت كلمة "
               "المرور' في شاشة تسجيل الدخول لإعادة تعيينها برمز بريد "
               "إلكتروني. يجب أن تكون كلمة المرور من 8 إلى 72 حرفًا. وبعد "
               "عدة محاولات خاطئة، يُقفل تسجيل الدخول مؤقتًا لمدة 15 دقيقة "
               "كإجراء أمان."),
    },
    LOGIN_GOOGLE_APPLE: {
        "en": ("You can also sign in with your Google account on any device, "
               "or with Apple sign-in on iOS. Virello only uses official "
               "sign-in buttons — it will never ask for your social-media "
               "passwords. If it fails, make sure you're signed into that "
               "Google or Apple account on your device first."),
        "ur": ("Aap apne Google account se kisi bhi device par, ya iOS par "
               "Apple sign-in se bhi login kar sakte hain. Virello sirf "
               "official sign-in buttons istemal karta hai — aapke "
               "social-media passwords kabhi nahi maange ga. Agar fail ho "
               "to pehle device par us Google ya Apple account mein "
               "signed-in hon."),
        "ar": ("يمكنك أيضًا تسجيل الدخول بحساب Google على أي جهاز، أو عبر "
               "Apple على نظام iOS. يستخدم Virello أزرار تسجيل الدخول "
               "الرسمية فقط — ولن يطلب كلمات مرور حساباتك على وسائل التواصل "
               "أبدًا. إذا فشل الدخول، تأكد أولًا من تسجيل دخولك إلى حساب "
               "Google أو Apple على جهازك."),
    },
    PLANS_COMPARE: {
        "en": ("Free Grow is $0, organic, and worldwide — perfect for trying "
               "Virello. Paid Boost adds paid promotion with bigger reach "
               "and longer runs: Starter $10/7d, Growth $25/14d, Pro $50/30d, "
               "Scale $100/30d. Starting out? Try Free Grow first, then "
               "upgrade when you need more."),
        "ur": ("Free Grow $0 mein organic aur worldwide hai — Virello "
               "aazmane ke liye behtareen. Paid Boost zyada reach aur lambi "
               "muddat ke sath paid promotion deta hai: Starter $10/7 din, "
               "Growth $25/14 din, Pro $50/30 din, Scale $100/30 din. Shuru "
               "mein Free Grow try karein, zaroorat ho to upgrade kar "
               "lein."),
        "ar": ("خطة Free Grow مجانية وعضوية وحول العالم — مثالية لتجربة "
               "Virello. تضيف Paid Boost ترويجًا مدفوعًا بوصول أكبر ومدد "
               "أطول: Starter بـ10 دولارات/7 أيام، وGrowth بـ25 دولارًا/14 "
               "يومًا، وPro بـ50 دولارًا/30 يومًا، وScale بـ100 دولار/30 "
               "يومًا. هل أنت في البداية؟ جرّب Free Grow أولًا ثم رقِّ عندما "
               "تحتاج المزيد."),
    },
    FEATURES_HOME: {
        "en": ("The Home tab is your starting point: your feed, quick "
               "stats, and shortcuts to Create and Grow. The bottom "
               "navigation takes you anywhere in the app. The center + "
               "button opens the Create hub."),
        "ur": ("Home tab aapka starting point hai: aapki feed, quick stats, "
               "aur Create aur Grow ke shortcuts. Neeche wali navigation se "
               "aap app mein kahin bhi ja sakte hain. Darmiyan wala + "
               "button Create hub kholta hai."),
        "ar": ("علامة التبويب 'الرئيسية' هي نقطة انطلاقك: خلاصتك وإحصاءاتك "
               "السريعة واختصارات الإنشاء والنمو. يأخذك شريط التنقل السفلي "
               "إلى أي مكان في التطبيق. ويفتح زر + الأوسط مركز الإنشاء."),
    },
    FEATURES_DISCOVER: {
        "en": ("The Discover tab shows trending content and posts matched to "
               "your interests. Browse trending topics, search, and filter "
               "by category. Tap any post to open it, join the comments, or "
               "visit the creator's profile."),
        "ur": ("Discover tab mein trending content aur aapki dilchaspi ke "
               "mutabiq posts nazar aati hain. Trending topics dekhein, "
               "search karein aur category se filter karein. Kisi post par "
               "tap karke use kholein, comments mein hissa lein ya creator "
               "ki profile dekhein."),
        "ar": ("تعرض علامة التبويب 'اكتشف' المحتوى الرائج والمنشورات المطابقة "
               "لاهتماماتك. تصفح المواضيع الرائجة وابحث ورشّح حسب الفئة. "
               "اضغط على أي منشور لفتحه أو المشاركة في التعليقات أو زيارة "
               "ملف منشئ المحتوى."),
    },
    FEATURES_CREATE: {
        "en": ("The Create hub (center + button) has it all: image and "
               "video tools, teleprompter, templates, voiceover, and "
               "captions. Crop, filter, trim, and render videos right in the "
               "app. When it's ready, share your content or send it to Grow."),
        "ur": ("Create hub (darmiyan wala + button) mein sab kuch hai: "
               "image aur video tools, teleprompter, templates, voiceover "
               "aur captions. App mein hi crop, filter, trim aur video "
               "render karein. Tayyar ho jaye to content share karein ya "
               "Grow mein bhejein."),
        "ar": ("يحتوي مركز الإنشاء (زر + الأوسط) على كل شيء: أدوات الصور "
               "والفيديو، والمُلقِّن، والقوالب، والتعليق الصوتي، والترجمة. "
               "قص ورشّح وقلّم واعرض الفيديوهات داخل التطبيق مباشرة. وعندما "
               "تجهز، شارك محتواك أو أرسله إلى 'نمو'."),
    },
    FEATURES_GROW: {
        "en": ("The Grow tab is where campaigns live: analyze a post, run "
               "the Viral Lab, set up a campaign, and review your audience. "
               "Free Grow runs organically; Paid Boost uses your chosen "
               "package. {campaigns_line}"),
        "ur": ("Grow tab mein campaigns hoti hain: post analyze karein, "
               "Viral Lab chalaye, campaign setup karein aur apni audience "
               "dekhein. Free Grow organic chalti hai; Paid Boost aapke "
               "chune hue package par. {campaigns_line}"),
        "ar": ("علامة التبويب 'نمو' هي موطن الحملات: حلل منشورًا، وشغّل مختبر "
               "الانتشار، وأنشئ حملة، وراجع جمهورك. تعمل Free Grow بشكل "
               "عضوي؛ وتستخدم Paid Boost الباقة التي اخترتها. "
               "{campaigns_line}"),
    },
    FEATURES_SHOP: {
        "en": ("The Shop tab lists real products across 26 departments, each "
               "with a full photo gallery before it's listed. Partner "
               "listings are affiliate links, always labeled 'Sponsored' "
               "(مشتہر). When a live price isn't available, we say 'Check "
               "price on Amazon' instead of guessing. Browsing is safe: "
               "Virello never touches your money — checkout happens securely "
               "on Amazon."),
        "ur": ("Shop tab mein 26 departments ki asal products hain, har "
               "product poori photo gallery ke sath list hoti hai. Partner "
               "listings affiliate links hain, hamesha 'Sponsored' (مشتہر) "
               "ka label lagta hai. Jab live price available na ho to "
               "andaza lagane ke bajaye 'Check price on Amazon' likhte "
               "hain. Browse karna mehfooz hai: Virello aapke paise ko "
               "haath nahi lagata — checkout Amazon ki mehfooz site par "
               "hoti hai."),
        "ar": ("تعرض علامة التبويب 'تسوق' منتجات حقيقية عبر 26 قسمًا، ولكل "
               "منتج معرض صور كامل قبل إدراجه. قوائم الشركاء هي روابط تابعة، "
               "وتحمل دائمًا وسم 'مُعلَن' (مشتہر). وعندما لا يتوفر سعر مباشر، "
               "نكتب 'تحقق من السعر على أمازون' بدلًا من التخمين. التصفح "
               "آمن: لا تلمس Virello أموالك أبدًا — تتم عملية الدفع على موقع "
               "أمازون الآمن."),
    },
    FEATURES_ACADEMY: {
        "en": ("The Academy tab offers free step-by-step lessons on content "
               "and growth skills, in English and Urdu, with quizzes to "
               "check your progress. It's completely free — just open a "
               "lesson and start learning."),
        "ur": ("Academy tab mein content aur growth skills par muft "
               "step-by-step lessons hain — English aur Urdu mein, quizzes "
               "ke sath. Ye bilkul muft hai — bas lesson kholein aur seekhna "
               "shuru karein."),
        "ar": ("تقدم علامة التبويب 'الأكاديمية' دروسًا مجانية خطوة بخطوة في "
               "مهارات المحتوى والنمو، بالإنجليزية والأردية، مع اختبارات "
               "لمتابعة تقدمك. وهي مجانية تمامًا — افتح درسًا وابدأ التعلم."),
    },
    TROUBLESHOOTING_CRASH: {
        "en": ("Sorry about that. First, update to the latest version from "
               "the Play Store. Then clear the app cache (Settings → Apps → "
               "Virello → Storage → Clear cache) and reopen it. If it still "
               "crashes, tell me what you were doing when it happened and "
               "I'll open a ticket for our team."),
        "ur": ("Maazrat. Pehle Play Store se latest version update karein. "
               "Phir app ka cache clear karein (Settings → Apps → Virello → "
               "Storage → Clear cache) aur dobara kholein. Agar phir bhi "
               "crash ho to batayein aap kya kar rahe thay — main hamari "
               "team ke liye ticket khol doon ga."),
        "ar": ("عذرًا على ذلك. أولًا، حدّث إلى أحدث إصدار من متجر Play. ثم "
               "امسح ذاكرة التخزين المؤقت للتطبيق (الإعدادات ← التطبيقات ← "
               "Virello ← التخزين ← مسح ذاكرة التخزين المؤقت) وأعد فتحه. إذا "
               "استمر التعطل، أخبرني بما كنت تفعله عند حدوثه وسأفتح تذكرة "
               "لفريقنا."),
    },
    TROUBLESHOOTING_LOGIN: {
        "en": ("Let's fix your sign-in. For email + password: use 'Forgot "
               "password' to reset it — the reset code goes to your email, "
               "so check your spam folder too. For Google or Apple: make "
               "sure you're signed into that account on your device. If "
               "none of that works, tell me and I'll escalate it."),
        "ur": ("Aaiye aapka sign-in theek karte hain. Email + password ke "
               "liye: 'Forgot password' se reset karein — reset code aapke "
               "email par aata hai, is liye spam folder bhi check karein. "
               "Google ya Apple ke liye: device par us account mein "
               "signed-in hon. Agar kuch na kaam kare to batayein — main "
               "ise escalate kar doon ga."),
        "ar": ("لنصلح تسجيل دخولك. للبريد وكلمة المرور: استخدم «نسيت كلمة "
               "المرور» لإعادة التعيين — يصل رمز التعيين إلى بريدك، فتحقق "
               "أيضًا من مجلد الرسائل غير المرغوب فيها. لـGoogle أو Apple: "
               "تأكد من تسجيل دخولك إلى ذلك الحساب على جهازك. إذا لم ينجح "
               "شيء، أخبرني وسأصعّد الأمر."),
    },
    ACCOUNT_DELETE: {
        "en": ("You can request account deletion from the app's Settings "
               "page — this permanently removes your account and personal "
               "data. If you'd like help, I can create a support ticket so "
               "our team processes your request."),
        "ur": ("Aap app ke Settings page se account deletion ki request kar "
               "sakte hain — is se aapka account aur personal data mustaqil "
               "tor par delete ho jata hai. Agar madad chahiye to main "
               "support ticket bana sakta hoon taake hamari team aapki "
               "request process kare."),
        "ar": ("يمكنك طلب حذف حسابك من صفحة الإعدادات في التطبيق — سيؤدي ذلك "
               "إلى إزالة حسابك وبياناتك الشخصية نهائيًا. إذا أردت المساعدة، "
               "يمكنني إنشاء تذكرة دعم ليعالج فريقنا طلبك."),
    },
    AFFILIATE_DISCLOSURE: {
        "en": ("Some Shop listings are affiliate links: if you buy through "
               "them, Virello may earn a small commission at no extra cost "
               "to you. These are always labeled 'Sponsored' (مشتہر) so you "
               "know. We only list real products and never invent prices or "
               "stock."),
        "ur": ("Shop ki kuch listings affiliate links hain: agar aap un se "
               "khareedein to Virello ko chhota sa commission mil sakta "
               "hai — aapko koi extra qeemat nahi deni parti. In par "
               "hamesha 'Sponsored' (مشتہر) ka label hota hai. Hum sirf asal "
               "products list karte hain, qeemat ya stock kabhi nahi "
               "gharte."),
        "ar": ("بعض قوائم التسوق هي روابط تابعة: إذا اشتريت عبرها، فقد تحصل "
               "Virello على عمولة صغيرة دون أي تكلفة إضافية عليك. تحمل هذه "
               "القوائم دائمًا وسم 'مُعلَن' (مشتہر) لتعرف ذلك. ندرج المنتجات "
               "الحقيقية فقط ولا نخترع الأسعار أو المخزون أبدًا."),
    },
    ORDER_STATUS: {
        "en": ("Virello doesn't sell products directly — Shop listings link "
               "out to Amazon, and Amazon fulfills your order. Track it with "
               "the link in your Amazon confirmation email. If a Virello "
               "product link looks broken, tell me and I'll report it."),
        "ur": ("Virello products directly nahi bechta — Shop listings "
               "Amazon par le jati hain, aur Amazon aapka order poora karta "
               "hai. Apni Amazon confirmation email ke link se track karein. "
               "Agar Virello ka product link kharab lage to batayein — main "
               "report kar doon ga."),
        "ar": ("لا تبيع Virello المنتجات مباشرة — تربط قوائم التسوق بموقع "
               "أمازون، وأمازون هو من ينفذ طلبك. تتبعه عبر الرابط في رسالة "
               "تأكيد أمازون. إذا بدا رابط منتج في Virello معطلًا، أخبرني "
               "وسأبلغ عنه."),
    },
    HUMAN_AGENT: {
        "en": ("Of course — I'm handing you over to our human support team. "
               "A team member will pick this up shortly. I can also create "
               "a support ticket right now so nothing gets lost."),
        "ur": ("Zaroor — main aapko hamari human support team ke hawalay kar "
               "raha hoon. Team ka koi member jald jawab de ga. Main abhi "
               "aapke liye support ticket bhi bana sakta hoon taake kuch "
               "miss na ho."),
        "ar": ("بالطبع — سأحيلك إلى فريق الدعم البشري لدينا. سيرد عليك أحد "
               "أعضاء الفريق قريبًا. يمكنني أيضًا إنشاء تذكرة دعم لك الآن "
               "حتى لا يضيع شيء."),
    },
    CONTACT: {
        "en": ("You can reach our support team from the app's Profile "
               "section. If you'd like, I can create a support ticket for "
               "you right now and the team will follow up."),
        "ur": ("Aap app ke Profile section se hamari support team se rabta "
               "kar sakte hain. Agar chahein to main abhi aapke liye support "
               "ticket bana sakta hoon aur team follow-up kare gi."),
        "ar": ("يمكنك التواصل مع فريق الدعم من قسم الملف الشخصي في التطبيق. "
               "وإذا أردت، يمكنني إنشاء تذكرة دعم لك الآن وسيتابع الفريق "
               "معك."),
    },
    HONESTY_POLICY: {
        "en": ("Virello is built on honest growth: no fake engagement, no "
               "bots, no click farms, and no traffic exchanges — ever. We "
               "never guarantee virality, followers, or sales; we speak only "
               "in honest estimates. Anything marked as an estimate or "
               "suggestion is exactly that."),
        "ur": ("Virello imandari wali growth par bana hai: koi fake "
               "engagement nahi, koi bots nahi, koi click farms ya traffic "
               "exchange nahi — kabhi bhi nahi. Hum virality, followers ya "
               "sales ki guarantee kabhi nahi dete; sirf imandana andaze "
               "batate hain. Jo cheez estimate ya suggestion ke tor par "
               "likhi ho, wahi hai."),
        "ar": ("بُنيت Virello على النمو الصادق: لا تفاعل مزيف ولا روبوتات ولا "
               "مزارع نقرات ولا تبادل زيارات — أبدًا. لا نضمن الانتشار أو "
               "المتابعين أو المبيعات أبدًا؛ نتحدث فقط بتقديرات صادقة. وكل ما "
               "يُوصف بأنه تقدير أو اقتراح هو كذلك فعلًا."),
    },
    LANGUAGE_CHANGE: {
        "en": ("You can switch the app's language anytime from Settings — "
               "Virello supports English, Urdu, and Arabic. I'll reply in "
               "whichever of these you write in."),
        "ur": ("Aap Settings se app ki zuban kabhi bhi badal sakte hain — "
               "Virello English, Urdu aur Arabic support karta hai. Aap jis "
               "zuban mein likhein ge, main usi mein jawab doon ga."),
        "ar": ("يمكنك تغيير لغة التطبيق في أي وقت من الإعدادات — يدعم Virello "
               "الإنجليزية والأردية والعربية. سأرد باللغة التي تكتب بها من "
               "بينها."),
    },
    UNKNOWN: {
        "en": ("I don't have that answer yet — I won't guess when it comes "
               "to your account or money. I can create a support ticket so "
               "a human can help you properly."),
        "ur": ("Iska jawab mere paas abhi nahi hai — aapke account ya paise "
               "ke maamle mein main andaza nahi lagaoon ga. Main aapke liye "
               "support ticket bana sakta hoon taake koi insan aapki durust "
               "madad kare."),
        "ar": ("ليس لدي إجابة عن ذلك بعد — لن أخمّن عندما يتعلق الأمر بحسابك "
               "أو أموالك. يمكنني إنشاء تذكرة دعم ليساعدك إنسان بشكل صحيح."),
    },
}

# Quick-reply suggestions per intent per language.
SUGGESTIONS: dict[str, dict[str, list[str]]] = {
    GREETING: {
        "en": ["How does Virello work?", "What is Free Grow?",
               "Which payment methods do you accept?"],
        "ur": ["Virello kaise kaam karta hai?", "Free Grow kya hai?",
               "Kaun se payment methods accept hote hain?"],
        "ar": ["كيف يعمل Virello؟", "ما هي خطة Free Grow؟",
               "ما طرق الدفع المقبولة؟"],
    },
    HOW_IT_WORKS: {
        "en": ["What is Free Grow?", "What is Paid Boost?",
               "What are the packages?"],
        "ur": ["Free Grow kya hai?", "Paid Boost kya hai?",
               "Packages kaun se hain?"],
        "ar": ["ما هي Free Grow؟", "ما هي Paid Boost؟", "ما هي الباقات؟"],
    },
    FREE_GROW: {
        "en": ["Compare Free vs Paid", "What are the packages?",
               "How do I start?"],
        "ur": ["Free vs Paid compare karein", "Packages kaun se hain?",
               "Shuru kaise karoon?"],
        "ar": ["قارن بين المجاني والمدفوع", "ما هي الباقات؟", "كيف أبدأ؟"],
    },
    PAID_BOOST: {
        "en": ["What are the packages?", "How do I pay?",
               "Show my campaigns"],
        "ur": ["Packages kaun se hain?", "Payment kaise karoon?",
               "Meri campaigns dekhein"],
        "ar": ["ما هي الباقات؟", "كيف أدفع؟", "عرض حملاتي"],
    },
    PACKAGES_PRICING: {
        "en": ["Compare plans", "How do I pay?", "What is Free Grow?"],
        "ur": ["Plans compare karein", "Payment kaise karoon?",
               "Free Grow kya hai?"],
        "ar": ["قارن الخطط", "كيف أدفع؟", "ما هي Free Grow؟"],
    },
    BILLING_GOOGLE_PLAY: {
        "en": ["What are the packages?", "Is my payment safe?",
               "I need a refund"],
        "ur": ["Packages kaun se hain?", "Kya payment mehfooz hai?",
               "Mujhe refund chahiye"],
        "ar": ["ما هي الباقات؟", "هل الدفع آمن؟", "أحتاج إلى استرداد"],
    },
    PAYMENT_SAFETY: {
        "en": ["What are the packages?", "How do I pay?",
               "I need a refund"],
        "ur": ["Packages kaun se hain?", "Payment kaise karoon?",
               "Mujhe refund chahiye"],
        "ar": ["ما هي الباقات؟", "كيف أدفع؟", "أحتاج إلى استرداد"],
    },
    CREDITS: {
        "en": ["What are the packages?", "How do I pay?",
               "What is Free Grow?"],
        "ur": ["Packages kaun se hain?", "Payment kaise karoon?",
               "Free Grow kya hai?"],
        "ar": ["ما هي الباقات؟", "كيف أدفع؟", "ما هي Free Grow؟"],
    },
    REFUNDS: {
        "en": ["Talk to a human", "Which payment methods do you accept?",
               "Create a ticket"],
        "ur": ["Insan se baat karein",
               "Kaun se payment methods accept hote hain?",
               "Ticket banayein"],
        "ar": ["التحدث مع إنسان", "ما طرق الدفع المقبولة؟", "إنشاء تذكرة"],
    },
    LOGIN_OTP: {
        "en": ["I didn't get the code", "Reset my password",
               "Talk to a human"],
        "ur": ["Mujhe code nahi mila", "Password reset karein",
               "Insan se baat karein"],
        "ar": ["لم يصلني الرمز", "إعادة تعيين كلمة المرور",
               "التحدث مع إنسان"],
    },
    LOGIN_PASSWORD: {
        "en": ["Reset my password", "I can't log in", "Talk to a human"],
        "ur": ["Password reset karein", "Login nahi ho raha",
               "Insan se baat karein"],
        "ar": ["إعادة تعيين كلمة المرور", "لا أستطيع تسجيل الدخول",
               "التحدث مع إنسان"],
    },
    LOGIN_GOOGLE_APPLE: {
        "en": ["Reset my password", "I can't log in", "Talk to a human"],
        "ur": ["Password reset karein", "Login nahi ho raha",
               "Insan se baat karein"],
        "ar": ["إعادة تعيين كلمة المرور", "لا أستطيع تسجيل الدخول",
               "التحدث مع إنسان"],
    },
    PLANS_COMPARE: {
        "en": ["What are the packages?", "What is Free Grow?",
               "What is Paid Boost?"],
        "ur": ["Packages kaun se hain?", "Free Grow kya hai?",
               "Paid Boost kya hai?"],
        "ar": ["ما هي الباقات؟", "ما هي Free Grow؟", "ما هي Paid Boost؟"],
    },
    FEATURES_HOME: {
        "en": ["Open Discover", "Open Create", "How does Virello work?"],
        "ur": ["Discover kholein", "Create kholein",
               "Virello kaise kaam karta hai?"],
        "ar": ["افتح 'اكتشف'", "افتح 'إنشاء'", "كيف يعمل Virello؟"],
    },
    FEATURES_DISCOVER: {
        "en": ["Open Create", "What is the Shop?", "How does Virello work?"],
        "ur": ["Create kholein", "Shop kya hai?",
               "Virello kaise kaam karta hai?"],
        "ar": ["افتح 'إنشاء'", "ما هو المتجر؟", "كيف يعمل Virello؟"],
    },
    FEATURES_CREATE: {
        "en": ["Open Grow", "What is the Academy?",
               "How does Virello work?"],
        "ur": ["Grow kholein", "Academy kya hai?",
               "Virello kaise kaam karta hai?"],
        "ar": ["افتح 'نمو'", "ما هي الأكاديمية؟", "كيف يعمل Virello؟"],
    },
    FEATURES_GROW: {
        "en": ["What is Paid Boost?", "Show my campaigns",
               "What is Free Grow?"],
        "ur": ["Paid Boost kya hai?", "Meri campaigns dekhein",
               "Free Grow kya hai?"],
        "ar": ["ما هي Paid Boost؟", "عرض حملاتي", "ما هي Free Grow؟"],
    },
    FEATURES_SHOP: {
        "en": ["Is the Shop safe?", "How do affiliates work?",
               "Track my order"],
        "ur": ["Kya Shop mehfooz hai?", "Affiliate kaise kaam karta hai?",
               "Order track karein"],
        "ar": ["هل المتجر آمن؟", "كيف تعمل الروابط التابعة؟", "تتبع طلبي"],
    },
    FEATURES_ACADEMY: {
        "en": ["Open Create", "How does Virello work?",
               "What is Free Grow?"],
        "ur": ["Create kholein", "Virello kaise kaam karta hai?",
               "Free Grow kya hai?"],
        "ar": ["افتح 'إنشاء'", "كيف يعمل Virello؟", "ما هي Free Grow؟"],
    },
    TROUBLESHOOTING_CRASH: {
        "en": ["The app won't open", "Create a ticket", "Talk to a human"],
        "ur": ["App nahi khul rahi", "Ticket banayein",
               "Insan se baat karein"],
        "ar": ["التطبيق لا يفتح", "إنشاء تذكرة", "التحدث مع إنسان"],
    },
    TROUBLESHOOTING_LOGIN: {
        "en": ["I didn't get the OTP", "Reset my password",
               "Talk to a human"],
        "ur": ["OTP nahi mila", "Password reset karein",
               "Insan se baat karein"],
        "ar": ["لم يصلني رمز OTP", "إعادة تعيين كلمة المرور",
               "التحدث مع إنسان"],
    },
    ACCOUNT_DELETE: {
        "en": ["Create a ticket", "Talk to a human",
               "How does Virello work?"],
        "ur": ["Ticket banayein", "Insan se baat karein",
               "Virello kaise kaam karta hai?"],
        "ar": ["إنشاء تذكرة", "التحدث مع إنسان", "كيف يعمل Virello؟"],
    },
    AFFILIATE_DISCLOSURE: {
        "en": ["Track my order", "What is the Shop?", "Talk to a human"],
        "ur": ["Order track karein", "Shop kya hai?",
               "Insan se baat karein"],
        "ar": ["تتبع طلبي", "ما هو المتجر؟", "التحدث مع إنسان"],
    },
    ORDER_STATUS: {
        "en": ["What is the Shop?", "Talk to a human", "Create a ticket"],
        "ur": ["Shop kya hai?", "Insan se baat karein", "Ticket banayein"],
        "ar": ["ما هو المتجر؟", "التحدث مع إنسان", "إنشاء تذكرة"],
    },
    HUMAN_AGENT: {
        "en": ["Create a ticket", "Contact support",
               "How does Virello work?"],
        "ur": ["Ticket banayein", "Support se rabta karein",
               "Virello kaise kaam karta hai?"],
        "ar": ["إنشاء تذكرة", "التواصل مع الدعم", "كيف يعمل Virello؟"],
    },
    CONTACT: {
        "en": ["Create a ticket", "Talk to a human",
               "How does Virello work?"],
        "ur": ["Ticket banayein", "Insan se baat karein",
               "Virello kaise kaam karta hai?"],
        "ar": ["إنشاء تذكرة", "التحدث مع إنسان", "كيف يعمل Virello؟"],
    },
    HONESTY_POLICY: {
        "en": ["How does Virello work?", "What is Free Grow?",
               "What is Paid Boost?"],
        "ur": ["Virello kaise kaam karta hai?", "Free Grow kya hai?",
               "Paid Boost kya hai?"],
        "ar": ["كيف يعمل Virello؟", "ما هي Free Grow؟", "ما هي Paid Boost؟"],
    },
    LANGUAGE_CHANGE: {
        "en": ["Switch to Urdu", "Switch to Arabic",
               "How does Virello work?"],
        "ur": ["Urdu mein baat karein", "Arabic mein baat karein",
               "Virello kaise kaam karta hai?"],
        "ar": ["التحدث بالأردية", "التحدث بالعربية", "كيف يعمل Virello؟"],
    },
    UNKNOWN: {
        "en": ["How does Virello work?", "Create a ticket",
               "Talk to a human"],
        "ur": ["Virello kaise kaam karta hai?", "Ticket banayein",
               "Insan se baat karein"],
        "ar": ["كيف يعمل Virello؟", "إنشاء تذكرة", "التحدث مع إنسان"],
    },
}

# Deep-link actions per intent: {"label": ..., "tab": N} or {"route": ...}.
_OPEN_SCREEN: dict[str, dict[str, dict[str, str]]] = {
    FEATURES_HOME: {
        "en": {"label": "Open Home", "tab": 0},
        "ur": {"label": "Home kholein", "tab": 0},
        "ar": {"label": "افتح الرئيسية", "tab": 0},
    },
    FEATURES_DISCOVER: {
        "en": {"label": "Open Discover", "tab": 1},
        "ur": {"label": "Discover kholein", "tab": 1},
        "ar": {"label": "افتح اكتشف", "tab": 1},
    },
    FEATURES_CREATE: {
        "en": {"label": "Open Create", "tab": 2},
        "ur": {"label": "Create kholein", "tab": 2},
        "ar": {"label": "افتح إنشاء", "tab": 2},
    },
    FEATURES_GROW: {
        "en": {"label": "Open Grow", "tab": 3},
        "ur": {"label": "Grow kholein", "tab": 3},
        "ar": {"label": "افتح نمو", "tab": 3},
    },
    FREE_GROW: {
        "en": {"label": "Open Grow", "tab": 3},
        "ur": {"label": "Grow kholein", "tab": 3},
        "ar": {"label": "افتح نمو", "tab": 3},
    },
    PAID_BOOST: {
        "en": {"label": "Open Grow", "tab": 3},
        "ur": {"label": "Grow kholein", "tab": 3},
        "ar": {"label": "افتح نمو", "tab": 3},
    },
    FEATURES_SHOP: {
        "en": {"label": "Open Shop", "tab": 4},
        "ur": {"label": "Shop kholein", "tab": 4},
        "ar": {"label": "افتح التسوق", "tab": 4},
    },
    PACKAGES_PRICING: {
        "en": {"label": "View plans", "route": "/billing"},
        "ur": {"label": "Plans dekhein", "route": "/billing"},
        "ar": {"label": "عرض الخطط", "route": "/billing"},
    },
    BILLING_GOOGLE_PLAY: {
        "en": {"label": "View plans", "route": "/billing"},
        "ur": {"label": "Plans dekhein", "route": "/billing"},
        "ar": {"label": "عرض الخطط", "route": "/billing"},
    },
    PAYMENT_SAFETY: {
        "en": {"label": "View plans", "route": "/billing"},
        "ur": {"label": "Plans dekhein", "route": "/billing"},
        "ar": {"label": "عرض الخطط", "route": "/billing"},
    },
    CREDITS: {
        "en": {"label": "View plans", "route": "/billing"},
        "ur": {"label": "Plans dekhein", "route": "/billing"},
        "ar": {"label": "عرض الخطط", "route": "/billing"},
    },
    FEATURES_ACADEMY: {
        "en": {"label": "Open Academy", "route": "/academy"},
        "ur": {"label": "Academy kholein", "route": "/academy"},
        "ar": {"label": "افتح الأكاديمية", "route": "/academy"},
    },
}

# Localized tool-result fragments.
_PLAN_LINE = {
    "en": "Your plan: {plan}, balance: {credits} credits.",
    "ur": "Aapka plan: {plan}, balance: {credits} credits.",
    "ar": "خطتك: {plan}، رصيدك: {credits} من الأرصدة.",
}
_CAMPAIGNS_LINE = {
    "en": "You have {n} campaign(s): {statuses}.",
    "ur": "Aapki {n} campaign(s) hain: {statuses}.",
    "ar": "لديك {n} من الحملات: {statuses}.",
}
_NO_CAMPAIGNS_LINE = {
    "en": "You don't have any campaigns yet — create one from the Grow tab.",
    "ur": "Aapki abhi koi campaign nahi hai — Grow tab se banayein.",
    "ar": "ليس لديك أي حملات بعد — أنشئ واحدة من علامة التبويب 'نمو'.",
}
_TICKET_CREATED_LINE = {
    "en": "Ticket #{num} created — our team will follow up.",
    "ur": "Ticket #{num} bana di gayi hai — hamari team follow-up kare gi.",
    "ar": "تم إنشاء التذكرة #{num} — سيتابع فريقنا معك.",
}
# Standalone confirmation used when the ticket request itself was the whole
# message ("Create a ticket" / "Ticket banayein") — the intent classifier
# misfires on the word "create" (→ features_create), so appending the
# ticket line to the Create-hub answer would confuse the user.
_TICKET_CONFIRM = {
    "en": ("Done — I've created support ticket #{num} for you. Our team "
           "will follow up soon. Is there anything else I can help with?"),
    "ur": ("Ho gaya — maine aapke liye support ticket #{num} bana di hai. "
           "Hamari team jald follow-up kare gi. Kya main aapki aur koi "
           "madad kar sakta hoon?"),
    "ar": ("تم — أنشأت لك تذكرة الدعم #{num}. سيتابع فريقنا معك قريبًا. هل "
           "يمكنني مساعدتك في شيء آخر؟"),
}
_CREATE_TICKET_LABEL = {
    "en": "Create a support ticket",
    "ur": "Support ticket banayein",
    "ar": "إنشاء تذكرة دعم",
}

# ---------------------------------------------------------------------------
# Server-side tools — real data only, results folded into answers.
# ---------------------------------------------------------------------------

def _ticket_number(ticket_id: uuid.UUID) -> str:
    """Short human-readable ticket number, e.g. 'A3F9K2'."""
    return ticket_id.hex[:6].upper()


async def get_my_plan(user, db) -> dict:
    """Plan name + credit balance from the users table."""
    plan = getattr(user.plan, "value", None) or str(user.plan)
    return {"plan": plan, "credits": int(user.credits or 0)}


async def my_campaigns(user, db) -> dict:
    """Campaign count + statuses from the campaigns table."""
    from sqlalchemy import func, select

    from app.models.core import Campaign

    res = await db.execute(
        select(Campaign.status, func.count(Campaign.id))
        .where(Campaign.user_id == user.id)
        .group_by(Campaign.status)
    )
    by_status: dict[str, int] = {}
    for status, count in res.all():
        name = getattr(status, "value", None) or str(status)
        by_status[name] = int(count)
    return {"count": sum(by_status.values()), "by_status": by_status}


async def create_ticket(user, db, subject: str, message: str) -> dict:
    """Persist a support ticket row; returns ids + human ticket number."""
    from app.models.core import SupportTicket

    ticket = SupportTicket(
        user_id=user.id,
        subject=(subject or "")[:255],
        message=message or "",
        status="open",
    )
    db.add(ticket)
    await db.commit()
    await db.refresh(ticket)
    return {
        "ticket_id": str(ticket.id),
        "ticket_number": _ticket_number(ticket.id),
        "status": ticket.status,
    }


def open_screen(intent: str, lang: str) -> list[dict]:
    """Deep-link actions for an intent, labels in the user's language."""
    lang = lang if lang in LANGS else "en"
    spec = _OPEN_SCREEN.get(intent)
    actions: list[dict] = []
    if spec:
        entry = dict(spec.get(lang, spec["en"]))
        if "tab" in entry:
            entry["tab"] = int(entry["tab"])
        actions.append(entry)
    return actions


# ---------------------------------------------------------------------------
# Language resolution — reuses the existing support-language logic when
# importable, else a simple script/keyword fallback. Always one of en/ur/ar.
# ---------------------------------------------------------------------------
_URDU_MARKERS = {"ے", "ھ", "ٹ", "ڈ", "ڑ", "ں", "ہ", "ھ", "ۂ"}


def _fallback_detect(text: str) -> str:
    t = text or ""
    if any(ch in _URDU_MARKERS for ch in t):
        return "ur"
    if any("\u0600" <= ch <= "\u06FF" for ch in t):
        return "ar"
    lowered = t.lower()
    urdu_roman = ("kaise", "kya", "hai", "mein", "nahi", "nahin", "karein",
                  "karoon", "aap", "mujhe", "batao", "chahiye", "hoon")
    if any(w in _tokens(lowered) for w in urdu_roman):
        return "ur"
    return "en"


def resolve_language(requested: str, text: str) -> str:
    """Resolve reply language; always returns 'en', 'ur', or 'ar'.

    Prefers the existing ai.py detection when it yields ur/ar; explicit
    requested codes win; otherwise falls back to script + Roman-Urdu
    keyword detection (ai.py's detector often returns 'en' for Roman Urdu).
    """
    explicit = (requested or "auto").strip().lower()
    if explicit in LANGS:
        return explicit
    code: str | None = None
    try:
        from app.routers.ai import _resolve_support_language

        code = _resolve_support_language(explicit, text)
    except Exception:
        code = None
    if code in LANGS and code != "en":
        return code
    return _fallback_detect(text)


# ---------------------------------------------------------------------------
# Intent classification (deterministic keyword scoring).
# ---------------------------------------------------------------------------
def classify_intent(text: str, language: str = "en",
                    exclude: frozenset[str] = frozenset()) -> tuple[str, float]:
    """Classify one input → (intent, confidence). No match → (unknown, 0.0).

    `exclude` removes intents from contention (e.g. FEATURES_CREATE when
    the user explicitly asked for a support ticket — the "create" keyword
    would otherwise misfire on "Create a ticket").
    """
    lang = (language or "en").lower()
    if lang not in LANGS:
        lang = "en"
    lowered = (text or "").lower()
    tokens = _tokens(text)

    scores = {intent: _score_intent(tokens, lowered, intent, lang)
              for intent in INTENTS
              if intent != UNKNOWN and intent not in exclude}
    best = max(scores, key=lambda k: scores[k])
    hits = scores[best]
    if hits <= 0:
        return UNKNOWN, 0.0
    conf = _confidence(hits)
    if conf < CONFIDENCE_THRESHOLD:
        return UNKNOWN, conf
    return best, conf


def _last_assistant_intent(history: list[dict]) -> str | None:
    """Recover the last assistant topic: explicit 'intent' key wins, else
    re-classify the last assistant message (it was our own reviewed copy)."""
    if not history:
        return None
    for item in reversed(history):
        if not isinstance(item, dict) or item.get("role") != "assistant":
            continue
        intent = item.get("intent")
        if isinstance(intent, str) and intent in INTENTS:
            return intent
        text = item.get("text") or ""
        recovered, _ = classify_intent(text, "en")
        if recovered != UNKNOWN:
            return recovered
        return None
    return None


def classify_message(text: str, language: str = "auto",
                     history: list[dict] | None = None,
                     exclude: frozenset[str] = frozenset()) -> dict:
    """Full classification: language resolution + pronoun resolution.

    If the message is mostly pronouns (uski/iska/its/this/price?) and there
    is prior history, reuse the last assistant topic's intent.
    """
    lang = resolve_language(language, text)
    tokens = _tokens(text)
    lowered = (text or "").lower()

    if history and tokens and tokens <= _PRONOUNS:
        prev = _last_assistant_intent(history)
        if prev and prev not in exclude:
            return {"intent": prev, "confidence": 0.6, "language": lang,
                    "method": METHOD, "pronoun_resolved": True}

    intent, conf = classify_intent(text, lang, exclude)
    return {"intent": intent, "confidence": conf, "language": lang,
            "method": METHOD, "pronoun_resolved": False}


# ---------------------------------------------------------------------------
# answer() — the public entry point.
# ---------------------------------------------------------------------------
def _fill(template: str, **kwargs) -> str:
    try:
        return template.format(**kwargs)
    except Exception:
        return template


async def answer(intent: str, lang: str, user=None, db=None,
                 history: list[dict] | None = None,
                 confidence: float = 0.0) -> dict:
    """Build the chat reply for an intent.

    Returns {answer, suggestions[3], actions[], escalated, intent,
    language, confidence}. Tools fold real server data into the copy.
    human_agent/contact → escalated=True + create_ticket offer.
    """
    lang = lang if lang in LANGS else "en"
    if intent not in INTENTS:
        intent = UNKNOWN

    template = ANSWERS[intent][lang]
    plan_line = ""
    campaigns_line = ""
    actions = open_screen(intent, lang)
    escalated = intent in (HUMAN_AGENT, CONTACT)

    # Tool: real plan + credits.
    if intent == CREDITS and user is not None and db is not None:
        try:
            plan = await get_my_plan(user, db)
            plan_line = _fill(
                _PLAN_LINE[lang], plan=plan["plan"],
                credits=plan["credits"])
        except Exception as exc:
            logger.warning("support get_my_plan failed: %s", exc)

    # Tool: real campaign summary.
    if intent == FEATURES_GROW and user is not None and db is not None:
        try:
            camps = await my_campaigns(user, db)
            if camps["count"]:
                statuses = ", ".join(
                    f"{s} ×{c}" for s, c in
                    sorted(camps["by_status"].items()))
                campaigns_line = _fill(
                    _CAMPAIGNS_LINE[lang], n=camps["count"],
                    statuses=statuses)
            else:
                campaigns_line = _NO_CAMPAIGNS_LINE[lang]
        except Exception as exc:
            logger.warning("support my_campaigns failed: %s", exc)

    body = _fill(template, plan_line=plan_line,
                 campaigns_line=campaigns_line)

    return {
        "answer": body,
        "suggestions": list(SUGGESTIONS[intent][lang]),
        "actions": actions,
        "escalated": escalated,
        "intent": intent,
        "language": lang,
        "confidence": confidence,
    }


async def handle_message(message: str, language: str = "auto",
                         history: list[dict] | None = None,
                         user=None, db=None) -> dict:
    """One chat turn: classify → (maybe create ticket) → answer.

    Never raises: any failure degrades to the honest fallback reply.
    """
    try:
        history = [h for h in (history or [])[-6:] if isinstance(h, dict)]
        lowered = (message or "").lower()
        # A pure ticket request ("Create a ticket") must never classify as
        # FEATURES_CREATE — the "create" keyword would misfire.
        exclude = frozenset({FEATURES_CREATE}) if _wants_ticket(lowered) else frozenset()
        cls = classify_message(message, language, history, exclude)
        intent = cls["intent"]
        lang = cls["language"]

        # Explicit ticket request: create the ticket, confirm its number.
        ticket_num = None
        if _wants_ticket(lowered) and user is not None and db is not None:
            try:
                t = await create_ticket(
                    user, db,
                    subject=f"support:{intent}",
                    message=(message or "")[:2000])
                ticket_num = t["ticket_number"]
            except Exception as exc:
                logger.warning("support create_ticket failed: %s", exc)

        result = await answer(intent, lang, user=user, db=db,
                              history=history,
                              confidence=cls["confidence"])
        if ticket_num:
            if intent in (UNKNOWN, FEATURES_CREATE):
                # Pure ticket request misclassified (e.g. "Create a ticket"
                # hit the "create" keyword): answer with the confirmation
                # alone instead of an unrelated topic's copy.
                result["answer"] = _fill(
                    _TICKET_CONFIRM[lang], num=ticket_num)
            else:
                result["answer"] = (
                    result["answer"] + " " +
                    _fill(_TICKET_CREATED_LINE[lang], num=ticket_num))
            result["ticket_number"] = ticket_num
            result["escalated"] = True

        # Escalation intents always carry a ticket offer action.
        if result["escalated"]:
            result["actions"].append({
                "type": "create_ticket",
                "label": _CREATE_TICKET_LABEL[lang],
            })
        return result
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("support brain failed: %s", exc)
        lang = resolve_language(language, message)
        return {
            "answer": ANSWERS[UNKNOWN][lang],
            "suggestions": list(SUGGESTIONS[UNKNOWN][lang]),
            "actions": [],
            "escalated": False,
            "intent": UNKNOWN,
            "language": lang,
            "confidence": 0.0,
        }
