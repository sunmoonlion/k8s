#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps JWT Service - 从 imooc-llmops 迁移
JWT 服务（保持同步，因为 JWT 库是同步的）
"""
import os
from dataclasses import dataclass
from typing import Any

import jwt
from injector import inject

from app.core.exceptions import UnauthorizedException


@inject
@dataclass
class JwtService:
    """jwt服务（保持同步）"""

    @classmethod
    def generate_token(cls, payload: dict[str, Any]) -> str:
        """根据传递的载荷信息生成token信息"""
        secret_key = os.getenv("JWT_SECRET_KEY")
        if not secret_key:
            raise ValueError("JWT_SECRET_KEY 环境变量未设置")
        return jwt.encode(payload, secret_key, algorithm="HS256")

    @classmethod
    def parse_token(cls, token: str) -> dict[str, Any]:
        """解析传入的token信息得到载荷"""
        secret_key = os.getenv("JWT_SECRET_KEY")
        if not secret_key:
            raise ValueError("JWT_SECRET_KEY 环境变量未设置")
        try:
            return jwt.decode(token, secret_key, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            raise UnauthorizedException("授权认证凭证已过期请重新登陆")
        except jwt.InvalidTokenError:
            raise UnauthorizedException("解析token出错，请重新登陆")
        except Exception as e:
            raise UnauthorizedException(str(e))

