#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Web App Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from urllib.parse import urlparse
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional
from uuid import UUID


class WebAppChatReq(BaseModel):
    """WebApp对话请求结构体"""
    conversation_id: Optional[UUID] = Field(None, description="会话id，格式必须为uuid")
    query: str = Field(..., description="用户提问query，不能为空")
    image_urls: Optional[list[str]] = Field(default_factory=list, description="图片URL列表")

    @field_validator("image_urls")
    @classmethod
    def validate_image_urls(cls, v: Optional[list[str]]) -> list[str]:
        """校验传递的图片URL链接列表"""
        # 1.校验数据类型如果为None则设置默认值空列表
        if v is None:
            return []

        # 2.校验数据的长度，最多不能超过5条URL记录
        if len(v) > 5:
            raise ValueError("上传的图片数量不能超过5，请核实后重试")

        # 3.循环校验image_url是否为URL
        for image_url in v:
            result = urlparse(image_url)
            if not all([result.scheme, result.netloc]):
                raise ValueError("上传的图片URL地址格式错误，请核实后重试")

        return v


class GetConversationsReq(BaseModel):
    """获取WebApp会话列表请求结构体"""
    is_pinned: bool = Field(False, description="是否置顶")


class GetConversationsResp(BaseModel):
    """获取WebApp会话列表响应结构体"""
    id: UUID
    name: str
    summary: str = ""
    created_at: int

