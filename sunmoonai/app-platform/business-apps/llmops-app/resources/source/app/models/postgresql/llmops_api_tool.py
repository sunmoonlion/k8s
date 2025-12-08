#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Tool 相关模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
account_id 已改为 user_id（统一使用 User 模型）
"""
from __future__ import annotations
from typing import TYPE_CHECKING
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Text, DateTime, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User


class ApiToolProvider(Base):
    """API工具提供者模型"""
    __tablename__ = "api_tool_provider"
    __table_args__ = (
        Index("api_tool_provider_user_id_idx", "user_id"),
        Index("api_tool_name_idx", "name"),
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
        index=True,
        comment="提供者名称"
    )
    icon: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="提供者图标"
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="提供者描述"
    )
    openapi_schema: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="OpenAPI Schema"
    )
    headers: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="请求头配置"
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

    # 关系定义
    tools: Mapped[list["ApiTool"]] = relationship(
        "ApiTool",
        back_populates="provider",
        foreign_keys="[ApiTool.provider_id]"
    )


class ApiTool(Base):
    """API工具表"""
    __tablename__ = "api_tool"
    __table_args__ = (
        Index("api_tool_user_id_idx", "user_id"),
        Index("api_tool_provider_id_name_idx", "provider_id", "name"),
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
    provider_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("api_tool_provider.id"),
        nullable=False,
        comment="关联提供者id"
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="工具名称"
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="工具描述"
    )
    url: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="工具URL"
    )
    method: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="HTTP方法"
    )
    parameters: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="工具参数"
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

    # 关系定义
    provider: Mapped["ApiToolProvider"] = relationship(
        "ApiToolProvider",
        back_populates="tools",
        foreign_keys=[provider_id]
    )


