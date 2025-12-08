#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Account Schema - 从 imooc-llmops 迁移
已转换为 Pydantic（注意：sunmoonai-web-backend 已有 User 相关 Schema，此文件主要用于兼容）
"""
from pydantic import BaseModel, Field, field_validator
from uuid import UUID
import re

# 导入密码模式
from app.utils.password import password_pattern


class GetCurrentUserResp(BaseModel):
    """获取当前登录用户信息响应"""
    id: UUID
    name: str
    email: str
    avatar: str = ""
    last_login_at: int | None = None
    last_login_ip: str = ""
    created_at: int


class UpdatePasswordReq(BaseModel):
    """更新用户密码请求"""
    password: str = Field(..., min_length=8, max_length=16, description="登录密码")

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """校验密码格式"""
        if not re.match(password_pattern, v):
            raise ValueError("密码最少包含一个字母、一个数字，并且长度是8-16")
        return v


class UpdateNameReq(BaseModel):
    """更新用户名称请求"""
    name: str = Field(..., min_length=3, max_length=30, description="用户名字，长度在3-30位")


class UpdateAvatarReq(BaseModel):
    """更新用户头像请求"""
    avatar: str = Field(..., description="用户头像，必须是URL图片地址")

    @field_validator("avatar")
    @classmethod
    def validate_avatar(cls, v: str) -> str:
        """校验头像URL格式"""
        if not (v.startswith("http://") or v.startswith("https://")):
            raise ValueError("用户头像必须是URL图片地址")
        return v

