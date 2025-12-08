#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Audio Schema - 从 imooc-llmops 迁移
已转换为 Pydantic（注意：文件上传在 FastAPI 中使用 UploadFile）
"""
from pydantic import BaseModel, Field
from uuid import UUID

# 注意：在 FastAPI 中，文件上传使用 fastapi.UploadFile，不需要 Schema
# 这里只定义请求参数 Schema


class MessageToAudioReq(BaseModel):
    """消息转流式事件语音请求结构"""
    message_id: UUID = Field(..., description="消息id，不能为空")

