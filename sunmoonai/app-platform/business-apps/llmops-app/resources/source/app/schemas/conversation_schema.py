#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Conversation Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field
from typing import Optional
from uuid import UUID

from app.schemas.llmops.common import PaginatorReq


class GetConversationMessagesWithPageReq(PaginatorReq):
    """获取指定会话消息列表分页数据请求结构"""
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


class GetConversationMessagesWithPageResp(BaseModel):
    """获取指定会话消息列表分页数据响应结构"""
    id: UUID
    conversation_id: UUID
    query: str
    image_urls: list[str] = []
    answer: str
    total_token_count: int = 0
    latency: float = 0
    agent_thoughts: list[MessageAgentThoughtResp] = []
    created_at: int


class UpdateConversationNameReq(BaseModel):
    """更新会话名字请求结构体"""
    name: str = Field(..., max_length=100, description="会话名字，长度不能超过100个字符")


class UpdateConversationIsPinnedReq(BaseModel):
    """更新会话置顶选项请求请求结构体"""
    is_pinned: bool = Field(False, description="是否置顶")

