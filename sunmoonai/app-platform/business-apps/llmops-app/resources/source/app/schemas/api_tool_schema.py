#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Tool Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from uuid import UUID

from app.schemas.llmops.common import PaginatorReq


class ValidateOpenAPISchemaReq(BaseModel):
    """校验OpenAPI规范字符串请求"""
    openapi_schema: str = Field(..., description="openapi_schema字符串")


class GetApiToolProvidersWithPageReq(PaginatorReq):
    """获取API工具提供者分页列表请求"""
    search_word: Optional[str] = Field(None, description="搜索关键词")


class CreateApiToolReq(BaseModel):
    """创建自定义API工具请求"""
    name: str = Field(..., min_length=1, max_length=30, description="工具提供者名字，长度在1-30")
    icon: str = Field(..., description="工具提供者的图标，必须是URL链接")
    openapi_schema: str = Field(..., description="openapi_schema字符串")
    headers: list[dict] = Field(default_factory=list, description="请求头列表")

    @field_validator("icon")
    @classmethod
    def validate_icon(cls, v: str) -> str:
        """校验图标URL格式"""
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError("工具提供者的图标必须是URL链接")
        return v

    @field_validator("headers")
    @classmethod
    def validate_headers(cls, v: list[dict]) -> list[dict]:
        """校验headers请求的数据是否正确"""
        for header in v:
            if not isinstance(header, dict):
                raise ValueError("headers里的每一个元素都必须是字典")
            if set(header.keys()) != {"key", "value"}:
                raise ValueError("headers里的每一个元素都必须包含key/value两个属性，不允许有其他属性")
        return v


class UpdateApiToolProviderReq(BaseModel):
    """更新API工具提供者请求"""
    name: str = Field(..., min_length=1, max_length=30, description="工具提供者名字，长度在1-30")
    icon: str = Field(..., description="工具提供者的图标，必须是URL链接")
    openapi_schema: str = Field(..., description="openapi_schema字符串")
    headers: list[dict] = Field(default_factory=list, description="请求头列表")

    @field_validator("icon")
    @classmethod
    def validate_icon(cls, v: str) -> str:
        """校验图标URL格式"""
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError("工具提供者的图标必须是URL链接")
        return v

    @field_validator("headers")
    @classmethod
    def validate_headers(cls, v: list[dict]) -> list[dict]:
        """校验headers请求的数据是否正确"""
        for header in v:
            if not isinstance(header, dict):
                raise ValueError("headers里的每一个元素都必须是字典")
            if set(header.keys()) != {"key", "value"}:
                raise ValueError("headers里的每一个元素都必须包含key/value两个属性，不允许有其他属性")
        return v


class GetApiToolProviderResp(BaseModel):
    """获取API工具提供者响应信息"""
    id: UUID
    name: str
    icon: str
    openapi_schema: str
    headers: list[dict] = []
    created_at: int


class GetApiToolResp(BaseModel):
    """获取API工具参数详情响应"""
    id: UUID
    name: str
    description: str
    inputs: list[dict] = []
    provider: dict


class GetApiToolProvidersWithPageResp(BaseModel):
    """获取API工具提供者分页列表数据响应"""
    id: UUID
    name: str
    icon: str
    description: str
    headers: list[dict] = []
    tools: list[dict] = []
    created_at: int

