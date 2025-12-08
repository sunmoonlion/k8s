#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Platform Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.platform_schema import (
    GetWechatConfigResp,
    UpdateWechatConfigReq,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_platform_service
from app.services.llmops.platform_service import PlatformService

router = APIRouter()


@router.get("/{app_id}/wechat-config", response_model=GetWechatConfigResp)
async def get_wechat_config(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    platform_service: Annotated[PlatformService, Depends(get_platform_service)],
) -> Any:
    """根据传递的id获取指定应用的微信配置"""
    # 1.调用服务获取应用的微信公众号配置
    wechat_config = await platform_service.get_wechat_config(db, app_id, current_user)

    # 2.构建响应并返回
    return GetWechatConfigResp.from_model(wechat_config, app_id)


@router.post("/{app_id}/wechat-config", response_model=dict)
async def update_wechat_config(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    req: UpdateWechatConfigReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    platform_service: Annotated[PlatformService, Depends(get_platform_service)],
) -> Any:
    """根据传递的应用id更新该应用的微信发布配置"""
    # 1.调用服务并更新应用配置
    await platform_service.update_wechat_config(
        db,
        app_id,
        wechat_app_id=req.wechat_app_id,
        wechat_app_secret=req.wechat_app_secret,
        wechat_token=req.wechat_token,
        user=current_user
    )

    return success_message("更新Agent应用微信公众号配置成功")

