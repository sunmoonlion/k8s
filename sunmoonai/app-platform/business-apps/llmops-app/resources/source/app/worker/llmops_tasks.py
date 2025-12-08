#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Celery Tasks - 从 imooc-llmops 迁移
文档处理、数据集处理等异步任务
"""
import asyncio
from uuid import UUID

from app.core.celery_app import celery_app
from app.core.dependency_injection import get_service
from app.services.llmops.indexing_service import IndexingService
from app.services.llmops.app_service import AppService
from app.db.postgresql.session import SessionLocal


@celery_app.task(acks_late=True, name="llmops.build_documents")
def build_documents(document_ids: list[str]) -> None:
    """根据传递的文档id列表，构建文档（异步任务）"""
    async def _build_documents():
        db = SessionLocal()
        try:
            indexing_service = get_service(IndexingService)
            # 将字符串 ID 转换为 UUID
            uuid_ids = [UUID(doc_id) for doc_id in document_ids]
            await indexing_service.build_documents(db, uuid_ids)
            await db.commit()
        except Exception as e:
            await db.rollback()
            raise
        finally:
            await db.close()
    
    # 在 Celery 任务中运行异步函数
    asyncio.run(_build_documents())


@celery_app.task(acks_late=True, name="llmops.update_document_enabled")
def update_document_enabled(document_id: str) -> None:
    """根据传递的文档id修改文档的状态（异步任务）"""
    async def _update_document_enabled():
        db = SessionLocal()
        try:
            indexing_service = get_service(IndexingService)
            uuid_id = UUID(document_id)
            await indexing_service.update_document_enabled(db, uuid_id)
            await db.commit()
        except Exception as e:
            await db.rollback()
            raise
        finally:
            await db.close()
    
    asyncio.run(_update_document_enabled())


@celery_app.task(acks_late=True, name="llmops.delete_document")
def delete_document(dataset_id: str, document_id: str) -> None:
    """根据传递的文档id+知识库id清除文档记录（异步任务）"""
    async def _delete_document():
        db = SessionLocal()
        try:
            indexing_service = get_service(IndexingService)
            dataset_uuid = UUID(dataset_id)
            document_uuid = UUID(document_id)
            await indexing_service.delete_document(db, dataset_uuid, document_uuid)
            await db.commit()
        except Exception as e:
            await db.rollback()
            raise
        finally:
            await db.close()
    
    asyncio.run(_delete_document())


@celery_app.task(acks_late=True, name="llmops.delete_dataset")
def delete_dataset(dataset_id: str) -> None:
    """根据传递的知识库id删除特定的知识库信息（异步任务）"""
    async def _delete_dataset():
        db = SessionLocal()
        try:
            indexing_service = get_service(IndexingService)
            uuid_id = UUID(dataset_id)
            await indexing_service.delete_dataset(db, uuid_id)
            await db.commit()
        except Exception as e:
            await db.rollback()
            raise
        finally:
            await db.close()
    
    asyncio.run(_delete_dataset())


@celery_app.task(acks_late=True, name="llmops.auto_create_app")
def auto_create_app(name: str, description: str, user_id: str) -> None:
    """根据传递的名称、描述、用户id创建一个Agent（异步任务）"""
    async def _auto_create_app():
        db = SessionLocal()
        try:
            app_service = get_service(AppService)
            uuid_id = UUID(user_id)
            await app_service.auto_create_app(db, name, description, uuid_id)
            await db.commit()
        except Exception as e:
            await db.rollback()
            raise
        finally:
            await db.close()
    
    asyncio.run(_auto_create_app())

