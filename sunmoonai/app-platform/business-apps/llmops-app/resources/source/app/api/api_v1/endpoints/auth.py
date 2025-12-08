#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Auth Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.auth_schema import (
    PasswordLoginReq,
    PasswordLoginResp,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_account_service
from app.services.llmops.account_service import AccountService

router = APIRouter()


@router.post("/password-login", response_model=PasswordLoginResp)
async def password_login(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: PasswordLoginReq,
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> Any:
    """账号密码登录"""
    access_token, expire_at = await account_service.password_login(
        db, req.email, req.password
    )
    return PasswordLoginResp(
        access_token=access_token,
        expire_at=expire_at,
    )


@router.post("/logout", response_model=dict)
async def logout(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> Any:
    """登出"""
    # TODO: 实现登出逻辑
    await account_service.logout(db, current_user)
    return success_message("登出成功")

