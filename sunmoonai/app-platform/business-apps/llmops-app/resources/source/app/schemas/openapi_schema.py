#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps OpenAPI Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
import uuid
from urllib.parse import urlparse
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional
from uuid import UUID


class OpenAPIChatReq(BaseModel):
    """开放API聊天接口请求结构体"""
    app_id: UUID = Field(..., description="应用id，格式必须为UUID")
    end_user_id: Optional[UUID] = Field(None, description="终端用户id，必须为UUID")
    conversation_id: Optional[str] = Field(None, description="会话id")
    query: str = Field(..., description="用户提问query，不能为空")
    image_urls: Optional[list[str]] = Field(default_factory=list, description="图片URL列表")
    stream: bool = Field(True, description="是否流式输出")

    @field_validator("conversation_id")
    @classmethod
    def validate_conversation_id(cls, v: Optional[str], info) -> Optional[str]:
        """自定义校验conversation_id函数"""
        # 1.检测是否传递数据，如果传递了，则类型必须为UUID
        if v:
            try:
                uuid.UUID(v)
            except Exception:
                raise ValueError("会话id格式必须为UUID")

            # 2.终端用户id是不是为空（需要在 model_validator 中检查）
        return v

    @field_validator("image_urls")
    @classmethod
    def validate_image_urls(cls, v: Optional[list[str]]) -> list[str]:
        """校验传递的图片URL链接列表"""
        # 1.校验数据类型如果为None则设置默认值空列表
        if v is None:
            return []

        # 2.校验数据的长度，最多不能超过5条URL记录
        if len(v) > 5:
            raise ValueError("上传的图片数量不能超过5，请核实后重试")

        # 3.循环校验image_url是否为URL
        for image_url in v:
            result = urlparse(image_url)
            if not all([result.scheme, result.netloc]):
                raise ValueError("上传的图片URL地址格式错误，请核实后重试")

        return v

    @model_validator(mode="after")
    def validate_conversation_and_end_user(self) -> "OpenAPIChatReq":
        """校验会话id和终端用户id的关系"""
        # 如果传递了会话id，则终端用户id不能为空
        if self.conversation_id and not self.end_user_id:
            raise ValueError("传递会话id则终端用户id不能为空")
        return self

