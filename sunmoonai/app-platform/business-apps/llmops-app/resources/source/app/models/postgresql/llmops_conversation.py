#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Conversation 相关模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
"""
from __future__ import annotations
from typing import TYPE_CHECKING, Optional
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Text, Integer, Boolean, DateTime, Float, Numeric, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    from .llmops_app import LLMOpsApp


class Conversation(Base):
    """交流会话模型"""
    __tablename__ = "conversation"
    __table_args__ = (
        Index("conversation_app_id_idx", "app_id"),
        Index("conversation_app_created_by_idx", "created_by"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4()
    )
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        index=True,
        comment="关联应用id"
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="会话名称"
    )
    summary: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="会话摘要/长期记忆"
    )
    is_pinned: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否置顶"
    )
    is_deleted: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否删除"
    )
    invoke_from: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="调用来源"
    )
    created_by: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        index=True,
        comment="会话创建者，会随着invoke_from的差异记录不同的信息，其中web_app和debugger会记录账号id、service_api会记录终端用户id"
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now()
    )

    # 注意：原模型中的 @property 方法（is_new）包含数据库查询逻辑，
    # 这些应该移到 Service 层作为异步方法实现


class Message(Base):
    """交流消息模型"""
    __tablename__ = "message"
    __table_args__ = (
        Index("message_conversation_id_idx", "conversation_id"),
        Index("message_created_by_idx", "created_by"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4()
    )

    # 消息关联的记录
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        comment="关联应用id"
    )
    conversation_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("conversation.id"),
        nullable=False,
        index=True,
        comment="关联会话id"
    )
    invoke_from: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="调用来源，涵盖service_api、web_app、debugger等"
    )
    created_by: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="消息的创建来源，有可能是LLMOps的用户，也有可能是开放API的终端用户"
    )

    # 消息关联的原始问题
    query: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="用户提问的原始query"
    )
    image_urls: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="用户提问的图片URL列表信息"
    )
    message: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="产生answer的消息列表"
    )
    message_token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="消息列表的token总数"
    )
    message_unit_price: Mapped[float] = mapped_column(
        Numeric(10, 7),
        nullable=False,
        server_default=0.0,
        comment="消息的单价"
    )
    message_price_unit: Mapped[float] = mapped_column(
        Numeric(10, 4),
        nullable=False,
        server_default=0.0,
        comment="消息的价格单位"
    )

    # 消息关联的答案信息
    answer: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="Agent生成的消息答案"
    )
    answer_token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="消息答案的token数"
    )
    answer_unit_price: Mapped[float] = mapped_column(
        Numeric(10, 7),
        nullable=False,
        server_default=0.0,
        comment="token的单位价格"
    )
    answer_price_unit: Mapped[float] = mapped_column(
        Numeric(10, 4),
        nullable=False,
        server_default=0.0,
        comment="token的价格单位"
    )

    # 消息的相关统计信息
    latency: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        server_default=0.0,
        comment="消息的总耗时"
    )
    is_deleted: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="软删除标记"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="消息的状态，涵盖正常、错误、停止"
    )
    error: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="发生错误时记录的信息"
    )
    total_token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="消耗的总token数，计算步骤的消耗"
    )
    total_price: Mapped[float] = mapped_column(
        Numeric(10, 7),
        nullable=False,
        server_default=0.0,
        comment="消耗的总价格，计算步骤的总消耗"
    )

    # 消息时间相关信息
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now()
    )

    # 智能体推理列表，创建表关联
    agent_thoughts: Mapped[list["MessageAgentThought"]] = relationship(
        "MessageAgentThought",
        back_populates="message_rel",
        lazy="selectin",
        cascade="all, delete-orphan"
    )

    # 注意：原模型中的 @property 方法（conversation）包含数据库查询逻辑，
    # 这些应该移到 Service 层作为异步方法实现


class MessageAgentThought(Base):
    """智能体消息推理模型，用于记录Agent生成最终消息答案时"""
    __tablename__ = "message_agent_thought"
    __table_args__ = (
        Index("message_agent_thought_app_id_idx", "app_id"),
        Index("message_agent_thought_conversation_id_idx", "conversation_id"),
        Index("message_agent_thought_message_id_idx", "message_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4()
    )

    # 推理步骤关联信息
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        index=True,
        comment="关联的应用id"
    )
    conversation_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("conversation.id"),
        nullable=False,
        index=True,
        comment="关联的会话id"
    )
    message_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("message.id"),
        nullable=False,
        index=True,
        comment="关联的消息id"
    )
    invoke_from: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="调用来源，涵盖service_api、web_app、debugger等"
    )
    created_by: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        comment="消息的创建来源，有可能是LLMOps的用户，也有可能是开放API的终端用户"
    )

    # 该步骤在消息中执行的位置
    position: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="推理观察的位置"
    )

    # 推理与观察，分别记录LLM和非LLM产生的消息
    event: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="事件名称"
    )
    thought: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="推理内容(存储LLM生成的内容)"
    )
    observation: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="观察内容(存储知识库、工具等非LLM生成的内容，用于让LLM观察)"
    )

    # 工具相关，涵盖工具名称、输入，在调用工具时会生成
    tool: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="调用工具名称"
    )
    tool_input: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="LLM调用工具的输入，如果没有则为空字典"
    )

    # Agent推理观察步骤使用的消息列表(传递prompt消息内容)
    message: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="该步骤调用LLM使用的提示消息"
    )
    message_token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="消息花费的token数"
    )
    message_unit_price: Mapped[float] = mapped_column(
        Numeric(10, 7),
        nullable=False,
        server_default=0.0,
        comment="单价，所有LLM的计算方式统一为CNY"
    )
    message_price_unit: Mapped[float] = mapped_column(
        Numeric(10, 4),
        nullable=False,
        server_default=0.0,
        comment="价格单位，值为1000代表1000token对应的单价"
    )

    # LLM生成内容相关(生成内容)
    answer: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="LLM生成的答案内容，值和thought保持一致"
    )
    answer_token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="LLM生成答案消耗token数"
    )
    answer_unit_price: Mapped[float] = mapped_column(
        Numeric(10, 7),
        nullable=False,
        server_default=0.0,
        comment="单价，所有LLM的计算方式统一为CNY"
    )
    answer_price_unit: Mapped[float] = mapped_column(
        Numeric(10, 4),
        nullable=False,
        server_default=0.0,
        comment="价格单位，值为1000代表1000token对应的单价"
    )

    # Agent推理观察统计相关
    total_token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="总消耗token"
    )
    total_price: Mapped[float] = mapped_column(
        Numeric(10, 7),
        nullable=False,
        server_default=0.0,
        comment="总消耗"
    )
    latency: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        server_default=0.0,
        comment="推理观察步骤耗时"
    )

    # 时间相关信息
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        comment="创建时间"
    )

    # 关系定义
    message_rel: Mapped["Message"] = relationship(
        "Message",
        back_populates="agent_thoughts"
    )

