#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Assistant Agent Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.assistant_agent_schema import (
    AssistantAgentChat,
    GetAssistantAgentMessagesWithPageReq,
    GetAssistantAgentMessagesWithPageResp,
)
from app.core.response import success_json, success_message, compact_generate_response
from app.core.service_factories import get_assistant_agent_service
from app.services.llmops.assistant_agent_service import AssistantAgentService

router = APIRouter()


@router.post("/chat", response_model=Any)
async def assistant_agent_chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: AssistantAgentChat,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    assistant_agent_service: Annotated[AssistantAgentService, Depends(get_assistant_agent_service)],
) -> Any:
    """与辅助智能体进行对话聊天"""
    # 1.调用服务创建会话响应
    response = await assistant_agent_service.chat(
        db,
        query=req.query,
        image_urls=req.image_urls,
        user=current_user
    )

    # 2.返回流式响应或普通响应
    return compact_generate_response(response)


@router.post("/chat/{task_id}/stop", response_model=dict)
async def stop_assistant_agent_chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    task_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    assistant_agent_service: Annotated[AssistantAgentService, Depends(get_assistant_agent_service)],
) -> Any:
    """停止与辅助智能体的对话聊天"""
    await assistant_agent_service.stop_chat(db, task_id, current_user)
    return success_message("停止辅助Agent会话成功")


@router.get("/messages", response_model=dict)
async def get_assistant_agent_messages_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    created_at: int = Query(0, ge=0),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    assistant_agent_service: Annotated[AssistantAgentService, Depends(get_assistant_agent_service)],
) -> Any:
    """获取与辅助智能体的消息分页列表"""
    # 1.构建请求对象
    req = GetAssistantAgentMessagesWithPageReq(
        current_page=current_page,
        page_size=page_size,
        created_at=created_at,
    )

    # 2.调用服务获取数据
    messages, paginator = await assistant_agent_service.get_conversation_messages_with_page(
        db, req, current_user
    )

    # 3.创建响应数据结构
    resp_list = [
        GetAssistantAgentMessagesWithPageResp(
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


@router.post("/delete-conversation", response_model=dict)
async def delete_assistant_agent_conversation(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    assistant_agent_service: Annotated[AssistantAgentService, Depends(get_assistant_agent_service)],
) -> Any:
    """清空/删除与辅助智能体的聊天会话记录"""
    # 1.调用服务清空辅助Agent会话列表
    await assistant_agent_service.delete_conversation(db, current_user)

    # 2.清空成功后返回消息响应
    return success_message("清空辅助Agent会话成功")

