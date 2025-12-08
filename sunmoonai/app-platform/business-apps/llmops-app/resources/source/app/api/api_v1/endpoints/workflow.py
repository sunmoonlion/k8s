#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Workflow Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.workflow_schema import (
    CreateWorkflowReq,
    UpdateWorkflowReq,
    GetWorkflowResp,
    GetWorkflowsWithPageReq,
    GetWorkflowsWithPageResp,
)
from app.core.response import success_json, success_message, compact_generate_response
from app.core.service_factories import get_workflow_service
from app.services.llmops.workflow_service import WorkflowService

router = APIRouter()


@router.post("/", response_model=dict)
async def create_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: CreateWorkflowReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """创建工作流基础信息"""
    workflow = await workflow_service.create_workflow(
        db,
        tool_call_name=req.tool_call_name,
        name=req.name,
        description=req.description,
        icon=req.icon,
        user=current_user
    )
    return success_json({"id": str(workflow.id)})


@router.get("/{workflow_id}", response_model=GetWorkflowResp)
async def get_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """获取工作流详情"""
    workflow = await workflow_service.get_workflow(db, workflow_id, current_user)
    return GetWorkflowResp(
        id=workflow.id,
        name=workflow.name,
        tool_call_name=workflow.tool_call_name or "",
        icon=workflow.icon or "",
        description=workflow.description or "",
        status=workflow.status or "",
        is_debug_passed=workflow.is_debug_passed or False,
        node_count=len(workflow.draft_graph.get("nodes", [])) if workflow.draft_graph else 0,
        published_at=int(workflow.published_at.timestamp()) if workflow.published_at else None,
        updated_at=int(workflow.updated_at.timestamp()) if workflow.updated_at else 0,
        created_at=int(workflow.created_at.timestamp()) if workflow.created_at else 0,
    )


@router.post("/{workflow_id}", response_model=dict)
async def update_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    req: UpdateWorkflowReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """更新工作流基础信息"""
    await workflow_service.update_workflow(
        db,
        workflow_id,
        name=req.name,
        tool_call_name=req.tool_call_name,
        icon=req.icon,
        description=req.description,
        user=current_user
    )
    return success_message("更新工作流成功")


@router.post("/{workflow_id}/delete", response_model=dict)
async def delete_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """删除工作流"""
    await workflow_service.delete_workflow(db, workflow_id, current_user)
    return success_message("删除工作流成功")


@router.get("/", response_model=dict)
async def get_workflows_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    status: str | None = Query(None),
    search_word: str | None = Query(None),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """获取工作流分页列表数据"""
    # 1.构建请求对象
    req = GetWorkflowsWithPageReq(
        current_page=current_page,
        page_size=page_size,
        status=status,
        search_word=search_word,
    )

    # 2.调用服务获取数据
    workflows, paginator = await workflow_service.get_workflows_with_page(
        db, req, current_user
    )

    # 3.构建响应结构
    resp_list = [
        GetWorkflowsWithPageResp(
            id=wf.id,
            name=wf.name,
            tool_call_name=wf.tool_call_name or "",
            icon=wf.icon or "",
            description=wf.description or "",
            status=wf.status or "",
            is_debug_passed=wf.is_debug_passed or False,
            node_count=len(wf.graph.get("nodes", [])) if wf.graph else 0,
            published_at=int(wf.published_at.timestamp()) if wf.published_at else None,
            updated_at=int(wf.updated_at.timestamp()) if wf.updated_at else 0,
            created_at=int(wf.created_at.timestamp()) if wf.created_at else 0,
        ) for wf in workflows
    ]

    return success_json({
        "list": [wf.model_dump() for wf in resp_list],
        "paginator": paginator,
    })


@router.post("/{workflow_id}/draft-graph", response_model=dict)
async def update_draft_graph(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    draft_graph: dict = Body(...),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """更新工作流草稿图"""
    await workflow_service.update_draft_graph(
        db, workflow_id, draft_graph, current_user
    )
    return success_message("更新工作流草稿图成功")


@router.get("/{workflow_id}/draft-graph", response_model=dict)
async def get_draft_graph(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """获取工作流草稿图"""
    # TODO: 实现获取草稿图逻辑
    draft_graph = await workflow_service.get_draft_graph(db, workflow_id, current_user)
    return success_json(draft_graph)


@router.post("/{workflow_id}/debug", response_model=Any)
async def debug_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    inputs: dict = Body(...),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """调试工作流"""
    # 1.调用服务调试工作流
    response = await workflow_service.debug_workflow(
        db, workflow_id, inputs, current_user
    )
    # 2.返回流式响应或普通响应
    return compact_generate_response(response)


@router.post("/{workflow_id}/publish", response_model=dict)
async def publish_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """发布工作流"""
    await workflow_service.publish_workflow(db, workflow_id, current_user)
    return success_message("发布工作流成功")


@router.post("/{workflow_id}/cancel-publish", response_model=dict)
async def cancel_publish_workflow(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    workflow_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    workflow_service: Annotated[WorkflowService, Depends(get_workflow_service)],
) -> Any:
    """取消发布工作流"""
    await workflow_service.cancel_publish_workflow(db, workflow_id, current_user)
    return success_message("取消发布工作流成功")

