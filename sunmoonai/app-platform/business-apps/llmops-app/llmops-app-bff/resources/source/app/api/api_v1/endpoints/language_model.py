#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Language Model Endpoints - 从 imooc-llmops 迁移
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
from app.core.service_factories import get_language_model_service
from app.services.llmops.language_model_service import LanguageModelService

router = APIRouter()


@router.get("/", response_model=dict)
async def get_language_models(
    *,
    language_model_service: Annotated[LanguageModelService, Depends(get_language_model_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """获取所有的语言模型提供商信息"""
    language_models = await language_model_service.get_language_models()
    return success_json(language_models)


@router.get("/{provider_name}/{model_name}", response_model=dict)
async def get_language_model(
    *,
    provider_name: str,
    model_name: str,
    language_model_service: Annotated[LanguageModelService, Depends(get_language_model_service)],
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
) -> Any:
    """根据传递的提供商名字+模型名字获取模型详细信息"""
    language_model = await language_model_service.get_language_model(provider_name, model_name)
    return success_json(language_model)


@router.get("/{provider_name}/icon")
async def get_language_model_icon(
    *,
    provider_name: str,
    language_model_service: Annotated[LanguageModelService, Depends(get_language_model_service)],
) -> Any:
    """根据传递的提供者名字获取指定提供商的icon图标"""
    icon, mimetype = await language_model_service.get_language_model_icon(provider_name)
    return StreamingResponse(io.BytesIO(icon), media_type=mimetype)

