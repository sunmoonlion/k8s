# B7i：Scheduler 本机活动观测

日期：2026-09-13。Luna 单人实施、自测，不宣称独立验收。
状态：四仓本地固定提交全量通过，未集成 master、推送或同步，未部署。
沿用[处置清单](v5-backlog-disposition-luna.md)的冻结范围与最终统一同步要求。
本包只有源码和隔离测试，不安装监控、不发布镜像、不修改业务部署或数据库。

## 1. 范围与语义

四后端起点：tpl `cd89d1f`、Info `a9f0d7b`、Knowledge `ffc88f9`、Investment
`681256f`；k8s `726cc4a3`。公共改动先在模板过完整门禁，再串行三个实例。

每后端恰好六文件：新增 `app/app/infrastructure/messaging/scheduler_activity.py`、
`app/app/cli/scheduler_activity.py`、`app/tests/test_scheduler_activity.py`、
`app/tests/test_scheduler_activity_broker.py`、`docs/scheduler-activity.md`；
`app/app/bootstrap/scheduler.py` 仅增加 ObservedScheduler 选择。
不改四角色拓扑、领域 handler、Beat 清单、依赖、迁移、API、前端或发布清单。

| 边界 | 实现与判据 |
| --- | --- |
| 调度算法 | 继承 Celery PersistentScheduler，父类 tick/apply_async 的参数、返回及异常传播保留；不替换 reserve、调度或持久化格式 |
| 循环活动 | 仅父类 tick 正常返回后累计，不用独立心跳线程掩盖主循环阻塞；最多每秒尝试写快照 |
| 发送结果 | 分列 apply_async 正常返回与异常次数；不是 broker confirm，更不是 Worker 消费或业务完成回执 |
| 临时文件 | 同目录原子替换，0600；不做持久业务账，不承诺 fsync。写失败不阻止原调度，固定日志且限频 |
| 新鲜度 | Linux BOOTTIME 含 suspend，不使用墙钟/mtime；校验 boot ID、PID 启动 ticks 和进程状态，拒绝暂停/退出/旧启动或 PID 复用 |
| 读取边界 | 同可信 UID/PID namespace；最多 4096 字节，拒绝 symlink/FIFO/非普通文件、异 UID、坏类型/非有限时间，只输出已定义字段 |
| CLI | 显式同一 schedule 路径及有限正数 max-age（最多 3600 秒）；读取失败固定错误/exit 1；不访问 broker/DB、凭据或发送任务 |
| 不自动推断 | 新鲜循环可以伴随发布失败或空转；同 UID 恶意伪造不在保障范围；不是选主锁或自动重启依据 |

Linux 专用的是运行角色适配器，不是未来本机 Agent 内核限制。非 Linux 缺少 procfs/
BOOTTIME 时此观测失败关闭，但不阻止 Celery 原调度。不把本地路径开放为浏览器 API。
文档示例 max-age 30 秒不是统一 SLO；需结合实际最大调度间隔、重试/等待单独冻结。
此包不接 Kubernetes startup/readiness/liveness，不把 broker 故障变成重启风暴。

## 2. 测试与失败根因

新增 42 项参数化单测：真实父类持久化/发送异常语义，坏文件/计数/时间、年龄过期、
未来时间、旧 boot/PID、暂停/僵尸等进程状态；墙钟/mtime 无关；原子 replace 失败保留
旧文件及临时文件回收；tick 异常不刷新；观测写失败/不支持时钟的限频与脱敏；CLI 输出。

另 1 项真实 Beat/RabbitMQ 场景：随机合成队列，真实 Beat 子进程首次发送；独立从队列
取出消息确认到达 broker；SIGSTOP 拒绝、SIGCONT 后 tick 推进；退出后故意留旧文件
仍拒绝；同一 schedule 重启看到新 PID，实际 CLI 可读。没有启动消费该队列的 Worker，
不据发送调用或队列消息声称业务完成。测试专用 max-interval=1，生产间隔未改。
清理只针对自建进程、随机队列/交换机，日志中的合成 broker 密码替换为 redacted。

上一轮初次 Ruff 排版与 Pyright 数值类型/可选文件名检查发现问题，已明确缩窄类型并
格式化；未禁用规则或增加类型忽略。真实测试首次 **42 passed / 1 failed，5.82 秒**：
`channel.basic_get` 返回原生 AMQP Message，测试误调用 Kombu Message 的 `ack()`。
查实际安装的 AMQP Channel 接口后修正为 `channel.basic_ack(delivery_tag)`；保留消息
实际存在的断言，不改生产发布逻辑。专项随后 **43 passed / 0 skipped，11.87 秒**；
模板未提交候选全量 **243 passed / 0 skipped，43.32 秒**。固定提交复验另记如下。

## 3. 固定提交门禁

| 后端 | 本地固定提交 | Ruff/Pyright 与完整 pytest |
| --- | --- | --- |
| tpl-backend | `ed157e41f11e5e20e6b77812890cb55d382b58f4` | 通过；243 passed / 0 skipped，43.56 秒 |
| info-backend | `0a6675d679e59ead6153386e898aed3c1dc0825e` | 通过；488 passed / 0 skipped，74.92 秒 |
| knowledge-backend | `937f09f90a357fa142d24d7c3883da5dfb133597` | 通过；403 passed / 0 skipped，62.55 秒 |
| investment-backend | `6a5bff975649a548079e5eb82ee2b7cdb0872981` | 通过；386 passed / 0 skipped，68.66 秒 |

合计 **1,520 passed / 0 skipped**，Ruff/Pyright 均通过；本轮固定提交复验无失败。
模板父仓部署脚手架另 **8 tests OK，0.190 秒**，不当作部署或 KIND 验收。
六个文件在四后端 SHA-256 逐字一致：

| 后端根相对路径 | SHA-256 |
| --- | --- |
| `app/app/bootstrap/scheduler.py` | `6b60384990dc5c13bf1f1d807e61fee2e2d118beb330b55b92083825f590bc5d` |
| `app/app/cli/scheduler_activity.py` | `ef377733d099ff1a145730c7f43f94f1816f89cc1f5a8074e23e5602a685c61c` |
| `app/app/infrastructure/messaging/scheduler_activity.py` | `828ae322bef2e6bc4810f1c5f0a0708e7bc69fcfca62c6c7d5972394b3331942` |
| `app/tests/test_scheduler_activity.py` | `5be122f8abfde2364c9ad026b91e723b9c73ad4f1d4f1b2a78e6ccff8129dd6a` |
| `app/tests/test_scheduler_activity_broker.py` | `5f2fe1ddf624b1a1b9a5a66243e5830ff6c7e4ac3094edbeeb770cdbba27f881` |
| `docs/scheduler-activity.md` | `27f19b328ffe12dba1f6217b7475ea3e31d6fda21cc575d9f4bc97162ddfdee4` |

完整套件包含各仓实际随机 PostgreSQL schema 故障测试、契约，以及 Info 的合成 S3、
Investment 的隔离 PG/Redis 测试；重复公共测试计入各仓数量，不声称互不相同场景。
父仓 gitlink、master 和远端引用保留原值；对齐报告仅工作区增量，统一集成前不推。

## 4. 资源、回滚与余项

上一轮四个 B7i 容器及其一次性卷已清理。本轮重新创建 `luna-b7i2-pg`、
`luna-b7i2-rabbit`、`luna-b7i2-minio`、`luna-b7i2-redis`，标签 `luna.task=B7i2`；
仅 127.0.0.1 的 55439/55679/59039/56389，合计内存上限 1152 MiB、每容器 CPU 上限 1。
使用已有镜像、独立合成凭据、测试库/vhost/随机对象，无业务挂载。
最终测试退出 0 后重新核对完整容器 ID 与标签/挂载，再 stop、rm -v；四容器
`347b4c2399f3…` / `9bf55ee02442…` / `669e1fcaaeac…` / `0230ac13d4fb…`
及本次四个匿名卷 `a938dae1c2fc…` / `bd8ae938fa97…` / `9c3ae17ccb8f…` /
`87e9a092288b…` 均已移除，只删除可重建合成测试数据。
容器/卷清单复核无上述残留；原三个 KIND 节点及原三个月前退出的容器保留，镜像未删。
四后端工作区干净，三个父仓对齐报告未暂存、gitlink 未更新；五个本地 master
仍为 B7e 起点且干净。两个预置协议草案保留未暂存，未调用 push 或云端同步。

回滚仅恢复 bootstrap 默认 scheduler 并停用此 CLI，schedule 格式未变，不降级数据库。
不能将旧 activity 文件保留理解为回滚后的活动证据。实际新镜像/角色身份/单实例与
启动退出策略、Worker 消费进展仍待相应 B7 子项验收。

监控组件部署、实际采集/告警与通知送达已按所有者本次要求进入
[未来 N4-OPS-01](tasks/N4-OPS-01/thread/0001/user-message.md)，状态 NOT_STARTED，不在本包安装。
其他 B7 运维/保留归档/数据切换及 B8 接收仍未完成，不以本包关闭整项。
