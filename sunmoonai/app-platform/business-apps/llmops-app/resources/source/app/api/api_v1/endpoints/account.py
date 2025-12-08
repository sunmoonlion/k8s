#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Account Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.account_schema import (
    GetCurrentUserResp,
    UpdatePasswordReq,
    UpdateNameReq,
    UpdateAvatarReq,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_account_service
from app.services.llmops.account_service import AccountService

router = APIRouter()


@router.get("/", response_model=GetCurrentUserResp)
async def get_current_user(
    *,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """获取当前登录用户信息"""
    # User 模型没有 avatar, last_login_at, last_login_ip 字段，返回默认值
    return GetCurrentUserResp(
        id=current_user.id,
        name=current_user.full_name or "",
        email=current_user.email,
        avatar="",  # User 模型没有 avatar 字段
        last_login_at=None,  # User 模型没有 last_login_at 字段
        last_login_ip="",  # User 模型没有 last_login_ip 字段
        created_at=int(current_user.created.timestamp()) if current_user.created else 0,
    )


@router.post("/password", response_model=dict)
async def update_password(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: UpdatePasswordReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> Any:
    """更新用户密码"""
    await account_service.update_password(
        db, current_user, req.password
    )
    return success_message("更新密码成功")


@router.post("/name", response_model=dict)
async def update_name(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: UpdateNameReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> Any:
    """更新用户名称"""
    await account_service.update_name(
        db, current_user, req.name
    )
    return success_message("更新用户名称成功")


@router.post("/avatar", response_model=dict)
async def update_avatar(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: UpdateAvatarReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> Any:
    """更新用户头像"""
    await account_service.update_avatar(
        db, current_user, req.avatar
    )
    return success_message("更新用户头像成功")

