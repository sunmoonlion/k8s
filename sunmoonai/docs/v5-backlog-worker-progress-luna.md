# B7j：已提交回执进展与真实 Worker 故障验证

2026-09-13；Luna 单人实施、自测，无独立评审声明。
状态：四仓最终固定提交完整回归通过，未集成 master、推送或部署。
范围/授权沿用[处置清单](v5-backlog-disposition-luna.md)；本地开发、最终统一同步。
起点后端 ed157e4/0a6675d/937f09f/6a5bff9，k8s f43d02c4。
本包不安装监控、不推镜像、不改业务部署/数据库/身份或自动重启策略。

## 1. 复用什么，补什么

已有 Worker readiness 只查本节点队列/任务注册，Scheduler 活动只说明循环返回；
它们都不是实际处理回执。B7d/B7h 已有投递只读 collector、CLI 和签名服务身份 HTTP。
本包在同一个 collector 内按原有 policy/topic/consumer 聚合已有 Inbox，增加两项 gauge：

| 字段 | 语义与边界 |
| --- | --- |
| retained_receipt_messages | 当前保留 Outbox 中，与必需 consumer/message_id 精确匹配的已提交 Inbox 数；错 consumer、孤立回执、其他 topic 不混入 |
| latest_receipt_recorded_timestamp_seconds | 上述 processed_at 最大 Unix 秒，无回执为 0；与数量一起解释，不代表精确提交时间、单调进度或某个 Worker 的心跳 |

LEFT JOIN 利用现有 Inbox 复合主键，保留原 done 判据及领域租约扩展；无回执 hint
仍按发布成功判断原传输完成，但两个新字段为零。不修改 Inbox 写入/幂等/业务语义，
也不增加迁移、影子表、动态标签或额外采集身份。JSON v1 加法字段，text 保持 gauge。

只有事务提交后另一会话才看到回执；回滚/未提交不算、重复不增。processed_at 默认
NOW 是写事务开始时间，不是 commit timestamp；乱序/墙钟回退会使数量增而最大时间
不增，归档/恢复/删除 Outbox 可使两值下降。不应用 counter rate/increase 语义。
有限未来值如实显示；任一匹配回执时间为正/负无穷则整个采集失败，不生成假正常值。
HTTP 503 / no-store / 取消传播 / 完整渲染后响应 / 服务鉴权不变，不输出部分指标或 SQL。

不新增“healthy”或“stalled”结论：空闲、正常长任务、失败、回执保留变化必须结合判断；
聚合不能证明每个 Worker 正常，也不证明领域业务结果或产品 Task 成功。
领域 handler 若将终止失败落账后正常返回，也可能有已处理回执；不能将它改称成功量。
旧数据迁移补入或恢复的 Inbox 也会进入聚合，不代表此刻 Worker 又执行了一次；
不能绕过发布/恢复记录，单靠一次最大时间或数量变化宣布运行态健康。

## 2. 实施路径和验收

每后端六个公共文件：修改 `app/app/infrastructure/messaging/delivery_observation.py`、
`docs/delivery-observation.md`；新增 `app/tests/test_delivery_progress.py`、
`app/tests/test_delivery_progress_http.py`、`app/tests/test_delivery_progress_worker.py`、
`app/tests/worker_progress_fixture.py`。实例的原 observer 装配、领域 handler 和任务清单
不修改；测试专用装配不进入生产入口，不把合成 handler 加入模板业务注册。
Investment 另在既有 test_agent_delivery_observation.py 增加七条新字段断言，
覆盖原真实 agent.executor consumer、错 consumer 不计数、notification 无回执分支；
这属于领域测试扩展，不将它复制到模板，不修改 AgentDelivery 生产代码。
后续首轮失败再补一个隔离 PG 回归：确认原 CASCADE 外键存在、旧归档为空且无 Agent
执行租约，删除 Outbox 仍由只读归档触发器拒绝，事务回滚后原数据保留。

新增 12 项参数化测试：10 项真实 PG 回执语义，1 项真实 prefork Worker，1 项签名 HTTP。
覆盖未提交/回滚、handler 在途、精确 consumer/孤立回执/hint、重复、保留后下降、乱序
时间、四种正/负无穷混合情况、Prometheus 输出；HTTP 实际签名成功与非有限值 503/
无指标泄漏及恢复；沿用既有 HTTP 未授权零数据库访问、只读/超时/取消/并发回归。

真实 Worker 使用本仓生产 bootstrap/注册 execute/DurableTasks/Inbox，仅在 tests 入口
替换隔离数据库适配与合成 handler。随机 loopback broker 队列 + 随机迁移后 PG schema；
核 OS 父子 PID 后暂停唯一 prefork 子进程；父进程 reserved 列表有任务、pong 仍正常，
但回执和业务计数为零。恢复后真实 execute 提交才增加；再次发同 ID 不增；失败 handler
的更新回滚且没有 Inbox，后续成功任务推进，证明不是仅凭 Celery 返回值/日志判完成。
同队列、单子进程的后继已提交任务作为前序重复/失败任务完成屏障，不通过随意 sleep 判定。
停进程后清理确切随机队列/交换机；超时仅回收本测试新建进程组，不信任外来 PID。

这证明共享执行链路与隔离故障行为，不证明现有业务镜像、真实 Provider、当前部署
Worker 身份/负载、全角色优雅退出或运行重启策略；测试库也不替代业务数据验收。

## 3. 新失败的根因与修正

1. 初次新 PG 专项 **5 passed / 1 failed，1.17 秒**：测试将字符串 infinity 直接绑定为
   asyncpg timestamptz 参数，驱动要求 datetime，在查询执行前拒绝。改测试为 text
   参数再由 PG cast，不改变生产语义；原非有限值拒绝断言保留。
2. 随后 **8 passed / 1 failed，15.29 秒**：暂停子进程后等待 active 是错误预期。
   核已安装 Celery strategy 的 task_reserved、Request.on_accepted 与 Billiard 子进程
   pool ACK：只有子进程开始接受任务回报后才 active。改为精确 reserved task ID
   证明父进程已收消息；暂停状态/pong/无回执/恢复/去重/回滚断言不变，超时未延长。
   随后新增场景 **10 passed，9.13 秒**。
3. 人工复核补混合正常值的正/负无穷反例。只检查 MAX 会吞掉较小的负无穷，确定性
   得到 **3 passed / 1 failed，0.68 秒**（未抛异常）。SQL 增加所有匹配回执的
   isfinite 聚合检查，内部坏值标志不输出；保留整个采集失败的标准。
   最终专项 **12 passed / 0 skipped，9.24 秒**，Ruff/Pyright 通过。
4. Investment 首轮固定全量 **167 passed / 1 failed，18.12 秒**：新 gauge 下降用例
   DELETE Outbox 触发旧 agent_delivery_failures 的 ON DELETE CASCADE；0007 将它
   改名归档并加 FOR EACH STATEMENT 只读触发器，因此即使归档为空也拒绝级联语句。
   这是新测试误假定全实例允许直接清理 Outbox，不是观察器写库或消费失败。
   保留迁移/只读保护不动，公共用例只在隔离 schema 移除合成 Inbox 回执验证 gauge
   可下降，不再暗示已实现/批准归档流程。模板新固定提交先重跑，再串行实例；
   Investment 另补“旧归档为空也阻止隐式 Outbox 清理，数据保留”的保护回归。
   保留/归档包必须解决引用闭包和该保护的协调，不能把新观测测试当作 GC 验收。

初次 Ruff 检出行长、导入顺序及 async 中阻塞进程启动/文件读取，已格式化并将对应
阻塞调用移到 asyncio.to_thread；未豁免 lint 或类型检查。上述失败均有根因及修正，
不以反复重跑或调整生产预算直到变绿作结论。

## 4. 固定提交全量门禁

首轮固定候选（Investment 失败后停止，公共测试随后从模板重新修正）：

| 后端 | 本地提交 | 完整静态/pytest |
| --- | --- | --- |
| tpl-backend | `a37835132217d8458a7440532f07d437a4684e3b` | Ruff/Pyright 通过；255 passed / 0 skipped，52.54 秒 |
| info-backend | `8baeefc432ca653bb670cf1fca9cbe4256c376a9` | Ruff/Pyright 通过；500 passed / 0 skipped，83.74 秒 |
| knowledge-backend | `1597b453fb11901277fb93c8316e796228572d41` | Ruff/Pyright 通过；415 passed / 0 skipped，72.03 秒 |
| investment-backend | `c90f522c620e9bedb09728e609b773aafad91c28` | Ruff/Pyright 通过；167 passed / 1 failed，18.12 秒；见上节 |

最终固定提交复验（不以首轮前三仓通过代替修订后的串行门禁）：

| 后端 | 最终本地提交 | 完整静态/pytest |
| --- | --- | --- |
| tpl-backend | `a91eb3e284ae91d4bc6b82fe567c4163cfa728f0` | Ruff/Pyright 通过；255 passed / 0 skipped，51.97 秒 |
| info-backend | `7dafb34ca70d1f71ebc332315bf0c7584b9c3092` | Ruff/Pyright 通过；500 passed / 0 skipped，83.31 秒 |
| knowledge-backend | `5df4f1759cd64bd0a3ca2c4cae8f68102ebe681d` | Ruff/Pyright 通过；415 passed / 0 skipped，72.09 秒 |
| investment-backend | `3d9531d1250d035aa13eb197198b6c5672450856` | Ruff/Pyright 通过；399 passed / 0 skipped，79.13 秒 |

最终合计 **1,569 passed / 0 skipped**；每仓公共用例重复计入，不是 1,569 种不同场景。
相对 B7i 每仓增加 12 项，Investment 另 1 项归档保护；四仓最终均在上述固定提交
运行 Ruff/Pyright 和完整 pytest，且严格串行。首轮失败未被删去或写成通过。

六个公共文件在四后端最终提交中 SHA-256 一致；Investment 领域测试另行保留，不覆盖。

| 后端根相对路径 | SHA-256 |
| --- | --- |
| `app/app/infrastructure/messaging/delivery_observation.py` | `3a7082729fdd35eb733dc64c15d7d2b93d006ba99d500ff95d36098482b5c502` |
| `docs/delivery-observation.md` | `bdc6408b7f0848344f5ad2a34911b9964aca62c42109b0b06fdfa04d93b9450b` |
| `app/tests/test_delivery_progress.py` | `c8245bc24f124d49ad0ae021e8e2bbf3284ea400507381c284735bfcb5f6150b` |
| `app/tests/test_delivery_progress_http.py` | `2ac23e625df304f2147ad76b671e8ac8f37aa1b1278aece9e99ddeec0cbec521` |
| `app/tests/test_delivery_progress_worker.py` | `e9790bbb060daefe619984b8ca1eba290c43f41d6277cf4ef9d6ab5a3a5bfa2f` |
| `app/tests/worker_progress_fixture.py` | `2b6536974e18a78c3c2a6af36fd665cfc15d85ce94c51cfe9d0c519534e598b1` |

模板部署脚手架另 8 tests OK（0.203 秒）；这是渲染/配置测试，不是实际部署门禁。

## 5. 副作用、回滚与剩余工作

四个临时容器 luna-b7j-pg/rabbit/minio/redis，标签 luna.task=B7j，均仅回环开放端口；
内存上限合计 1152 MiB、各 CPU 上限 1，原缓存镜像不改、无业务卷，合成凭据不入 Git。
最终四仓测试退出 0 后，核完整容器 ID、B7j 标签和挂载，stop / rm -v 精确清理：
PG `7ee943281142…`、RabbitMQ `de0ac9d569d5…`、MinIO `35dbdc32d286…`、
Redis `bd6016ab78a6…`；四个新匿名卷 `de3056c1424f…`、`ca49525a9e5c…`、
`a4f4c2541442…`、`da28536ca498…` 均核对无残留。只删除可重建合成测试数据；
容器清单仍仅原三个 KIND 节点和原三个月前退出容器，镜像/业务卷/业务资源未动。
回滚撤销本包聚合字段/测试/说明，无数据库降级。
本包只在 Luna 留本地提交，父仓 gitlink 不暂存，不更新 master、不推送或云端同步。
四后端最终干净；三个父仓增量对齐报告未暂存，gitlink 仍 B7e 起点；五个本地 master
仍原 HEAD 且干净。两份预置 general/pro 协议草案未修改、未暂存。

监控实际部署/采集/新鲜度/告警送达继续由[未来 N4-OPS-01](tasks/N4-OPS-01/thread/01/user-message.md)
接收，未实施；保留归档、真实运行/发布/数据切换门禁仍由 B7 逐项核验，B8/B9 未完成。
