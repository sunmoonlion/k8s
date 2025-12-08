#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Analysis Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.core.response import success_json
from app.core.service_factories import get_analysis_service
from app.services.llmops.analysis_service import AnalysisService

router = APIRouter()


@router.get("/{app_id}", response_model=dict)
async def get_app_analysis(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    analysis_service: Annotated[AnalysisService, Depends(get_analysis_service)],
) -> Any:
    """根据传递的应用id获取应用的统计信息"""
    app_analysis = await analysis_service.get_app_analysis(db, app_id, current_user)
    return success_json(app_analysis)

