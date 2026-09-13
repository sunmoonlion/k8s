# B7o：模板数据库分角色权限与真实拒绝测试（Luna）

日期：2026-09-13。单人实施、自测；模板候选已验证，未部署、未接业务凭据供给。
承接 [B7n 权限实查](v5-backlog-runtime-permissions-luna.md)，执行边界仍为
[逐步处置清单](v5-backlog-disposition-luna.md)的“完成本批后统一集成/同步”。

## 1. 冻结对象与结果

本包只实现模板数据库这一子项，不同时扩展三领域或 RabbitMQ：

- tpl-app 新增 `k8s-deployment/runtime_database_policy.py`，纯权限 SQL 编译函数。
- 新增普通单元测试及 `k8s-deployment/integration/test_runtime_database_policy_pg.py`，
  更新该部署目录 README；不修改 Backend、迁移、依赖、镜像、deploy.py 或 gitlink。
- k8s 仅本报告、处置清单和覆盖矩阵；两份未跟踪 general/pro 草案不动。

开工 tpl-app `10acfdcf`、tpl-backend `a91eb3e`、k8s `e1c84246`。
模板最终固定提交 **`a4d300fbd3417302d6c41d4d4e59599b3432b0a5`**。
tpl 父仓 backend 索引仍是 `53698628c5d26c9af933fd3fe567d239e7d3ecce`；
原 `M tpl-backend` 保留，未顺带更新。四后端、三个领域父仓既有增量均未改。
不新增分支、不合并 master、不推送、不构建、不操作云端或业务集群。

| 规则 | 落实 |
| --- | --- |
| D1/D2/D3/D8 | 仅一次性 PG 的独立测试库；由真实 migration 登录跑现有模板迁移，运行账号不迁移 |
| I3/I8/D9 | 四独立 LOGIN、四独立随机密码；跨库/换用 migration 密码拒绝；不带业务凭据 |
| R6/T3 | 公共候选先进模板，先过模板门禁；未将未评审的权限套入三领域，不另造 Backend |
| R1/T4/T5 | 固定模板父仓提交与原 Backend 分列；纯源码候选，不动 gitlink/运行发布 |

源码回滚用反向本包提交即可，未产生业务状态回滚需要。测试容器创建/删除、真实测试
连接均通过平台批准；不存在对业务库“先试写再 rollback”。

## 2. 权限候选的精确能力

编译器校验四角色名不同、安全 SQL 标识符、迁移后六张表的完整列名集合；未知表、
缺表、加列均拒绝。不用 `ALL TABLES`、`ALL PRIVILEGES`、自动发现后全量授予等规则。
六张表：auth_user、alembic_version、outbox_message、inbox_message、
outbox_dead_letter、outbox_execution。

| 角色 | 候选授权 | 不授予 |
| --- | --- | --- |
| API | 六表 SELECT；身份绑定指定列 INSERT/UPDATE；Outbox 意图七列 INSERT、仅 deduplication_key 列 UPDATE | 版本表写、身份主键/issuer/subject 更新、消息状态/租约/载荷更新、伪造 Inbox、死信/执行账写、删除 |
| Worker | 版本表及四投递表 SELECT；Outbox 意图 INSERT；Outbox/死信/执行账 UPDATE；Inbox/死信/执行账 INSERT | auth_user 访问、版本表写、删除回执/租约墓碑/Outbox、DDL |
| Scheduler | 编译器不授 schema/表权限；测试外部供给仅给本库 CONNECT | 业务表和版本表读写、建 schema/临时表、角色提升 |
| Migration | 编译器不另授；测试中由本库 owner 登录真正执行模板单链迁移 | 三运行账号不能 SET 为 migration；migration 也不能连接另一 owner 的测试库 |

API 的幂等写使用原 `SqlOutboxRepository.enqueue`：ON CONFLICT 会无操作更新去重键。
不能仅授 INSERT，也不需要由此授整个 Outbox UPDATE。Worker 的实际 pump、consume、
renew/release/replay/reconcile 分别需要这些指定表的 INSERT/UPDATE，而非一概 CRUD。

这是可信 Backend 进程间的权限缩小，**不是行级/租户/工具授权**。API 仍有能力直接修改
已获授权的去重键列，ACL 本身不强制它只能做无操作更新；Worker 的应用租约谓词也
不是这里新造的数据库 RLS。不能把这组账号直接交给不受信 Agent 或浏览器。

## 3. 严格区分权限编译与供给

编译器无连接、无密码、无 CREATE ROLE、无撤权/owner/default ACL 修改、无 apply 入口；
它返回的是加法 GRANT，**不能将已有宽权限角色自动收紧**。其使用前置必须由实际供给器
检查并建立：全新独立账号、正确 owner、无继承越权、关闭 PUBLIC/默认授予、完整对象基线。
表/列匹配也不代替类型、索引、触发器、函数、RLS 和有效权限审计。

本包的供给代码仅为隔离测试 fixture：在新库撤 PUBLIC 的库/schema 权限、关闭该创建者
的新表/序列/函数 PUBLIC 默认权限，再迁移、编译、授予。没有声称这能处理当前业务库的
历史角色、旧 creator/default ACL 或共享 Secret。生产供给器及有效权限前置仍待实现。

负对照实际证明：先给 API 版本表整表 UPDATE，再撤该列 UPDATE，原整表权限仍生效；
撤整表权限后才真正拒绝。新建未评审表时运行角色读写失败，编译器也拒绝扩展后的清单。
这与 [PostgreSQL GRANT](https://www.postgresql.org/docs/17/sql-grant.html) 的加法授权/
表列权限语义一致；默认权限只影响未来对象，不能替代已有对象撤权，参见
[ALTER DEFAULT PRIVILEGES](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html)。

## 4. 隔离环境与验收

新建独立容器 `luna-b7o-pg`，完整 ID：
`30e58b5b4c8a415c439310e8083ff3a3236f98e43001b532151d951562aa623b`。
缓存镜像 `bitnami/postgresql:17.6.0-debian-12-r4`，本地 image ID `dbd371582fbb`；
256 MiB / 1 CPU，仅 `127.0.0.1:55439`，无业务目录挂载。没有新建 RabbitMQ 或 KIND。

测试必须给显式环境确认和精确 loopback/端口/测试库；缺失时错误退出，不 skip。
连接前另外核对 Docker 完整 ID、标签、挂载、端口与 Ready，不能只凭 `_tests` 后缀
判断目标安全。每例新建随机命名的两个库及四 LOGIN，密码只在 fixture 内存中；
API/Worker/Scheduler/Migration 都以自己的连接认证，不用管理员 SET ROLE 代替登录。

18 项真实 PG 测试包括：

- 四身份/owner、原 readiness 版本检查；原 AuthService 身份创建和更新不变 ID。
- API 原 enqueue 幂等复用、异载荷冲突、事务回滚；禁止改投递状态/租约/载荷或伪造回执。
- Worker 原 pump/consume，跟进意图与 Inbox 同事务提交、重复消费不重复；原只读指标
  在 API 身份下正确读取已提交回执。publish 使用合成回调，**不是 RabbitMQ 发送验收**。
- handler 中途写入后失败整体回滚；发布失败落死信、重放、缺回执对账恢复。
- 真正 renew、过期后新 epoch、旧 owner 续租拒绝、迟到 release 不覆盖新 owner；
  release 保留墓碑，不需要 DELETE 权限。
- 三运行角色版本表写、DDL、schema/临时表创建、SET migration、删除投递账等均返回
  PostgreSQL **42501**；Scheduler 指定 schema 的 SELECT 也被拒绝。
- 四角色连接另一 owner 的数据库均 **42501**；三个运行密码不能认证 migration，
  返回 **28P01**，不是连接不通或任意异常当拒绝。
- 未来新表默认拒绝、未知清单拒绝，以及旧整表权限的负对照。

普通 unittest 自动收集编译器的 4 项新测试，模板原 8 项仍通过。真实 PG 测试需显式
运行上述 integration 文件，README 已记运行命令；**尚未接远端 CI**，不称每次提交自动
验收真实 PG。没有跑四后端全量用例，四后端本包没有改动；没有三领域真实权限验收。

## 5. 失败及修复，不放宽验收

1. 首轮 Scheduler 负向 SQL 未限定 schema：schema 无 USAGE 导致搜索路径不可见，
   返回 42P01 而非 42501。改为 `public.表名`，保留严格 42501 断言；不增加 Scheduler
   权限，也不接受“任何数据库异常”。修复后 12 项通过。
2. 首次失败的 pytest fixture repr 含临时合成密码；这些随机账号已在该次 teardown
   删除。改为固定脱敏 repr，后续真实测试验证四随机密码均不会进入 repr；不是业务
   凭据泄露，不轮换业务账号。随后增加不同密码、回滚与 fencing，17 项通过。
3. 增加 migration 跨库拒绝时，测试库 `CREATE DATABASE ... OWNER CURRENT_USER`
   语法不成立。改为该隔离环境已锁定的 `"postgres"` owner，不扩大 migration 权限；
   失败 fixture 的已创建对象已清理。最终 18 项通过。

一次旧平台渲染回归在异步模板测试返回错误后仍被启动；它不应用新权限，但不计为
本轮模板先行的最终门禁。修复后等待模板固定提交完整通过，再依次重跑 Info、
Knowledge、Investment，最终顺序见下表；没有将失败候选推广至任何实例。

## 6. 固定版本复验与清理回执

| 固定对象 / 门禁 | 最终结果 |
| --- | --- |
| tpl-app a4d300f，三 Python 文件 Ruff | 通过 |
| tpl-app a4d300f，普通脚手架/权限单元 | 12 tests，0.188 秒，零跳过 |
| tpl-app a4d300f，真实隔离 PG | 18 passed，8.30 秒，零跳过 |
| k8s 原 e1c84246，既有测试+Info 渲染 | 24 tests，0.695 秒 |
| 随后 Knowledge 渲染 | 3 tests，0.682 秒 |
| 最后 Investment 渲染 | 3 tests，0.637 秒 |

平台合计 30 项，仅验证已有渲染/发布脚本未被模板候选影响，**不是三实例权限已对齐**。
权限编译器 SHA-256：`778ed257ee673c5e9ba9cb0efda2ed99fff7969c90735fe15cbaf308466860ff`。
真实 PG 测试 SHA-256：`d8e69640cff57f41e2fbbc46c41577402c892dbde474a9d47912235992b0b3be`。

最终只读查询测试 PG：`b7o_` 测试库与测试角色均 **0**。核对完整容器 ID/挂载后停止
并 `docker rm -v` 删除该容器及三个已确认匿名卷，重新列卷确认三者均不存在；仅删除
可重建的合成数据。原 KIND 三容器、旧 gifted_chaum 和缓存镜像均保留。
没有遗留测试进程、业务 Job、文件型 kubeconfig 或持久化凭据文件。

下一子包继续逐领域冻结权限 overlay、真实用例验证；RabbitMQ 生产/消费/pidbox、
Scheduler 实际启动发送、历史权限收敛/凭据供给、受控切换仍在 B7 留账。本包不把这些
迁入未来计划，也不宣称 B7 整包结束或开始 B9 同步。
