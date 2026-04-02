#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Segment Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from uuid import UUID

from app.schemas.llmops.common import PaginatorReq


class GetSegmentsWithPageReq(PaginatorReq):
    """获取文档片段列表请求"""
    search_word: Optional[str] = Field(None, description="搜索关键词")


class GetSegmentsWithPageResp(BaseModel):
    """获取文档片段列表响应结构"""
    id: UUID
    document_id: UUID
    dataset_id: UUID
    position: int = 0
    content: str = ""
    keywords: list[str] = []
    character_count: int = 0
    token_count: int = 0
    hit_count: int = 0
    enabled: bool = False
    disabled_at: Optional[int] = None
    status: str = ""
    error: Optional[str] = None
    updated_at: int
    created_at: int


class GetSegmentResp(BaseModel):
    """获取文档详情响应结构"""
    id: UUID
    document_id: UUID
    dataset_id: UUID
    position: int = 0
    content: str = ""
    keywords: list[str] = []
    character_count: int = 0
    token_count: int = 0
    hit_count: int = 0
    hash: str = ""
    enabled: bool = False
    disabled_at: Optional[int] = None
    status: str = ""
    error: Optional[str] = None
    updated_at: int
    created_at: int


class UpdateSegmentEnabledReq(BaseModel):
    """更新文档片段启用状态请求"""
    enabled: bool = Field(..., description="是否启用")


class CreateSegmentReq(BaseModel):
    """创建文档片段请求结构"""
    content: str = Field(..., description="片段内容")
    keywords: Optional[list[str]] = Field(None, description="关键词列表")

    @field_validator("keywords")
    @classmethod
    def validate_keywords(cls, v: Optional[list[str]]) -> list[str]:
        """校验关键词列表"""
        # 1.校验数据类型+非空
        if v is None:
            return []

        # 2.校验数据的长度，最长不能超过10个关键词
        if len(v) > 10:
            raise ValueError("关键词长度范围数量在1-10")

        # 3.循环校验关键词信息，关键词必须是字符串
        for keyword in v:
            if not isinstance(keyword, str):
                raise ValueError("关键词必须是字符串")

        # 4.删除重复数据并更新
        return list(dict.fromkeys(v))


class UpdateSegmentReq(BaseModel):
    """更新文档片段请求"""
    content: str = Field(..., description="片段内容")
    keywords: Optional[list[str]] = Field(None, description="关键词列表")

    @field_validator("keywords")
    @classmethod
    def validate_keywords(cls, v: Optional[list[str]]) -> list[str]:
        """校验关键词列表"""
        # 1.校验数据类型+非空
        if v is None:
            return []

        # 2.校验数据的长度，最长不能超过10个关键词
        if len(v) > 10:
            raise ValueError("关键词长度范围数量在1-10")

        # 3.循环校验关键词信息，关键词必须是字符串
        for keyword in v:
            if not isinstance(keyword, str):
                raise ValueError("关键词必须是字符串")

        # 4.删除重复数据并更新
        return list(dict.fromkeys(v))

