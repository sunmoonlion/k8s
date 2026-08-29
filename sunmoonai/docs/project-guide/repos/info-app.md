# info-app（资讯采集与治理）

> 取证时点：2026-08-29 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的东西

## 1. 定位

资讯域：从外部源采集内容 → 抽取 → 去重 → 人工治理 → 把可分发制品送给 knowledge-app。
它是 knowledge 的**唯一内容上游**。

后端约 90 个文件、7–8k 行。最大的单文件是 `info_crawl_service.py`（约 1.8k 行），
整条采集-治理-分发链都在里面。

## 2. 结构（只列模板之外）

| 路径 | 装什么 |
| --- | --- |
| `application/collectors/` | 采集器族 + 注册表，见 §4.1 |
| `application/services/info_crawl_service.py` | **本仓最大单文件**（约 1.8k 行），采集/去重/治理/分发编排 |
| `application/services/delivery_outbox.py` | 业务 outbox 生命周期 |
| `interfaces/endpoints/info_routes.py` | 领域路由（模板面在 `interfaces/http/`） |
| `interfaces/schemas/info.py` | 领域 schema |
| `tasks/` | `crawl.py` `distribution.py` `search.py` `ping.py` |
| `infrastructure/search/` | ES/OpenSearch 索引适配（**默认关闭**） |
| `infrastructure/external/knowledge_app.py` | 调 knowledge 摄入的客户端 |
| `cli/drain_delivery_outbox.py` | CronJob 用的有界单次扫描 |
| `contracts/knowledge-provider-lock.json` | artifact 契约的**消费锁** |

## 3. 硬规则

模板五项不变量原样存在（`tests/test_kernel_invariants.py`，92 行），**额外一项**：

| 规则 | 位置 |
| --- | --- |
| 业务 outbox 与共享 outbox 必须分表 | `test_business_and_shared_outboxes_remain_distinct`（`:62`） |

这条存在的原因见 §5——本仓有两套同名不同物的 outbox，容易混。

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
→ 按 canonical_url 归并文档 → **sha256 精确去重 + simhash64 近似去重**
→ content_hash 未变则跳过新版本，变了则建 clean/text 制品 + 新 `InfoDocumentVersion`
→ 索引（Celery 优先，broker 不可用时回落 API 内联；但 `SEARCH_BACKEND=disabled` 时直接跳过）。

### 4.3 分发 → knowledge

```
校验制品可分发性 → 组装 artifact v1 payload
  → 同事务写 distribution_record + delivery_outbox_message
  → Celery dispatch_distribution → POST knowledge 内部摄入端点
```

`delivery_outbox_message` 是**真正在跑**的 outbox，状态机四态：

```
pending → leased → published → completed
```

`completed` 表示**业务完成**（下游确认成功），不只是 broker 发布成功。
broker 发布失败只记录并 release，不抛出——**API 层不因 broker 故障返回 5xx**；
CronJob 跑 `cli/drain_delivery_outbox.py` 兜底。

## 5. 数据

迁移链 6 个版本，线性：

```
20260706_0001_info_spider_mvp → 0002_source_governance → 0003_auth_identity
→ 0004_delivery_outbox → 0005_outbox_primitives → 0006_delivery_outbox_uuid_default
```

领域表（`infrastructure/models/info.py`，9 张）：

`info_source` · `info_collector` · `crawl_job` · `raw_artifact` · `info_document` ·
`info_document_version` · `extracted_content` · `distribution_record` · `delivery_outbox_message`

**两套 outbox，同名不同物，勿混**：

| 表 | 语义 | 状态 |
| --- | --- | --- |
| `delivery_outbox_message` | info 分发专用业务 outbox | **接线并在跑** |
| `outbox_message` / `inbox_message` | 模板共享原语 | **零业务调用** |

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
| 共享 Outbox | 表与仓库类在，业务层零调用 |
| Celery beat | Scheduler 入口在，无调度定义 |
| `/api/internal` 入站面 | 无 router |
| Web interaction 生产可用 | 同模板：默认 503 |

## 8. 验证

```bash
cd <repo>/info-app/info-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && uv run pytest -q
uv run pytest tests/test_kernel_invariants.py -q      # 6 项

# 单次 outbox 扫描
uv run python -m app.cli.drain_delivery_outbox --limit 50
```

复核：
```bash
grep -n 'target_app' app/app/application/services/info_crawl_service.py | grep 1177
grep -n 'search_backend' core/config.py                  # default="disabled"
sed -n '/adapters: dict/,/}/p' app/app/application/collectors/registry.py
```
