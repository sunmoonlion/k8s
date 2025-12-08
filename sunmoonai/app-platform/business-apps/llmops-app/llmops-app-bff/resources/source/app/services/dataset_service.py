#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Dataset Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
import logging
from dataclasses import dataclass
from uuid import UUID

from injector import inject
from sqlalchemy import select, desc, delete, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.postgresql.llmops_llmops_dataset import Dataset, Segment, DatasetQuery, AppDatasetJoin
# Removed: user model is in auth service User
from app.services.llmops.base_service import BaseService
from app.services.llmops.retrieval_service import RetrievalService
from app.schemas.llmops.dataset_schema import (
    CreateDatasetReq,
    UpdateDatasetReq,
    GetDatasetsWithPageReq,
    HitReq
)
from app.core.exceptions import NotFoundException, ValidateErrorException, FailException
from app.core.llmops.entity.dataset_entity import DEFAULT_DATASET_DESCRIPTION_FORMATTER


@inject
@dataclass
class DatasetService(BaseService):
    """知识库服务（异步版本）"""
    retrieval_service: RetrievalService

    async def create_dataset(
        self,
        db: AsyncSession,
        req: CreateDatasetReq,
        user: User
    ) -> Dataset:
        """根据传递的请求信息创建知识库"""
        # 1.检测该用户下是否存在同名知识库
        result = await db.execute(
            select(Dataset).where(
                Dataset.user_id == user.id,
                Dataset.name == req.name  # Pydantic 直接访问属性
            )
        )
        dataset = result.scalar_one_or_none()
        if dataset:
            raise ValidateErrorException(f"该知识库{req.name}已存在")

        # 2.检测是否传递了描述信息，如果没有传递需要补充上
        description = req.description or ""
        if description.strip() == "":
            description = DEFAULT_DATASET_DESCRIPTION_FORMATTER.format(name=req.name)

        # 3.创建知识库记录并返回
        return await self.create(
            db,
            Dataset,
            user_id=user.id,
            name=req.name,
            icon=str(req.icon),  # HttpUrl 转字符串
            description=description,
        )

    async def get_dataset_queries(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        user: User
    ) -> list[DatasetQuery]:
        """根据传递的知识库id获取最近的10条查询记录"""
        # 1.获取知识库并校验权限
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise NotFoundException("该知识库不存在")

        # 2.调用知识库查询模型查找最近的10条记录
        result = await db.execute(
            select(DatasetQuery)
            .where(DatasetQuery.dataset_id == dataset_id)
            .order_by(desc(DatasetQuery.created_at))
            .limit(10)
        )
        dataset_queries = result.scalars().all()

        return dataset_queries

    async def get_dataset(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        user: User
    ) -> Dataset:
        """根据传递的知识库id获取知识库记录"""
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise NotFoundException("该知识库不存在")

        return dataset

    async def update_dataset(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        req: UpdateDatasetReq,
        user: User
    ) -> Dataset:
        """根据传递的知识库id+数据更新知识库"""
        # 1.检测知识库是否存在并校验
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise NotFoundException("该知识库不存在")

        # 2.检测修改后的知识库名称是否出现重名
        result = await db.execute(
            select(Dataset).where(
                Dataset.user_id == user.id,
                Dataset.name == req.name,  # Pydantic 直接访问属性
                Dataset.id != dataset_id
            )
        )
        check_dataset = result.scalar_one_or_none()
        if check_dataset:
            raise ValidateErrorException(f"该知识库名称{req.name}已存在，请修改")

        # 3.校验描述信息是否为空，如果为空则人为设置
        description = req.description or ""
        if description.strip() == "":
            description = DEFAULT_DATASET_DESCRIPTION_FORMATTER.format(name=req.name)

        # 4.更新数据
        await self.update(
            db,
            dataset,
            name=req.name,
            icon=str(req.icon),  # HttpUrl 转字符串
            description=description,
        )

        return dataset

    async def get_datasets_with_page(
        self,
        db: AsyncSession,
        req: GetDatasetsWithPageReq,
        user: User
    ) -> tuple[list[Dataset], dict]:  # TODO: 返回 Paginator 对象
        """根据传递的信息获取知识库列表分页数据"""
        # 1.构建筛选器
        filters = [Dataset.user_id == user.id]
        if req.search_word:
            filters.append(Dataset.name.ilike(f"%{req.search_word}%"))

        # 2.构建查询
        query = select(Dataset).where(*filters).order_by(desc(Dataset.created_at))

        # 3.执行分页查询
        offset = req.offset
        page_size = req.page_size
        
        result = await db.execute(query.offset(offset).limit(page_size))
        datasets = result.scalars().all()

        # 4.获取总数
        count_result = await db.execute(
            select(func.count(Dataset.id)).where(*filters)
        )
        total = count_result.scalar_one()

        # 返回 Paginator 对象
        paginator = {
            "total": total,
            "current_page": req.current_page,
            "page_size": page_size,
            "total_page": (total + page_size - 1) // page_size if page_size > 0 else 0
        }

        return datasets, paginator

    async def hit(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        req: HitReq,
        user: User
    ) -> list[dict]:
        """根据传递的知识库id+请求执行召回测试"""
        # 1.检测知识库是否存在并校验
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise NotFoundException("该知识库不存在")

        # 2.调用检索服务执行检索
        # TODO: 将 retrieval_service 也改为异步，这里先假设是同步的，需要在线程池中运行
        import asyncio
        req_dict = req.model_dump(exclude_none=True)
        lc_documents = await asyncio.to_thread(
            self.retrieval_service.search_in_datasets,
            dataset_ids=[dataset_id],
            account_id=user.id,  # TODO: 改为 user_id
            **req_dict
        )
        lc_document_dict = {str(lc_document.metadata["segment_id"]): lc_document for lc_document in lc_documents}

        # 3.根据检索到的数据查询对应的片段信息
        segment_ids = [str(lc_document.metadata["segment_id"]) for lc_document in lc_documents]
        if segment_ids:
            result = await db.execute(
                select(Segment).where(Segment.id.in_(segment_ids))
            )
            segments = result.scalars().all()
        else:
            segments = []
        
        segment_dict = {str(segment.id): segment for segment in segments}

        # 4.排序片段数据
        sorted_segments = [
            segment_dict[str(lc_document.metadata["segment_id"])]
            for lc_document in lc_documents
            if str(lc_document.metadata["segment_id"]) in segment_dict
        ]

        # 5.组装响应数据
        hit_result = []
        # 批量获取 document 和 upload_file 信息
        document_ids = list(set(segment.document_id for segment in sorted_segments))
        documents = {}
        upload_files = {}
        if document_ids:
            from app.models.postgresql.llmops_llmops_dataset import Document
            from app.models.postgresql.llmops_llmops_upload_file import UploadFile
            doc_result = await db.execute(
                select(Document).where(Document.id.in_(document_ids))
            )
            docs = doc_result.scalars().all()
            documents = {str(doc.id): doc for doc in docs}
            
            upload_file_ids = list(set(doc.upload_file_id for doc in docs))
            if upload_file_ids:
                upload_result = await db.execute(
                    select(UploadFile).where(UploadFile.id.in_(upload_file_ids))
                )
                uploads = upload_result.scalars().all()
                upload_files = {str(upload.id): upload for upload in uploads}
        
        for segment in sorted_segments:
            document = documents.get(str(segment.document_id))
            upload_file = upload_files.get(str(document.upload_file_id)) if document else None
            hit_result.append({
                "id": segment.id,
                "document": {
                    "id": document.id if document else segment.document_id,
                    "name": document.name if document else "",
                    "extension": upload_file.extension if upload_file else "",
                    "mime_type": upload_file.mime_type if upload_file else "",
                },
                "dataset_id": segment.dataset_id,
                "score": lc_document_dict[str(segment.id)].metadata.get("score", 0),
                "position": segment.position,
                "content": segment.content,
                "keywords": segment.keywords,
                "character_count": segment.character_count,
                "token_count": segment.token_count,
                "hit_count": segment.hit_count,
                "enabled": segment.enabled,
                "disabled_at": segment.disabled_at.isoformat() if segment.disabled_at else None,
                "status": segment.status,
                "error": segment.error,
                "updated_at": segment.updated_at.isoformat(),
                "created_at": segment.created_at.isoformat(),
            })

        return hit_result

    async def delete_dataset(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        user: User
    ) -> Dataset:
        """根据传递的知识库id删除知识库信息，涵盖知识库底下的所有文档、片段、关键词，以及向量数据库里存储的数据"""
        # 1.获取知识库并校验权限
        dataset = await self.get(db, Dataset, dataset_id)
        if dataset is None or dataset.user_id != user.id:
            raise NotFoundException("该知识库不存在")

        try:
            # 2.删除知识库基础记录以及知识库和应用关联的记录
            await self.delete(db, dataset)
            
            # 删除关联记录
            await db.execute(
                delete(AppDatasetJoin).where(AppDatasetJoin.dataset_id == dataset_id)
            )
            await db.commit()

            # 3.调用异步任务执行后续的操作
            from app.worker.llmops_tasks import delete_dataset
            delete_dataset.delay(str(dataset_id))
        except Exception as e:
            logging.exception(
                "删除知识库失败, dataset_id: %(dataset_id)s, 错误信息: %(error)s",
                {"dataset_id": dataset_id, "error": e},
            )
            raise FailException("删除知识库失败，请稍后重试")

