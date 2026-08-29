# 数据与迁移

> 取证时点：2026-08-29 ｜ 决策来由见 [ADR-0002](../decisions/0002-system-of-record.md)、
> [ADR-0004](../decisions/0004-object-storage-ownership.md)、[ADR-0010](../decisions/0010-database-convergence.md)

## 1. 一个 App 一个库，谁的表谁改

四个 App 各自持有自己的 PostgreSQL 逻辑库与迁移链。
**代码中不存在跨 App 直接读写对方表的路径**——跨 App 传数据一律走 HTTP 契约。

| 主档 | 归属 | 派生系统 |
| --- | --- | --- |
| 来源、采集作业、文档版本、原始制品 | info-app | Elasticsearch 索引（**默认关闭**） |
| 摄入任务、知识文档与版本、Evidence | knowledge-app | RAGFlow |
| Agent session / run / 事件 / 副作用 / Pilot 请求 | investment-app | LangGraph checkpoint 表（同库） |
| 用户身份 `auth_user` | 各 App 各自一份 | Casdoor 为上游 IdP |

物理资源可以共享（同一个 PostgreSQL 集群），但必须用独立逻辑库、角色、Secret、
备份与访问策略。对象存储同理：独立 bucket、凭据、生命周期。

## 2. 派生系统可重建，主档不可

这是 [ADR-0002](../decisions/0002-system-of-record.md) 与
[ADR-0005](../decisions/0005-ragflow-as-derived-system.md) 的直接后果，
代码里有两处可观察的体现：

- info 的索引任务在 `SEARCH_BACKEND=disabled` 时**直接跳过**（默认就是 disabled）
- knowledge 在无 RAGFlow 凭据时摄入止于 `artifact_verified`，**不写** `KnowledgeDocument*`

两者都是「**主档已落、派生未建**」的**合法状态**，不是故障。

RAGFlow / Elasticsearch / 向量 / 缓存**都不能**当作权威业务记录。

## 3. 数据库双角色

每个 App 在 PG 里有两个角色：运行态用户与迁移用户
（供给脚本在 `k8s/sunmoonai/utils/db-provisioner/`）。

运行态凭据再按进程角色拆成多个 Secret——migration / API / Worker / Scheduler
各持最小权限。**前端不得持有后端或数据库凭据。**
Secret 名清单在各 App 的 `release.json.external_secrets`。

investment-app 另有一步特殊处理：部署时在跑迁移 Job **之前**用 SQL 改 PG 角色的
LOGIN 状态；info 与 knowledge 无此步。

## 4. 迁移纪律

| 规则 | 由谁保证 | 违反后果 |
| --- | --- | --- |
| **单链线性**，无分叉、无 merge revision | 各仓 `test_one_linear_canonical_migration_chain` | CI 失败 |
| 迁移文件名清单**逐字**匹配测试里的列表 | 同上 | CI 失败 |
| 恰好一个 `down_revision = None` | 同上 | CI 失败 |
| 迁移由独立 Job 执行，跑完即删 | 各 `deployment/deploy.py` | — |
| 迁移失败或超时**阻断整次 apply** | 同上 | `DeployError` |
| 迁移入口固定 `python -m app.bootstrap.migration` | 各仓 `bootstrap/migration.py` | — |

**改迁移必须同步改 `test_kernel_invariants.py` 里那份文件名清单**，否则 CI 失败。
那份清单是链顺序的真源。

各仓链长度（不含 `__init__.py`）：tpl 2 · info 6 · knowledge 5 · investment 5。
迁移 head 是易腐值，本目录不记，查法见 [`../verify.md`](../verify.md)。

## 5. Outbox：四仓都有表，四仓都没接线

`outbox_message` 与 `inbox_message` 两张表、SQL 仓库类、两个 Port，
在四个仓中**结构完全一致且全部存在**，但**业务层零调用点**。

来源可从模板关系推断：这是 tpl-app 的模板资产（迁移 `20260801_0002_outbox_primitives`），
三个实例各自继承了表与代码，但都没有在自己的领域服务里用起来。

**这属于「模板有意留白」，不是缺陷**——但读代码时极易误认为"事件发布已经做好了"。

**唯一真正在跑的 outbox 是 info-app 的另一张表**：`delivery_outbox_message`，
状态机 `pending → leased → published → completed`，由 `delivery_outbox.py` 与
`dispatch_distribution` 任务驱动。它与共享 outbox **同名不同物**，
info 仓专门有一项不变量测试（`test_business_and_shared_outboxes_remain_distinct`）
把两者钉开——这项测试的存在本身就是"容易混"的证据。

## 6. 幂等与副作用

| 机制 | 位置 | 语义 |
| --- | --- | --- |
| Agent run 幂等 | investment `infrastructure/agent/repositories.py` | `session_id` + `idempotency_key` |
| Pilot run 幂等 | investment `pilot_repository.py` | `owner_actor_id` + `idempotency_key` |
| 摄入任务幂等 | knowledge `knowledge_ingestion_service.py` | `idempotency_key` 命中则返回已有 job |
| 分发幂等键 | info | `info-app:{version_id}:{dataset_key}:artifact-v1` |
| 副作用一次性 | investment `side_effect_service.record_once` | `tool_call_id` 为 PK + `ON CONFLICT DO NOTHING` |
| Resume 令牌一次性 | investment `pilot_repository.consume_resume` | 置位后不可复用 |

## 7. 数据组件在哪配置

`k8s/sunmoonai/data-platform/` 下八个子目录：postgresql · redis · mongodb · neo4j ·
elasticsearch · kibana · logstash · **object-storage**（目录名不是 minio 或 s3）。
消息中间件不在此，在 `messaging-platform/`（RabbitMQ）。

**四个 App 实际用到的只有**：PostgreSQL、Redis、object-storage、RabbitMQ、
Elasticsearch（info，默认关闭）。**mongodb / neo4j / kibana / logstash 未见任何 App 侧引用。**
