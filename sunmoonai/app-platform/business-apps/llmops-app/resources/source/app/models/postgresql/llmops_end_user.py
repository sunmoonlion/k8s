#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps End User 模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
tenant_id 保持不变（可能指向 User 或其他实体）
"""
from __future__ import annotations
from typing import TYPE_CHECKING
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import DateTime, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User
    from .llmops_app import LLMOpsApp

class EndUser(Base):
    """终端用户表模型"""
    __tablename__ = "end_user"
    __table_args__ = (
        Index("end_user_tenant_id_idx", "tenant_id"),
        Index("end_user_app_id_idx", "app_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="终端id"
    )
    tenant_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="归属的用户/空间id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理"
    )
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        index=True,
        comment="归属应用的id，终端用户只能在应用下使用"
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

