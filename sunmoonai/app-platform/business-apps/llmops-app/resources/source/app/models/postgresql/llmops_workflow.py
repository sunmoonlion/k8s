#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Workflow 相关模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
account_id 已改为 user_id（统一使用 User 模型）
"""
from __future__ import annotations
from typing import TYPE_CHECKING, Optional
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Text, Boolean, DateTime, Float, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User
    from .llmops_app import LLMOpsApp

class Workflow(Base):
    """工作流模型"""
    __tablename__ = "workflow"
    __table_args__ = (
        Index("workflow_user_id_idx", "user_id"),
        Index("workflow_tool_call_name_idx", "tool_call_name"),
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
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="工作流名字"
    )
    tool_call_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        index=True,
        comment="工作流工具调用名字"
    )
    icon: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="工作流图标"
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="应用描述"
    )
    graph: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="运行时配置"
    )
    draft_graph: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="草稿图配置"
    )
    is_debug_passed: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否调试通过"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="工作流状态"
    )
    published_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="发布时间"
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

class WorkflowResult(Base):
    """工作流存储结果模型"""
    __tablename__ = "workflow_result"
    __table_args__ = (
        Index("workflow_result_app_id_idx", "app_id"),
        Index("workflow_result_user_id_idx", "user_id"),
        Index("workflow_result_workflow_id_idx", "workflow_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="结果id"
    )
    app_id: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=True,
        index=True,
        comment="工作流调用的应用id，如果为空则代表非应用调用"
    )
    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="创建用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理"
    )
    workflow_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("workflow.id"),
        nullable=False,
        index=True,
        comment="结果关联的工作流id"
    )
    graph: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="运行时配置"
    )
    state: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="工作流最终状态"
    )
    latency: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        server_default=0.0,
        comment="消息的总耗时"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="运行状态"
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

