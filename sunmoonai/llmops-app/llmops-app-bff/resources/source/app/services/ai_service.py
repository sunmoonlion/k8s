#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps AI Service - 从 imooc-llmops 迁移
AI 服务（部分保持同步，因为 LangChain 是同步的）
Account 已改为 User，account_id 已改为 user_id
"""
import json
from dataclasses import dataclass
from typing import Generator
from uuid import UUID

from injector import inject
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_conversation import Message
from app.services.llmops.base_service import BaseService
from app.services.llmops.conversation_service import ConversationService
from app.core.exceptions import ForbiddenException
import asyncio

# 导入 Entity
from app.core.llmops.entity.ai_entity import OPTIMIZE_PROMPT_TEMPLATE


@inject
@dataclass
class AIService(BaseService):
    """AI服务（部分保持同步）"""
    conversation_service: ConversationService

    async def generate_suggested_questions_from_message_id(
        self,
        db: AsyncSession,
        message_id: UUID,
        user: User
    ) -> list[str]:
        """根据传递的消息id+用户生成建议问题列表"""
        # 1.查询消息并校验权限信息
        message = await self.get(db, Message, message_id)
        if not message or message.user_id != user.id:
            raise ForbiddenException("该条消息不存在或无权限")

        # 2.构建对话历史列表
        histories = f"Human: {message.query}\nAI: {message.answer}"

        # 3.调用服务生成建议问题（同步方法）
        return await asyncio.to_thread(
            self.conversation_service.generate_suggested_questions,
            histories
        )

    @classmethod
    def optimize_prompt(cls, prompt: str) -> Generator[str, None, None]:
        """根据传递的prompt进行优化生成（保持同步，因为 LangChain 是同步的）"""
        # 1.构建优化prompt的提示词模板
        prompt_template = ChatPromptTemplate.from_messages([
            ("system", OPTIMIZE_PROMPT_TEMPLATE),
            ("human", "{prompt}")
        ])

        # 2.构建LLM
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.5)

        # 3.组装优化链
        optimize_chain = prompt_template | llm | StrOutputParser()

        # 4.调用链并流式事件返回
        for optimize_prompt in optimize_chain.stream({"prompt": prompt}):
            # 5.组装响应数据
            data = {"optimize_prompt": optimize_prompt}
            yield f"event: optimize_prompt\ndata: {json.dumps(data)}\n\n"

