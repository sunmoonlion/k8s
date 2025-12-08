#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps OAuth Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.oauth_schema import (
    AuthorizeReq,
    AuthorizeResp,
)
from app.core.response import success_json
from app.core.service_factories import get_oauth_service
from app.services.llmops.oauth_service import OAuthService

router = APIRouter()


@router.get("/{provider_name}", response_model=dict)
async def provider(
    *,
    provider_name: str,
    oauth_service: Annotated[OAuthService, Depends(get_oauth_service)],
) -> Any:
    """根据传递的提供商名字获取授权认证重定向地址"""
    # 1.根据provider_name获取授权服务提供商
    oauth = await oauth_service.get_oauth_by_provider_name(provider_name)

    # 2.调用函数获取授权地址
    redirect_url = await oauth.get_authorization_url()

    return success_json({"redirect_url": redirect_url})


@router.post("/authorize/{provider_name}", response_model=AuthorizeResp)
async def authorize(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    provider_name: str,
    req: AuthorizeReq,
    oauth_service: Annotated[OAuthService, Depends(get_oauth_service)],
) -> Any:
    """根据传递的提供商名字+code获取第三方授权信息"""
    # 1.调用服务登录账号
    credential = await oauth_service.oauth_login(
        db, provider_name, req.code
    )

    return AuthorizeResp(
        access_token=credential["access_token"],
        expire_at=credential["expire_at"],
    )

