#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Document Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.document_schema import (
    CreateDocumentsReq,
    CreateDocumentsResp,
    GetDocumentResp,
    UpdateDocumentNameReq,
    GetDocumentsWithPageReq,
    GetDocumentsWithPageResp,
    UpdateDocumentEnabledReq,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_document_service
from app.services.llmops.document_service import DocumentService

router = APIRouter()


@router.post("/{dataset_id}/documents", response_model=dict)
async def create_documents(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    req: CreateDocumentsReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """创建/新增文档列表"""
    # 1.调用服务创建文档
    documents, batch = await document_service.create_documents(
        db,
        dataset_id,
        upload_file_ids=req.upload_file_ids,
        process_type=req.process_type,
        rule=req.rule,
        user=current_user
    )

    # 2.构建响应结构
    resp = CreateDocumentsResp(
        documents=[
            {
                "id": doc.id,
                "name": doc.name,
                "status": doc.status,
                "created_at": int(doc.created_at.timestamp()) if doc.created_at else 0,
            } for doc in documents
        ],
        batch=batch,
    )

    return success_json(resp.model_dump())


@router.get("/{dataset_id}/documents/{document_id}", response_model=GetDocumentResp)
async def get_document(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """获取文档基础信息"""
    document = await document_service.get_document(db, dataset_id, document_id, current_user)
    return GetDocumentResp(
        id=document.id,
        dataset_id=document.dataset_id,
        name=document.name,
        segment_count=0,  # TODO: 计算片段数量
        character_count=document.character_count or 0,
        hit_count=document.hit_count or 0,
        position=document.position or 0,
        enabled=document.enabled or False,
        disabled_at=int(document.disabled_at.timestamp()) if document.disabled_at else None,
        status=document.status or "",
        error=document.error,
        updated_at=int(document.updated_at.timestamp()) if document.updated_at else 0,
        created_at=int(document.created_at.timestamp()) if document.created_at else 0,
    )


@router.get("/{dataset_id}/documents", response_model=dict)
async def get_documents_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    search_word: str | None = Query(None),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """获取文档分页列表"""
    # 1.构建请求对象
    req = GetDocumentsWithPageReq(
        current_page=current_page,
        page_size=page_size,
        search_word=search_word,
    )

    # 2.调用服务获取数据
    documents, paginator = await document_service.get_documents_with_page(
        db, dataset_id, req, current_user
    )

    # 3.构建响应结构
    resp_list = [
        GetDocumentsWithPageResp(
            id=doc.id,
            name=doc.name,
            character_count=doc.character_count or 0,
            hit_count=doc.hit_count or 0,
            position=doc.position or 0,
            enabled=doc.enabled or False,
            disabled_at=int(doc.disabled_at.timestamp()) if doc.disabled_at else None,
            status=doc.status or "",
            error=doc.error,
            updated_at=int(doc.updated_at.timestamp()) if doc.updated_at else 0,
            created_at=int(doc.created_at.timestamp()) if doc.created_at else 0,
        ) for doc in documents
    ]

    return success_json({
        "list": [doc.model_dump() for doc in resp_list],
        "paginator": paginator,
    })


@router.post("/{dataset_id}/documents/{document_id}/name", response_model=dict)
async def update_document_name(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    req: UpdateDocumentNameReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """更新文档名称/基础信息"""
    await document_service.update_document_name(
        db, dataset_id, document_id, req.name, current_user
    )
    return success_message("更新文档名称成功")


@router.post("/{dataset_id}/documents/{document_id}/enabled", response_model=dict)
async def update_document_enabled(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    req: UpdateDocumentEnabledReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """更新文档启用状态"""
    await document_service.update_document_enabled(
        db, dataset_id, document_id, req.enabled, current_user
    )
    return success_message("更新文档启用状态成功")


@router.post("/{dataset_id}/documents/{document_id}/delete", response_model=dict)
async def delete_document(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    document_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """根据传递的文档id删除指定的文档"""
    await document_service.delete_document(db, dataset_id, document_id, current_user)
    return success_message("删除文档成功")


@router.get("/{dataset_id}/documents/batch/{batch}", response_model=dict)
async def get_documents_status(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    batch: str,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    document_service: Annotated[DocumentService, Depends(get_document_service)],
) -> Any:
    """根据传递的batch获取文档状态列表"""
    documents = await document_service.get_documents_by_batch(
        db, dataset_id, batch, current_user
    )
    return success_json([
        {
            "id": str(doc.id),
            "name": doc.name,
            "status": doc.status,
            "error": doc.error,
            "created_at": int(doc.created_at.timestamp()) if doc.created_at else 0,
        } for doc in documents
    ])

