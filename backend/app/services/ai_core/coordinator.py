"""Ask Virello coordinator — intent → module dispatch with shared context.

The main flow:
  1. classify intent (keyword heuristic v1, labeled)
  2. load/create conversation + per-user AIContext
  3. dispatch to the mapped module:
     - live modules call REAL existing services/endpoints
     - unbuilt vision modules (commerce) return an honest "coming soon"
       message — functionality is NEVER faked (academy and entertainment
       went live in Phases 5 and 6 and now dispatch to real services)
  4. persist user + assistant messages, log the intent, merge context
  5. return a structured response

Multi-module chaining: when the input implies several intents
(e.g. "create a post and grow it"), step 1 executes and the rest are
returned as suggested actions. Paid/irreversible steps are NEVER
auto-executed.
"""
from __future__ import annotations

import logging
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.core import User
from app.models.academy import Lesson
from app.models.ai_core import AIIntentLog
from app.services.ai.base import AIProvider, AIRequest, get_ai_provider
from app.services.ai_core import router as intent_router
from app.services.ai_core.context import (
    add_message,
    get_context,
    get_or_create_conversation,
    update_context,
)
from app.services.language.detector import detect_primary_code

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Localized reply templates. {x} placeholders are filled at runtime.
# ---------------------------------------------------------------------------
_T: dict[str, dict[str, str]] = {
    "analyze_no_url": {
        "en": ("Paste a post or video link and I'll run it through the Viral Lab — "
               "hook, clarity, hashtags, media and CTA — then suggest improvements. "
               "Analysis is heuristic (v1), never a promise of virality."),
        "ur": ("Apni post ya video ka link bhejo — Viral Lab is ka tajziya karega "
               "(hook, wazahat, hashtags, media, CTA) aur behtri ki tajaweez dega. "
               "Tajziya heuristic (v1) hai, virality ki guarantee nahi."),
        "ar": ("الصق رابط منشور أو فيديو وسأحلله في مختبر الانتشار — الخطاف، الوضوح، "
               "الوسوم، الوسائط، والدعوة — ثم أقترح تحسينات. التحليل استدلالي (v1) "
               "وليس وعدًا بالانتشار."),
    },
    "analyze_fetch_failed": {
        "en": "I couldn't fetch that link ({reason}). You can retry it directly with POST /api/v1/analysis/analyze.",
        "ur": "Ye link fetch nahi ho saka ({reason}). Aap POST /api/v1/analysis/analyze se dobara try kar sakte hain.",
        "ar": "تعذّر جلب هذا الرابط ({reason}). يمكنك إعادة المحاولة عبر POST /api/v1/analysis/analyze.",
    },
    "grow": {
        "en": ("Here's how the AI Growth Agent would grow this — analyze → discover "
               "legitimate audience segments → build a campaign strategy → launch "
               "only after your approval → measure real results → optimize. "
               "I never auto-launch paid campaigns, and I never fabricate reach, "
               "views or sales."),
        "ur": ("AI Growth Agent is tarah grow karega — tajziya → jaiz audience segments "
               "talash karna → campaign strategy → sirf aap ki approval ke baad launch → "
               "asal nataij ki paimaish → behtri. Main paid campaign khud launch nahi "
               "karta aur reach/views/sales kabhi jaali nahi banata."),
        "ar": ("هكذا سينمّي وكيل النمو بالذكاء الاصطناعي هذا — تحليل ← اكتشاف شرائح "
               "جمهور شرعية ← بناء استراتيجية حملة ← الإطلاق فقط بعد موافقتك ← قياس "
               "نتائج حقيقية ← تحسين. لا أُطلق حملات مدفوعة تلقائيًا أبدًا، ولا أختلق "
               "الوصول أو المشاهدات أو المبيعات."),
    },
    "discover": {
        "en": ("Open Discover for trending topics, AI Picks and your Following feed. "
               "Tell me your interests (e.g. tech, fashion, fitness) and I'll point "
               "you to the right surface — or set them with PUT /api/v1/discovery/interests."),
        "ur": ("Discover me trending topics, AI Picks aur Following feed dekho. "
               "Apni dilchaspiyan batao (jaise tech, fashion, fitness) — main sahi "
               "jagah ki taraf ishara karunga."),
        "ar": ("افتح «اكتشف» للمواضيع الرائجة واختيارات الذكاء الاصطناعي وخلاصة المتابَعة. "
               "أخبرني باهتماماتك وسأوجهك إلى المكان المناسب."),
    },
    "support_fallback": {
        "en": ("I'm Virello's AI assistant. I can help with how Virello works, plans "
               "(Free Grow vs Paid Boost), payments (PayPal, Payoneer, Google Pay), "
               "and account issues. What do you need help with?"),
        "ur": ("Main Virello ka AI assistant hoon. Virello kaise kaam karta hai, plans "
               "(Free Grow vs Paid Boost), payments (PayPal, Payoneer, Google Pay) aur "
               "account ke masail me madad kar sakta hoon. Kya madad chahiye?"),
        "ar": ("أنا مساعد Virello الذكي. يمكنني المساعدة في كيفية عمل Virello، والخطط "
               "والمدفوعات (PayPal وPayoneer وGoogle Pay) ومشاكل الحساب. بمَ أساعدك؟"),
    },
    "coming_soon": {
        "en": "{name} is coming in Phase {phase} of the Virello evolution. {detail} I'll announce it here the moment it lands — nothing is faked in the meantime.",
        "ur": "{name} Virello evolution ke Phase {phase} me aa raha hai. {detail} Jaisay hi launch hoga, yahin elaan karunga — tab tak kuch jaali nahi banaya jayega.",
        "ar": "{name} قادم في المرحلة {phase} من تطور Virello. {detail} سأعلن عنه هنا فور إطلاقه — ولن يُختلق أي شيء في هذه الأثناء.",
    },
    "unknown": {
        "en": ("I'm not sure what you need yet. I can: create content ideas, analyze "
               "a post link (Viral Lab), plan growth for a campaign, surface "
               "discovery picks, or answer support questions. What would you like to do?"),
        "ur": ("Mujhe abhi samajh nahi aaya aap kya chahte hain. Main ye kar sakta hoon: "
               "content ideas banana, post link ka tajziya (Viral Lab), campaign ke liye "
               "growth plan, discovery picks, ya support sawalat ke jawab. Kya karna chahenge?"),
        "ar": ("لست متأكدًا مما تحتاجه بعد. يمكنني: إنشاء أفكار محتوى، تحليل رابط منشور "
               "(مختبر الانتشار)، التخطيط لنمو حملة، عرض اختيارات الاكتشاف، أو الإجابة "
               "عن أسئلة الدعم. ماذا تريد أن تفعل؟"),
    },
    "learn_intro": {
        "en": ("🎓 Welcome to the AI Academy! Here are the lessons available right now — "
               "open one to learn, take the quiz, and I'll track your progress:"),
        "ur": ("🎓 AI Academy me khush aamdeed! Ye lessons abhi available hain — "
               "koi aik kholo, quiz do, aur main aapki progress track karunga:"),
        "ar": ("🎓 مرحبًا بك في أكاديمية الذكاء الاصطناعي! هذه الدروس متاحة الآن — "
               "افتح واحدًا وتعلّم وأجب عن الاختبار وسأتتبع تقدمك:"),
    },
    "learn_no_lessons": {
        "en": "🎓 The AI Academy is ready, but no lessons are published yet — check back soon.",
        "ur": "🎓 AI Academy tayyar hai, lekin abhi koi lesson publish nahi hua — jald wapas check karein.",
        "ar": "🎓 أكاديمية الذكاء الاصطناعي جاهزة، لكن لا توجد دروس منشورة بعد — عُد قريبًا.",
    },
    "entertain_intro": {
        "en": ("🎭 Ready for a break? I can write you an original uplifting short story "
               "or dream up a comic strip idea — just give me a topic."),
        "ur": ("🎭 Break ka waqt? Main aapke liye aik original achhi kahani likh sakta hoon "
               "ya comic strip ka idea bana sakta hoon — bas topic batao."),
        "ar": ("🎭 مستعد لاستراحة؟ يمكنني كتابة قصة قصيرة أصلية مبهجة لك أو ابتكار "
               "فكرة شريط مصور — فقط أعطني موضوعًا."),
    },
    "dev_note": {
        "en": "\n\n_(Development preview — heuristic output. Connect a production AI provider for final results.)_",
        "ur": "\n\n_(Development preview — heuristic output. Hatmi nataij ke liye production AI provider connect karein.)_",
        "ar": "\n\n_(معاينة تطويرية — مخرجات استدلالية. اربط موفر ذكاء اصطناعي إنتاجيًا للنتائج النهائية.)_",
    },
}

_COMING_SOON_DETAIL = {
    "shop": {
        "en": "It will bring product discovery, comparison and creator-to-customer journeys.",
        "ur": "Is me product discovery, comparison aur creator-to-customer journeys hongi.",
        "ar": "سيشمل اكتشاف المنتجات والمقارنة ورحلات المبدع إلى العميل.",
        "name_en": "🛍️ AI Commerce (Shop)",
    },
    "learn": {
        "en": "It will bring short AI-powered lessons, quizzes and progress tracking.",
        "ur": "Is me chhote AI lessons, quizzes aur progress tracking hogi.",
        "ar": "سيشمل دروسًا قصيرة بالذكاء الاصطناعي واختبارات وتتبعًا للتقدم.",
        "name_en": "🎓 AI Academy",
    },
    "entertain": {
        "en": "It will bring AI stories, comics and interactive short-form entertainment.",
        "ur": "Is me AI kahaniyan, comics aur interactive entertainment hoga.",
        "ar": "سيشمل قصص الذكاء الاصطناعي والقصص المصورة والترفيه التفاعلي.",
        "name_en": "🎭 AI Entertainment",
    },
}

_ACTION_LABELS = {
    "analyze_endpoint": {"en": "Analyze a link (API)", "ur": "Link ka tajziya (API)", "ar": "تحليل رابط (API)"},
    "set_interests": {"en": "Set my interests", "ur": "Meri dilchaspiyan set karo", "ar": "تعيين اهتماماتي"},
    "open_discover": {"en": "Open Discover feed", "ur": "Discover feed kholo", "ar": "فتح خلاصة اكتشف"},
    "build_campaign": {"en": "Draft a campaign (approval required)", "ur": "Campaign ka draft (approval zaroori)", "ar": "مسودة حملة (تتطلب موافقة)"},
    "growth_loops": {"en": "View growth loops", "ur": "Growth loops dekho", "ar": "عرض حلقات النمو"},
    "support": {"en": "Ask support", "ur": "Support se poocho", "ar": "اسأل الدعم"},
    "open_academy": {"en": "Open Academy", "ur": "Academy kholo", "ar": "فتح الأكاديمية"},
    "open_entertain": {"en": "Open Entertainment", "ur": "Entertainment kholo", "ar": "فتح الترفيه"},
}


def _t(key: str, lang: str, **kw: str) -> str:
    lang = lang if lang in ("en", "ur", "ar") else "en"
    return _T[key][lang].format(**kw)


def _label(key: str, lang: str) -> str:
    lang = lang if lang in ("en", "ur", "ar") else "en"
    return _ACTION_LABELS[key][lang]


def _detect_language(text: str, user: User) -> str:
    try:
        code = detect_primary_code(text)
    except Exception:
        code = ""
    if code in ("en", "ur", "ar"):
        return code
    pref = (getattr(user, "preferred_language", "") or "en").lower()
    return pref if pref in ("en", "ur", "ar") else "en"


# ---------------------------------------------------------------------------
# Module dispatchers (live modules call REAL services; unbuilt ones are honest)
# ---------------------------------------------------------------------------
async def _dispatch_create(
    db: AsyncSession, text: str, lang: str, provider: AIProvider | None
) -> tuple[str, list[dict], bool, str | None]:
    """Content ideas via the AI provider ABC (dev/heuristic fallback labeled)."""
    prov = provider or get_ai_provider()
    system = (
        "You are Virello's Creator assistant. Generate 3 short, original content "
        "ideas (hook + format + one-line brief) for the user's request. "
        "Reply in the user's language. Never promise virality, reach or sales."
    )
    try:
        resp = await prov.complete(
            AIRequest(agent="creator", system=system, user=text,
                      max_tokens=600, temperature=0.7, json_mode=False)
        )
        reply = resp.text.strip()
        dev = bool(resp.dev)
        provider_name: str | None = resp.provider
    except Exception as exc:  # fail closed, stay honest
        logger.warning("creator provider failed: %s", exc)
        reply = _t("support_fallback", lang)
        dev, provider_name = True, None
    if dev:
        reply += _t("dev_note", lang)
    return reply, [], dev, provider_name


async def _dispatch_analyze(
    db: AsyncSession, text: str, lang: str
) -> tuple[str, list[dict], bool, str | None]:
    """Viral Lab: run the REAL analysis engine when a link is present."""
    urls = intent_router.extract_urls(text)
    if not urls:
        return (
            _t("analyze_no_url", lang),
            [{
                "label": _label("analyze_endpoint", lang),
                "kind": "api",
                "method": "POST",
                "path": "/api/v1/analysis/analyze",
                "body": {"url": "<post-or-video-url>"},
            }],
            True, None,
        )
    url = urls[0]
    try:
        from app.services.analysis.service import analyze_post, analysis_summary
        row = await analyze_post(url, db)
        summary = analysis_summary(row)
        scores = summary.get("scores", {}) if isinstance(summary, dict) else {}
        lines = [f"• {k}: {v}" for k, v in list(scores.items())[:6]]
        reply = {
            "en": f"Viral Lab analysis for {url} (heuristic v1 — not a promise of virality):\n" + "\n".join(lines),
            "ur": f"{url} ka Viral Lab tajziya (heuristic v1 — virality ki guarantee nahi):\n" + "\n".join(lines),
            "ar": f"تحليل مختبر الانتشار لـ {url} (استدلالي v1 — ليس وعدًا بالانتشار):\n" + "\n".join(lines),
        }[lang if lang in ("en", "ur", "ar") else "en"]
        return reply, [], True, None
    except Exception as exc:
        logger.warning("analysis engine failed for %s: %s", url, exc)
        reason = str(exc)[:160] or "fetch failed"
        return (
            _t("analyze_fetch_failed", lang, reason=reason),
            [{
                "label": _label("analyze_endpoint", lang),
                "kind": "api",
                "method": "POST",
                "path": "/api/v1/analysis/analyze",
                "body": {"url": url},
            }],
            True, None,
        )


def _dispatch_grow(lang: str) -> tuple[str, list[dict], bool, str | None]:
    """Growth plan. Suggests actions only — NEVER auto-creates/launches."""
    actions = [
        {
            "label": _label("build_campaign", lang),
            "kind": "api",
            "method": "POST",
            "path": "/api/v1/ads/campaigns",
            "note": "draft only — advertiser approval gate required before launch",
        },
        {
            "label": _label("growth_loops", lang),
            "kind": "api",
            "method": "GET",
            "path": "/api/v1/growth/loops",
        },
    ]
    return _t("grow", lang), actions, True, None


def _dispatch_discover(lang: str) -> tuple[str, list[dict], bool, str | None]:
    actions = [
        {"label": _label("open_discover", lang), "kind": "api",
         "method": "GET", "path": "/api/v1/discovery/feed"},
        {"label": _label("set_interests", lang), "kind": "api",
         "method": "PUT", "path": "/api/v1/discovery/interests",
         "body": {"interests": ["<topic>"]}},
    ]
    return _t("discover", lang), actions, True, None


async def _dispatch_support(
    text: str, lang: str, provider: AIProvider | None
) -> tuple[str, list[dict], bool, str | None]:
    """Support answers via provider; deterministic honest fallback."""
    prov = provider or get_ai_provider()
    system = (
        "You are Virello AI Support. Answer briefly and honestly about the "
        "Virello app: AI growth manager, Free Grow (organic, $0) vs Paid Boost "
        "packages (Starter $10/7d, Growth $25/14d, Pro $50/30d, Scale $100/30d), "
        "payments via PayPal/Payoneer/Google Pay only (no Stripe), OAuth-only "
        "social connections (never passwords), no fake engagement ever. "
        "Reply in the user's language. If unsure, say so."
    )
    try:
        resp = await prov.complete(
            AIRequest(agent="support", system=system, user=text,
                      max_tokens=400, temperature=0.3, json_mode=False)
        )
        reply = resp.text.strip()
        dev = bool(resp.dev)
        provider_name: str | None = resp.provider
    except Exception as exc:
        logger.warning("support provider failed: %s", exc)
        return _t("support_fallback", lang), [], True, None
    if dev:
        reply += _t("dev_note", lang)
    return reply, [], dev, provider_name


def _dispatch_coming_soon(intent: str, lang: str) -> tuple[str, list[dict], bool, str | None]:
    info = intent_router.module_for(intent)
    detail = _COMING_SOON_DETAIL[intent]
    name = detail.get("name_en", info["module"])
    reply = _t(
        "coming_soon", lang,
        name=name, phase=str(info.get("phase", "?")),
        detail=detail[lang if lang in ("en", "ur", "ar") else "en"],
    )
    return reply, [], True, None


async def _dispatch_learn(
    db: AsyncSession, lang: str
) -> tuple[str, list[dict], bool, str | None]:
    """AI Academy: list REAL published lessons grouped by category.

    Real DB data only — an honest empty message when nothing is seeded.
    """
    lang = lang if lang in ("en", "ur", "ar") else "en"
    actions = [{
        "type": "open",
        "target": "academy",
        "label": _label("open_academy", lang),
    }]
    rows = (
        (await db.execute(
            select(Lesson.title, Lesson.category)
            .where(Lesson.is_published.is_(True))
            .order_by(Lesson.order_index.asc(), Lesson.created_at.asc())
            .limit(30)
        ))
        .all()
    )
    if not rows:
        return _t("learn_no_lessons", lang), actions, True, None
    grouped: dict[str, list[str]] = {}
    for title, category in rows:
        grouped.setdefault(category or "general", []).append(title)
    lines = [f"• {cat}: " + "; ".join(titles[:5])
             for cat, titles in sorted(grouped.items())]
    reply = _t("learn_intro", lang) + "\n" + "\n".join(lines)
    return reply, actions, True, None


def _dispatch_entertain(lang: str) -> tuple[str, list[dict], bool, str | None]:
    """AI Entertainment: short invite; the real generation lives in
    POST /api/v1/entertain/story and /comic-idea (dev-labeled)."""
    lang = lang if lang in ("en", "ur", "ar") else "en"
    actions = [{
        "type": "open",
        "target": "entertain",
        "label": _label("open_entertain", lang),
    }]
    return _t("entertain_intro", lang), actions, True, None


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
async def handle_ask(
    db: AsyncSession,
    user: User,
    text: str,
    conversation_id: uuid.UUID | None = None,
    provider: AIProvider | None = None,
    language: str | None = None,
) -> dict:
    """Classify → dispatch → persist → update context → structured response."""
    text = (text or "").strip()
    if not text:
        raise ValueError("text is required")

    lang = (language or "").lower() or _detect_language(text, user)
    intent, confidence = intent_router.classify_intent(text, lang)
    chained = intent_router.detect_intents(text, lang)
    module_info = intent_router.module_for(intent)

    convo = await get_or_create_conversation(
        db, user.id, conversation_id, title=text[:60] or "Ask Virello")
    await add_message(db, convo.id, "user", text, intent=intent,
                      module=module_info["module"])
    ctx = await get_context(db, user.id)

    # --- dispatch primary intent ---
    if intent == intent_router.CREATE_CONTENT:
        reply, actions, dev, provider_name = await _dispatch_create(db, text, lang, provider)
    elif intent == intent_router.ANALYZE_CONTENT:
        reply, actions, dev, provider_name = await _dispatch_analyze(db, text, lang)
    elif intent == intent_router.GROW:
        reply, actions, dev, provider_name = _dispatch_grow(lang)
    elif intent == intent_router.DISCOVER:
        reply, actions, dev, provider_name = _dispatch_discover(lang)
    elif intent == intent_router.SUPPORT:
        reply, actions, dev, provider_name = await _dispatch_support(text, lang, provider)
    elif intent == intent_router.LEARN:
        reply, actions, dev, provider_name = await _dispatch_learn(db, lang)
    elif intent == intent_router.ENTERTAIN:
        reply, actions, dev, provider_name = _dispatch_entertain(lang)
    elif intent == intent_router.SHOP:
        reply, actions, dev, provider_name = _dispatch_coming_soon(intent, lang)
    else:  # unknown
        reply, actions, dev, provider_name = _t("unknown", lang), [], True, None

    # --- multi-module chaining: execute step 1, suggest the rest ---
    plan: list[dict] = []
    if len(chained) > 1:
        for i, (ch_intent, ch_conf) in enumerate(chained):
            ch_module = intent_router.module_for(ch_intent)["module"]
            plan.append({
                "step": i + 1,
                "intent": ch_intent,
                "module": ch_module,
                "status": "executed" if i == 0 else "suggested",
                "note": ("Executed now." if i == 0
                         else "Suggested next step — say the word and I'll do it. "
                              "Paid/irreversible steps always need your explicit approval."),
            })
        extra = [intent_router.module_for(c[0])["module"] for c in chained[1:]]
        reply += "\n\n" + {
            "en": f"Multi-step plan detected — I'll also line up: {', '.join(extra)}. Say 'go' and I'll take the next step.",
            "ur": f"Multi-step plan samajh aaya — ye bhi tayyar hain: {', '.join(extra)}. 'Go' kaho to agla qadam uthata hoon.",
            "ar": f"رُصدت خطة متعددة الخطوات — سأجهز أيضًا: {', '.join(extra)}. قل «انطلق» وسأتخذ الخطوة التالية.",
        }[lang if lang in ("en", "ur", "ar") else "en"]

    # --- persist assistant turn + intent audit ---
    await add_message(
        db, convo.id, "assistant", reply, intent=intent,
        module=module_info["module"],
        meta={"method": intent_router.METHOD, "confidence": confidence,
              "dev": dev, "provider": provider_name},
    )
    db.add(AIIntentLog(
        user_id=user.id, conversation_id=convo.id, raw_input=text[:2000],
        intent=intent, confidence=confidence, module=module_info["module"]))
    await db.commit()

    # --- merge context (summaries append, entities/preferences merge) ---
    await update_context(
        db, user.id,
        summary_addenda=f"[{intent}] {text[:120]}",
        entities={"last_intent": intent, "last_module": module_info["module"]},
    )

    return {
        "intent": intent,
        "confidence": confidence,
        "intents": [{"intent": i, "confidence": c} for i, c in chained],
        "module": module_info["module"],
        "module_status": module_info["status"],
        "method": intent_router.METHOD,
        "reply": reply,
        "reply_language": lang,
        "dev": dev,
        "provider": provider_name,
        "actions": actions,
        "plan": plan,
        "conversation_id": str(convo.id),
        "context_updated": True,
    }
