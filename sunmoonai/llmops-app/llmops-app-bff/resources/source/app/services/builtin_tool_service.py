#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Builtin Tool Service - 从 imooc-llmops 迁移
内置工具服务（保持同步，因为工具是同步的）
"""
import mimetypes
import os.path
from dataclasses import dataclass
from typing import Any

from injector import inject
from langchain_core.pydantic_v1 import BaseModel

from app.core.llmops.tools.builtin_tools.providers import BuiltinProviderManager
from app.core.llmops.tools.builtin_tools.categories import BuiltinCategoryManager
from app.core.exceptions import NotFoundException


@inject
@dataclass
class BuiltinToolService:
    """内置工具服务（保持同步）"""
    builtin_provider_manager: BuiltinProviderManager
    builtin_category_manager: BuiltinCategoryManager

    def get_builtin_tools(self) -> list:
        """获取LLMOps项目中的所有内置提供商+工具对应的信息"""
        # TODO: 实现完整的工具列表获取逻辑
        # 1.获取所有的提供商
        # 2.遍历所有的提供商并提取工具信息
        
        builtin_tools = []
        # TODO: 实现完整逻辑
        return builtin_tools

    def get_provider_tool(self, provider_name: str, tool_name: str) -> dict:
        """根据传递的提供者名字+工具名字获取指定工具信息"""
        # TODO: 实现完整的工具获取逻辑
        # 1.获取内置的提供商
        # 2.获取该提供商下对应的工具
        # 3.组装提供商和工具实体信息
        
        raise NotFoundException(f"该工具{tool_name}不存在")

    def get_provider_icon(self, provider_name: str) -> tuple[bytes, str]:
        """根据传递的提供者名字获取icon流信息"""
        # TODO: 实现完整的图标获取逻辑
        # 1.获取对应的工具提供者
        # 2.获取项目的根路径信息
        # 3.拼接得到提供者所在的文件夹
        # 4.拼接得到icon对应的路径
        # 5.检测icon是否存在
        # 6.读取icon的类型
        # 7.读取icon的字节数据
        
        raise NotFoundException(f"该工具提供者{provider_name}不存在")

    def get_categories(self) -> list[dict[str, Any]]:
        """获取所有的内置分类信息，涵盖了category、name、icon"""
        # TODO: 实现完整的分类获取逻辑
        # category_map = self.builtin_category_manager.get_category_map()
        # return [{
        #     "name": category["entity"].name,
        #     "category": category["entity"].category,
        #     "icon": category["icon"],
        # } for category in category_map.values()]
        
        return []

    @classmethod
    def get_tool_inputs(cls, tool) -> list:
        """根据传入的工具获取inputs信息"""
        inputs = []
        if hasattr(tool, "args_schema") and issubclass(tool.args_schema, BaseModel):
            for field_name, model_field in tool.args_schema.__fields__.items():
                inputs.append({
                    "name": field_name,
                    "description": model_field.field_info.description or "",
                    "required": model_field.required,
                    "type": model_field.outer_type_.__name__,
                })
        return inputs

