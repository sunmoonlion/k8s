#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps OAuth Service - 从 imooc-llmops 迁移
第三方授权认证服务（已转换为异步版本）
Account 已改为 User，account_id 已改为 user_id
"""
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

from injector import inject
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.llmops.base_service import BaseService
from app.services.llmops.account_service import AccountService
from app.services.llmops.jwt_service import JwtService
from app.core.exceptions import NotFoundException
from app.core.config import settings

# TODO: 导入 OAuth 相关
# from app.utils.oauth import OAuth, GithubOAuth
# from app.models.postgresql.llmops_llmops_account import AccountOAuth  # 如果存在

# 临时定义
class OAuth:
    def get_access_token(self, code: str) -> str:
        """获取访问令牌"""
        raise NotImplementedError

    def get_user_info(self, access_token: str):
        """获取用户信息"""
        raise NotImplementedError

class GithubOAuth(OAuth):
    def __init__(self, client_id: str, client_secret: str, redirect_uri: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri


@inject
@dataclass
class OAuthService(BaseService):
    """第三方授权认证服务（异步版本）"""
    jwt_service: JwtService
    account_service: AccountService

    @classmethod
    def get_all_oauth(cls) -> dict[str, OAuth]:
        """获取LLMOps集成的所有第三方授权认证方式"""
        # 1.实例化集成的第三方授权认证OAuth
        github = GithubOAuth(
            client_id=settings.GITHUB_CLIENT_ID or "",
            client_secret=settings.GITHUB_CLIENT_SECRET or "",
            redirect_uri=settings.GITHUB_REDIRECT_URI or "",
        )

        # 2.构建字典并返回
        return {
            "github": github,
        }

    @classmethod
    def get_oauth_by_provider_name(cls, provider_name: str) -> OAuth:
        """根据传递的服务提供商名字获取授权服务"""
        all_oauth = cls.get_all_oauth()
        oauth = all_oauth.get(provider_name)

        if oauth is None:
            raise NotFoundException(f"该授权方式[{provider_name}]不存在")

        return oauth

    async def oauth_login(
        self,
        db: AsyncSession,
        provider_name: str,
        code: str,
        remote_addr: str | None = None
    ) -> dict[str, Any]:
        """第三方OAuth授权认证登录，返回授权凭证以及过期时间"""
        # 1.根据传递的provider_name获取oauth
        oauth = self.get_oauth_by_provider_name(provider_name)

        # 2.根据code从第三方登录服务中获取access_token（同步操作）
        import asyncio
        oauth_access_token = await asyncio.to_thread(oauth.get_access_token, code)

        # 3.根据获取到的token提取user_info信息（同步操作）
        oauth_user_info = await asyncio.to_thread(oauth.get_user_info, oauth_access_token)

        # 4.根据provider_name+openid获取授权记录
        account_oauth = await self.account_service.get_account_oauth_by_provider_name_and_openid(
            db,
            provider_name,
            oauth_user_info.id,
        )
        
        if not account_oauth:
            # 5.该授权认证方式是第一次登录，查询邮箱是否存在
            user = await self.account_service.get_account_by_email(db, oauth_user_info.email)
            if not user:
                # 6.用户不存在，注册用户
                user = await self.account_service.create_account(
                    db,
                    name=oauth_user_info.name,
                    email=oauth_user_info.email,
                )
            # 7.添加授权认证记录
            # TODO: 如果存在 AccountOAuth 模型
            # account_oauth = await self.create(
            #     db,
            #     AccountOAuth,
            #     user_id=user.id,
            #     provider=provider_name,
            #     openid=oauth_user_info.id,
            #     encrypted_token=oauth_access_token,
            # )
        else:
            # 8.查找用户信息
            user = await self.account_service.get_account(db, account_oauth.user_id)
            # TODO: 更新授权令牌
            # await self.update(
            #     db,
            #     account_oauth,
            #     encrypted_token=oauth_access_token,
            # )

        # 9.更新用户信息，涵盖最后一次登录时间，以及ip地址
        # TODO: 检查 User 模型是否有相关字段
        # await self.account_service.update_account(
        #     db,
        #     user,
        #     last_login_at=datetime.now(),
        #     last_login_ip=remote_addr,
        # )

        # 10.生成授权凭证信息
        expire_at = int((datetime.now() + timedelta(days=30)).timestamp())
        payload = {
            "sub": str(user.id),
            "iss": "llmops",
            "exp": expire_at,
        }
        access_token = self.jwt_service.generate_token(payload)

        return {
            "expire_at": expire_at,
            "access_token": access_token,
        }

