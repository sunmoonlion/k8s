#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Key Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field
from uuid import UUID


class CreateApiKeyReq(BaseModel):
    """创建API秘钥请求"""
    is_active: bool = Field(True, description="是否激活")
    remark: str = Field("", max_length=100, description="秘钥备注，不能超过100个字符")


class UpdateApiKeyReq(BaseModel):
    """更新API秘钥请求"""
    is_active: bool = Field(..., description="是否激活")
    remark: str = Field("", max_length=100, description="秘钥备注，不能超过100个字符")


class UpdateApiKeyIsActiveReq(BaseModel):
    """更新API秘钥激活请求"""
    is_active: bool = Field(..., description="是否激活")


class GetApiKeysWithPageResp(BaseModel):
    """获取API秘钥分页列表数据"""
    id: UUID
    api_key: str
    is_active: bool = False
    remark: str = ""
    updated_at: int
    created_at: int

