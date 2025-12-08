#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Web App Service - 从 imooc-llmops 迁移
WebApp服务（部分保持同步，因为 Agent 是同步的）
Account 已改为 User，account_id 已改为 user_id
"""
import json
from dataclasses import dataclass
from typing import Generator, Any
from uuid import UUID

from injector import inject
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_app import LLMOpsApp
from app.models.postgresql.llmops_llmops_conversation import Conversation, Message
from app.services.llmops.base_service import BaseService
from app.services.llmops.app_config_service import AppConfigService
from app.services.llmops.conversation_service import ConversationService
from app.services.llmops.language_model_service import LanguageModelService
from app.services.llmops.retrieval_service import RetrievalService
from app.core.exceptions import NotFoundException, ForbiddenException

# TODO: 导入依赖
# from app.core.llmops.agent.agents import FunctionCallAgent, ReACTAgent, AgentQueueManager
# from app.core.llmops.agent.entities.agent_entity import AgentConfig
# from app.core.llmops.agent.entities.queue_entity import QueueEvent
# from app.core.llmops.language_model.entities.model_entity import ModelFeature
# from app.core.llmops.memory import TokenBufferMemory
# from app.core.llmops.entity.app_entity import AppStatus
# from app.core.llmops.entity.conversation_entity import InvokeFrom, MessageStatus
# from app.core.llmops.entity.dataset_entity import RetrievalSource
# from app.schemas.llmops.web_app_schema import WebAppChatReq

# 临时定义
class AppStatus:
    DRAFT = "draft"
    PUBLISHED = "published"

class InvokeFrom:
    WEB_APP = "web_app"

class MessageStatus:
    NORMAL = "normal"


@inject
@dataclass
class WebAppService(BaseService):
    """WebApp服务（部分保持同步）"""
    app_config_service: AppConfigService
    retrieval_service: RetrievalService
    conversation_service: ConversationService
    language_model_service: LanguageModelService

    async def get_web_app(
        self,
        db: AsyncSession,
        token: str
    ) -> LLMOpsApp:
        """根据传递的token获取WebApp实例"""
        # 1.在数据库中查询token对应的应用
        result = await db.execute(
            select(LLMOpsApp).where(LLMOpsApp.token == token)
        )
        app = result.scalar_one_or_none()
        if not app or app.status != AppStatus.PUBLISHED:
            raise NotFoundException("该WebApp不存在或者未发布，请核实后重试")

        # 2.返回查询的应用
        return app

    async def get_web_app_info(
        self,
        db: AsyncSession,
        token: str
    ) -> dict[str, Any]:
        """根据传递的token获取WebApp信息"""
        # 1.获取App基础信息
        app = await self.get_web_app(db, token)

        # 2.根据App基础信息构建LLM
        app_config = await self.app_config_service.get_app_config(db, app)
        # TODO: 加载语言模型
        # llm = self.language_model_service.load_language_model(app_config.get("model_config", {}))

        # 3.提取信息并返回
        return {
            "id": str(app.id),
            "icon": app.icon,
            "name": app.name,
            "description": app.description,
            "app_config": {
                "opening_statement": app_config.get("opening_statement"),
                "opening_questions": app_config.get("opening_questions"),
                "suggested_after_answer": app_config.get("suggested_after_answer"),
                # "features": llm.features,
                "text_to_speech": app_config.get("text_to_speech"),
                "speech_to_text": app_config.get("speech_to_text"),
            }
        }

    async def web_app_chat(
        self,
        db: AsyncSession,
        token: str,
        query: str,
        image_urls: list[str] | None,
        conversation_id: UUID | None,
        stream: bool,
        user: User
    ) -> Generator:
        """根据传递的token凭证+请求与指定的WebApp进行对话"""
        # TODO: 实现完整的 WebApp 聊天逻辑
        # 1.获取WebApp应用并校验应用是否发布
        # 2.检测是否传递了会话id
        # 3.获取校验后的运行时配置
        # 4.新建一条消息记录
        # 5.从语言模型管理器中加载大语言模型
        # 6.实例化TokenBufferMemory用于提取短期记忆
        # 7.将草稿配置中的tools转换成LangChain工具
        # 8.检测是否关联了知识库
        # 9.检测是否关联工作流
        # 10.根据LLM是否支持tool_call决定使用不同的Agent
        # 11.流式或块内容输出
        
        # 临时返回空生成器
        yield ""

    async def stop_web_app_chat(
        self,
        db: AsyncSession,
        token: str,
        task_id: UUID,
        user: User
    ):
        """根据传递的token+task_id停止与指定WebApp对话"""
        # TODO: 实现停止聊天逻辑
        # 1.获取WebApp应用并校验应用是否发布
        # 2.调用智能体队列管理器停止特定任务
        # AgentQueueManager.set_stop_flag(task_id, InvokeFrom.WEB_APP, user.id)
        pass

    async def get_conversations(
        self,
        db: AsyncSession,
        token: str,
        is_pinned: bool,
        user: User
    ) -> list[Conversation]:
        """根据传递的token+is_pinned+user获取指定用户在该WebApp下的会话列表数据"""
        # 1.获取WebApp应用并校验应用是否发布
        app = await self.get_web_app(db, token)

        # 2.筛选过滤并查询数据
        result = await db.execute(
            select(Conversation).where(
                Conversation.app_id == app.id,
                Conversation.user_id == user.id,
                Conversation.invoke_from == InvokeFrom.WEB_APP,
                Conversation.is_pinned == is_pinned,
                ~Conversation.is_deleted,
            ).order_by(desc(Conversation.created_at))
        )
        return result.scalars().all()

