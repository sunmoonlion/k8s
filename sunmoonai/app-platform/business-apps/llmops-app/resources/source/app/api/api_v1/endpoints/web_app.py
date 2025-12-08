#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Web App Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.web_app_schema import (
    WebAppChatReq,
    GetConversationsReq,
    GetConversationsResp,
)
from app.core.response import success_json, success_message, compact_generate_response
from app.core.service_factories import get_web_app_service
from app.services.llmops.web_app_service import WebAppService

router = APIRouter()


@router.get("/{token}", response_model=dict)
async def get_web_app(
    *,
    token: str,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    web_app_service: Annotated[WebAppService, Depends(get_web_app_service)],
) -> Any:
    """根据传递的token凭证标识获取WebApp基础信息"""
    # 1.调用服务根据传递的token获取应用信息
    resp = await web_app_service.get_web_app_info(token)

    # 2.返回成功响应
    return success_json(resp)


@router.post("/{token}/chat", response_model=Any)
async def web_app_chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    token: str,
    req: WebAppChatReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    web_app_service: Annotated[WebAppService, Depends(get_web_app_service)],
) -> Any:
    """根据传递的token+query等信息与WebApp进行对话"""
    # 1.调用服务获取对应响应内容
    response = await web_app_service.web_app_chat(
        db,
        token,
        query=req.query,
        conversation_id=req.conversation_id,
        image_urls=req.image_urls,
        user=current_user
    )

    # 2.返回流式响应或普通响应
    return compact_generate_response(response)


@router.post("/{token}/chat/{task_id}/stop", response_model=dict)
async def stop_web_app_chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    token: str,
    task_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    web_app_service: Annotated[WebAppService, Depends(get_web_app_service)],
) -> Any:
    """根据传递的token+task_id停止与WebApp的对话"""
    await web_app_service.stop_web_app_chat(db, token, task_id, current_user)
    return success_message("停止WebApp会话成功")


@router.get("/{token}/conversations", response_model=dict)
async def get_conversations(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    token: str,
    is_pinned: bool = Query(False),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    web_app_service: Annotated[WebAppService, Depends(get_web_app_service)],
) -> Any:
    """根据传递的token+is_pinned获取指定WebApp下的所有会话列表信息"""
    # 1.调用服务获取会话列表
    conversations = await web_app_service.get_conversations(
        db, token, is_pinned, current_user
    )

    # 2.构建响应并返回
    resp_list = [
        GetConversationsResp(
            id=conv.id,
            name=conv.name,
            summary=conv.summary or "",
            created_at=int(conv.created_at.timestamp()) if conv.created_at else 0,
        ) for conv in conversations
    ]

    return success_json([conv.model_dump() for conv in resp_list])

