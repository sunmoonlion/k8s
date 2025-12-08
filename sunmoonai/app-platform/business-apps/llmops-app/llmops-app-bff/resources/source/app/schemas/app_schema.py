#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps App Schema - 从 imooc-llmops 迁移
已转换为 Pydantic BaseModel
"""
from typing import Optional, List, Dict, Any
from uuid import UUID
from urllib.parse import urlparse
from pydantic import BaseModel, Field, field_validator, HttpUrl, model_validator
from datetime import datetime

from app.schemas.llmops.common import PaginatorReq


class CreateAppReq(BaseModel):
    """创建Agent应用请求结构体"""
    name: str = Field(..., min_length=1, max_length=40, description="应用名称")
    icon: HttpUrl = Field(..., description="应用图标URL")
    description: Optional[str] = Field(default="", max_length=800, description="应用描述")


class UpdateAppReq(BaseModel):
    """更新Agent应用请求结构体"""
    name: str = Field(..., min_length=1, max_length=40, description="应用名称")
    icon: HttpUrl = Field(..., description="应用图标URL")
    description: Optional[str] = Field(default="", max_length=800, description="应用描述")


class GetAppsWithPageReq(PaginatorReq):
    """获取应用分页列表数据请求"""
    search_word: Optional[str] = Field(default="", description="搜索关键词")


class GetAppsWithPageResp(BaseModel):
    """获取应用分页列表数据响应结构"""
    id: UUID
    name: str
    icon: str
    description: str
    preset_prompt: str = ""
    model_config: Dict[str, Any] = Field(default_factory=dict)
    status: str = ""
    updated_at: int = 0  # 时间戳
    created_at: int = 0  # 时间戳


class GetAppResp(BaseModel):
    """获取应用基础信息响应结构"""
    id: UUID
    debug_conversation_id: Optional[UUID] = None
    name: str
    icon: str
    description: str
    status: str = ""
    draft_updated_at: int = 0  # 时间戳
    updated_at: int = 0  # 时间戳
    created_at: int = 0  # 时间戳


class GetPublishHistoriesWithPageReq(PaginatorReq):
    """获取应用发布历史配置分页列表请求"""
    pass


class GetPublishHistoriesWithPageResp(BaseModel):
    """获取应用发布历史配置列表分页数据"""
    id: UUID
    version: int = 0
    created_at: int = 0  # 时间戳


class FallbackHistoryToDraftReq(BaseModel):
    """回退历史版本到草稿请求结构体"""
    app_config_version_id: UUID = Field(..., description="回退配置版本id")


class UpdateDebugConversationSummaryReq(BaseModel):
    """更新应用调试会话长期记忆请求体"""
    summary: str = Field(default="", description="会话摘要")


class DebugChatReq(BaseModel):
    """应用调试会话请求结构体"""
    image_urls: List[str] = Field(default_factory=list, description="图片URL列表")
    query: str = Field(..., min_length=1, description="用户提问query")
    
    @field_validator('image_urls')
    @classmethod
    def validate_image_urls(cls, v: List[str]) -> List[str]:
        """校验传递的图片URL链接列表"""
        # 1.校验数据类型如果为None则设置默认值空列表
        if not isinstance(v, list):
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


class GetDebugConversationMessagesWithPageReq(PaginatorReq):
    """获取调试会话消息列表分页请求结构体"""
    created_at: int = Field(default=0, ge=0, description="created_at游标")


class AgentThoughtResp(BaseModel):
    """Agent推理步骤响应结构"""
    id: UUID
    position: int = 0
    event: str = ""
    thought: str = ""
    observation: str = ""
    tool: str = ""
    tool_input: Dict[str, Any] = Field(default_factory=dict)
    latency: float = 0.0
    created_at: int = 0  # 时间戳


class GetDebugConversationMessagesWithPageResp(BaseModel):
    """获取调试会话消息列表分页响应结构体"""
    id: UUID
    conversation_id: UUID
    query: str = ""
    image_urls: List[str] = Field(default_factory=list)
    answer: str = ""
    total_token_count: int = 0
    latency: float = 0.0
    agent_thoughts: List[AgentThoughtResp] = Field(default_factory=list)
    created_at: int = 0  # 时间戳

