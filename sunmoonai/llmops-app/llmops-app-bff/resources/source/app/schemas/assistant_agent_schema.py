#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Assistant Agent Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from urllib.parse import urlparse
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from uuid import UUID

from app.schemas.llmops.common import PaginatorReq


class AssistantAgentChat(BaseModel):
    """辅助Agent会话请求结构体"""
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


class GetAssistantAgentMessagesWithPageReq(PaginatorReq):
    """获取辅助智能体消息列表分页请求"""
    created_at: int = Field(0, ge=0, description="created_at游标，最小值为0")


class MessageAgentThoughtResp(BaseModel):
    """消息 Agent 思考响应结构"""
    id: UUID
    position: int
    event: str
    thought: str
    observation: str | None
    tool: str | None
    tool_input: dict | None
    latency: float
    created_at: int


class GetAssistantAgentMessagesWithPageResp(BaseModel):
    """获取辅助智能体消息列表分页响应结构"""
    id: UUID
    conversation_id: UUID
    query: str
    image_urls: list[str] = []
    answer: str
    total_token_count: int = 0
    latency: float = 0
    agent_thoughts: list[MessageAgentThoughtResp] = []
    created_at: int

