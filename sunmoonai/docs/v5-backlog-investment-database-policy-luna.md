# B7r：Investment 数据库权限、真实断点与 Agent 控制验证（Luna）

日期：2026-09-13。单人实施、自测，本地源码候选；业务身份/部署未切换。
承接 [Knowledge B7q](v5-backlog-knowledge-database-policy-luna.md)，依
[逐步处置清单](v5-backlog-disposition-luna.md)继续本批，最后统一集成与同步。

## 1. 冻结范围和基线

只增加 Investment 部署侧纯权限编译器、普通/真实 PG 测试、部署说明；模板仅新增
明确的 b7r 一次性测试确认域。四 Backend/迁移/依赖、契约、运行镜像、Secret、业务库
及云端不动。两份 general/pro 未跟踪草稿保留，不新增分支或更新 master/gitlink。

| 仓 | 开工 / 固定代码版本 |
| --- | --- |
| tpl-app | `2faa36751b08337148796f4556fc36de28f9ca2f` → `9abc39d0b78a67e3592570cd6c32ade1b3b40cc0`，仅测试确认域与 README |
| k8s | `e1304a8b599ae931225f4bfb3717439f445dcc93` → `15588f3af15284b4b54daa454eac93b6abf439a8`，策略、两类测试和部署说明四文件 |
| investment-backend | 未改 `3d9531d1250d035aa13eb197198b6c5672450856`，实际迁移 head `20260911_0007` |
| investment-app | 未改 `fc4503f35c131ee14e29c10354948dfad65e8f0e`，预置对齐报告/backend 差异保留 |

tpl backend 索引仍 `53698628c5d26c9af933fd3fe567d239e7d3ecce`；其余领域父仓/四后端
状态不因本包改变。无 push、远端同步或 master 合并。源码回滚为反向本包提交；
没有业务数据需要回滚，只创建可重建合成测试环境。

| 约束 | 落实 |
| --- | --- |
| D1/D2/D3/D8 | 同一领域测试库、四真实独立登录；迁移身份跑原单链，运行角色不升级 |
| D4/D9/I3 | 不接业务模型/存储凭据；四随机密码不写仓库，不交浏览器或 Agent 工具 |
| T2/T3/R6 | 不 fork 后端；模板→Info→Knowledge 门禁通过才写 Investment overlay |
| R1/T4/T5 | 仓+固定提交可复查；不改 gitlink/source-lock/image，不把测试身份当业务部署 |

## 2. 实际调用链决定授权

核对 AgentRepository、PilotRepository、AgentTransactions、AgentDelivery、EffectRepository、
AgentRunService、AgentExecutionService、执行任务和原 GraphExecutor/checkpointer。
额外核本机锁定的 `langgraph-checkpoint-postgres==3.1.0` 实际 SQL，不猜库的权限需求。
纯编译器引用模板六表策略作为原样前缀；总计冻结 18 表完整列集合，未知表/缺表/新列
一律拒绝生成。没有通配授权、领域全表 UPDATE、DELETE 或 TRUNCATE。

| 对象 | API | Worker |
| --- | --- | --- |
| agent_sessions / agent_runs | 指定列创建、SELECT；状态/resume_token/error/updated_at 更新 | SELECT；状态与已接受 execution_state 更新；无创建权限 |
| session_events | SELECT、指定列 INSERT | 同 API，均不得改写或删除既有事件 |
| agent_pilot_requests | SELECT、指定列 INSERT；无 UPDATE | 只读 |
| agent_pilot_controls | SELECT、仅 run_id INSERT；取消/恢复控制列 UPDATE | 只读，不能写人响应控制 |
| agent_execution_leases | SELECT；仅 epoch/expires_at UPDATE，用于取消撤销 | SELECT、指定列 INSERT；command_id/owner/epoch/expires_at UPDATE |
| tool_side_effects | 无访问 | SELECT、指定列 INSERT；status/result/receipt/execution_epoch/updated_at UPDATE，不能改 intent 或绑定身份 |
| checkpoints | 无访问 | SELECT、原 Saver 使用列 INSERT；只更新 checkpoint/metadata |
| checkpoint_blobs | 无访问 | SELECT、INSERT；无 UPDATE |
| checkpoint_writes | 无访问 | SELECT、INSERT；只更新 channel/type/blob |
| checkpoint_migrations / agent_delivery_failures_legacy_0006 | 无访问 | 无访问 |

Scheduler 无 schema/表权限，外部夹具仅给本库 CONNECT；Migration 拥有测试库/表，
运行账号不能 SET 为它。字段的精确清单见编译器，不以本表简写代替可执行策略。

**取消不是 Worker 独占写。**原 API 的 request_cancel 先校 owner，再把 session 租约
epoch 增一、expires_at 设为负无穷，从而拒绝旧 Worker 接受迟到结果；只给 SELECT
会破坏取消。这次保留两列 UPDATE，但不开放 owner/command_id 修改或租约 INSERT。

**列权限不是行级/审批/fencing 实现。**API 已获两列权限不代表数据库强制它只增 epoch
或只缩短到期时间；Worker 断点写权限也不强制 thread 隔离。原应用 owner/token/租约
谓词与已接受快照仍负责这些边界。两角色都可追加事件、API 也可写运行状态，不能说
数据库 ACL 能证明事件是谁批准或状态一定真实。凭据只能给可信 Backend 进程。

## 3. 实际 PostgreSQL 验收

一次性容器 `luna-b7r-pg`，完整 ID：
`94163d9a25e2a8c5edddd9af329af0ed8da01a0955f70c6794aba359684dd025`。
缓存 PG 17.6（image ID `dbd371582fbb`），256 MiB/1 CPU，仅绑定
`127.0.0.1:55439`；核完整 ID、b7r 标签、三个匿名卷、无业务 bind 和 Ready。
创建、连接与清理均通过平台批准。夹具要求精确 URL/管理员/测试库/确认域，缺失失败
而非 skip；每例独立两个库/四 LOGIN，关闭 PUBLIC/default ACL 后迁移、核清单、授权。

24 项真实 PG 测试覆盖：

- 四真实数据库身份、不同密码/fixture repr 脱敏、owner、head 和原 readiness。
- 生产 `phase0_postgres_checkpointer` 实际连测试 Worker，读取 current_user 验身份；
  只替换连接配置，保留生产 URL 转换、PostgresSaver、默认不 setup 的路径。
- 12 路 API 重复建 run 只生成一个任务/执行意图；UI 写失败时状态、事件及通知意图回滚。
- 原 phase0 图等待→API resume→新 Worker 调用完成；真实 PostgreSQL checkpoint、
  blobs、writes 非空，两个 attempt 的 thread 分开，重复投递不重复副作用或 Inbox。
- 原 pilot 图产出 input_required，API 拒绝非 owner 和陈旧 action，重复响应幂等、不同
  输入拒绝；新的 Worker 调用恢复完成；浏览器事件可按游标重取且拒绝非 owner。
- API 恢复中 enqueue 失败，token/控制行消费一并回滚；没有半条恢复命令。
- API 取消先拒绝非 owner，再撤销真正 Worker 的租约；阻塞执行器释放迟到结果后
  LeaseLost、无 completed 事件/Inbox。该取消故障用例用合成阻塞执行器，不能外推
  杀死外部 CLI、真实模型或沙箱进程。
- 旧 epoch 不能写结果/覆盖新 owner，迟到 release 不破坏新租约续租。
- 远端合成副作用成功、本地落回执前失去租约：reconcile 标 unknown，原业务键查回执
  恢复不重复执行；结果仍不明时拒绝盲目重执行。
- 原 Agent pump/共享死信/重放在 Worker 身份下可用，publish 为合成回调而非真实 broker。
- 三运行角色版本账/归档读写、DDL/schema/临时表/SET migration、所有 18 表删除截断
  精确 42501；API 不能写断点/效果账/执行快照/伪造租约，Worker 不能建 run/写审批控制。
- Scheduler 全表读取拒绝，新表默认拒绝且 inventory 拒绝；四角色跨另一 owner 的库
  都 42501，三个运行密码冒用 migration 都 28P01。

原 phase0/pilot 是已有阶段性路径，不等于未来统一 Task/Interaction 审批产品已完成。
图前 draft/citation、远端副作用、publish 均为合成替身，没有真实浏览器、模型、检索、
Redis/RabbitMQ 或业务接口验收。普通四项策略测试由平台 unittest 收集，真实 PG 仍需
显式运行，未接远端 CI；命令见 [部署说明](../app-platform/investment-app/deployment/database-policy.md)。

## 4. 门禁记录与下一游标

开工模板普通 12 项（0.226 秒），随后固定模板 18 PG（11.61 秒）→Info 25 PG
（23.93 秒）→Knowledge 27 PG（20.45 秒）通过后才写 Investment 策略。
Investment 四项普通单测、初验 24 PG（18.45 秒）通过。仅首轮测试导入排序 I001
格式问题已修复；无真实 PG 失败，不删测试、不放宽 SQLSTATE 或身份/状态断言。

最终固定模板 `9abc39d` 普通 12 项（0.252 秒）通过；严格串行模板 18 PG（8.54 秒）
→Info 25 PG（19.44 秒）→Knowledge 27 PG（20.76 秒）→Investment `15588f3a` 24 PG
（18.50 秒），共 94 项，全部零跳过。随后平台基础/Info 28 项（0.747 秒）→Knowledge
策略/渲染 7 项（0.674 秒）→Investment 策略/渲染 7 项（0.661 秒），共 42 项通过；
受影响 Python 的 Ruff 和 diff 检查通过。没有改四后端，因此未重跑四后端全量套件。
最终 PG 验证后只补文档，不再改代码；文档回执单独提交。

清理前查 b7o/b7p/b7q/b7r 测试库 **0**、测试角色 **0**；再次核完整容器 ID/标签/三卷
后，经批准 stop + rm -v 删除上述一次性容器及三个匿名测试卷。按完整 ID/精确卷名
复查均无残留，原三个 KIND 节点和旧 exited 容器保留。删除的仅可重建测试环境，
临时合成数据不可恢复；业务数据/Secret/镜像没有删除或修改。

三领域数据库策略至此均有独立账号候选，但它们只是加法 GRANT，**不能收紧现有
宽权限角色**。仍待 broker 分角色权限及真实启动/拒绝验证、历史 ACL/default ACL
收敛、供给/撤销/轮换、备份恢复与数据/镜像共同切换。表列清单不等于完整类型/
函数/触发器/RLS 审计。当前业务共享身份事实未变；B7/B8/B9 仍未完成，不中间同步。
