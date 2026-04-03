#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Builtin App Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field
from uuid import UUID


class GetBuiltinAppCategoriesResp(BaseModel):
    """获取内置应用分类列表响应"""
    category: str
    name: str


class GetBuiltinAppsResp(BaseModel):
    """获取内置应用实体列表响应"""
    id: str
    category: str
    name: str
    icon: str
    description: str
    model_config: dict = {}
    created_at: int


class AddBuiltinAppToSpaceReq(BaseModel):
    """添加内置应用到个人空间请求"""
    builtin_app_id: UUID = Field(..., description="内置应用id，格式必须为UUID")

