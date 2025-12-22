#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Segment Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.segment_schema import (
    GetSegmentsWithPageReq,
    GetSegmentsWithPageResp,
    GetSegmentResp,
    UpdateSegmentEnabledReq,
    CreateSegmentReq,
    UpdateSegmentReq,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_segment_service
from app.services.llmops.segment_service import SegmentService

router = APIRouter()


@router.get("/{dataset_id}/documents/{document_id}/segments", response_model=dict)
async def get_segments_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    search_word: str | None = Query(None),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    segment_service: Annotated[SegmentService, Depends(get_segment_service)],
) -> Any:
    """获取文档片段列表"""
    # 1.构建请求对象
    req = GetSegmentsWithPageReq(
        current_page=current_page,
        page_size=page_size,
        search_word=search_word,
    )

    # 2.调用服务获取数据
    segments, paginator = await segment_service.get_segments_with_page(
        db, dataset_id, document_id, req, search_word, current_user
    )

    # 3.构建响应结构
    resp_list = [
        GetSegmentsWithPageResp(
            id=seg.id,
            document_id=seg.document_id,
            dataset_id=seg.dataset_id,
            position=seg.position or 0,
            content=seg.content or "",
            keywords=seg.keywords or [],
            character_count=seg.character_count or 0,
            token_count=seg.token_count or 0,
            hit_count=seg.hit_count or 0,
            enabled=seg.enabled or False,
            disabled_at=int(seg.disabled_at.timestamp()) if seg.disabled_at else None,
            status=seg.status or "",
            error=seg.error,
            updated_at=int(seg.updated_at.timestamp()) if seg.updated_at else 0,
            created_at=int(seg.created_at.timestamp()) if seg.created_at else 0,
        ) for seg in segments
    ]

    return success_json({
        "list": [seg.model_dump() for seg in resp_list],
        "paginator": paginator,
    })


@router.post("/{dataset_id}/documents/{document_id}/segments", response_model=dict)
async def create_segment(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    req: CreateSegmentReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    segment_service: Annotated[SegmentService, Depends(get_segment_service)],
) -> Any:
    """创建文档片段"""
    segment = await segment_service.create_segment(
        db,
        dataset_id,
        document_id,
        content=req.content,
        keywords=req.keywords,
        user=current_user
    )
    return success_json({"id": str(segment.id)})


@router.get("/{dataset_id}/documents/{document_id}/segments/{segment_id}", response_model=GetSegmentResp)
async def get_segment(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    segment_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    segment_service: Annotated[SegmentService, Depends(get_segment_service)],
) -> Any:
    """获取文档片段详情"""
    segment = await segment_service.get_segment(
        db, dataset_id, document_id, segment_id, current_user
    )
    return GetSegmentResp(
        id=segment.id,
        document_id=segment.document_id,
        dataset_id=segment.dataset_id,
        position=segment.position or 0,
        content=segment.content or "",
        keywords=segment.keywords or [],
        character_count=segment.character_count or 0,
        token_count=segment.token_count or 0,
        hit_count=segment.hit_count or 0,
        hash=segment.hash or "",
        enabled=segment.enabled or False,
        disabled_at=int(segment.disabled_at.timestamp()) if segment.disabled_at else None,
        status=segment.status or "",
        error=segment.error,
        updated_at=int(segment.updated_at.timestamp()) if segment.updated_at else 0,
        created_at=int(segment.created_at.timestamp()) if segment.created_at else 0,
    )


@router.post("/{dataset_id}/documents/{document_id}/segments/{segment_id}", response_model=dict)
async def update_segment(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    segment_id: UUID,
    req: UpdateSegmentReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    segment_service: Annotated[SegmentService, Depends(get_segment_service)],
) -> Any:
    """更新文档片段"""
    await segment_service.update_segment(
        db,
        dataset_id,
        document_id,
        segment_id,
        content=req.content,
        keywords=req.keywords,
        user=current_user
    )
    return success_message("更新文档片段成功")


@router.post("/{dataset_id}/documents/{document_id}/segments/{segment_id}/enabled", response_model=dict)
async def update_segment_enabled(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    segment_id: UUID,
    req: UpdateSegmentEnabledReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    segment_service: Annotated[SegmentService, Depends(get_segment_service)],
) -> Any:
    """更新文档片段启用状态"""
    await segment_service.update_segment_enabled(
        db, dataset_id, document_id, segment_id, req.enabled, current_user
    )
    return success_message("更新文档片段启用状态成功")


@router.post("/{dataset_id}/documents/{document_id}/segments/{segment_id}/delete", response_model=dict)
async def delete_segment(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    segment_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    segment_service: Annotated[SegmentService, Depends(get_segment_service)],
) -> Any:
    """删除文档片段"""
    await segment_service.delete_segment(
        db, dataset_id, document_id, segment_id, current_user
    )
    return success_message("删除文档片段成功")

