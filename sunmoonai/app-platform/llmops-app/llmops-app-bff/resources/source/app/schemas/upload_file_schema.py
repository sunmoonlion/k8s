#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Upload File Schema - 从 imooc-llmops 迁移
已转换为 Pydantic（注意：文件上传在 FastAPI 中使用 UploadFile）
"""
from pydantic import BaseModel
from uuid import UUID

# 注意：在 FastAPI 中，文件上传使用 fastapi.UploadFile，不需要 Schema
# 这里只定义响应 Schema


class UploadFileResp(BaseModel):
    """上传文件接口响应接口"""
    id: UUID
    user_id: UUID  # 原 account_id
    name: str
    key: str
    size: int = 0
    extension: str = ""
    mime_type: str = ""
    created_at: int

