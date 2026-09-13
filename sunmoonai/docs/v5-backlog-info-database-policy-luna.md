# B7p：Info 领域数据库权限候选与独立登录验收（Luna）

日期：2026-09-13。单人实施、自测；Info 本地源码候选，不是业务凭据切换或部署。
承接 [模板权限 B7o](v5-backlog-template-database-policy-luna.md)与
[有效权限实查 B7n](v5-backlog-runtime-permissions-luna.md)，仍按
[处置清单](v5-backlog-disposition-luna.md)完成本批后统一集成/同步。

## 1. 冻结范围与基线

只做模板隔离测试夹具提取、Info 领域权限 overlay 与真实数据库验证，不同时实现
Knowledge/Investment 策略、RabbitMQ 供给、业务 Secret、迁移切换或运行发布。

| 对象 | 开工基线 / 最终候选 |
| --- | --- |
| tpl-app | 开工 `a4d300fbd3417302d6c41d4d4e59599b3432b0a5`；固定 `96d401705fdb73dc219095061cb4d3f8099f1a6a` |
| k8s | 开工 `378a22703af9df00426f9b63ac4182d6828720ae`；策略/测试固定 `58980ce60d6b427eeece01768c4499701410be9d`；文档回执单独提交 |
| tpl-backend | 未改 `a91eb3e284ae91d4bc6b82fe567c4163cfa728f0`；父仓索引 gitlink 仍 `53698628c5d26c9af933fd3fe567d239e7d3ecce` |
| info-backend | 未改 `7dafb34ca70d1f71ebc332315bf0c7584b9c3092`；真实迁移到 `20260913_0009` |
| Info 父仓 | 未改 `016517ba7c9f8a66b95a4dfde9e6d7e1886eb504`；原对齐报告增量与 backend gitlink 差异保留 |

独占本地 Luna，预置脏文件按原批次归属保留；两份未跟踪 general/pro 草案不动。
不新增分支、不更新父仓 backend gitlink、不合并 master、不 push、不操作云端。
源码回滚为反向本包提交；没有业务状态需要回滚。测试资源只含可重建合成数据。

| 约束 | 落实 |
| --- | --- |
| D1/D2/D3/D8 | 单 App 测试库；迁移账号实际跑原单链，运行角色不升级；不跨领域读表 |
| D4/D9/I3 | 外部存储替身、四独立随机密码；无浏览器/业务/Provider 凭据供给 |
| T2/T3/R6 | 不另建 Backend；公共夹具先入模板并过门禁，Info 保留领域扩展，未推进其余实例权限 |
| R1/T4/T5 | 仓与固定提交分列；不把测试账号当当前业务账号，不改发布锁、镜像或 gitlink |

## 2. 公共工具与 Info 接线

模板新增 `k8s-deployment/integration/permission_pg_support.py`，原 18 项测试只改为
引用公共夹具/辅助函数。工具不导入 `app`，由调用方传 Backend 路径和纯权限编译器；
每个 App 的测试必须独立进程，避免同名 Python 包混用。

Info 新增部署侧 `sunmoonai/app-platform/info-app/deployment/info_database_policy.py`，
按五仓并列拓扑引用模板公共编译器；普通测试在平台 scripts/tests，真实 PG 测试在
scripts/integration。运行方法见 [部署侧说明](../app-platform/info-app/deployment/database-policy.md)。
不在 Info 应用服务中塞权限供给逻辑，也不更改原迁移/依赖。

完整清单锁定 15 张表的列名：模板六表 + Info 八张活动领域表 + 旧投递归档表。
任何缺表、新表或列集合变化都会拒绝生成；公共六表 GRANT 为模板输出的原样前缀，
overlay 不能替换它。没有全表 UPDATE、DELETE、TRUNCATE 或未来对象通配授权。
这里“没有全表 UPDATE”指 Info 领域增量；模板 Worker 的投递状态表授权原样保留。

## 3. 依据真实调用者划分权限

核对了 Info routes → application services → ORM/SQL，以及三个实际 delivery handler。
API 现有职责含上传入库、采集器发现、人工审核、分发创建/状态更新/重试，不能当只读账号。

| 领域对象 | API | Worker |
| --- | --- | --- |
| info_source / info_collector | SELECT、指定列 INSERT；无 UPDATE | SELECT；无写入 |
| crawl_job | SELECT、指定列 INSERT；更新 request/status/文档关联/updated_at | SELECT；更新执行状态、计次、HTTP/错误/耗时/文档关联；不创建任务、不改 request/目标 |
| raw_artifact | SELECT、指定列 INSERT；仅补文档/版本关联和 updated_at | 同 API；不改对象键、哈希或存储状态 |
| info_document | SELECT、指定列 INSERT；更新审核/metadata/current_version/content_hash/updated_at | SELECT、指定列 INSERT；更新抽取标题/发布时间/metadata/current_version/content_hash/updated_at；不改审核状态 |
| info_document_version | SELECT、指定列 INSERT；仅审核状态/metadata/updated_at UPDATE | SELECT、指定列 INSERT；无 UPDATE |
| extracted_content | SELECT、指定列 INSERT；无 UPDATE | 同 API |
| distribution_record | SELECT、指定列 INSERT；状态/载荷历史/错误/updated_at UPDATE | SELECT；相同进展列 UPDATE，无 INSERT |
| delivery_outbox_message_legacy | 无读取或写入授权 | 无读取或写入授权 |

领域 INSERT 使用已评审固定清单中的非时间戳列（含 UUID 和 ORM 默认值），不是把
数据库现场发现的字段自动全部放行。Scheduler 没有 schema/表授权，测试外部引导仅
给本库 CONNECT；Migration 是测试库/表 owner，运行账号无 SET 权限。

API 与 Worker 都不能改 canonical 身份、版本内容哈希/写协议、分发身份目标、Artifact
对象地址，不能删去重/回执/租约或归档。这是**可信 Backend 进程之间**的权限缩小：
它不强制行级、租户或人的审批，也不把已授权列限制为特定状态转换。API 原有分发状态
更新能力仍保留；不能宣称只有 Worker 才能让领域状态显示成功。数据库账号不得交给
不受信 Agent、浏览器或 Local Runner；那部分仍需产品授权边界。

## 4. 真实隔离验证与覆盖边界

一次性容器 `luna-b7p-pg`，完整 ID
`90264a1d4e617f74facf6b13b22c8c231aba9c93f78e40f55b31b102b1688ddc`；
缓存 PostgreSQL 17.6 镜像（本地 image ID `dbd371582fbb`），256 MiB/1 CPU，
仅 `127.0.0.1:55439`。创建、连接和清理受平台批准；复核标签和三匿名卷，无业务 bind。

夹具仅接受精确 loopback/端口/backlog_tests 管理员连接与显式确认域。每例生成两个随机
测试库和四个不同 LOGIN/密码，先关闭 PUBLIC 库/schema 访问、未来表/序列/函数默认
授予，再由真实迁移登录建对象、核完整清单、执行候选 GRANT。Info 旧迁移需 uuid-ossp，
只在新测试库显式安装；不为此改生产迁移或扩展业务库。

25 项真实 PG 测试：

- 四真实认证身份、密码不同/fixture repr 脱敏、owner、精确 revision、原 schema readiness。
- API 创建 source/collector、发现任务、重复请求只保留一条意图；真实 PG advisory 准入。
- 文本与二进制两类上传，同 canonical 文档生成递增版本；原审核/摘要/实体 metadata 用例。
- 上传/建抓取任务时注入 enqueue 失败，领域行和 Outbox 一起回滚。
- Worker 原 DurableTasks/handler 抓取成功、HTTP 失败、抽取失败，原领域写入和后续索引
  意图；重复消费不再次抓取，失败后 API 显式请求生成下一代命令。
- 12 路并发创建分发，None/空串/default 收敛同一记录/命令；显式重试保持记录 ID，新增
  一代命令；模拟远端接受后回执丢失，无 Inbox，第二次原消费恢复且请求快照相同。
- 原索引用例读取文档/版本/Artifact/抽取记录、调用搜索替身并记 Inbox；重复消费不再次索引。
- 三运行角色版本表写/DDL/schema/临时表/SET migration、所有 15 表 DELETE/TRUNCATE、
  归档读写均精确 **42501**；API/Worker 各自越权更新拒绝；Scheduler 所有表 SELECT 拒绝。
- 四角色连接另一个 owner 的库均 **42501**；三运行密码冒用迁移账号均 **28P01**。
- Migration 新建未评审表后，运行角色读写拒绝，编译器亦拒绝扩展后的清单。

HTTP/对象存储/搜索/Knowledge 客户端为合成替身；未启动真实 RabbitMQ、S3、ES 或
RAGFlow，不证明通知/对象/下游实际到达。真实数据库测试需显式运行，未接远端 CI；
普通四项编译器测试由现有 unittest 自动收集。未跑四后端全量，它们本包未改。

## 5. 验证记录、问题与后续

初验模板 12 单元 + 18 PG（8.73 秒）；Info 四项普通单测 + 25 PG（19.53 秒）。
夹具提取最初两处导入排序 I001、Info 单测一处嵌套判断 SIM102 已修正，最终 Ruff 通过。
本包没有真实 PG 失败；没有跳过或放宽任何 SQLSTATE/业务断言，也没有改生产权限去
迁就夹具。先前 B7o 的语法/搜索路径问题仍归原报告，不算本包新根因。

固定模板 `96d4017`：18 PG（8.44 秒）、12 单元（0.170 秒）通过；随后 Info 固定
`58980ce6`：25 PG（19.49 秒），全部零跳过。平台按基础/Info 28 项（0.726 秒）→
Knowledge 渲染 3 项（0.702 秒）→ Investment 渲染 3 项（0.633 秒）串行通过；后两项
只是既有渲染回归，不是其领域数据库权限已接入。最终两仓受影响 Python 的 Ruff 和
diff 检查均通过；验证后没有修改代码，仅补文档。

清理前 psql 首次遗漏合成管理员密码，未建立连接（`fe_sendauth: no password supplied`）；
按原因显式传入该一次性密码并使用 `-w` 禁止交互后，查得 b7o/b7p 测试库 **0**、
测试角色 **0**。不是权限策略失败，也没有改 pg_hba 或扩权来处理诊断命令。
再次核对完整容器 ID/标签/挂载后，经批准 stop + rm -v 删除上述容器及三个匿名卷，
复查容器和精确卷名均无残留；原三个 KIND 节点及旧 exited 容器保留。
移除的仅可重建合成测试环境，不能恢复其临时数据；业务数据/镜像/Secret 未删除。

仍待：Knowledge → Investment 领域策略及真实独立身份验证；broker 权限/实际 Scheduler
启动；业务历史 ACL 与默认授权收敛、角色供给/撤销/轮换；备份恢复/数据和镜像共同切换。
本函数是加法授权，**不能收紧已有账号**，表列清单也不替代类型/触发器/函数/RLS 的
有效权限审计。当前业务库仍共享旧运行 principal，本包不改变 B7n 的实际环境结论。
其余 B7/B8/B9 按清单推进；不据本包关闭整个旧账，也不进行中间同步。
