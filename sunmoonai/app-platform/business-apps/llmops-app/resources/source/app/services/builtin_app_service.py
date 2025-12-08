#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Builtin App Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
from dataclasses import dataclass

from injector import inject
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_app import LLMOpsApp, AppConfigVersion
from app.services.llmops.base_service import BaseService
from app.core.exceptions import NotFoundException

# TODO: 导入依赖
# from app.core.llmops.builtin_apps import BuiltinAppManager
# from app.core.llmops.builtin_apps.entities.builtin_app_entity import BuiltinAppEntity
# from app.core.llmops.builtin_apps.entities.category_entity import CategoryEntity
# from app.core.llmops.entity.app_entity import AppConfigType, AppStatus

# 临时定义
class AppConfigType:
    DRAFT = "draft"
    PUBLISHED = "published"

class AppStatus:
    DRAFT = "draft"
    PUBLISHED = "published"


@inject
@dataclass
class BuiltinAppService(BaseService):
    """内置应用服务（异步版本）"""
    # TODO: 注入依赖
    # builtin_app_manager: BuiltinAppManager

    def get_categories(self) -> list:
        """获取分类列表信息"""
        # TODO: 实现完整的分类获取逻辑
        # return self.builtin_app_manager.get_categories()
        return []

    def get_builtin_apps(self) -> list:
        """获取所有内置应用实体信息列表"""
        # TODO: 实现完整的内置应用获取逻辑
        # return self.builtin_app_manager.get_builtin_apps()
        return []

    async def add_builtin_app_to_space(
        self,
        db: AsyncSession,
        builtin_app_id: str,
        user: User
    ) -> LLMOpsApp:
        """将指定的内置应用添加到个人空间下"""
        # 1.获取内置应用信息，并检测是否存在
        # TODO: 实现完整的内置应用获取逻辑
        # builtin_app = self.builtin_app_manager.get_builtin_app(builtin_app_id)
        # if not builtin_app:
        #     raise NotFoundException("该内置应用不存在，请核实后重试")
        
        # 临时处理
        raise NotFoundException("该内置应用不存在，请核实后重试")

        # 2.创建应用信息
        # app = await self.create(
        #     db,
        #     LLMOpsApp,
        #     user_id=user.id,
        #     status=AppStatus.DRAFT,
        #     **builtin_app.model_dump(include={"name", "icon", "description"})
        # )

        # 3.创建草稿配置信息
        # draft_app_config = await self.create(
        #     db,
        #     AppConfigVersion,
        #     app_id=app.id,
        #     model_config=builtin_app.language_model_config,
        #     config_type=AppConfigType.DRAFT,
        #     **builtin_app.model_dump(include={
        #         "dialog_round", "preset_prompt", "tools", "retrieval_config", "long_term_memory",
        #         "opening_statement", "opening_questions", "speech_to_text", "text_to_speech",
        #         "review_config", "suggested_after_answer",
        #     })
        # )

        # 4.更新应用草稿配置
        # await self.update(db, app, draft_app_config_id=draft_app_config.id)

        # return app

