# info-app（资讯采集与治理）

> 采集防护源码候选更新：2026-09-12（未部署）｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的东西

## 1. 定位

资讯域：从外部源采集内容 → 抽取 → 去重 → 人工治理 → 把可分发制品送给 knowledge-app。
它是 knowledge 的**唯一内容上游**。

后端约 90 个文件、7–8k 行。最大的单文件是 `info_crawl_service.py`（约 1.8k 行），
整条采集-治理-分发链都在里面。

## 1.1 重要点（读代码前先别理解反）

| | |
| --- | --- |
| 去重 | sha256 精确 + `simhash64` 近似，阈值 **0.84**（`info_crawl_service.py` 的 `_NEAR_DUPLICATE_THRESHOLD`） |
| 可分发的产物 | 只有 `clean_markdown` 与 `text_plain` 两类 artifact |
| 分发目标 | 硬编码 `knowledge-app`，其余 `target_app` 一律拒绝 |
| 全文索引 | `SEARCH_BACKEND` 默认 `disabled`，索引任务直接 skip |
| 爬虫 | **不内嵌** Scrapy / Playwright，采集结果须外部注入 |

## 2. 结构（只列模板之外）

| 路径 | 装什么 |
| --- | --- |
| `application/collectors/` | 采集器族 + 注册表，见 §4.1 |
| `application/services/info_crawl_service.py` | **本仓最大单文件**（约 1.8k 行），采集/去重/治理/分发编排 |
| `application/services/delivery_outbox.py` | 公共 Outbox 的 Info 分发领域适配 |
| `interfaces/endpoints/info_routes.py` | 领域路由（模板面在 `interfaces/http/`） |
| `interfaces/schemas/info.py` | 领域 schema |
| `infrastructure/messaging/delivery_handlers.py` | 采集、索引、分发的领域 handler 注册 |
| `tasks/durable_delivery.py` | 公共发布与执行入口；旧业务 Celery 入口拒绝直接投递 |
| `infrastructure/search/` | ES/OpenSearch 索引适配（**默认关闭**） |
| `infrastructure/external/knowledge_app.py` | 调 knowledge 摄入的客户端 |
| `infrastructure/external/crawl_http.py` | 正文、RSS/API discovery 的公网抓取策略；不用于受信内部服务 |
| `infrastructure/storage/crawl_concurrency.py` | Info 专用跨进程来源准入；独立 PostgreSQL 事务锁 |
| `domain/info_identity_v1.py` / `cli/identity_preflight.py` | 冻结的 URL 身份策略、迁移前只读冲突核查 |
| `application/services/artifact_reconciliation.py` / `cli/reconcile_artifacts.py` | Info S3 与 RawArtifact 双向、分页只读对账；无自动清理 |
| `cli/drain_delivery_outbox.py` | 兼容公共 pump，仅接受批量上限 100 |
| `contracts/knowledge-provider-lock.json` | artifact 契约的**消费锁** |

## 3. 硬规则

模板结构不变量仍由 `tests/test_kernel_invariants.py` 检查，额外约束：

| 规则 | 位置 |
| --- | --- |
| 旧投递表归档，公共 Outbox 是唯一新投递真源 | `test_legacy_delivery_is_archived_and_shared_outbox_is_authoritative` |

旧分发日志只保留迁移/回滚用途，见 §5。

配置层额外的生产校验：`ALLOWED_HOSTS` 禁 `*`、禁 `REFERENCE_INTERACTION_ENABLED`。

运行期约束：

| 规则 | 违反后果 |
| --- | --- |
| 抓取响应超 `CRAWL_MAX_BYTES`（默认 10 MiB） | 任务 failed |
| 可分发 artifact 仅 `clean_markdown` / `text_plain`，且必须有对象存储 version_id | `ArtifactNotDistributableError` → 409（8 处 raise 点） |
| `dispatch_distribution` 的 `target_app` 必须是 `knowledge-app` | `ValueError`（`info_crawl_service.py:1177-1178`） |
| Worker/Scheduler 启动须配 broker | `RuntimeError` |
| 资讯域端点整体需 `info:admin` scope | 403 |

## 4. 关键机制

### 4.1 采集器注册表

`application/collectors/registry.py` 用一张 dict 映射类型到适配器，**六种类型五个实现**
（rss 与 atom 共用 `RssCollectorAdapter`）：

```
rss / atom      → RssCollectorAdapter        (ElementTree 双格式)
api             → ApiCollectorAdapter        (87 行，items_path 点路径 + 字段映射)
changedetection → ChangeDetectionCollectorAdapter (21 行，需 watch_id)
scrapy          → ScrapyCollectorAdapter     (23 行)
playwright      → PlaywrightCollectorAdapter (18 行)
```

未命中类型抛 `ValueError: unsupported collector type`。

**scrapy 与 playwright 不内嵌爬虫**：两个适配器都很短，实际结果须由外部 crawler
经 `external_results.py`（99 行）注入。

### 4.2 采集 → 版本

抓取（httpx，限大小/超时/UA）→ 存 raw 制品 → trafilatura 抽取 markdown + text
→ 按 canonical URL 的 v1 派生身份键归并文档 → **sha256 精确去重 + simhash64 近似去重**
→ content_hash 未变则跳过新版本，变了则建 clean/text 制品 + 新 `InfoDocumentVersion`
→ 与版本同事务保存索引命令，由公共消费者执行；`SEARCH_BACKEND=disabled` 时跳过。

2026-09-12 源码候选：正文与 RSS/API discovery 都经 `fetch_crawl_url`。仅公网 HTTP/80、
HTTPS/443；解析结果全量校验后固定 IP，保留 TLS 主机校验，逐跳重验且不跨站携带凭据。
流式读取限额、总 deadline，拒绝非 identity 压缩响应，不隐式使用环境代理。
来源准入首版每个来源 ID 一个执行，无 ID 时按规范化目标主机归组；正文与发现共用数据库
advisory lock，业务中间提交不释放。忙时不抓取、不写终态/Inbox；Worker 复用公共有界
重排/死信/重放，发现接口返回 409。不同来源 ID 不是同站总限速，不承诺公平等待；
每个执行额外占用一个数据库连接。源码候选与实际部署分开验收。边界及测试见
[`v5 处置清单`](../../v5-backlog-disposition-luna.md)。

B3 源码候选需要先执行 `20260912_0008`：原 URL 保留，派生身份键唯一；首次创建
upsert，文档行锁覆盖版本号、当前版本和索引意图。旧程序缺身份键的新文档/缺写协议的新版本
插入会失败；切换必须停写并用独立 Migration Job 升级。只读 `identity_preflight` 输出冲突
数量/样本 ID，不自动合并数据。上传仍保留原同名版本语义，不代表未来客户工作区文件身份。
业务库尚未核查或升级，不能直接把源码同步当作部署完成。

B4 源码候选：S3 写后严格按回执 VersionId 核验，拒绝无版本写回执。只读对账分别枚举
`info/original/` 的全部 S3 版本和已登记 RawArtifact，报告缺失、不一致、未登记与模糊引用；
未登记候选不等于可删除，原始抓取没有 document_version_id 也受保护。只读 CLI 每次
最多 100 项，可用 cursor 续扫；不是跨 DB/S3 原子快照，要从头复扫。无新表/迁移，
未接周期任务或自动回收；实际存储核查、保留策略、权限与部署另验，详见 v5 处置清单。

创建作业时 `enqueue=false` 只建单；`run` 接口持久排队，不在请求内采集。
索引重建响应 `queued` 表示排队数，`indexed=0` 不宣称后台已完成。

### 4.3 分发 → knowledge

```
校验制品可分发性 → 组装 artifact v1 payload
  → 同事务写 distribution_record + outbox_message
  → 公共 Scheduler 发布 / Worker 消费 → POST knowledge 内部摄入端点
```

公共消费者使用执行租约、epoch、提交前 fencing 与 Inbox；只有下游确认和本地提交后
才记录完成回执。Scheduler 每 5 秒发布与对账，有限重试后入死信，可显式重放。
broker 故障不改变已接受命令；分发重试保持相同下游业务身份。取消和租约丢失不写终态。

## 5. 数据

源码迁移链 8 个版本，线性（0008 尚未用于业务库）：

```
20260706_0001_info_spider_mvp → 0002_source_governance → 0003_auth_identity
→ 0004_delivery_outbox → 0005_outbox_primitives → 0006_delivery_outbox_uuid_default
→ 20260911_0007_durable_delivery
→ 20260912_0008_canonical_identity
```

领域表（`infrastructure/models/info.py`，9 张）：

`info_source` · `info_collector` · `crawl_job` · `raw_artifact` · `info_document` ·
`info_document_version` · `extracted_content` · `distribution_record` · `delivery_outbox_message_legacy`

**新旧投递记录的归属**：

| 表 | 语义 | 状态 |
| --- | --- | --- |
| `delivery_outbox_message_legacy` | 原分发日志 | 归档；旧表名写入失败 |
| `outbox_message` / `inbox_message` | 公共命令与完成回执 | 采集、索引、分发已接线 |
| `outbox_dead_letter` / `outbox_execution` | 公共死信与执行租约 | 有限重试、恢复与 fencing |

迁移保留旧消息 ID 和完成回执；历史 pending 采集需盘点后显式排队，不能猜测 enqueue。
降级拒绝未排空领域命令；详细切换、备份与回滚见 Info 后端 `docs/durable-delivery-luna.md`。

`info_document.metadata_json` 是治理审计的载体（review_history / audit_log，
含 correlation_id / actor / reason）。治理动作用 `expected_updated_at` 做乐观并发。

## 6. 对外接口

| 方向 | 内容 |
| --- | --- |
| 提供 | Admin/Web 模板面 + `interfaces/endpoints/info_routes.py` 的资讯域 REST |
| 消费 | knowledge artifact 契约 v1（锁：`contracts/knowledge-provider-lock.json`） |
| 发出 | `dispatch_distribution` → knowledge 内部摄入端点 |

`interfaces/http/internal/` 只有包说明，**无 router 挂载**。

## 7. 已知未实现

> **这张表由 `tests/test_dormant_capabilities.py` 守着**：每条休眠声明都有可执行
> 判据，能力一旦接线、或判据锚点被改名，测试即失败。改这张表前先跑那个测试。
> 机制说明见该文件的模块 docstring；它的边界是**保证已声明的条目不变陈旧**，
> 发现不了新出现的休眠能力——新增时手工加一条。


| 项 | 实际状态 |
| --- | --- |
| Elasticsearch 索引 | 默认 `SEARCH_BACKEND=disabled`，索引任务直接 skip |
| 多下游分发 | 运行时只接受 `knowledge-app` |
| 内置 Scrapy/Playwright 爬虫 | 不内嵌，须外部注入结果 |
| `/api/internal` 入站面 | 无 router |
| Web interaction 生产可用 | 同模板：默认 503 |

## 8. 验证

```bash
cd <repo>/info-app/info-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && uv run pytest -q
uv run pytest tests/test_kernel_invariants.py -q      # 6 项

# 单次 outbox 扫描
uv run python -m app.cli.drain_delivery_outbox --limit 100

# 受权 Info S3/DB 只读配置下运行；报告/cursor 可能含文件名，不公开传播
uv run python -m app.cli.reconcile_artifacts --mode inventory --limit 50
uv run python -m app.cli.reconcile_artifacts --mode references --limit 50
```

复核：
```bash
grep -n 'target_app' app/app/application/services/info_crawl_service.py | grep 1177
grep -n 'search_backend' core/config.py                  # default="disabled"
sed -n '/adapters: dict/,/}/p' app/app/application/collectors/registry.py
```
