# B7n：运行身份有效权限与供给边界（Luna）

日期：2026-09-13。单人实施、自测；只读目录核查完成，不是权限拆分或部署验收完成。
承接 [B7m 渲染修复](v5-backlog-runtime-rendering-luna.md)及
[B7l 运行预检](v5-backlog-runtime-preflight-luna.md)。

## 1. 冻结范围与基线

所有者“继续”，沿用[逐步处置清单](v5-backlog-disposition-luna.md)：
先完成本批处置，最后统一集成和同步。本包仅新增 k8s 的只读目录采集器、测试、本报告，
更新处置清单及覆盖矩阵；不修改四后端、模板/实例渲染、旧发布产物、gitlink 或 master。
不新增分支、不推送、不接触云端、不创建/轮换/撤销身份、不发布/消费消息、不迁移或部署。

开工 k8s `78f375bf76c0ee5aaf0cf349ff5732c95f56a9c7`，tpl 父仓 `10acfdcf`；
四后端 tpl `a91eb3e`、Info `7dafb34`、Knowledge `5df4f17`、Investment `3d9531d`。
既有父仓 backend gitlink 差异、三个领域父仓对齐报告增量、两份未跟踪协议草案全部保留。

| 规则 | 本包落实 |
| --- | --- |
| D1/D2/D3/D8 | 每个 Pod 只用自己的 App 数据库身份查系统目录；不读业务行、不跨 App 查表，不运行迁移 |
| I3/I8/D9 | 不打印 URL/密码/错误正文；不拿管理员身份替代运行角色，不将凭据送到前端 |
| T3/R6 | 平台只读验收工具统一一份，不修改公共 Backend 能力；模板门禁先验，再 Info→Knowledge→Investment |
| R1/T4/T5 | 固定源码与实际镜像证据分列；本地候选，不中间同步、不更新父仓 gitlink |

回滚仅反向本包源码提交；没有集群写入需要回滚。只读 exec 已走平台权限批准。

## 2. 新工具及安全边界

工具：`sunmoonai/app-platform/scripts/audit_runtime_database_permissions.py`。
用 Backend 自带 Python 执行，从 `core.config.get_settings().database_url` 取得已规范化的
asyncpg URL；不接受命令行 URL，不将凭据传回本机，不调用任何旧供给脚本。

- 单连接、单次 `REPEATABLE READ, READ ONLY` 事务；先设 `search_path=pg_catalog`。
- SQL 只读取系统目录和权限函数：身份、可继承/可 SET 的角色、业务 schema、表/视图、
  序列、用户 schema 函数的所有者/SECURITY DEFINER/EXECUTE、显式 default ACL。
- 不读 `pg_authid`/`pg_shadow`、角色配置、函数正文、业务记录或原始 Secret。
- 检查列级权限、owner 可用性和 SET 路径，不能只看直接 GRANT 或超级用户标志。
- 每节最多 2000 行，查询取 2001 行发现溢出即失败，不截断后宣布完整；连接 5 秒、
  每语句 3 秒、锁等待 1 秒、总协作式 timeout 15 秒；不宣称操作系统级硬杀保证。
- 先完整 JSON 序列化才输出；失败退出 1，诊断只含白名单类别/固定查询节名/SQLSTATE。
  外部取消传播，不输出半份成功报告，也不打印底层连接异常。
- 成功标记是 `status=collected, permission_acceptance=not_evaluated`，不是安全门禁通过。

此工具没有执行拒绝试验：`has_*_privilege` 表示 ACL 能力，不保证某条实际 SQL 成功，
还可能受 schema、触发器、RLS 等限制。default ACL 没有记录也不代表默认零权限。
未覆盖系统 schema 函数、large object、FDW、每列明细、全部管理选项或 PG17 MAINTAIN，
不能据本工具作“全权限审计通过”。角色 MEMBER/USAGE/SET 与对象权限的区别按
[PostgreSQL 17 权限查询函数](https://www.postgresql.org/docs/17/functions-info.html)
核对；对象所有权也不能用简单 REVOKE 等同去除，见
[PostgreSQL GRANT](https://www.postgresql.org/docs/17/sql-grant.html)。

复跑方式：先重新核对 KIND/namespace UID、实际 Pod UID/镜像，再将工具通过 stdin
送入已批准 Pod 的 `/app/.venv/bin/python -`。不要复制到业务容器或从旧 Pod 名直接盲跑。
工具需要 PostgreSQL 16+；环境不符、连接失败、目录不完整均不产生验收通过。

## 3. 九角色 PostgreSQL 实查

正式修复后采集 UTC **09:11:08～09:11:58**（北京时间 17:11）。
当前仍为 B7l 的本地 kind / app-platform-dev，12 个后端 Pod 均 Running/Ready；
每 App 选 API 一副本及唯一 Worker/Scheduler，共九个独立连接、九份完整结果。
Pod 名与 imageID 再核均未变，仍是 B7l 列出的 9 月 11 日旧镜像，不含本批新后端代码。
采集器从 stdin 执行并不改变镜像，不能据此声称工具或修复已随镜像部署。

| App | 各三角色实际 principal | 逻辑库 | 普通表数 | DB/public schema/表 owner |
| --- | --- | --- | --- | --- |
| Info | info_backend_user | info_admin | 15 | info_backend_user_migration |
| Knowledge | knowledge_backend_user | knowledge_admin | 10 | knowledge_backend_user_migration |
| Investment | investment_backend_user | investment_admin | 18 | investment_backend_user_migration |

九个连接一致：PostgreSQL `170006`，session_user=current_user，事务 readonly=on，
isolation=repeatable read；superuser/createdb/createrole/replication/bypassrls 均 false，
可到达其他角色列表为空。当前库 CONNECT 和 TEMPORARY 为 true，CREATE 为 false；
public USAGE=true、CREATE=false；不能立即使用或 SET 成 schema/表 owner。

每个库上表列出的全部普通表，三个运行身份均有 SELECT/INSERT/UPDATE/DELETE，
TRUNCATE/REFERENCES/TRIGGER/grant option 均 false。**包含 `alembic_version`**：
ACL 层面允许运行角色改版本记录，这是待修权限，不把“没有 DDL 权限”当完整隔离。
没有执行 UPDATE/DELETE 验证，未改任何版本记录。三个库本次目录均无用户序列。

Info/Knowledge 各 10 个 UUID 扩展函数，均可 EXECUTE、非 SECURITY DEFINER；
Info 函数 owner 仍为 `info_admin_user_migration`，Knowledge 为 postgres。
Investment 一个 `agent_delivery_archive_readonly`，owner 为当前 migration 角色，
可 EXECUTE、非 SECURITY DEFINER。其旧归档的 DELETE ACL=true **不代表删除可成功**，
[B7j](v5-backlog-worker-progress-luna.md) 已实证触发器仍拒绝旧归档写入。

默认权限事实：

- 三库当前 migration creator 都仍给旧 runtime 用户授新表 CRUD、新序列 USAGE/SELECT/UPDATE。
- Info/Knowledge 还保留旧 migration creator 对旧 admin/runtime 的 default ACL，
  以及 postgres creator 对旧 admin 的新表全部七项旧式表权限授权。
- 这些是未来对象授权规则，不等于旧角色当前还能登录；本包未核全部旧角色 LOGIN/连接。
  只撤现有表授权、不清理正确 creator 的 default ACL，会在后续迁移中重新扩大权限。

## 4. RabbitMQ 配置与实际授权

分别从九个 Pod 的 Settings 在 Pod 内解析，只输出 username/vhost/queue、是否配置
result backend；不输出 URL、密码，也未用这些连接发布或消费。每 App 三角色完全一致：

| App | 用户 | vhost | 业务队列 |
| --- | --- | --- | --- |
| Info | info-admin-backend-worker | info-development | info.admin.default |
| Knowledge | knowledge-admin-backend-worker | knowledge-development | knowledge.admin.default |
| Investment | investment-backend-worker | investment-development | investment.default |

九个 Pod 当前 result backend 均未配置。配置用户名不是认证成功证明，但随后对真实
`rabbitmq-sunmoonai-0`（UID `2d6c8230-32e0-470b-8645-05601dcdaf43`，Ready）执行
三个 vhost 的 `rabbitmqctl list_permissions --formatter=json`：上述用户确有授权，
各用户的 configure/write/read 表达式相同，覆盖各自业务队列及 Celery 控制/回复资源；
包含未收尾的 `^celery` 前缀，不能声称仅允许精确列出的资源。
Info/Knowledge 另有 producer 用户，但权限仍与 worker 同形，当前 Pod 也没有使用它。
三个 vhost 的 admin 另有全权限；本包没有查询其他 vhost 或全部用户标签/身份后端，
不据本次结果证明这些用户不能访问任何其他 vhost。

RabbitMQ 的资源授权与具体 AMQP 操作有关，不能把“API 是生产者”简化成只给 write，
忽略 Kombu 自动声明/绑定；也不能给 API 业务队列 read 后宣称它不能消费。
候选策略需在实际 Celery/Kombu 配置下试验，语义依据
[RabbitMQ 访问控制](https://www.rabbitmq.com/docs/access-control)。

## 5. 旧脚本为何不能直接用于本轮供给

1. `docs/architecture-v2/scripts/run_r3_template_gate.sh` 是模板全环境门禁：创建命名空间、
   身份、数据库，部署并清理；虽然 DB 分三个角色，broker 仍共用 Redis 密码。
   路径也不是本轮 Luna。未运行。
2. `provision_r5_info_database_roles_kind.sh` 及 Knowledge 变体：目标是旧 runtime/migration
   二分，runtime 授全表 CRUD，并写 default ACL；不是 API/Worker/Scheduler 三分供给。
   本轮没有 `--apply`、未创建临时 Secret。
3. `app-platform/scripts/prepare-investment-broker-kind.sh`：会改共享启动 definitions、
   授统一用户同形权限，删除旧队列/用户，并可能重启三个 Deployment。源码还有固定开发
   密码值；本报告不抄值，未断言它与实时密码一致。需纳入 Secret 扫描/受控替换旧账，
   不能靠删源码声称凭据已轮换。本轮没有运行该脚本。
4. Investment `deployment/deploy.py` 的 migration 前还会改旧角色 LOGIN/NOLOGIN。
   后续部署必须拆清这一副作用，不能认为“只换镜像”。

## 6. 下一供给工作单元的决策与验收

沿用 B7m 的 `<app>-backend-runtime` 分角色键及独立 migration Secret；不另造一套
连接配置。**每角色必须是真实不同 principal/user，而非同一 URL 换三个键。**
先实现、验证可丢弃环境的供给与拒绝矩阵，再单列实际集群切换批准；不直接套旧脚本。

| 角色 | 当前源码实际职责与候选权限边界 | 必须证明的拒绝/正向场景 |
| --- | --- | --- |
| API | application 业务事务、创建 Outbox、只读版本/指标；诊断 ping 仍可发布消息 | 正常用例成功；不能改 alembic_version、DDL、SET migration、读其他 App；不能消费业务队列 |
| Worker | pump/consume 实际读写 Outbox/Inbox/租约和领域数据；会继续发布 execute 消息 | 正常处理/重试/死信/恢复；权限不能仅为 consume；拒绝版本表写、DDL、其他 App |
| Scheduler | ObservedScheduler 基于 PersistentScheduler，Beat 发 pump；不是它执行 pump 的 DB 事务 | 先试独立 CONNECT-only DB 身份，不授业务表读写；实际 Beat 启动/周期发送成功，业务表写/消费拒绝 |
| Migration | 独立 Job 拥有当前 App 对象，按单链迁移 | 运行 Pod 不带其凭据且不能 SET；可迁移并验证新表 ACL，不获得其他 App 权限 |

源码依据（各 Backend `app/` 下）：`app/bootstrap/scheduler.py`、`app/worker.py`、
`app/tasks/durable_delivery.py::_run`、`app/infrastructure/messaging/celery_producer.py`；
Investment 另有 agent delivery 发布。API/Worker 的精确逐表/逐操作 allowlist **尚未冻结**，
不得为了“先可用”执行 `GRANT ... ON ALL TABLES`。Scheduler 的 CONNECT-only 也是
待隔离实测候选，不冒充已经通过或擅自删除模板所要求的 DATABASE_URL 引用。

后续实施验收必须同时包含：

1. 模板先验证角色供给、现有/新表权限，串行三实例领域用例；未知表默认不放行。
2. alembic_version 运行身份只读、旧归档保持只读；DML/DDL/SET ROLE/列权限/继承/
   PUBLIC/default ACL 的实际拒绝。受控测试先在可丢弃 PG，不向业务表试写再 rollback。
3. Worker 本节点 readiness 的 active_queues/registered 依赖 pidbox/reply；按当前
   Celery/Kombu 实测所需队列/交换机/绑定权限，不删探针或放宽到 `.*` 来过门禁。
4. API/Scheduler 生产成功但业务消费失败；Worker consume、再 publish、迟确认/恢复成功；
   跨 vhost 拒绝；明确控制消息按资源隔离不等于能按同一 pidbox 中的命令内容授权。
5. broker 活跃拓扑与启动 definitions 同步受控更新，重启后不恢复旧用户/宽权限；
   凭据从受保护供给面进入，不将密码/URL/密码 hash 当普通版本化配置。
6. 切换前冻结 UID/版本、权限定义、实际可恢复备份/恢复演练、旧消费者排空；新旧权限
   有明确观察/撤销窗口。轮换或 NOLOGIN 不自动终止既有连接，需另核连接排空和拒绝。
7. 任一步失败停下一个 App；不先撤旧凭据制造停机。回滚同时考虑源码、DB revision、
   Secret/默认 ACL/broker definitions，不用旧镜像直连超前 schema。

以上权限供给和实际切换仍留 B7，不伪装成已迁入未来 N4。Prometheus/Alertmanager
仅原已批准的监控子项留 N4-OPS-01，和这里的身份问题分开。

## 7. 测试、失败根因与交付状态

新增 7 项单元测试：只读设置顺序、目录边界、版本/会话身份失败关闭、溢出不截断、
完整输出/脱敏、SQLSTATE 白名单、deadline/外部取消。常规 unittest discover 自动收集；
这些 fake connection 测的是控制与脱敏，不冒充真实 SQL 或实际拒绝试验。

首个真实 Info 查询失败：目录结果中的 `pg_class.relkind` 与
`pg_default_acl.defaclobjtype` 是 PostgreSQL 内部 `char`，asyncpg 返回 bytes，JSON
序列化抛 TypeError。通过只打印字段路径/类型的诊断确认，不输出字段值或异常正文。
修为 SQL 显式 `::text`；测试锁定转换，且仍拒绝意外不可序列化对象，不加 `default=str`
吞掉未知类型。随后同一工具在九个真实运行角色全部采集成功，非提高权限后重试。

初轮 Ruff 提示 CLI 的宽异常捕获：这是必要的最终脱敏边界，局部注明理由；查询边界
只转出固定节名/SQLSTATE，外部取消继续传播。不全局禁用规则或打印异常来绕过检查。
一次补丁因格式化后上下文不同被拒，未产生部分修改，按实际内容重新应用。

候选回归：Ruff 两文件通过；模板脚手架 8 项（0.213 秒）；平台已有测试+新增 7 项+
Info 渲染 24 项（0.678 秒），再 Knowledge 3 项（0.686 秒），Investment 3 项
（0.641 秒），平台合计 **30 项、零跳过**。实际只读 PG 九份、RabbitMQ 三个 vhost
授权清单均采集成功；没有实际写/拒绝、broker 消费或新镜像验收。

没有创建测试容器、文件型 kubeconfig、业务 Job/Secret 或持久化凭据文件；无需清理
集群资源。源码候选待本地提交后固定复验；本批仍不作中间 master/远端同步。
