#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Conversation Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.conversation_schema import (
    GetConversationMessagesWithPageReq,
    GetConversationMessagesWithPageResp,
    UpdateConversationNameReq,
    UpdateConversationIsPinnedReq,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_conversation_service
from app.services.llmops.conversation_service import ConversationService

router = APIRouter()


@router.get("/{conversation_id}/messages", response_model=dict)
async def get_conversation_messages_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    conversation_id: UUID,
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    created_at: int = Query(0, ge=0),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    conversation_service: Annotated[ConversationService, Depends(get_conversation_service)],
) -> Any:
    """获取指定会话消息列表分页数据"""
    # 1.构建请求对象
    req = GetConversationMessagesWithPageReq(
        current_page=current_page,
        page_size=page_size,
        created_at=created_at,
    )

    # 2.调用服务获取数据
    messages, paginator = await conversation_service.get_conversation_messages_with_page(
        db, conversation_id, req, current_user
    )

    # 3.构建响应结构
    resp_list = [
        GetConversationMessagesWithPageResp(
            id=msg.id,
            conversation_id=msg.conversation_id,
            query=msg.query or "",
            image_urls=msg.image_urls or [],
            answer=msg.answer or "",
            total_token_count=msg.total_token_count or 0,
            latency=msg.latency or 0.0,
            agent_thoughts=[],  # TODO: 加载 agent_thoughts
            created_at=int(msg.created_at.timestamp()) if msg.created_at else 0,
        ) for msg in messages
    ]

    return success_json({
        "list": [msg.model_dump() for msg in resp_list],
        "paginator": paginator,
    })


@router.post("/{conversation_id}/delete", response_model=dict)
async def delete_conversation(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    conversation_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    conversation_service: Annotated[ConversationService, Depends(get_conversation_service)],
) -> Any:
    """根据传递的会话id删除指定的会话"""
    await conversation_service.delete_conversation(db, conversation_id, current_user)
    return success_message("删除会话成功")


@router.post("/{conversation_id}/messages/{message_id}/delete", response_model=dict)
async def delete_message(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    conversation_id: UUID,
    message_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    conversation_service: Annotated[ConversationService, Depends(get_conversation_service)],
) -> Any:
    """根据传递的会话id+消息id删除指定的消息"""
    await conversation_service.delete_message(db, conversation_id, message_id, current_user)
    return success_message("删除消息成功")


@router.get("/{conversation_id}/name", response_model=dict)
async def get_conversation_name(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    conversation_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    conversation_service: Annotated[ConversationService, Depends(get_conversation_service)],
) -> Any:
    """根据传递的会话id获取会话名字"""
    conversation = await conversation_service.get_conversation(db, conversation_id, current_user)
    return success_json({"name": conversation.name})


@router.post("/{conversation_id}/name", response_model=dict)
async def update_conversation_name(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    conversation_id: UUID,
    req: UpdateConversationNameReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    conversation_service: Annotated[ConversationService, Depends(get_conversation_service)],
) -> Any:
    """根据传递的会话id+名字更新会话名字"""
    await conversation_service.update_conversation_name(
        db, conversation_id, req.name, current_user
    )
    return success_message("更新会话名字成功")


@router.post("/{conversation_id}/is-pinned", response_model=dict)
async def update_conversation_is_pinned(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    conversation_id: UUID,
    req: UpdateConversationIsPinnedReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    conversation_service: Annotated[ConversationService, Depends(get_conversation_service)],
) -> Any:
    """根据传递的会话id+置顶选项更新会话置顶状态"""
    await conversation_service.update_conversation_is_pinned(
        db, conversation_id, req.is_pinned, current_user
    )
    return success_message("更新会话置顶状态成功")

