#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Dataset Schema - 从 imooc-llmops 迁移
已转换为 Pydantic BaseModel
"""
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator, HttpUrl
from datetime import datetime

from app.schemas.llmops.common import PaginatorReq, Paginator


class CreateDatasetReq(BaseModel):
    """创建知识库请求"""
    name: str = Field(..., min_length=1, max_length=100, description="知识库名称")
    icon: HttpUrl = Field(..., description="知识库图标URL")
    description: Optional[str] = Field(default="", max_length=2000, description="知识库描述")


class UpdateDatasetReq(BaseModel):
    """更新知识库请求"""
    name: str = Field(..., min_length=1, max_length=100, description="知识库名称")
    icon: HttpUrl = Field(..., description="知识库图标URL")
    description: Optional[str] = Field(default="", max_length=2000, description="知识库描述")


class GetDatasetResp(BaseModel):
    """获取知识库详情响应结构"""
    id: UUID
    name: str
    icon: str
    description: str
    document_count: int = 0
    hit_count: int = 0
    related_app_count: int = 0
    character_count: int = 0
    updated_at: int = 0  # 时间戳
    created_at: int = 0  # 时间戳


class GetDatasetsWithPageReq(PaginatorReq):
    """获取知识库分页列表请求数据"""
    search_word: Optional[str] = Field(default="", description="搜索关键词")


class GetDatasetsWithPageResp(BaseModel):
    """获取知识库分页列表响应数据"""
    id: UUID
    name: str
    icon: str
    description: str
    document_count: int = 0
    related_app_count: int = 0
    character_count: int = 0
    updated_at: int = 0  # 时间戳
    created_at: int = 0  # 时间戳


class HitReq(BaseModel):
    """知识库召回测试请求"""
    query: str = Field(..., min_length=1, max_length=200, description="查询语句")
    retrieval_strategy: str = Field(..., description="检索策略")
    k: int = Field(..., ge=1, le=10, description="最大召回数量")
    score: Optional[float] = Field(default=None, ge=0, le=0.99, description="最小匹配度")
    
    @field_validator('retrieval_strategy')
    @classmethod
    def validate_retrieval_strategy(cls, v: str) -> str:
        from app.core.llmops.entity.dataset_entity import RetrievalStrategy
        allowed_strategies = [RetrievalStrategy.FULL_TEXT, RetrievalStrategy.SEMANTIC, RetrievalStrategy.HYBRID]
        if v not in allowed_strategies:
            raise ValueError(f"检索策略必须是 {allowed_strategies} 之一")
        return v


class GetDatasetQueriesResp(BaseModel):
    """获取知识库最近查询响应结构"""
    id: UUID
    dataset_id: UUID
    query: str
    source: str
    created_at: int = 0  # 时间戳

