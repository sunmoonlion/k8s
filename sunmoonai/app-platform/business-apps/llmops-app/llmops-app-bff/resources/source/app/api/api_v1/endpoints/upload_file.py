#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Upload File Endpoints - 从 imooc-llmops 迁移
已转换为 FastAPI APIRouter
"""
from typing import Annotated, Any

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.api import deps
from app.core.response import success_json
from app.core.service_factories import get_cos_service
from app.services.llmops.cos_service import CosService
from app.core.llmops.entity.upload_file_entity import ALLOWED_DOCUMENT_EXTENSION, ALLOWED_IMAGE_EXTENSION

router = APIRouter()

# 文件大小限制：15MB
MAX_FILE_SIZE = 15 * 1024 * 1024


@router.post("/file", response_model=dict)
async def upload_file(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    file: UploadFile = File(...),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    cos_service: Annotated[CosService, Depends(get_cos_service)],
) -> Any:
    """上传文件/文档"""
    # 1.验证文件扩展名
    filename = file.filename or ""
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in ALLOWED_DOCUMENT_EXTENSION:
        raise HTTPException(
            status_code=400,
            detail=f"仅允许上传{'/'.join(ALLOWED_DOCUMENT_EXTENSION)}文件"
        )
    
    # 2.读取文件内容
    file_content = await file.read()
    
    # 3.验证文件大小
    if len(file_content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail="上传文件最大不能超过15MB"
        )
    
    # 4.上传文件到COS
    upload_file_record = await cos_service.upload_file(
        db,
        file_content=file_content,
        filename=filename,
        mime_type=file.content_type or "",
        only_image=False,
        user=current_user
    )
    
    # 5.构建响应
    return success_json({
        "id": str(upload_file_record.id),
        "user_id": str(upload_file_record.user_id),
        "name": upload_file_record.name,
        "key": upload_file_record.key or "",
        "size": upload_file_record.size or 0,
        "extension": upload_file_record.extension or "",
        "mime_type": upload_file_record.mime_type or "",
        "created_at": int(upload_file_record.created_at.timestamp()) if upload_file_record.created_at else 0,
    })


@router.post("/image", response_model=dict)
async def upload_image(
    *,
    db: Annotated[AsyncSession, Depends(deps.get_db)],
    file: UploadFile = File(...),
    current_user: Annotated[models.User, Depends(deps.get_current_active_user)],
    cos_service: Annotated[CosService, Depends(get_cos_service)],
) -> Any:
    """上传图片"""
    # 1.验证文件扩展名
    filename = file.filename or ""
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in ALLOWED_IMAGE_EXTENSION:
        raise HTTPException(
            status_code=400,
            detail=f"仅允许上传{'/'.join(ALLOWED_IMAGE_EXTENSION)}文件"
        )
    
    # 2.读取文件内容
    file_content = await file.read()
    
    # 3.验证文件大小
    if len(file_content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail="上传图片最大不能超过15MB"
        )
    
    # 4.上传图片到COS
    upload_file_record = await cos_service.upload_file(
        db,
        file_content=file_content,
        filename=filename,
        mime_type=file.content_type or "",
        only_image=True,
        user=current_user
    )
    
    # 5.获取图片的实际URL地址
    image_url = cos_service.get_file_url(upload_file_record.key)
    
    # 6.构建响应
    return success_json({
        "image_url": image_url
    })

