# ADR-0005：RAGFlow 定位为可重建的派生系统

- 状态：已接受
- 日期：2026-06-11

## 背景

RAGFlow 提供文档解析、分块、向量索引和知识检索，但其内部 MinIO、MySQL、Elasticsearch 和 Valkey 数据结构属于具体产品实现。让 RAGFlow 保存唯一原文会使平台无法独立治理、迁移和恢复资讯。

## 决策

`info-app` 保存资讯原始证据、规范化内容和历史版本。`knowledge-app` 通过统一
接口管理文档投递、映射、处理状态和重建；RAGFlow 接收受控副本，并保存产品内部
状态、分块和检索索引。

`info-app` 记录领域分发状态，`knowledge-app` 记录 RAGFlow Dataset、Document、
同步版本、内容哈希和处理状态，并提供全量重建及增量对账。

Data Platform 建设 S3 对象存储和 Elasticsearch 后，RAGFlow 仍继续使用其自带 MinIO 和 Elasticsearch：

- 平台 S3 对象存储保存 Info App 原始主档和领域处理产物。
- 平台 Elasticsearch 保存 Info App 领域全文索引。
- RAGFlow MinIO 保存知识处理文档副本。
- RAGFlow Elasticsearch 保存分块、Embedding、向量和内部检索数据。

两组设施不共享 Bucket、Index、Alias 或写入账号。RAGFlow 不获得 Info App 原始主档 Bucket 的永久访问权限，由 Info App 主动创建并分发受控副本。

## 结果

- 删除或替换 RAGFlow 不会丢失资讯主档。
- RAGFlow 故障不阻断资讯接收和保存。
- 未来可以并行分发到其他搜索或知识引擎。
- RAGFlow 可以连同其 MinIO、Elasticsearch、MySQL 和 Valkey 整体升级或重建。
- 其他 App 依赖 `knowledge-app` 的公开契约，不直接绑定 RAGFlow 私有 API。
- RAGFlow 解析和向量索引负载不会与平台领域存储形成同一故障和容量边界。
- 同一内容会存在领域主档、领域派生产物和 RAGFlow 处理副本，这是有意的数据分级。
