#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
LLMOps Vector Database Service - 从 imooc-llmops 迁移
向量数据库服务（部分保持同步，因为 Weaviate 客户端是同步的）
"""
from dataclasses import dataclass
from typing import Any

from injector import inject
from langchain_core.documents import Document
from langchain_core.vectorstores import VectorStoreRetriever
from langchain_weaviate import WeaviateVectorStore
from weaviate.collections import Collection

from app.services.llmops.embeddings_service import EmbeddingsService

# 向量数据库的集合名字
COLLECTION_NAME = "Dataset"


@inject
@dataclass
class VectorDatabaseService:
    """向量数据库服务（部分保持同步）"""
    embeddings_service: EmbeddingsService

    def __init__(self, embeddings_service: EmbeddingsService):
        """初始化向量数据库服务"""
        from app.core.extensions import get_weaviate_client
        self.weaviate_client = get_weaviate_client()
        self.embeddings_service = embeddings_service

    @property
    def vector_store(self) -> WeaviateVectorStore:
        """获取向量存储"""
        return WeaviateVectorStore(
            client=self.weaviate_client,
            index_name=COLLECTION_NAME,
            text_key="text",
            embedding=self.embeddings_service.cache_backed_embeddings,
        )

    def add_documents(self, documents: list[Document], **kwargs: Any):
        """往向量数据库中新增文档（保持同步，因为 Weaviate 客户端是同步的）"""
        self.vector_store.add_documents(documents, **kwargs)

    def get_retriever(self) -> VectorStoreRetriever:
        """获取检索器"""
        return self.vector_store.as_retriever()

    @property
    def collection(self) -> Collection:
        """获取 Weaviate 集合"""
        return self.weaviate_client.collections.get(COLLECTION_NAME)

