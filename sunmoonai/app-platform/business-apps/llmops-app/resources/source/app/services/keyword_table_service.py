#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Keyword Table Service - 从 imooc-llmops 迁移
已转换为异步版本
"""
from dataclasses import dataclass
from uuid import UUID

from injector import inject
from redis import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import asyncio

from app.models.postgresql.llmops_llmops_dataset import Segment, KeywordTable
from app.services.llmops.base_service import BaseService

# 导入 Entity 和常量
from app.core.llmops.entity.cache_entity import (
    LOCK_KEYWORD_TABLE_UPDATE_KEYWORD_TABLE,
    LOCK_EXPIRE_TIME,
)


@inject
@dataclass
class KeywordTableService(BaseService):
    """知识库关键词表服务（异步版本）"""

    def __init__(self):
        """初始化关键词表服务"""
        from app.core.extensions import get_redis_client
        self.redis_client = get_redis_client()

    async def get_keyword_table_from_dataset_id(
        self,
        db: AsyncSession,
        dataset_id: UUID
    ) -> KeywordTable:
        """根据传递的知识库id获取关键词表"""
        result = await db.execute(
            select(KeywordTable).where(KeywordTable.dataset_id == dataset_id)
        )
        keyword_table = result.scalar_one_or_none()
        
        if keyword_table is None:
            keyword_table = await self.create(
                db,
                KeywordTable,
                dataset_id=dataset_id,
                keyword_table={}
            )

        return keyword_table

    async def delete_keyword_table_from_ids(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        segment_ids: list[UUID]
    ) -> None:
        """根据传递的知识库id+片段id列表删除对应关键词表中多余的数据"""
        # 1.删除知识库关键词表里多余的数据，该操作需要上锁，避免在并发的情况下拿到错误的数据
        from app.utils.redis_helper import redis_lock, redis_unlock
        from app.utils.llmops_helper import generate_random_string
        
        cache_key = LOCK_KEYWORD_TABLE_UPDATE_KEYWORD_TABLE.format(dataset_id=dataset_id)
        lock_value = generate_random_string(16)
        
        # 尝试获取锁
        lock_acquired = await redis_lock(self.redis_client, cache_key, lock_value, LOCK_EXPIRE_TIME)
        if not lock_acquired:
            raise FailException("获取锁失败，请稍后重试")
        
        try:
            # 2.获取当前知识库的关键词表
            keyword_table_record = await self.get_keyword_table_from_dataset_id(db, dataset_id)
            keyword_table = keyword_table_record.keyword_table.copy()

            # 3.将片段id列表转换成集合，并创建关键词集合用于清除空关键词
            segment_ids_to_delete = set([str(segment_id) for segment_id in segment_ids])
            keywords_to_delete = set()

            # 4.循环遍历所有关键词执行判断与更新
            for keyword, ids in keyword_table.items():
                ids_set = set(ids)
                if segment_ids_to_delete.intersection(ids_set):
                    keyword_table[keyword] = list(ids_set.difference(segment_ids_to_delete))
                    if not keyword_table[keyword]:
                        keywords_to_delete.add(keyword)

            # 5.检测空关键词数据并删除（关键词并没有映射任何字段id的数据）
            for keyword in keywords_to_delete:
                del keyword_table[keyword]

            # 6.将数据更新到关键词表中
            await self.update(db, keyword_table_record, keyword_table=keyword_table)
        finally:
            # 释放锁
            await redis_unlock(self.redis_client, cache_key, lock_value)

    async def add_keyword_table_from_ids(
        self,
        db: AsyncSession,
        dataset_id: UUID,
        segment_ids: list[UUID]
    ) -> None:
        """根据传递的知识库id+片段id列表，在关键词表中添加关键词"""
        # 1.新增知识库关键词表里多余的数据，该操作需要上锁，避免在并发的情况下拿到错误的数据
        from app.utils.redis_helper import redis_lock, redis_unlock
        from app.utils.llmops_helper import generate_random_string
        from app.core.exceptions import FailException
        
        cache_key = LOCK_KEYWORD_TABLE_UPDATE_KEYWORD_TABLE.format(dataset_id=dataset_id)
        lock_value = generate_random_string(16)
        
        # 尝试获取锁
        lock_acquired = await redis_lock(self.redis_client, cache_key, lock_value, LOCK_EXPIRE_TIME)
        if not lock_acquired:
            raise FailException("获取锁失败，请稍后重试")
        
        try:
            # 2.获取指定知识库的关键词表
            keyword_table_record = await self.get_keyword_table_from_dataset_id(db, dataset_id)
            keyword_table = {
                field: set(value) for field, value in keyword_table_record.keyword_table.items()
            }

            # 3.根据segment_ids查找片段的关键词信息
            result = await db.execute(
                select(Segment.id, Segment.keywords).where(Segment.id.in_(segment_ids))
            )
            segments = result.all()

            # 4.循环将新关键词添加到关键词表中
            for segment_id, keywords in segments:
                for keyword in keywords:
                    if keyword not in keyword_table:
                        keyword_table[keyword] = set()
                    keyword_table[keyword].add(str(segment_id))

            # 5.更新关键词表
            await self.update(
                db,
                keyword_table_record,
                keyword_table={field: list(value) for field, value in keyword_table.items()}
            )
        finally:
            # 释放锁
            await redis_unlock(self.redis_client, cache_key, lock_value)

