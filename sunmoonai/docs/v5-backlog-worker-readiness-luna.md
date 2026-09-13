# B7e：Worker 消费配置就绪检查

2026-09-13；所有者原话“继续”，沿用单人 Luna 逐包实施与同步授权。

**当前状态：已修复本机重复校时配置；四仓原始完整门禁通过，源码集成与最终环境复核中。未部署。**

## 冻结范围与基线

父仓基线 tpl@b0f19c6、Info@41965dd、Knowledge@7c9e5aa、Investment@7874ae1、
k8s@2c1a2091；后端 tpl@1f8941f、Info@9ea1c5e、Knowledge@d16fb6c、Investment@7113e52。
本地基线重核干净，唯 k8s 两份预置协议草稿除外，继续原样保留。两端同步沿用 B7d 回执，
本包发布前再核预期 HEAD。工作区 Luna，单写者/整合者本助手，隔离为约定，不声称独立验收。

旧 M1-502 的 Worker 探针仅 grep pong，不能识别错误消费队列。本包新增共享 CLI 与测试/
说明，模板未来部署脚手架改用 CLI；按模板→Info→Knowledge→Investment 串行增量同步。
四后端仅新增 `app/app/cli/worker_readiness.py`、`app/tests/test_worker_readiness.py`、
`app/tests/test_worker_readiness_broker.py`、`docs/worker-readiness.md`；模板父仓 runtime
模板及 scaffold 测试，三个父仓模板对齐报告，k8s 本证据/处置清单/覆盖矩阵/模板指南。
不修改已锁定 digest 的历史 bundle/release；旧镜像没有新 CLI，须下次共同发布再接实例探针。

| 规则 | 处置 |
| --- | --- |
| D1/D2/D8、C1/C2 | 不建表、不访问业务 DB、不投业务任务；检查复用现有 Celery 配置与任务注册真源 |
| I3/I8、T3 | 本 Pod exec，Settings 中既有 Worker broker 身份；不增权限/Secret/HTTP 面；失败仅固定错误码 |
| R6、C3/C4 | 模板固定提交门禁后严格串行实例；保留领域任务注册，无 DTO 或依赖修改 |
| T4/T5、R1–R5/R7 | 先子后父、预期 HEAD 快进再同步；不构建/推镜像、不部署、不改旧发布记录 |

判据：仅定向本 POD_NAME 的 `celery@…`，队列名/交换机/路由/持久性符合配置，
应用注册任务完整；空/错节点/异常/缺任务/错队列/失联均失败关闭。子进程隔离限制总耗时，
丢弃库日志，避免连接重试超出 Kubernetes 8 秒探针预算；不把 broker 故障绑定 liveness
制造重启风暴。控制查询会创建临时 broker 回复队列/消息，并非网络层“纯读”，但不改业务队列。

硬门禁：配置/回复结构/队列/任务负例；本机名缺失；异常脱敏；真实子进程超时回收；
隔离 RabbitMQ + 本仓真实 Worker 正向、pong 但错误队列、失联和恢复；四仓 Ruff/Pyright
及完整回归零跳过，模板脚手架回归。只用 loopback 一次性容器与合成数据，结束核精确 ID 清理。
单包最多两轮修复后重新评估；任何实例失败停止下一实例；无真实用户/财务数据，无多家评优。

不判：消费完成进展、prefork 子进程卡死、Scheduler 周期活性、DB schema、真实 broker
ACL/网络/负载和 KIND。readiness 失败也不会停止 Celery 消费；这些继续 B7，不能将整项销账。
采集/告警及归档仍未完成，源码搜索未找到应用 Prometheus 接线，不由此擅自安装监控平台。

## 开发期失败与范围增量

第一轮真实 Worker 启动失败，隔离 RabbitMQ 日志明确初始用户仅容器内部可登录。
仅在该一次性 broker 增加合成测试用户、授权固定测试 vhost 后专项通过；未改业务身份。
模板首轮全量 32 passed 后，旧 `test_database_lock_timeout_and_recovery` 恢复步骤超时。
源码显示 50 毫秒 monkeypatch 注入跨过锁释放，仍作用于恢复阶段；单独复跑通过。
增加四仓该测试文件的局部修正：用 monkeypatch.context 将人工 50 毫秒预算限制在故障
阶段，恢复时回到原生产 2 秒；保留超时与恢复断言，生产代码/预算完全不变。
这是本包唯一范围增量，先模板重过固定门禁再同步；不是 B7c/B7d 其它时序失败根因的证明。

Knowledge 固定 7b11608 首轮全量在旧重放观测用例失败（33 passed）：死信为 0、可发布
为 0，预期后者为 1。立即停止串行推进。只在失败后取证的临时脚本第一版另遇到
claim 后 expired publisher 数量异常，但诊断参数误用 ISO 字符串而非 datetime，未取得
完整状态；该诊断错误已修正，不能将它当作环境根因证据。
后续 150 + 600 次同循环、100 次独立事件循环的原场景均未复现；完整测试顺序加临时
失败后取证插件为 322 passed（48.55 秒）。这些是诊断，不替代常规固定门禁。
生产源码/原重放断言均未修改。当前只能确认是 B7d 已存在的同一未解决症状，不能确定
数据库时钟、循环、驱动或实现根因；不因重跑通过标为修复，亦不据本包开放部署门禁。

去掉诊断插件后的常规全量再次失败：180 passed 后
`test_response_loss_recovers_without_repeating_remote_write[upload]` 的恢复消费返回 False
（22.30 秒）。这与早先的抓取取消/重放症状有相似时序，但关联及根因仍未证明。
独立只读诊断交替两个连接做 10000 次 PostgreSQL 时钟读取未见倒退；该结果不能排除
所有时钟问题，也不支持断言“WSL/NTP 就是根因”。不继续重跑直到变绿，不放宽断言。

## 首次门禁断点（历史，后续修复见下）

| 仓 | 本地 Luna 后端候选 | 固定常规门禁 |
| --- | --- | --- |
| tpl-backend | `53698628c5d26c9af933fd3fe567d239e7d3ecce` | 167 passed / 0 skipped，28.58 秒，Ruff/Pyright 通过 |
| info-backend | `7755da238c73f494157f6e147ec1467b4c075872` | 411 passed / 0 skipped，57.14 秒，Ruff/Pyright 通过 |
| knowledge-backend | `7b11608e163da70f66c32e4c96ac0ef7c6065168` | Ruff/Pyright 通过；两次常规全量失败，未通过 |
| investment-backend | `7113e528bce0d69eed6f2ca46ad85abf5f18abc7` | 未推进，仍为 B7d 基线 |

模板父仓 `ee0978a253a5fadd2f5049d8877d4e9f7f42782b` 的脚手架固定回归 8 tests OK
（0.235 秒）。Info 父仓候选 `df46b5460a64effc74fd222b0f578353f36a40ea` 有增量对齐报告。
新探针自身为每仓 35 单元 + 1 个真实 RabbitMQ 场景；模板/Info 完整门禁含该场景，
Knowledge 带诊断的完整运行也执行该场景，但不能抵消其常规套件失败。

模板和 Info 子仓已先推现有远端 master 与 `luna/durable-delivery-20260911-local` refs；
**这不是父仓 master 或部署升级**。五父仓本地 master 仍为开工基线，没有运行五仓
remote-pull，云端工作区未由本包更新。Luna 的父仓/Knowledge 子仓候选仅本地保存，
尚未推送；不得据此前两子仓推送成功宣称 B7e 跨机交付完成。

下一步先调查两个常规失败的完整状态/时间/租约，保留原断言与失败证据；如需公共修复，
回模板冻结增量，模板→Info→Knowledge 重新过固定门禁后才到 Investment。
这比继续做 Scheduler/采集优先。B7e、B7 整体及 B8 均未完成；无业务数据/Secret/镜像/部署操作。

## 首次断点与清理（历史）

Knowledge 父仓仅 `knowledge-backend` gitlink 为本包工作中变动，尚未提交；子仓候选已有
上述本地提交且干净，不丢改动，不将未推子仓的 gitlink 发布出去。Investment 完全未改。
模板/Info Luna 父仓候选已本地提交且干净；k8s 只提交本包四文档，两份预置草案不暂存。
恢复时先核这些实际 HEAD，不按 B7d 的“全部工作区一致”假设直接 realign 或覆盖。

四个新建一次性 RabbitMQ/PG/S3/Redis 容器核完整 ID 后停止并自动移除，复查名称无残留；
本包诊断进程/合成 Worker 匹配检查无残留。仅删除可重建合成数据，不清理任何业务资源。
本机 `/tmp/luna_b7e_observation_probe.py`、`/tmp/luna_b7e_pytest_capture.py`、
`/tmp/luna_b7e_db_clock.py` 是临时诊断草件，不作为正式交付或稳定测试门禁；重启后可能丢失。
后续如继续复现，须先新建隔离资源并明确测试 URL，不复用已删除容器的运行态假设。

所有者随后明确“出现问题总要解决”：继续排查而非交接停工；上节是首次资源清理的
历史断点，后续重新建立一次性 PG。只暂停下游推进/合并，不暂停根因定位和修复。

## 时钟故障定位与获准的环境修复

续查相关两文件 20 轮均通过，转回完整上下文后又在
`test_hung_provider_read_is_cancelled_at_deadline` 得到 consume=False（154 passed 后失败）。
诊断代码只在失败后取证，不修改业务断言。独立顺序 DB 时钟审计终于捕获确定的倒退：

| 读取 | PostgreSQL clock_timestamp / UTC | 后端 PID |
| --- | --- | --- |
| 前一次 | 2026-09-13 04:09:38.985104+00:00 | 1163 |
| 后一次 | 2026-09-13 04:09:37.109305+00:00 | 1162 |

两次读取按 monotonic 时间顺序完成，数据库墙钟倒退 **1,875,799 微秒**。因此“上一操作
已完成 ⇒ 下一操作读到的 clock_timestamp 更大”在此环境不成立；刚释放的 expires_at、
刚重放的 available_at 等可能重新落到未来。没有把没有回执直接当作重复执行授权。
完整用例失败时的全部 SQL 状态并非每次都捕获；证据足以确认时钟故障及它能造成该类
边界失败，但不把全部历史偶发错误无区别证明成同一根因。

系统实测 Ubuntu 24.04 / WSL2，内核参数 `hv_utils.timesync_implicit=1`，同时
timesyncd 为 enabled/active；NTP 32 秒轮询，offset -1.772516 秒、jitter 723.392 毫秒。
系统日志多次 `Time jumped backwards, rotating`。当前 clocksource 为 tsc，本包未更换。
[Ubuntu 官方说明](https://ubuntu.com/wsl/docs/stable/explanation/time-sync/)明确指出，
Hyper-V 隐式校时与 WSL 内 NTP 可能冲突，Ubuntu 24.04 采用宿主校时时应禁用 timesyncd。
[PostgreSQL 文档](https://www.postgresql.org/docs/17/functions-datetime.html)区分事务时间与
实际墙钟；clock_timestamp 本身不是单调时钟，不用 sleep 或放宽断言掩盖异常。

逐步获准后实施（本机系统运维增量，不是应用镜像/业务部署）：

1. 临时 stop timesyncd，保留 Hyper-V，不手工改时钟、不重启。连续 180 秒、31,940 次
   跨连接读取 **0 次倒退、0 次超过 50ms 的跳变**，相对 monotonic 最大残差 2.821ms。
2. 按官方建议 disable timesyncd 开机启动；最终 disabled/inactive/dead。
   原 enabled/active 已记录，避免重启后双重校时重新出现。
3. 查 Windows W32Time：服务 Running/Automatic，但 Leap=3、stratum=0 未同步，原
   NtpServer=`time.windows.com,0x9`，Type=NTP。原源三次 UDP 123 探测均超时；Ubuntu
   NTP 三次均响应，宿主偏差约 -1.45～-1.47 秒。普通 resync 被拒绝，UAC resync 后
   状态仍未同步；没有把进程退出码当成功。
4. 另获准将宿主源改为 ntp.ubuntu.com 客户端模式并 resync。实际注册表
   NtpServer=`ntp.ubuntu.com,8`，Type=NTP；读回 Leap=0、stratum=3、来源
   185.125.190.57，最近成功同步 **2026-09-13 12:24:22 CST**。时区未改。

WSL 保留宿主校时后，不要仅因 Linux 的 NTP 服务未运行就再次启用 timesyncd。
应核宿主同步状态和数据库墙钟稳定性。未来换机器先核源码同步，也先核测试环境时钟。
人工大幅校时、宿主休眠恢复等仍需运行门禁；本包不是数据库时间永不跳变的形式化保证。

仅在需要回退且重新评估校时冲突时恢复原设置：管理员 w32tm 将 manualpeerlist 设回
`time.windows.com,0x9`；WSL `sudo systemctl enable --now systemd-timesyncd.service`。
这些是恢复原值的方法，**不是推荐常态**；本包没有自动执行回退或改 Windows 时区/其它服务。

## 修复后的固定门禁

生产投递源码和旧重放/重试断言不改，不借诊断插件、不跳过测试；模板开始重新串行。

| 后端 | 固定提交 | 完整原始回归 |
| --- | --- | --- |
| tpl-backend | `53698628c5d26c9af933fd3fe567d239e7d3ecce` | 167 passed / 0 skipped，27.81 秒 |
| info-backend | `7755da238c73f494157f6e147ec1467b4c075872` | 411 passed / 0 skipped，54.77 秒 |
| knowledge-backend | `7b11608e163da70f66c32e4c96ac0ef7c6065168` | 连续 322 / 322 passed，均零跳过，44.71 / 44.50 秒 |
| investment-backend | `d2312663433343f877ad33b8d342d1e258495a73` | 305 passed / 0 skipped，50.76 秒 |

合计 1205 项（各仓含重复公共场景），四仓 Ruff/Pyright 通过。新增四文件与修改的旧观测
测试文件五份 SHA-256 四仓一致；Investment 原 Agent overlay 原样保留，新探针按本仓
真实任务注册表检查。模板脚手架 8 项通过。宿主 NTP 源恢复后另做最终时钟审计及 Knowledge
全量，结果后填；该环境修复不替代应用镜像、真实业务身份、KIND、部署及数据切换验收。

最终宿主已同步后的复核：同一 Knowledge 提交原始完整 **322 passed / 0 skipped**
（44.81 秒）；连续 180 秒、31,858 次 DB 时钟读取，**0 次倒退、0 次超过 50ms 跳变**，
相对 monotonic 最大残差 5.938ms。模板父仓脚手架再跑 8 tests OK（0.197 秒）。
此前失败的既有测试正常保留；未增加 sleep、retry-until-green 或跳过标记。

## 本包源码集成对象

| 父仓 | 锁定上节后端的内容提交 |
| --- | --- |
| tpl-app | `ee0978a253a5fadd2f5049d8877d4e9f7f42782b` |
| info-app | `016517ba7c9f8a66b95a4dfde9e6d7e1886eb504` |
| knowledge-app | `8150c520fad0a8f8a6738441501f0e7104a7475a` |
| investment-app | `fc4503f35c131ee14e29c10354948dfad65e8f0e` |

四后端既有 master/Luna refs 已推；父仓快进与云端实际 checkout 核对后再回填同步回执。
本包仍不声称消费进展、Scheduler 心跳、scrape/告警/归档或业务部署已验收；下一 B7
继续这些独立旧账，B8/N1～N6 正式接收仍未完成。
