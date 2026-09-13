# B6a：公共持久定时投递源码验证

2026-09-13，单人 Luna 实施/自测，无独立多家评审；当前定位是源码候选，不是部署验收。
任务归属及后续游标见[逐步处置清单](v5-backlog-disposition-luna.md)。

## 1. 本包解决什么

历史 M1-203 要求解析轮询每次查询后释放 Worker。既有公共 Outbox 已有可变 available_at，
但入队接口不能声明延迟，消费者也没核原始到期时间。本包补共享底座，不直接改解析流程。

`enqueue_task(..., not_before=...)` 接收带时区的绝对时间，规范为 UTC，作为版本化保留
header `sunmoonai.not_before.v1` 写入既有 Outbox，参与幂等意图比较。相同幂等键修改
定时拒绝，不让重试逐次延长；新字段计入原有传输大小限制，原始 headers 不得伪造它。
领域计算时间应使用 PostgreSQL 时钟，并将需恢复的时间持久化，而非重放时重算。

available_at 仍为可变调度投影，发布同时检查两者。消费者检查原始最早时间，不使用
发布完成时会变化的 available_at；否则一次正常发布也会误挡消费者。未到期的直接
broker 提示不占执行租约，不写 Inbox，也不扣发布重试次数。对账及死信重放不会提前执行。
到期仅意味着具备执行资格，实际延迟受 pump 周期、队列和容量影响，不承诺精确定时。

handler 不自行中途提交时，领域进度、下一条消息、当前 Inbox 同事务；租约失效、取消、
事务异常及最终提交失败都一起回滚。这是下一包应遵守的调用纪律，不是替现有领域用例
自动去掉所有中间 commit。需要串行化的后续消息须沿用同一 topic/aggregate_key。

没有新增表、迁移、并行队列或 Celery countdown；没有改跨 App 领域 schema。
原消息无保留项继续立即执行。详细接口及启用规则随四后端的
`docs/durable-scheduling.md` 同步。

## 2. 模板对齐报告

按模板→Info→Knowledge→Investment 串行落地，各实例通过后才推进下一实例。
对齐范围是此次新增公共能力，不冒充全项目所有历史差异已清零。

| 实例 | 公共同步 | 领域扩展 | 配置 | 暂时兼容 | 本包违规漂移 |
| --- | --- | --- | --- | --- | --- |
| Info | 7 文件与模板逐字一致 | 无新增；抓取/分发/Artifact 不改 | 无改动 | 无时间字段的旧消息保持原语义 | 无 |
| Knowledge | 7 文件与模板逐字一致 | 无新增；仍保留原解析流程 | 无改动 | 同左，B5 授权/回执不变 | 无 |
| Investment | 7 文件与模板逐字一致 | AgentDelivery 的 session 租约认领引入同一到期谓词，另加 2 项真实 DB 测试 | 无改动 | 旧 start/resume 不变 | 无 |

7 文件：`app/app/application/dto/outbox.py`、`application/services/durable_tasks.py`、
`infrastructure/messaging/delivery_schedule.py`、`infrastructure/messaging/durable_delivery.py`、
`infrastructure/repositories/outbox.py`（后四项同属 app/app）、
`app/tests/test_delivery_schedule.py`、`docs/durable-scheduling.md`。
Investment 额外为 `app/app/infrastructure/agent/delivery.py` 与
`app/tests/test_agent_delivery_schedule.py`。没有覆盖领域目录、改前端、改认证或 release manifest。

## 3. 固定提交与测试

| 后端仓 | 固定提交 | tree | 固定提交回归 |
| --- | --- | --- | --- |
| tpl-backend | 30a106689739601916c322b0159fce5829c99a69 | 9499208b73ba3ee77769533b6726c0bab6db2b0e | 80 passed / 0 skipped，4.72 秒 |
| info-backend | 6a2be5768c524a985ddcde3bec5ae28e01ff0606 | cfcd008610eef7023997eb491dc9a5bbded6eb7f | 293 passed / 0 skipped，19.90 秒 |
| knowledge-backend | 1e26b74fc5993cd425ecccd68010e35579700af5 | 695c46e9130ce23d6d4e969ba46d9bcc7f2b8f0a | 188 passed / 0 skipped，12.44 秒 |
| investment-backend | 8228a0fc83caab62159745cd0b95a9c37e0b74e7 | e21e3ea9f6c8d443caad6f378a441af937691036 | 215 passed / 0 skipped，13.85 秒 |

四仓 Ruff/Pyright 全通过。每仓新增 15 项共享测试，Investment 额外 2 项领域入口测试。
测试使用同一个可丢弃 PostgreSQL 容器，每条用例独立随机 schema，执行各自真实迁移链；
Info 的既有 Artifact 回归使用可丢弃 S3，Investment 的 Lua/锁测试使用可丢弃 Redis。
四仓都带入模板的 web-interaction consumer vectors；领域契约本次不变，既有双端回归仍跑。

专项覆盖：

- 未来消息两条发布入口、直接消费者均拒绝，到期消息可处理，成功发布不误拦消费。
- 时区规范化、旧即时语义、保留 header 伪造、可变 dict 绕过、大小/数量限额。
- 同一时间不同表示幂等，不同时间/增删时间字段拒绝；重投不重写 available_at。
- 传输退避、对账、死信重放保持原始时间，不能提前执行。
- 后续消息在提交前对其他连接不可见；handler/commit 故障、租约失效及任务取消
  不遗留孤立进度、后续消息或 Inbox；恢复后只提交一次。
- Investment 专用 session 租约入口同样阻止未到期消息，包括死信重放后；到期可认领。

初轮 Investment 191 passed / 22 skipped 不是最终证据；补齐 Agent DB/Redis 环境后得到
上表零跳过结果。下载 Redis 7 镜像超时，改用已有 Bitnami Redis 8.2.1，未借用业务实例。
没有验证真实业务 RAGFlow、真实 broker、跨机运行时钟、部署容量或网络/身份隔离。

## 4. 启用与回滚边界

新定时意图不能在旧消费者仍运行时启用。先排空并统一升级 API/Worker/Scheduler 的相容
版本，再启用定时生产者；业务库需只读核查保留 header 是否存在历史冲突/异常，不能
把源码 rg 无冲突当成业务数据证明。数据库直写者必须遵守协议，非法日期可能阻断 claim。

回滚旧版本前停止新生产者，排空/对账全部仍被引用的定时消息，再走已授权发布流程；
不能删除 Outbox 或清库来“完成回滚”。本包没有构建镜像、改 Secret、执行业务迁移或部署。
每个实例的 KIND、身份、运行态回滚及容量验证仍属 B7/发布门禁，不能由本轮数据库测试替代。

## 5. 下一包 B6b（尚未实现）

Knowledge 将提交解析与轮询拆为有界执行；每条 poll 只做一次远端状态查询，再同事务
持久安排后继。需先冻结：解析代次及消息过期判据、跨进程可恢复 deadline、退避上限、
结果未知阻断、授权复核和最终领域提交。轮询不得重复读取源文件或盲目再次上传；
旧消息重放不得重置新代次或新 deadline。沿用公共 Outbox 与 Provider 操作账，避免第二真源。
这些仍须实现和故障测试，不能因为 B6a 通过就标 M1-203 或 B6 已完成。
