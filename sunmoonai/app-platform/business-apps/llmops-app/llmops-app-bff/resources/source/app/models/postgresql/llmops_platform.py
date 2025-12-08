#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Platform 相关模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
"""
from __future__ import annotations
from typing import TYPE_CHECKING
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, DateTime, Boolean, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    from .llmops_app import LLMOpsApp
    from .llmops_conversation import Conversation
    from .llmops_end_user import EndUser


class WechatConfig(Base):
    """Agent微信配置信息"""
    __tablename__ = "wechat_config"
    __table_args__ = (
        Index("wechat_config_app_id_idx", "app_id"),
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
        comment="配置关联应用id"
    )
    wechat_app_id: Mapped[str] = mapped_column(
        String(255),
        nullable=True,
        server_default="",
        comment="微信公众号开发者id"
    )
    wechat_app_secret: Mapped[str] = mapped_column(
        String(255),
        nullable=True,
        server_default="",
        comment="微信公众号开发者秘钥"
    )
    wechat_token: Mapped[str] = mapped_column(
        String(255),
        nullable=True,
        server_default="",
        comment="微信公众号校验凭证"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="配置状态"
    )
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


class WechatEndUser(Base):
    """微信公众号与终端用户标识关联表"""
    __tablename__ = "wechat_end_user"
    __table_args__ = (
        Index("wechat_end_user_openid_app_id_idx", "openid", "app_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="记录id"
    )
    openid: Mapped[str] = mapped_column(
        String,
        nullable=False,
        comment="发送方账号，数据其实是openid(FromUserName/source)"
    )
    app_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("app.id"),
        nullable=False,
        comment="关联配置的应用id"
    )
    end_user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("end_user.id"),
        nullable=False,
        comment="关联的终端用户id"
    )
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

    # 注意：原模型中的 @property 方法（conversation）包含数据库查询逻辑，
    # 这些应该移到 Service 层作为异步方法实现


class WechatMessage(Base):
    """微信公众号消息模型，用于记录未推送的消息记录"""
    __tablename__ = "wechat_message"
    __table_args__ = (
        Index("wechat_message_wechat_end_user_id_idx", "wechat_end_user_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4(),
        comment="记录id"
    )
    wechat_end_user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("wechat_end_user.id"),
        nullable=False,
        index=True,
        comment="关联的微信终端用户id"
    )
    message_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("message.id"),
        nullable=False,
        comment="关联的消息id"
    )
    is_pushed: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否推送，默认为false表示未推送"
    )
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


