#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Dataset Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.dataset_schema import (
    CreateDatasetReq,
    GetDatasetResp,
    UpdateDatasetReq,
    GetDatasetsWithPageReq,
    GetDatasetsWithPageResp,
    HitReq,
    GetDatasetQueriesResp,
)
from app.core.response import success_json, success_message
from app.core.service_factories import get_dataset_service
from app.services.llmops.dataset_service import DatasetService

router = APIRouter()


@router.post("/", response_model=dict)
async def create_dataset(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: CreateDatasetReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """创建知识库"""
    # 1.调用服务创建知识库
    await dataset_service.create_dataset(
        db,
        name=req.name,
        description=req.description,
        icon=req.icon,
        embedding_model=req.embedding_model,
        embedding_model_provider=req.embedding_model_provider,
        embedding_dimension=req.embedding_dimension,
        user=current_user
    )

    # 2.返回成功调用提示
    return success_message("创建知识库成功")


@router.get("/{dataset_id}", response_model=GetDatasetResp)
async def get_dataset(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """根据传递的知识库id获取详情"""
    dataset = await dataset_service.get_dataset(db, dataset_id, current_user)
    return GetDatasetResp(
        id=dataset.id,
        name=dataset.name,
        description=dataset.description,
        icon=dataset.icon,
        embedding_model=dataset.embedding_model or "",
        embedding_model_provider=dataset.embedding_model_provider or "",
        embedding_dimension=dataset.embedding_dimension or 0,
        document_count=0,  # TODO: 计算文档数量
        updated_at=int(dataset.updated_at.timestamp()) if dataset.updated_at else 0,
        created_at=int(dataset.created_at.timestamp()) if dataset.created_at else 0,
    )


@router.post("/{dataset_id}", response_model=dict)
async def update_dataset(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    req: UpdateDatasetReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """根据传递的知识库id+信息更新知识库"""
    # 1.调用服务更新知识库
    await dataset_service.update_dataset(
        db,
        dataset_id,
        name=req.name,
        description=req.description,
        icon=req.icon,
        user=current_user
    )

    # 2.返回成功调用提示
    return success_message("更新知识库成功")


@router.post("/{dataset_id}/delete", response_model=dict)
async def delete_dataset(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """根据传递的知识库id删除知识库"""
    await dataset_service.delete_dataset(db, dataset_id, current_user)
    return success_message("删除知识库成功")


@router.get("/", response_model=dict)
async def get_datasets_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    search_word: str | None = Query(None),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """获取当前登录用户的知识库分页列表数据"""
    # 1.构建请求对象
    req = GetDatasetsWithPageReq(
        current_page=current_page,
        page_size=page_size,
        search_word=search_word,
    )

    # 2.调用服务获取列表数据以及分页器
    datasets, paginator = await dataset_service.get_datasets_with_page(db, req, current_user)

    # 3.构建响应结构并返回
    resp_list = [
        GetDatasetsWithPageResp(
            id=dataset.id,
            name=dataset.name,
            description=dataset.description,
            icon=dataset.icon,
            document_count=0,  # TODO: 计算文档数量
            updated_at=int(dataset.updated_at.timestamp()) if dataset.updated_at else 0,
            created_at=int(dataset.created_at.timestamp()) if dataset.created_at else 0,
        ) for dataset in datasets
    ]

    return success_json({
        "list": [dataset.model_dump() for dataset in resp_list],
        "paginator": paginator,
    })


@router.post("/{dataset_id}/hit", response_model=dict)
async def hit(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    req: HitReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """根据传递的知识库id+检索参数执行召回测试"""
    # 1.调用服务执行检索策略
    hit_result = await dataset_service.hit(
        db,
        dataset_id,
        query=req.query,
        top_k=req.top_k,
        score_threshold=req.score_threshold,
        retrieval_mode=req.retrieval_mode,
        user=current_user
    )

    return success_json(hit_result)


@router.get("/{dataset_id}/queries", response_model=dict)
async def get_dataset_queries(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    dataset_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    dataset_service: Annotated[DatasetService, Depends(get_dataset_service)],
) -> Any:
    """根据传递的知识库id获取最近的10条查询记录"""
    dataset_queries = await dataset_service.get_dataset_queries(db, dataset_id, current_user)
    resp_list = [
        GetDatasetQueriesResp(
            id=query.id,
            query=query.query,
            created_at=int(query.created_at.timestamp()) if query.created_at else 0,
        ) for query in dataset_queries
    ]
    return success_json([query.model_dump() for query in resp_list])

