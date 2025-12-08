#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Builtin Tool Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
import io

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.core.response import success_json
from app.core.service_factories import get_builtin_tool_service
from app.services.llmops.builtin_tool_service import BuiltinToolService

router = APIRouter()


@router.get("/", response_model=dict)
async def get_builtin_tools(
    *,
    builtin_tool_service: Annotated[BuiltinToolService, Depends(get_builtin_tool_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """获取LLMOps所有内置工具信息+提供商信息"""
    builtin_tools = await builtin_tool_service.get_builtin_tools()
    return success_json(builtin_tools)


@router.get("/{provider_name}/tools/{tool_name}", response_model=dict)
async def get_provider_tool(
    *,
    provider_name: str,
    tool_name: str,
    builtin_tool_service: Annotated[BuiltinToolService, Depends(get_builtin_tool_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """根据传递的提供商名字+工具名字获取指定工具的信息"""
    builtin_tool = await builtin_tool_service.get_provider_tool(provider_name, tool_name)
    return success_json(builtin_tool)


@router.get("/{provider_name}/icon")
async def get_provider_icon(
    *,
    provider_name: str,
    builtin_tool_service: Annotated[BuiltinToolService, Depends(get_builtin_tool_service)],
) -> Any:
    """根据传递的提供商获取icon图标流信息"""
    icon, mimetype = await builtin_tool_service.get_provider_icon(provider_name)
    return StreamingResponse(io.BytesIO(icon), media_type=mimetype)


@router.get("/categories", response_model=dict)
async def get_categories(
    *,
    builtin_tool_service: Annotated[BuiltinToolService, Depends(get_builtin_tool_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """获取所有内置提供商的分类信息"""
    categories = await builtin_tool_service.get_categories()
    return success_json(categories)

