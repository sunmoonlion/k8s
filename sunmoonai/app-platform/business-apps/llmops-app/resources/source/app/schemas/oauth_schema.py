#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps OAuth Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field


class AuthorizeReq(BaseModel):
    """第三方授权认证请求体"""
    code: str = Field(..., description="授权码，不能为空")


class AuthorizeResp(BaseModel):
    """第三方授权认证响应结构"""
    access_token: str
    expire_at: int

