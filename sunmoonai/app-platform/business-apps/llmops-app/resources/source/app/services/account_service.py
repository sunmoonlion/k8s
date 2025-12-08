#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Account Service - 从 imooc-llmops 迁移
账号服务（已转换为异步版本，但注意：sunmoonai-web-backend 已有 User 服务，此服务主要用于 OAuth 相关）
Account 已改为 User，account_id 已改为 user_id
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any
from uuid import UUID

from injector import inject
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.services.llmops.base_service import BaseService
from app.services.llmops.jwt_service import JwtService
from app.core.exceptions import FailException
from app.core.security import get_password_hash, verify_password


@inject
@dataclass
class AccountService(BaseService):
    """账号服务（异步版本，主要用于 OAuth 相关，注意：sunmoonai-web-backend 已有 User 服务）"""
    jwt_service: JwtService

    async def get_account(
        self,
        db: AsyncSession,
        account_id: UUID
    ) -> User:
        """根据id获取指定的用户模型"""
        return await self.get(db, User, account_id)

    async def get_account_oauth_by_provider_name_and_openid(
        self,
        db: AsyncSession,
        provider_name: str,
        openid: str,
    ):
        """根据传递的提供者名字+openid获取第三方授权认证记录"""
        # TODO: 如果 sunmoonai-web-backend 有 OAuth 模型，需要查询
        # result = await db.execute(
        #     select(AccountOAuth).where(
        #         AccountOAuth.provider == provider_name,
        #         AccountOAuth.openid == openid,
        #     )
        # )
        # return result.scalar_one_or_none()
        return None

    async def get_account_by_email(
        self,
        db: AsyncSession,
        email: str
    ) -> User | None:
        """根据传递的邮箱查询用户信息"""
        result = await db.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()

    async def create_account(
        self,
        db: AsyncSession,
        **kwargs
    ) -> User:
        """根据传递的键值对创建用户信息"""
        return await self.create(db, User, **kwargs)

    async def update_password(
        self,
        db: AsyncSession,
        user: User,
        password: str
    ) -> User:
        """更新当前用户密码信息（使用 sunmoonai-web-backend 的密码处理方式）"""
        # 使用 passlib 的 Argon2 哈希密码
        hashed_password = get_password_hash(password)
        
        # 更新用户信息
        await self.update_account(db, user, hashed_password=hashed_password)
        
        return user

    async def update_account(
        self,
        db: AsyncSession,
        user: User,
        **kwargs
    ) -> User:
        """根据传递的信息更新用户"""
        await self.update(db, user, **kwargs)
        return user

    async def password_login(
        self,
        db: AsyncSession,
        email: str,
        password: str,
        remote_addr: str | None = None
    ) -> tuple[str, int]:
        """根据传递的密码+邮箱登录特定的用户（使用 sunmoonai-web-backend 的密码处理方式）"""
        # 1.根据传递的邮箱查询用户是否存在
        user = await self.get_account_by_email(db, email)
        if not user:
            raise FailException("账号不存在或者密码错误，请核实后重试")

        # 2.校验用户密码是否正确（使用 passlib 的 verify_password）
        if not user.hashed_password or not verify_password(
                plain_password=password,
                hashed_password=user.hashed_password
        ):
            raise FailException("账号不存在或者密码错误，请核实后重试")

        # 3.检查用户是否激活
        if not user.is_active:
            raise FailException("账号已被禁用，请联系管理员")

        # 4.生成凭证信息
        expire_at = int((datetime.now() + timedelta(days=30)).timestamp())
        payload = {
            "sub": str(user.id),
            "iss": "llmops",
            "exp": expire_at,
        }
        access_token = self.jwt_service.generate_token(payload)

        # 5.更新用户的登录信息（User 模型没有 last_login_at, last_login_ip 字段，跳过）
        # 如果需要记录登录信息，可以考虑在 User 模型中添加这些字段

        return access_token, expire_at

