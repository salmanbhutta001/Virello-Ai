"""Live campaign status over WebSocket: GET /api/v1/campaigns/{id}/stream.

Sends {"status": ..., "updated": ...} every 2s until the campaign reaches a
terminal state (paused/completed). Production: Redis pub/sub instead of polling.
"""
import asyncio
import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.core import Campaign, CampaignStatus

router = APIRouter()

TERMINAL = {CampaignStatus.paused, CampaignStatus.completed}


@router.websocket("/campaigns/{campaign_id}/stream")
async def campaign_stream(websocket: WebSocket, campaign_id: uuid.UUID) -> None:
    await websocket.accept()
    try:
        while True:
            async with SessionLocal() as db:
                res = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
                campaign = res.scalar_one_or_none()
            if campaign is None:
                await websocket.send_json({"error": "campaign not found"})
                break
            await websocket.send_json({
                "id": str(campaign.id),
                "status": campaign.status.value,
                "title": campaign.title,
            })
            if campaign.status in TERMINAL:
                break
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        pass
    finally:
        await websocket.close()
