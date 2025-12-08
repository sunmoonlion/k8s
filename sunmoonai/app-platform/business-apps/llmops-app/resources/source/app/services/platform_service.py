#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Platform Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
from dataclasses import dataclass
from uuid import UUID

from injector import inject
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy import select

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_platform import WechatConfig
from app.services.llmops.base_service import BaseService
from app.services.llmops.app_service import AppService
from app.core.exceptions import NotFoundException

# 导入 Entity
from app.core.llmops.entity.app_entity import AppStatus
from app.core.llmops.entity.platform_entity import WechatConfigStatus


@inject
@dataclass
class PlatformService(BaseService):
    """第三方平台服务（异步版本）"""
    app_service: AppService

    async def get_wechat_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> WechatConfig:
        """根据传递的应用id+用户获取微信发布配置"""
        # 1.获取应用信息并校验权限
        app = await self.app_service.get_app(db, app_id, user)

        # 2.获取应用的微信配置信息（需要通过 Service 层获取，因为原模型的 @property 已移除）
        result = await db.execute(
            select(WechatConfig).where(WechatConfig.app_id == app.id)
        )
        wechat_config = result.scalar_one_or_none()
        
        if not wechat_config:
            raise NotFoundException("微信配置不存在")
        
        return wechat_config

    async def update_wechat_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        wechat_app_id: str | None,
        wechat_app_secret: str | None,
        wechat_token: str | None,
        user: User
    ) -> WechatConfig:
        """根据传递的应用id+用户+配置信息更新应用的微信发布配置"""
        # 1.获取应用信息并校验权限
        app = await self.app_service.get_app(db, app_id, user)

        # 2.根据传递的请求判断app_id/app_secret/token是否齐全并计算状态
        status = WechatConfigStatus.UNCONFIGURED
        if wechat_app_id and wechat_app_secret and wechat_token:
            status = WechatConfigStatus.CONFIGURED

        # 3.根据应用的发布状态修正状态数据
        if app.status == AppStatus.DRAFT and status == WechatConfigStatus.CONFIGURED:
            status = WechatConfigStatus.UNCONFIGURED

        # 4.获取或创建微信配置
        result = await db.execute(
            select(WechatConfig).where(WechatConfig.app_id == app.id)
        )
        wechat_config = result.scalar_one_or_none()
        
        if not wechat_config:
            wechat_config = await self.create(
                db,
                WechatConfig,
                app_id=app.id,
                wechat_app_id=wechat_app_id,
                wechat_app_secret=wechat_app_secret,
                wechat_token=wechat_token,
                status=status,
            )
        else:
            # 5.更新应用微信配置信息
            await self.update(
                db,
                wechat_config,
                wechat_app_id=wechat_app_id,
                wechat_app_secret=wechat_app_secret,
                wechat_token=wechat_token,
                status=status,
            )

        return wechat_config
