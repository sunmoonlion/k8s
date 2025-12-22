#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Indexing Service - 从 imooc-llmops 迁移
索引构建服务（部分异步版本，因为涉及文件处理和向量数据库）
Account 已改为 User，account_id 已改为 user_id
"""
import logging
import re
import uuid
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from injector import inject
from langchain_core.documents import Document as LCDocument
from redis import Redis
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from weaviate.classes.query import Filter
import asyncio

from app.models.postgresql.llmops_llmops_dataset import Document, Segment, KeywordTable, DatasetQuery
from app.services.llmops.base_service import BaseService
from app.services.llmops.embeddings_service import EmbeddingsService
from app.services.llmops.jieba_service import JiebaService
from app.services.llmops.keyword_table_service import KeywordTableService
from app.services.llmops.process_rule_service import ProcessRuleService
from app.services.llmops.vector_database_service import VectorDatabaseService
from app.core.exceptions import NotFoundException

# 导入 Entity 和常量
from app.core.llmops.entity.cache_entity import LOCK_DOCUMENT_UPDATE_ENABLED
from app.core.llmops.entity.dataset_entity import DocumentStatus, SegmentStatus
from app.utils.llmops_helper import generate_text_hash
# TODO: 导入其他依赖
# from app.core.llmops.file_extractor import FileExtractor


@inject
@dataclass
class IndexingService(BaseService):
    """索引构建服务（部分异步版本）"""
    # TODO: 注入依赖
    # file_extractor: FileExtractor
    process_rule_service: ProcessRuleService
    embeddings_service: EmbeddingsService
    jieba_service: JiebaService
    keyword_table_service: KeywordTableService
    vector_database_service: VectorDatabaseService

    def __init__(
        self,
        process_rule_service: ProcessRuleService,
        embeddings_service: EmbeddingsService,
        jieba_service: JiebaService,
        keyword_table_service: KeywordTableService,
        vector_database_service: VectorDatabaseService
    ):
        """初始化索引服务"""
        from app.core.extensions import get_redis_client
        self.redis_client = get_redis_client()
        self.process_rule_service = process_rule_service
        self.embeddings_service = embeddings_service
        self.jieba_service = jieba_service
        self.keyword_table_service = keyword_table_service
        self.vector_database_service = vector_database_service

    async def build_documents(
        self,
        db: AsyncSession,
        document_ids: list[UUID]
    ) -> None:
        """根据传递的文档id列表构建知识库文档，涵盖了加载、分割、索引构建、数据存储等内容"""
        # 1.根据传递的文档id获取所有文档
        result = await db.execute(
            select(Document).where(Document.id.in_(document_ids))
        )
        documents = result.scalars().all()

        # 2.执行循环遍历所有文档完成对每个文档的构建
        for document in documents:
            try:
                # 3.更新当前状态为解析中，并记录开始处理的时间
                await self.update(
                    db,
                    document,
                    status=DocumentStatus.PARSING,
                    processing_started_at=datetime.now()
                )

                # 4.执行文档加载步骤，并更新文档的状态与时间
                lc_documents = await self._parsing(db, document)

                # 5.执行文档分割步骤，并更新文档状态与时间，涵盖了片段的信息
                lc_segments = await self._splitting(db, document, lc_documents)

                # 6.执行文档索引构建，涵盖关键词提取、向量，并更新数据状态
                await self._indexing(db, document, lc_segments)

                # 7.存储操作，涵盖文档状态更新，以及向量数据库的存储
                await self._completed(db, document, lc_segments)

            except Exception as e:
                logging.exception("构建文档发生错误, 错误信息: %(error)s", {"error": e})
                await self.update(
                    db,
                    document,
                    status=DocumentStatus.ERROR,
                    error=str(e),
                    stopped_at=datetime.now(),
                )

    async def update_document_enabled(
        self,
        db: AsyncSession,
        document_id: UUID
    ) -> None:
        """根据传递的文档id更新文档状态，同时修改weaviate向量数据库中的记录"""
        # 1.构建缓存键
        cache_key = LOCK_DOCUMENT_UPDATE_ENABLED.format(document_id=document_id)

        # 2.根据传递的document_id获取文档记录
        document = await self.get(db, Document, document_id)
        if document is None:
            logging.exception("当前文档不存在, 文档id: %(document_id)s", {"document_id": document_id})
            raise NotFoundException("当前文档不存在")

        # 3.查询归属于当前文档的所有片段的节点id
        result = await db.execute(
            select(Segment.id, Segment.node_id, Segment.enabled).where(
                Segment.document_id == document_id,
                Segment.status == SegmentStatus.COMPLETED,
            )
        )
        segments = result.all()
        segment_ids = [id for id, _, _ in segments]
        node_ids = [node_id for _, node_id, _ in segments]
        
        try:
            # 4.执行循环遍历所有node_ids并更新向量数据（同步操作）
            collection = self.vector_database_service.collection
            for node_id in node_ids:
                try:
                    await asyncio.to_thread(
                        collection.data.update,
                        uuid=node_id,
                        properties={
                            "document_enabled": document.enabled,
                        }
                    )
                except Exception as e:
                    await db.execute(
                        select(Segment).where(Segment.node_id == node_id)
                    )
                    # TODO: 更新片段状态为 ERROR
                    # await self.update(...)

            # 5.更新关键词表对应的数据
            if document.enabled is True:
                # 从禁用改为启用，需要新增关键词
                enabled_segment_ids = [id for id, _, enabled in segments if enabled is True]
                await self.keyword_table_service.add_keyword_table_from_ids(
                    db, document.dataset_id, enabled_segment_ids
                )
            else:
                # 从启用改为禁用，需要剔除关键词
                await self.keyword_table_service.delete_keyword_table_from_ids(
                    db, document.dataset_id, segment_ids
                )
        except Exception as e:
            # 记录日志并将状态修改回原来的状态
            logging.exception(
                "修改向量数据库文档启用状态失败, document_id: %(document_id)s, 错误信息: %(error)s",
                {"document_id": document_id, "error": e},
            )
            origin_enabled = not document.enabled
            await self.update(
                db,
                document,
                enabled=origin_enabled,
                disabled_at=None if origin_enabled else datetime.now(),
            )
        finally:
            # 6.清空缓存键表示异步操作已经执行完成
            from app.utils.redis_helper import redis_delete
            await redis_delete(self.redis_client, cache_key)

    async def delete_document(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        document_id: UUID
    ) -> None:
        """根据传递的知识库id+文档id删除文档信息"""
        # 1.查找该文档下的所有片段id列表
        result = await db.execute(
            select(Segment.id).where(Segment.document_id == document_id)
        )
        segment_ids = [str(id) for id, in result.all()]

        # 2.调用向量数据库删除其关联记录（同步操作）
        collection = self.vector_database_service.collection
        await asyncio.to_thread(
            collection.data.delete_many,
            where=Filter.by_property("document_id").equal(document_id),
        )

        # 3.删除postgres关联的segment记录
        await db.execute(
            delete(Segment).where(Segment.document_id == document_id)
        )
        await db.commit()

        # 4.删除片段id对应的关键词记录
        await self.keyword_table_service.delete_keyword_table_from_ids(
            db, dataset_id, segment_ids
        )

    async def delete_dataset(
        self,
        db: AsyncSession,
        dataset_id: UUID
    ) -> None:
        """根据传递的知识库id执行相应的删除操作"""
        try:
            # 1.删除关联的文档记录
            await db.execute(
                delete(Document).where(Document.dataset_id == dataset_id)
            )

            # 2.删除关联的片段记录
            await db.execute(
                delete(Segment).where(Segment.dataset_id == dataset_id)
            )

            # 3.删除关联的关键词表记录
            await db.execute(
                delete(KeywordTable).where(KeywordTable.dataset_id == dataset_id)
            )

            # 4.删除知识库查询记录
            await db.execute(
                delete(DatasetQuery).where(DatasetQuery.dataset_id == dataset_id)
            )

            await db.commit()

            # 5.调用向量数据库删除知识库的关联记录（同步操作）
            await asyncio.to_thread(
                self.vector_database_service.collection.data.delete_many,
                where=Filter.by_property("dataset_id").equal(str(dataset_id))
            )
        except Exception as e:
            logging.exception(
                "异步删除知识库关联内容出错, dataset_id: %(dataset_id)s, 错误信息: %(error)s",
                {"dataset_id": dataset_id, "error": e},
            )

    async def _parsing(
        self,
        db: AsyncSession,
        document: Document
    ) -> list[LCDocument]:
        """解析传递的文档为LangChain文档列表"""
        # TODO: 实现文件提取逻辑
        # 1.获取upload_file并加载LangChain文档
        # upload_file = document.upload_file
        # lc_documents = await asyncio.to_thread(
        #     self.file_extractor.load,
        #     upload_file,
        #     False,
        #     True
        # )
        
        # 临时返回空列表，需要完整实现
        lc_documents = []

        # 2.循环处理LangChain文档，并删除多余的空白字符串
        for lc_document in lc_documents:
            lc_document.page_content = self._clean_extra_text(lc_document.page_content)

        # 3.更新文档状态并记录时间
        await self.update(
            db,
            document,
            character_count=sum([len(lc_document.page_content) for lc_document in lc_documents]),
            status=DocumentStatus.SPLITTING,
            parsing_completed_at=datetime.now(),
        )

        return lc_documents

    async def _splitting(
        self,
        db: AsyncSession,
        document: Document,
        lc_documents: list[LCDocument]
    ) -> list[LCDocument]:
        """根据传递的信息进行文档分割，拆分成小块片段"""
        try:
            # 1.根据process_rule获取文本分割器
            # TODO: 获取 process_rule
            # process_rule = document.process_rule
            # text_splitter = await asyncio.to_thread(
            #     self.process_rule_service.get_text_splitter_by_process_rule,
            #     process_rule,
            #     self.embeddings_service.calculate_token_count,
            # )
            
            # 临时实现
            from langchain_text_splitters import RecursiveCharacterTextSplitter
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200,
            )

            # 2.按照process_rule规则清除多余的字符串
            # for lc_document in lc_documents:
            #     lc_document.page_content = await asyncio.to_thread(
            #         self.process_rule_service.clean_text_by_process_rule,
            #         lc_document.page_content,
            #         process_rule,
            #     )

            # 3.分割文档列表为片段列表（同步操作）
            lc_segments = await asyncio.to_thread(
                text_splitter.split_documents,
                lc_documents
            )

            # 4.获取对应文档下得到最大片段位置
            result = await db.execute(
                select(func.coalesce(func.max(Segment.position), 0)).where(
                    Segment.document_id == document.id
                )
            )
            position = result.scalar() or 0

            # 5.循环处理片段数据并添加元数据，同时存储到postgres数据库中
            segments = []
            for lc_segment in lc_segments:
                position += 1
                content = lc_segment.page_content
                segment = await self.create(
                    db,
                    Segment,
                    user_id=document.user_id,
                    dataset_id=document.dataset_id,
                    document_id=document.id,
                    node_id=uuid.uuid4(),
                    position=position,
                    content=content,
                    character_count=len(content),
                    token_count=self.embeddings_service.calculate_token_count(content),
                    hash=generate_text_hash(content),
                    status=SegmentStatus.WAITING,
                )
                lc_segment.metadata = {
                    "user_id": str(document.user_id),
                    "dataset_id": str(document.dataset_id),
                    "document_id": str(document.id),
                    "segment_id": str(segment.id),
                    "node_id": str(segment.node_id),
                    "document_enabled": False,
                    "segment_enabled": False,
                }
                segments.append(segment)

            # 6.更新文档的数据，涵盖状态、token数等内容
            await self.update(
                db,
                document,
                token_count=sum([segment.token_count for segment in segments]),
                status=DocumentStatus.INDEXING,
                splitting_completed_at=datetime.now(),
            )

            return lc_segments
        except Exception as e:
            logging.exception("_splitting出现异常: %(error)s", {"error": e})
            raise

    async def _indexing(
        self,
        db: AsyncSession,
        document: Document,
        lc_segments: list[LCDocument]
    ) -> None:
        """根据传递的信息构建索引，涵盖关键词提取、词表构建"""
        for lc_segment in lc_segments:
            # 1.提取每一个片段对应的关键词，关键词的数量最多不超过10个（同步操作）
            keywords = await asyncio.to_thread(
                self.jieba_service.extract_keywords,
                lc_segment.page_content,
                10
            )

            # 2.逐条更新文档片段的关键词
            segment_id = UUID(lc_segment.metadata["segment_id"])
            result = await db.execute(
                select(Segment).where(Segment.id == segment_id)
            )
            segment = result.scalar_one()
            
            await self.update(
                db,
                segment,
                keywords=keywords,
                status=SegmentStatus.INDEXING,
                indexing_completed_at=datetime.now(),
            )

            # 3.获取当前知识库的关键词表
            keyword_table_record = await self.keyword_table_service.get_keyword_table_from_dataset_id(
                db, document.dataset_id
            )

            keyword_table = {
                field: set(value) for field, value in keyword_table_record.keyword_table.items()
            }

            # 4.循环将新关键词添加到关键词表中
            for keyword in keywords:
                if keyword not in keyword_table:
                    keyword_table[keyword] = set()
                keyword_table[keyword].add(lc_segment.metadata["segment_id"])

            # 5.更新关键词表
            await self.update(
                db,
                keyword_table_record,
                keyword_table={field: list(value) for field, value in keyword_table.items()}
            )

        # 6.更新文档状态
        await self.update(
            db,
            document,
            indexing_completed_at=datetime.now(),
        )

    async def _completed(
        self,
        db: AsyncSession,
        document: Document,
        lc_segments: list[LCDocument]
    ) -> None:
        """存储文档片段到向量数据库，并完成状态更新"""
        # 1.循环遍历片段列表数据，将文档状态及片段状态设置成True
        for lc_segment in lc_segments:
            lc_segment.metadata["document_enabled"] = True
            lc_segment.metadata["segment_enabled"] = True

        # 2.调用向量数据库，每次存储10条数据，避免一次传递过多的数据
        try:
            for i in range(0, len(lc_segments), 10):
                chunks = lc_segments[i:i + 10]
                ids = [chunk.metadata["node_id"] for chunk in chunks]
                
                # 同步操作：添加文档到向量数据库
                await asyncio.to_thread(
                    self.vector_database_service.vector_store.add_documents,
                    chunks,
                    ids=ids
                )
                
                # 更新片段状态
                for node_id in ids:
                    result = await db.execute(
                        select(Segment).where(Segment.node_id == UUID(node_id))
                    )
                    segment = result.scalar_one()
                    await self.update(
                        db,
                        segment,
                        status=SegmentStatus.COMPLETED,
                        completed_at=datetime.now(),
                        enabled=True,
                    )
        except Exception as e:
            logging.exception(
                "构建文档片段索引发生异常, 错误信息: %(error)s",
                {"error": e},
            )
            # TODO: 更新片段状态为 ERROR
            for node_id in ids:
                result = await db.execute(
                    select(Segment).where(Segment.node_id == UUID(node_id))
                )
                segment = result.scalar_one()
                await self.update(
                    db,
                    segment,
                    status=SegmentStatus.ERROR,
                    completed_at=None,
                    stopped_at=datetime.now(),
                    enabled=False,
                    error=str(e),
                )

        # 3.更新文档的状态数据
        await self.update(
            db,
            document,
            status=DocumentStatus.COMPLETED,
            completed_at=datetime.now(),
            enabled=True,
        )

    @classmethod
    def _clean_extra_text(cls, text: str) -> str:
        """清除过滤传递的多余空白字符串"""
        text = re.sub(r'<\|', '<', text)
        text = re.sub(r'\|>', '>', text)
        text = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\xEF\xBF\xBE]', '', text)
        text = re.sub('\uFFFE', '', text)  # 删除零宽非标记字符
        return text

