#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Key 模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
account_id 已改为 user_id（统一使用 User 模型）
"""
from __future__ import annotations
from typing import TYPE_CHECKING
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Boolean, DateTime, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User


class ApiKey(Base):
    """API秘钥模型"""
    __tablename__ = "api_key"
    __table_args__ = (
        Index("api_key_user_id_idx", "user_id"),
        Index("api_key_api_key_idx", "api_key"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="记录id"
    )
    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="关联用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理"
    )
    api_key: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        index=True,
        comment="加密后的api秘钥"
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否激活，为true时可以使用"
    )
    remark: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="备注信息"
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

    # 注意：原模型中的 @property 方法（account）包含数据库查询逻辑，
    # 这些应该移到 Service 层作为异步方法实现


