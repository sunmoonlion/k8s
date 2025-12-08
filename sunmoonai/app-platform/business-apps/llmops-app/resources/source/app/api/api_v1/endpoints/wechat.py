#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps WeChat Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.core.service_factories import get_wechat_service
from app.services.llmops.wechat_service import WechatService

router = APIRouter()


@router.get("/{app_id}")
@router.post("/{app_id}")
async def wechat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    request: Request,
    wechat_service: Annotated[WechatService, Depends(get_wechat_service)],
) -> Any:
    """Agent微信API校验与消息推送"""
    # TODO: 实现微信消息处理逻辑
    response = await wechat_service.wechat(db, app_id, request)
    return response

