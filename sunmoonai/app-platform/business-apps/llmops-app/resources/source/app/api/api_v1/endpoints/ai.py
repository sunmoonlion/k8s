#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps AI Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.ai_schema import (
    OptimizePromptReq,
    GenerateSuggestedQuestionsReq,
)
from app.core.response import success_json, compact_generate_response
from app.core.service_factories import get_ai_service
from app.services.llmops.ai_service import AIService

router = APIRouter()


@router.post("/optimize-prompt", response_model=Any)
async def optimize_prompt(
    *,
    req: OptimizePromptReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    ai_service: Annotated[AIService, Depends(get_ai_service)],
) -> Any:
    """根据传递的预设prompt进行优化"""
    # 1.调用服务优化prompt
    resp = await ai_service.optimize_prompt(req.prompt)

    # 2.返回流式响应或普通响应
    return compact_generate_response(resp)


@router.post("/suggested-questions", response_model=dict)
async def generate_suggested_questions(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: GenerateSuggestedQuestionsReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    ai_service: Annotated[AIService, Depends(get_ai_service)],
) -> Any:
    """根据传递的消息id生成建议问题列表"""
    # 1.调用服务生成建议问题列表
    suggested_questions = await ai_service.generate_suggested_questions_from_message_id(
        db, req.message_id, current_user
    )

    return success_json(suggested_questions)

