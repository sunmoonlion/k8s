# 数据与迁移

> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15
> 各仓表清单见 [`../repos/`](../repos/) 的 §5。

## 1. 一个 App 一个库，谁的表谁改

四个 App 各自持有自己的 PostgreSQL 库与迁移链，**不存在跨 App 直接读写对方表**的代码。
跨 App 传数据一律走 HTTP 契约（见 [`contracts.md`](contracts.md)）。

| 主档 | 归属 | 派生系统 |
| --- | --- | --- |
| 来源、采集作业、文档版本、原始制品 | info-app | Elasticsearch 索引（**默认关闭**，见下） |
| 摄入任务、知识文档与版本、Evidence | knowledge-app | RAGFlow（外部索引与检索引擎） |
| Agent session / run / 事件 / 副作用 / Pilot 请求 | investment-app | LangGraph checkpoint 表（同库） |
| 用户身份 `auth_user` | 各 App 各自一份 | Casdoor 为上游 IdP |

**派生系统可重建，主档不可**：info 的索引任务在 `SEARCH_BACKEND=disabled` 时直接 skip
（`info-app/.../info_crawl_service.py:1298-1300`，默认值 `core/config.py:180`）；
knowledge 在无 RAGFlow 凭据时摄入止于 `artifact_verified`，不写 document/version
（`knowledge_ingestion_service.py:519-531`）。两者都是「主档已落、派生未建」的合法状态。

## 2. 数据库双角色

每个 App 在 PG 里有两个角色：运行态用户与迁移用户。供给脚本为
`k8s/sunmoonai/utils/db-provisioner/drivers/postgresql.sh:3-11`（`dbctl` 驱动）。

investment-app 另有一步特殊处理：部署时在跑迁移 Job 前用 SQL 改 PG 角色的 LOGIN 状态
（`k8s/sunmoonai/app-platform/investment-app/deployment/deploy.py:141-169`），
info 与 knowledge 无此步。

运行态凭据按进程角色拆成多个 Secret，migration / API / Worker / Scheduler 各持最小权限
（`info-app/dev-to-prod-deploy/secret-conf/guide.md:6-12`）；前端不得持后端或 DB 凭据。
Secret 名清单在各 App 的 `release.json.external_secrets`。

## 3. 迁移纪律

| 规则 | 由谁保证 | 违反后果 |
| --- | --- | --- |
| 单链线性历史，无分叉、无 merge revision | 各仓 `tests/test_kernel_invariants.py`（info `:39-59`、knowledge `:39-63`、investment `:39-57`、tpl `:45-51`） | CI 失败 |
| 迁移由独立 Job 执行，跑完即删 | `k8s` 各 `deployment/deploy.py`（步骤 3） | — |
| 迁移失败或超时阻断整次 apply | `investment-app/deployment/deploy.py:197-199` | `DeployError: migration Job failed` |
| 迁移入口固定为 `python -m app.bootstrap.migration` | 各仓 `app/bootstrap/migration.py:20-38` | — |

迁移链的 head 是易腐值，本目录不记；查法见 [`../verify.md`](../verify.md) §2。
测试文件里那份 revision 顺序清单是链顺序的真源，改迁移必须同步改它。

## 4. Outbox / Inbox：四仓都有表，四仓都没接线

`outbox_message` 与 `inbox_message` 两张表、`SqlOutboxRepository` 仓库类、
`OutboxPublisher` / `OutboxRepository` 两个 Port，在 tpl / info / knowledge / investment
四仓中**结构完全一致且全部存在**，但**业务层零调用点**。

验证：`rg 'SqlOutbox|\.enqueue\(|claim_batch' <repo>/app/app --glob '!**/tests/**'`
在四仓中都只命中 `infrastructure/repositories/__init__.py` 与 `application/ports/__init__.py`
的再导出语句。

原因可从模板关系推断：这套原语是 tpl-app 的模板资产（`tpl-app` 迁移 `20260801_0002_outbox_primitives.py`），
三个实例各自继承了表与代码，但都没有在自己的领域服务里用起来。

**唯一真正在跑的 outbox 是 info-app 的另一张表**：`delivery_outbox_message`
（`info-app/.../infrastructure/models/info.py:194-229`），由 `delivery_outbox.py` 与
`app.tasks.dispatch_distribution` 驱动，用于向 knowledge 分发。它与共享 outbox 同名不同物，勿混。

## 5. 幂等与副作用

| 机制 | 位置 | 语义 |
| --- | --- | --- |
| Agent run 幂等 | `investment-app/.../repositories.py:64-77` | `session_id` + `idempotency_key` 唯一 |
| Pilot run 幂等 | `investment-app/.../pilot_repository.py:37-60` | `owner_actor_id` + `idempotency_key` 唯一 |
| 摄入任务幂等 | `knowledge-app/.../knowledge_ingestion_service.py:73-119` | 命中则返回已有 job |
| 副作用一次性 | `investment-app/.../repositories.py:272-295` | `tool_call_id` 为 PK + `ON CONFLICT DO NOTHING`，重复返回 `inserted=False` |
| Resume 令牌一次性 | `investment-app/.../pilot_repository.py:373-415` | 置位后不可复用，再用抛 `ValueError` |

## 6. 数据层组件在哪配置

`k8s/sunmoonai/data-platform/` 下八个子目录：`postgresql`、`redis`、`mongodb`、`neo4j`、
`elasticsearch`、`kibana`、`logstash`、`object-storage`。消息中间件不在此，在
`messaging-platform/`（RabbitMQ，Celery broker）。

四个 App 实际用到的：PostgreSQL（主档）、Redis（会话锁与 pubsub）、object-storage（制品）、
RabbitMQ（Celery）、Elasticsearch（info 索引，默认关闭）。
mongodb / neo4j / kibana / logstash 未见 App 侧引用。
