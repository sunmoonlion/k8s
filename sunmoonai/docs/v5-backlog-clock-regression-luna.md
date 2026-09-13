# B7f：历史投递失败的确定性复核（Luna）

日期：2026-09-13。状态：本地候选已提交，固定提交完整复验通过；未集成、推送或同步。
执行者：Luna 单人开发、自测；不宣称独立评审。
范围与顺序以[处置清单](v5-backlog-disposition-luna.md)为准。

## 1. 为什么不能只记“偶发”

历史现场包括 Info B7c 抓取取消后同来源消息 `consume=False`、Knowledge B7d/B7e
重放后可发布数为零、上传响应丢失后的立即恢复和轮询 deadline 用例 `consume=False`。
这些都不能因后来复跑通过就销账。
[B7e](v5-backlog-worker-readiness-luna.md)已捕获真实 DB 时钟回退 1.875799 秒并修复
WSL 双重校时与宿主时间源，但没有保存每一次旧失败的全部数据库状态。

本轮不修改宿主时间，不重新开启已修好的冲突校时；只在一次性测试数据库所用的
SQLAlchemy engine 上替换显式 SQL 时钟表达式，执行的仍是真实事务、约束与领域服务。
一小时偏移用于让已知机制稳定出现，不代表历史回拨幅度，也不是压测统计。

## 2. 可重复的机制与修复

| 路径 | 旧行为与确定性证据 | 候选修复 |
| --- | --- | --- |
| 执行释放 | 释放写 `expires_at=clock_timestamp()`；回拨后变为未来，claim 被拒且旧 owner 的 renew/guard 被接受 | 显式释放写负无穷，保留 owner/epoch 墓碑及接任者隔离 |
| 立即投递 | 无预约 enqueue、重放、对账写当前时间；回拨使本应立即可投递的消息多等一段墙钟时间 | 无额外等待使用负无穷；实际失败退避继续使用未来时间 |
| 观测预约 | 没有 not-before 时用 created_at 作门槛；回拨后将未预约消息计为 scheduled | 与执行语义一致，无预约用负无穷；年龄仍按创建/预约时间且非负 |

模板新增回归先对未修改生产代码执行，得到 **6 failed / 3 passed**：包括领取被拒、
释放后的旧 owner 续租/guard 未拒绝，以及 enqueue/replay/reconcile 的错误等待。
模板修复后专项 61 passed，完整 176 passed / 0 skipped（28.57 秒），Ruff/Pyright 通过。

Info 复核直接调用原始
`test_inflight_worker_blocks_same_host_not_other_host_and_cancel_releases`，不改原断言。
只把第一次忙来源释放时的 SQL 时钟前移，随后恢复；未修改生产代码上 **1 failed**，
准确停在原第 328 行 `assert await runtime.consume(same_message)`，返回 False。
来源 advisory lock 已释放，阻塞发生在公共执行租约领取，未进入抓取 handler。

上述证据证明了代码中的缺陷及同一失败点的因果路径，不声称恢复了每次历史现场。
其余正常拒绝条件（已处理 Inbox、未到真正预约时间、活动死信、真实在途 owner）仍需
保持有效，不可用一律重试或返回 True 掩盖。新增故障测试与原全量同时验收。

Knowledge 在未修改生产代码上复用原场景，得到 **4 failed**：upload/parse 在原
`test_knowledge_delivery_db.py:291` 重试返回 False，轮询在
`test_ingestion_polling_db.py:550` 返回 False，重放观测在
`test_delivery_observation.py:189` 得到 dead-letter=0、publishable=0。
故障仅加在第一次释放或重放的 SQL 时间，原测试的 deadline、超时、Provider 写入次数和
结果断言均未改。修复后同故障场景与全部旧测试一起通过。

Investment 独立租约旧代码另有 **4 failed**：释放后 claim/renew/guard 同类错误，
以及取消已递增 epoch 但释放时间回拨后仍被计为 active。候选同步明确失效状态，
保留取消的 epoch 递增和权限检查，释放额外精确匹配 command_id；未替换领域租约表。

## 3. 兼容性与边界

无新表、迁移、依赖或配置；不更改 Inbox、业务主档、死信重放审计时间或幂等键。
负无穷是原 PostgreSQL timestamptz 类型支持的值，旧 SQL 比较仍可读取；不批量改旧行。
释放行不删除、不重置 epoch；旧 owner 的迟到释放不得撤销新 owner。
Investment 的独立 Agent session 租约必须同语义修复，不能覆盖为公共租约表。

本包不把墙钟改造成单调时钟，不承诺活动 TTL、预约、真实退避、deadline、超时对账
不受任意系统校时影响；原环境校时修复继续有效。既有记录、实际监控和运行环境仍需
后续门禁。源码修复不是镜像、部署或数据切换，禁止借此操作业务库或做回收。

## 4. 串行验证与剩余处置

模板先完成，随后严格 Info → Knowledge → Investment；每一仓失败就先解决再推进。
当前所有改动只在 Luna 工作区，未中间合并 master、push 或运行远端同步脚本。
本地固定后端候选如下；总计 **1250 passed / 0 skipped**，较 B7e 新增 45 项，
共享测试在四仓重复执行，不当作 1250 个独立业务场景。四仓 Ruff/Pyright 均通过。

| 后端 | 本地提交 | 首轮全量 / 秒 | 固定提交复验 / 秒 |
| --- | --- | --- | --- |
| tpl-backend | `1c5173bbd6aeff9ca0d1cc1ebaa8282e9d597969` | 176 / 28.57 | 176 / 28.98 |
| info-backend | `fbb48ef7b80dce04f8a75e54f8011b60cd4389aa` | 421 / 56.15 | 421 / 56.85 |
| knowledge-backend | `94512d5f0e22fea49bfada5a32e117c2237fe2f2` | 335 / 47.64 | 335 / 47.14 |
| investment-backend | `24a7512d7981543106c6174cfdddc0372b8b4e00` | 318 / 53.39 | 318 / 51.68 |

四公共生产文件、共用回归及说明 SHA-256 在四仓一致；三个领域额外测试各自保留。
固定复跑命令为各后端 `app` 中的 `.venv/bin/pytest -q -x -rs --tb=short`；
`DELIVERY_TEST_DATABASE_URL` 指向本机 55439 的一次性 `backlog_tests`，真实 RabbitMQ
隔离 vhost 经 `CELERY_PROBE_TEST_BROKER_URL` 启用，共享向量经
`WEB_INTERACTION_CONSUMER_VECTORS` 指向模板契约文件；Info 同时启用一次性 S3，
Investment 同时启用 `AGENT_TEST_DATABASE_URL` 与一次性 Redis。不调用业务 Provider。

另发现 2026-09-11 Info 模板对齐报告中的 Calico 首次允许探针失败尚无根因。
它是独立网络验收问题，不归于投递校时。本轮只读检查原门禁脚本发现：探针日志丢到
`/dev/null` 且 Pod 在判断结果前删除，失败时缺少现场；退出清理 trap 又先于“集群已存在”
检查注册，可能清理并非本次创建的同名集群。原脚本未执行，不据这些问题断言首次放行
失败的网络根因；下一工作单元必须先修安全边界和诊断保留，再受控复核包级放行/拒绝。

本包之后仍须完成 B7 消费进展/Scheduler/采集告警/保留与实际环境门禁的处置，以及
B8 新 dev-plan 正式接收；不可将本包通过写成旧账已全部归零。
