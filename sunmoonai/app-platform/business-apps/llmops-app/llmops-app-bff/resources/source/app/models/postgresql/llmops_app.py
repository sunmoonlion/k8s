#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps App 模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
account_id 已改为 user_id（统一使用 User 模型）
"""
from __future__ import annotations
from typing import TYPE_CHECKING, Optional
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Text, Integer, DateTime, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User
    from .llmops_conversation import Conversation
    from .llmops_platform import WechatConfig


class LLMOpsApp(Base):
    """AI应用基础模型类"""
    __tablename__ = "app"
    __table_args__ = (
        Index("app_user_id_idx", "user_id"),
        Index("app_token_idx", "token"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4()
    )
    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="创建用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理"
    )
    app_config_id: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        comment="发布配置id，当值为空时代表没有发布"
    )
    draft_app_config_id: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        comment="关联的草稿配置id"
    )
    debug_conversation_id: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        comment="应用调试会话id，为None则代表没有会话信息"
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="应用名字"
    )
    icon: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="应用图标"
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="应用描述"
    )
    token: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        server_default="",
        comment="应用凭证信息"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="应用状态"
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

    # 关系定义（如果需要）
    # user: Mapped["User"] = relationship("User", back_populates="apps")
    # debug_conversation: Mapped[Optional["Conversation"]] = relationship(
    #     "Conversation",
    #     foreign_keys=[debug_conversation_id],
    #     back_populates="app"
    # )

    # 注意：原模型中的 @property 方法（app_config, draft_app_config, debug_conversation, 
    # token_with_default, wechat_config）包含数据库查询逻辑，这些应该移到 Service 层
    # 作为异步方法实现


class AppConfig(Base):
    """应用配置模型"""
    __tablename__ = "app_config"
    __table_args__ = (
        Index("app_config_app_id_idx", "app_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="配置id"
    )
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        index=True,
        comment="关联应用id"
    )
    model_config: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="模型配置"
    )
    dialog_round: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="携带上下文轮数"
    )
    preset_prompt: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="预设prompt"
    )
    tools: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="应用关联工具列表"
    )
    workflows: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="应用关联的工作流列表"
    )
    retrieval_config: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="检索配置"
    )
    long_term_memory: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="长期记忆配置"
    )
    opening_statement: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="开场白文案"
    )
    opening_questions: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="开场白建议问题列表"
    )
    speech_to_text: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="语音转文本配置"
    )
    text_to_speech: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="文本转语音配置"
    )
    suggested_after_answer: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default='{"enable": true}',
        comment="回答后生成建议问题"
    )
    review_config: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="审核配置"
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


class AppConfigVersion(Base):
    """应用配置版本历史表，用于存储草稿配置+历史发布配置"""
    __tablename__ = "app_config_version"
    __table_args__ = (
        Index("app_config_version_app_id_idx", "app_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="配置id"
    )
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        index=True,
        comment="关联应用id"
    )
    model_config: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="模型配置"
    )
    dialog_round: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="携带上下文轮数"
    )
    preset_prompt: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="人设与回复逻辑"
    )
    tools: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="应用关联的工具列表"
    )
    workflows: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="应用关联的工作流列表"
    )
    datasets: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="应用关联的知识库列表"
    )
    retrieval_config: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="检索配置"
    )
    long_term_memory: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="长期记忆配置"
    )
    opening_statement: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="开场白文案"
    )
    opening_questions: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="开场白建议问题列表"
    )
    speech_to_text: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="语音转文本配置"
    )
    text_to_speech: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="文本转语音配置"
    )
    suggested_after_answer: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default='{"enable": true}',
        comment="回答后生成建议问题"
    )
    review_config: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="审核配置"
    )
    version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="发布版本号"
    )
    config_type: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="配置类型"
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


class AppDatasetJoin(Base):
    """应用知识库关联表模型"""
    __tablename__ = "app_dataset_join"
    __table_args__ = (
        Index("app_dataset_join_app_id_dataset_id_idx", "app_id", "dataset_id"),
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
        nullable=False
    )
    dataset_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False
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

