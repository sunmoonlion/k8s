#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Tool Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.api_tool_schema import (
    ValidateOpenAPISchemaReq,
    GetApiToolProvidersWithPageReq,
    CreateApiToolReq,
    UpdateApiToolProviderReq,
    GetApiToolProviderResp,
    GetApiToolResp,
    GetApiToolProvidersWithPageResp,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_api_tool_service
from app.services.llmops.api_tool_service import ApiToolService

router = APIRouter()


@router.post("/validate-openapi-schema", response_model=dict)
async def validate_openapi_schema(
    *,
    req: ValidateOpenAPISchemaReq,
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """校验OpenAPI规范字符串"""
    # TODO: 实现 OpenAPI Schema 验证逻辑
    try:
        api_tool_service.parse_openapi_schema(req.openapi_schema)
        return success_message("OpenAPI规范校验通过")
    except Exception as e:
        return success_json({"valid": False, "error": str(e)})


@router.get("/", response_model=dict)
async def get_api_tool_providers_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    search_word: str | None = Query(None),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """获取API工具提供者分页列表"""
    api_tool_providers, paginator = await api_tool_service.get_api_tool_providers_with_page(
        db,
        current_page=current_page,
        page_size=page_size,
        search_word=search_word,
        user=current_user
    )
    
    resp_list = [
        GetApiToolProvidersWithPageResp(
            id=provider.id,
            name=provider.name,
            icon=provider.icon or "",
            description=provider.description or "",
            headers=provider.headers or [],
            tools=[],  # TODO: 加载工具列表
            created_at=int(provider.created_at.timestamp()) if provider.created_at else 0,
        ) for provider in api_tool_providers
    ]
    
    return success_json({
        "list": [provider.model_dump() for provider in resp_list],
        "paginator": paginator,
    })


@router.post("/", response_model=dict)
async def create_api_tool_provider(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: CreateApiToolReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """创建自定义API工具"""
    await api_tool_service.create_api_tool(
        db,
        name=req.name,
        icon=req.icon,
        headers=req.headers,
        openapi_schema_str=req.openapi_schema,
        user=current_user
    )
    return success_message("创建API工具成功")


@router.get("/{provider_id}", response_model=GetApiToolProviderResp)
async def get_api_tool_provider(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    provider_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """获取API工具提供者信息"""
    provider = await api_tool_service.get_api_tool_provider(
        db, provider_id, current_user
    )
    return GetApiToolProviderResp(
        id=provider.id,
        name=provider.name,
        icon=provider.icon or "",
        openapi_schema=provider.openapi_schema or "",
        headers=provider.headers or [],
        created_at=int(provider.created_at.timestamp()) if provider.created_at else 0,
    )


@router.post("/{provider_id}", response_model=dict)
async def update_api_tool_provider(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    provider_id: UUID,
    req: UpdateApiToolProviderReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """更新API工具提供者"""
    await api_tool_service.update_api_tool_provider(
        db,
        provider_id,
        name=req.name,
        icon=req.icon,
        headers=req.headers,
        openapi_schema_str=req.openapi_schema,
        user=current_user
    )
    return success_message("更新API工具提供者成功")


@router.get("/{provider_id}/tools/{tool_name}", response_model=GetApiToolResp)
async def get_api_tool(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    provider_id: UUID,
    tool_name: str,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """获取API工具参数详情"""
    tool = await api_tool_service.get_api_tool(
        db, provider_id, tool_name, current_user
    )
    # TODO: 获取 provider 信息
    return GetApiToolResp(
        id=tool.id,
        name=tool.name,
        description=tool.description or "",
        inputs=[],  # TODO: 从 parameters 转换
        provider={},  # TODO: 获取 provider 信息
    )


@router.post("/{provider_id}/delete", response_model=dict)
async def delete_api_tool_provider(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    provider_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    api_tool_service: Annotated[ApiToolService, Depends(get_api_tool_service)],
) -> Any:
    """删除API工具提供者"""
    await api_tool_service.delete_api_tool_provider(db, provider_id, current_user)
    return success_message("删除API工具提供者成功")

