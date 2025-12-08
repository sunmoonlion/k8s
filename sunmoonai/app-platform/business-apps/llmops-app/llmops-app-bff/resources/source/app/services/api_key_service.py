#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Key Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
import secrets
from dataclasses import dataclass
from uuid import UUID

from injector import inject
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_api_key import ApiKey
from app.services.llmops.base_service import BaseService
from app.schemas.llmops.common import PaginatorReq
from app.core.exceptions import ForbiddenException, NotFoundException

# TODO: 导入 Paginator
# from app.utils.llmops.paginator import Paginator


@inject
@dataclass
class ApiKeyService(BaseService):
    """API秘钥服务（异步版本）"""

    async def create_api_key(
        self,
        db: AsyncSession,
        is_active: bool,
        remark: str,
        user: User
    ) -> ApiKey:
        """根据传递的信息创建API秘钥"""
        return await self.create(
            db,
            ApiKey,
            user_id=user.id,
            api_key=self.generate_api_key(),
            is_active=is_active,
            remark=remark,
        )

    async def get_api_key(
        self,
        db: AsyncSession,
        api_key_id: UUID,
        user: User
    ) -> ApiKey:
        """根据传递的秘钥id+用户信息获取记录"""
        api_key = await self.get(db, ApiKey, api_key_id)
        if not api_key or api_key.user_id != user.id:
            raise ForbiddenException("API秘钥不存在或无权限")
        return api_key

    async def get_api_by_by_credential(
        self,
        db: AsyncSession,
        api_key: str
    ) -> ApiKey | None:
        """根据传递的凭证信息获取ApiKey记录"""
        result = await db.execute(
            select(ApiKey).where(ApiKey.api_key == api_key)
        )
        return result.scalar_one_or_none()

    async def update_api_key(
        self,
        db: AsyncSession,
        api_key_id: UUID,
        user: User,
        **kwargs
    ) -> ApiKey:
        """根据传递的信息更新API秘钥"""
        api_key = await self.get_api_key(db, api_key_id, user)
        await self.update(db, api_key, **kwargs)
        return api_key

    async def delete_api_key(
        self,
        db: AsyncSession,
        api_key_id: UUID,
        user: User
    ) -> ApiKey:
        """根据传递的id删除API秘钥"""
        api_key = await self.get_api_key(db, api_key_id, user)
        await self.delete(db, api_key)
        return api_key

    async def get_api_keys_with_page(
        self,
        db: AsyncSession,
        req: PaginatorReq,
        user: User
    ) -> tuple[list[ApiKey], dict]:
        """根据传递的信息获取API秘钥分页列表数据"""
        from app.utils.paginator import Paginator
        
        # 1.构建查询
        query = select(ApiKey).where(
            ApiKey.user_id == user.id
        ).order_by(desc(ApiKey.created_at))
        
        # 2.使用分页器
        paginator = Paginator(current_page=req.current_page, page_size=req.page_size)
        api_keys = await paginator.paginate(db, query)
        
        # 3.返回分页信息
        paginator_dict = paginator.to_dict()
        
        return api_keys, paginator_dict

    @classmethod
    def generate_api_key(cls, api_key_prefix: str = "llmops-v1/") -> str:
        """生成一个长度为48的API秘钥，并携带前缀"""
        return api_key_prefix + secrets.token_urlsafe(48)
