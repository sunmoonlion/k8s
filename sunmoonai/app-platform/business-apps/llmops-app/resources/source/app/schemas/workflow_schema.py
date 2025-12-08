#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Workflow Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from uuid import UUID
import re

from app.schemas.llmops.common import PaginatorReq

# 导入 Entity
from app.core.llmops.entity.workflow_entity import WorkflowStatus, WORKFLOW_CONFIG_NAME_PATTERN


class CreateWorkflowReq(BaseModel):
    """创建工作流基础请求"""
    name: str = Field(..., max_length=50, description="工作流名称，长度不能超过50")
    tool_call_name: str = Field(..., max_length=50, description="英文名称，不能超过50个字符")
    icon: str = Field(..., description="工作流图标，必须是图片URL地址")
    description: str = Field(..., max_length=1024, description="工作流描述，不能超过1024个字符")

    @field_validator("tool_call_name")
    @classmethod
    def validate_tool_call_name(cls, v: str) -> str:
        """校验英文名称格式"""
        if not re.match(WORKFLOW_CONFIG_NAME_PATTERN, v):
            raise ValueError("英文名称仅支持字母、数字和下划线，且以字母/下划线为开头")
        return v

    @field_validator("icon")
    @classmethod
    def validate_icon(cls, v: str) -> str:
        """校验图标URL格式"""
        # 简单的URL验证
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError("工作流图标必须是图片URL地址")
        return v


class UpdateWorkflowReq(BaseModel):
    """更新工作流基础请求"""
    name: str = Field(..., max_length=50, description="工作流名称，长度不能超过50")
    tool_call_name: str = Field(..., max_length=50, description="英文名称，不能超过50个字符")
    icon: str = Field(..., description="工作流图标，必须是图片URL地址")
    description: str = Field(..., max_length=1024, description="工作流描述，不能超过1024个字符")

    @field_validator("tool_call_name")
    @classmethod
    def validate_tool_call_name(cls, v: str) -> str:
        """校验英文名称格式"""
        if not re.match(WORKFLOW_CONFIG_NAME_PATTERN, v):
            raise ValueError("英文名称仅支持字母、数字和下划线，且以字母/下划线为开头")
        return v

    @field_validator("icon")
    @classmethod
    def validate_icon(cls, v: str) -> str:
        """校验图标URL格式"""
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError("工作流图标必须是图片URL地址")
        return v


class GetWorkflowResp(BaseModel):
    """获取工作流详情响应结构"""
    id: UUID
    name: str
    tool_call_name: str
    icon: str
    description: str
    status: str
    is_debug_passed: bool = False
    node_count: int = 0
    published_at: Optional[int] = None
    updated_at: int
    created_at: int


class GetWorkflowsWithPageReq(PaginatorReq):
    """获取工作流分页列表数据请求结构"""
    status: Optional[str] = Field(None, description="工作流状态")
    search_word: Optional[str] = Field(None, description="搜索关键词")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: Optional[str]) -> Optional[str]:
        """校验工作流状态"""
        if v and v not in [WorkflowStatus.DRAFT, WorkflowStatus.PUBLISHED]:
            raise ValueError("工作流状态格式错误")
        return v


class GetWorkflowsWithPageResp(BaseModel):
    """获取工作流分页列表数据响应结构"""
    id: UUID
    name: str
    tool_call_name: str
    icon: str
    description: str
    status: str
    is_debug_passed: bool = False
    node_count: int = 0
    published_at: Optional[int] = None
    updated_at: int
    created_at: int

