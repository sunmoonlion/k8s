#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Audio Service - 从 imooc-llmops 迁移
语音服务（部分保持同步，因为 OpenAI 客户端是同步的）
Account 已改为 User，account_id 已改为 user_id
"""
import base64
import json
import logging
import os
from dataclasses import dataclass
from io import BytesIO
from typing import Generator, Union
from uuid import UUID

from injector import inject
from openai import OpenAI
from sqlalchemy.ext.asyncio import AsyncSession
import asyncio

# Removed: user model is in auth service User
from app.models.postgresql.llmops_llmops_conversation import Message
from app.models.postgresql.llmops_llmops_app import LLMOpsApp
from app.services.llmops.base_service import BaseService
from app.services.llmops.app_service import AppService
from app.core.exceptions import NotFoundException, FailException

# 导入 Entity
from app.core.llmops.entity.app_entity import AppStatus
from app.core.llmops.entity.conversation_entity import InvokeFrom


@inject
@dataclass
class AudioService(BaseService):
    """语音服务，涵盖语音转文本、消息流式输出语音（部分保持同步）"""
    app_service: AppService

    def audio_to_text(self, audio_file: bytes, filename: str = "recording.wav") -> str:
        """将传递的语音转换成文本（保持同步，因为 OpenAI 客户端是同步的）"""
        # 1.提取音频文件，并将音频文件转换成FileContent类型
        audio_file_obj = BytesIO(audio_file)
        audio_file_obj.name = filename

        # 2.创建OpenAI客户端，并调用whisper服务将音频转换成文字
        client = self._get_openai_client()
        transcription = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file_obj,
        )

        # 3.返回识别的文字内容
        return transcription.text

    async def message_to_audio(
        self,
        db: AsyncSession,
        message_id: UUID,
        user: User
    ) -> Generator:
        """将消息转换成流式时间输出语音"""
        # 1.根据传递的消息id获取消息并校验权限
        message = await self.get(db, Message, message_id)
        if not message or message.is_deleted or message.answer.strip() == "" or message.user_id != user.id:
            raise NotFoundException("该消息不存在，请核实后重试")

        # 2.校验消息归属的会话状态是否正常
        # TODO: 获取 conversation
        # conversation = message.conversation
        # if conversation is None or conversation.is_deleted or conversation.user_id != user.id:
        #     raise NotFoundException("该消息会话不存在，请核实后重试")
        
        # 临时处理
        conversation_id = message.conversation_id
        # TODO: 获取 conversation

        # 3.定义文本转语音启动配置、音色，默认为开启+echo音色
        enable = True
        voice = "echo"

        # 4.根据会话信息获取会话归属的应用
        if message.invoke_from in [InvokeFrom.WEB_APP, InvokeFrom.DEBUGGER]:
            app = await self.get(db, LLMOpsApp, message.app_id)
            if not app:
                raise NotFoundException("该消息会话归属应用不存在或校验失败，请核实后重试")
            if message.invoke_from == InvokeFrom.DEBUGGER and app.user_id != user.id:
                raise NotFoundException("该消息会话归属的应用不存在或校验失败，请核实后重试")
            if message.invoke_from == InvokeFrom.WEB_APP and app.status != AppStatus.PUBLISHED:
                raise NotFoundException("该消息会话归属的应用未发布，请核实后重试")

            # TODO: 获取 app_config
            # app_config: Union[AppConfig, AppConfigVersion] = (
            #     app.draft_app_config
            #     if message.invoke_from == InvokeFrom.DEBUGGER
            #     else app.app_config
            # )
            # text_to_speech = app_config.text_to_speech
            # enable = text_to_speech.get("enable", False)
            # voice = text_to_speech.get("voice", "echo")
        elif message.invoke_from == InvokeFrom.SERVICE_API:
            raise NotFoundException("开放API消息不支持文本转语音服务")

        # 5.根据状态获取不同的配置并判断是否开启文字转语音
        if enable is False:
            raise FailException("该应用未开启文字转语音功能，请核实后重试")

        # 6.调用tts服务将消息answer转换成流式事件输出语音（同步操作）
        try:
            client = self._get_openai_client()
            response = client.audio.speech.with_streaming_response.create(
                model="tts-1",
                voice=voice,
                response_format="mp3",
                input=message.answer.strip(),
            )
        except Exception as error:
            logging.error("文字转语音失败: %(error)s", {"error": error}, exc_info=True)
            raise FailException("文字转语音失败，请稍后重试")

        # 7.定义内部函数实现流式事件输出
        def tts() -> Generator:
            """内部函数，从response中获取音频流式事件输出数据"""
            common_data = {
                "conversation_id": str(conversation_id),
                "message_id": str(message.id),
                "audio": "",
            }
            for chunk in response.__enter__().iter_bytes(1024):
                data = {**common_data, "audio": base64.b64encode(chunk).decode("utf-8")}
                yield f"event: tts_message\ndata: {json.dumps(data)}\n\n"
            yield f"event: tts_end\ndata: {json.dumps(common_data)}\n\n"

        # 8.调用tts函数流式事件输出语音数据
        return tts()

    @classmethod
    def _get_openai_client(cls) -> OpenAI:
        """获取OpenAI客户端"""
        return OpenAI(
            api_key=os.environ.get("OPENAI_API_KEY"),
            base_url=os.environ.get("OPENAI_API_BASE"),
        )

