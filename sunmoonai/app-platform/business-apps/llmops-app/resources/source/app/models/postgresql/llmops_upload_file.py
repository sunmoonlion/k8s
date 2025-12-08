#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Upload File 模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
account_id 已改为 user_id（统一使用 User 模型）
"""
from __future__ import annotations
from typing import TYPE_CHECKING
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Integer, DateTime, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User

class UploadFile(Base):
    """上传文件模型"""
    __tablename__ = "upload_file"
    __table_args__ = (
        Index("upload_file_user_id_idx", "user_id"),
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
        comment="文件名"
    )
    key: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="文件存储key"
    )
    size: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="文件大小"
    )
    extension: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="文件扩展名"
    )
    mime_type: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="MIME类型"
    )
    hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="文件哈希值"
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

