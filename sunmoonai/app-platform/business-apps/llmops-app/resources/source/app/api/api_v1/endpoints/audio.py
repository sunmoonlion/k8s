#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Audio Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.audio_schema import MessageToAudioReq
from app.core.response import success_json, compact_generate_response
from app.core.service_factories import get_audio_service
from app.services.llmops.audio_service import AudioService

router = APIRouter()


@router.post("/audio-to-text", response_model=dict)
async def audio_to_text(
    *,
    file: UploadFile = File(...),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    audio_service: Annotated[AudioService, Depends(get_audio_service)],
) -> Any:
    """将语音转换成文本"""
    # 1.调用服务将音频文件转换成文本
    text = await audio_service.audio_to_text(file)

    return success_json({"text": text})


@router.post("/message-to-audio", response_model=Any)
async def message_to_audio(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: MessageToAudioReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    audio_service: Annotated[AudioService, Depends(get_audio_service)],
) -> Any:
    """将消息转换成流式输出音频"""
    # 1.调用服务获取流式事件输出
    response = await audio_service.message_to_audio(
        db, req.message_id, current_user
    )

    # 2.返回流式响应或普通响应
    return compact_generate_response(response)

