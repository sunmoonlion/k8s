# ADR-0010：每个 App 收敛一个逻辑数据库和一条迁移链

- 状态：已接受
- 日期：2026-08-01

## 背景

旧 Admin/Web Backend 可能拥有独立数据库角色、迁移目录、认证表或业务表。直接合并迁移
文件会产生 revision 冲突、表名冲突、重复主档和不可回滚切换；长期双写会破坏唯一事实源。

## 决策

- 每个领域 App 最终只有一个逻辑 PostgreSQL 数据库、一个应用写入角色和一条 Alembic head；
- Redis、S3、Elasticsearch、RAGFlow 等仍按既有数据所有权作为缓存、对象、索引或派生系统；
- 迁移前生成表、约束、索引、revision、数据量、所有者、Secret、备份和消费者清单；
- 采用 expand -> backfill -> reconcile -> switch read -> switch write -> observe -> contract；
- 旧写路径切换时必须 fail-closed，不能无期限双写；
- 必要双写必须有事务 Outbox、幂等、版本和对账，且有明确截止任务；
- 迁移由独立 Job 执行，API/Worker 启动不得隐式升级数据库；
- 回滚窗结束前保留旧库备份、旧角色定义和恢复演练证据；
- 禁止跨 App 合并数据库或直接读表。

## 门禁

- 可恢复备份和实际恢复演练；
- 回填计数、哈希/抽样和业务不变量对账；
- 新旧读路径结果对比；
- 旧凭据在切换后被拒绝；
- migration current 只有一个 head；
- 回滚和重新前滚均通过。

## 结果

数据库归并成为显式数据迁移项目，而不是源码目录合并的副作用。
