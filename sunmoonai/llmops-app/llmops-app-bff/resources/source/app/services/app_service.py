#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps App Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
import io
import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Generator, Optional
from uuid import UUID

import requests
from injector import inject
from langchain_community.utilities.dalle_image_generator import DallEAPIWrapper
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableParallel
from langchain_openai import ChatOpenAI
from redis import Redis
from sqlalchemy import select, desc, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload
from werkzeug.datastructures import FileStorage

from app.models.postgresql.llmops_llmops_app import LLMOpsApp, AppConfig, AppConfigVersion, AppDatasetJoin
# Removed: user model is in auth service User
from app.services.llmops.base_service import BaseService
from app.schemas.llmops.app_schema import (
    CreateAppReq,
    UpdateAppReq,
    GetAppsWithPageReq,
    DebugChatReq,
    FallbackHistoryToDraftReq,
    UpdateDebugConversationSummaryReq,
    GetDebugConversationMessagesWithPageReq,
)
from app.core.exceptions import NotFoundException, ForbiddenException, ValidateErrorException, FailException
# TODO: 导入其他依赖的 Service
# from app.services.llmops.app_config_service import AppConfigService
# from app.services.llmops.conversation_service import ConversationService
# from app.services.llmops.cos_service import CosService
# from app.services.llmops.language_model_service import LanguageModelService
# from app.services.llmops.retrieval_service import RetrievalService

# 导入 Entity 和常量
from app.core.llmops.entity.app_entity import (
    AppStatus,
    AppConfigType,
    DEFAULT_APP_CONFIG,
    GENERATE_ICON_PROMPT_TEMPLATE,
)
from app.core.llmops.entity.ai_entity import OPTIMIZE_PROMPT_TEMPLATE
from app.core.llmops.entity.conversation_entity import InvokeFrom, MessageStatus
from app.core.llmops.entity.workflow_entity import WorkflowStatus


@inject
@dataclass
class AppService(BaseService):
    """应用服务逻辑（异步版本）"""
    # TODO: 注入其他依赖
    # redis_client: Redis
    # cos_service: CosService
    # conversation_service: ConversationService
    # retrieval_service: RetrievalService
    # app_config_service: AppConfigService
    # language_model_service: LanguageModelService
    # api_provider_manager: ApiProviderManager
    # builtin_provider_manager: BuiltinProviderManager
    # language_model_manager: LanguageModelManager

    async def create_app(
        self,
        db: AsyncSession,
        req: CreateAppReq,
        user: User
    ) -> LLMOpsApp:
        """创建Agent应用服务"""
        # 1.创建应用记录
        app = LLMOpsApp(
            user_id=user.id,
            name=req.name,
            icon=str(req.icon),  # HttpUrl 转字符串
            description=req.description or "",
            status=AppStatus.DRAFT,
        )
        db.add(app)
        await db.flush()

        # 2.添加草稿记录
        app_config_version = AppConfigVersion(
            app_id=app.id,
            version=0,
            config_type=AppConfigType.DRAFT,
            **DEFAULT_APP_CONFIG,
        )
        db.add(app_config_version)
        await db.flush()

        # 3.为应用添加草稿配置id
        app.draft_app_config_id = app_config_version.id
        await db.commit()
        await db.refresh(app)

        return app

    async def get_app(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> LLMOpsApp:
        """根据传递的id获取应用的基础信息"""
        # 1.查询数据库获取应用基础信息
        app = await self.get(db, LLMOpsApp, app_id)

        # 2.判断应用是否存在
        if not app:
            raise NotFoundException("该应用不存在，请核实后重试")

        # 3.判断当前用户是否有权限访问该应用
        if app.user_id != user.id:
            raise ForbiddenException("当前用户无权限访问该应用，请核实后尝试")

        return app

    async def delete_app(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> LLMOpsApp:
        """根据传递的应用id+用户，删除指定的应用信息"""
        app = await self.get_app(db, app_id, user)
        await self.delete(db, app)
        return app

    async def update_app(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User,
        **kwargs
    ) -> LLMOpsApp:
        """根据传递的应用id+用户+信息，更新指定的应用"""
        app = await self.get_app(db, app_id, user)
        await self.update(db, app, **kwargs)
        return app

    async def get_apps_with_page(
        self,
        db: AsyncSession,
        req: GetAppsWithPageReq,
        user: User
    ) -> tuple[list[LLMOpsApp], dict]:
        """根据传递的分页参数获取当前登录用户下的应用分页列表数据"""
        # 1.构建筛选条件
        filters = [LLMOpsApp.user_id == user.id]
        if req.search_word:
            filters.append(LLMOpsApp.name.ilike(f"%{req.search_word}%"))

        # 2.构建查询
        query = select(LLMOpsApp).where(*filters).order_by(desc(LLMOpsApp.created_at))

        # 3.执行分页查询
        offset = req.offset
        page_size = req.page_size
        
        result = await db.execute(query.offset(offset).limit(page_size))
        apps = result.scalars().all()

        # 4.获取总数
        count_result = await db.execute(
            select(func.count(LLMOpsApp.id)).where(*filters)
        )
        total = count_result.scalar_one()

        # 5.返回分页信息
        paginator = {
            "total": total,
            "current_page": req.current_page,
            "page_size": page_size,
            "total_page": (total + page_size - 1) // page_size if page_size > 0 else 0
        }

        return apps, paginator

    async def copy_app(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> LLMOpsApp:
        """根据传递的应用id，拷贝Agent相关信息并创建一个新Agent"""
        # 1.获取App+草稿配置，并校验权限
        app = await self.get_app(db, app_id, user)
        
        # 2.获取草稿配置（需要通过 Service 层获取，因为原模型的 @property 已移除）
        # 调用 app_config_service 获取草稿配置
        from app.core.service_factories import get_app_config_service
        app_config_service = get_app_config_service()
        draft_app_config = await app_config_service.get_draft_app_config(db, app)
        # draft_app_config = await self.get_draft_app_config(db, app_id, user)
        
        # 临时方案：直接查询
        result = await db.execute(
            select(AppConfigVersion).where(
                AppConfigVersion.app_id == app_id,
                AppConfigVersion.config_type == AppConfigType.DRAFT
            )
        )
        draft_app_config = result.scalar_one_or_none()
        if not draft_app_config:
            raise NotFoundException("草稿配置不存在")

        # 3.创建新应用（复制基础信息）
        new_app = LLMOpsApp(
            user_id=user.id,
            name=f"{app.name} (副本)",
            icon=app.icon,
            description=app.description,
            status=AppStatus.DRAFT,
        )
        db.add(new_app)
        await db.flush()

        # 4.创建新的草稿配置（复制配置信息）
        new_draft_app_config = AppConfigVersion(
            app_id=new_app.id,
            version=0,
            config_type=AppConfigType.DRAFT,
            model_config=draft_app_config.model_config,
            dialog_round=draft_app_config.dialog_round,
            preset_prompt=draft_app_config.preset_prompt,
            tools=draft_app_config.tools,
            workflows=draft_app_config.workflows,
            datasets=draft_app_config.datasets,
            retrieval_config=draft_app_config.retrieval_config,
            long_term_memory=draft_app_config.long_term_memory,
            opening_statement=draft_app_config.opening_statement,
            opening_questions=draft_app_config.opening_questions,
            speech_to_text=draft_app_config.speech_to_text,
            text_to_speech=draft_app_config.text_to_speech,
            suggested_after_answer=draft_app_config.suggested_after_answer,
            review_config=draft_app_config.review_config,
        )
        db.add(new_draft_app_config)
        await db.flush()

        # 5.更新应用的草稿配置id
        new_app.draft_app_config_id = new_draft_app_config.id
        await db.commit()
        await db.refresh(new_app)

        return new_app

    async def get_draft_app_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> dict[str, Any]:
        """根据传递的应用id，获取指定的应用草稿配置信息"""
        app = await self.get_app(db, app_id, user)
        
        # 调用 app_config_service.get_draft_app_config
        # 使用依赖注入获取 app_config_service
        from app.core.service_factories import get_app_config_service
        app_config_service = get_app_config_service()
        # from app.services.llmops.app_config_service import AppConfigService
        # app_config_service = AppConfigService()
        # return await app_config_service.get_draft_app_config(db, app)
        
        # 临时方案：直接查询并转换为字典
        result = await db.execute(
            select(AppConfigVersion).where(
                AppConfigVersion.app_id == app_id,
                AppConfigVersion.config_type == AppConfigType.DRAFT
            )
        )
        draft_app_config = result.scalar_one_or_none()
        if not draft_app_config:
            raise NotFoundException("草稿配置不存在")
        
        return {
            "model_config": draft_app_config.model_config,
            "dialog_round": draft_app_config.dialog_round,
            "preset_prompt": draft_app_config.preset_prompt,
            "tools": draft_app_config.tools,
            "workflows": draft_app_config.workflows,
            "datasets": draft_app_config.datasets,
            "retrieval_config": draft_app_config.retrieval_config,
            "long_term_memory": draft_app_config.long_term_memory,
            "opening_statement": draft_app_config.opening_statement,
            "opening_questions": draft_app_config.opening_questions,
            "speech_to_text": draft_app_config.speech_to_text,
            "text_to_speech": draft_app_config.text_to_speech,
            "suggested_after_answer": draft_app_config.suggested_after_answer,
            "review_config": draft_app_config.review_config,
        }

    async def update_draft_app_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        draft_app_config: dict[str, Any],
        user: User,
    ) -> AppConfigVersion:
        """根据传递的应用id+草稿配置修改指定应用的最新草稿"""
        # 1.获取应用信息并校验
        app = await self.get_app(db, app_id, user)

        # 2.校验传递的草稿配置信息
        draft_app_config = await self._validate_draft_app_config(db, draft_app_config, user)

        # 3.获取当前应用的最新草稿信息
        result = await db.execute(
            select(AppConfigVersion).where(
                AppConfigVersion.app_id == app_id,
                AppConfigVersion.config_type == AppConfigType.DRAFT
            )
        )
        draft_app_config_record = result.scalar_one_or_none()
        if not draft_app_config_record:
            raise NotFoundException("草稿配置不存在")

        # 4.更新草稿配置
        await self.update(
            db,
            draft_app_config_record,
            **draft_app_config,
        )

        return draft_app_config_record

    async def publish_draft_app_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> LLMOpsApp:
        """根据传递的应用id+用户，发布/更新指定的应用草稿配置为运行时配置"""
        # 1.获取应用的信息以及草稿信息
        app = await self.get_app(db, app_id, user)
        draft_app_config = await self.get_draft_app_config(db, app_id, user)

        # 2.创建应用运行配置
        app_config = await self.create(
            db,
            AppConfig,
            app_id=app_id,
            model_config=draft_app_config["model_config"],
            dialog_round=draft_app_config["dialog_round"],
            preset_prompt=draft_app_config["preset_prompt"],
            tools=[
                {
                    "type": tool["type"],
                    "provider_id": tool["provider"]["id"],
                    "tool_id": tool["tool"]["name"],
                    "params": tool["tool"]["params"],
                }
                for tool in draft_app_config["tools"]
            ],
            workflows=[workflow["id"] for workflow in draft_app_config["workflows"]],
            retrieval_config=draft_app_config["retrieval_config"],
            long_term_memory=draft_app_config["long_term_memory"],
            opening_statement=draft_app_config["opening_statement"],
            opening_questions=draft_app_config["opening_questions"],
            speech_to_text=draft_app_config["speech_to_text"],
            text_to_speech=draft_app_config["text_to_speech"],
            suggested_after_answer=draft_app_config["suggested_after_answer"],
            review_config=draft_app_config["review_config"],
        )

        # 3.更新应用关联的运行时配置以及状态
        await self.update(db, app, app_config_id=app_config.id, status=AppStatus.PUBLISHED)

        # 4.先删除原有的知识库关联记录
        await db.execute(
            delete(AppDatasetJoin).where(AppDatasetJoin.app_id == app_id)
        )
        await db.commit()

        # 5.新增新的知识库关联记录
        for dataset in draft_app_config["datasets"]:
            await self.create(
                db,
                AppDatasetJoin,
                app_id=app_id,
                dataset_id=dataset["id"] if isinstance(dataset, dict) else dataset
            )

        # 6.获取当前最大的发布版本
        result = await db.execute(
            select(func.coalesce(func.max(AppConfigVersion.version), 0)).where(
                AppConfigVersion.app_id == app_id,
                AppConfigVersion.config_type == AppConfigType.PUBLISHED,
            )
        )
        max_version = result.scalar_one() or 0

        # 7.获取应用草稿记录，复制为发布历史
        draft_result = await db.execute(
            select(AppConfigVersion).where(
                AppConfigVersion.app_id == app_id,
                AppConfigVersion.config_type == AppConfigType.DRAFT
            )
        )
        draft_config = draft_result.scalar_one_or_none()
        if draft_config:
            # 8.新增发布历史配置
            await self.create(
                db,
                AppConfigVersion,
                app_id=app_id,
                version=max_version + 1,
                config_type=AppConfigType.PUBLISHED,
                model_config=draft_config.model_config,
                dialog_round=draft_config.dialog_round,
                preset_prompt=draft_config.preset_prompt,
                tools=draft_config.tools,
                workflows=draft_config.workflows,
                datasets=draft_config.datasets,
                retrieval_config=draft_config.retrieval_config,
                long_term_memory=draft_config.long_term_memory,
                opening_statement=draft_config.opening_statement,
                opening_questions=draft_config.opening_questions,
                speech_to_text=draft_config.speech_to_text,
                text_to_speech=draft_config.text_to_speech,
                suggested_after_answer=draft_config.suggested_after_answer,
                review_config=draft_config.review_config,
            )

        return app

    async def cancel_publish_app_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> LLMOpsApp:
        """根据传递的应用id+用户，取消发布指定的应用配置"""
        # 1.获取应用信息并校验权限
        app = await self.get_app(db, app_id, user)

        # 2.检测下当前应用的状态是否为已发布
        if app.status != AppStatus.PUBLISHED:
            raise FailException("当前应用未发布，请核实后重试")

        # 3.修改应用的发布状态，并清空关联配置id
        await self.update(db, app, status=AppStatus.DRAFT, app_config_id=None)

        # 4.删除应用关联的知识库信息
        await db.execute(
            delete(AppDatasetJoin).where(AppDatasetJoin.app_id == app_id)
        )
        await db.commit()

        return app

    async def get_publish_histories_with_page(
        self,
        db: AsyncSession,
        app_id: UUID,
        req,  # TODO: GetPublishHistoriesWithPageReq
        user: User
    ) -> tuple[list[AppConfigVersion], dict]:
        """根据传递的应用id+请求数据，获取指定应用的发布历史配置列表信息"""
        # 1.获取应用信息并校验权限
        await self.get_app(db, app_id, user)

        # 2.构建筛选条件
        filters = [
            AppConfigVersion.app_id == app_id,
            AppConfigVersion.config_type == AppConfigType.PUBLISHED,
        ]

        # 3.构建查询
        query = select(AppConfigVersion).where(*filters).order_by(desc(AppConfigVersion.version))

        # 4.执行分页查询
        offset = req.offset if hasattr(req, 'offset') else 0
        page_size = req.page_size if hasattr(req, 'page_size') else 20
        
        result = await db.execute(query.offset(offset).limit(page_size))
        app_config_versions = result.scalars().all()

        # 5.获取总数
        count_result = await db.execute(
            select(func.count(AppConfigVersion.id)).where(*filters)
        )
        total = count_result.scalar_one()

        # 6.返回分页信息
        paginator = {
            "total": total,
            "current_page": req.current_page if hasattr(req, 'current_page') else 1,
            "page_size": page_size,
            "total_page": (total + page_size - 1) // page_size if page_size > 0 else 0
        }

        return app_config_versions, paginator

    async def fallback_history_to_draft(
        self,
        db: AsyncSession,
        app_id: UUID,
        app_config_version_id: UUID,
        user: User,
    ) -> AppConfigVersion:
        """根据传递的应用id、历史配置版本id、用户信息，回退特定配置到草稿"""
        # 1.校验应用权限并获取信息
        app = await self.get_app(db, app_id, user)

        # 2.查询指定的历史版本配置id
        app_config_version = await self.get(db, AppConfigVersion, app_config_version_id)
        if not app_config_version:
            raise NotFoundException("该历史版本配置不存在，请核实后重试")

        # 3.校验历史版本配置信息（剔除已删除的工具、知识库、工作流）
        draft_app_config_dict = {
            "model_config": app_config_version.model_config,
            "dialog_round": app_config_version.dialog_round,
            "preset_prompt": app_config_version.preset_prompt,
            "tools": app_config_version.tools,
            "workflows": app_config_version.workflows,
            "datasets": app_config_version.datasets,
            "retrieval_config": app_config_version.retrieval_config,
            "long_term_memory": app_config_version.long_term_memory,
            "opening_statement": app_config_version.opening_statement,
            "opening_questions": app_config_version.opening_questions,
            "speech_to_text": app_config_version.speech_to_text,
            "text_to_speech": app_config_version.text_to_speech,
            "suggested_after_answer": app_config_version.suggested_after_answer,
            "review_config": app_config_version.review_config,
        }

        # 4.校验历史版本配置信息
        draft_app_config_dict = await self._validate_draft_app_config(db, draft_app_config_dict, user)

        # 5.获取草稿配置记录
        result = await db.execute(
            select(AppConfigVersion).where(
                AppConfigVersion.app_id == app_id,
                AppConfigVersion.config_type == AppConfigType.DRAFT
            )
        )
        draft_app_config_record = result.scalar_one_or_none()
        if not draft_app_config_record:
            raise NotFoundException("草稿配置不存在")

        # 6.更新草稿配置信息
        await self.update(
            db,
            draft_app_config_record,
            **draft_app_config_dict,
        )

        return draft_app_config_record

    async def delete_debug_conversation(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> LLMOpsApp:
        """根据传递的应用id，删除指定的应用调试会话"""
        # 1.获取应用信息并校验权限
        app = await self.get_app(db, app_id, user)

        # 2.判断是否存在debug_conversation_id这个数据，如果不存在表示没有会话，无需执行任何操作
        if not app.debug_conversation_id:
            return app

        # 3.否则将debug_conversation_id的值重置为None
        await self.update(db, app, debug_conversation_id=None)

        return app

    async def get_published_config(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> dict[str, Any]:
        """根据传递的应用id+用户，获取应用的发布配置"""
        # 1.获取应用信息并校验权限
        app = await self.get_app(db, app_id, user)

        # 2.获取 token（需要实现 token_with_default 的逻辑）
        # TODO: 实现 token_with_default 的逻辑（原模型中的 @property 方法）
        token = app.token or ""
        if app.status == AppStatus.PUBLISHED and not token:
            import random
            import string
            token = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
            await self.update(db, app, token=token)

        # 3.构建发布配置并返回
        return {
            "web_app": {
                "token": token if app.status == AppStatus.PUBLISHED else "",
                "status": app.status,
            }
        }

    async def regenerate_web_app_token(
        self,
        db: AsyncSession,
        app_id: UUID,
        user: User
    ) -> str:
        """根据传递的应用id+用户，重新生成WebApp凭证标识"""
        # 1.获取应用信息并校验权限
        app = await self.get_app(db, app_id, user)

        # 2.判断应用是否已发布
        if app.status != AppStatus.PUBLISHED:
            raise FailException("应用未发布，无法生成WebApp凭证标识")

        # 3.重新生成token并更新数据
        import random
        import string
        token = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
        await self.update(db, app, token=token)

        return token

    # TODO: 以下方法需要依赖其他 Service，暂时标记 TODO
    # - get_debug_conversation_summary (需要 conversation service 和 debug_conversation 的 @property)
    # - update_debug_conversation_summary (需要 conversation service)
    # - debug_chat (复杂，涉及 Agent、LangChain、流式响应，需要完整迁移 Agent 相关代码)
    # - stop_debug_chat (需要 AgentQueueManager)
    # - get_debug_conversation_messages_with_page (需要 conversation service 和 Message 模型)
    
    async def _validate_draft_app_config(
        self,
        db: AsyncSession,
        draft_app_config: dict[str, Any],
        user: User
    ) -> dict[str, Any]:
        """校验传递的应用草稿配置信息，返回校验后的数据"""
        from app.models.postgresql.llmops_llmops_workflow import Workflow
        from app.models.postgresql.llmops_llmops_dataset import Dataset
        from app.models.postgresql.llmops_llmops_api_tool import ApiTool, ApiToolProvider
        from app.core.llmops.entity.workflow_entity import WorkflowStatus
        from app.utils.llmops_helper import get_value_type
        
        # 1. 校验上传的草稿配置中对应的字段，至少拥有一个可以更新的配置
        acceptable_fields = [
            "model_config", "dialog_round", "preset_prompt",
            "tools", "workflows", "datasets", "retrieval_config",
            "long_term_memory", "opening_statement", "opening_questions",
            "speech_to_text", "text_to_speech", "suggested_after_answer", "review_config",
        ]

        # 2. 判断传递的草稿配置是否在可接受字段内
        if (
                not draft_app_config
                or not isinstance(draft_app_config, dict)
                or set(draft_app_config.keys()) - set(acceptable_fields)
        ):
            raise ValidateErrorException("草稿配置字段出错，请核实后重试")

        # 3. 校验 model_config 字段
        if "model_config" in draft_app_config:
            model_config = draft_app_config["model_config"]
            if not isinstance(model_config, dict):
                raise ValidateErrorException("模型配置格式错误，请核实后重试")

            # 3.1 判断 model_config 键信息是否正确
            if set(model_config.keys()) != {"provider", "model", "parameters"}:
                raise ValidateErrorException("模型键配置格式错误，请核实后重试")

            # 3.2 判断模型提供者信息是否正确
            if not model_config["provider"] or not isinstance(model_config["provider"], str):
                raise ValidateErrorException("模型服务提供商类型必须为字符串")
            
            # TODO: 需要 language_model_manager 来验证 provider 和 model
            # provider = self.language_model_manager.get_provider(model_config["provider"])
            # if not provider:
            #     raise ValidateErrorException("该模型服务提供商不存在，请核实后重试")
            # model_entity = provider.get_model_entity(model_config["model"])
            # if not model_entity:
            #     raise ValidateErrorException("该服务提供商下不存在该模型，请核实后重试")
            
            # 3.3 判断模型信息是否正确
            if not model_config["model"] or not isinstance(model_config["model"], str):
                raise ValidateErrorException("模型名字必须是字符串")
            
            # 3.4 校验 parameters（简化版本，完整版本需要 model_entity）
            if "parameters" in model_config:
                parameters = model_config["parameters"]
                if not isinstance(parameters, dict):
                    raise ValidateErrorException("模型参数配置格式错误")
                # 基本参数校验
                for param_name, param_value in parameters.items():
                    if param_name in ["temperature", "top_p"]:
                        if not isinstance(param_value, (int, float)) or not (0 <= param_value <= 1):
                            parameters[param_name] = 0.5 if param_name == "temperature" else 0.85
                    elif param_name in ["frequency_penalty", "presence_penalty"]:
                        if not isinstance(param_value, (int, float)) or not (-2 <= param_value <= 2):
                            parameters[param_name] = 0.2
                    elif param_name == "max_tokens":
                        if not isinstance(param_value, int) or not (1 <= param_value <= 8192):
                            parameters[param_name] = 8192
                
                model_config["parameters"] = parameters
                draft_app_config["model_config"] = model_config

        # 4. 校验 dialog_round 上下文轮数
        if "dialog_round" in draft_app_config:
            dialog_round = draft_app_config["dialog_round"]
            if not isinstance(dialog_round, int) or not (0 <= dialog_round <= 100):
                raise ValidateErrorException("携带上下文轮数范围为0-100")

        # 5. 校验 preset_prompt
        if "preset_prompt" in draft_app_config:
            preset_prompt = draft_app_config["preset_prompt"]
            if not isinstance(preset_prompt, str) or len(preset_prompt) > 2000:
                raise ValidateErrorException("人设与回复逻辑必须是字符串，长度在0-2000个字符")

        # 6. 校验 tools 工具
        if "tools" in draft_app_config:
            tools = draft_app_config["tools"]
            validate_tools = []

            # 6.1 tools 类型必须为列表
            if not isinstance(tools, list):
                raise ValidateErrorException("工具列表必须是列表型数据")
            # 6.2 tools 的长度不能超过5
            if len(tools) > 5:
                raise ValidateErrorException("Agent绑定的工具数不能超过5")
            # 6.3 循环校验工具里的每一个参数
            for tool in tools:
                # 6.4 校验 tool 非空并且类型为字典
                if not tool or not isinstance(tool, dict):
                    raise ValidateErrorException("绑定插件工具参数出错")
                # 6.5 校验工具的参数是不是 type、provider_id、tool_id、params
                if set(tool.keys()) != {"type", "provider_id", "tool_id", "params"}:
                    raise ValidateErrorException("绑定插件工具参数出错")
                # 6.6 校验 type 类型是否为 builtin_tool 以及 api_tool
                if tool["type"] not in ["builtin_tool", "api_tool"]:
                    raise ValidateErrorException("绑定插件工具参数出错")
                # 6.7 校验 provider_id 和 tool_id
                if (
                        not tool["provider_id"]
                        or not tool["tool_id"]
                        or not isinstance(tool["provider_id"], str)
                        or not isinstance(tool["tool_id"], str)
                ):
                    raise ValidateErrorException("插件提供者或者插件标识参数出错")
                # 6.8 校验 params 参数，类型为字典
                if not isinstance(tool["params"], dict):
                    raise ValidateErrorException("插件自定义参数格式错误")
                # 6.9 校验对应的工具是否存在
                if tool["type"] == "builtin_tool":
                    # TODO: 需要 builtin_provider_manager 来验证
                    # builtin_tool = self.builtin_provider_manager.get_tool(tool["provider_id"], tool["tool_id"])
                    # if not builtin_tool:
                    #     continue
                    validate_tools.append(tool)
                else:
                    # 查询数据库验证 api_tool
                    result = await db.execute(
                        select(ApiTool).where(
                            ApiTool.provider_id == tool["provider_id"],
                            ApiTool.name == tool["tool_id"],
                            ApiTool.user_id == user.id,
                        )
                    )
                    api_tool = result.scalar_one_or_none()
                    if not api_tool:
                        continue
                    validate_tools.append(tool)

            # 6.10 校验绑定的工具是否重复
            check_tools = [f"{tool['provider_id']}_{tool['tool_id']}" for tool in validate_tools]
            if len(set(check_tools)) != len(validate_tools):
                raise ValidateErrorException("绑定插件存在重复")

            # 6.11 重新赋值工具
            draft_app_config["tools"] = validate_tools

        # 7. 校验 workflow，提取已发布+权限正确的工作流列表进行绑定
        if "workflows" in draft_app_config:
            workflows = draft_app_config["workflows"]

            # 7.1 判断 workflows 是否为列表
            if not isinstance(workflows, list):
                raise ValidateErrorException("绑定工作流列表参数格式错误")
            # 7.2 判断关联的工作流列表是否超过5个
            if len(workflows) > 5:
                raise ValidateErrorException("Agent绑定的工作流数量不能超过5个")
            # 7.3 循环校验工作流的每个参数，类型必须为UUID
            workflow_ids = []
            for workflow_id in workflows:
                try:
                    workflow_ids.append(UUID(workflow_id) if isinstance(workflow_id, str) else workflow_id)
                except Exception:
                    raise ValidateErrorException("工作流参数必须是UUID")
            # 7.4 判断是否重复关联了工作流
            if len(set(workflow_ids)) != len(workflow_ids):
                raise ValidateErrorException("绑定工作流存在重复")
            # 7.5 校验关联工作流的权限，剔除不属于当前用户，亦或者未发布的工作流
            result = await db.execute(
                select(Workflow).where(
                    Workflow.id.in_(workflow_ids),
                    Workflow.user_id == user.id,
                    Workflow.status == WorkflowStatus.PUBLISHED,
                )
            )
            workflow_records = result.scalars().all()
            workflow_sets = set([str(workflow_record.id) for workflow_record in workflow_records])
            draft_app_config["workflows"] = [str(wid) for wid in workflow_ids if str(wid) in workflow_sets]

        # 8. 校验 datasets 知识库列表
        if "datasets" in draft_app_config:
            datasets = draft_app_config["datasets"]

            # 8.1 判断 datasets 类型是否为列表
            if not isinstance(datasets, list):
                raise ValidateErrorException("绑定知识库列表参数格式错误")
            # 8.2 判断关联的知识库列表是否超过5个
            if len(datasets) > 5:
                raise ValidateErrorException("Agent绑定的知识库数量不能超过5个")
            # 8.3 循环校验知识库的每个参数
            dataset_ids = []
            for dataset_id in datasets:
                try:
                    dataset_ids.append(UUID(dataset_id) if isinstance(dataset_id, str) else dataset_id)
                except Exception:
                    raise ValidateErrorException("知识库列表参数必须是UUID")
            # 8.4 判断是否传递了重复的知识库
            if len(set(dataset_ids)) != len(dataset_ids):
                raise ValidateErrorException("绑定知识库存在重复")
            # 8.5 校验绑定的知识库权限，剔除不属于当前用户的知识库
            result = await db.execute(
                select(Dataset).where(
                    Dataset.id.in_(dataset_ids),
                    Dataset.user_id == user.id,
                )
            )
            dataset_records = result.scalars().all()
            dataset_sets = set([str(dataset_record.id) for dataset_record in dataset_records])
            draft_app_config["datasets"] = [str(did) for did in dataset_ids if str(did) in dataset_sets]

        # 9. 校验 retrieval_config 检索配置
        if "retrieval_config" in draft_app_config:
            retrieval_config = draft_app_config["retrieval_config"]
            if not isinstance(retrieval_config, dict):
                raise ValidateErrorException("检索配置格式错误")
            
            # 9.1 校验 retrieval_strategy
            if "retrieval_strategy" in retrieval_config:
                from app.core.llmops.entity.dataset_entity import RetrievalStrategy
                strategy = retrieval_config["retrieval_strategy"]
                if strategy not in [RetrievalStrategy.FULL_TEXT, RetrievalStrategy.SEMANTIC, RetrievalStrategy.HYBRID]:
                    raise ValidateErrorException("检索策略参数错误")
            
            # 9.2 校验 k
            if "k" in retrieval_config:
                k = retrieval_config["k"]
                if not isinstance(k, int) or not (1 <= k <= 20):
                    raise ValidateErrorException("检索数量k范围为1-20")
            
            # 9.3 校验 score
            if "score" in retrieval_config:
                score = retrieval_config["score"]
                if not isinstance(score, (int, float)) or not (0 <= score <= 1):
                    raise ValidateErrorException("检索匹配度score范围为0-1")

        # 10. 校验 long_term_memory 长期记忆
        if "long_term_memory" in draft_app_config:
            long_term_memory = draft_app_config["long_term_memory"]
            if not isinstance(long_term_memory, dict):
                raise ValidateErrorException("长期记忆配置格式错误")
            if "enable" in long_term_memory:
                if not isinstance(long_term_memory["enable"], bool):
                    raise ValidateErrorException("长期记忆启用状态必须是布尔值")

        # 11. 校验 opening_statement 开场白
        if "opening_statement" in draft_app_config:
            opening_statement = draft_app_config["opening_statement"]
            if not isinstance(opening_statement, str) or len(opening_statement) > 2000:
                raise ValidateErrorException("开场白必须是字符串，长度在0-2000个字符")

        # 12. 校验 opening_questions 开场问题
        if "opening_questions" in draft_app_config:
            opening_questions = draft_app_config["opening_questions"]
            if not isinstance(opening_questions, list):
                raise ValidateErrorException("开场问题列表必须是列表型数据")
            if len(opening_questions) > 5:
                raise ValidateErrorException("开场问题数量不能超过5个")
            for question in opening_questions:
                if not isinstance(question, str) or len(question) > 100:
                    raise ValidateErrorException("开场问题必须是字符串，长度在0-100个字符")

        # 13. 校验 speech_to_text 语音转文字
        if "speech_to_text" in draft_app_config:
            speech_to_text = draft_app_config["speech_to_text"]
            if not isinstance(speech_to_text, dict):
                raise ValidateErrorException("语音转文字配置格式错误")
            if "enable" in speech_to_text:
                if not isinstance(speech_to_text["enable"], bool):
                    raise ValidateErrorException("语音转文字启用状态必须是布尔值")

        # 14. 校验 text_to_speech 文字转语音
        if "text_to_speech" in draft_app_config:
            text_to_speech = draft_app_config["text_to_speech"]
            if not isinstance(text_to_speech, dict):
                raise ValidateErrorException("文字转语音配置格式错误")
            if "enable" in text_to_speech:
                if not isinstance(text_to_speech["enable"], bool):
                    raise ValidateErrorException("文字转语音启用状态必须是布尔值")
            if "voice" in text_to_speech:
                from app.core.llmops.entity.audio_entity import ALLOWED_AUDIO_VOICES
                if text_to_speech["voice"] not in ALLOWED_AUDIO_VOICES:
                    raise ValidateErrorException(f"语音音色必须是 {ALLOWED_AUDIO_VOICES} 之一")
            if "auto_play" in text_to_speech:
                if not isinstance(text_to_speech["auto_play"], bool):
                    raise ValidateErrorException("自动播放状态必须是布尔值")

        # 15. 校验 suggested_after_answer 回答后建议问题
        if "suggested_after_answer" in draft_app_config:
            suggested_after_answer = draft_app_config["suggested_after_answer"]
            if not isinstance(suggested_after_answer, dict):
                raise ValidateErrorException("回答后建议问题配置格式错误")
            if "enable" in suggested_after_answer:
                if not isinstance(suggested_after_answer["enable"], bool):
                    raise ValidateErrorException("回答后建议问题启用状态必须是布尔值")

        # 16. 校验 review_config 审核配置
        if "review_config" in draft_app_config:
            review_config = draft_app_config["review_config"]
            if not isinstance(review_config, dict):
                raise ValidateErrorException("审核配置格式错误")
            if "enable" in review_config:
                if not isinstance(review_config["enable"], bool):
                    raise ValidateErrorException("审核启用状态必须是布尔值")
            if "keywords" in review_config:
                keywords = review_config["keywords"]
                if not isinstance(keywords, list):
                    raise ValidateErrorException("审核关键词列表必须是列表型数据")
                for keyword in keywords:
                    if not isinstance(keyword, str):
                        raise ValidateErrorException("审核关键词必须是字符串")
            if "inputs_config" in review_config:
                inputs_config = review_config["inputs_config"]
                if not isinstance(inputs_config, dict):
                    raise ValidateErrorException("输入审核配置格式错误")
                if "enable" in inputs_config:
                    if not isinstance(inputs_config["enable"], bool):
                        raise ValidateErrorException("输入审核启用状态必须是布尔值")
                if "preset_response" in inputs_config:
                    if not isinstance(inputs_config["preset_response"], str) or len(inputs_config["preset_response"]) > 500:
                        raise ValidateErrorException("输入审核预设回复必须是字符串，长度在0-500个字符")
            if "outputs_config" in review_config:
                outputs_config = review_config["outputs_config"]
                if not isinstance(outputs_config, dict):
                    raise ValidateErrorException("输出审核配置格式错误")
                if "enable" in outputs_config:
                    if not isinstance(outputs_config["enable"], bool):
                        raise ValidateErrorException("输出审核启用状态必须是布尔值")

        return draft_app_config

