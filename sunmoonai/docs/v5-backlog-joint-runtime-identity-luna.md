# B7u：独立数据库与 broker 身份联合运行（Luna）

日期：2026-09-13。单人实施、自测，不宣称独立评审。承接
[B7t](v5-backlog-instance-broker-alignment-luna.md)，遵守
[处置清单](v5-backlog-disposition-luna.md)的最后统一集成、同步顺序。

## 1. 范围、基线与边界

目标是补齐“PG 权限单独通过、broker 权限单独通过”之间的联合证据，先模板再实例。
只在模板父仓增加隔离验收装配与测试，复用已经验过的角色策略和实际 Backend；
不改生产代码、权限编译器、任务调度周期、租约、迁移、部署或业务凭据。

| 对象 | 开工固定提交 |
| --- | --- |
| tpl-app | fb9aee86646b51fad16cc17bd3e81be919eb5591 |
| tpl-backend | 44e74fe02d29616dfe636b06cc717bd9698536d9 |
| info-backend | 5fb909b6a012bfa62d1002abb6deb3fd9e3dc016 |
| knowledge-backend | e79a71272dbcf487e2a0def6dd65a954d3ca0ed8 |
| investment-backend | 68f776edf6f8155f4e5ebfc4e321a17da229dc95 |
| k8s | a3b59437ac883ca0597707f38f226cc2a2f6b864 |

改动路径是 `tpl-app/k8s-deployment/integration/` 下的测试和本证据/清单。
继续保留所有原有父仓 gitlink 差异、三个旧对齐报告的预置增量以及两份 general/pro 草案。
不新建分支、不更新 master、不推远端、不发布镜像，不借此包切换业务身份。
回滚仅撤销本轮测试源码提交；没有新增业务迁移或需要恢复的业务数据。

| 约束 | 落实 |
| --- | --- |
| D1/D2/D8 | 随机一次性数据库、四个独立 LOGIN；真实迁移和精确列权限；不接业务库 |
| I3/I8 | API/Worker/Scheduler 分别使用独立 PG/broker 身份，不把管理账号用于任务执行 |
| C1/R6 | 原共享投递/Inbox/epoch/租约/提交保护不替换；模板先验证 |
| R1/T4/T5 | 本地源码候选与部署分列；父仓 gitlink 和推送留最终批次 |

## 2. 验收装配

`runtime_identity_worker.py` 只替换 handler 注册，实际 `get_postgres`、生产 Settings、
Celery dispatch/execute、DurableTasks、事务与默认 60 秒租约保持原样。
handler 的合成效果是同一事务中追加一个已有 Outbox 类型的后续意图，其 payload 记录
实际 SQL `current_user`；成功回执来自真实 Inbox，不拿日志、broker ACK 当业务提交。
不增加测试表，不扩大六张共享表的权限，也不以任意表计数器绕开候选 ACL。

API 使用独立子进程调用实际存储与 enqueue_task，检查实际数据库身份、意图去重；
Worker 使用真实 prefork，concurrency=1，默认 mingle/gossip/heartbeat/remote control
与原 readiness 均保留。Beat 使用真实 scheduler bootstrap、原 5 秒 pump 调度。
文件仅在 pytest 自己的临时目录中协调合成故障，不是产品跨进程通信或审批设计。
运行子进程环境过滤继承的数据库/broker URL，只注入本角色两个 URL；不带测试供给者
或 migration URL。检查实际 late-ACK 默认开启，不通过关闭确认来通过测试。
Scheduler 的 PG 身份由独立真实登录核验 CONNECT 和 schema 拒绝；Beat 本身按原职责
只发消息，不为证明“用了数据库”而新增 SQL 访问。真正使用 Worker SQL 身份的是任务
子进程中的事务；运行时证据不等于生产 Pod 已按此挂载凭据或已有强进程隔离。

目标选择沿用 B7t 的 `BROKER_PERMISSION_TEST_BACKEND`，每次使用该后端自己的 venv；
只允许模板、Info、Knowledge、Investment 的已审核策略，不为未知实例自动授表权限。
Info 使用真实 0009 迁移及原 uuid-ossp 前置；其余分别使用对应当前迁移和领域列 ACL。
所有实例都复用这一份测试入口，不制造三份副本、不修改子仓源码或任务注册。
Investment 原 Agent pump 调度也保留，但库中没有合成 Agent 命令；本包仍只对共同
DurableTasks 链路作联合恢复声明，Agent 真断点/控制事务证据沿用 B7r，不混称本包覆盖。

三项联合验收：

1. API 提交 → 独立 Scheduler/Beat 发布 pump → Worker 发布/执行 → 原子效果/Inbox；
   重复执行后用后一已提交任务作顺序屏障，并检查队列 ACK 统计及 ready/unack 排空。
2. handler 插入效果后抛错，验证效果与 Inbox 均回滚；即使 broker 已 ACK 也不能算成功；
   解除合成故障后由 API 重新发送执行提示，验证同一意图只提交一次。
3. handler 事务打开时，观察真实 broker unack；核验测试自己创建的进程组后 SIGKILL。
   重启 Worker 和真实 Beat，不改 SQL 时间戳、不缩短 60 秒租约，等待生产对账恢复；
   原子效果、Inbox、epoch 增长及第二次投递必须同时成立。

这些证据不涵盖业务 HTTP/JWT、跨域 Provider、真实 LLM/工具、浏览器审批、生产级进程
隔离或每个领域的完整任务链。尤其不把公共 handler 装配当成 Investment AgentDelivery
端到端验收，也不把两次 ACK 当成两个业务效果。

## 3. 一次性资源与失败处置

两个明确开关：`JOINT_RUNTIME_TEST_CONFIRM=disposable-b7u-only` 与
`BROKER_PERMISSION_TEST_CONFIRM=disposable-b7s-only`。新建 PG 固定回环 55439，端口
占用即失败；不复用已有服务。broker 沿用 B7s 的随机新容器/vhost/三个窄权限账号。
PG 先 create 得到确切 ID，再在 try/finally 中 start；端口绑定失败也在已知对象的
清理保护内。不在 Docker run 报错后依靠通配符搜索或清理未知容器。
PG 镜像 `sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b`；
RabbitMQ 镜像沿用 B7s 固定值。容器 ID、镜像、标签、挂载和清理后不存在均需核验。
资源内仅合成数据，删除后复跑可重建；不删除旧 KIND、业务数据或缓存镜像。

开发期失败不隐藏：

- 初次收集因本地辅助模块 import 顺序未先加入 deployment 路径失败，修正入口后
  三项正常收集；普通父仓 18 单测及 Ruff 通过。
- 首轮真实测试，Scheduler 无 public USAGE 时，裸表名走 search_path 返回 42P01，
  不能用它证明 42501。新增两项精确断言：裸表名必须不可见；限定 public 表名必须
  真正权限拒绝。没有把任意异常都判为拒绝，没有放宽账号权限。
- 第二轮真实处理已提交，但立即读管理连接快照只见 Worker，Scheduler 尚未出现在
  采样结果中。改为有界等待同一 vhost 的两个实际用户名，记录角色采样序列；不删掉
  身份断言，不将“已配置 URL”当成实际登录。随后开发期三项 119.95 秒通过，实际记录
  `worker → scheduler + worker` 序列，印证原采样先后问题。

## 4. 当前结果

测试入口已固定 `tpl-app@9d08dc78d171b6f2a2795a7e438b77328ea508d5`，只含三个测试
文件的增量。普通父仓 18 单测及两新增文件 Ruff/收集通过；固定提交严格按模板→Info→
Knowledge→Investment 完成下表运行门禁。四个 Backend 均未改动，使用第 1 节提交。
使用说明单独提交为 `tpl-app@669c97d80b8567a789ea8376753775eb1423629f`；相对
`9d08dc7` 仅 README 变化，测试源码完全一致。四后端全量 Ruff/Pyright 本轮均通过。

| 目标 | 外层联合及既有门禁 | 内层完整 Backend |
| --- | --- | --- |
| 模板 | 36 passed / 0 skipped，213.28 秒 | 258 passed / 0 skipped，52.55 秒 |
| Info | 36 passed / 0 skipped，247.49 秒 | 503 passed / 0 skipped，83.18 秒 |
| Knowledge | 36 passed / 0 skipped，247.91 秒 | 418 passed / 0 skipped，71.21 秒 |
| Investment | 36 passed / 0 skipped，267.83 秒 | 402 passed / 0 skipped，78.91 秒 |

每仓外层包括新增三项联合、原 30 项 broker、完整回归包装和两项辅助资源验收。
完整回归使用自己独立的宽权限测试数据库/vhost，不拿其通过数重复充作窄权限证据。
内层完整回归合计 **1,581 项零跳过**；外层 144 项包含四个回归包装，不重复算成额外
业务场景。真正新增的是每仓三项、共 **12 次联合场景执行**。四份外层 JUnit 再核均为
36 tests / 0 failures / 0 errors / 0 skipped；四次真实管理采样均先见 Worker，随后才
出现 Worker + Scheduler。最终四组没有新增失败，开发期失败与根因保留在第 3 节。

## 5. 资源清理与未关闭范围

以下为四组联合验收的主要资源，均在对应门禁结束时精确移除并查询确认不存在：

| 目标 | 联合 PostgreSQL 容器 ID | 联合 RabbitMQ 容器 ID |
| --- | --- | --- |
| 模板 | ff95061e9c4866cfac7693cc886fd1d3dca9c918c63370679da02d67ab7cab48 | ea15365ffdd9f8d588554aa38b7c9ba07f7ae5775796fe2ac88238ab39975852 |
| Info | 54b60d48682fdd0e31ab626b136c8881d652321a597488583e38913dc7b38f86 | 9b8d51e883f015d98d13cba6bb805195d24f6907940db04e5146f42378b4f842 |
| Knowledge | 84ff21aa113745734436ae81fb71a507c896b653dcfbb16fd654d9fc40e404cc | c8f9ae8d2ddbf0c7310b0572365846717f59edfb4e6d2318992052ed2d8872e5 |
| Investment | ed46fd427b17fc848cfcfd6763b53f1fe08781232a8d1de4212a50f943544c4b | dae722b7672cc5a1b25eb67df418ee1c474095b811b6daf14df6fdb4b93000df |

四组最终验收共创建并移除 26 个一次性容器及其 29 个匿名卷（联合 8 容器/12 卷，
原 broker/完整回归/辅助门禁另 18 容器/17 卷）。删除的只有可复跑重建的合成数据。
开发期两次失败和一次成功试跑的六个容器、九个匿名卷也已分别核验清理。
最终 `docker ps -a --no-trunc` 只见原三个 KIND 节点及旧退出容器 gifted_chaum，完整
ID 与开工前一致。没有删除镜像、业务数据、旧容器或用户文件，没有遗留测试 Worker。

本包关闭四仓**公共投递链路**的联合身份运行、事务/ACK 区分及默认租约故障恢复子项。
无生产代码增量，三个实例父仓无需再复制模板文件或追加 gitlink；原预置报告增量保留。
真实领域外部副作用/产品链路不据此扩张覆盖，原 B7r 等领域证据各自保留。

下一游标是身份供给及重启一致性、旧权限撤销/连接排空、备份恢复与受控切换前置；
实际业务操作仍留 B7 并需要冻结精确对象和回滚条件，不凭“继续”自动轮换业务凭据。
B8 未来计划正式接收、B9 最终集成同步、N4-OPS-01 监控部署保持各自边界。
