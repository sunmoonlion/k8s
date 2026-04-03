#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Document Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
import logging
import random
import time
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID
from typing import Optional

from injector import inject
from redis import Redis
from sqlalchemy import select, desc, asc, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.postgresql.llmops_llmops_dataset import Dataset, Document, Segment, ProcessRule
from app.models.postgresql.llmops_llmops_upload_file import UploadFile
# Removed: user model is in auth service User
from app.services.llmops.base_service import BaseService
from app.core.exceptions import ForbiddenException, FailException, NotFoundException

# 导入 Entity 和常量
from app.core.llmops.entity.cache_entity import LOCK_DOCUMENT_UPDATE_ENABLED, LOCK_EXPIRE_TIME
from app.core.llmops.entity.dataset_entity import ProcessType, DocumentStatus, SegmentStatus
from app.core.llmops.entity.upload_file_entity import ALLOWED_DOCUMENT_EXTENSION
from app.worker.llmops_tasks import (
    build_documents,
    update_document_enabled,
    delete_document as delete_document_task,
)


@inject
@dataclass
class DocumentService(BaseService):
    """文档服务（异步版本）"""

    def __init__(self):
        """初始化文档服务"""
        from app.core.extensions import get_redis_client
        self.redis_client = get_redis_client()

    async def create_documents(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        upload_file_ids: list[UUID],
        process_type: str = ProcessType.AUTOMATIC,
        rule: Optional[dict] = None,
        user: Optional[User] = None,
    ) -> tuple[list[Document], str]:
        """根据传递的信息创建文档列表并调用异步任务"""
        # 1.检测知识库权限
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise ForbiddenException("当前用户无该知识库权限或知识库不存在")

        # 2.提取文件并校验文件权限与文件扩展
        result = await db.execute(
            select(UploadFile).where(
                UploadFile.user_id == user.id,
                UploadFile.id.in_(upload_file_ids)
            )
        )
        upload_files = result.scalars().all()

        upload_files = [
            upload_file for upload_file in upload_files
            if upload_file.extension.lower() in ALLOWED_DOCUMENT_EXTENSION
        ]

        if len(upload_files) == 0:
            logging.warning(
                "上传文档列表未解析到合法文件, "
                "user_id: %(user_id)s, "
                "dataset_id: %(dataset_id)s, "
                "upload_file_ids: %(upload_file_ids)s",
                {"user_id": user.id, "dataset_id": dataset_id, "upload_file_ids": repr(upload_file_ids)},
            )
            raise FailException("暂未解析到合法文件，请重新上传")

        # 3.创建批次与处理规则并记录到数据库中
        batch = time.strftime("%Y%m%d%H%M%S") + str(random.randint(100000, 999999))
        process_rule = await self.create(
            db,
            ProcessRule,
            user_id=user.id,
            dataset_id=dataset_id,
            mode=process_type,
            rule=rule or {},
        )

        # 4.获取当前知识库的最新文档位置
        position = await self.get_latest_document_position(db, dataset_id)

        # 5.循环遍历所有合法的上传文件列表并记录
        documents = []
        for upload_file in upload_files:
            position += 1
            document = await self.create(
                db,
                Document,
                user_id=user.id,
                dataset_id=dataset_id,
                upload_file_id=upload_file.id,
                process_rule_id=process_rule.id,
                batch=batch,
                name=upload_file.name,
                position=position,
            )
            documents.append(document)

        # 6.调用异步任务，完成后续操作
        build_documents.delay([str(document.id) for document in documents])

        # 7.返回文档列表与处理批次
        return documents, batch

    async def get_documents_status(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        batch: str,
        user: User
    ) -> list[dict]:
        """根据传递的知识库id+处理批次获取文档列表的状态"""
        # 1.检测知识库权限
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise ForbiddenException("当前用户无该知识库权限或知识库不存在")

        # 2.查询当前知识库下该批次的文档列表
        result = await db.execute(
            select(Document).where(
                Document.dataset_id == dataset_id,
                Document.batch == batch,
            ).order_by(asc(Document.position))
        )
        documents = result.scalars().all()
        
        if documents is None or len(documents) == 0:
            raise NotFoundException("该处理批次未发现文档，请核实后重试")

        # 3.循环遍历文档列表提取文档的状态信息
        documents_status = []
        for document in documents:
            # 4.查询每个文档的总片段数和已构建完成的片段数
            segment_count_result = await db.execute(
                select(func.count(Segment.id)).where(Segment.document_id == document.id)
            )
            segment_count = segment_count_result.scalar_one() or 0
            
            completed_segment_count_result = await db.execute(
                select(func.count(Segment.id)).where(
                    Segment.document_id == document.id,
                    Segment.status == SegmentStatus.COMPLETED,
                )
            )
            completed_segment_count = completed_segment_count_result.scalar_one() or 0

            # 5.获取上传文件信息
            upload_file = await self.get(db, UploadFile, document.upload_file_id)
            
            documents_status.append({
                "id": document.id,
                "name": document.name,
                "size": upload_file.size if upload_file else 0,
                "extension": upload_file.extension if upload_file else "",
                "mime_type": upload_file.mime_type if upload_file else "",
                "position": document.position,
                "segment_count": segment_count,
                "completed_segment_count": completed_segment_count,
                "error": document.error,
                "status": document.status,
                "processing_started_at": int(document.processing_started_at.timestamp()) if document.processing_started_at else 0,
                "parsing_completed_at": int(document.parsing_completed_at.timestamp()) if document.parsing_completed_at else 0,
                "splitting_completed_at": int(document.splitting_completed_at.timestamp()) if document.splitting_completed_at else 0,
                "indexing_completed_at": int(document.indexing_completed_at.timestamp()) if document.indexing_completed_at else 0,
                "completed_at": int(document.completed_at.timestamp()) if document.completed_at else 0,
                "stopped_at": int(document.stopped_at.timestamp()) if document.stopped_at else 0,
                "created_at": int(document.created_at.timestamp()),
            })

        return documents_status

    async def get_document(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        user: User
    ) -> Document:
        """根据传递的知识库id+文档id获取文档记录信息"""
        document = await self.get(db, Document, document_id)
        if document is None:
            raise NotFoundException("该文档不存在，请核实后重试")
        if document.dataset_id != dataset_id or document.user_id != user.id:
            raise ForbiddenException("当前用户获取该文档，请核实后重试")

        return document

    async def update_document(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        user: User,
        **kwargs
    ) -> Document:
        """根据传递的知识库id+文档id，更新文档信息"""
        document = await self.get(db, Document, document_id)
        if document is None:
            raise NotFoundException("该文档不存在，请核实后重试")
        if document.dataset_id != dataset_id or document.user_id != user.id:
            raise ForbiddenException("当前用户无权限修改该文档，请核实后重试")

        return await self.update(db, document, **kwargs)

    async def update_document_enabled(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        enabled: bool,
        user: User,
    ) -> Document:
        """根据传递的知识库id+文档id，更新文档的启用状态，同时会异步更新weaviate向量数据库中的数据"""
        # 1.获取文档并校验权限
        document = await self.get(db, Document, document_id)
        if document is None:
            raise NotFoundException("该文档不存在，请核实后重试")
        if document.dataset_id != dataset_id or document.user_id != user.id:
            raise ForbiddenException("当前用户无权限修改该知识库下的文档，请核实后重试")

        # 2.判断文档是否处于可以修改的状态，只有构建完成才可以修改enabled
        if document.status != DocumentStatus.COMPLETED:
            raise ForbiddenException("当前文档处于不可修改状态，请稍后重试")

        # 3.判断修改的启用状态是否正确，需与当前的状态相反
        if document.enabled == enabled:
            raise FailException(f"文档状态修改错误，当前已是{'启用' if enabled else '禁用'}状态")

        # 4.获取更新文档启用状态的缓存键并检测是否上锁
        cache_key = LOCK_DOCUMENT_UPDATE_ENABLED.format(document_id=document.id)
        from app.utils.redis_helper import redis_get
        cache_result = await redis_get(self.redis_client, cache_key)
        if cache_result is not None:
            raise FailException("当前文档正在修改启用状态，请稍后再次尝试")

        # 5.修改文档的启用状态并设置缓存键，缓存时间为600s
        await self.update(
            db,
            document,
            enabled=enabled,
            disabled_at=None if enabled else datetime.utcnow(),
        )
        from app.utils.redis_helper import redis_set
        await redis_set(self.redis_client, cache_key, 1, ex=LOCK_EXPIRE_TIME)

        # 6.启用异步任务完成后续操作
        update_document_enabled.delay(str(document.id))

        return document

    async def delete_document(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        user: User
    ) -> Document:
        """根据传递的知识库id+文档id删除文档信息，涵盖：文档片段删除、关键词表更新、weaviate向量数据库记录删除"""
        # 1.获取文档并校验权限
        document = await self.get(db, Document, document_id)
        if document is None:
            raise NotFoundException("该文档不存在，请核实后重试")
        if document.dataset_id != dataset_id or document.user_id != user.id:
            raise ForbiddenException("当前用户无权限删除该知识库下的文档，请核实后重试")

        # 2.判断文档是否处于可删除状态，只有构建完成/出错的时候才可以删除，其他情况需要等待构建完成
        if document.status not in [DocumentStatus.COMPLETED, DocumentStatus.ERROR]:
            raise FailException("当前文档处于不可删除状态，请稍后重试")

        # 3.删除postgres中的文档基础信息
        await self.delete(db, document)

        # 4.调用异步任务执行后续操作，涵盖：关键词表更新、片段数据删除、weaviate记录删除等
        delete_document_task.delay(str(dataset_id), str(document_id))

        return document

    async def get_documents_with_page(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        req,  # TODO: GetDocumentsWithPageReq
        user: User
    ) -> tuple[list[Document], dict]:
        """根据传递的知识库id+请求数据获取文档分页列表数据"""
        # 1.获取知识库并校验权限
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise NotFoundException("该知识库不存在，或无权限")

        # 2.构建筛选器
        filters = [
            Document.user_id == user.id,
            Document.dataset_id == dataset_id,
        ]
        if hasattr(req, 'search_word') and req.search_word:
            filters.append(Document.name.ilike(f"%{req.search_word}%"))

        # 3.构建查询
        query = select(Document).where(*filters).order_by(desc(Document.created_at))

        # 4.执行分页查询
        offset = req.offset if hasattr(req, 'offset') else 0
        page_size = req.page_size if hasattr(req, 'page_size') else 20
        
        result = await db.execute(query.offset(offset).limit(page_size))
        documents = result.scalars().all()

        # 5.获取总数
        count_result = await db.execute(
            select(func.count(Document.id)).where(*filters)
        )
        total = count_result.scalar_one()

        # 6.返回分页信息
        paginator = {
            "total": total,
            "current_page": req.current_page if hasattr(req, 'current_page') else 1,
            "page_size": page_size,
            "total_page": (total + page_size - 1) // page_size if page_size > 0 else 0
        }

        return documents, paginator

    async def get_latest_document_position(
        self,
        db: AsyncSession,
        dataset_id: UUID
    ) -> int:
        """根据传递的知识库id获取最新文档位置"""
        result = await db.execute(
            select(Document).where(
                Document.dataset_id == dataset_id,
            ).order_by(desc(Document.position)).limit(1)
        )
        document = result.scalar_one_or_none()
        return document.position if document else 0

