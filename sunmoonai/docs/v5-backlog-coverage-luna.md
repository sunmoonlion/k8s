# B7b：存量验收子项核对与 API schema readiness（Luna）

日期：2026-09-13。状态：首轮子项核对已记录；API readiness 源码已集成并同步两端 master/Luna；未部署，B7 整包未完成。
单人实施与自测，不宣称独立验收。历史依据为
[旧实施计划](mooc-manus-langgraph-v5-implementation-plan.md)与
[旧暂停 handoff](mooc-manus-langgraph-v5-handoff-20260712.md)，不从新版 handoff 反推欠账。

## 1. 证据边界与基线

所有者原话“继续”，沿用[处置清单](v5-backlog-disposition-luna.md)授权。
本轮只读源码、测试及部署声明；未查询业务记录、扫描业务桶、读取 Secret 值或操作集群。
旧 R6/R7、2026-09-11 投递报告是其固定版本证据，不当作本轮运行结果。

两端 master/Luna 五父仓已重新核对一致，云端干净；本地只有预置 general/pro 两草案。
父仓基线：tpl `9229d6a`、Info `2756db4`、Knowledge `deaa49b`、Investment `00e2118`、
k8s `5d79cee8`。后端：tpl `553c36b`、Info `f2c4001`、Knowledge `e99a894`、Investment `9622af0`。

矩阵中的“已有源码”只对列出的子能力成立；“未核验”不等于没有实现；“源码缺口”是
本次实际路径核对发现的欠账，必须继续处置，不直接藏进未来产品计划。

## 2. B7 验收子项矩阵

路径均以所属后端的 `app/app/` 为根，另标父仓/k8s 的除外。
缺口按第 1 节开工基线记录；API 修复结果见第 4 节，不把旧缺口当修复后的现状。

| 子项 / 原任务 | 本次核对的载体与结论 | 去向 / 尚缺验收 |
| --- | --- | --- |
| 身份分面 / M1-001 | `interfaces/http/routes.py`、auth middleware 与 Admin/Web/Internal 分面、现有 auth tests | 已有基础；新 Task/文件/审批的逐资源授权仍属 N1/N2，不能据分面存在判全覆盖 |
| 服务身份 / M1-002 | `infrastructure/security/service_identity.py`、`core/config.py` 的 subject/scope 精确绑定 | 基础已有；真实独立撤销、当前角色凭据和轮换证据需受控运行验收 |
| Secret / M1-003 | 源码配置校验和部署 Secret 引用不等于全 Git 历史扫描与有效凭据轮换证明 | 当前扫描/轮换/CI 和最小挂载尚未核验；不得输出秘密或自行轮换 |
| 配置与流量 / M1-004 | 模板 `k8s-deployment/deployment_config.py`、`deploy.py` 及 v2 release/bundle 门禁 | 替代旧 Research traffic-mode；当前 Git/运行态漂移仍待只读核对，不执行 apply 冒充核验 |
| 网络/容器 / M1-005 | 模板 network policies、runtime 非 root/drop capabilities/read-only FS 声明；[B7g](v5-backlog-network-gate-luna.md) 已复现旧 DNS 首败、修门禁并在全新 Calico 验证当前 Info 策略六条流向 | 仅 Info 声明与合成目标包级证据；不是业务镜像/其他 App/真实身份全验收；常驻 KIND kindnet 不 enforce |
| 分发载体 / M1-104 | Info `info_crawl_service._artifact_contract_payload` 有 contract_version、版本/Dataset 稳定幂等键、correlation；公共 Outbox 有 attempts/available_at | 字段与传输基础已有，不要求按旧表名重造第二本账 |
| 逻辑交付去重 / M1-104 | B7b 核查时每次新 UUID + INSERT，无版本/Dataset 唯一约束；后续 B7c 补复用、唯一索引和写入护栏 | [B7c 源码验证](v5-backlog-distribution-identity-luna.md)；业务库冲突调查、备份与角色切换仍待验收，下游幂等不能替代本地逻辑身份 |
| 发布/Inbox/租约 / M1-105、M3-001 | `DurableTasks`、公共 `durable_delivery.py`、Outbox repository、各领域 handler、真实 PG 故障测试 | 已有源码及分包固定提交证据；新版本正式环境 broker 故障/丢回执/kill 仍未验收 |
| 对账/死信重放 / M1-105 | 5 秒 Beat pump、`cli/durable_delivery.py` reconcile/replay/dead-letters；重放不删 Inbox | 机制已有；实际调度活性、告警到达、权限与运行策略待核 |
| 保留/归档 / M1-105 | [B7k 固定源码审计](v5-backlog-retention-audit-luna.md)核清 FK 之外的去重、恢复读原命令、Provider 跨任务回执与 epoch 依赖，区分两种 legacy；[B7j](v5-backlog-worker-progress-luna.md) 已实测 Investment 空旧归档仍拒绝隐式 Outbox 删除 | **实施未收口**；引用审计和候选实施门禁已成文，批准保留/重放窗口、实际盘点/恢复与旧表退役待完成；未删除、不默认保留天数，也未冒称 B8 已接收 |
| Provider 意图/未知结果 / M1-202、M3-002 | Knowledge `ragflow_delivery.py`、Investment 副作用账与 adapter 边界 | 已有部分 Provider 实现；不是通用跨 Provider 全覆盖；真实 parse/迟到响应/未知回执处理仍需按 Provider 验收 |
| 单次 parse / M1-203 | B6a/B6b 持久调度与 B7a 日志源码 | 已有源码；实际长 parse Worker 占用/切换、旧协议调查与回滚未验收 |
| Run 创建 / M1-302 | Investment `application/agent/run_service.py` 与持久命令、真实 PG 故障测试 | 已有基础；产品 Task/Attempt、浏览器通用/专业入口由 N1/N2 接收 |
| 恢复/取消 / M1-303 | run_service 的单次恢复、Pilot 的 request_cancel 与执行适配 | 不代表统一 token hash/expiry/跨用户/取消竞态全覆盖；N1/N2 按产品合同统一，不能复活两套内核 |
| Journal/投影 / M1-309 | `application/agent/event_sink.py` 同事务事件与通知；既有 SSE 回放 | 已有事实基础；完整 UI 投影可重建、最终对账与产品旅程仍 N1/N2/N4 |
| SSE / M1-310 | 持久事件与 Redis 提示分离，既有 cursor/回放路径与测试 | 不据局部回放判 heartbeat/backpressure/跨设备最终恢复全通过；N1/N2 统一验收 |
| 租约/退出 / M1-311 | 公共与 Agent execution lease、epoch、心跳、真实子进程 kill 测试；Pod preStop 声明 | 源码及隔离 kill 已有；实际 SIGTERM drain/Pod eviction/回投窗口待运行验证 |
| Migration Job / M1-501 | 模板 `deploy.run_migration` 等待独立 Job，失败抛错阻止完整 apply 后续 runtime；bootstrap 无隐式迁移 | 已有编排；当前角色权限、业务备份/恢复、revision/发布关联待验，不凭 Job 完成判所有数据库正确 |
| API readiness / M1-502 | 四仓 ready 仅 Redis ping/SELECT 1；没有 revision 检查和端点内统一 deadline | **本包修复**：只读精确版本检查及协作式探测超时；不迁移数据库 |
| Worker/Scheduler / M1-502 | 旧实例 bundle 仍为 `inspect ping`；[B7e](v5-backlog-worker-readiness-luna.md) 补本节点队列/注册检查；[B7i](v5-backlog-scheduler-activity-luna.md) 补 Scheduler 本机活动；[B7j](v5-backlog-worker-progress-luna.md) 补匹配 Inbox 回执只读进展及真实 prefork 暂停/恢复/回滚/重复，四仓最终 1569 项零跳过 | 源码与隔离进程证据已补，未部署；实际 Worker 负载/身份、Scheduler 运行策略与 startup/live 仍待验，不把聚合回执当 per-worker 健康或产品成功量 |
| 关联/日志 / M1-503 | API audit context、Outbox/领域 correlation；B7a 公共库降噪 | 部分已有；跨全链 correlation 覆盖、结构化字段与隐私仍需核，不等于全量脱敏 |
| 指标/告警 / M1-503、M1-105 | [B7d](v5-backlog-delivery-observation-luna.md) 补只读 gauge/CLI；[B7h](v5-backlog-metrics-http-luna.md) 补受保护 HTTP；[B7j](v5-backlog-worker-progress-luna.md) 补已提交回执聚合及故障恢复 | 观测/受保护入口源码已补；实际监控部署、采集/新鲜度/告警到达与 broker queue 接线已按所有者决定交未来 [N4-OPS-01](dev-plan/implementation-plan.md)，尚未实施；新 retrieval/run/SSE 产品指标仍 N4，不算整套观测完成 |
| 发布可追踪 / M1-504 | 既有 digest bundle/release manifest/父子仓 gitlink；本轮 B2～B7 仅源码更新 | 底座已有，不可把源码 SHA 当当前 imageID；按源码→镜像→角色→数据统一发布，不能回填历史 release |
| B4 对账运维 | Info `cli/reconcile_artifacts.py` 只读报告，原文主档不变 | 周期、权限、保留和业务扫描未验；自动修复/GC 与全引用审批门禁 N4 |
| B5/B6 切换 | Dataset 授权快照、执行协议标记和代次均失败关闭 | 真实绑定、旧任务/回执调查、排空、一致切换和可回滚窗未验，禁止新旧消费者混滚 |

N1～N6 除 N4-OPS-01 监控子项已被新版实施计划接收外，仍指既有待迁入包。上表是首轮覆盖核对，
既有测试来源是各包固定提交报告，不把本次只读搜索写成已复跑全部历史运行验收。

## 3. API readiness 冻结工作单元

只改每后端 `bootstrap/api.py`，新增 `infrastructure/storage/schema_readiness.py`、
`tests/test_schema_readiness.py`、`docs/schema-readiness.md`；三个父仓对齐报告、模板指南、
本矩阵与处置清单。不修改 API 路径/响应结构、领域、模型、迁移链、依赖、Secret 或部署清单。

| 规则 | 处置 |
| --- | --- |
| D1/D2/D8 | 迁移链为期望版本唯一真源；只 SELECT 当前 App 的 alembic_version，不 stamp/upgrade/建表 |
| I3/I8 | 使用现有 API 数据库 principal；缺 SELECT 权限即不 ready，不提升权限；不泄露版本或连接信息 |
| R6/T3 | 模板先门禁，再 Info → Knowledge → Investment；只修 API，Worker/Scheduler 单列欠账 |
| C3/C4、T4/T5/R1 | 不改 provider schema；完整回归含契约；先子后父提交与同步，不构建/部署 |

策略：从打包 Alembic scripts 取得单 head（只读脚本，不运行 env.py/迁移），不新增影子配置；
数据库必须恰好一个相同 revision，缺表/空/旧/超前/多个版本/包损坏/权限或连接失败均 503。
数据库值每次重新查询，不缓存“已 ready”。单次 Redis + DB 检查总计 2 秒协作式 timeout；
外部取消继续传播，超时返回原通用 not_ready，live 不依赖数据库。2 秒不是任意驱动的强制杀死保证。

严格相等不自动承诺 expand/contract 的跨版本兼容。升级与回滚必须联合数据库版本，
不得因为新代码 503 就把旧代码指向超前数据库、擅自降级或放宽检查。
版本匹配不是全表完整性/权限/数据不变量证明，也不能阻止绕过 readiness 直连 Pod 的请求。
不同 App 可能使用相同 revision 字符串，数据库名/角色/所有权隔离仍由独立部署门禁核对，
不能以版本相等证明没有接错数据库。

验收冻结：真实隔离 PG 迁移/降级/重新升级；缺表、空表、旧/超前/多个 revision、权限拒绝；
包缺失/空/多 head；三个 ready 别名与 live、503 脱敏、Redis 故障/慢调用、DB 锁等待超时、
请求取消、恢复后重新 ready；Ruff/Pyright + 四仓完整回归（PG/S3/Redis/契约），无跳过。
不以测试角色权限代替当前业务 API principal 验收。回滚用反向提交，无业务数据变更。

## 4. 实施与同步证据

按模板 → Info → Knowledge → Investment 完成串行实现、静态和完整回归。
每后端恰好 4 文件，schema_readiness、测试、后端说明 SHA-256 四仓相同；API 保留
各自身份/路由扩展，只加入同一增量。没有新增迁移、依赖、配置字段或协议分支。

| 后端 | 固定 commit | 完整回归 | 时间 |
| --- | --- | --- | --- |
| tpl-backend | `ed8d5dcbd72cb2d4fea555a2e9fb35c599ef4391` | 107 passed / 0 skipped | 13.09 秒 |
| info-backend | `96e376241fce87ae7d34fc4e6dd18f50129119af` | 320 passed / 0 skipped | 30.08 秒 |
| knowledge-backend | `40edfc28292964ad18ab5a29d852aa8feeb7043c` | 262 passed / 0 skipped | 27.84 秒 |
| investment-backend | `85f8cb77617fe357fafddbe20b1b933318eda6ed` | 242 passed / 0 skipped | 26.87 秒 |

Ruff/Pyright 均通过；后端合计 931 项（各仓含共享场景，非 931 种不同场景），每仓新增 19 项。
新测试由 Alembic EnvironmentContext 实际执行本仓迁移并记录版本表，真实降级后 503、
重新升级后 200；不是仅给空库 stamp。真实 PG 版本表锁等待被取消后连接可再次使用。
测试专用 NOLOGIN 角色仅授版本表 SELECT 即可探测，撤销即 503；不提升业务角色权限。
记录实际探针 SQL 只有 SELECT；三个别名/无依赖 live、缺表/空/旧/超前/多行、损坏打包、
Redis 异常与负向 ping、超时、请求取消和恢复均覆盖。

新 HTTP 探针通过实际 ASGI factory，Redis ping/连接错误受控注入；锁等待、迁移和权限是
真实一次性 PG。既有完整回归含真实一次性 S3/Redis 和共享契约向量。不冒充 KIND、真实
Casdoor、业务主链/Provider、业务角色授权或发布/备份恢复验收。初轮测试格式及过宽异常
断言由 Ruff 检出并修正，没有降低门禁或更新依赖。

B7 其余缺口按第 2 节继续，下一源码工作先处理 Info 逻辑交付去重，再逐项核指标、角色
活性与归档/运维。B8 尚未启动正式接收，不以本表替代新版 dev-plan。

模板父仓部署脚手架额外只读回归：`python3 -m unittest discover -s k8s-deployment/tests -q`
**8 tests OK**（0.239 秒）。这些是配置、渲染和局部组件选择测试，不是迁移失败注入、
完整发布或当前集群验收；本轮没有运行带 apply/凭据重建的旧 R7 gate。

## 5. 源码同步与清理回执

| 父仓 | 内容提交（锁定第 4 节后端） |
| --- | --- |
| tpl-app | `54877558ae43b41be3d64b1c8388fc8df9f68b7d` |
| info-app | `2b4f18bd46a46a4ebf848a3fa1dbe6ac2e39d6c4` |
| knowledge-app | `dd8c7ff5b8b201bd8c3fe1dcf3785d046061b41a` |
| investment-app | `6d6b0142ec8d541740856ea5f52bbbcca7805044` |
| k8s 初次内容 | `9f22c7e4513cff0e48e180e27c69420afe25d3fb`（本节另作后续状态回填） |

四后端先推既有 master/Luna ref；父仓在 Luna 提交，再核对本地 master 预期旧 HEAD 和
干净状态后逐仓快进、更新子模块。五父仓 master/Luna 已推 GitHub/Gitee；五仓脚本
`remote-pull master` 与 `remote-pull luna` 均完成。初次 k8s 三份文档门禁通过。
没有新增分支、force/realign；预置两份 general/pro 草案未暂存、修改或传至云端。

一次性 PG/S3/Redis 三容器逐个核对完整 ID 后停止并自动移除，复查无残留；清理的
只有可重建测试数据。未操作业务库/桶/Secret，未构建镜像、推送 Harbor 或部署。
上述为 B7b 当时游标。B7c 的后续源码与同步结果见
[逻辑交付去重证据](v5-backlog-distribution-identity-luna.md)；指标/角色活性/归档/真实环境
门禁及 B8 仍未完成。

B7d 的后续观测与实例对齐见[只读投递观测证据](v5-backlog-delivery-observation-luna.md)。
B7d 当时入口无 HTTP 暴露面；B7h 后续加入专用 scope 保护的 HTTP，仍无业务写入；
没有因只读快照成功就关闭 Worker/Scheduler、
告警接线、归档或其它真实环境门禁。
