#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Conversation Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from injector import inject
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.postgresql.llmops_llmops_conversation import Conversation, Message, MessageAgentThought
# Removed: user model is in auth service User
from app.services.llmops.base_service import BaseService
from app.core.exceptions import NotFoundException, ForbiddenException

# 导入 Entity 和常量
from app.core.llmops.entity.conversation_entity import (
    SUMMARIZER_TEMPLATE,
    CONVERSATION_NAME_TEMPLATE,
    ConversationInfo,
    SUGGESTED_QUESTIONS_TEMPLATE,
    SuggestedQuestions,
    InvokeFrom,
    MessageStatus,
)
# TODO: 导入 Agent Entity
# from app.core.llmops.entity.agent.queue_entity import AgentThought, QueueEvent


@inject
@dataclass
class ConversationService(BaseService):
    """会话服务（异步版本）"""

    @classmethod
    def summary(cls, human_message: str, ai_message: str, old_summary: str = "") -> str:
        """根据传递的人类消息、AI消息还有原始的摘要信息总结生成一段新的摘要"""
        # 1.创建prompt
        prompt = ChatPromptTemplate.from_template(SUMMARIZER_TEMPLATE)

        # 2.构建大语言模型实例，并且将大语言模型的温度调低，降低幻觉的概率
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.5)

        # 3.构建链应用
        summary_chain = prompt | llm | StrOutputParser()

        # 4.调用链并获取新摘要信息
        new_summary = summary_chain.invoke({
            "summary": old_summary,
            "new_lines": f"Human: {human_message}\nAI: {ai_message}",
        })

        return new_summary

    @classmethod
    def generate_conversation_name(cls, query: str) -> str:
        """根据传递的query生成对应的会话名字，并且语言与用户的输入保持一致"""
        # 1.创建prompt
        prompt = ChatPromptTemplate.from_messages([
            ("system", CONVERSATION_NAME_TEMPLATE),
            ("human", "{query}")
        ])

        # 2.构建大语言模型实例，并且将大语言模型的温度调低，降低幻觉的概率
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)
        # TODO: 使用 structured_llm 如果 ConversationInfo 已定义
        # structured_llm = llm.with_structured_output(ConversationInfo)

        # 3.构建链应用
        chain = prompt | llm | StrOutputParser()

        # 4.提取并整理query，截取长度过长的部分
        if len(query) > 2000:
            query = query[:300] + "...[TRUNCATED]..." + query[-300:]
        query = query.replace("\n", " ")

        # 5.调用链并获取会话信息
        try:
            name = chain.invoke({"query": query})
            # TODO: 如果使用 structured_llm，提取 subject
            # if conversation_info and hasattr(conversation_info, "subject"):
            #     name = conversation_info.subject
        except Exception as e:
            logging.exception(
                "提取会话名称出错, query: %(query)s, 错误信息: %(error)s",
                {"query": query, "error": e},
            )
            name = "新的会话"
        
        if len(name) > 75:
            name = name[:75] + "..."

        return name

    @classmethod
    def generate_suggested_questions(cls, histories: str) -> list[str]:
        """根据传递的历史信息生成最多不超过3个的建议问题"""
        # 1.创建prompt
        prompt = ChatPromptTemplate.from_messages([
            ("system", SUGGESTED_QUESTIONS_TEMPLATE),
            ("human", "{histories}")
        ])

        # 2.构建大语言模型实例，并且将大语言模型的温度调低，降低幻觉的概率
        llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)
        # TODO: 使用 structured_llm 如果 SuggestedQuestions 已定义
        # structured_llm = llm.with_structured_output(SuggestedQuestions)

        # 3.构建链应用
        chain = prompt | llm | StrOutputParser()

        # 4.调用链并获取建议问题列表
        try:
            questions_str = chain.invoke({"histories": histories})
            # TODO: 解析 questions_str 为列表，或使用 structured_llm
            # if suggested_questions and hasattr(suggested_questions, "questions"):
            #     questions = suggested_questions.questions
            questions = [q.strip() for q in questions_str.split("\n") if q.strip()][:3]
        except Exception as e:
            logging.exception(
                "生成建议问题出错, histories: %(histories)s, 错误信息: %(error)s",
                {"histories": histories, "error": e},
            )
            questions = []
        
        if len(questions) > 3:
            questions = questions[:3]

        return questions

    async def save_agent_thoughts(
        self,
        db: AsyncSession,
        user_id: UUID,
        app_id: UUID,
        app_config: dict[str, Any],
        conversation_id: UUID,
        message_id: UUID,
        agent_thoughts: list,  # TODO: list[AgentThought]
    ):
        """存储智能体推理步骤消息"""
        # 1.定义变量存储推理位置及总耗时
        position = 0
        latency = 0.0
        total_token_count = 0
        total_price = 0.0

        # 2.获取会话和消息记录
        conversation = await self.get(db, Conversation, conversation_id)
        if not conversation:
            raise NotFoundException("会话不存在")
        
        message = await self.get(db, Message, message_id)
        if not message:
            raise NotFoundException("消息不存在")

        # 3.循环遍历推理步骤并存储
        for agent_thought in agent_thoughts:
            position += 1
            latency += getattr(agent_thought, 'latency', 0.0)
            total_token_count += getattr(agent_thought, 'total_token_count', 0)
            total_price += getattr(agent_thought, 'total_price', 0.0)

            # TODO: 根据 AgentThought 的实际结构创建 MessageAgentThought
            message_agent_thought = MessageAgentThought(
                app_id=app_id,
                conversation_id=conversation_id,
                message_id=message_id,
                invoke_from=getattr(agent_thought, 'invoke_from', 'debugger'),
                created_by=user_id,
                position=position,
                event=getattr(agent_thought, 'event', ''),
                thought=getattr(agent_thought, 'thought', ''),
                observation=getattr(agent_thought, 'observation', ''),
                tool=getattr(agent_thought, 'tool', ''),
                tool_input=getattr(agent_thought, 'tool_input', {}),
                message=getattr(agent_thought, 'message', []),
                message_token_count=getattr(agent_thought, 'message_token_count', 0),
                message_unit_price=getattr(agent_thought, 'message_unit_price', 0.0),
                message_price_unit=getattr(agent_thought, 'message_price_unit', 0.0),
                answer=getattr(agent_thought, 'answer', ''),
                answer_token_count=getattr(agent_thought, 'answer_token_count', 0),
                answer_unit_price=getattr(agent_thought, 'answer_unit_price', 0.0),
                answer_price_unit=getattr(agent_thought, 'answer_price_unit', 0.0),
                total_token_count=getattr(agent_thought, 'total_token_count', 0),
                total_price=getattr(agent_thought, 'total_price', 0.0),
                latency=getattr(agent_thought, 'latency', 0.0),
            )
            db.add(message_agent_thought)

        # 4.更新消息记录
        await self.update(
            db,
            message,
            total_token_count=total_token_count,
            total_price=total_price,
            latency=latency,
        )

        # 5.更新会话记录
        await self.update(
            db,
            conversation,
            updated_at=datetime.utcnow(),
        )

        await db.commit()

    async def get_conversation(
        self,
        db: AsyncSession,
        conversation_id: UUID,
        user: User
    ) -> Conversation:
        """根据传递的会话id获取会话记录"""
        conversation = await self.get(db, Conversation, conversation_id)
        if not conversation:
            raise NotFoundException("该会话不存在")

        # TODO: 校验权限（需要根据业务逻辑判断）
        # 这里暂时跳过权限校验，因为 Conversation 可能没有直接的 user_id 字段
        # 需要通过 app_id 或其他方式校验

        return conversation

    async def get_message(
        self,
        db: AsyncSession,
        message_id: UUID,
        user: User
    ) -> Message:
        """根据传递的消息id获取消息记录"""
        message = await self.get(db, Message, message_id)
        if not message:
            raise NotFoundException("该消息不存在")

        # TODO: 校验权限

        return message

    async def get_conversation_messages_with_page(
        self,
        db: AsyncSession,
        conversation_id: UUID,
        req,  # TODO: GetConversationMessagesWithPageReq
        user: User
    ) -> tuple[list[Message], dict]:
        """根据传递的会话id+请求数据，获取会话消息列表分页数据"""
        # 1.获取会话并校验权限
        conversation = await self.get_conversation(db, conversation_id, user)

        # 2.构建筛选条件
        filters = [Message.conversation_id == conversation_id]
        # TODO: 添加其他筛选条件（如 created_at 游标等）

        # 3.构建查询
        query = (
            select(Message)
            .where(*filters)
            .options(joinedload(Message.agent_thoughts))
            .order_by(desc(Message.created_at))
        )

        # 4.执行分页查询
        offset = req.offset if hasattr(req, 'offset') else 0
        page_size = req.page_size if hasattr(req, 'page_size') else 20
        
        result = await db.execute(query.offset(offset).limit(page_size))
        messages = result.scalars().all()

        # 5.获取总数
        from sqlalchemy import func
        count_result = await db.execute(
            select(func.count(Message.id)).where(*filters)
        )
        total = count_result.scalar_one()

        # 6.返回分页信息
        paginator = {
            "total": total,
            "current_page": req.current_page if hasattr(req, 'current_page') else 1,
            "page_size": page_size,
            "total_page": (total + page_size - 1) // page_size if page_size > 0 else 0
        }

        return messages, paginator

    async def delete_conversation(
        self,
        db: AsyncSession,
        conversation_id: UUID,
        user: User
    ) -> Conversation:
        """根据传递的会话id删除会话记录（软删除）"""
        conversation = await self.get_conversation(db, conversation_id, user)
        await self.update(db, conversation, is_deleted=True)
        return conversation

