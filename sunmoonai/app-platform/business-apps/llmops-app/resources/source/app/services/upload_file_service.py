#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Upload File Service - 从 imooc-llmops 迁移
已转换为异步版本
"""
from dataclasses import dataclass
from typing import Any

from injector import inject
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.postgresql.llmops_llmops_upload_file import UploadFile
from app.services.llmops.base_service import BaseService


@inject
@dataclass
class UploadFileService(BaseService):
    """上传文件记录服务（异步版本）"""

    async def create_upload_file(
        self,
        db: AsyncSession,
        **kwargs
    ) -> UploadFile:
        """创建文件上传记录"""
        return await self.create(db, UploadFile, **kwargs)
