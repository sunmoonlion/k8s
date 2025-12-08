#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Segment Service - 从 imooc-llmops 迁移
已转换为异步版本（部分方法保持同步，因为涉及向量数据库和 Redis）
Account 已改为 User，account_id 已改为 user_id
"""
import logging
import uuid
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from injector import inject
from langchain_core.documents import Document as LCDocument
from redis import Redis
from sqlalchemy import select, func, asc
from sqlalchemy.ext.asyncio import AsyncSession
import asyncio

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_dataset import Document, Segment
from app.services.llmops.base_service import BaseService
from app.services.llmops.embeddings_service import EmbeddingsService
from app.services.llmops.jieba_service import JiebaService
from app.services.llmops.keyword_table_service import KeywordTableService
from app.services.llmops.vector_database_service import VectorDatabaseService
from app.core.exceptions import NotFoundException, FailException, ValidateErrorException
from app.schemas.llmops.common import PaginatorReq

# 导入 Entity 和常量
from app.core.llmops.entity.cache_entity import LOCK_EXPIRE_TIME, LOCK_SEGMENT_UPDATE_ENABLED
from app.core.llmops.entity.dataset_entity import DocumentStatus, SegmentStatus
from app.utils.llmops_helper import generate_text_hash
from app.utils.paginator import Paginator


@inject
@dataclass
class SegmentService(BaseService):
    """片段服务（部分异步版本）"""
    jieba_service: JiebaService
    embeddings_service: EmbeddingsService
    keyword_table_service: KeywordTableService
    vector_database_service: VectorDatabaseService

    def __init__(
        self,
        jieba_service: JiebaService,
        embeddings_service: EmbeddingsService,
        keyword_table_service: KeywordTableService,
        vector_database_service: VectorDatabaseService
    ):
        """初始化片段服务"""
        from app.core.extensions import get_redis_client
        self.redis_client = get_redis_client()
        self.jieba_service = jieba_service
        self.embeddings_service = embeddings_service
        self.keyword_table_service = keyword_table_service
        self.vector_database_service = vector_database_service

    async def create_segment(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        content: str,
        keywords: list[str] | None,
        user: User,
    ) -> Segment:
        """根据传递的信息新增文档片段信息"""
        # 1.校验上传内容的token长度总数，不能超过1000
        token_count = self.embeddings_service.calculate_token_count(content)
        if token_count > 1000:
            raise ValidateErrorException("片段内容的长度不能超过1000 token")

        # 2.获取文档信息并校验
        document = await self.get(db, Document, document_id)
        if (
            document is None
            or document.user_id != user.id
            or document.dataset_id != dataset_id
        ):
            raise NotFoundException("该知识库文档不存在，或无权限新增，请核实后重试")

        # 3.判断文档的状态是否可以新增片段数据，只有completed才可以新增
        if document.status != DocumentStatus.COMPLETED:
            raise FailException("当前文档不可新增片段，请稍后尝试")

        # 4.提取文档片段的最大位置
        result = await db.execute(
            select(func.coalesce(func.max(Segment.position), 0)).where(
                Segment.document_id == document_id
            )
        )
        position = result.scalar() or 0

        # 5.检测是否传递了keywords，如果没有传递的话，调用jieba服务生成关键词
        if keywords is None or len(keywords) == 0:
            keywords = await asyncio.to_thread(
                self.jieba_service.extract_keywords,
                content,
                10
            )

        # 6.往postgres数据库中新增记录
        segment = None
        try:
            # 7.位置+1并且新增segment记录
            position += 1
            segment = await self.create(
                db,
                Segment,
                user_id=user.id,
                dataset_id=dataset_id,
                document_id=document_id,
                node_id=uuid.uuid4(),
                position=position,
                content=content,
                character_count=len(content),
                token_count=token_count,
                keywords=keywords,
                hash=generate_text_hash(content),
                enabled=True,
                processing_started_at=datetime.now(),
                indexing_completed_at=datetime.now(),
                completed_at=datetime.now(),
                status=SegmentStatus.COMPLETED,
            )

            # 8.往向量数据库中新增数据（同步操作，使用 asyncio.to_thread）
            await asyncio.to_thread(
                self.vector_database_service.vector_store.add_documents,
                [LCDocument(
                    page_content=content,
                    metadata={
                        "user_id": str(document.user_id),
                        "dataset_id": str(document.dataset_id),
                        "document_id": str(document.id),
                        "segment_id": str(segment.id),
                        "node_id": str(segment.node_id),
                        "document_enabled": document.enabled,
                        "segment_enabled": True,
                    }
                )],
                ids=[str(segment.node_id)],
            )

            # 9.重新计算片段的字符总数以及token总数
            result = await db.execute(
                select(
                    func.coalesce(func.sum(Segment.character_count), 0),
                    func.coalesce(func.sum(Segment.token_count), 0)
                ).where(Segment.document_id == document.id)
            )
            document_character_count, document_token_count = result.first()

            # 10.更新文档的对应信息
            await self.update(
                db,
                document,
                character_count=document_character_count,
                token_count=document_token_count,
            )

            # 11.更新关键词表信息
            if document.enabled is True:
                await self.keyword_table_service.add_keyword_table_from_ids(
                    db, dataset_id, [segment.id]
                )

        except Exception as e:
            logging.exception(
                "构建文档片段索引发生异常, 错误信息: %(error)s",
                {"error": e},
            )
            if segment:
                await self.update(
                    db,
                    segment,
                    error=str(e),
                    status=SegmentStatus.ERROR,
                    enabled=False,
                    disabled_at=datetime.now(),
                    stopped_at=datetime.now(),
                )
            raise FailException("新增文档片段失败，请稍后尝试")

        return segment

    async def update_segment(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        segment_id: UUID,
        content: str,
        keywords: list[str] | None,
        user: User
    ) -> Segment:
        """根据传递的信息更新指定的文档片段信息"""
        # 1.获取片段信息并校验权限
        segment = await self.get(db, Segment, segment_id)
        if (
            segment is None
            or segment.user_id != user.id
            or segment.dataset_id != dataset_id
            or segment.document_id != document_id
        ):
            raise NotFoundException("该文档片段不存在，或无权限修改，请核实后重试")

        # 2.判断文档片段是否处于可修改的环境
        if segment.status != SegmentStatus.COMPLETED:
            raise FailException("当前片段不可修改状态，请稍后尝试")

        # 3.检测是否传递了keywords，如果没有传递的话，调用jieba服务生成关键词
        if keywords is None or len(keywords) == 0:
            keywords = await asyncio.to_thread(
                self.jieba_service.extract_keywords,
                content,
                10
            )

        # 4.计算新内容hash值，用于判断是否需要更新向量数据库以及文档详情
        new_hash = generate_text_hash(content)
        required_update = segment.hash != new_hash

        try:
            # 5.更新segment表记录
            await self.update(
                db,
                segment,
                keywords=keywords,
                content=content,
                hash=new_hash,
                character_count=len(content),
                token_count=self.embeddings_service.calculate_token_count(content),
            )

            # 6.更新片段归属关键词信息
            await self.keyword_table_service.delete_keyword_table_from_ids(
                db, dataset_id, [segment_id]
            )
            await self.keyword_table_service.add_keyword_table_from_ids(
                db, dataset_id, [segment_id]
            )

            # 7.检测是否需要更新文档信息以及向量数据库
            if required_update:
                # 更新文档信息，涵盖字符总数、token总次数
                result = await db.execute(
                    select(
                        func.coalesce(func.sum(Segment.character_count), 0),
                        func.coalesce(func.sum(Segment.token_count), 0)
                    ).where(Segment.document_id == document_id)
                )
                document_character_count, document_token_count = result.first()
                
                await self.update(
                    db,
                    segment,  # TODO: 应该更新 document，需要获取 document
                    character_count=document_character_count,
                    token_count=document_token_count,
                )

                # 更新向量数据库对应记录（同步操作）
                await asyncio.to_thread(
                    self.vector_database_service.collection.data.update,
                    uuid=str(segment.node_id),
                    properties={
                        "text": content,
                    },
                    vector=self.embeddings_service.embeddings.embed_query(content)
                )
        except Exception as e:
            logging.exception(
                "更新文档片段记录失败, segment_id: %(segment_id)s, 错误信息: %(error)s",
                {"segment_id": segment_id, "error": e},
            )
            raise FailException("更新文档片段记录失败，请稍后尝试")

        return segment

    async def get_segments_with_page(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        req: PaginatorReq,
        search_word: str | None,
        user: User,
    ) -> tuple[list[Segment], dict]:
        """根据传递的信息获取片段列表分页数据"""
        # 1.获取文档并校验权限
        document = await self.get(db, Document, document_id)
        if document is None or document.dataset_id != dataset_id or document.user_id != user.id:
            raise NotFoundException("该知识库文档不存在，或无权限查看，请核实后重试")

        # 2.构建筛选器
        filters = [Segment.document_id == document_id]
        if search_word:
            filters.append(Segment.content.ilike(f"%{search_word}%"))

        # 3.构建查询
        query = select(Segment).where(*filters).order_by(asc(Segment.position))
        
        # 4.执行分页查询
        result = await db.execute(query.offset(req.offset).limit(req.page_size))
        segments = result.scalars().all()
        
        # 5.获取总数
        count_result = await db.execute(select(Segment).where(*filters))
        total = len(count_result.scalars().all())
        
        # 6.构建分页信息
        paginator = {
            "current_page": req.current_page,
            "page_size": req.page_size,
            "total": total,
            "total_pages": (total + req.page_size - 1) // req.page_size,
        }

        return segments, paginator

    async def get_segment(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        segment_id: UUID,
        user: User
    ) -> Segment:
        """根据传递的信息获取片段详情信息"""
        # 1.获取片段信息并校验权限
        segment = await self.get(db, Segment, segment_id)
        if (
            segment is None
            or segment.user_id != user.id
            or segment.dataset_id != dataset_id
            or segment.document_id != document_id
        ):
            raise NotFoundException("该文档片段不存在，或无权限查看，请核实后重试")

        return segment

    async def update_segment_enabled(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        segment_id: UUID,
        enabled: bool,
        user: User
    ) -> Segment:
        """根据传递的信息更新文档片段的启用状态信息"""
        # 1.获取片段信息并校验权限
        segment = await self.get(db, Segment, segment_id)
        if (
            segment is None
            or segment.user_id != user.id
            or segment.dataset_id != dataset_id
            or segment.document_id != document_id
        ):
            raise NotFoundException("该文档片段不存在，或无权限修改，请核实后重试")

        # 2.判断文档片段是否处于可启用/禁用的环境
        if segment.status != SegmentStatus.COMPLETED:
            raise FailException("当前片段不可修改状态，请稍后尝试")

        # 3.判断更新的片段启用状态和数据库的数据是否一致，如果是则抛出错误
        if enabled == segment.enabled:
            raise FailException(f"片段状态修改错误，当前已是{'启用' if enabled else '禁用'}")

        # 4.获取更新片段启用状态锁并上锁检测
        cache_key = LOCK_SEGMENT_UPDATE_ENABLED.format(segment_id=segment_id)
        from app.utils.redis_helper import redis_get
        cache_result = await redis_get(self.redis_client, cache_key)
        if cache_result is not None:
            raise FailException("当前文档片段正在修改状态，请稍后尝试")

        # 5.上锁并更新对应的数据，涵盖postgres记录、weaviate、关键词表
        from app.utils.redis_helper import redis_lock, redis_unlock
        from app.utils.llmops_helper import generate_random_string
        
        lock_value = generate_random_string(16)
        lock_acquired = await redis_lock(self.redis_client, cache_key, lock_value, LOCK_EXPIRE_TIME)
        if not lock_acquired:
            raise FailException("获取锁失败，请稍后重试")
        
        try:
            # 6.修改postgres数据库里的文档片段状态
            await self.update(
                db,
                segment,
                enabled=enabled,
                disabled_at=None if enabled else datetime.now()
            )

            # 7.更新关键词表的对应信息，有可能新增，也有可能删除
            document = await self.get(db, Document, document_id)
            if enabled is True and document.enabled is True:
                await self.keyword_table_service.add_keyword_table_from_ids(
                    db, dataset_id, [segment_id]
                )
            else:
                await self.keyword_table_service.delete_keyword_table_from_ids(
                    db, dataset_id, [segment_id]
                )

            # 8.同步处理weaviate向量数据库里的数据
            await asyncio.to_thread(
                self.vector_database_service.collection.data.update,
                uuid=segment.node_id,
                properties={"segment_enabled": enabled}
            )
        except Exception as e:
            logging.exception(
                "更改文档片段启用状态出现异常, segment_id: %(segment_id)s, 错误信息: %(error)s",
                {"segment_id": segment_id, "error": e},
            )
            await self.update(
                db,
                segment,
                error=str(e),
                status=SegmentStatus.ERROR,
                enabled=False,
                disabled_at=datetime.now(),
                stopped_at=datetime.now(),
            )
            raise FailException("更新文档片段启用状态失败，请稍后重试")
        finally:
            # 释放锁
            await redis_unlock(self.redis_client, cache_key, lock_value)

    async def delete_segment(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID,
        segment_id: UUID,
        user: User
    ) -> Segment:
        """根据传递的信息删除指定的文档片段信息"""
        # 1.获取片段信息并校验权限
        segment = await self.get(db, Segment, segment_id)
        if (
            segment is None
            or segment.user_id != user.id
            or segment.dataset_id != dataset_id
            or segment.document_id != document_id
        ):
            raise NotFoundException("该文档片段不存在，或无权限修改，请核实后重试")

        # 2.判断文档是否处于可以删除的状态，只有COMPLETED/ERROR才可以删除
        if segment.status not in [SegmentStatus.COMPLETED, SegmentStatus.ERROR]:
            raise FailException("当前文档片段处于不可删除状态，请稍后尝试")

        # 3.删除文档片段并获取该片段的文档信息
        document = await self.get(db, Document, document_id)
        await self.delete(db, segment)

        # 4.同步删除关键词表中属于该片段的关键词
        await self.keyword_table_service.delete_keyword_table_from_ids(
            db, dataset_id, [segment_id]
        )

        # 5.同步删除向量数据库存储的记录
        try:
            await asyncio.to_thread(
                self.vector_database_service.collection.data.delete_by_id,
                str(segment.node_id)
            )
        except Exception as e:
            logging.exception(
                "删除文档片段记录失败, segment_id: %(segment_id)s, 错误信息: %(error)s",
                {"segment_id": segment_id, "error": e},
            )

        # 6.更新文档信息，涵盖字符总数、token总次数
        result = await db.execute(
            select(
                func.coalesce(func.sum(Segment.character_count), 0),
                func.coalesce(func.sum(Segment.token_count), 0)
            ).where(Segment.document_id == document_id)
        )
        document_character_count, document_token_count = result.first()
        
        await self.update(
            db,
            document,
            character_count=document_character_count,
            token_count=document_token_count,
        )

        return segment

