#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Document Schema - 从 imooc-llmops 迁移
已转换为 Pydantic
"""
import uuid
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional
from uuid import UUID

from app.schemas.llmops.common import PaginatorReq

# 导入 Entity
from app.core.llmops.entity.dataset_entity import ProcessType, DEFAULT_PROCESS_RULE


class CreateDocumentsReq(BaseModel):
    """创建/新增文档列表请求"""
    upload_file_ids: list[str] = Field(..., description="上传文件id列表")
    process_type: str = Field(..., description="文档处理类型")
    rule: dict = Field(..., description="处理规则")

    @field_validator("upload_file_ids")
    @classmethod
    def validate_upload_file_ids(cls, v: list[str]) -> list[str]:
        """校验上传文件id列表"""
        # 1.校验数据的长度，最长不能超过10条记录
        if len(v) == 0 or len(v) > 10:
            raise ValueError("新增的文档数范围在1-10")

        # 2.循环校验id是否为uuid
        for upload_file_id in v:
            try:
                uuid.UUID(upload_file_id)
            except Exception:
                raise ValueError(f"文件id {upload_file_id} 的格式必须是UUID")

        # 3.删除重复数据并更新
        return list(dict.fromkeys(v))

    @model_validator(mode="after")
    def validate_rule(self) -> "CreateDocumentsReq":
        """校验上传处理规则"""
        # 1.校验处理模式，如果为自动，则为rule赋值默认值
        if self.process_type == ProcessType.AUTOMATIC:
            self.rule = DEFAULT_PROCESS_RULE["rule"]
        else:
            # 2.检测自定义处理类型下是否传递了rule
            if not isinstance(self.rule, dict) or len(self.rule) == 0:
                raise ValueError("自定义处理模式下，rule不能为空")

            # 3.校验pre_process_rules
            if "pre_process_rules" not in self.rule or not isinstance(self.rule["pre_process_rules"], list):
                raise ValueError("pre_process_rules必须为列表")

            # 4.提取pre_process_rules中唯一的处理规则
            unique_pre_process_rule_dict = {}
            for pre_process_rule in self.rule["pre_process_rules"]:
                # 5.校验id参数
                if (
                    "id" not in pre_process_rule
                    or pre_process_rule["id"] not in ["remove_extra_space", "remove_url_and_email"]
                ):
                    raise ValueError("预处理id格式错误")

                # 6.校验enabled参数
                if "enabled" not in pre_process_rule or not isinstance(pre_process_rule["enabled"], bool):
                    raise ValueError("预处理enabled格式错误")

                # 7.将数据添加到唯一字典中
                unique_pre_process_rule_dict[pre_process_rule["id"]] = {
                    "id": pre_process_rule["id"],
                    "enabled": pre_process_rule["enabled"],
                }

            # 8.判断一下是否传递了两个处理规则
            if len(unique_pre_process_rule_dict) != 2:
                raise ValueError("预处理规则格式错误，请重试尝试")

            # 9.将处理后的数据转换成列表并覆盖与处理规则
            self.rule["pre_process_rules"] = list(unique_pre_process_rule_dict.values())

            # 10.校验分段参数segment
            if "segment" not in self.rule or not isinstance(self.rule["segment"], dict):
                raise ValueError("分段设置不能为空且为字典")

            # 11.校验分隔符separators
            if "separators" not in self.rule["segment"] or not isinstance(self.rule["segment"]["separators"], list):
                raise ValueError("分隔符列表不能为空且为列表")
            for separator in self.rule["segment"]["separators"]:
                if not isinstance(separator, str):
                    raise ValueError("分隔符列表元素类型错误")
            if len(self.rule["segment"]["separators"]) == 0:
                raise ValueError("分隔符列表不能为空列表")

            # 12.校验分块大小chunk_size
            if "chunk_size" not in self.rule["segment"] or not isinstance(self.rule["segment"]["chunk_size"], int):
                raise ValueError("分割块大小不能为空且为整数")
            if self.rule["segment"]["chunk_size"] < 100 or self.rule["segment"]["chunk_size"] > 1000:
                raise ValueError("分割块大小在100-1000")

            # 13.校验块重叠大小chunk_overlap
            chunk_size = self.rule["segment"]["chunk_size"]
            if "chunk_overlap" not in self.rule["segment"] or not isinstance(self.rule["segment"]["chunk_overlap"], int):
                raise ValueError("块重叠大小不能为空且为整数")
            if not (0 <= self.rule["segment"]["chunk_overlap"] <= chunk_size * 0.5):
                raise ValueError(f"块重叠大小在0-{int(chunk_size * 0.5)}")

            # 14.更新并提出多余数据
            self.rule = {
                "pre_process_rules": self.rule["pre_process_rules"],
                "segment": {
                    "separators": self.rule["segment"]["separators"],
                    "chunk_size": self.rule["segment"]["chunk_size"],
                    "chunk_overlap": self.rule["segment"]["chunk_overlap"],
                }
            }

        return self


class DocumentItemResp(BaseModel):
    """文档项响应结构"""
    id: UUID
    name: str
    status: str
    created_at: int


class CreateDocumentsResp(BaseModel):
    """创建文档列表响应结构"""
    documents: list[DocumentItemResp] = []
    batch: str = ""


class GetDocumentResp(BaseModel):
    """获取文档基础信息响应结构"""
    id: UUID
    dataset_id: UUID
    name: str
    segment_count: int = 0
    character_count: int = 0
    hit_count: int = 0
    position: int = 0
    enabled: bool = False
    disabled_at: Optional[int] = None
    status: str = ""
    error: Optional[str] = None
    updated_at: int
    created_at: int


class UpdateDocumentNameReq(BaseModel):
    """更新文档名称/基础信息请求"""
    name: str = Field(..., max_length=100, description="文档名称，长度不能超过100")


class GetDocumentsWithPageReq(PaginatorReq):
    """获取文档分页列表请求"""
    search_word: Optional[str] = Field(None, description="搜索关键词")


class GetDocumentsWithPageResp(BaseModel):
    """获取文档分页列表响应结构"""
    id: UUID
    name: str
    character_count: int = 0
    hit_count: int = 0
    position: int = 0
    enabled: bool = False
    disabled_at: Optional[int] = None
    status: str = ""
    error: Optional[str] = None
    updated_at: int
    created_at: int


class UpdateDocumentEnabledReq(BaseModel):
    """更新文档启用状态请求"""
    enabled: bool = Field(..., description="是否启用")

