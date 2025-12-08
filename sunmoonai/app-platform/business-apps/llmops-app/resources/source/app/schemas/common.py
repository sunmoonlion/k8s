#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps 通用 Schema - 分页等通用结构
"""
from typing import Optional, Generic, TypeVar, List
from pydantic import BaseModel, Field, field_validator

T = TypeVar('T')


class PaginatorReq(BaseModel):
    """分页请求基础类"""
    current_page: int = Field(default=1, ge=1, le=9999, description="当前页数")
    page_size: int = Field(default=20, ge=1, le=50, description="每页条数")
    
    @property
    def page(self) -> int:
        """兼容性：返回 current_page - 1（用于 offset 计算）"""
        return self.current_page - 1
    
    @property
    def offset(self) -> int:
        """计算 offset"""
        return self.page * self.page_size


class Paginator(BaseModel):
    """分页器响应"""
    total_page: int = Field(description="总页数")
    total_record: int = Field(description="总条数")
    current_page: int = Field(description="当前页数")
    page_size: int = Field(description="每页条数")


class PageModel(BaseModel, Generic[T]):
    """分页响应模型"""
    list: List[T] = Field(description="数据列表")
    paginator: Paginator = Field(description="分页信息")

