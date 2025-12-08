#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps App Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.schemas.llmops.app_schema import (
    CreateAppReq,
    UpdateAppReq,
    GetAppsWithPageReq,
    GetAppsWithPageResp,
    GetAppResp,
    GetPublishHistoriesWithPageReq,
    GetPublishHistoriesWithPageResp,
    FallbackHistoryToDraftReq,
    UpdateDebugConversationSummaryReq,
    DebugChatReq,
    GetDebugConversationMessagesWithPageReq,
    GetDebugConversationMessagesWithPageResp,
)
from app.core.response import success_json, success_message, compact_generate_response
from app.core.service_factories import get_app_service
from app.services.llmops.app_service import AppService

router = APIRouter()


@router.post("/", response_model=dict)
async def create_app(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    req: CreateAppReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """调用服务创建新的APP记录"""
    # 1.调用服务创建应用信息
    app = await app_service.create_app(
        db,
        name=req.name,
        icon=req.icon,
        description=req.description,
        user=current_user
    )

    # 2.返回创建成功响应提示
    return success_json({"id": str(app.id)})


@router.get("/{app_id}", response_model=GetAppResp)
async def get_app(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """获取指定的应用基础信息"""
    app = await app_service.get_app(db, app_id, current_user)
    return GetAppResp(
        id=app.id,
        name=app.name,
        icon=app.icon,
        description=app.description,
        status=app.status,
        app_config_id=str(app.app_config_id) if app.app_config_id else None,
        draft_app_config_id=str(app.draft_app_config_id) if app.draft_app_config_id else None,
        debug_conversation_id=str(app.debug_conversation_id) if app.debug_conversation_id else None,
        token=app.token or "",
        updated_at=int(app.updated_at.timestamp()) if app.updated_at else 0,
        created_at=int(app.created_at.timestamp()) if app.created_at else 0,
    )


@router.post("/{app_id}", response_model=dict)
async def update_app(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    req: UpdateAppReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的信息更新指定的应用"""
    # 1.调用服务更新数据
    await app_service.update_app(
        db,
        app_id,
        name=req.name,
        icon=req.icon,
        description=req.description,
        user=current_user
    )

    return success_message("修改Agent智能体应用成功")


@router.post("/{app_id}/copy", response_model=dict)
async def copy_app(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id快速拷贝该应用"""
    app = await app_service.copy_app(db, app_id, current_user)
    return success_json({"id": str(app.id)})


@router.post("/{app_id}/delete", response_model=dict)
async def delete_app(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的信息删除指定的应用"""
    await app_service.delete_app(db, app_id, current_user)
    return success_message("删除Agent智能体应用成功")


@router.get("/", response_model=dict)
async def get_apps_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    search_word: str | None = Query(None),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """获取当前登录用户的应用分页列表数据"""
    # 1.构建请求对象
    req = GetAppsWithPageReq(
        current_page=current_page,
        page_size=page_size,
        search_word=search_word,
    )

    # 2.调用服务获取列表数据以及分页器
    apps, paginator = await app_service.get_apps_with_page(db, req, current_user)

    # 3.构建响应结构并返回
    resp_list = [
        GetAppsWithPageResp(
            id=app.id,
            name=app.name,
            icon=app.icon,
            description=app.description,
            status=app.status,
            updated_at=int(app.updated_at.timestamp()) if app.updated_at else 0,
            created_at=int(app.created_at.timestamp()) if app.created_at else 0,
        ) for app in apps
    ]

    return success_json({
        "list": [app.model_dump() for app in resp_list],
        "paginator": paginator,
    })


@router.get("/{app_id}/draft-app-config", response_model=dict)
async def get_draft_app_config(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id获取应用的最新草稿配置"""
    draft_config = await app_service.get_draft_app_config(db, app_id, current_user)
    return success_json(draft_config)


@router.post("/{app_id}/draft-app-config", response_model=dict)
async def update_draft_app_config(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    draft_app_config: dict = Body(...),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id+草稿配置更新应用的最新草稿配置"""
    # 1.调用服务更新应用的草稿配置
    await app_service.update_draft_app_config(
        db,
        app_id,
        draft_app_config,
        current_user
    )

    return success_message("更新应用草稿配置成功")


@router.post("/{app_id}/publish", response_model=dict)
async def publish(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id发布/更新特定的草稿配置信息"""
    await app_service.publish_draft_app_config(db, app_id, current_user)
    return success_message("发布/更新应用配置成功")


@router.post("/{app_id}/cancel-publish", response_model=dict)
async def cancel_publish(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id，取消发布指定的应用配置信息"""
    await app_service.cancel_publish_app_config(db, app_id, current_user)
    return success_message("取消发布应用配置成功")


@router.post("/{app_id}/fallback-history", response_model=dict)
async def fallback_history_to_draft(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    req: FallbackHistoryToDraftReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id+历史配置版本id，退回指定版本到草稿中"""
    # 1.调用服务回退指定版本到草稿
    await app_service.fallback_history_to_draft(
        db,
        app_id,
        req.app_config_version_id,
        current_user
    )

    return success_message("回退历史配置至草稿成功")


@router.get("/{app_id}/publish-histories", response_model=dict)
async def get_publish_histories_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id，获取应用发布历史列表"""
    # 1.构建请求对象
    req = GetPublishHistoriesWithPageReq(
        current_page=current_page,
        page_size=page_size,
    )

    # 2.调用服务获取分页列表数据
    app_config_versions, paginator = await app_service.get_publish_histories_with_page(
        db, app_id, req, current_user
    )

    # 3.创建响应结构并返回
    resp_list = [
        GetPublishHistoriesWithPageResp(
            id=version.id,
            version=version.version,
            config_type=version.config_type,
            updated_at=int(version.updated_at.timestamp()) if version.updated_at else 0,
            created_at=int(version.created_at.timestamp()) if version.created_at else 0,
        ) for version in app_config_versions
    ]

    return success_json({
        "list": [version.model_dump() for version in resp_list],
        "paginator": paginator,
    })


@router.get("/{app_id}/summary", response_model=dict)
async def get_debug_conversation_summary(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id获取调试会话长期记忆"""
    summary = await app_service.get_debug_conversation_summary(db, app_id, current_user)
    return success_json({"summary": summary})


@router.post("/{app_id}/summary", response_model=dict)
async def update_debug_conversation_summary(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    req: UpdateDebugConversationSummaryReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id+摘要信息更新调试会话长期记忆"""
    # 1.调用服务更新调试会话长期记忆
    await app_service.update_debug_conversation_summary(
        db,
        app_id,
        req.summary,
        current_user
    )

    return success_message("更新AI应用长期记忆成功")


@router.post("/{app_id}/conversations/delete-debug-conversation", response_model=dict)
async def delete_debug_conversation(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id，清空该应用的调试会话记录"""
    await app_service.delete_debug_conversation(db, app_id, current_user)
    return success_message("清空应用调试会话记录成功")


@router.post("/{app_id}/conversations", response_model=Any)
async def debug_chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    req: DebugChatReq,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id+query，发起调试对话"""
    # 1.调用服务发起会话调试
    response = await app_service.debug_chat(
        db,
        app_id,
        query=req.query,
        image_urls=req.image_urls,
        user=current_user
    )

    # 2.返回流式响应或普通响应
    return compact_generate_response(response)


@router.post("/{app_id}/conversations/tasks/{task_id}/stop", response_model=dict)
async def stop_debug_chat(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    task_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id+任务id停止某个应用的指定调试会话"""
    await app_service.stop_debug_chat(db, app_id, task_id, current_user)
    return success_message("停止应用调试会话成功")


@router.get("/{app_id}/conversations/messages", response_model=dict)
async def get_debug_conversation_messages_with_page(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_page: int = Query(1, ge=1, le=9999),
    page_size: int = Query(20, ge=1, le=50),
    created_at: int = Query(0, ge=0),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id，获取该应用的调试会话分页列表记录"""
    # 1.构建请求对象
    req = GetDebugConversationMessagesWithPageReq(
        current_page=current_page,
        page_size=page_size,
        created_at=created_at,
    )

    # 2.调用服务获取数据
    messages, paginator = await app_service.get_debug_conversation_messages_with_page(
        db, app_id, req, current_user
    )

    # 3.创建响应结构
    resp_list = [
        GetDebugConversationMessagesWithPageResp(
            id=msg.id,
            conversation_id=msg.conversation_id,
            query=msg.query,
            image_urls=msg.image_urls or [],
            answer=msg.answer or "",
            total_token_count=msg.total_token_count or 0,
            latency=msg.latency or 0.0,
            agent_thoughts=[],  # TODO: 加载 agent_thoughts
            created_at=int(msg.created_at.timestamp()) if msg.created_at else 0,
        ) for msg in messages
    ]

    return success_json({
        "list": [msg.model_dump() for msg in resp_list],
        "paginator": paginator,
    })


@router.get("/{app_id}/published-config", response_model=dict)
async def get_published_config(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id获取应用的发布配置信息"""
    published_config = await app_service.get_published_config(db, app_id, current_user)
    return success_json(published_config)


@router.post("/{app_id}/published-config/regenerate-web-app-token", response_model=dict)
async def regenerate_web_app_token(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    app_id: UUID,
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    app_service: Annotated[AppService, Depends(get_app_service)],
) -> Any:
    """根据传递的应用id重新生成WebApp凭证标识"""
    token = await app_service.regenerate_web_app_token(db, app_id, current_user)
    return success_json({"token": token})


@router.get("/ping", response_model=dict)
async def ping() -> Any:
    """健康检查"""
    return success_json({"pong": "success"})

