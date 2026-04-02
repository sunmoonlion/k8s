#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Dataset 相关模型 - 从 imooc-llmops 迁移
已转换为 SQLAlchemy 2.0 异步版本
account_id 已改为 user_id（统一使用 User 模型）
"""
from __future__ import annotations
from typing import TYPE_CHECKING, Optional
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Text, Integer, Boolean, DateTime, Index, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import UUID, JSONB
from uuid import uuid4

from app.db.postgresql.base_class import Base

if TYPE_CHECKING:
    # Removed: user model is in auth service User
    from .llmops_app import AppDatasetJoin

class Dataset(Base):
    """知识库表"""
    __tablename__ = "dataset"
    __table_args__ = (
        Index("dataset_user_id_name_idx", "user_id", "name"),
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
        comment="创建用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理")
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="知识库名称"
    )
    icon: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="知识库图标"
    )
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="知识库描述"
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

    # 注意：原模型中的 @property 方法（document_count, hit_count, related_app_count, 
    # character_count）包含数据库查询逻辑，这些应该移到 Service 层作为异步方法实现

class Document(Base):
    """文档表模型"""
    __tablename__ = "document"
    __table_args__ = (
        Index("document_user_id_idx", "user_id"),
        Index("document_dataset_id_idx", "dataset_id"),
        Index("document_batch_idx", "batch"),
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
        comment="创建用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理")
    )
    dataset_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("dataset.id"),
        nullable=False,
        index=True,
        comment="关联知识库id"
    )
    upload_file_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        comment="关联上传文件id"
    )
    process_rule_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        comment="关联处理规则id"
    )
    batch: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="批次号"
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="文档名称"
    )
    position: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=1,
        comment="文档位置"
    )
    character_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="字符数"
    )
    token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="Token数"
    )
    processing_started_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="处理开始时间"
    )
    parsing_completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="解析完成时间"
    )
    splitting_completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="分割完成时间"
    )
    indexing_completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="索引完成时间"
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="完成时间"
    )
    stopped_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="停止时间"
    )
    error: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="错误信息"
    )
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否启用"
    )
    disabled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="禁用时间"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="waiting",
        comment="文档状态"
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

    # 注意：原模型中的 @property 方法（upload_file, process_rule, segment_count, hit_count）
    # 包含数据库查询逻辑，这些应该移到 Service 层作为异步方法实现

class Segment(Base):
    """片段表模型"""
    __tablename__ = "segment"
    __table_args__ = (
        Index("segment_user_id_idx", "user_id"),
        Index("segment_dataset_id_idx", "dataset_id"),
        Index("segment_document_id_idx", "document_id"),
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
        comment="创建用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理")
    )
    dataset_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("dataset.id"),
        nullable=False,
        index=True,
        comment="关联知识库id"
    )
    document_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("document.id"),
        nullable=False,
        index=True,
        comment="关联文档id"
    )
    node_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        comment="节点id"
    )
    position: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=1,
        comment="片段位置"
    )
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="片段内容"
    )
    character_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="字符数"
    )
    token_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="Token数"
    )
    keywords: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        server_default="[]",
        comment="关键词列表"
    )
    hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="",
        comment="内容哈希值"
    )
    hit_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=0,
        comment="命中次数"
    )
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=False,
        comment="是否启用"
    )
    disabled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="禁用时间"
    )
    processing_started_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="处理开始时间"
    )
    indexing_completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="索引完成时间"
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="完成时间"
    )
    stopped_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="停止时间"
    )
    error: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="错误信息"
    )
    status: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="waiting",
        comment="片段状态"
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

    # 注意：原模型中的 @property 方法（document）包含数据库查询逻辑，
    # 这些应该移到 Service 层作为异步方法实现

class KeywordTable(Base):
    """关键词表模型"""
    __tablename__ = "keyword_table"
    __table_args__ = (
        Index("keyword_table_dataset_id_idx", "dataset_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4()
    )
    dataset_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("dataset.id"),
        nullable=False,
        index=True,
        comment="关联知识库id"
    )
    keyword_table: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="关键词表"
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

class DatasetQuery(Base):
    """知识库查询表模型"""
    __tablename__ = "dataset_query"
    __table_args__ = (
        Index("dataset_query_dataset_id_idx", "dataset_id"),
        Index("dataset_created_by_idx", "created_by"),
        Index("dataset_source_app_id_idx", "source_app_id"),
    )

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        server_default=func.uuid_generate_v4()
    )
    dataset_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("dataset.id"),
        nullable=False,
        index=True,
        comment="关联知识库id"
    )
    query: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="",
        comment="查询内容"
    )
    source: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="HitTesting",
        comment="查询来源"
    )
    source_app_id: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        index=True,
        comment="来源应用id"
    )
    created_by: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
        index=True,
        comment="创建者id"
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

class ProcessRule(Base):
    """文档处理规则表模型"""
    __tablename__ = "process_rule"
    __table_args__ = (
        Index("process_rule_user_id_idx", "user_id"),
        Index("process_rule_dataset_id_idx", "dataset_id"),
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
        comment="创建用户id（原 account_id），注意：不建立外键约束，用户信息由认证服务管理")
    )
    dataset_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("dataset.id"),
        nullable=False,
        index=True,
        comment="关联知识库id"
    )
    mode: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        server_default="automic",
        comment="处理模式"
    )
    rule: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        server_default="{}",
        comment="处理规则"
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

