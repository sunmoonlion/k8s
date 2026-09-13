# B7t：三实例预建 broker 拓扑增量对齐（Luna）

日期：2026-09-13。单人实施、自测，不宣称独立评审。承接
[B7s 模板权限候选](v5-backlog-template-broker-policy-luna.md)，沿用
[逐步处置清单](v5-backlog-disposition-luna.md)的“先完成剩余处置、最后统一同步”。

## 1. 冻结边界与基线

只将模板 `tpl-backend@44e74fe02d29616dfe636b06cc717bd9698536d9` 的四文件增量
按 Info→Knowledge→Investment 串行同步，并用各后端自己的 Python 环境验收。
运行源码只有配置开关及 Celery 构造增量；新增公共测试和说明。不改领域服务、任务注册、
迁移、前端或跨域 DTO；不把 broker ACL 当成浏览器审批机制。

| 仓 | 开工 HEAD |
| --- | --- |
| tpl-app | df2893d5b5d547577c2b4280e0d73eeed768db06 |
| tpl-backend | 44e74fe02d29616dfe636b06cc717bd9698536d9 |
| info-backend | 7dafb34ca70d1f71ebc332315bf0c7584b9c3092 |
| knowledge-backend | 5df4f1759cd64bd0a3ca2c4cae8f68102ebe681d |
| investment-backend | 3d9531d1250d035aa13eb197198b6c5672450856 |
| k8s | 3238154d67973e2d2fd09c59641cf4b9978c3db1 |

模板测试入口最终固定 `tpl-app@fb9aee86646b51fad16cc17bd3e81be919eb5591`。
其前一提交 `5a59931` 增加通用目标/辅助服务，后一提交保持模板共享交互向量真源。
所有子仓仍使用既有分支，不新建分支。不更新父仓 gitlink、master、Harbor 镜像、
业务 Secret/definitions、集群或远端。三个父仓预置对齐报告增量（Info 76 行、另两仓
各 74 行）保留，不混入本轮新提交；两份未跟踪 general/pro 草案不动。

| 约束 | 落实 |
| --- | --- |
| R6/T3 | 模板先验，实例严格串行；仍为一套 Backend 按角色运行 |
| C3/C4 | 不产生交互向量副本；读取模板真源，领域 provider 锁/契约不改 |
| D1/D2/D8 | 不改业务库或迁移；故障测试使用随机新容器内测试 schema |
| I3/I8/D9 | 独立合成 broker 身份，禁止生产者消费/改拓扑；新开关默认关闭 |
| R1/T4/T5 | 代码候选与业务部署分列；固定提交验收，不中途发布悬空 gitlink |

## 2. 共用门禁与证据边界

`tpl-app/k8s-deployment/integration/test_runtime_broker_policy.py` 仍是唯一 broker
集成门禁；`broker_test_support.py` 不导入 App 模块，只选同级已初始化 Backend 并创建
临时依赖。每次用目标自己的 `.venv/bin/pytest` 执行，避免四套 app/core 模块混装。

参数：`BROKER_PERMISSION_TEST_CONFIRM=disposable-b7s-only` 必须明确提供；
`BROKER_PERMISSION_TEST_BACKEND` 为目标 Backend 的 app 绝对目录；
`BROKER_PERMISSION_TEST_AUXILIARY` 为 none、s3 或 redis。拒绝任意目录和外部依赖 URL。

每轮包含 30 项限制身份的真实 RabbitMQ 验收、1 项完整 Backend 零跳过回归包装、
2 项辅助服务启动/清理。完整回归的临时测试 broker 身份是独立 vhost 内的宽权限，
不充作 30 项窄权限证据；PG 回归也不是 B7o～B7r 四身份矩阵的重新验收。
Worker 保留实际任务注册、mingle/gossip/heartbeat/remote control 和原 readiness；
漏建队列/交换机/绑定必须令真实发布失败，API/Scheduler 不能消费、purge 或改拓扑。

Info 完整回归另用临时 S3（回环 59039、原测试声明的合成凭据）；端口占用会失败，
不复用现有服务。Knowledge 不增加辅助业务依赖；Investment 使用临时密码保护的
Valkey 测 Redis Lua，以及同一临时 PG 提供的 AGENT_TEST_DATABASE_URL。
Web 交互向量仍来自 tpl-app/contracts，领域契约仍由各自现有测试核验。

辅助服务固定缓存镜像：

```text
MinIO  sha256:a72bf37c235a83a73890d2a46c5b36801fed61c335175e0396070bf84a8bbb98
Valkey sha256:9917e842cfc3220e4ac3e819eb98a975cc171eff5e532c79cb75558030eb9078
```

RabbitMQ/PG 镜像沿用 B7s。均只建立本轮随机容器、回环端口及自身匿名卷；每个资源
校验容器 ID、镜像、标签和挂载，清理后查询容器/卷确已消失。不删除镜像或业务数据。

## 3. 串行结果与对齐分类

| 后端 | 固定提交 | 外层共享门禁 | 内层完整 Backend |
| --- | --- | --- | --- |
| 模板 | 44e74fe02d29616dfe636b06cc717bd9698536d9 | 33 passed / 0 skipped，91.62 秒 | 258 passed / 0 skipped，51.73 秒 |
| Info | 5fb909b6a012bfa62d1002abb6deb3fd9e3dc016 | 33 passed / 0 skipped，124.14 秒 | 503 passed / 0 skipped，81.91 秒 |
| Knowledge | e79a71272dbcf487e2a0def6dd65a954d3ca0ed8 | 33 passed / 0 skipped，112.49 秒 | 418 passed / 0 skipped，71.24 秒 |
| Investment | 68f776edf6f8155f4e5ebfc4e321a17da229dc95 | 33 passed / 0 skipped，127.73 秒 | 402 passed / 0 skipped，79.25 秒 |

上述模板结果在共用入口 `fb9aee8` 固定后取得；普通模板父仓 unittest 18 项通过。
三实例均在各自固定提交上完成全量 Ruff/Pyright 及新增配置测试，再完成表中门禁。
模板 Backend 未改，静态结果沿用 B7s 同一固定提交；本包重跑完整 Backend/外层门禁。
内层总计 **1,581 passed / 0 skipped**；外层总计 132 项中有 4 项完整回归包装，
不重复计成额外业务场景。真正的 broker 权限场景为每仓 30 项、合计 120 次场景执行。
本包三实例没有真实测试失败；未用 retry 到偶然变绿或删除断言的方式通过。

四文件范围：`app/app/worker.py`、`app/core/config.py`、
`app/tests/test_broker_topology.py`、`docs/broker-topology.md`。
worker/settings 仅同步公共增量，保留领域任务、默认队列、领域设置和既有计划任务。
测试及说明须逐字相同；这不是全仓文件相同的声明。

四仓公共测试/说明 SHA-256 分别为
`7351cae7dd12faf52a3d9e8710d3fd084d6ccfd47e75f9b33fdc78a7eec376f9` 和
`3b1aace826a3b48fe9e75f3699a1fdbdc835e40a54243a084f36cd5acc654d48`，逐仓核验一致。
从 `def configure_celery` 到首个 `if os.environ` 边界行的公共段抽取 SHA-256 也均为
`1b786eda321c93d39c781adb72733bfb600b2c0c0d153dbac0c5529d600c248a`。
领域注册、默认配置和计划任务仅保留各自原有差异，无新增临时兼容或本增量违规漂移。

三个父仓各新增 `docs/template-alignment-broker-topology.md` 记录四类差异和未验收范围，
不把本轮说明追加并提交到含预置增量的旧报告中。父仓 gitlink 仍保持原索引值。
报告提交：info-app `012d08bb0cc8e3952b25ea68b460927c2d03f1a8`、knowledge-app
`56951491079844bfe62115f635504d4d94e47c8d`、investment-app
`6a443ccdd410cc227732d4eed290d1de95393e90`。

最终四次串行门禁均已逐资源验证清理：模板/Knowledge 各 4 个容器，Info/Investment
各 5 个（完整回归额外使用 S3/Redis）；共 18 个最终验收容器及 17 个自身匿名卷。
主要 RabbitMQ/PG 对象如下，其余辅助服务 ID 和卷 ID 随门禁安全输出，清理后均查无对象。

| 目标 | RabbitMQ 容器 ID | PostgreSQL 容器 ID |
| --- | --- | --- |
| 模板 | 8ab38f58433e3c2c13fb43f832f8d681d20360f4ad0ae8b991fd8b3bcc84a618 | acf83a2dc8de020fadfa0021f77436197c3f62573465bbc42c5a4bb23aaf34ed |
| Info | ab985399dc1993e9cfb2ed581e084dfb9409a3f9233faaffbfa903942cdd0f5b | a3023466d0670e782695349a6a10b5b89983cb68c3d893bc3aa4d3f5018b1964 |
| Knowledge | 68faa58978fc9911a97f1bd4edf6a0ec929b373cbb537db5b55596dac73dc587 | 3bd200c0004e4667ff733fd3067f9f86afe7e79f71451c829e8be36f7cce3f97 |
| Investment | 491f9217f4f88384743124699e83b69faa6a73918608333572ef79210f47b1b9 | c9a66a3108472a9f809aa312b65ea8c9df31f513131101264d0c88f636a519c3 |

被删除的是本包合成测试数据，复跑会重建；没有删除业务数据、镜像或旧 KIND 容器。
收尾 docker ps -a 再核，仅原三个 KIND 节点与旧退出容器 gifted_chaum，ID 未变。

## 4. 发现与处置

- 共用辅助模块最初被单元测试加到 sys.path 首位，和单元目录中同名的 broker 测试模块
  冲突；改为追加辅助模块路径，普通 unittest 18 项重新通过。未把 import 失败跳过。
- 只读预检发现实例父仓没有 Web 交互向量副本；候选入口改回读取模板真源，而非复制
  文档或造三套向量。修正后的模板固定提交重新验收后才推进 Info。

## 5. 尚未关闭的工作

本包只验源码与可丢弃环境，不改现有业务部署，也未重新执行 KIND/身份切换/发布回滚。
预建开关、精确拓扑、独立 DB/broker 凭据及新镜像仍须联合供给；不得只改一个布尔值。
联合身份启动、真实处理/迟确认/恢复、启动 definitions 持久化与重启一致性、旧连接排空
和撤销、备份恢复与受控切换仍留 B7。模板和三实例 broker 通过也不自动关闭这些子项。
N4-OPS-01 监控待办、B8 未来计划正式接收、B9 最终集成同步保持各自边界。
