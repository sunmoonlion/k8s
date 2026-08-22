# knowledge-app

> 仓库路径 `/home/zymun/master/knowledge-app`。深读基线：2026-08-13（后端约 7000 行 Python、契约
> schema、迁移链、前端结构）。App 之间的公共形态见 `baseline/app-platform/inter-apps/app-platform.md`。

## 1. 概要

知识库域 App，Info→Knowledge→Investment 数据链的**中枢**：消费 info 分发的不可变 artifact，
校验后入库到检索提供方（RAGFlow），向 investment 提供受契约约束的检索/引用服务。父仓
`contracts/` 是摄入与检索 **provider 契约的唯一可编辑真源**（Info/Investment 仓只有消费锁）。

### 仓库拓扑

```
knowledge-app/
├── contracts/
│   ├── README.md                    # 契约治理规则
│   ├── artifact/v1/                 # 摄入契约（producer=Info，provider=Knowledge）
│   │   ├── info-knowledge-artifact.schema.json   # sha256 a3219604...499c81
│   │   ├── contract-manifest.json
│   │   └── examples/upsert.json
│   └── retrieval/v1/                # 检索契约（provider=Knowledge，consumer=investment-app）
│       ├── knowledge-retrieval-request/response.schema.json
│       ├── citation.schema.json     # 浏览器安全引用投影
│       ├── contract-manifest.json   # 每文件 sha256 钉住
│       └── examples/
├── docs/（拓扑文档与历史快照材料）
├── knowledge-backend/（app/ 包根 + db-provisioner + 三个 access-bootstrap + mybuild）
├── knowledge-admin-frontend/app/    # 运营面（Next.js）
└── knowledge-web-frontend/app/      # 用户面
```

### 运行与验证

与模板同套命令；RAGFlow 未启用时摄入降级为 artifact 契约验证器（`artifact_verified`）。

## 2. 重要点

1. **摄入契约 v1**：一个请求 = **恰好一个不可变、带 S3 版本的对象**；provider 用只读身份
   先验 storage version/size/media type/SHA-256 再上传 RAGFlow；DB id 只是 lineage，
   provider 永不回拨 Info 数据库。
2. **幂等受理**：idempotency_key 去重；service principal 只来自验证后的 token，永不从
   JSON payload 接受。
3. **制品安全解析**：bucket/前缀白名单 + 手写 SigV4 + version/size/content-type 双次校验 +
   sha256 比对，流式限额。
4. **同事务原子提交**：领域身份（uuid5 稳定派生，可跨环境重算）+ provider binding + 终态 job。
5. **检索三重授权**：dataset 白名单 ∧ tenant 一致 ∧ `knowledge:retrieve` scope。
6. **浏览器安全投影**：浏览器只见 citation 投影 + 同源 source_href，永不见 provider 原始
   URL；RAGFlow id 是私有 binding，永不是领域身份。
7. **双关系服务身份**：ingest（info→）与 retrieve（investment→）两个独立验证器，各自
   audience/subject allowlist；关系 scope 由本地 subject allowlist 授予。
8. 破坏性契约变更 = 新 major + 双版本迁移窗口。

## 3. 架构

### 3.1 两大契约（核心）

#### artifact/v1 摄入契约

- 请求体 `KnowledgeIngestionCreate`（pydantic extra=forbid）：contract_version=1、operation=upsert、distribution_id、**source_app 字面量 "info-app"**、source_document(_version)_id、`artifact`（ArtifactRef：类型仅 clean_markdown/text_plain、`s3://` uri 无 query/fragment/userinfo、storage_version、sha256、1~52428800 字节、content_type 仅 text/markdown|text/plain 可带 charset）、dataset_key（`^[a-z0-9][a-z0-9._-]*$` ≤120）、idempotency_key、correlation_id/causation_id、document（title/canonical_url/content_hash/source_name/published_at/metadata）。
- 契约原则（contracts/README.md）：**v1 只接受恰好一个不可变、带 S3 版本的对象**；provider 用自己的只读身份解析，先验证 storage version/size/media type/SHA-256 再上传 RAGFlow；DB id 只是 lineage，provider 永不回拨 Info 数据库。破坏性变更需新 major + 双版本迁移窗口。

#### retrieval/v1 检索契约

- manifest：contract=`sunmoonai.knowledge.retrieval`，service_consumers=[investment-app]、browser_consumers=[investment-web-frontend]；request=exact-fields-v1，response 允许加性可选字段，破坏性变更需新 major；消费方必须钉住 manifest digest 并跑 CDC 测试。
- 请求 `KnowledgeRetrievalRequest`：query(≤8192)、dataset_keys(1~8)、filters（source_document(_version)_ids 各≤50 且去重）、top_k(1~50)、token_budget(1~32000)、**security_context**（tenant_id 正则、actor_id、actor_type human/service、policy_version、delegated_run_id）——全部 extra=forbid。
- 响应 `Evidence`：evidence_id/knowledge_document(_version)_id/chunk_id（均为 uuid5 稳定派生）、content、score、rank、title、source_uri（仅 http/https 清洗）、source_document(_version)_id、content_hash、token_estimate、truncated、access_scope、provider_metadata（term/vector_similarity）。
- `Citation`（浏览器投影）：quote≤1000、source_href 必须匹配 `^/api/citations/{uuid}/source$`——浏览器只拿到同源授权路径，永不见 provider 原始 URL。RAGFlow dataset/document/chunk id 是私有 provider binding，永不是领域身份。

### 3.2 后端领域链

#### 摄入链（`knowledge_ingestion_service.py` + `ragflow.py`）

1. `submit_ingestion`：按 idempotency_key 幂等（已存在直接返回原 job）；internal 面提交时把 **service principal 记入 accepted 状态日志**（subject/issuer/audience/scopes/policy_version），永不从 JSON payload 接受。
2. 202 后经 Celery `app.tasks.process_knowledge_ingestion` 派发（producer 不可用时 dispatch 端点 inline 同步处理）。
3. `process_ingestion_job`：终态直接返回；置 running 后——
   - RAGFlow 启用：`ingest_into_ragflow` = 解析制品 → `ensure_dataset`（按名查找或建 naive/me dataset）→ `upload_document` → `parse_document` → **轮询 `_wait_for_document_parse`**（终态 DONE/FAIL/CANCEL 或 progress≥1，超时/FAIL 抛错）。
   - 未启用：降级 `artifact-contract-verifier` 处理器，只验证制品到 `artifact_verified`。
4. **制品解析安全链**（`resolve_artifact_content`/`_resolve_artifact_ref`/`_fetch_s3_object`）：必须恰好 1 个 ref；只接受 s3://；bucket 在 `artifact_bucket_allowlist`、key 在 `artifact_prefix_allowlist`、无非法路径段；**手写 SigV4 签名** HEAD+GET（path-style 可选），双次校验 x-amz-version-id/Content-Length/content-type，流式下载限额（超出声明大小即断），最后 `hmac.compare_digest` 校验 sha256。
5. `complete_ragflow_ingestion`：**同一事务原子提交**领域身份 + provider binding + 终态 job。稳定 ID：`uuid5(DOC_NS, "{source_app}:{source_document_id}:{dataset_key}")` 与 `uuid5(VER_NS, "{doc_id}:{source_version_id}")`；KnowledgeDocument ON CONFLICT DO NOTHING、KnowledgeDocumentVersion ON CONFLICT DO UPDATE（按 doc+source_version 唯一键）；access_scope=`["tenant:{default_tenant}"]`。
6. 错误分类 `classify_ingestion_error`：artifact_unreadable / ragflow_config_error / ragflow_parse_failed / external_api_error / failed。终态集含 succeeded/failed/ragflow_config_error/ragflow_parse_failed/artifact_unreadable/external_api_error/artifact_verified/legacy_binding_missing。
7. `retry_ingestion_job`：仅终态可重试；succeeded 禁止；**ragflow_config_error 需 force**；记 retry_count/retry_history/last_retry_at，重置为 accepted 再派发。
8. `check_ragflow_config`：探活 datasets + tenant models，检查默认 embedding 模型（embd_id/tenant_embd_id）。

#### 检索链（`knowledge_retrieval_service.py`）

1. 三重授权校验：请求 dataset_keys ⊆ `retrieval_datasets` 白名单；tenant_id == `retrieval_default_tenant_id`；service principal 含 `knowledge:retrieve` scope。
2. `_eligible_versions`：document active + version indexed + provider=ragflow + dataset_key 命中 + 可选 source id 过滤；再按 `tenant:{id}` access_scope 过滤；空则返回空响应。
3. 调 RAGFlow `/retrieval`（top_k≥32 冗余、similarity_threshold 0、vector_similarity_weight 0.3）；超时→504、协议错→502、一般错→503。
4. `_assemble_response`：chunk 按 (provider_dataset_id, provider_document_id) 映射回版本；token_budget 逐条扣减并截断；chunk_id/evidence_id = uuid5 稳定派生（CHUNK/EVIDENCE namespace + version_id + chunk 指纹）；truncated 三条件聚合。

#### HTTP 表面

- `routes.py`：admin/web 认证 + diagnostics + web interactions（与模板同构）；`knowledge_admin_router`（前缀 `/api/knowledge`，挂 `require_knowledge_admin`）；**`knowledge_internal_router`（前缀 `/api/internal/v1/knowledge`）不挂 admin 依赖**，靠端点级 service identity。
- 端点：`POST /knowledge/ingestions`（admin 提交，202）、`POST /internal/v1/knowledge/ingestions`（Info 服务身份）、`POST /internal/v1/knowledge/retrievals`（Investment 服务身份）、`GET /knowledge/ingestions`（多条件过滤列表）、`GET /knowledge/ragflow/config-check`、`GET /knowledge/ingestions/{id}`、`POST .../status`、`.../dispatch`、`.../retry`。

#### 双关系 Service Identity（`service_auth.py`）

`ServiceAuthVerifier(relation="ingest"|"retrieve")` 两个独立实例：
- ingest：Casdoor application `sunmoonai-info-knowledge-ingest`、scope `knowledge:ingest`；
- retrieve：`sunmoonai-investment-knowledge-retrieve`（与 investment 出站侧同名 application 完全对齐）、scope `knowledge:retrieve`；各自独立 discovery/backchannel/audience/subject allowlist。
- 校验链：audience 验签 → subject ∈ allowlist（否则 Forbidden）→ issuer 存在 → scope 结构校验（注意：Casdoor client-credentials token 可能只带 provider 的 openid scope，**关系 scope 由本地 subject allowlist 授予**并体现在 Principal 上）→ iat/exp 时间戳校验。未配置 audience/subjects 时 503。

### 3.3 数据模型与迁移（head = `20260811_0005`）

1. `20260710_0001` knowledge_ingestion_job（uq idempotency_key、ix source_version/status）。
2. `20260712_0002` auth_user。
3. `20260715_0003` retrieval_domain：knowledge_document（uq source_app+source_document_id+dataset_key）+ knowledge_document_version（uq doc+source_version、uq ingestion_id、provider binding 三索引）；**含遗留数据回填**：把旧 succeeded job 用 uuid5 重算身份回填新表；无 provider binding 的旧记录标记 `legacy_binding_missing`（带显式 CAST 的 jsonb 回填语句，有方言编译回归测试）。
4. `20260808_0004` outbox primitives（模板原语）。
5. `20260811_0005` 四表 id 补 `gen_random_uuid()`。

模型：KnowledgeIngestionJob（status_history JSONB 日志、payload 全量留档）、KnowledgeDocument、KnowledgeDocumentVersion（access_scope JSONB、provider/provider_dataset_id/provider_document_id）。

### 3.4 Knowledge 专属配置（core/config.py 625 行）

- 双资源边界：`internal_auth_*`（Info→Knowledge ingest）与 `retrieval_auth_*`（Investment→Knowledge retrieve），各含 casdoor_application/discovery/backchannel/audience/subject_allowlist/required_scope。
- RAGFlow：`ragflow_api_base/api_key`、parse 超时与轮询间隔；`ragflow_enabled` = base+key 都配置。
- 检索策略：`retrieval_dataset_allowlist`（CSV）、`retrieval_default_tenant_id`（默认 sunmoonai）、provider 超时。
- S3 只读消费：`s3_endpoint/region/access_key/secret/force_path_style` + `artifact_s3_allowed_buckets/prefixes`、`artifact_max_size_bytes`、`artifact_allowed_content_types`。
- celery_queue 默认 `knowledge.default`；数据库 `knowledge`。

### 3.5 前端

与模板/info 同构（Next.js 16 + shadcn + Tailwind v4 + next-intl + standalone）：

- **admin**：`(dashboard)/knowledge/ingestions` 页 + `knowledge-ingestions-panel.tsx`（入库任务列表/重试/dispatch/config-check），另有 dashboard/settings/reference/rich-reference/forbidden；复用 crud/rich 组件套件。
- **web**：dashboard/toolkit/login，interaction 运行时与 info web 同构。

### 3.6 关键边界规则速查

| 规则 | 位置 |
|---|---|
| 一个 artifact 请求 = 恰好一个带版本的 s3:// 对象 | ragflow.resolve_artifact_content |
| provider 永不回拨 Info 数据库 | contracts/README.md |
| dataset_key 是唯一稳定入参；RAGFlow id 是私有 binding | retrieval 契约 |
| 浏览器只见 citation 投影 + 同源 source_href | Citation DTO |
| 幂等键去重 + service principal 只来自验证后的 token | submit_ingestion |
| 领域身份用 uuid5 稳定派生，可跨环境重算 | ingestion_service |
| 破坏性契约变更 = 新 major + 双版本窗口 | contracts/README.md |

## 4. 关联

- 上游（artifact 消费锁持有方）：`../info-app/info-app.md`。
- 下游（retrieval 消费锁持有方）：`../investment-app/investment-app.md`。
- 母模板：`../tpl-app/tpl-app.md`；公共形态：`../../inter-apps/app-platform.md`（§8 跨 App 集成）。
- 部署声明：`../k8s/k8s.md`；平台间关系：`../../../sunmoonai/architecture.md`。
