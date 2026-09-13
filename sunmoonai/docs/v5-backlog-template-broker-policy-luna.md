# B7s：模板 RabbitMQ 权限与预建拓扑候选（Luna）

日期：2026-09-13。单人实施、自测；本包只推进到模板，不冒充三领域已对齐或业务已切换。
承接 [B7n 权限边界](v5-backlog-runtime-permissions-luna.md)和
[B7r 数据库候选](v5-backlog-investment-database-policy-luna.md)。

## 1. 冻结范围与提交

所有者“继续”，沿用[逐步处置清单](v5-backlog-disposition-luna.md)：剩余处置完成后再
一次性集成/同步。本包不新增分支，不推仓库、不更新 master、gitlink、镜像、部署或 Secret。
三领域 Backend 未改；三个既有对齐报告增量、父仓 gitlink 差异及两份未跟踪协议草案保留。

| 仓 | 开工基线 | 本包固定源码 |
| --- | --- | --- |
| tpl-backend | a91eb3e284ae91d4bc6b82fe567c4163cfa728f0 | 44e74fe02d29616dfe636b06cc717bd9698536d9 |
| tpl-app | 9abc39d0b78a67e3592570cd6c32ade1b3b40cc0 | df2893d5b5d547577c2b4280e0d73eeed768db06 |
| k8s | 98140fd5774f2d112a89324f0ac6beab964bf722 | 本报告、清单和覆盖矩阵；提交见 Git |

Backend manifest：`app/app/worker.py`、`app/core/config.py`、
`app/tests/test_broker_topology.py`、`docs/broker-topology.md`。
模板父仓 manifest：`k8s-deployment/runtime_broker_policy.py`、
`k8s-deployment/tests/test_runtime_broker_policy.py`、
`k8s-deployment/integration/test_runtime_broker_policy.py`、`k8s-deployment/README.md`。
父仓索引 gitlink 仍为 `53698628c5d26c9af933fd3fe567d239e7d3ecce`，本包没有发布悬空引用。

| 规则 | 本包落实 |
| --- | --- |
| I3/I8/D9 | 每个运行角色独立合成身份；凭据不进入编译器输出或前端；错误不放宽 ACL |
| T3/R6 | 同一 Backend 镜像的配置开关；模板先验证，尚未开始实例同步 |
| D1/D2/D8 | broker 不承担领域主档；不改业务 DB/迁移；完整回归只使用新建测试库 |
| R1/T4/T5 | 本地固定候选与部署分列；无中间推送、镜像构建或业务凭据切换 |

回滚为反向本包本地源码提交。没有业务状态变更；未来部署后不能只回退布尔开关而忽略
自动声明所需权限。测试资源仅限平台已批准、随机命名的新容器和其自身匿名卷。

## 2. 已复现的真实权限矛盾

当前 Celery 用 `CELERY_QUEUE` 同时命名任务交换机、队列及 routing key。Kombu 自动
声明后调用 queue.bind，需要目标队列 write、来源交换机 read。RabbitMQ 权限按资源名称
匹配，同名交换机的 read 也会允许从队列 basic.get/basic.consume。
语义核对 [RabbitMQ 访问控制](https://www.rabbitmq.com/docs/access-control)，实测版本为
4.1.3；不把当前网页关于 4.3.1 被动声明的新规则当成 4.1.3 实测结果。

隔离 broker 中分别对 API、Scheduler 证明：已有 configure/write 但无 read 时绑定拒绝；
给同名 read 后绑定成功，且可实际取走一条合成消息。因此不能靠补同名 read 实现“只发布”。
真实 `CeleryProducer.dispatch_ping()` 在旧默认声明模式配新窄权限时也明确 AccessRefused。

## 3. 候选实现及保证范围

Backend 显式开关 `CELERY_TASK_TOPOLOGY_PREDECLARED` 默认 false，保持原部署行为。
只有供给面预建并验证 durable direct 交换机、durable 非排他/非 auto-delete 队列及精确
绑定后，才能联合新的分角色用户启用。当前候选没有 Celery result backend。

启用后任务 Queue `no_declare=True`、不自动创建未知队列；开启 AMQP publisher confirms，
默认路由含内置 Celery 任务采用 mandatory 和 5 秒确认等待。漏建交换机、队列或绑定的
真实发布均报错，不静默返回成功。该保证不覆盖可信调用者自行覆盖发布选项或原生 AMQP。
它也不证明领域提交：确认丢失仍可能重复，原 Outbox/Inbox、租约与 fencing 继续承担恢复。

纯编译器只输出 vhost、任务拓扑及三个独立用户的 permissions，不输出 users/密码/hash。
名字校验、不同用户校验、控制资源保留字碰撞校验失败关闭。API/Scheduler configure/read
为空，仅 write 精确任务交换机；Worker 保留任务 read/write，以及锚定的 pidbox、reply、
事件资源权限，不能 configure/delete 持久任务队列或交换机。不授其他 vhost 权限。

没有关闭 Worker 的 mingle/gossip/heartbeat/remote control，真实本节点 readiness 通过。
但 Worker 的 read 也允许 purge，read/write 组合可能允许重新绑定；控制资源 ACL 不能
区别 inspect/shutdown，同一 vhost 的 Worker 控制面仍是信任域。不得把本策略描述成
Worker 内部不可篡改、逐条命令审批或未来浏览器授权机制。

## 4. 隔离验收

复跑入口在 tpl-app 根，必须先取得 Docker 执行批准：

```bash
BROKER_PERMISSION_TEST_CONFIRM=disposable-b7s-only \
  tpl-backend/app/.venv/bin/pytest -q -x -rP \
  k8s-deployment/integration/test_runtime_broker_policy.py
```

缺确认失败，不跳过；不接受外部 broker URL。RabbitMQ 固定缓存 image ID
`sha256:ee10eb35bee296808f458c828ef7f581c15e4f18bcaf621742938b0897fcf718`，
只映射宿主机 127.0.0.1 动态端口、无挂载、768 MiB/2 CPU。每例新建随机 vhost、
三个不同用户与独立密码，只写合成消息；结束删除本例对象，最后删除整个测试容器。

30 项真实 broker 场景：

- 2 项原自动绑定 read 泄漏复现；14 项生产者 get/consume/purge/delete/declare/控制发布/
  无关交换机发布拒绝；3 项跨 vhost 连接拒绝。
- 3 项真实应用生产者分别以 API/Worker/Scheduler 身份发布并由 Worker 取到原任务消息。
- 2 项真实应用旧声明模式拒绝；1 项 Worker 删除持久拓扑拒绝。
- 3 项分别漏建队列、交换机、绑定，真实应用发布必须失败。
- 1 项真实 prefork Worker 默认启动能力和本节点探针；1 项真实 ObservedScheduler/Beat
  进程周期投递、Worker 取到任务字节及本地活动探针通过。

第 31 项是完整模板 Backend 回归：另建缓存 PostgreSQL 17.6 的随机容器和测试库，
使用独立宽权限测试 vhost 跑既有数据库、进程和跨仓消费者向量测试；JUnit 拒绝任何 skip。
**这个宽权限回归不冒充上述 30 项窄权限证据，也不是 DB+broker 独立身份的联合业务启动验收。**
首次完整运行 31 passed；内层 Backend **258 passed / 0 skipped（53.61 秒）**。
提交后最终复验和清理证据见下节；初始缺集成环境的 174 passed / 84 skipped 已由完整回归覆盖。

## 5. 本包失败及根因处置

1. 镜像管理接口 401：日志明确“User can only log in via localhost”，镜像脚本
   `librabbitmq.sh` 的 `rabbitmq_print_management_configuration` 按默认设置写入
   `loopback_users.<初始用户> = true`。宿主机回环端口经 Docker 转发后不等于容器 localhost。
   延长等待和限制 Erlang 线程都未解决此问题；不是内存或密码错误。现保留初始限制，
   通过容器内 CLI 创建只属于测试的独立管理用户，再从回环 HTTP 供给合成角色。
2. 过早 await_startup 返回 69：Bitnami 初始化先启后台 broker、再停、最后正式启动；
   不能容器刚创建就调用 CLI。现等待最后一次启动完成标记，再执行 CLI 和认证探测。
3. 原辅助断言让 pytest 展示了临时 CLI 诊断（包括合成 cookie hash）。改成隐藏工具
   traceback、固定失败消息及 timeout 脱敏，合成实例 repr 不展示 URL；未读取业务凭据。
4. 单元测试把 Queue 字典的 KeyError 误当发布入口 QueueNotFound，改测真正的 send_task；
   集成测试把 py-amqp 原始 Message 当成 Kombu Message 调 ack，改用 channel.basic_ack。
5. 管理 HTTP 的异步统计字段 consumers 尚未出现，并非 Worker 未启动。改用真实 AMQP
   被动 queue.declare 返回的 consumer count；不填默认值或删消费检查。正式探针已先通过。

以上故障均未略过或迁入未来计划；修正后重新执行整套本包门禁。旧权限缺陷的拒绝/泄漏
保留为回归用例，不用放宽权限来“修复”测试。

## 6. 最终复验与下一游标

在 §1 两个固定代码提交上最终复验：外层 **31 passed / 0 skipped（91.88 秒）**，
其中 30 项真实 broker 场景、1 项完整回归包装；内层 **258 passed / 0 skipped
（51.82 秒）**。不把包装测试重复计算成额外业务场景。模板父仓普通 unittest **16 项**
通过（原 12 + 新增 broker 4），相关 Ruff、Backend 全量 Ruff/Pyright 和 git diff 检查通过。
未改三领域源码，因此本包未运行三领域套件，也不把 B7r 的旧结果充作本包验证。

最终创建并精确删除的容器：

- RabbitMQ `2e9d3be8af83f6c8ae0f55355fc6f87a97a423a57d4414c6e6587085875ce27a`，无挂载。
- PostgreSQL `7ed0650471ac7c886e64628884131dd9f13c3036c800dabd3ff4583cd88a0484`，
  image `sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b`。

PostgreSQL 自身三个匿名卷也逐一查询确已不存在：

```text
dcad4197cf0b8cd53c57fe8a60041c78f8ddeadbf71fe2d620361cc6221dd172
53979c4190694bbdc8f7859a6035ec60d1490d67a9a321e234d4bd61dd33010e
389fb9ab1b50b2fe92af7b8613ec261c3b822ec29a9325da3e41470f5ec6ef06
```

删除对象只有本包合成环境，不含业务数据、镜像或既有 KIND；测试数据已删除，需复跑重建。

下一步固定为 Info → Knowledge → Investment 串行对齐本公共能力、保留领域代码并分别
完成门禁；再推进联合 DB/broker 身份启动、消息迟确认/恢复及供给切换。任一实例失败停下
一个，不把模板局部通过外推到三实例。业务启动 definitions 持久化与重启不恢复宽权限、
旧连接撤销、可恢复备份、Secret/镜像/DB 联合切换仍未验收，继续留 B7。
只有原先批准的 Prometheus/Alertmanager 子项继续留 N4-OPS-01；B8/B9 和最终同步未关闭。
