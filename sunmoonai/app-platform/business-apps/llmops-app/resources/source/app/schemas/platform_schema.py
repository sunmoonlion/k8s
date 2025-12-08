#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Platform Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
import os
from pydantic import BaseModel
from uuid import UUID


class GetWechatConfigResp(BaseModel):
    """获取微信配置响应结构"""
    app_id: UUID
    url: str
    ip: str
    wechat_app_id: str = ""
    wechat_app_secret: str = ""
    wechat_token: str = ""
    status: str = ""
    updated_at: int
    created_at: int

    @classmethod
    def from_model(cls, wechat_config, app_id: UUID):
        """从模型创建响应对象"""
        return cls(
            app_id=app_id,
            url=f"{os.getenv('SERVICE_API_PREFIX', '')}/wechat/{str(app_id)}",
            ip=os.getenv("SERVICE_IP", ""),
            wechat_app_id=wechat_config.wechat_app_id or "",
            wechat_app_secret=wechat_config.wechat_app_secret or "",
            wechat_token=wechat_config.wechat_token or "",
            status=wechat_config.status or "",
            updated_at=int(wechat_config.updated_at.timestamp()) if wechat_config.updated_at else 0,
            created_at=int(wechat_config.created_at.timestamp()) if wechat_config.created_at else 0,
        )


class UpdateWechatConfigReq(BaseModel):
    """更新微信配置请求"""
    wechat_app_id: str | None = None
    wechat_app_secret: str | None = None
    wechat_token: str | None = None

