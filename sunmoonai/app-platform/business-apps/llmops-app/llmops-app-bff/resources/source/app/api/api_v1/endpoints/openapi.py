#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps OpenAPI Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.openapi_schema import OpenAPIChatReq
from app.core.response import success_json, compact_generate_response
from app.core.service_factories import get_openapi_service
from app.services.llmops.openapi_service import OpenAPIService

router = APIRouter()


@router.post("/chat", response_model=Any)
async def chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: OpenAPIChatReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    openapi_service: Annotated[OpenAPIService, Depends(get_openapi_service)],
) -> Any:
    """开放Chat对话接口"""
    # 1.调用服务创建会话
    resp = await openapi_service.chat(
        db,
        app_id=req.app_id,
        end_user_id=req.end_user_id,
        conversation_id=req.conversation_id,
        query=req.query,
        image_urls=req.image_urls,
        stream=req.stream,
        user=current_user
    )

    # 2.返回流式响应或普通响应
    return compact_generate_response(resp)

