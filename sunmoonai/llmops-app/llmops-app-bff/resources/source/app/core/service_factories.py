#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Service 工厂函数 - 统一管理所有 Service 的依赖注入
"""
from app.core.dependency_injection import create_service_factory

# 导入所有 Service
from app.services.llmops.app_service import AppService
from app.services.llmops.dataset_service import DatasetService
from app.services.llmops.conversation_service import ConversationService
from app.services.llmops.document_service import DocumentService
from app.services.llmops.segment_service import SegmentService
from app.services.llmops.workflow_service import WorkflowService
from app.services.llmops.api_key_service import ApiKeyService
from app.services.llmops.api_tool_service import ApiToolService
from app.services.llmops.upload_file_service import UploadFileService
from app.services.llmops.cos_service import CosService
from app.services.llmops.account_service import AccountService
from app.services.llmops.oauth_service import OAuthService
from app.services.llmops.ai_service import AIService
from app.services.llmops.audio_service import AudioService
from app.services.llmops.builtin_app_service import BuiltinAppService
from app.services.llmops.builtin_tool_service import BuiltinToolService
from app.services.llmops.assistant_agent_service import AssistantAgentService
from app.services.llmops.analysis_service import AnalysisService
from app.services.llmops.language_model_service import LanguageModelService
from app.services.llmops.platform_service import PlatformService
from app.services.llmops.wechat_service import WechatService
from app.services.llmops.web_app_service import WebAppService
from app.services.llmops.openapi_service import OpenAPIService

# 创建所有 Service 的工厂函数
get_app_service = create_service_factory(AppService)
get_dataset_service = create_service_factory(DatasetService)
get_conversation_service = create_service_factory(ConversationService)
get_document_service = create_service_factory(DocumentService)
get_segment_service = create_service_factory(SegmentService)
get_workflow_service = create_service_factory(WorkflowService)
get_api_key_service = create_service_factory(ApiKeyService)
get_api_tool_service = create_service_factory(ApiToolService)
get_upload_file_service = create_service_factory(UploadFileService)
get_cos_service = create_service_factory(CosService)
get_account_service = create_service_factory(AccountService)
get_oauth_service = create_service_factory(OAuthService)
get_ai_service = create_service_factory(AIService)
get_audio_service = create_service_factory(AudioService)
get_builtin_app_service = create_service_factory(BuiltinAppService)
get_builtin_tool_service = create_service_factory(BuiltinToolService)
get_assistant_agent_service = create_service_factory(AssistantAgentService)
get_analysis_service = create_service_factory(AnalysisService)
get_language_model_service = create_service_factory(LanguageModelService)
get_platform_service = create_service_factory(PlatformService)
get_wechat_service = create_service_factory(WechatService)
get_web_app_service = create_service_factory(WebAppService)
get_openapi_service = create_service_factory(OpenAPIService)

