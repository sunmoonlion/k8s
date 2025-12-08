#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Workflow Service - 从 imooc-llmops 迁移
已转换为异步版本（部分方法保持同步，因为涉及工作流执行）
Account 已改为 User，account_id 已改为 user_id
"""
import json
import logging
import time
import uuid
from dataclasses import dataclass
from typing import Any, Generator
from uuid import UUID

from injector import inject
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_workflow import Workflow, WorkflowResult
from app.services.llmops.base_service import BaseService
from app.core.exceptions import ValidateErrorException, NotFoundException, ForbiddenException, FailException

# 导入 Entity 和常量
from app.core.llmops.entity.workflow_entity import (
    WorkflowStatus,
    WorkflowResultStatus,
    DEFAULT_WORKFLOW_CONFIG,
)
# TODO: 导入其他依赖
# from app.core.llmops.tools.builtin_tools.providers import BuiltinProviderManager
# from app.core.llmops.workflow import Workflow as WorkflowTool
# from app.core.llmops.workflow.entities.workflow_entity import WorkflowConfig
# from app.schemas.llmops.workflow_schema import CreateWorkflowReq, GetWorkflowsWithPageReq


@inject
@dataclass
class WorkflowService(BaseService):
    """工作流服务（部分异步版本，工作流执行保持同步）"""
    # TODO: 注入依赖
    # builtin_provider_manager: BuiltinProviderManager

    async def create_workflow(
        self,
        db: AsyncSession,
        tool_call_name: str,
        name: str,
        description: str,
        icon: str,
        user: User
    ) -> Workflow:
        """根据传递的请求信息创建工作流"""
        # 1.根据传递的工作流工具名称查询工作流信息
        result = await db.execute(
            select(Workflow).where(
                Workflow.tool_call_name == tool_call_name.strip(),
                Workflow.user_id == user.id,
            )
        )
        check_workflow = result.scalar_one_or_none()
        if check_workflow:
            raise ValidateErrorException(f"在当前用户下已创建[{tool_call_name}]工作流，不支持重名")

        # 2.调用数据库服务创建工作流
        return await self.create(
            db,
            Workflow,
            **{
                **DEFAULT_WORKFLOW_CONFIG,
                "user_id": user.id,
                "name": name,
                "description": description,
                "icon": icon,
                "is_debug_passed": False,
                "status": WorkflowStatus.DRAFT,
                "tool_call_name": tool_call_name.strip(),
            }
        )

    async def get_workflow(
        self,
        db: AsyncSession,
        workflow_id: UUID,
        user: User
    ) -> Workflow:
        """根据传递的工作流id，获取指定的工作流基础信息"""
        # 1.查询数据库获取工作流基础信息
        workflow = await self.get(db, Workflow, workflow_id)

        # 2.判断工作流是否存在
        if not workflow:
            raise NotFoundException("该工作流不存在，请核实后重试")

        # 3.判断当前用户是否有权限访问该工作流
        if workflow.user_id != user.id:
            raise ForbiddenException("当前用户无权限访问该工作流，请核实后尝试")

        return workflow

    async def delete_workflow(
        self,
        db: AsyncSession,
        workflow_id: UUID,
        user: User
    ) -> Workflow:
        """根据传递的工作流id+用户信息，删除指定的工作流"""
        # 1.获取工作流基础信息并校验权限
        workflow = await self.get_workflow(db, workflow_id, user)

        # 2.删除工作流
        await self.delete(db, workflow)

        return workflow

    async def update_workflow(
        self,
        db: AsyncSession,
        workflow_id: UUID,
        user: User,
        **kwargs
    ) -> Workflow:
        """根据传递的工作流id+请求更新工作流基础信息"""
        # 1.获取工作流基础信息并校验权限
        workflow = await self.get_workflow(db, workflow_id, user)

        # 2.根据传递的工具调用名字查询是否存在重名工作流
        tool_call_name = kwargs.get("tool_call_name", "").strip()
        if tool_call_name:
            result = await db.execute(
                select(Workflow).where(
                    Workflow.tool_call_name == tool_call_name,
                    Workflow.user_id == user.id,
                    Workflow.id != workflow.id,
                )
            )
            check_workflow = result.scalar_one_or_none()
            if check_workflow:
                raise ValidateErrorException(f"在当前用户下已创建[{tool_call_name}]工作流，不支持重名")

        # 3.更新工作流基础信息
        await self.update(db, workflow, **kwargs)

        return workflow

    async def get_workflows_with_page(
        self,
        db: AsyncSession,
        current_page: int,
        page_size: int,
        search_word: str | None,
        status: str | None,
        user: User
    ) -> tuple[list[Workflow], dict]:
        """根据传递的信息获取工作流分页列表数据"""
        # 1.构建筛选器
        filters = [Workflow.user_id == user.id]
        if search_word:
            filters.append(Workflow.name.ilike(f"%{search_word}%"))
        if status:
            filters.append(Workflow.status == status)

        # 2.构建查询
        query = select(Workflow).where(*filters).order_by(desc(Workflow.created_at))
        
        # 3.使用分页器
        from app.utils.paginator import Paginator
        paginator = Paginator(current_page=current_page, page_size=page_size)
        workflows = await paginator.paginate(db, query)
        
        # 4.返回分页信息
        paginator_dict = paginator.to_dict()
        
        return workflows, paginator_dict

    async def update_draft_graph(
        self,
        db: AsyncSession,
        workflow_id: UUID,
        draft_graph: dict[str, Any],
        user: User
    ) -> Workflow:
        """根据传递的工作流id+草稿图配置+用户更新工作流的草稿图"""
        # 1.根据传递的id获取工作流并校验权限
        workflow = await self.get_workflow(db, workflow_id, user)

        # 2.校验传递的草稿图配置，因为有可能边有可能还未建立，所以需要校验关联的数据
        validate_draft_graph = await self._validate_graph(db, workflow_id, draft_graph, user)

        # 3.更新工作流草稿图配置，每次修改都将is_debug_passed的值重置为False
        await self.update(db, workflow, **{
            "draft_graph": validate_draft_graph,
            "is_debug_passed": False,
        })

        return workflow

    async def _validate_graph(
        self,
        db: AsyncSession,
        workflow_id: UUID,
        draft_graph: dict[str, Any],
        user: User
    ) -> dict[str, Any]:
        """校验工作流图配置"""
        # TODO: 实现完整的工作流图验证逻辑
        # 1.验证节点和边的结构
        # 2.验证节点类型和配置
        # 3.验证边的连接关系
        
        return draft_graph

    # TODO: 迁移其他方法
    # - publish_workflow
    # - cancel_publish_workflow
    # - debug_workflow
    # - stop_debug_workflow
    # - get_workflow_debug_result
    # - get_workflow_results_with_page
    # - get_workflow_result
