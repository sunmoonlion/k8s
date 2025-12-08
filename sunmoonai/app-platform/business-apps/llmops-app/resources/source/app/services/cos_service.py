#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps COS Service - 从 imooc-llmops 迁移
腾讯云COS对象存储服务（保持同步，因为 COS 客户端是同步的）
Account 已改为 User，account_id 已改为 user_id
"""
import hashlib
import uuid
from dataclasses import dataclass
from datetime import datetime

from injector import inject
from qcloud_cos import CosS3Client, CosConfig
from sqlalchemy.ext.asyncio import AsyncSession

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_upload_file import UploadFile
from app.services.llmops.upload_file_service import UploadFileService
from app.core.exceptions import FailException
from app.core.config import settings

# 导入 Entity
from app.core.llmops.entity.upload_file_entity import ALLOWED_IMAGE_EXTENSION, ALLOWED_DOCUMENT_EXTENSION


@inject
@dataclass
class CosService:
    """腾讯云cos对象存储服务（保持同步）"""
    upload_file_service: UploadFileService

    async def upload_file(
        self,
        db: AsyncSession,
        file_content: bytes,
        filename: str,
        mime_type: str,
        only_image: bool,
        user: User
    ) -> UploadFile:
        """上传文件到腾讯云cos对象存储，上传后返回文件的信息"""
        # 1.提取文件扩展名并检测是否可以上传
        extension = filename.rsplit(".", 1)[-1] if "." in filename else ""
        if extension.lower() not in (ALLOWED_IMAGE_EXTENSION + ALLOWED_DOCUMENT_EXTENSION):
            raise FailException(f"该.{extension}扩展的文件不允许上传")
        elif only_image and extension not in ALLOWED_IMAGE_EXTENSION:
            raise FailException(f"该.{extension}扩展的文件不支持上传，请上传正确的图片")

        # 2.获取客户端+存储桶名字
        client = self.get_client()
        bucket = self.get_bucket()

        # 3.生成一个随机的名字
        random_filename = str(uuid.uuid4()) + "." + extension
        now = datetime.now()
        upload_filename = f"{now.year}/{now.month:02d}/{now.day:02d}/{random_filename}"

        # 4.将数据上传到cos存储桶中（同步操作，使用 asyncio.to_thread）
        import asyncio
        try:
            await asyncio.to_thread(
                client.put_object,
                bucket,
                file_content,
                upload_filename
            )
        except Exception as e:
            raise FailException("上传文件失败，请稍后重试")

        # 5.创建upload_file记录
        return await self.upload_file_service.create_upload_file(
            db,
            user_id=user.id,
            name=filename,
            key=upload_filename,
            size=len(file_content),
            extension=extension,
            mime_type=mime_type,
            hash=hashlib.sha3_256(file_content).hexdigest(),
        )

    def download_file(self, key: str, target_file_path: str):
        """下载cos云端的文件到本地的指定路径（保持同步）"""
        client = self.get_client()
        bucket = self.get_bucket()
        client.download_file(bucket, key, target_file_path)

    @classmethod
    def get_file_url(cls, key: str) -> str:
        """根据传递的cos云端key获取图片的实际URL地址"""
        cos_domain = settings.COS_DOMAIN

        if not cos_domain:
            bucket = settings.COS_BUCKET
            scheme = settings.COS_SCHEME
            region = settings.COS_REGION
            if bucket and region:
                cos_domain = f"{scheme}://{bucket}.cos.{region}.myqcloud.com"
            else:
                raise FailException("COS配置不完整，无法生成文件URL")

        return f"{cos_domain}/{key}"

    @classmethod
    def get_client(cls) -> CosS3Client:
        """获取腾讯云cos对象存储客户端"""
        if not all([settings.COS_REGION, settings.COS_SECRET_ID, settings.COS_SECRET_KEY]):
            raise FailException("COS配置不完整，请检查环境变量")
        
        conf = CosConfig(
            Region=settings.COS_REGION,
            SecretId=settings.COS_SECRET_ID,
            SecretKey=settings.COS_SECRET_KEY,
            Token=None,
            Scheme=settings.COS_SCHEME
        )
        return CosS3Client(conf)

    @classmethod
    def get_bucket(cls) -> str:
        """获取存储桶的名字"""
        if not settings.COS_BUCKET:
            raise FailException("COS_BUCKET配置缺失")
        return settings.COS_BUCKET

