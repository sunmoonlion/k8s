#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Key Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.api_key_schema import (
    CreateApiKeyReq,
    UpdateApiKeyReq,
    UpdateApiKeyIsActiveReq,
    GetApiKeysWithPageResp,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_api_key_service
from app.services.llmops.api_key_service import ApiKeyService

router = APIRouter()


@router.post("/", response_model=dict)
async def create_api_key(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: CreateApiKeyReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_key_service: Annotated[ApiKeyService, Depends(get_api_key_service)],
) -> Any:
    """创建API秘钥"""
    api_key = await api_key_service.create_api_key(
        db,
        is_active=req.is_active,
        remark=req.remark,
        user=current_user
    )
    return success_json({"id": str(api_key.id)})


@router.get("/", response_model=dict)
async def get_api_keys_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_key_service: Annotated[ApiKeyService, Depends(get_api_key_service)],
) -> Any:
    """获取API秘钥分页列表数据"""
    from app.schemas.llmops.common import PaginatorReq
    
    req = PaginatorReq(
        current_page=current_page,
        page_size=page_size,
    )
    
    api_keys, paginator = await api_key_service.get_api_keys_with_page(
        db, req, current_user
    )
    
    resp_list = [
        GetApiKeysWithPageResp(
            id=key.id,
            api_key=key.api_key or "",
            is_active=key.is_active or False,
            remark=key.remark or "",
            updated_at=int(key.updated_at.timestamp()) if key.updated_at else 0,
            created_at=int(key.created_at.timestamp()) if key.created_at else 0,
        ) for key in api_keys
    ]
    
    return success_json({
        "list": [key.model_dump() for key in resp_list],
        "paginator": paginator,
    })


@router.post("/{api_key_id}", response_model=dict)
async def update_api_key(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    api_key_id: UUID,
    req: UpdateApiKeyReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_key_service: Annotated[ApiKeyService, Depends(get_api_key_service)],
) -> Any:
    """更新API秘钥"""
    await api_key_service.update_api_key(
        db,
        api_key_id,
        is_active=req.is_active,
        remark=req.remark,
        user=current_user
    )
    return success_message("更新API秘钥成功")


@router.post("/{api_key_id}/is-active", response_model=dict)
async def update_api_key_is_active(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    api_key_id: UUID,
    req: UpdateApiKeyIsActiveReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_key_service: Annotated[ApiKeyService, Depends(get_api_key_service)],
) -> Any:
    """更新API秘钥激活状态"""
    await api_key_service.update_api_key(
        db,
        api_key_id,
        is_active=req.is_active,
        user=current_user
    )
    return success_message("更新API秘钥激活状态成功")


@router.post("/{api_key_id}/delete", response_model=dict)
async def delete_api_key(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    api_key_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_key_service: Annotated[ApiKeyService, Depends(get_api_key_service)],
) -> Any:
    """删除API秘钥"""
    await api_key_service.delete_api_key(db, api_key_id, current_user)
    return success_message("删除API秘钥成功")

