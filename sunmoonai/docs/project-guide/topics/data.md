# 数据与迁移

> 源码复核：2026-09-13 ｜ 相关规则见 [`../../dev-agent/composition/constraints.md`](../../dev-agent/SDD/constraints.md)「数据」D1–D9

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

这是约束第 2 条（单一主档）与第 5 条（RAGFlow 是派生系统）的直接后果，
代码里有两处可观察的体现：

- info 的索引任务在 `SEARCH_BACKEND=disabled` 时**直接跳过**（默认就是 disabled）
- knowledge 在无 RAGFlow 凭据时摄入止于 `artifact_verified`，**不写** `KnowledgeDocument*`

两者都是「**主档已落、派生未建**」的**合法状态**，不是故障。

RAGFlow / Elasticsearch / 向量 / 缓存**都不能**当作权威业务记录。

## 3. 数据库运行身份：旧供给与新候选分开

业务 KIND 最近只读核查仍是运行态共享用户与独立 Migration owner；API/Worker/Scheduler
不是已完成最小权限拆分。旧 `utils/db-provisioner/` 和实例供给脚本不能冒充新策略。
当前源码已有四角色候选：API 接受业务意图、Worker 消费/回执、Scheduler CONNECT-only、
Migration 拥有迁移对象。模板按六张表精确列授权，三个实例各有领域扩展；未知清单拒绝。
真实登录与联合投递已在临时环境验证，**加法 GRANT 不会撤掉旧 PUBLIC/继承/default ACL**。
候选真源为 `tpl-app/k8s-deployment/runtime_database_policy.py` 与各实例 deployment 的
`*_database_policy.py`。角色独立 Secret 键和实际账号权限须一并供给，不可只复制旧 URL。
**前端不得持有后端或数据库凭据。**Secret 名仍从具体 release 的 external_secrets 查。

investment-app 另有一步特殊处理：部署时在跑迁移 Job **之前**用 SQL 改 PG 角色的
LOGIN 状态；info 与 knowledge 无此步。

## 4. 迁移纪律

### 做数据迁移时

程序（七步、fail-closed、六条验收）是**规则**，不写在投影里：
见 [`../../dev-agent/composition/constraints.md`](../../dev-agent/SDD/constraints.md)「数据」。

## 5. 共享可靠投递已接入业务

四仓共享 `outbox_message`、`inbox_message`、`outbox_dead_letter`、`outbox_execution`；
`application/services/durable_tasks.py` 与 `infrastructure/messaging/durable_delivery.py`
提供事务意图、有限投递、租约/epoch、提交前 fencing、Inbox、死信、显式重放和对账。
API 只接受持久意图；Beat 发 pump 提示，数据库 pump/consume 由 Worker 执行。
Info 采集/索引/分发、Knowledge 摄入/轮询均已接入；Investment 在公共策略上扩展会话
执行与 Redis 通知，不另建 publisher/死信真源。旧 Info 分发日志和旧 Agent 死信仅保留
受保护的回滚档案，不再接受新业务写入。

broker ACK、控制探针 pong、已提交 Inbox、Provider 业务成功是不同证据。释放租约保留
epoch 墓碑并显式标失效，立即重排不再依赖墙钟门槛；真实预约/退避仍按 DB 时间执行。
Knowledge 对未知外部写入结果保留操作账并阻断盲目重传。**不能按固定天数直接删
Outbox/Inbox/死信/租约**：去重、回滚、Provider 回执和迟到执行者仍可能引用它们。
来源、验证和未完成保留策略见[保留保护条件](../../legacy-backlog/deployment-checklist.md)。

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
