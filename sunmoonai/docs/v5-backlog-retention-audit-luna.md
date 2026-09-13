# B7k：可靠投递保留与归档引用审计（Luna）

日期：2026-09-13。单人源码审计；不是独立评审、业务库盘点或归档实施验收。

## 1. 本次结论与范围

旧 M1-105 的“保留/归档”仍需完成，不能把投递完成、备份成功或记录过期直接解释为
允许删除。现有账本同时承担去重、恢复、外部副作用对账和迁移回滚；只检查数据库外键
无法覆盖这些引用。当前源码未提供完整的保留窗、归档读取或受控回收流程。

本包完成**当前源码引用审计和后续实施前置的拆解**，不宣称完成 GC、业务归档或正式
保留策略。不改保留天数，不新增删除命令，不改既有迁移/触发器/权限；现有记录保持原状。
旧计划没有给定保留天数，不能把 B4 的 24 小时调查分类或开发产物 GC 规则当业务 TTL。

授权沿用[处置清单](v5-backlog-disposition-luna.md)：可独立补齐的旧账先做，需统一开发
的明确转交。本包只改本报告、处置清单和[覆盖矩阵](v5-backlog-coverage-luna.md)。
不修改新 dev-plan，不擅自把本子项标为“已迁入”；不扩大已经明确延期的监控子项范围。

| 规则 | 本包处置 |
| --- | --- |
| D1～D5、C1/C2 | 区分权威账、快照、派生存储；不跨 App 查库；把逻辑去重和未知外部结果纳入引用 |
| D6～D8 | 不改迁移；旧归档的退役必须另走线性迁移、实际备份恢复及回滚门禁 |
| I3、D9 | 不读 Secret 值，不导出业务载荷，不把运维报告或数据库能力交给浏览器 |
| R1/R6、T4/T5 | 仅文档，无公共代码变更；不重跑并冒认后端门禁，不更新父仓 gitlink/master，不推送/同步/部署 |

审计固定源码；路径以所属后端为根。不是当前集群镜像或业务数据库的事实证明。

| 仓库 | HEAD（审计前后不变） |
| --- | --- |
| tpl-app/tpl-backend | `a91eb3e284ae91d4bc6b82fe567c4163cfa728f0` |
| info-app/info-backend | `7dafb34ca70d1f71ebc332315bf0c7584b9c3092` |
| knowledge-app/knowledge-backend | `5df4f1759cd64bd0a3ca2c4cae8f68102ebe681d` |
| investment-app/investment-backend | `3d9531d1250d035aa13eb197198b6c5672450856` |

k8s 开工 HEAD：`38f67f9ba3327fb8060304b3d2ad39d7fa8dc928`。两个预置协议草案不动。

## 2. 公共投递账本的实际依赖

源码载体：`app/app/infrastructure/models/outbox.py`、
`app/app/infrastructure/repositories/outbox.py`、
`app/app/infrastructure/messaging/delivery_schema.py`、
`app/app/infrastructure/messaging/durable_delivery.py`、
`app/app/application/services/durable_tasks.py`。

| 对象 / 引用种类 | 当前用途 | 单独删除的风险 |
| --- | --- | --- |
| Outbox 的唯一 deduplication_key；无独立去重墓碑 | enqueue 比较 topic、aggregate_key、payload、headers；相同意图返回原 UUID，不同意图拒绝 | 原行消失后同业务键可获新 UUID；旧 Inbox 不一定能挡住新消息身份，也丢失冲突意图核验 |
| Inbox 的 `(consumer, message_id)`；**无 Outbox 外键** | claim_execution 和 reconcile 都检查精确消费回执，handler 完成时同事务提交 | Outbox 尚在时删回执，可能使已执行命令再次有资格消费/对账重排；领域幂等只能保护各自已实现的部分 |
| outbox_dead_letter.message_id → Outbox；默认 NO ACTION | 未重放死信阻断消费/发布；重放保留 Inbox | 删父行受引用阻挡；先删死信会丢失阻断与调查证据；replayed_at 非空也不是可删判据 |
| outbox_execution.message_id → Outbox；默认 NO ACTION | resource_key 为 topic + aggregate_key，换 owner 时 epoch 加一；释放只置过期时间为负无穷 | 已释放行仍有外键引用，且是 epoch 墓碑；删除再创建会把代次重置，不能只按租约过期清理 |
| aggregate_key / payload / headers；字符串或 JSON | 映射领域对象、任务代次、调度时间和相关上下文 | 外键扫描看不到；消息过期不能证明领域引用结束，篡改载荷也会破坏去重比较 |

模板 `delivery_handlers.py` 返回空注册表，实例提供自己的 handler；不能据模板没有领域
引用就向实例广播通用 DELETE。共享 consumer 通常等于 topic；Investment 的执行回执是
`agent.executor`，通知策略则是无 Inbox 的 hint。必须按注册策略判断，不能统一要求
`consumer=topic`，也不能将 `published` 一律当成业务完成。

`cli/durable_delivery.py` 当前只有 dead-letters/reconcile/replay；replay 没有按年龄拒绝的
产品窗口，也不会删除 Inbox。只有限重试不等于有界历史重放。broker 消息寿命也不等于
API 幂等重试寿命，不能据任一单独 TTL 推导安全删除时间。

handler 允许受租约保护的**中间提交**：最终 Inbox 尚无，不代表领域或外部系统没有
副作用。反之，Inbox 已有只证明对应 handler 提交，不证明对象可删除或业务结果成功。

## 3. 三个实例的额外引用

### 3.1 Info：领域链和旧 Outbox

源码：`app/app/application/services/delivery_outbox.py`、
`app/app/application/services/info_crawl_service.py`、
`app/app/infrastructure/messaging/delivery_handlers.py`、
`app/app/infrastructure/models/info.py`；迁移
`app/alembic/versions/20260911_0007_durable_delivery.py`。

| 消息 / 对象 | 必须继续追踪的依赖 |
| --- | --- |
| info.crawl.v1 | payload.job_id → CrawlJob；去重键含 delivery_generation；原文、文档版本及抓取诊断材料不能只按任务终态清理 |
| info.index.v1 | payload.document_version_id → InfoDocumentVersion；初次索引和显式 reindex 的键不同；搜索可重建不等于源版本可删 |
| info.distribution.dispatch.v1 | payload.distribution_id → DistributionRecord；去重键含 retry_history 派生代次；分发快照还承载下游稳定身份/Artifact 引用 |
| delivery_outbox_message_legacy | 旧消息 ID 与公共 Outbox 的对应关系是迁移复制，不是二者之间的 FK；aggregate_id 仍 FK 引用 distribution_record.id，后者再引用文档版本 |

0007 downgrade 根据当前 Inbox 回写旧表完成状态，再改回旧表名。该历史表不是通用
冷归档存储：它不自动收录所有后续公共消息。源码未见 Investment 那种语句级只读触发器，
**不能把“legacy 命名/新代码不再写”说成数据库已强制只读**；业务角色权限尚待运行核验。
本包不借审计改写既有迁移或补默认授权。

B4 `docs/v5-backlog-artifacts-luna.md` 明确只查 RawArtifact / ExtractedContent 的本域
引用，不穷尽历史分发快照、Knowledge 摄入引用或其他产品证据。`unregistered_candidate`
只是调查分类。跨域引用须走各领域拥有的版本化契约，不增加跨库 SQL 或共享目录协议。

### 3.2 Knowledge：摄入、轮询和 Provider 操作记录

源码：`app/app/infrastructure/models/knowledge.py`、
`app/app/application/services/knowledge_ingestion_service.py`、
`app/app/application/services/ragflow_delivery.py`、
`app/app/application/services/ingestion_execution.py`；迁移
`app/alembic/versions/20260911_0006_durable_delivery.py`。

`knowledge.ingest.v1` 的 payload 含 ingestion_id/generation/step，aggregate_key 是由
来源 App、来源版本、Dataset 得出的 upload_identity。同一上传身份可能被不同 job/代次
继续使用，不能以一条轮询消息的 Inbox 或一个 job 的完成时间回收全部上传记录。

KnowledgeDocumentVersion.ingestion_id 以 RESTRICT 外键保留摄入任务；来源版本、
source_artifact_refs、payload、metadata_json 的执行快照、Provider document/dataset ID
还有逻辑/跨域引用。`knowledge_provider_operation` 没有指向 job 的 FK，但 key 包括
`dataset:<name>`、`upload:<identity>` 和 `parse:<identity>:<job>:<generation>`，记录
意图、身份作用域、执行不确定性及回执。

operation 创建/校验意图；start **先提交 executing 再发网络写**；confirm 持久化回执；
执行中断可进入 unknown。`legacy_unknown` 明确阻止旧上传结果未调查时再次上传；parse
还查询同上传身份下先前 executing/unknown 记录。删除这些行可能把“结果未知”变回
“从未执行”，破坏原防重纪律。即使 confirmed，也未证明不再有后续重试/派生对象引用。

0006 downgrade 在 Provider 操作表非空时拒绝丢回执，要求已验证备份恢复；不能为了
让 downgrade 成功，先清空该表。RAGFlow 可重建是派生系统原则，不代表当前远端副作用
回执可以随时抛弃。

### 3.3 Investment：恢复幂等、执行代次和回滚快照

源码：`app/app/application/agent/run_service.py`、
`app/app/infrastructure/agent/repositories.py`、
`app/app/infrastructure/agent/pilot_repository.py`、
`app/app/infrastructure/agent/delivery.py`、
`app/app/infrastructure/agent/transactions.py`、
`app/app/application/agent/side_effect_service.py`；迁移
`app/alembic/versions/20260910_0006_agent_reliability.py` 和
`app/alembic/versions/20260911_0007_durable_delivery.py`。

| 引用 | 实际用途与保护边界 |
| --- | --- |
| Outbox aggregate_key/payload → agent_runs | 执行时校验 run、session、graph 和命令种类；不是 FK 保护的通用消息包 |
| resume 去重键 → 原 Outbox.payload | RunService 和 Pilot 重复恢复读取原命令核对输入/上下文；单独归档删除会改变相同请求的返回语义，即使 Inbox 仍在 |
| agent_execution_leases.command_id → Outbox | 外键默认 NO ACTION；session 级 epoch 释放后保留，副作用记录依赖其代次；session FK 的 CASCADE 不是安全删除授权 |
| tool_side_effects → run / tool_call_id / execution_epoch | completed 的回执供复用；executing/unknown 先 lookup，缺回执不允许盲重做；不能随 run 级联删除而忽略远端结算 |
| session_events、execution_state 及图 checkpoint | 涉及历史展示、游标回放和恢复；未来统一 Task/Attempt 的引用门禁不能只从旧表级联关系推导 |
| agent_delivery_failures_legacy_0006.message_id → Outbox | 保留旧 CASCADE FK，但 0007 新增语句级拒写/拒删/拒 TRUNCATE 触发器；是回滚快照，不是可随父行回收的垃圾 |

现有 GraphExecutor 以 binding.execution_id 分隔执行线程，并从持久接受的 state 发起
恢复；不能照旧 session_id 约定批量删 checkpoint。相关载体为
`app/app/infrastructure/graph/executor.py` 和 `checkpointer.py`；本包没有枚举实际
checkpoint 库表/活跃实例，不能宣称完整 checkpoint 引用闭包已验证。

[B7j](v5-backlog-worker-progress-luna.md) 已实测并新增
`app/tests/test_agent_delivery_observation.py` 中
`test_current_archive_guard_prevents_implicit_outbox_cleanup`：即使旧归档零行、无 Agent
lease，删除 Outbox 仍会因 FK 生成的 DELETE 语句触发只读保护而失败。该测试是原保护的
证据，不是本轮新跑的结果，也不是业务清理缺陷的修复。退役必须同时交代回滚窗、归档
恢复和线性迁移，不能禁用触发器、删 FK 或改 session_replication_role 绕过保护。

## 4. 后续方案与实施门禁（候选，尚未实现）

建议拆为三层：① 现有数据保留及只读盘点；② 可校验导出/隔离恢复；③ 批准窗口后的
压缩/删除。先做归档副本不必同时删除在线记录；但没有容量和隐私约束的永久保留也不是
最终产品策略。下面是实施前置，不是已批准的保留政策或自动放行规则。

1. **冻结政策和对象。**分 App/topic/对象类别给出幂等重试、消息/死信重放、用户恢复、
   事件回放、外部回执及发布回滚窗口，明确何时起算、谁可延长、何时拒绝过期请求、
   调查/争议保护及隐私要求。窗口没有上界的分支，不得仅按创建时间清理。
2. **盘点已部署版本。**核源码、imageID、revision、表/约束/触发器、角色、行数/体积、
   活跃执行与停用旧消费者；按每 App 只读权限取证。源码中的未见不证明业务库不存在，
   查不到/权限不足/未知 topic/旧无版本引用均保持保护，不输出“无引用”。
3. **保证运行读路径。**若冷迁移后还要接受原键请求，先实现唯一权威的归档定位与读取，
   或保留可验证意图和结果的在线去重记录；不能删行后仅指望人手工解压。压缩 payload
   会影响严格意图比较及审批上下文，需版本化契约和正反例；本包不选定第二本主档。
4. **关闭并发引用窗口。**审批绑定候选精确身份/版本、策略版本与报告摘要；执行前重新
   核引用和活跃 owner/epoch。一次 SELECT 快照不能阻止之后新增引用；需与生产者/恢复
   路径互斥或可验证的保留/退役协议，失效则重新调查审批。跨域部分用契约，不跨库锁表。
5. **导出并实际恢复。**逐 App 记录 schema/revision、源发布、精确对象、计数/校验和及
   关联的存储版本；加密、最小权限、可重取。隔离环境验证读取/恢复/重放/去重/回滚，
   不能仅检查压缩包能解开或文件 checksum 正确。
6. **单独处置旧归档。**Info 与 Investment 的旧表并非同一机制；逐一记录保留/退役及
   downgrade 行为。旧回滚窗未结束不自动 contract。新迁移需模板公共部分先验，再
   串行实例覆盖各自领域；不能修改已经发布的历史迁移充当升级。
7. **最后才受控删除。**精确批次、有限锁等待、dry-run/人工复核、完整审计与中止条件；
   业务库、S3、Provider 的授权分别取得。失败保留原账及保护，不以先删 dead-letter/
   Inbox/epoch/legacy 的顺序“解决”引用冲突。

恢复尤其不能把“全库倒回备份”当外部系统的时光倒流：备份后的远端写仍可能存在。
启用恢复环境的任何发送/执行前，须隔离旧执行者并对账回执/不确定操作，避免旧快照
再次调用外部副作用。纯本机和云端都需要这套语义；存储、身份、执行隔离由适配层实现，
不要求未来 Electron 安装 Kubernetes，也不赋予浏览器数据库清理权限。

## 5. 验收清单、欠账去向与本包验证

| 后续验收 | 必须观察的结果 |
| --- | --- |
| 相同/冲突意图在归档边界重试 | 相同请求按批准契约返回原结果/明确过期；冲突输入或权限上下文被拒，不生成新副作用 |
| 丢回执、迟到消息、旧死信重放 | 保留窗内可恢复；窗外行为明确；删档不让已经完成的业务再次自动执行 |
| 执行/恢复/新引用与候选清理并发 | 新引用、租约或审批过期阻止删除；旧 epoch/owner 不重新生效 |
| unknown/legacy_unknown/confirmed Provider 记录 | 未结算保护不丢；跨 job 的上传身份、parse 代次和恢复回执仍一致 |
| legacy FK/只读触发器及迁移往返 | 原防护不被绕过；实际归档恢复与新旧发布组合可验证，非只有空库 DDL |
| 归档丢失、损坏、无权、超时、中途失败 | 拒绝删除，保留原权威与可继续调查的证据；不把失败当空集合 |
| Artifact / Citation / checkpoint / SSE 历史 | 精确版本可读；仍承诺的恢复和历史不悬空；未知引用失败关闭 |
| 备份后的远端写及旧消费者重现 | 恢复流程先隔离/对账，不重做已发生动作；旧写路径被拒 |

处置分工：B7 保留当前投递归档、旧表回滚、实际盘点/备份恢复及发布门禁的欠账；B4 的
全引用自动回收、N1/N2 的产品恢复窗口、N3 的来源失效和 N4 的统一生命周期须联合设计，
待 B8 正式接收。不能以本报告关闭 M1-105，也不因联合设计把 B7 其它运维项整体延期。

本轮固定源码逐路径读取完成；`doc-gate.py --staged` 三份文档通过，
`git diff --cached --check` 通过。没有新执行后端测试、查询业务数据库、
建立测试容器、导出/删除记录、改 Secret、构建/推送镜像或部署。历史测试仅按固定报告
引用，不累计为本轮测试数。未定义新的保留天数，未把候选方案当成用户已批准政策。
下一步仍可推进 B7 当前角色/身份/发布与数据切换的只读预检；实际迁移、归档删除和
部署须先给出精确对象、批准范围和回滚条件，不能以“继续”扩大为任意业务数据操作。
