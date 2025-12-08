#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
响应工具函数 - 用于统一 API 响应格式
"""
from typing import Any, Union, Generator, AsyncGenerator
from enum import IntEnum
from fastapi.responses import StreamingResponse, JSONResponse
import json


class HttpCode(IntEnum):
    """HTTP 状态码枚举"""
    SUCCESS = 200
    FAIL = 400
    VALIDATE_ERROR = 400
    NOT_FOUND = 404
    UNAUTHORIZED = 401
    FORBIDDEN = 403


def success_json(data: Any = None) -> dict[str, Any]:
    """成功数据响应"""
    return {
        "code": HttpCode.SUCCESS,
        "message": "",
        "data": data or {},
    }


def success_message(msg: str = "") -> dict[str, Any]:
    """成功的消息响应"""
    return {
        "code": HttpCode.SUCCESS,
        "message": msg,
        "data": {},
    }


def fail_json(data: Any = None, message: str = "") -> dict[str, Any]:
    """失败数据响应"""
    return {
        "code": HttpCode.FAIL,
        "message": message,
        "data": data or {},
    }


def validate_error_json(errors: dict = None, message: str = "") -> dict[str, Any]:
    """数据验证错误响应"""
    if errors:
        first_key = next(iter(errors), None)
        if first_key is not None and errors[first_key]:
            msg = errors[first_key][0] if isinstance(errors[first_key], list) else str(errors[first_key])
        else:
            msg = message or "数据验证错误"
    else:
        msg = message or "数据验证错误"
    
    return {
        "code": HttpCode.VALIDATE_ERROR,
        "message": msg,
        "data": errors or {},
    }


def error_json(message: str = "", code: int = 400, data: Any = None) -> dict[str, Any]:
    """错误响应（用于异常处理器）"""
    return {
        "code": code,
        "message": message,
        "data": data or {},
    }


def compact_generate_response(
    response: Union[dict, Generator[str, None, None], AsyncGenerator[str, None]]
) -> Union[JSONResponse, StreamingResponse]:
    """
    统一合并处理块输出以及流式事件输出
    
    Args:
        response: 可以是字典（块输出）或生成器（流式输出）
    
    Returns:
        JSONResponse 或 StreamingResponse
    """
    # 1.检测下是否为块输出（字典）
    if isinstance(response, dict):
        return JSONResponse(content=response)
    
    # 2.检测是否为同步生成器
    if isinstance(response, Generator):
        async def generate() -> AsyncGenerator[str, None]:
            """将同步生成器转换为异步生成器"""
            for chunk in response:
                yield chunk
        
        return StreamingResponse(
            generate(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            }
        )
    
    # 3.检测是否为异步生成器
    if hasattr(response, '__aiter__'):
        return StreamingResponse(
            response,
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            }
        )
    
    # 4.默认返回 JSON 响应
    return JSONResponse(content=response if isinstance(response, dict) else {"data": response})

