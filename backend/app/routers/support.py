"""Live Chat Support — deterministic brain endpoint.

POST /api/v1/support/chat answers from reviewed EN/UR/AR copy plus real
server-side tools (plan, campaigns, tickets). It never calls an external
AI provider. The endpoint never raises: on any failure it returns a
safe generic reply with HTTP 200.
"""
import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.deps import get_current_user
from app.core.database import get_db
from app.models.core import User

logger = logging.getLogger(__name__)

router = APIRouter()


class ChatHistoryItem(BaseModel):
    role: str = "user"
    text: str = ""


class ChatIn(BaseModel):
    message: str = Field(default="", max_length=4000)
    language: str = "auto"  # "auto" | "en" | "ur" | "ar"
    history: list[ChatHistoryItem] = Field(default_factory=list)


_SAFE_REPLY = {
    "en": ("Something went wrong on our side — I couldn't process that. "
           "Please try again, or create a support ticket from the app's "
           "Profile section."),
    "ur": ("Hamari taraf kuch ghalat ho gaya — main ise process nahi kar "
           "saka. Dobara koshish karein, ya app ke Profile section se "
           "support ticket banayein."),
    "ar": ("حدث خطأ من جانبنا — لم أتمكن من معالجة ذلك. حاول مرة أخرى، أو "
           "أنشئ تذكرة دعم من قسم الملف الشخصي في التطبيق."),
}


@router.post("/chat")
async def chat(body: ChatIn, user: User = Depends(get_current_user),
               db=Depends(get_db)) -> dict:
    """One support chat turn → {answer, suggestions[3], actions[],
    escalated, intent, language, confidence, [ticket_number]}.

    Always HTTP 200. Never raises.
    """
    try:
        from app.services.support import brain

        message = (body.message or "").strip()
        history = [{"role": h.role, "text": h.text} for h in body.history]
        result = await brain.handle_message(
            message, language=body.language or "auto",
            history=history, user=user, db=db)
        return result
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("support chat failed: %s", exc)
        lang = (body.language or "auto").strip().lower()
        if lang not in ("en", "ur", "ar"):
            lang = "en"
        return {
            "answer": _SAFE_REPLY[lang],
            "suggestions": [
                "How does Virello work?",
                "Create a ticket",
                "Talk to a human",
            ],
            "actions": [],
            "escalated": False,
            "intent": "unknown",
            "language": lang,
            "confidence": 0.0,
        }
