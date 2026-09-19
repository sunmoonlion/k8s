# knowledge-app（知识库）

> 取证时点：2026-09-13 后端源码与隔离验证；本轮增量未部署 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的东西；源码集成不代表已部署

## 1. 定位

知识域：消费 info 分发的不可变制品，校验后送入 RAGFlow 索引；向 investment 提供受契约
约束的检索与引用。

它是 Info→Knowledge→Investment 链的**中枢**，也是**两套跨仓契约的唯一提供方**——
`contracts/` 下的 schema 是可编辑真源，另外两个仓只持锁文件。

**RAGFlow 是派生系统**（约束第 5 条）：
索引可由摄入链重建，权威记录在本仓的 PostgreSQL。

后端约 75 个文件、5–6k 行。

## 1.1 重要点（读代码前先别理解反）

| | |
| --- | --- |
| 摄入单位 | 一次请求恰好一个不可变、带版本的对象 |
| RAGFlow 的 id | **不是领域身份**——它是派生系统的内部标识，领域身份是 `knowledge_document_version` |
| 浏览器看得到什么 | 只有 citation 投影；**provider 原始 URL 永不外露**（`citation_source` 返回 302，location 由服务端解析） |
| RAGFlow 定位 | **可重建的派生系统**，不保存唯一原文 |

## 2. 结构（只列模板之外）

| 路径 | 装什么 |
| --- | --- |
| `application/services/knowledge_ingestion_service.py` | 摄入编排 |
| `application/services/provider_delivery.py` | 依赖统一 Port 的操作意图、回执恢复与未知结果阻断 |
| `application/services/ingestion_execution.py` | 任务拥有的持久轮询游标、受理协议标记及重试代次提交/自动 flush 栅栏 |
| `application/services/ingestion_authorization.py` / `core/ingestion_policy.py` | 摄入静态映射与受理快照复核；独立于检索白名单 |
| `application/services/knowledge_retrieval_service.py` | 检索编排 |
| `application/dto/knowledge.py` / `dto/retrieval.py` | 契约 DTO |
| `application/ports/knowledge_provider.py` | 供应商无关的类型化数据面接口与错误语义 |
| `infrastructure/external/knowledge_provider.py` | 当前 Provider 配置与装配，默认 RAGFlow |
| `infrastructure/external/ragflow_provider.py`、`ragflow.py` | RAGFlow 适配器与底层 HTTP 客户端 |
| `infrastructure/external/artifact_content.py` | 独立的不可变 S3 Artifact 校验读取 |
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
| Artifact 必须恰好 1 个 `s3://` 引用 | 供应商无关 `ArtifactError`（属于 `ProviderError`） |
| bucket / prefix 受 allowlist 约束 | 摄入拒绝 |
| 内部 ingest / retrieve 需 Bearer + subject allowlist | 401/403/503 |
| 生产关闭 OpenAPI 与 `/docs` | 无文档端点 |

## 4. 关键机制

### 4.1 摄入链

```
校验 artifact 契约 DTO（extra=forbid）
  → INGESTION_DATASET_BINDINGS 显式准入（空配置全部拒绝）
  → 按 idempotency_key 并发幂等建 job（status=accepted），同事务写公共 Outbox
  → Scheduler 周期触发公共 pump；Worker 持执行租约读取消息 UUID
  → running → 制品解析（见下）→ RAGFlow 操作意图/上传回执/parse
  → 每条 poll 单次查询；未完成则游标 + 后继 Outbox + Inbox 同事务，释放 Worker
  → 成功：同事务 upsert KnowledgeDocument/Version + job succeeded + Inbox
  → 失败：分类为 artifact_unreadable / ragflow_parse_failed / ragflow_config_error 等
  → Provider 结果未知：reconciliation_required，不写 Inbox，不盲目重复远端写入
```

**制品解析的安全链**：必须恰好一个 `s3://` 引用 → bucket 在 allowlist、key 在
prefix allowlist → 手写 SigV4 签名做 HEAD + GET → 双次校验 version-id / Content-Length /
content-type → 流式下载限额 → 最后 `hmac.compare_digest` 比对 sha256。

**尚未进入 RAGFlow 时无凭据降级**：摄入止于 `artifact_verified`，**不写** `KnowledgeDocument*`。
这是"主档已落、派生未建"的合法状态；已确认上传并进入解析的任务不能因凭据被移除而
退回这个模式，必须恢复配置或调查。

创建、重试和 dispatch 都只请求持久排队，不再以 broker 缺失为由进程内执行。相同
幂等键但不同请求内容拒绝；公共消费者在每次提交前验证租约，防止旧 Worker 迟到覆盖。
upload/parse 操作先持久化 executing 再访问远端；有回执则继续查询，
无回执且结果未知则对账，不以单次查无结果证明可以重传。上传认领校验稳定版本文件名、
dataset、原文件长度与 SHA-256。历史 running 缺失回执标为 legacy_unknown，先调查。

2026-09-13 B5 源码候选：`INGESTION_DATASET_BINDINGS` 为 key 到既有 dataset_id/name 的
静态 JSON 映射；不从 RETRIEVAL_DATASET_ALLOWLIST 推导写权限。Admin/Internal 共享
受理用例，未知 key 返回 403 且不建 job/Outbox。服务端首条 accepted 历史保存绑定快照，
dispatch/retry/Worker/恢复/最终落库复核，force 不能绕过；旧无快照任务不自动补绑。
dataset 仅查找并核 ID/name，数据面创建入口失败关闭；配置缺目标不能触发自动创建。
静态配置不是即时撤权：部署必须排空旧 API/Worker、同步一致配置；实际映射、存量任务和
切换未验收，不能直接无配置部署。详细边界见 [部署清单](../../legacy-backlog/deployment-checklist.md)。

B6b 源码：执行状态在 job.metadata_json 的保留项 ingestion_execution_v1，首条受理历史
保存服务端协议标记；原请求留在 payload，用户 retry_count 不作为代次。消息携带
generation/step，与 upload_identity 资源键核对；旧游标/代次不动当前执行，未来/旧格式
消息失败关闭。已保存验证游标后，poll/显式 retry 无需重读源文件，仍复核 Provider 回执。
deadline/interval 首次 parse 前按 DB 时钟固定，后续指数退避且最多 60 秒，每次读取受
剩余 deadline 限制；poll 只查一次文档状态，另查租户身份，无 sleep 或重复 POST。
旧无协议标记任务不自动迁入；部署前必须一致升级/排空，详细验收见
[`B6b 证据`](../../legacy-backlog/verification-index.md)。

领域身份用 **uuid5 稳定派生**（可跨环境重算），RAGFlow 的 dataset/document/chunk id
是**私有 provider binding，永不是领域身份**。

### 4.2 检索链

三重授权，全部不通过即 `ForbiddenError`（`knowledge_retrieval_service.py:45-56`）：

```python
requested_datasets ⊆ settings.retrieval_datasets          # dataset 白名单
payload.security_context.tenant_id == retrieval_default_tenant_id   # 租户一致
settings.retrieval_auth_required_scope in service_principal.scopes  # scope
```

通过后：查 `indexed` 且匹配当前配置 Provider 的版本 → 按 `tenant:{id}` access_scope 过滤
→ 调数据面 Port（当前 RAGFlow 适配器调用 `/retrieval`）→ chunk 映射回版本，按 token_budget 逐条扣减并截断
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

迁移链 6 个版本，线性：

```
20260710_0001_knowledge_ingestion → 0002_auth_identity → 0003_retrieval_domain
→ 0004_outbox_primitives → 0005_uuid_defaults → 20260911_0006_durable_delivery
```

三张领域表：`knowledge_ingestion_job`（含 status_history JSONB 与 payload 全量留档）、
`knowledge_document`、`knowledge_document_version`（含 access_scope 与 provider binding）。

`outbox_message` / `inbox_message` 是公共命令及消费回执；新增公共死信/执行租约表。
`knowledge_provider_operation` 记录外部副作用意图与回执，不取代领域文档主档。
迁移回填 accepted/running 命令，保留历史 running 的未知上传状态。存在未消费命令
或 Provider 回执时降级拒绝丢弃；须经排空、对账及已验证的备份恢复流程处置。

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

四个 Backend 均已挂载受服务身份与 scope 保护的 Internal 投递指标路由；
本仓另外拥有摄入和检索等领域 Internal 路由，不能把指标接线误当成领域接口全覆盖。

## 7. 已知未实现与风险

> **这张表由 `tests/test_dormant_capabilities.py` 守着**：每条休眠声明都有可执行
> 判据，能力一旦接线、或判据锚点被改名，测试即失败。改这张表前先跑那个测试。
> 机制说明见该文件的模块 docstring；它的边界是**保证已声明的条目不变陈旧**，
> 发现不了新出现的休眠能力——新增时手工加一条。


| 项 | 实际状态 |
| --- | --- |
| Admin「入库任务」运维页 | **静态占位页**：只列 API 路径文案，无 fetch、无表格、无操作 |
| Web interaction 生产可用 | 同模板：默认 503 |
| Web 侧检索业务页 | 无，只有 toolkit/common 与可选 reference workspace |

### Provider 可替换边界

当前源码已将摄入回执编排、恢复与检索接到 `KnowledgeProvider` Port；dataset/document、
解析状态和检索 chunk 通过统一类型传递。RAGFlow 的 HTTP 字段、run 别名与租户范围
摘要计算留在适配器，原文读取不再依赖 RAGFlow 模块。事务、授权与 Outbox 仍由应用层持有。

这不是已接入 WeKnora：当前装配只允许 RAGFlow，旧任务/回执键和状态、数据库
`ragflow_document_id` 以及专用 config-check 接口保留兼容。
**retrieval v1 的 provider 元数据仍限定 ragflow**，其它 Provider 显式拒绝，不伪装身份。
将来替换还需实现适配器、扩展契约并做消费者回归、重建索引/绑定及验证引用和未知结果；
不能只换地址或直接复用旧 Provider 回执。实现及证据见
[Provider 内部解耦证据与历史入口](../../legacy-backlog/verification-index.md#knowledge-provider-内部解耦)；
适配义务与兼容边界由 Knowledge Backend 的 `docs/knowledge-provider.md` 维护。

运行身份隔离使用 Knowledge 自身的表列策略，包含 provider operation journal 的权限
边界；本机 KIND 已迁移至 `20260911_0006`，完成分角色身份切换和旧身份退出；既有
codex-smoke 摄入绑定已应用，没有重放历史任务，不代表完整 Provider 业务验收。续作见
[部署清单](../../legacy-backlog/deployment-checklist.md)。

## 8. 验证

```bash
cd <repo>/knowledge-app/knowledge-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && uv run pytest -q
uv run pytest tests/test_kernel_invariants.py -q      # 6 项
```

复核关键风险：
```bash
# 生产链：单次轮询、终态判定、持久 deadline 与故障恢复（需要可丢弃 DB）
uv run pytest tests/test_ingestion_polling_db.py -q
# 旧 helper 兼容回归不替代上面的生产链测试
uv run pytest tests/test_knowledge_ingestion.py -k 'cancelled or numeric or progress_alone' -q

# 三重授权
sed -n '/requested_datasets = set/,/retrieval service relation/p' app/app/application/services/knowledge_retrieval_service.py

# citation 路由实际只有一条，且在 web 前缀下
# citation 的 source_href 必须能在真实路由表里找到
uv run pytest tests/test_knowledge_retrieval.py -k resolves_to_a_real_route
```
