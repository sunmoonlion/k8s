#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps API Tool Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
import json
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from injector import inject
from sqlalchemy import select, desc, delete
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_api_tool import ApiToolProvider, ApiTool
from app.services.llmops.base_service import BaseService
from app.core.exceptions import ValidateErrorException, NotFoundException

# TODO: 导入其他依赖
# from app.core.llmops.tools.api_tools.entities import OpenAPISchema
# from app.core.llmops.tools.api_tools.providers import ApiProviderManager
# from app.schemas.llmops.api_tool_schema import (
#     CreateApiToolReq,
#     GetApiToolProvidersWithPageReq,
#     UpdateApiToolProviderReq,
# )
# from app.utils.llmops.paginator import Paginator

# 临时定义
class OpenAPISchema:
    def __init__(self, **kwargs):
        self.description = kwargs.get("info", {}).get("description", "")
        self.server = kwargs.get("servers", [{}])[0].get("url", "") if kwargs.get("servers") else ""
        self.paths = kwargs.get("paths", {})


@inject
@dataclass
class ApiToolService(BaseService):
    """自定义API插件服务（异步版本）"""
    # TODO: 注入依赖
    # api_provider_manager: ApiProviderManager

    async def update_api_tool_provider(
        self,
        db: AsyncSession,
        provider_id: UUID,
        name: str,
        icon: str,
        headers: dict,
        openapi_schema_str: str,
        user: User,
    ):
        """根据传递的provider_id+req更新对应的API工具提供者信息"""
        # 1.根据传递的provider_id查找API工具提供者信息并校验
        api_tool_provider = await self.get(db, ApiToolProvider, provider_id)
        if api_tool_provider is None or api_tool_provider.user_id != user.id:
            raise ValidateErrorException("该工具提供者不存在")

        # 2.校验openapi_schema数据
        openapi_schema = self.parse_openapi_schema(openapi_schema_str)

        # 3.检测当前用户是否已经创建了同名的工具提供者，如果是则抛出错误
        result = await db.execute(
            select(ApiToolProvider).where(
                ApiToolProvider.user_id == user.id,
                ApiToolProvider.name == name,
                ApiToolProvider.id != api_tool_provider.id,
            )
        )
        check_api_tool_provider = result.scalar_one_or_none()
        if check_api_tool_provider:
            raise ValidateErrorException(f"该工具提供者名字{name}已存在")

        # 4.先删除该工具提供者下的所有工具
        await db.execute(
            delete(ApiTool).where(
                ApiTool.provider_id == api_tool_provider.id,
                ApiTool.user_id == user.id,
            )
        )
        await db.commit()

        # 5.修改工具提供者信息
        await self.update(
            db,
            api_tool_provider,
            name=name,
            icon=icon,
            headers=headers,
            description=openapi_schema.description,
            openapi_schema=openapi_schema_str,
        )

        # 6.新增工具信息从而完成覆盖更新
        for path, path_item in openapi_schema.paths.items():
            for method, method_item in path_item.items():
                await self.create(
                    db,
                    ApiTool,
                    user_id=user.id,
                    provider_id=api_tool_provider.id,
                    name=method_item.get("operationId"),
                    description=method_item.get("description"),
                    url=f"{openapi_schema.server}{path}",
                    method=method,
                    parameters=method_item.get("parameters", []),
                )

    async def get_api_tool_providers_with_page(
        self,
        db: AsyncSession,
        current_page: int,
        page_size: int,
        search_word: str | None,
        user: User,
    ) -> tuple[list[Any], dict]:
        """获取自定义API工具服务提供者分页列表数据"""
        from app.utils.paginator import Paginator
        
        # 1.构建筛选器
        filters = [ApiToolProvider.user_id == user.id]
        if search_word:
            filters.append(ApiToolProvider.name.ilike(f"%{search_word}%"))

        # 2.构建查询
        query = select(ApiToolProvider).where(*filters).order_by(desc(ApiToolProvider.created_at))
        
        # 3.使用分页器
        paginator = Paginator(current_page=current_page, page_size=page_size)
        api_tool_providers = await paginator.paginate(db, query)
        
        # 4.返回分页信息
        paginator_dict = paginator.to_dict()
        
        return api_tool_providers, paginator_dict

    async def get_api_tool(
        self,
        db: AsyncSession,
        provider_id: UUID,
        tool_name: str,
        user: User
    ) -> ApiTool:
        """根据传递的provider_id+tool_name获取对应工具的参数详情信息"""
        result = await db.execute(
            select(ApiTool).where(
                ApiTool.provider_id == provider_id,
                ApiTool.name == tool_name,
            )
        )
        api_tool = result.scalar_one_or_none()

        if api_tool is None or api_tool.user_id != user.id:
            raise NotFoundException("该工具不存在")

        return api_tool

    async def get_api_tool_provider(
        self,
        db: AsyncSession,
        provider_id: UUID,
        user: User
    ) -> ApiToolProvider:
        """根据传递的provider_id获取API工具提供者信息"""
        # 1.查询数据库获取对应的数据
        api_tool_provider = await self.get(db, ApiToolProvider, provider_id)

        # 2.检验数据是否为空，并且判断该数据是否属于当前用户
        if api_tool_provider is None or api_tool_provider.user_id != user.id:
            raise NotFoundException("该工具提供者不存在")

        return api_tool_provider

    async def create_api_tool(
        self,
        db: AsyncSession,
        name: str,
        icon: str,
        headers: dict,
        openapi_schema_str: str,
        user: User
    ) -> None:
        """根据传递的请求创建自定义API工具"""
        # 1.检验并提取openapi_schema对应的数据
        openapi_schema = self.parse_openapi_schema(openapi_schema_str)

        # 2.查询当前登录的用户是否已经创建了同名的工具提供者，如果是则抛出错误
        result = await db.execute(
            select(ApiToolProvider).where(
                ApiToolProvider.user_id == user.id,
                ApiToolProvider.name == name,
            )
        )
        api_tool_provider = result.scalar_one_or_none()
        if api_tool_provider:
            raise ValidateErrorException(f"该工具提供者名字{name}已存在")

        # 3.首先创建工具提供者，并获取工具提供者的id信息，然后在创建工具信息
        api_tool_provider = await self.create(
            db,
            ApiToolProvider,
            user_id=user.id,
            name=name,
            icon=icon,
            description=openapi_schema.description,
            openapi_schema=openapi_schema_str,
            headers=headers,
        )

        # 4.创建api工具并关联api_tool_provider
        for path, path_item in openapi_schema.paths.items():
            for method, method_item in path_item.items():
                await self.create(
                    db,
                    ApiTool,
                    user_id=user.id,
                    provider_id=api_tool_provider.id,
                    name=method_item.get("operationId"),
                    description=method_item.get("description"),
                    url=f"{openapi_schema.server}{path}",
                    method=method,
                    parameters=method_item.get("parameters", []),
                )

    async def delete_api_tool_provider(
        self,
        db: AsyncSession,
        provider_id: UUID,
        user: User
    ):
        """根据传递的provider_id删除对应的工具提供商+工具的所有信息"""
        # 1.先查找数据，检测下provider_id对应的数据是否存在，权限是否正确
        api_tool_provider = await self.get(db, ApiToolProvider, provider_id)
        if api_tool_provider is None or api_tool_provider.user_id != user.id:
            raise NotFoundException("该工具提供者不存在")

        # 2.先来删除提供者对应的工具信息
        await db.execute(
            delete(ApiTool).where(
                ApiTool.provider_id == provider_id,
                ApiTool.user_id == user.id,
            )
        )

        # 3.删除服务提供者
        await db.delete(api_tool_provider)
        await db.commit()

    @classmethod
    def parse_openapi_schema(cls, openapi_schema_str: str) -> OpenAPISchema:
        """解析传递的openapi_schema字符串，如果出错则抛出错误"""
        try:
            data = json.loads(openapi_schema_str.strip())
            if not isinstance(data, dict):
                raise
        except Exception as e:
            raise ValidateErrorException("传递数据必须符合OpenAPI规范的JSON字符串")

        return OpenAPISchema(**data)
