#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
异步基础服务，完善数据库的基础增删改查功能，简化代码
"""
from typing import Any, Optional, Type

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.postgresql.base_class import Base


class BaseService:
    """异步基础服务，完善数据库的基础增删改查功能，简化代码"""

    async def create(self, db: AsyncSession, model: Type[Base], **kwargs) -> Any:
        """根据传递的模型类+键值对信息创建数据库记录"""
        model_instance = model(**kwargs)
        db.add(model_instance)
        await db.commit()
        await db.refresh(model_instance)
        return model_instance

    async def delete(self, db: AsyncSession, model_instance: Any) -> Any:
        """根据传递的模型实例删除数据库记录"""
        db.delete(model_instance)
        await db.commit()
        return model_instance

    async def update(self, db: AsyncSession, model_instance: Any, **kwargs) -> Any:
        """根据传递的模型实例+键值对信息更新数据库记录"""
        for field, value in kwargs.items():
            if hasattr(model_instance, field):
                setattr(model_instance, field, value)
            else:
                raise ValueError(f"模型 {type(model_instance).__name__} 没有字段 {field}")
        db.add(model_instance)
        await db.commit()
        await db.refresh(model_instance)
        return model_instance

    async def get(self, db: AsyncSession, model: Type[Base], primary_key: Any) -> Optional[Any]:
        """根据传递的模型类+主键的信息获取唯一数据"""
        result = await db.execute(select(model).where(model.id == primary_key))
        return result.scalar_one_or_none()


