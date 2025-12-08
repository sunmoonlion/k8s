#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps AI Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field
from uuid import UUID


class GenerateSuggestedQuestionsReq(BaseModel):
    """生成建议问题列表请求结构体"""
    message_id: UUID = Field(..., description="消息id，格式必须为uuid")


class OptimizePromptReq(BaseModel):
    """优化预设prompt请求结构体"""
    prompt: str = Field(..., max_length=2000, description="预设prompt，长度不能超过2000个字符")

