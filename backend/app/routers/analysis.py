"""Post/link analysis API — powered by the analysis engine.

POST /analysis/analyze {url} -> platform, fetched metadata, extracted
features, transparent content score (heuristic estimate, never a guarantee).
Results are cached for 7 days.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.core import User
from app.services.analysis.service import analyze_post, analysis_summary

router = APIRouter()


class AnalyzeIn(BaseModel):
    url: str


@router.post("/analyze")
async def analyze(body: AnalyzeIn, db: AsyncSession = Depends(get_db),
                  _user: User = Depends(get_current_user)) -> dict:
    url = (body.url or "").strip()
    if not url.lower().startswith(("http://", "https://")):
        raise HTTPException(400, "Provide a public http(s) post URL")
    row = await analyze_post(url, db)
    return analysis_summary(row)
