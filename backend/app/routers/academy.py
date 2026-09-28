"""AI Academy API — Phase 5 of the Virello evolution.

Lessons are public to browse; progress/quizzes need auth. Quiz answers
are graded server-side (answer indices never sent to the client before
grading). Admin-only lesson generation uses get_ai_provider() with strict
validation; provider failures return honest 502s and dev output is labeled.
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.models.academy import Lesson, LessonProgress
from app.models.core import User
from app.routers.admin import require_admin
from app.services.ai.base import (
    AIProviderError,
    AIProviderNotConfigured,
    AIRequest,
    get_ai_provider,
)

router = APIRouter(prefix="/academy", tags=["academy"])

PASS_RATIO = 0.6


# ---------------------------------------------------------------------------
# Out models
# ---------------------------------------------------------------------------
class LessonListOut(BaseModel):
    id: str
    title: str
    description: str
    category: str
    level: str
    language: str
    order_index: int
    has_quiz: bool


class LessonSectionOut(BaseModel):
    heading: str
    body: str


class QuizQuestionOut(BaseModel):
    q: str
    options: list[str]


class LessonDetailOut(BaseModel):
    id: str
    title: str
    description: str
    category: str
    level: str
    language: str
    content: list[LessonSectionOut]
    quiz: list[QuizQuestionOut] | None = None


class StartOut(BaseModel):
    status: str
    lesson_id: str


class QuizIn(BaseModel):
    answers: list[int]


class QuizResultItem(BaseModel):
    question_index: int
    correct: bool
    correct_option: int
    explanation: str


class QuizOut(BaseModel):
    score: int
    total: int
    passed: bool
    results: list[QuizResultItem]


class ProgressItemOut(BaseModel):
    lesson_id: str
    status: str
    quiz_score: float | None = None
    completed_at: str | None = None


class ProgressOut(BaseModel):
    progress: list[ProgressItemOut]
    stats: dict


class GenerateLessonIn(BaseModel):
    topic: str = Field(..., min_length=3, max_length=200)
    level: str = Field(default="beginner", pattern="^(beginner|intermediate|advanced)$")
    language: str = Field(default="en", pattern="^(en|ur|ar)$")
    category: str = Field(
        default="content", pattern="^(content|growth|commerce|marketing)$"
    )


class GenerateLessonOut(BaseModel):
    lesson_id: str
    title: str
    dev: bool
    provider: str | None = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _parse_uuid(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except (ValueError, AttributeError):
        raise HTTPException(404, "Lesson not found")


async def _get_lesson(db: AsyncSession, lesson_id: uuid.UUID) -> Lesson:
    res = await db.execute(
        select(Lesson).where(Lesson.id == lesson_id, Lesson.is_published.is_(True))
    )
    lesson = res.scalar_one_or_none()
    if lesson is None:
        raise HTTPException(404, "Lesson not found")
    return lesson


def _detail_out(lesson: Lesson) -> LessonDetailOut:
    """Build the client-safe detail view: quiz ships questions + options
    only — no answer indices, no explanations (server grades)."""
    content_raw = (lesson.content_json or {}).get("sections", [])
    sections = [
        LessonSectionOut(heading=str(s.get("heading", "")),
                         body=str(s.get("body", "")))
        for s in content_raw
        if isinstance(s, dict)
    ]
    quiz: list[QuizQuestionOut] | None = None
    if lesson.quiz_json and isinstance(lesson.quiz_json.get("questions"), list):
        quiz = [
            QuizQuestionOut(
                q=str(q.get("q", "")),
                options=[str(o) for o in (q.get("options") or [])],
            )
            for q in lesson.quiz_json["questions"]
            if isinstance(q, dict)
        ]
    return LessonDetailOut(
        id=str(lesson.id),
        title=lesson.title,
        description=lesson.description,
        category=lesson.category,
        level=lesson.level,
        language=lesson.language,
        content=sections,
        quiz=quiz,
    )


async def _upsert_progress(
    db: AsyncSession,
    user: User,
    lesson_id: uuid.UUID,
    status: str | None = None,
    quiz_score: float | None = None,
    completed_at: datetime | None = None,
) -> LessonProgress:
    res = await db.execute(
        select(LessonProgress).where(
            LessonProgress.user_id == user.id,
            LessonProgress.lesson_id == lesson_id,
        )
    )
    row = res.scalar_one_or_none()
    if row is None:
        row = LessonProgress(user_id=user.id, lesson_id=lesson_id, status="started")
        db.add(row)
    if status is not None:
        row.status = status
    if quiz_score is not None:
        row.quiz_score = quiz_score
    if completed_at is not None:
        row.completed_at = completed_at
    await db.commit()
    await db.refresh(row)
    return row


# ---------------------------------------------------------------------------
# Public: browse + detail
# ---------------------------------------------------------------------------
@router.get("/lessons", response_model=list[LessonListOut])
async def list_lessons(
    category: str | None = Query(default=None),
    level: str | None = Query(default=None),
    language: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Lesson)
        .where(Lesson.is_published.is_(True))
        .order_by(Lesson.order_index.asc(), Lesson.created_at.asc())
    )
    if category:
        stmt = stmt.where(Lesson.category == category)
    if level:
        stmt = stmt.where(Lesson.level == level)
    if language:
        stmt = stmt.where(Lesson.language == language)
    rows = (await db.execute(stmt)).scalars().all()
    return [
        LessonListOut(
            id=str(l.id),
            title=l.title,
            description=l.description,
            category=l.category,
            level=l.level,
            language=l.language,
            order_index=l.order_index,
            has_quiz=bool(l.quiz_json and l.quiz_json.get("questions")),
        )
        for l in rows
    ]


@router.get("/lessons/{lesson_id}", response_model=LessonDetailOut)
async def lesson_detail(
    lesson_id: str,
    db: AsyncSession = Depends(get_db),
):
    lesson = await _get_lesson(db, _parse_uuid(lesson_id))
    return _detail_out(lesson)


# ---------------------------------------------------------------------------
# Authenticated: progress + quizzes
# ---------------------------------------------------------------------------
@router.post("/lessons/{lesson_id}/start", response_model=StartOut)
async def start_lesson(
    lesson_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = await _get_lesson(db, _parse_uuid(lesson_id))
    await _upsert_progress(db, user, lesson.id, status="started")
    return StartOut(status="started", lesson_id=str(lesson.id))


@router.post("/lessons/{lesson_id}/quiz", response_model=QuizOut)
async def grade_quiz(
    lesson_id: str,
    body: QuizIn,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = await _get_lesson(db, _parse_uuid(lesson_id))
    questions = (lesson.quiz_json or {}).get("questions") or []
    if not questions:
        raise HTTPException(404, "This lesson has no quiz")
    if len(body.answers) != len(questions):
        raise HTTPException(
            422,
            f"Expected {len(questions)} answers, got {len(body.answers)}",
        )
    results: list[QuizResultItem] = []
    score = 0
    for i, q in enumerate(questions):
        correct_idx = q.get("answer")
        options = q.get("options") or []
        is_valid = (
            isinstance(correct_idx, int)
            and 0 <= correct_idx < len(options)
            and isinstance(body.answers[i], int)
            and 0 <= body.answers[i] < len(options)
        )
        correct = bool(is_valid and body.answers[i] == correct_idx)
        score += 1 if correct else 0
        results.append(
            QuizResultItem(
                question_index=i,
                correct=correct,
                correct_option=correct_idx if isinstance(correct_idx, int) else -1,
                explanation=str(q.get("explanation", "")),
            )
        )
    total = len(questions)
    passed = (score / total) >= PASS_RATIO if total else False
    await _upsert_progress(
        db, user, lesson.id, status="started", quiz_score=float(score)
    )
    return QuizOut(score=score, total=total, passed=passed, results=results)


@router.post("/lessons/{lesson_id}/complete", response_model=StartOut)
async def complete_lesson(
    lesson_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = await _get_lesson(db, _parse_uuid(lesson_id))
    await _upsert_progress(
        db, user, lesson.id, status="completed", completed_at=datetime.utcnow()
    )
    return StartOut(status="completed", lesson_id=str(lesson.id))


@router.get("/my/progress", response_model=ProgressOut)
async def my_progress(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    rows = (
        (await db.execute(
            select(LessonProgress)
            .where(LessonProgress.user_id == user.id)
            .order_by(LessonProgress.updated_at.desc())
        ))
        .scalars()
        .all()
    )
    progress = [
        ProgressItemOut(
            lesson_id=str(r.lesson_id),
            status=r.status,
            quiz_score=r.quiz_score,
            completed_at=r.completed_at.isoformat() if r.completed_at else None,
        )
        for r in rows
    ]
    scores = [r.quiz_score for r in rows if r.quiz_score is not None]
    stats = {
        "started": sum(1 for r in rows if r.status == "started"),
        "completed": sum(1 for r in rows if r.status == "completed"),
        "avg_score": round(sum(scores) / len(scores), 2) if scores else 0.0,
    }
    return ProgressOut(progress=progress, stats=stats)


# ---------------------------------------------------------------------------
# Admin: AI-generated lessons (draft, unpublished)
# ---------------------------------------------------------------------------
_GENERATE_SYSTEM = (
    "You are the Virello AI Academy lesson writer. Write an original, practical "
    "marketing/growth lesson in the requested language. Keep advice honest: no "
    "fake engagement, no bots, no bought followers, no guaranteed virality. "
    "Respond with ONLY a JSON object."
)

_GENERATE_USER_TEMPLATE = """Write a lesson on the topic: "{topic}".
Language: {language}. Level: {level}. Category: {category}.

Return ONLY valid JSON with this exact shape:
{{
  "title": "short lesson title",
  "description": "1-2 sentence description",
  "sections": [ {{"heading": "...", "body": "3-6 sentences of real, actionable advice"}}, ... 3-5 sections ],
  "quiz": {{ "questions": [
    {{"q": "question text",
      "options": ["A", "B", "C", "D"],
      "answer": 0,
      "explanation": "why this answer is right"}}
    , ... 3-5 questions ] }}
}}
"""


def _validate_generated(payload: dict) -> tuple[str, str, dict, dict]:
    """Strict-validate the provider's lesson JSON. Raises ValueError."""
    if not isinstance(payload, dict):
        raise ValueError("provider returned non-object JSON")
    title = str(payload.get("title", "")).strip()
    description = str(payload.get("description", "")).strip()
    sections = payload.get("sections")
    quiz = payload.get("quiz")
    if not title or not description:
        raise ValueError("missing title/description")
    if not isinstance(sections, list) or not (3 <= len(sections) <= 6):
        raise ValueError("sections must be a list of 3-6")
    for s in sections:
        if not isinstance(s, dict) or not s.get("heading") or not s.get("body"):
            raise ValueError("each section needs heading + body")
    if not isinstance(quiz, dict) or not isinstance(quiz.get("questions"), list):
        raise ValueError("quiz must have questions list")
    questions = quiz["questions"]
    if not (3 <= len(questions) <= 6):
        raise ValueError("quiz needs 3-6 questions")
    for q in questions:
        if not isinstance(q, dict):
            raise ValueError("bad question shape")
        options = q.get("options")
        if not isinstance(options, list) or len(options) != 4:
            raise ValueError("each question needs exactly 4 options")
        if not isinstance(q.get("answer"), int) or not 0 <= q["answer"] < 4:
            raise ValueError("answer must be an index 0-3")
        if not q.get("q") or not q.get("explanation"):
            raise ValueError("each question needs q + explanation")
    return (
        title,
        description,
        {"sections": [{"heading": str(s["heading"]), "body": str(s["body"])}
                       for s in sections]},
        {"questions": [{"q": str(q["q"]),
                        "options": [str(o) for o in q["options"]],
                        "answer": q["answer"],
                        "explanation": str(q["explanation"])}
                       for q in questions]},
    )


@router.post("/generate-lesson", response_model=GenerateLessonOut)
async def generate_lesson(
    body: GenerateLessonIn,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    provider = get_ai_provider()
    try:
        resp = await provider.complete(
            AIRequest(
                agent="academy",
                system=_GENERATE_SYSTEM,
                user=_GENERATE_USER_TEMPLATE.format(
                    topic=body.topic, language=body.language,
                    level=body.level, category=body.category,
                ),
                max_tokens=2500,
                temperature=0.6,
                json_mode=True,
            )
        )
    except (AIProviderError, AIProviderNotConfigured) as exc:
        raise HTTPException(502, f"AI provider failed: {exc}") from exc
    except Exception as exc:  # fail closed, stay honest
        raise HTTPException(502, f"AI provider failed: {exc}") from exc

    try:
        title, description, content_json, quiz_json = _validate_generated(
            json.loads(resp.text)
        )
    except (json.JSONDecodeError, ValueError) as exc:
        raise HTTPException(
            502, f"AI provider returned an invalid lesson: {exc}"
        ) from exc

    max_order = (await db.execute(
        select(func.max(Lesson.order_index))
    )).scalar() or 0
    lesson = Lesson(
        title=title,
        description=description,
        category=body.category,
        level=body.level,
        language=body.language,
        content_json=content_json,
        quiz_json=quiz_json,
        order_index=max_order + 1,
        is_published=False,  # draft — admin reviews before publishing
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)
    return GenerateLessonOut(
        lesson_id=str(lesson.id),
        title=lesson.title,
        dev=bool(resp.dev),
        provider=resp.provider,
    )
