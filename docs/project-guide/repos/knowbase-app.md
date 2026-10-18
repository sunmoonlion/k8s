# knowbase-app：加工入库

> 最后更新：2026-10-16 ｜ 按代码现状重写 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

把 knowfeed 登记来的数据集与文档加工成可查询的形态：数据集目录、口径、语义层，文档入库与检索。属于**数据线**：是我们自己的内部工具，**不作为用户专家的数据源**（`C-L2`）——现在沙箱仍经 MCP 接它，工作台对用户开放前改为默认不接（[0026](../../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)「四」）。2026-10-15 由 `knowledge-app` 改名而来，数据从空库开始。路由与表名里的 `knowledge` 是「知识」这个领域词，不是旧应用名，保留。

## 领域

| 块 | 代码 | 表 |
| --- | --- | --- |
| 数据集目录与查询 | `domain/datasets.py`、`dataset_view.py`；服务 `dataset_catalog`、`dataset_pages`、`dataset_query`、`dataset_registry_view` | `knowledge_dataset` |
| 语义层 | `domain/semantic.py`；服务 `semantic_model`、`semantic_metrics`、`semantic_query`、`semantic_guard`（WrenAI 只用引擎、嵌在工具后面，`C-A8`） | — |
| 入库 | 服务 `ingestion_authorization`、`ingestion_execution`、`knowledge_ingestion_service` | `knowledge_ingestion_job`、`knowledge_document`、`knowledge_document_version` |
| 检索与 RAGFlow | 服务 `knowledge_retrieval_service`、`provider_delivery` | `knowledge_provider_operation` |
| 投递 | Outbox / Inbox | `outbox_message`、`inbox_message` |

设计：[0006](../../dev-investment-agent/tree-build/SDD/modules/0006-knowledge.md)、[语义层 0009](../../dev-investment-agent/tree-build/SDD/modules/0009-semantic.md)；后端说明在 `knowbase-backend/docs/`（`dataset-registry.md`、`semantic-layer.md`、`knowbase-provider.md`、`ingestion-polling.md` 等）。

## 对外提供什么

| 接口 | 给谁 | 说明 |
| --- | --- | --- |
| MCP `/api/mcp/knowledge`（服务名 `sunmoon_knowbase`） | 沙箱里的 Codex | 工具 `list_datasets`、`describe_schema`、`metric_definitions`、`run_sql`；沙箱带 knowbench 签发的短期令牌（变量 `KNOWBASE_MCP_*`） |
| 入库契约 `knowfeed-knowbase-artifact` v1 | knowfeed（服务身份 `knowbase:ingest`） | schema 真源在本仓 `contracts/artifact/v1/` |
| 检索契约 `knowledge-retrieval` v1 | knowbench（服务身份 `knowbase:retrieve`） | schema 真源在本仓 `contracts/retrieval/v1/`（含 citation） |

两套契约都是**提供方**，调用方只持锁（[契约](../topics/contracts.md)）。

## 数据放在哪

- 自己的库 `knowbase`、Redis 前缀、RabbitMQ vhost（标准应用一套）。
- **不自己存原件**：用账号 `knowbase_source_reader` 只读 knowfeed 的桶 `knowfeed-originals` 的 `knowfeed/` 前缀；容器里的缓存目录可丢。
- RAGFlow 是可重建的派生系统（`C-D5`），本环境的数据集名 `sunmoon-kind-knowbase-default`。
- 样例：Olist 演示数据集的定义与登记脚本在 `k8s/gitops/components/app-platform/knowbase-app/knowbase-backend/samples/`（只是定义，不自动跑）。

## 界面

- **管理端**（`knowbase-admin.sunmoonai.com`）：数据集登记、数据目录、入库（`/zh-CN/knowledge/…`）；按应用角色显示，暂时看不到（总览「已知缺口」）。
- **网页端**：只有一页说明。只在所有者机器上可访问。

## 部署

`k8s/gitops/components/app-platform/knowbase-app/`：`database`、`migration`、`redis`、`rabbitmq`、`identity`、`provider`（在 RAGFlow 里建数据集、绑定）、`runtime`、`samples`。
