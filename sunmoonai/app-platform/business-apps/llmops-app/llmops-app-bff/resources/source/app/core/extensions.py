#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
扩展模块 - 统一管理外部服务客户端（Redis, Weaviate 等）
"""
import redis
from typing import Optional

try:
    from weaviate import Client, WeaviateClient
except ImportError:
    # 兼容旧版本的 weaviate
    try:
        from weaviate import Client
        WeaviateClient = Client
    except ImportError:
        WeaviateClient = None

from app.core.config import settings


# Redis 客户端（单例）
_redis_client: Optional[redis.Redis] = None


def get_redis_client() -> redis.Redis:
    """获取 Redis 客户端（单例）"""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.Redis(
            host=getattr(settings, 'REDIS_HOST', 'localhost'),
            port=getattr(settings, 'REDIS_PORT', 6379),
            db=getattr(settings, 'REDIS_DB', 0),
            password=getattr(settings, 'REDIS_PASSWORD', None),
            username=getattr(settings, 'REDIS_USERNAME', None),
            decode_responses=False,  # 保持二进制模式，兼容性更好
        )
    return _redis_client


# Weaviate 客户端（单例）
_weaviate_client: Optional[WeaviateClient] = None


def get_weaviate_client():
    """获取 Weaviate 客户端（单例）"""
    global _weaviate_client
    if _weaviate_client is None:
        weaviate_url = getattr(settings, 'WEAVIATE_URL', 'http://localhost:8080')
        weaviate_api_key = getattr(settings, 'WEAVIATE_API_KEY', None)
        
        # 构建连接参数
        connection_params = {
            "url": weaviate_url,
        }
        if weaviate_api_key:
            connection_params["auth_credentials"] = {
                "api_key": weaviate_api_key
            }
        
        if WeaviateClient is not None:
            _weaviate_client = Client(**connection_params)
        else:
            # 如果 weaviate 未安装，返回 None 或抛出异常
            raise ImportError("weaviate 库未安装，请先安装: pip install weaviate-client")
    return _weaviate_client


def reset_extensions():
    """重置所有扩展（用于测试）"""
    global _redis_client, _weaviate_client
    _redis_client = None
    _weaviate_client = None

