#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps App Config Service - 从 imooc-llmops 迁移
已转换为异步版本
Account 已改为 User，account_id 已改为 user_id
"""
from dataclasses import dataclass
from typing import Any, Union
from uuid import UUID

from injector import inject
from langchain_core.tools import BaseTool
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.postgresql.llmops_llmops_app import LLMOpsApp, AppConfig, AppConfigVersion, AppDatasetJoin
from app.models.postgresql.llmops_llmops_api_tool import ApiTool
from app.models.postgresql.llmops_llmops_dataset import Dataset
from app.models.postgresql.llmops_llmops_workflow import Workflow
from app.services.llmops.base_service import BaseService

# 导入 Entity 和常量
from app.core.llmops.entity.app_entity import DEFAULT_APP_CONFIG
from app.core.llmops.entity.workflow_entity import WorkflowStatus
from app.utils.llmops_helper import datetime_to_timestamp, get_value_type
# TODO: 导入其他依赖
# from app.core.llmops.language_model import LanguageModelManager
# from app.core.llmops.tools.api_tools.entities import ToolEntity
# from app.core.llmops.tools.api_tools.providers import ApiProviderManager
# from app.core.llmops.tools.builtin_tools.providers import BuiltinProviderManager
# from app.core.llmops.workflow import Workflow as WorkflowTool
# from app.core.llmops.workflow.entities.workflow_entity import WorkflowConfig


@inject
@dataclass
class AppConfigService(BaseService):
    """应用配置服务（异步版本）"""
    # TODO: 注入依赖
    # api_provider_manager: ApiProviderManager
    # builtin_provider_manager: BuiltinProviderManager
    # language_model_manager: LanguageModelManager

    async def get_draft_app_config(
        self,
        db: AsyncSession,
        app: LLMOpsApp
    ) -> dict[str, Any]:
        """根据传递的应用获取该应用的草稿配置"""
        # 1.提取应用的草稿配置（需要通过 Service 层获取，因为原模型的 @property 已移除）
        result = await db.execute(
            select(AppConfigVersion).where(
                AppConfigVersion.app_id == app.id,
                AppConfigVersion.config_type == "draft"
            )
        )
        draft_app_config = result.scalar_one_or_none()
        if not draft_app_config:
            raise NotFoundException("草稿配置不存在")

        # 2.校验model_config信息，如果使用了不存在的提供者或者模型，则使用默认值(宽松校验)
        validate_model_config = await self._process_and_validate_model_config(draft_app_config.model_config)
        if draft_app_config.model_config != validate_model_config:
            await self.update(db, draft_app_config, model_config=validate_model_config)

        # 3.循环遍历工具列表删除已经被删除的工具信息
        tools, validate_tools = await self._process_and_validate_tools(db, draft_app_config.tools)

        # 4.判断是否需要更新草稿配置中的工具列表信息
        if draft_app_config.tools != validate_tools:
            await self.update(db, draft_app_config, tools=validate_tools)

        # 5.校验知识库列表，如果引用了不存在/被删除的知识库，需要剔除数据并更新，同时获取知识库的额外信息
        datasets, validate_datasets = await self._process_and_validate_datasets(db, draft_app_config.datasets)

        # 6.判断是否存在已删除的知识库，如果存在则更新
        if set(validate_datasets) != set(draft_app_config.datasets):
            await self.update(db, draft_app_config, datasets=validate_datasets)

        # 7.校验工作流列表对应的数据
        workflows, validate_workflows = await self._process_and_validate_workflows(db, draft_app_config.workflows)
        if set(validate_workflows) != set(draft_app_config.workflows):
            await self.update(db, draft_app_config, workflows=validate_workflows)

        # 8.将数据转换成字典后返回
        return self._process_and_transformer_app_config(
            validate_model_config,
            tools,
            workflows,
            datasets,
            draft_app_config,
        )

    async def get_app_config(
        self,
        db: AsyncSession,
        app: LLMOpsApp
    ) -> dict[str, Any]:
        """根据传递的应用获取该应用的运行配置"""
        # 1.提取应用的运行配置
        if not app.app_config_id:
            raise NotFoundException("应用未发布，无运行配置")
        
        app_config = await self.get(db, AppConfig, app.app_config_id)
        if not app_config:
            raise NotFoundException("运行配置不存在")

        # 2.校验model_config信息，如果运行时配置里的model_config发生变化则进行更新
        validate_model_config = await self._process_and_validate_model_config(app_config.model_config)
        if app_config.model_config != validate_model_config:
            await self.update(db, app_config, model_config=validate_model_config)

        # 3.循环遍历工具列表删除已经被删除的工具信息
        tools, validate_tools = await self._process_and_validate_tools(db, app_config.tools)

        # 4.判断是否需要更新运行配置中的工具列表信息
        if app_config.tools != validate_tools:
            await self.update(db, app_config, tools=validate_tools)

        # 5.校验知识库列表
        result = await db.execute(
            select(AppDatasetJoin).where(AppDatasetJoin.app_id == app.id)
        )
        app_dataset_joins = result.scalars().all()
        origin_datasets = [str(app_dataset_join.dataset_id) for app_dataset_join in app_dataset_joins]
        datasets, validate_datasets = await self._process_and_validate_datasets(db, origin_datasets)

        # 6.判断是否存在已删除的知识库，如果存在则删除关联记录
        for dataset_id in set(origin_datasets) - set(validate_datasets):
            await db.execute(
                delete(AppDatasetJoin).where(AppDatasetJoin.dataset_id == dataset_id)
            )
        await db.commit()

        # 7.校验工作流列表对应的数据
        workflows, validate_workflows = await self._process_and_validate_workflows(db, app_config.workflows)
        if set(validate_workflows) != set(app_config.workflows):
            await self.update(db, app_config, workflows=validate_workflows)

        # 8.将数据转换成字典后返回
        return self._process_and_transformer_app_config(
            validate_model_config,
            tools,
            workflows,
            datasets,
            app_config,
        )

    def get_langchain_tools_by_tools_config(self, tools_config: list[dict]) -> list[BaseTool]:
        """根据传递的工具配置列表获取langchain工具列表"""
        # 注意：这个方法保持同步，因为它会被 LangChain 工具调用
        # TODO: 实现完整的工具获取逻辑
        # 1.循环遍历所有工具配置列表信息
        # 2.根据不同的工具类型执行不同的操作（builtin_tool, api_tool）
        # 3.返回工具列表
        
        tools = []
        # TODO: 实现工具获取逻辑
        return tools

    def get_langchain_tools_by_workflow_ids(self, workflow_ids: list[UUID]) -> list[BaseTool]:
        """根据传递的工作流配置列表获取langchain工具列表"""
        # 注意：这个方法保持同步，因为它会被 LangChain 工具调用
        # TODO: 实现完整的工作流工具获取逻辑
        workflows = []
        # TODO: 实现工作流工具获取逻辑
        return workflows

    @classmethod
    def _process_and_transformer_app_config(
        cls,
        model_config: dict[str, Any],
        tools: list[dict],
        workflows: list[dict],
        datasets: list[dict],
        app_config: Union[AppConfig, AppConfigVersion]
    ) -> dict[str, Any]:
        """根据传递的插件列表、工作流列表、知识库列表以及应用配置创建字典信息"""
        return {
            "id": str(app_config.id),
            "model_config": model_config,
            "dialog_round": app_config.dialog_round,
            "preset_prompt": app_config.preset_prompt,
            "tools": tools,
            "workflows": workflows,
            "datasets": datasets,
            "retrieval_config": app_config.retrieval_config,
            "long_term_memory": app_config.long_term_memory,
            "opening_statement": app_config.opening_statement,
            "opening_questions": app_config.opening_questions,
            "speech_to_text": app_config.speech_to_text,
            "text_to_speech": app_config.text_to_speech,
            "suggested_after_answer": app_config.suggested_after_answer,
            "review_config": app_config.review_config,
            "updated_at": int(app_config.updated_at.timestamp()) if app_config.updated_at else 0,
            "created_at": int(app_config.created_at.timestamp()) if app_config.created_at else 0,
        }

    async def _process_and_validate_tools(
        self,
        db: AsyncSession,
        origin_tools: list[dict]
    ) -> tuple[list[dict], list[dict]]:
        """根据传递的原始工具信息进行处理和校验"""
        # TODO: 实现完整的工具验证逻辑
        # 1.循环遍历工具列表删除已被删除的工具
        # 2.对于 builtin_tool，通过 builtin_provider_manager 验证
        # 3.对于 api_tool，查询数据库验证
        
        validate_tools = []
        tools = []
        
        for tool in origin_tools:
            if tool.get("type") == "builtin_tool":
                # TODO: 实现内置工具验证
                validate_tools.append(tool)
                tools.append({
                    "type": "builtin_tool",
                    "provider": {
                        "id": tool.get("provider", {}).get("id", ""),
                        "name": tool.get("provider", {}).get("name", ""),
                        "label": tool.get("provider", {}).get("label", ""),
                        "icon": tool.get("provider", {}).get("icon", ""),
                        "description": tool.get("provider", {}).get("description", ""),
                    },
                    "tool": {
                        "id": tool.get("tool", {}).get("id", ""),
                        "name": tool.get("tool", {}).get("name", ""),
                        "label": tool.get("tool", {}).get("label", ""),
                        "description": tool.get("tool", {}).get("description", ""),
                        "params": tool.get("tool", {}).get("params", {}),
                    }
                })
            elif tool.get("type") == "api_tool":
                # 查询数据库获取对应的工具记录
                provider_id = tool.get("provider_id")
                tool_id = tool.get("tool_id")
                
                result = await db.execute(
                    select(ApiTool).where(
                        ApiTool.provider_id == provider_id,
                        ApiTool.name == tool_id,
                    )
                )
                tool_record = result.scalar_one_or_none()
                if not tool_record:
                    continue

                validate_tools.append(tool)
                
                # 获取 provider 信息
                from app.models.postgresql.llmops_llmops_api_tool import ApiToolProvider
                provider_result = await db.execute(
                    select(ApiToolProvider).where(ApiToolProvider.id == provider_id)
                )
                provider_record = provider_result.scalar_one_or_none()
                
                tools.append({
                    "type": "api_tool",
                    "provider": {
                        "id": str(provider_id),
                        "name": provider_record.name if provider_record else "",
                        "label": provider_record.name if provider_record else "",
                        "icon": provider_record.icon if provider_record else "",
                        "description": provider_record.description if provider_record else "",
                    },
                    "tool": {
                        "id": str(tool_record.id),
                        "name": tool_record.name,
                        "label": tool_record.name,
                        "description": tool_record.description or "",
                        "params": tool_record.parameters or {},
                    },
                })

        return tools, validate_tools

    async def _process_and_validate_datasets(
        self,
        db: AsyncSession,
        origin_datasets: list
    ) -> tuple[list[dict], list]:
        """根据传递的知识库并返回知识库配置与校验后的数据"""
        # 1.校验知识库配置列表
        datasets = []
        if not origin_datasets:
            return datasets, []
        
        # 将 origin_datasets 转换为 UUID 列表（可能是字符串或 UUID）
        dataset_ids = [UUID(dataset_id) if isinstance(dataset_id, str) else dataset_id for dataset_id in origin_datasets]
        
        result = await db.execute(
            select(Dataset).where(Dataset.id.in_(dataset_ids))
        )
        dataset_records = result.scalars().all()
        dataset_dict = {str(dataset_record.id): dataset_record for dataset_record in dataset_records}
        dataset_sets = set(dataset_dict.keys())

        # 2.计算存在的知识库id列表，为了保留原始顺序，使用列表循环的方式来判断
        validate_datasets = [str(dataset_id) for dataset_id in origin_datasets if str(dataset_id) in dataset_sets]

        # 3.循环获取知识库数据
        for dataset_id in validate_datasets:
            dataset = dataset_dict.get(dataset_id)
            if dataset:
                datasets.append({
                    "id": str(dataset.id),
                    "name": dataset.name,
                    "icon": dataset.icon,
                    "description": dataset.description,
                })

        return datasets, validate_datasets

    async def _process_and_validate_model_config(
        self,
        origin_model_config: dict[str, Any]
    ) -> dict[str, Any]:
        """根据传递的模型配置处理并校验，随后返回校验后的信息"""
        # 1.判断model_config是否为字典，如果不是则直接返回默认值
        if not isinstance(origin_model_config, dict):
            return DEFAULT_APP_CONFIG["model_config"]

        # 2.提取origin_model_config中provider、model、parameters对应的信息
        model_config = {
            "provider": origin_model_config.get("provider", ""),
            "model": origin_model_config.get("model", ""),
            "parameters": origin_model_config.get("parameters", {}),
        }

        # TODO: 实现完整的模型配置验证逻辑
        # 3.判断provider是否存在、类型是否正确
        # 4.判断model是否存在、类型是否正确
        # 5.判断parameters信息类型是否错误

        return model_config

    async def _process_and_validate_workflows(
        self,
        db: AsyncSession,
        origin_workflows: list
    ) -> tuple[list[dict], list]:
        """根据传递的工作流列表进行处理和校验"""
        workflows = []
        if not origin_workflows:
            return workflows, []
        
        # 将 origin_workflows 转换为 UUID 列表
        workflow_ids = [UUID(wf_id) if isinstance(wf_id, str) else wf_id for wf_id in origin_workflows]
        
        result = await db.execute(
            select(Workflow).where(
                Workflow.id.in_(workflow_ids),
                Workflow.status == WorkflowStatus.PUBLISHED,
            )
        )
        workflow_records = result.scalars().all()
        workflow_dict = {str(wf_record.id): wf_record for wf_record in workflow_records}
        workflow_sets = set(workflow_dict.keys())

        # 计算存在的工作流id列表
        validate_workflows = [str(wf_id) for wf_id in origin_workflows if str(wf_id) in workflow_sets]

        # 循环获取工作流数据
        for workflow_id in validate_workflows:
            workflow = workflow_dict.get(workflow_id)
            if workflow:
                workflows.append({
                    "id": str(workflow.id),
                    "name": workflow.name,
                    "icon": workflow.icon,
                    "description": workflow.description,
                })

        return workflows, validate_workflows

