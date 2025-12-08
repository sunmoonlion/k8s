#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Auth Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
from pydantic import BaseModel, Field, field_validator, EmailStr
import re

# 导入密码模式
from app.utils.password import password_pattern


class PasswordLoginReq(BaseModel):
    """账号密码登录请求结构"""
    email: EmailStr = Field(..., min_length=5, max_length=254, description="登录邮箱，长度在5-254个字符")
    password: str = Field(..., min_length=8, max_length=16, description="账号密码")

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """校验密码格式"""
        if not re.match(password_pattern, v):
            raise ValueError("密码最少包含一个字母，一个数字，并且长度为8-16")
        return v


class PasswordLoginResp(BaseModel):
    """账号密码授权认证响应结构"""
    access_token: str
    expire_at: int

