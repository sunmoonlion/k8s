#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Builtin App Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.builtin_app_schema import (
    GetBuiltinAppCategoriesResp,
    GetBuiltinAppsResp,
    AddBuiltinAppToSpaceReq,
)
from app.core.response import success_json
from app.core.service_factories import get_builtin_app_service
from app.services.llmops.builtin_app_service import BuiltinAppService

router = APIRouter()


@router.get("/categories", response_model=dict)
async def get_builtin_app_categories(
    *,
    builtin_app_service: Annotated[BuiltinAppService, Depends(get_builtin_app_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """获取内置应用分类列表信息"""
    categories = await builtin_app_service.get_categories()
    resp_list = [
        GetBuiltinAppCategoriesResp(
            category=cat.category,
            name=cat.name,
        ) for cat in categories
    ]
    return success_json([cat.model_dump() for cat in resp_list])


@router.get("/", response_model=dict)
async def get_builtin_apps(
    *,
    builtin_app_service: Annotated[BuiltinAppService, Depends(get_builtin_app_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """获取所有内置应用列表信息"""
    builtin_apps = await builtin_app_service.get_builtin_apps()
    resp_list = [
        GetBuiltinAppsResp(
            id=app.id,
            category=app.category,
            name=app.name,
            icon=app.icon,
            description=app.description,
            model_config=app.model_config or {},
            created_at=app.created_at or 0,
        ) for app in builtin_apps
    ]
    return success_json([app.model_dump() for app in resp_list])


@router.post("/add-builtin-app-to-space", response_model=dict)
async def add_builtin_app_to_space(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: AddBuiltinAppToSpaceReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    builtin_app_service: Annotated[BuiltinAppService, Depends(get_builtin_app_service)],
) -> Any:
    """将指定的内置应用添加到个人空间"""
    # 1.将指定内置应用模板添加到个人空间
    app = await builtin_app_service.add_builtin_app_to_space(
        db, req.builtin_app_id, current_user
    )

    return success_json({"id": str(app.id)})

