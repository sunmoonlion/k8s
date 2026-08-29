# knowledge-app（知识库）

> 取证时点：2026-08-29 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的东西

## 1. 定位

知识域：消费 info 分发的不可变制品，校验后送入 RAGFlow 索引；向 investment 提供受契约
约束的检索与引用。

它是 Info→Knowledge→Investment 链的**中枢**，也是**两套跨仓契约的唯一提供方**——
`contracts/` 下的 schema 是可编辑真源，另外两个仓只持锁文件。

**RAGFlow 是派生系统**（约束第 5 条）：
索引可由摄入链重建，权威记录在本仓的 PostgreSQL。

后端 76 个文件 / 5794 行。

## 2. 结构（只列模板之外）

| 路径 | 装什么 |
| --- | --- |
| `application/services/knowledge_ingestion_service.py` | 531 行，摄入编排 |
| `application/services/knowledge_retrieval_service.py` | 250 行，检索编排 |
| `application/dto/knowledge.py` / `dto/retrieval.py` | 115 / 144 行，契约 DTO |
| `infrastructure/external/ragflow.py` | RAGFlow 客户端与制品解析 |
| `infrastructure/security/service_auth.py` | **双关系**服务身份验证器，见 §4.3 |
| `interfaces/endpoints/knowledge_routes.py` | Admin + Internal 领域路由 |
| `contracts/artifact/v1/` | 摄入契约（producer = info-app） |
| `contracts/retrieval/v1/` | 检索契约（consumer = investment-app），三个 schema |

## 3. 硬规则

模板五项不变量原样存在（85 行），**额外一项**：

| 规则 | 位置 |
| --- | --- |
| UUID 主键必须同时有客户端与数据库双侧默认值 | `test_uuid_mixin_has_client_and_database_defaults`（`:66`） |

运行期约束：

| 规则 | 违反后果 |
| --- | --- |
| Admin `/api/knowledge/*` 需 `knowledge:admin` scope | 403 |
| 检索需 RAGFlow 已配置 | `ServiceUnavailableError` |
| **检索三重授权**（见 §4.2） | `ForbiddenError` |
| Artifact 必须恰好 1 个 `s3://` 引用 | `RAGFlowError` |
| bucket / prefix 受 allowlist 约束 | 摄入拒绝 |
| 内部 ingest / retrieve 需 Bearer + subject allowlist | 401/403/503 |
| 生产关闭 OpenAPI 与 `/docs` | 无文档端点 |

## 4. 关键机制

### 4.1 摄入链

```
校验 artifact 契约 DTO（extra=forbid）
  → 按 idempotency_key 幂等建 job（status=accepted）
  → Celery 可用则投递，否则同步处理
  → running → 制品解析（见下）→ RAGFlow 上传/parse/轮询
  → 成功：同事务 upsert KnowledgeDocument/Version + job succeeded
  → 失败：分类为 artifact_unreadable / ragflow_parse_failed / ragflow_config_error 等
```

**制品解析的安全链**：必须恰好一个 `s3://` 引用 → bucket 在 allowlist、key 在
prefix allowlist → 手写 SigV4 签名做 HEAD + GET → 双次校验 version-id / Content-Length /
content-type → 流式下载限额 → 最后 `hmac.compare_digest` 比对 sha256。

**无 RAGFlow 凭据时降级**：摄入止于 `artifact_verified`，**不写** `KnowledgeDocument*`。
这是"主档已落、派生未建"的合法状态。

领域身份用 **uuid5 稳定派生**（可跨环境重算），RAGFlow 的 dataset/document/chunk id
是**私有 provider binding，永不是领域身份**。

### 4.2 检索链

三重授权，全部不通过即 `ForbiddenError`（`knowledge_retrieval_service.py:45-56`）：

```python
requested_datasets ⊆ settings.retrieval_datasets          # dataset 白名单
payload.security_context.tenant_id == retrieval_default_tenant_id   # 租户一致
settings.retrieval_auth_required_scope in service_principal.scopes  # scope
```

通过后：查 `indexed` 且 `provider=ragflow` 的版本 → 按 `tenant:{id}` access_scope 过滤
→ 调 RAGFlow `/retrieval` → chunk 映射回版本，按 token_budget 逐条扣减并截断
→ evidence_id / chunk_id 用 uuid5 稳定派生 → Citation 由 `Citation.from_evidence` 投影。

### 4.3 双关系服务身份

`ServiceAuthVerifier(relation="ingest"|"retrieve")` 是**两个独立实例**，
各有自己的 audience、subject allowlist、discovery/backchannel 配置与 required scope：

| 关系 | 谁在调 | scope |
| --- | --- | --- |
| `ingest` | info-app | `knowledge:ingest` |
| `retrieve` | investment-app | `knowledge:retrieve` |

代码注释记录了一个要点：Casdoor 的 client-credentials token 可能只带 provider 的
`openid` scope，**关系 scope 由本地 subject allowlist 授予**并体现在 Principal 上。

## 5. 数据

迁移链 5 个版本，线性：

```
20260710_0001_knowledge_ingestion → 0002_auth_identity → 0003_retrieval_domain
→ 0004_outbox_primitives → 0005_uuid_defaults
```

三张领域表：`knowledge_ingestion_job`（含 status_history JSONB 与 payload 全量留档）、
`knowledge_document`、`knowledge_document_version`（含 access_scope 与 provider binding）。

`outbox_message` / `inbox_message` 存在但**零业务调用**（模板继承）。

## 6. 对外接口

| 契约 | 角色 | 真源 |
| --- | --- | --- |
| artifact v1 | **provider**（producer 是 info-app） | `contracts/artifact/v1/info-knowledge-artifact.schema.json` |
| retrieval v1 | **provider**（consumer 是 investment-app） | `contracts/retrieval/v1/` 三 schema + manifest |

| 端点 | 用途 |
| --- | --- |
| `POST /api/internal/v1/knowledge/ingestions` | info 服务身份调用 |
| `POST /api/internal/v1/knowledge/retrievals` | investment 服务身份调用 |
| `GET/POST /api/knowledge/ingestions*` | Admin 运维（见 §7 警告） |

本仓与 investment 是**仅有的两个真正挂载了 `/api/internal/v1` router** 的仓。

## 7. 已知未实现与风险

> **这张表由 `tests/test_dormant_capabilities.py` 守着**：每条休眠声明都有可执行
> 判据，能力一旦接线、或判据锚点被改名，测试即失败。改这张表前先跑那个测试。
> 机制说明见该文件的模块 docstring；它的边界是**保证已声明的条目不变陈旧**，
> 发现不了新出现的休眠能力——新增时手工加一条。


| 项 | 实际状态 |
| --- | --- |
| Admin「入库任务」运维页 | **静态占位页**：只列 API 路径文案，无 fetch、无表格、无操作 |
| 共享 Outbox | 表与仓库类在，零业务调用 |
| Web interaction 生产可用 | 同模板：默认 503 |
| Web 侧检索业务页 | 无，只有 toolkit/common 与可选 reference workspace |

## 8. 验证

```bash
cd <repo>/knowledge-app/knowledge-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && uv run pytest -q
uv run pytest tests/test_kernel_invariants.py -q      # 6 项
```

复核关键风险：
```bash
# 终态判定：CANCEL 必须抛错，progress 不得单独构成成功条件
sed -n '/async def _wait_for_document_parse/,/_RUN_ALIASES/p' app/app/infrastructure/external/ragflow.py
uv run pytest tests/test_knowledge_ingestion.py -k 'cancelled or numeric or progress_alone' -q

# 三重授权
sed -n '/requested_datasets = set/,/retrieval service relation/p' app/app/application/services/knowledge_retrieval_service.py

# citation 路由实际只有一条，且在 web 前缀下
# citation 的 source_href 必须能在真实路由表里找到（O6 的回归护栏）
uv run pytest tests/test_knowledge_retrieval.py -k resolves_to_a_real_route
```
