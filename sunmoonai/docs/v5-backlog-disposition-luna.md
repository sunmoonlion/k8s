# v5 停工遗留任务：逐步处置清单（Luna）

日期：2026-09-12。执行者：Luna，单人实施与自测，不宣称独立评审。

## 1. 请求、边界与完成口径

所有者要求：从旧 v5 handoff 查清当时停工遗留任务；与当前架构冲突的旧做法放弃，
不冲突且可独立补齐的先还账，需要统一设计的转入即将重写的新 dev-plan。
随后明确：不多家开发，由 Luna 一人逐步完成；现有 Luna 工作区开发，验收后集成 master，
不新增工作分支。禁止从重构后 dev-plan/handoff 反推历史欠账。

历史真源：[旧 handoff](mooc-manus-langgraph-v5-handoff-20260712.md) 的 2026-08-01
最终暂停记录及 [旧实施计划](mooc-manus-langgraph-v5-implementation-plan.md)。
本清单是处置与执行记录，不改写历史，不替代新产品架构或新 dev-plan。

当前架构：Next / 单领域 FastAPI Backend；三个领域不跨库；公共底座模板先行；
Supervisor 下通用执行适配已有智能体、专业 Agent 自建；云端先交付但始终兼容本机。
Local Runner、Electron 和新评优协议是新需求，不能伪装成旧任务。

执行范围：现有五仓 Luna 工作区中的清单、代码、测试和必要文档；逐包验证与提交。
不自动切生产流量、删除业务数据/历史证据、轮换凭据或强制覆盖分支。
部署、数据迁移、外部状态变更需列出精确对象与回滚条件，按授权和平台批准机制实施。
保留现有两份未跟踪的 general/pro 协议草案，不修改、不顺带提交。

状态：待核验 / 待实施 / 实施中 / 候选已验证 / 已集成 / 旧做法不再实施 /
待迁入新计划 / 已迁入新计划。代码、集成、部署分开记；有测试文件不等于跑过。
旧任务按验收子项销账，不能因一部分已做而整体打勾。

## 2. 开工基线与规则

2026-09-12 只读核对：本地与云端 master、Luna 五父仓 HEAD 和 gitlink 一致；
GitHub origin 的 master/Luna 实时引用与下表一致。云端两个工作区干净；本地只有既有两份
协议草案未跟踪。没有执行 reset、pull、stash、强推或改写 master。

| 父仓 | 基线 commit | 后端 gitlink |
| --- | --- | --- |
| tpl-app | 8b1e68cdb43884ec00ab294f72b93eab1b57b5fa | ca67032502a7507986f175b17967db624644f1a5 |
| info-app | 7bdf11caa835a1d6db834bfa5313bc103ada2048 | 8c3b695e3e2b5b4064b5b14ce8d2b6d6767177e2 |
| knowledge-app | 456205fe2639eb7538b6d32659fa6636664b7582 | 72f17d2e81bafaa5818a9a94e735c011720b9baf |
| investment-app | e357cb326dd542743fe5e94c4f08e3ef47ab84c5 | 00b1b55cb1d186224e57fe3528998b6734ecb327 |
| k8s | b94cf7df8080b2708d1b46406371a9b1e88b9a22 | 不适用 |

子模块各有独立 Git 元数据，目录位于 Luna 不代表子模块分支也叫 luna；按父仓 gitlink
固定起点，保留既有子仓开发分支，不在 master 工作区改代码、不额外创建分支。
Git 元数据位于可写根之外，提交/集成通过平台权限批准，不绕过沙箱。

| 规则 | 本轮遵守方式 |
| --- | --- |
| D1–D8 | 单一领域主档；迁移前清单、备份恢复、线性迁移及回滚；不直接改业务库 |
| C1–C6 | 复用公共可靠投递；provider 契约唯一；改变契约跑双端测试 |
| I1、I3–I8 | 接口共享用例；服务与用户身份分离；新增防护失败关闭 |
| T1–T5 | 不新增 App/Backend；先推子仓可达提交再更新父仓；记录各仓 SHA |
| R1–R7 | 公共能力先进模板再串行实例；不覆盖正式镜像；源码验证不冒充部署 |
| 最新所有者决定 | 单人实施、自测及复核，无多家轮次；不伪造独立验收信号 |

## 3. 当时停工快照

- P0-001～006、007D/E、008B/B6、009A～E 已有接受记录；Spike 不代表生产主链。
- P0-008C.0～.4 设计/代码门禁通过；.5 构建和身份探测通过，但部署被 LLM Secret 阻断。
- P0-008C.6/.7 未完成，Gate P0 未闭合；正式 M1 未启动。
- M2 是后续产品化规划；M3 是按指标触发的规模化目标，并非全部都应现在清零。
- M1-313/314 当时已 NOT_APPLICABLE，不重新计为欠账。

## 4. 原任务处置索引

| 原任务 | 保留目标与后续覆盖 | 处置去向 |
| --- | --- | --- |
| P0-008C.5/.6/.7 | 旧 Research/BFF 部署组合不恢复；真实交互与故障验收保留 | N1 |
| M1-001～005 | v2 覆盖公共身份、配置、发布与部分容器/网络证据；不证明新产品资源授权全覆盖 | B7 核存量；N1/N4 补新产品 |
| M1-101 | canonical identity、版本并发 | B3 |
| M1-102 | 抓取 SSRF、流式限额、重定向、时限、来源并发 | B2 |
| M1-103 | 不可变 Artifact 已有；孤儿对象/提交生命周期待核 | B4 |
| M1-104/105 | 公共投递/下游幂等/死信/对账已接；B7c 补 Info 重复创建复用同一逻辑交付；指标、保留与运行态仍欠账 | B7 |
| M1-201 | 稳定领域 ID 和 Provider binding 已有；不能强求照旧名称拆表 | B1 记录已有覆盖，N3 补生命周期 |
| M1-202 | 摄入意图/回执/未知结果阻断已有；真实解析故障范围另核 | B6/B7 |
| M1-203 | B6a/B6b 持久单次轮询及 B7a 共享 SQL/HTTP 日志降噪源码已集成；运行态尚未验收 | B6/B7a 源码；B7b 运行态 |
| M1-204 | 检索白名单已有，摄入目标授权与任意创建限制仍缺 | B5 |
| M1-205 | Retrieval 契约、实现及 R6 真检索已有 | B1 记录覆盖；N3 按失效语义扩展 |
| M1-206 | 停用/删除/reindex、来源失效传播 | N3 |
| M1-301 | 执行身份、配置、调用关系 | N2 |
| M1-302/303 | 创建/恢复事务与命令已做；完整审批、取消及授权仍需产品集成 | B7 核已有；N1/N2 补缺 |
| M1-304～308 | 真实执行、状态、模型、证据、工具/沙箱；已有 Pilot 不等于全产品 | N2 |
| M1-309～311 | 事件事务、SSE 回放、租约已有；产品投影、取消/退出/背压需统一验收 | B7 核已有；N1/N2 补缺 |
| M1-312 | 持久预算、deadline、错误模型 | N2 |
| M1-313/314 | 旧未选 Agent Server/Hybrid 分支 | 旧做法不再实施 |
| M1-400/411A/412 | 旧技术栈/拓扑迁移已由 P0-009、v2、退役工作替代 | 旧做法不再实施；不丢业务等价目标 |
| M1-401～410、411B/C/D、413 | 业务界面、契约客户端、恢复、治理、安全/性能/可访问性 | N1/N4；不恢复双栈 |
| M1-501/502/504 | 迁移 Job、健康检查、发布可追溯底座已有；角色细项待核 | B7；新增执行器交 N2/N4 |
| M1-503 | 已有链路观测与新 Agent 观测分开 | B7/N4 |
| M1-600/601 | R6 真实 S3→解析→检索→Citation 已过；不包含完整模型回答/浏览器产品旅程 | N4 保留剩余验收 |
| M1-602～605 | 全产品故障、安全、质量、canary/恢复 | N4；复用已有局部证据 |
| M1-701/702、M2-001～005、101～105 | 长期记忆、多 Agent、版本兼容及控制面 | N5 |
| M3-001/002 | 公共投递和部分 Provider operation journal 已提前做 | B7 核覆盖，余项按真实 Provider 触发 |
| M3-003～010 | Registry、JSONB 拆分、多租户、扩缩容、分区、灾备、SLO、多 Provider | N6；写触发条件，不提前建满 |

后续完成证据：[R6](architecture-v2/R6-cross-app-vertical-plan.md)、
[R7](architecture-v2/R7-release-closeout.md)、
[退役](architecture-v2/R7.1-legacy-retirement-closeout.md)。
近期投递实现证据在各后端 `docs/durable-delivery-luna.md` 和父仓
`docs/template-alignment-durable-delivery.md`；这些是历史版本证据，不推断当前集群状态。

## 5. 顺序执行包

| 包 | 状态 | 范围、前置与验收 |
| --- | --- | --- |
| B0 基线 | 候选已验证 | 两端 master/Luna 与 Git 远端引用、父子仓及预置脏文件核对；见本文件基线 |
| B1 处置清单 | 已集成 | 原任务有去向；旧做法/已有覆盖/独立修复/后续统一开发分开；正式索引文档门禁 2 份通过；两端 master/Luna 已同步 |
| B2 抓取防护 | 已集成 | B2.1/B2.2 已集成并同步两端 master/Luna；同源串行准入与原消息有界重排、死信重放通过。M1-102 源码子项已具证据；尚未部署，不承诺公平等待/故障分区硬上界 |
| B3 身份与版本 | 源码已集成 | 保守规范化、只读存量核查工具、并发新建/版本与 0008 迁移已同步两端 master/Luna；243 项通过。业务库存量核查、备份与迁移切换尚未执行，不以测试库证据销账 |
| B4 Artifact 对账 | 检测源码已集成 | 只读双向对账、可追踪未登记对象、精确版本写后核验已同步两端 master/Luna；278 项通过。自动修复/回收、周期策略交 B7/N4，实际业务存储未扫描 |
| B5 Dataset 授权 | 源码已集成 | 静态映射、未知目标拒绝、数据面禁建、受理快照及执行/重试/恢复复核已同步两端 master/Luna；173 项及 Info 消费边通过。业务映射/旧任务与一致配置切换未验收 |
| B6 解析调度 | B6a/B6b 源码已集成 | [公共同步证据](v5-backlog-scheduling-luna.md)；[Knowledge 单次轮询证据](v5-backlog-parse-polling-luna.md)。235 项回归及 Info 消费边通过，已同步两端 master/Luna；日志源码由 B7a 补齐，运行态未验收，不把 M1-203 整项销账 |
| B7 已有覆盖收口 | B7a/B7b 源码已集成；其余未完成 | [公共日志证据](v5-backlog-logging-luna.md)；[子项矩阵与健康检查](v5-backlog-coverage-luna.md)。B7b API schema readiness 四仓 931 项、零跳过，两端 master/Luna 同步；下一 B7c Info 逻辑交付去重；投递指标、保留归档和角色活性继续欠账；接 B4～B6 运维/切换；自动修复回收与全引用门禁交 N4 |
| B8 后续移交 | 待实施 | N1～N6 建立待迁入清单与原任务关联；新 dev-plan 真正接收后才标已迁入，不以本文件冒充已完成产品开发 |
| B9 集成与同步 | 实施中 | B1～B6、B7a/B7b 本轮源码子项已集成、同步；后续逐包执行，不等全部；子仓先推、父仓 gitlink 后推；master 预期 HEAD 核对、快进/明确合并；再同步两端工作区；不覆写预置草案 |

每包开工前记录受影响路径、风险/假设、不可变基线、测试与回滚；修改共同底座时
先 tpl，再 Info→Knowledge→Investment，不并行覆盖。发生新架构选择、存量数据冲突或
必须扩大外部操作权限时暂停该包并报告，不用临时默认值改变用户意图。

## 6. 新 dev-plan 接收包（尚未迁入）

| 包 | 要求 | 依赖/边界 |
| --- | --- | --- |
| N1 Web 产品闭环 | 真适配、审批、取消、SSE、刷新/多标签恢复、引用/文件 UI | 统一产品 Task/Interaction 与两路执行器；不恢复旧 BFF 服务 |
| N2 Agent 核心 | 身份映射、Profile 生效、模型/工具、预算/证据、隔离、取消/恢复、版本 | general/pro 分工；云端/本机核心兼容；复用已有投递/副作用账 |
| N3 知识生命周期 | 停用/删除/reindex、旧引用、在途摄入和来源失效 | 跨域契约与迁移；不需要等全部 Agent 完成 |
| N4 产品质量与上线 | 业务治理界面、全链路安全/故障/评估、SLO、受控上线恢复；B4 自动修复/回收及全引用/保留审批门禁 | 绑定最终产品路径；基础 v2 发布和 R6 不等于产品验收，只读对账不等于自动清理 |
| N5 记忆与协作 | 记忆确认/纠错/删除、多 Agent 上下文/预算/调用树、版本兼容 | 薄切先验证；不照搬旧单 Runtime 结构 |
| N6 触发式扩展 | Registry、多租户、规模、灾备、多 Provider | 每项指定触发指标；已做基础不重复建设 |

## 7. 执行日志

- 2026-09-12：完成 B0 只读检查，建立 B1。没有改历史 handoff、新 dev-plan 或两份协议草案。
- B2.1 冻结路径：Info 后端 `infrastructure/external/crawl_http.py`，两个 discovery 适配器，
  正文抓取调用点及对应测试/说明；属于 Info 采集领域，不改模板与受信服务 HTTP。
- B2.1 兼容边界：公网标准端口；不用环境代理；拒绝压缩；跨站不转发采集凭据。
  不增加内网来源权限；来源并发暂未完成。无 DB migration/依赖变更，无部署。
- B2.1 初轮：专项+collector 64 passed；Ruff/Pyright 通过；未配数据库 157 passed / 26 skipped。
  不能把该初轮结果当最终。补齐数据库后 182 passed / 2 skipped（仅缺共享契约向量）。
- B2.1 最终：增加 DNS 进程退出及容量测试、拒绝抓取的真实数据库回归；传入一次性
  `info_backlog_tests` 与模板共享契约向量，**186 passed / 0 skipped**（6.77 秒）。
  Ruff、Pyright 通过；真实 HTTPS GET example.com 返回 200、559 bytes。
  `doc-gate.py --staged` 对本清单及 Info 指南 2 份通过；无 DB migration/依赖变更。
- B2.1 后端固定提交：`info-backend@19243109988f949c6d9520c14f03cb0e2f6fe8fc`，
  tree `5939fa853b90c94b9d187bcc97fc18a1da48b428`。既有子仓开发分支提交，没有新建分支。
- B1/B2.1 集成内容提交：`info-app@55e5e4c8ee91baeac4a9be2972ccf3f747d1e557`，
  `k8s@7ecd97f8ec22ceb2735936e6302d67e27eb508ed`。Info 子仓先推既有开发分支和
  master；父仓在 Luna 提交，再快进本地 master，推送 GitHub/Gitee 的既有 master/Luna。
  使用五仓脚本 `to-remote master` 和 `remote-pull luna` 成功更新云端工作区及子模块；
  其余三父仓没有新提交。以上为内容提交，本日志状态回填另作后续文档提交。
- 集成前在后端固定提交上复跑：**186 passed / 0 skipped**（6.66 秒）。一次性测试
  PostgreSQL 容器已停止并自动移除，测试数据可重建；没有操作业务数据库。
- 本地两份未跟踪协议草案继续保留，未暂存、提交或强制清理；因此没有对本地 Luna
  使用要求全仓干净的 `to-remote luna`，而是精确推送已提交引用后调用 `remote-pull luna`。
- 当前游标：B2.2 来源并发待实施；B3～B8 未完成；源码同步不是部署，未构建或推送镜像。
- B2.2 开工：所有者原话“继续”；沿用单人开发、既有 Luna 分支和逐包源码集成授权。
  基线为 Info 父仓 `55e5e4c`、子仓 `1924310`、k8s `3cb46a29`。
  冻结范围：Info 专用来源锁、抓取/发现入口、接口忙响应、对应测试及文档；不改公共
  DurableTasks、不新增状态表/迁移/配置或分支，不部署。D1/D2 单一业务主档、C2 复用
  既有有界投递与死信重放、I1 共享 application 入口、R6 仅 Info 领域扩展。
  首版固定每个来源一个执行；没有来源 ID 时按标准化主机归组。采用独立 PostgreSQL
  事务的非阻塞 advisory lock，覆盖一次抓取/发现，业务中间提交不释放该锁。
  忙竞争不进入业务抓取、不落终态/Inbox、不新增消息；由既有 reconcile 重排原消息。
  这不是无限等待：持续争用仍可能耗尽公共投递上限并进入可重放死信，不承诺公平队列。
  验收冻结：同源互斥/异源并行、发现与抓取互斥、忙响应与无副作用、异常/取消/进程退出
  释放、真实 DB 重排及死信重放；Ruff/Pyright、全量测试含共享向量。回滚用反向提交，
  无业务数据迁移；无证据的极端网络分区/数据库重启期间外部 HTTP 强制停止不作保证。
- B2.2 核验：两端与 GitHub master/Luna 仍为上述基线；本地预置草案保持不动。
  新增测试发现并修复 IPv6 别名未归一问题；独立测试连接最初被沙箱拒绝，申请权限后重跑，
  不把权限错误算代码通过。专项和原 Info 投递回归 **30 passed**（5.26 秒）；
  全套加共享契约向量 **203 passed / 0 skipped**（9.37 秒），Ruff/Pyright 通过。
  HTTP、S3 注入，PostgreSQL 和锁持有子进程真实运行；无生产或 KIND 验证。
- 当前游标更新：B2.2 候选已验证，进入源码提交/集成；下一包 B3 身份与版本；B3～B8 未完成。
- B2.2 后端固定提交：`info-backend@33f4a1f9444b89f41eaf00a2c4256d76e78b4881`，
  tree `7b04fb4441600c6eebcf0b0562d0f66d099286ab`；7 个精确文件，没有附带其他修改。
- B2.2 固定提交复跑：**203 passed / 0 skipped**（9.27 秒）；静态检查通过。
  一次性 PostgreSQL 容器核对 ID 后已停止并自动移除，测试数据可重建，业务库未操作。
  Info 子仓先推既有开发分支/master，再提交父仓
  `info-app@136112fff0aca2d335d110e44f5f6db69ef521fe`；文档内容提交
  `k8s@0f94a453f748ed2b9c4c383af28049a0d8071c02`，正式索引门禁 2 份通过。
  本地 master 均快进，父仓 master/Luna 已推 GitHub/Gitee；两次五仓 `remote-pull`
  已成功更新云端 master/Luna 及子模块。本条状态回填另作后续文档提交，无部署/镜像变更。
- 当前游标：**B2 源码已集成，下一包 B3**。只读预核仍见 canonical URL 普通索引、
  `max(version_no) + 1`；B2 的来源锁不能替代文档身份唯一性/版本并发，B3 不提前销账。
  B3～B8 尚未完成；两份预置协议草稿继续保持未跟踪、未修改。
- B3 开工：所有者原话“继续”；起点 Info 子仓 `33f4a1f`、父仓 `136112f`、k8s `79b507f1`。
  冻结范围：Info 版本化 URL 身份函数/只读核查、领域模型及写入、单链 0008 迁移、测试与文档。
  D1/D2 保留文档唯一主档，身份键只作派生索引；D6/D7 新迁移及链清单；D8 不启动时迁移；
  C2 原事务索引命令不拆；I1 各入口共用用例；R6 Info 领域扩展；不改模板或跨域契约。
  策略：HTTP(S) scheme/主机规范化、默认端口、空路径、去 fragment；路径/查询不随意重写，
  不移除追踪参数/不排序查询/不合并 HTTP 与 HTTPS。upload:// 既有精确命名语义保留。
  原 canonical_url、文档 ID、版本/制品/投递引用保留；新增 SHA-256 身份键唯一约束，
  新写入必须带身份键，旧写路径失败关闭；upsert 后锁文档，版本号及当前版本同事务。
  迁移先核重复/非法 URL，发现冲突只报数量和样本 ID，不合并、不删除、不泄露 URL 参数；
  降级只撤销本包派生列、写协议列、约束及身份不可变 trigger/function。验收：真实 DB 并发新建/版本/回滚、旧写拒绝、迁移冲突原子回滚、
  升降级/重新前滚与备份恢复演练，全套及共享向量。业务库清单、备份和正式切换仍待独立授权。
- B3 核验：既有文档的旧版本写路径也必须阻断，故增加无 DB 默认值的写协议标记；
  仅要求首次创建的身份键并不充分。URL/身份键冻结，其他治理字段及当前版本仍可更新。
  upload:// 保留现有 Admin 同名版本语义，不冒充未来客户/工作区文件隔离方案。
- B3 自测：Ruff/Pyright 通过；真实 PostgreSQL 17.6 加共享契约向量
  **243 passed / 0 skipped**（12.25 秒）。覆盖 8 并发版本、6 同名上传、重复内容复用、
  stale ORM、竞争回滚、旧写拒绝、摘要冲突、503 行跨批次迁移及回填后约束失败的原子回滚。
  实际 Alembic 空库升级至唯一 0008 head；真实 pg_dump/pg_restore 到独立测试库，
  恢复库降至 0007 再升至 0008，文档/版本/Outbox/迁移记录四表逐行一致。
  真实测试发现流式游标阻止同事务 DDL，已改成关闭结果集的主键分页。只读 CLI 的 ready
  仅对合成数据成立，不能推断业务库不存在重复。S3/HTTP 仍注入，孤儿对象继续交 B4。
- 当前游标：B3 源码候选已验证，进入提交/集成；业务库核查与受控迁移未执行；
  下一包 B4 Artifact 对账，B4～B8 未完成。没有构建镜像或执行部署。
- B3 后端固定提交：`info-backend@14d57d81752660b0a139b2f3827f804ed4fd781d`，
  tree `45a6b8654aa5aff4bacdeed7fd01755444f1c29f`。固定提交复跑
  **243 passed / 0 skipped**（13.16 秒），Ruff/Pyright 通过。
  已推既有后端开发分支与 master，无新分支；一次性 PostgreSQL 容器核对 ID 后停止并
  自动移除，合成测试数据可重建，未操作业务库。父仓与两端工作区同步结果另行回填。
- B3 集成：父仓 `info-app@8f8506a370665d14d63608334dab9e7f68d8b50a`，
  文档内容 `k8s@9566c42ecbb32a14d31d04100b063c07ec9d912d`；暂存文档门禁 2 份通过。
  本地 master 快进；父仓既有 master/Luna 推送 GitHub/Gitee，五仓脚本 `remote-pull master`
  及 `remote-pull luna` 均成功，云端子模块固定至上述后端提交。本条是后续状态回填，
  其余三父仓未改，两份协议草案继续未跟踪且未修改；无镜像/业务库/部署操作。
- 下一游标 B4 只读预核：旧 M1-103 要求 DB 失败后对象不永久失联。现有 S3 写入在
  RawArtifact 入库之前；storage_state 默认为 available，尚未找到 staging/孤儿对账实现。
  这说明 B3 的数据库原子性不能替代对象生命周期；B4 仍待冻结方案、实现及故障验证，
  不能把无文档版本引用的原始抓取对象直接当垃圾删除。B4～B8 未完成。
- B4 开工（所有者原话“继续”）：基线子仓 `14d57d8`、Info 父仓 `8f8506a`、k8s `8ac7a25a`。
  单人 Luna 实施/自测，不新建分支，不修改两份草案。冻结范围为 Info 专属对象存储适配、
  只读双向 Artifact 对账用例/CLI、对应测试与文档；不改公共模板、契约、表或迁移。
  D1/D2 保留 RawArtifact 主档，对账状态仅为可重建观测，不增第二状态表；D4 仅配置的
  Info bucket 与 info/original/ 前缀；C3/C4 不改跨域 DTO；I1 领域用例与运维入口分离；
  T4/T5 子仓先推并记录 SHA；R1/R6 源码候选、不部署，Info 领域能力不改模板。
  最小 reconciler 先做只读检测：S3 所有版本与已登记引用双向核查、稳定游标、有界页面、
  权限错误/缺失/摘要 metadata 不符显式报告；新鲜未登记对象不当作孤儿，任何候选都不是
  删除许可。对象写后按返回 VersionId 核验，不读可能已变化的 latest。
  验收冻结：DB 回滚/提交、S3 成功但回执丢失、同 key 多版本与删除标记、分页恢复、
  403/404/不一致、旧引用保留、全量及共享向量。无存储 DELETE、无自动补写领域记录；
  自动清理/保留策略与生产调度另交 B7/N4，不能把只读检测说成自动回收已完成。
- B4 核验：两端 master/Luna 起点一致且受影响仓干净（预置两份草案除外）。
  RawArtifact 继续是唯一主档，staging/committed 的可见性按对象库存与 DB 已提交记录观测，
  不新增持久 staging 状态。双向检测不穷尽外部分发快照/备份/法律保留，永不输出删除许可。
  S3 PUT 无 VersionId/null 回执现在失败关闭；升级前应受控确认 bucket Versioning，
  不能用业务写入试探。旧本地文件 storage 保持开发语义，本 CLI 拒绝对它假装 S3 对账。
- B4 自测：专项初轮 27 项；完整 PostgreSQL + 真实 S3 + 共享契约向量
  **278 passed / 0 skipped**（16.94 秒），Ruff/Pyright 通过。覆盖 DB 回滚后对象重取、
  PUT 成功丢回执、在途提交前后复扫、历史版本/删除标记分页、缺失/403/不一致、旧引用保护。
  仅随机测试 bucket 有故障制造及自动清理，业务存储/库/Secret/部署均未操作。
- 当前游标：B4 最小检测源码候选进入提交/集成；自动修复/回收、周期运维另交 B7/N4，
  不冒充整个生命周期完成。下一包 B5 Dataset 授权；B5～B8 及业务环境验收仍未完成。
- B4 固定后端提交：`info-backend@034b121cb00ba5889966d385de4d8f9c3697e872`，
  tree `439c5e676543d428985f615139c06e7239914032`；6 个精确文件。
  固定提交全量复跑 **278 passed / 0 skipped**（17.15 秒），已推既有开发分支与 master。
  父仓锁定提交 `info-app@a18f0a584959285ce33cff90ebef421bc064950f`；工作区同步结果另回填。
- B4 同步完成：文档内容提交 `k8s@c594d222aab53737ad6e59fcf0e4f629dcbdfcef`，
  正式索引门禁 2 份通过。本地 master 快进，Info/k8s 的既有 master/Luna 均推 GitHub/Gitee；
  五仓 `remote-pull master` 和 `remote-pull luna` 均成功，云端后端固定到 `034b121`。
  本条为后续状态回填。两个一次性 PostgreSQL/S3 容器核对 ID 后已停止并自动移除，
  测试 bucket 随用例回收，合成数据可重建；业务对象无删除，业务库/部署未变。
  其余三父仓无改动，两份预置协议草稿未修改/未跟踪；下一包 B5，B5～B8 未完成。
- B5 开工（2026-09-13，所有者“继续”）：Knowledge 父仓 `456205f`、后端 `72f17d2`，
  k8s `5edb2a62`。单人 Luna 实施/自测，既有分支；冻结 Knowledge 领域配置与授权用例、
  受理/dispatch/retry/Worker/恢复/最终绑定、RAGFlow 数据集选择及相应测试文档。
  D1/D2 不新增表或迁移，授权快照追加于已有 accepted 首条历史（与 job/Outbox 同事务）；
  C1/C2 保留公共投递/回执/未知结果阻断；C3/C4 DTO 不变，但新增拒绝语义须测 Info 消费边；
  I1 Admin/Internal 共用授权，I3/I5/I7 保留现有身份边界；T4/T5 子仓先推并记录 SHA；
  R1/R6 不部署，Knowledge 领域扩展不改模板。
  配置为空默认拒绝全部摄入，不借检索白名单授权写入；静态 key→既有 ID/name，禁止
  数据面自动建 dataset。受理快照与执行时配置必须一致，旧无快照任务、撤权/改绑、
  force retry/恢复越权均失败关闭；不猜测回填旧任务，不改变历史回执身份。
  验收：未知目标前置拒绝且无 job/Outbox/远端写入，两面同用例；真实 DB 并发受理、
  重试/Worker/恢复撤权、错 ID 同名目标拒绝、无创建、已有可靠投递回归及共享契约。
  实际映射、存量任务处置、凭据/部署切换另验；无业务 dataset 创建/删除或 Secret 修改。
- B5 核验：两端受影响 master/Luna 与上述基线一致。采用 INGESTION_DATASET_BINDINGS
  默认 {} 全拒绝；快照位于首条 accepted 历史，客户端 document.metadata 与 Admin 状态
  metadata 均不能充当授权。核查发现空历史旧任务可被 status metadata 冒充首条受理，
  已明确拒绝 status 写保留授权字段，并补测试。没有新增领域状态表或修改契约 schema。
- B5 自测：原可靠投递回归 145 passed（去掉已废弃的 dataset 创建丢回执变体，保留
  upload/parse 丢回执并改测零 dataset 创建）；完整 **173 passed / 0 skipped**（10.55 秒），
  Ruff/Pyright 通过。Info 固定源码 `034b121` 契约/分发 6 passed（0.94 秒），Knowledge 的
  202/403 实际 ASGI 响应还经子进程加载 Info 真客户端消费。DB 真实，身份/Provider/HTTP
  传输注入，不宣称真实业务 RAGFlow、跨机部署或 IAM 验收。
- 当前游标：B5 候选进入提交/集成，下一包 B6 解析调度。静态 Settings 有进程缓存，
  不是即时撤权广播；必须排空旧 API/Worker 并一致切换配置。未配置会拒绝全部新摄入；
  旧无快照任务不自动迁入，处理与真实映射/凭据/部署验收留 B7/N4，B6～B8 未完成。
- B5 后端固定提交 `knowledge-backend@81df172cd6dd1b92ed057a369a9fcc3c375ea9d8`，
  tree `8effc27f841876b135e646df9e947bb9d0aaf2b6`；9 个精确文件，无新分支。
  固定提交复跑 **173 passed / 0 skipped**（10.77 秒），已推既有开发分支与 master。
  父仓及两端工作区同步结果另回填；Info/模板/Investment 源码未改，契约 schema 未改。
- B5 同步完成：父仓 `knowledge-app@f65dc8682573ab906682089f9b266e8605e68e36`，
  文档内容 `k8s@60ae2496a1775308165d2baccd8effb1ccbf22ba`，正式索引门禁 2 份通过。
  本地 master 均快进，父仓既有 master/Luna 推 GitHub/Gitee；两次五仓 `remote-pull`
  已成功同步云端 master/Luna 及后端子模块。此条为后续状态回填。
  一次性 PostgreSQL 测试容器核对 ID 后停止并自动移除，合成数据可重建；没有业务库、
  dataset、Secret、镜像或部署变更。两份预置草案未改/未跟踪，其余三父仓无改动。
  下一包 B6，B6～B8 与前述业务环境验收仍未完成。
- B6 开工（2026-09-13，所有者“继续”）：两端 Knowledge/k8s 起点与 B5 同步记录一致。
  核查发现 available_at 已用于发布退避，但 enqueue_task 无延迟入口，消费者未检查
  原始最早执行时间。先拆 B6a 公共持久定时，再做 B6b Knowledge 单次解析轮询。
  B6a 冻结四后端的 Outbox DTO、入队/发布/消费、仓库与同构测试，以及处置文档；
  模板基线 ca670325、Info 034b121c、Knowledge 81df172c、Investment 00b1b55c。
  单人 Luna，原分支，不碰两份未跟踪草案。D1/D2 继续只有公共 Outbox，不新增表/迁移；
  最早执行时间作为保留的版本化消息 header 保存不可变意图，available_at 仅作可变调度
  投影；C1/C2 保留事务/幂等/死信/重放/对账；C3/C4 不改跨 App 领域契约；I1 无新接口；
  T4/T5 子仓先推、记录固定 SHA；R6 模板门禁后 Info→Knowledge→Investment 串行。
  验收：未到期发布/消费零执行、零重试扣次；到期可执行；重投不改原定时；变更定时的
  同幂等键拒绝；重放/对账不能提前执行；领域状态+后续命令+Inbox 原子提交/故障回滚；
  全套真实隔离 PostgreSQL 与共享契约向量。仅源码候选，部署/身份/KIND/回滚运行态
  仍交 B7；混跑旧消费者不具备新定时保证，启用前必须排空并统一升级运行角色。
  B6b 才负责解析 deadline/backoff、重试代次、Provider 回执及不重复上传；B6a 不冒充
  解析链已非阻塞。旧入口无定时参数保持原语义，不依赖 Celery 内存 countdown。
- B6a 实例核查：Investment 的 AgentDelivery 采用领域 session 租约，覆盖了通用
  claim_execution；须显式接入模板的同一 NOT_BEFORE_DUE_SQL，不复制另一套判时策略。
  纳入本包消费扩展点及真实 Agent DB 的到期/未到期/重放测试，未改变 Agent 编排或审批。
  Info/Knowledge 仍使用通用消费者；其领域文件与历史功能保持不变。
- B6a 固定源码验证：模板 30a106689739601916c322b0159fce5829c99a69（80 passed，
  4.72 秒）、Info 6a2be5768c524a985ddcde3bec5ae28e01ff0606（293 passed，19.90 秒）、
  Knowledge 1e26b74fc5993cd425ecccd68010e35579700af5（188 passed，12.44 秒）、
  Investment 8228a0fc83caab62159745cd0b95a9c37e0b74e7（215 passed，13.85 秒）。
  四仓 Ruff/Pyright 通过，最终均 0 skipped；真实隔离 PostgreSQL/S3/Redis 和共享
  契约向量。Investment 初轮漏测试环境变量导致跳过 22 项，补齐后完整复跑；Redis
  Docker Hub 下载超时，改用本机已有 Bitnami 8.2.1，没有操作业务 Redis 或拉取替代源码。
  7 个公共文件逐字一致，Investment 另有 2 个领域消费扩展/测试文件；详见本包证据。
  当前进入子仓先推、父仓锁定和两端同步；B6b～B8 及所有实际部署门禁仍未完成。
- B6a 同步完成：四父仓 tpl-app@7ae62d9、info-app@86f0842、knowledge-app@b15c9d2、
  investment-app@cb2eefb；文档内容 k8s@2a2117f1，暂存门禁 2 份通过。
  子仓先推既有 master/Luna 远程 ref，父仓 master/Luna 已推 GitHub/Gitee；本机 master
  快进，五仓脚本 remote-pull master / remote-pull luna 均成功，云端子模块固定到上述
  后端提交。本条为同步后的状态回填，不新增分支，不执行 force/realign。
  三个一次性 PostgreSQL/S3/Redis 容器核对完整 ID 后停止并自动移除，只有可重建测试
  数据被清理；业务库/对象/Secret/镜像/部署未改，两份协议草稿未动。
  下一游标 B6b：Knowledge 单次轮询、持久 deadline/backoff、代次安全和回执原子接续。
- B6b 开工（2026-09-13，所有者“继续”）：本机/云端基线 Knowledge 父仓 b15c9d2、
  后端 1e26b74、k8s 7d1359ea；受影响仓干净，两份预置协议草案除外。单人 Luna，原分支。
  冻结 Knowledge 领域执行状态、摄入服务、Provider 编排、handler、解析配置/状态规范化、
  对应测试和文档。D1/D2 在既有 job.metadata_json 的保留命名空间维护唯一执行状态，
  原请求仍留在 payload；首条受理历史保存服务端协议标记，禁止客户端/Admin 伪造。
  旧无标记任务/无代次消息失败关闭，不能从用户 metadata 的 retry_count 猜执行代次；
  旧任务调查/迁入交 B7，不自动回填。无表/迁移；D4/D5 原文及已验证上传回执不变；
  C1/C2 使用 B6a Outbox 同事务接续，既有未知副作用阻断保留；C3/C4 schema 不变但
  保留字段拒绝语义要测 HTTP/Info 消费边；I1/I5 两面同用例、执行时复核绑定及 provider。
  T4/T5 先子后父固定提交；R1/R6 无部署、不改公共模板，Knowledge 领域扩展。
  硬门禁：单次 poll 无 sleep/上传/源文件重读；持久 DB-clock deadline 和有界 backoff；
  旧代次/旧游标重放无副作用；并发 retry 后旧 Worker 不能提交（覆盖 ORM 自动 flush）；
  确认结果、下一命令、Inbox 原子性；提交丢回执/进程退出/超时/FAIL/CANCEL/撤权/HTTP
  查询故障恢复及全量 DB/契约回归。Provider 网络与身份注入不冒充真实 RAGFlow 验收。
- B6b 核验补充：普通 poll 不锁 job 跨 HTTP；commit 与 autoflush 双重代次检查，
  retry/dispatch 锁行时刷新 ORM 缓存，防止旧缓存重复发起重试；消息资源键也必须匹配
  upload_identity。进入解析后移除凭据不能降级为 artifact_verified。原始 metadata 的
  retry_count/非列表 retry_history 不授予执行控制，原请求仍保留在 payload。
- B6b 固定后端 knowledge-backend@2212e461ef7428fc4f4b321b6f3deb92ea4630af，
  tree aae97b4d73950ba3f35ae1e93c84e64d2b880f1b；9 文件。固定提交复跑
  **235 passed / 0 skipped**（21.78 秒），Ruff/Pyright 通过；包含真实子进程 kill 后
  的过期租约恢复及 45 项新领域测试、2 项新 HTTP 变体。Info 6a2be57 分发/契约
  **6 passed**（0.70 秒）。新消息的 domain/Outbox/Inbox 接续为同事务；未知副作用
  中间回执仍单独持久，不能混称所有步骤一次事务。
  当前进入提交后的集成/同步；B7 接旧协议调查/切换/运行态及 M1-203 日志降噪，
  B8 与产品开发未完成。没有业务库迁移、Secret、应用镜像或部署操作。
- B6b 同步完成：knowledge-app@c1bde217a89587709a2f8e45db8964cee059951f；
  文档内容 k8s@19fa5b29c0412659f92c76240f38484f52abcb31，暂存门禁 3 份通过。
  子仓先推既有 master/Luna ref，父仓 master/Luna 推至 GitHub/Gitee，本机 master
  快进并对齐子模块；五仓脚本 remote-pull master / remote-pull luna 均成功。
  云端 Knowledge 子模块固定为 2212e46，其他三 App 父/子仓未变；此条为后续状态回填。
  一次性 PostgreSQL 测试容器按完整 ID 核对后停止、自动移除，合成测试数据可重建；
  业务数据/Secret/应用镜像/部署未动。两份预置协议草案仍未跟踪且未修改，无新分支。
  下一游标 B7：核已有覆盖与未验收子项；B8/新版 dev-plan 的正式接收仍未完成。
- B7a（2026-09-13，所有者“继续”）：核实旧 M1-203/M1-503 日志子项缺口，
  冻结工作单元见 [B7a 证据](v5-backlog-logging-luna.md)。模板先行，随后严格串行
  Info → Knowledge → Investment；每后端 5 个精确文件，共享库策略四仓一致，领域
  Worker/调度不覆盖。关闭开发期自动 SQL echo，隐藏绑定参数，SQL/HTTP 库 WARNING；
  API 与 Celery 日志入口均验证，保留审计/任务/告警，不宣称完整脱敏。
  固定提交 tpl-backend@553c36b、info-backend@f2c4001、knowledge-backend@e99a894、
  investment-backend@9622af0 全量依次 **88/301/243/223 passed，全部零跳过**，
  Ruff/Pyright 通过；真实一次性 PG/S3/Redis，新增专项每仓 8 项，不冒充容器消费测试。
- B7a 集成：tpl-app@9229d6a、info-app@2756db4、knowledge-app@deaa49b、
  investment-app@00e2118；文档内容 k8s@733292e7，文档门禁 3 份通过。
  四子仓先推既有 master/Luna ref，五父仓 master 逐一核对旧 HEAD/干净状态后快进，
  推送 GitHub/Gitee；五仓脚本 remote-pull master / luna 均完成，此条是后续状态回填。
  已核对完整 ID 并停止三个一次性测试容器，自动移除确认无残留；只有可重建测试数据。
  本地两份预置草案保留，未新建分支、force/realign、修改业务库/Secret、构建/推送镜像或部署。
  下一游标 **B7b 子项矩阵及健康/指标/归档/恢复核验**；源码发现 ready 未校验 schema、
  Worker ping 不充分证明消费活性，仍待处置。B8/N1～N6 新 dev-plan 接收尚未完成。
- B7b（2026-09-13，所有者“继续”）：重新核对两端 master/Luna 五仓基线一致、云端干净；
  形成 [验收子项矩阵](v5-backlog-coverage-luna.md)，按开工源码区分已有、缺口和未验收。
  发现 Info create_knowledge_distribution 每次新建 UUID，稳定下游幂等键不能证明返回
  同一逻辑交付，此项保留为 B7c；未把存量指标/归档/角色活性偷换为未来产品已完成。
  本包冻结每后端 4 文件：API 入口、schema_readiness、专项测试、说明；D1/D2/D8 只读
  本 App 版本表，以镜像迁移链为唯一期望真源，不 stamp/upgrade/提权；R6 模板先行再
  串行 Info → Knowledge → Investment。2 秒协作式超时、异常和错版本 503、取消传播，
  live handler 无依赖；版本匹配不证明表完整、DB 身份或业务权限，不覆盖 Worker/Scheduler。
- B7b 固定回归：tpl-backend@ed8d5dc、info-backend@96e3762、knowledge-backend@40edfc2、
  investment-backend@85f8cb7，依次 **107/320/262/242 passed，全部零跳过**；Ruff/Pyright
  通过。每仓 19 新测试，真实 PG 迁移/降级/再升级、SELECT 角色、锁超时与恢复；旧全套
  含 S3/Redis/契约。脚手架 8 tests OK 不冒充真实部署或迁移失败注入。
  内容父仓 tpl-app@5487755、info-app@2b4f18b、knowledge-app@dd8c7ff、
  investment-app@6d6b014；k8s@9f22c7e4（初次文档门禁 3 份），本条是后续状态回填。
  子仓先推、父仓 master 核预期 HEAD/干净后快进；五父仓 master/Luna 推至 GitHub/Gitee，
  五仓 remote-pull master / luna 均完成。测试容器按完整 ID 核对后停止、自动移除且复查
  无残留，仅清理可重建测试数据；业务库/Secret/镜像/部署未动，两份预置草案保留。
  下一游标 **B7c Info 逻辑交付去重**；其它 B7 子项和 B8/N1～N6 正式接收仍未完成。
- B7c（2026-09-13，所有者“继续”）：范围与约束见
  [逻辑交付去重证据](v5-backlog-distribution-identity-luna.md)。单人 Luna、Info 领域扩展，
  不改模板或跨 App DTO；版本行锁串行创建、数据库版本/App/dataset 唯一索引兜底。
  重复请求返回原 ID/Artifact/回执/历史；仅 pending 可确保原代次命令，不隐式 retry。
  0009 线性迁移，冲突先核查后阻断，无历史合并/删除/重键；只读 CLI 样本有界，
  新写协议列无数据库默认值，旧 INSERT 拒绝，身份字段不可改写。
  固定后端 info-backend@d607d8e90d36ad2f51a006dbb4cec4fda200f1e8（9 文件），
  tree d2ce72e2119d906198cdc73feb27fa925473e020；源码已验证，固定复跑与同步回执另补。
  业务数据库、凭据、应用镜像、部署均未操作；两份未跟踪协议草稿保留。
- B7c 固定提交复跑 **351 passed / 0 skipped**（38.79 秒），Ruff/Pyright 通过；
  新增 31 项；Knowledge@40edfc2 配对摄入/授权/投递 **78 passed / 0 skipped**。
  合成数据实际 pg_dump/pg_restore 后，1 条交付和 2 条 Outbox 保持一致，恢复库
  升级/降级/再升级及重复创建通过；版本表往返由独立实际 Alembic 测试覆盖。
  首轮既有抓取并发取消用例一次失败，单独及后续两次全量未复现，根因未定，留 B7
  活性核查线索；未修改/跳过用例，不宣称该问题已修复。
  父仓 info-app@253869fc67d1fae5bc7336863f6781aaf7513647，初次内容
  k8s@eeb645beb8dc1b311bf3cc4d8e1f7f5300278e42（4 文档门禁），此条为后续状态回填。
  子仓先推、父仓 master 核预期 SHA/干净后快进；父仓 master/Luna 推 GitHub/Gitee，
  五仓脚本 remote-pull master / luna 均成功，SSH 复核云端五仓干净且受影响 SHA 一致。
  两个一次性 PG/S3 容器核完整 ID 后停止并自动移除，确认无残留，仅可重建合成数据；
  业务数据/Secret/镜像/部署未变，两份协议草案未改。下一游标 **B7 指标/角色活性/
  归档与运行门禁**；B7 整体和 B8/N1～N6 新 dev-plan 正式接收仍未完成。
- B7d（2026-09-13，所有者“继续”）：[冻结范围与证据](v5-backlog-delivery-observation-luna.md)。
  单人 Luna，模板先行后严格串行 Info→Knowledge→Investment。只读观测既有 Outbox/
  Inbox/死信/租约，JSON v1 和 Prometheus text gauge；无新表、迁移、HTTP 端点或状态写入。
  policy/topic 标签仅来自有界代码注册，未知 topic 只计数量；消费映射与执行租约使用实际
  Delivery 扩展，Investment 单独装配 AgentDelivery，不误用空公共 handler 或公共租约表。
  REPEATABLE READ/READ ONLY、DB 语句及整体超时；读取失败退出 2，不输出秘密、假零
  或半份快照。快照时间可识别过时数据，但不证明 Worker/Scheduler 活性。
  实际 scrape/告警/角色探针与归档仍在 B7，禁止用本包的 CLI 输出冒充已接监控。
