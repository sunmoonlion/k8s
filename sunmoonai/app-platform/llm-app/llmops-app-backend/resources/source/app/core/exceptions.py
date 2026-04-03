#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps 异常类 - 从 imooc-llmops 迁移
"""
from typing import Any, Optional


class CustomException(Exception):
    """自定义异常基类"""
    def __init__(self, message: str, code: int = 400, data: Optional[Any] = None):
        self.message = message
        self.code = code
        self.data = data
        super().__init__(self.message)


class FailException(CustomException):
    """失败异常"""
    def __init__(self, message: str = "操作失败", data: Optional[Any] = None):
        super().__init__(message, code=400, data=data)


class NotFoundException(CustomException):
    """未找到异常"""
    def __init__(self, message: str = "资源不存在", data: Optional[Any] = None):
        super().__init__(message, code=404, data=data)


class UnauthorizedException(CustomException):
    """未授权异常"""
    def __init__(self, message: str = "未授权", data: Optional[Any] = None):
        super().__init__(message, code=401, data=data)


class ForbiddenException(CustomException):
    """禁止访问异常"""
    def __init__(self, message: str = "禁止访问", data: Optional[Any] = None):
        super().__init__(message, code=403, data=data)


class ValidateErrorException(CustomException):
    """验证错误异常"""
    def __init__(self, message: str = "验证失败", data: Optional[Any] = None):
        super().__init__(message, code=400, data=data)


