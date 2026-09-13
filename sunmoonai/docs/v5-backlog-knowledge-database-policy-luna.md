# B7q：Knowledge 数据库领域权限与真实登录验证（Luna）

日期：2026-09-13。单人实施、自测；本地源码候选，不是业务供给或部署验收。
承接 [B7p Info](v5-backlog-info-database-policy-luna.md)，仍按
[逐步处置清单](v5-backlog-disposition-luna.md)在剩余工作完成后统一集成/同步。

## 1. 冻结范围、基线和规则

范围：模板测试工具新增明确的 `disposable-b7q-only` 确认域；Knowledge 部署侧纯权限
编译器、普通单测、独立 PG 测试及说明。不改 Backend/迁移/契约/依赖，不改业务凭据、
镜像、发布锁、部署或远端。Investment 领域权限另续，不将本包扩成全平台供给器。

| 仓 | 开工基线 / 固定版本 |
| --- | --- |
| tpl-app | `96d401705fdb73dc219095061cb4d3f8099f1a6a` → `2faa36751b08337148796f4556fc36de28f9ca2f`，仅夹具确认域及 README |
| k8s | `49833689c4c8796fb7b1d301891bbe1c4bf1638d` → `81c990e009541470fc852d86c13d937ff7131800`，Knowledge 策略、两类测试、部署说明四文件 |
| knowledge-backend | 未改 `5df4f1759cd64bd0a3ca2c4cae8f68102ebe681d`；实际迁移 head `20260911_0006` |
| knowledge-app | 未改 `8150c520fad0a8f8a6738441501f0e7104a7475a`；原对齐报告与 backend 差异保留 |

四后端及其他领域父仓均不修改；tpl 父仓 backend 索引仍 `53698628c5d26c9af933fd3fe567d239e7d3ecce`。
Luna 独占继续同一工作包，不新建分支；两份未跟踪 general/pro 草稿不纳入提交。
不更改 master、不 push、不更新 gitlink，不访问云端。源码回滚用反向本包提交，
没有业务数据需要回滚；本次只生成可重建合成测试数据。

| 规则 | 落实 |
| --- | --- |
| D1/D2/D3/D5/D8 | 一个领域测试库，真实独立 migration 登录跑原单链；RAGFlow 为替身，不引入第二主档 |
| D4/D9/I3 | 无业务存储、浏览器或 Provider 凭据；四运行/迁移角色不同密码 |
| T2/T3/R6 | 不 fork Backend；公共确认域先入模板过门禁，再 Info 回归，再 Knowledge 领域实现 |
| R1/T4/T5 | 固定仓与提交分列；测试身份不是业务身份，不触碰发布/source-lock/gitlink |

## 2. 权限从实际调用路径导出

已核 routes、knowledge_ingestion_service、ragflow_delivery、ingestion_execution、
knowledge_retrieval_service 及 provider_receipts CLI。完整冻结 10 表的列名集合：
模板六表 + knowledge_ingestion_job / knowledge_provider_operation / knowledge_document /
knowledge_document_version；公共 GRANT 为模板原样前缀，未知表/列或缺表即拒绝生成。

| 对象 | API | Worker |
| --- | --- | --- |
| 摄入 job | SELECT、指定非时间戳列 INSERT；状态/历史/错误/完成关联/metadata/updated_at UPDATE | SELECT、相同进展列 UPDATE；无 INSERT |
| Provider operation | 无 SELECT/INSERT/UPDATE | SELECT、operation_key/intent/state/receipt INSERT；仅 state/receipt/updated_at UPDATE |
| knowledge_document | SELECT；无写入 | SELECT、指定列 INSERT；无 UPDATE |
| knowledge_document_version | SELECT；无写入 | SELECT、指定列 INSERT；仅原 upsert 更新的完成关联、内容摘要、访问范围、状态与 Provider 绑定等列 UPDATE |

两运行角色不能修改摄入源身份、dataset、幂等键、原 payload/Artifact 引用，不能改
Provider operation key/intent，不能改知识文档的源身份/dataset。所有运行角色无
DELETE/TRUNCATE/DDL/版本表写；Scheduler 无 schema/表授权，外部测试引导仅给本库
CONNECT。Migration 拥有测试库与对象，运行账号不能 SET 为它。

领域 INSERT 按评审后的固定列集合排除 created_at/updated_at，保留 ORM 默认值写入；
没有基于现场发现自动全量授权，也没有领域全表 UPDATE。模板 Worker 的投递表状态
权限不作削减。`complete_ragflow_ingestion` 的 ON CONFLICT 更新分支在真实 Worker
身份下执行；不能误认为“首次摄入成功”就证明了重摄入路径。

**权限边界不是产品审批。**原 API 可人工更新 job 状态和 metadata，显式 retry 也要改
其中的执行游标；列 ACL 不理解 JSON 子字段或合法状态转换，不能据此宣称快照/代次
对数据库账号不可伪造。运行凭据只供可信 Backend，不交浏览器、不受信 Agent 或
Local Runner。API 不能写 Provider 账或知识版本，job 显示成功不等于可信索引已生成。

现有回执恢复是 CLI，不是浏览器 API；其原应用用例在 Worker 身份下验证，只对外读
回执，但会写本地已验证回执账。正式使用需获准 Worker 执行环境/运维授权；本包没有
新增第五类运行角色或产品审批机制，也没有为让 API 执行该 CLI 而扩大其数据库权限。

## 3. 真实隔离验收

新建 `luna-b7q-pg`，完整 ID
`38a7b55ea4667a10032f12f9d6e8f44d91e02807d155ba1836d45f152bc418a9`；
缓存 PG 17.6 镜像（本地 ID `dbd371582fbb`），256 MiB/1 CPU，仅绑定
`127.0.0.1:55439`。创建和连接经平台批准，核完整 ID、标签、挂载及 Ready；无业务 bind。

夹具要求精确管理员 URL/测试库/端口与确认域；每例独立两个测试库、四 LOGIN 和随机
密码，关 PUBLIC/默认授予后由 migration 真迁移，核 inventory，再执行 GRANT。
不使用管理员 SET ROLE 冒充四身份认证；只清理自身精确对象，不 FORCE/CASCADE。

27 项 PG 用例包括：

- 四登录/密码脱敏、owner、精确 revision 和原 schema readiness。
- 12 路并发受理只产生一个 job/意图，异载荷冲突与重复请求；意图写失败时受理事务回滚。
- artifact-only 原消费提交 artifact_verified，不伪造索引或 Provider 账；重复消费无新执行。
- 正常摄入及 upload/parse 响应丢失，原 journal 恢复，外部 upload/parse 计次不重复。
- 同源版本第二次受理走真实 upsert，文档/版本 ID 保持，ingestion 关联更新。
- 领域 INSERT/upsert 已执行后注入最终提交中断，文档/版本/Inbox 全回滚；已确认 Provider
  回执保留，重试完成领域与 Inbox，不重复上传/解析。
- 操作员选定回执的原恢复用例在 Worker 登录下可用；仅读 Provider，既不新上传/parse，
  也不直接成功或自动消费原命令；随后正常消费完成。
- 原解析游标、后继命令和 Inbox 提交；提前命令不读 Provider，后续轮询每次一次读取，
  deadline 不延长；API 显式重试生成新代次，旧代次只确认不执行。
- 撤回 dataset 绑定在访问 Artifact/Provider 前拒绝；API 原检索读取 Worker 写入的
  知识域记录，正确限制 Provider dataset/document，同时无权读取 Provider journal。
- 三运行角色版本表写/DDL/schema/临时表/SET migration/全部十表删除截断精确 42501；
  API/Worker 交叉越权拒绝，Scheduler 所有表读取拒绝；新表默认拒绝且清单编译拒绝。
- 四角色跨另一个 owner 的数据库均 42501，三个运行密码冒用 migration 均 28P01。

测试复用固定 Backend 的合成 Provider/Artifact/契约辅助对象；没有执行真实 RAGFlow、
S3、broker 或业务 HTTP。为避免把权限门禁变成一秒解析超时测试，替身配置给 120 秒
解析预算；轮询只调整合成 Outbox not-before，不改系统时钟或业务 deadline。
运行命令与边界见 [部署说明](../app-platform/knowledge-app/deployment/database-policy.md)。
普通四项策略单测由平台 unittest 收集；真实 PG 门禁仍需显式运行，未接远端 CI。

## 4. 验证日志与未完成事项

初验模板 12 单元（0.201 秒）+18 PG（8.68 秒），Info 25 PG（19.25 秒）通过后才
写 Knowledge 领域策略。Knowledge 四普通单测通过，初版 25 PG（18.53 秒），补两条
边界后 27 PG（20.34 秒）。本包无真实 PG 失败；Ruff 首轮三处 SIM905（固定字符串
split）和一处 I001 已修复，没有更改授权范围或弱化拒绝断言来消除失败。

最终固定提交严格串行复验：模板 `2faa367` 18 PG（8.54 秒）+12 普通单测（0.177 秒），
Info 25 PG（19.50 秒），Knowledge `81c990e0` 27 PG（20.87 秒），全部零跳过。
随后平台基础/Info 28 项（0.667 秒）→ Knowledge 策略/渲染 7 项（0.657 秒）→
Investment 既有渲染 3 项（0.632 秒），共 38 项通过。Investment 只回归已有渲染，
不称它已接入数据库领域权限。受影响 Python 的 Ruff、diff 检查通过；未跑四后端
全量套件，因为它们本包未改；真实 PG 之后只补文档，不再改代码。

清理前实查 b7o/b7p/b7q 测试库 **0**、测试角色 **0**；重新核完整容器 ID/标签/三匿名卷
后，经批准停止并 `rm -v` 删除上述一次性容器及三卷。复查精确卷名无残留，原三个 KIND
节点和旧 exited 容器保留。删除的仅可重建测试环境，其临时合成数据不可恢复；没有
删除业务数据、镜像或 Secret。文档回执单独提交，不改变上述固定代码证据。

仍待 Investment 领域策略、broker 权限和真实 Scheduler 启动、业务历史 ACL/default
ACL 收敛、账号供给/撤销/轮换、备份恢复及数据/镜像共同切换。本函数仅加法 GRANT，
不能收紧旧账号；列清单也不替代类型/函数/触发器/RLS 等有效权限检查。当前业务共享
身份结论没有被本包改变；B7/B8/B9 整体未结束，不提前同步或把部署欠账销掉。
