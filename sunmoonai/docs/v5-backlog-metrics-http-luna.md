# B7h：受保护的投递指标 HTTP 采集

日期：2026-09-13。Luna 单人实施、自测，不宣称独立评审。
四仓最终本地固定提交全量通过；没有集成 master、推送或同步。
范围/基线/授权沿用[逐步处置清单](v5-backlog-disposition-luna.md)。

## 1. 本包补什么

[B7d](v5-backlog-delivery-observation-luna.md) 已有实际账本的只读 collector 和 CLI，
但尚无采集器可调用的受保护 HTTP 入口。B7h 在同一个 Backend API 中增加
`GET /api/internal/v1/delivery/metrics`，不另建服务、业务账、数据库迁移或缓存。

入口复用 `delivery_observers.py` 的实际策略：Info/Knowledge 的 handler 注册不动，
Investment 的 AgentDelivery 和租约判断不动。API 使用 lifespan 已有 session factory，
不在每次请求初始化/关闭数据库，也不调用 claim/pump/replay/reconcile。

| 边界 | 实现与验收 |
| --- | --- |
| 服务身份 | 原 OIDC 验证器校验签名、issuer、audience、有效期；subject 精确绑定，实际 scope 包含 `delivery:observe`，全部 scope 是绑定子集 |
| 浏览器隔离 | Cookie 不授权该接口；浏览器 audience 的令牌也拒绝；未授权请求不触碰数据库 |
| 最小授权 | 无新增默认 subject、客户端、凭据或配置值；旧主体不会自动获得指标访问权 |
| 数据访问 | 既有 READ ONLY / REPEATABLE READ；collector 2 秒协作式预算、SQL 1.5 秒；只静态、有界 policy/topic 标签 |
| 负载保护 | 每进程最多一个在途采集，多余请求立即 503 busy，不排队；不是跨进程/副本全局限流 |
| 失败与新鲜度 | 完成采集和渲染后才返回；错误 503、不输出半份/假零/缓存旧值；成功及预期 401/403/503/405 均 no-store |
| 生命周期 | 取消不吞、finally 释放采集槽；不初始化/关闭 API 共享池；OIDC 超时独立于 collector 预算 |
| 日志 | 采集失败只传安全错误码给统一错误处理，不透出原 SQL、参数、驱动异常或 DSN |

身份验证使用合成 OIDC discovery/JWKS 响应、真实 RSA 签名及原验证代码；不是跳过鉴权
的 dependency override，但也不冒充真实 Casdoor/采集器身份的部署验收。
PG 是本次一次性容器及随机 schema；锁、非法时间字段、只读状态和恢复均在真实 DB 验证。

## 2. 失败处置与覆盖

初次专项 1 failed：端点误重复写了 `/api`，而 API 工厂统一添加该前缀，实际请求得到
404。核对实际挂载后改为相对路径；原 URL/授权断言不变，随后专项 24 passed（2.75 秒）。
初次 Ruff 的排版问题经格式化修正，未改规则或依赖。

模板首次全量 99 passed / 1 failed：旧 `test_dormant_capabilities.py` 明确断言没有
Internal router。能力新增使休眠声明失效，按该机制的要求删去这一条，改成真实路由表
的正向挂载检查，并同步模板/Info 指南；保留其他休眠项和全部强制鉴权负向断言。
Info 同样存在该旧声明，等模板全量通过后才串行改；Knowledge/Investment 原来已有
领域 Internal 路由，不修改其休眠清单。总览旧“零调用 Outbox / 无 beat_schedule”
投影同时按已存在源码更正，不能让过时文档继续被误当当前事实。

每仓 HTTP 专项 24 项：缺令牌/Cookie/格式、错签名/issuer/audience/过期、未绑定主体、
缺 scope/越权 scope；真实 DB 只读聚合和 observer 装配；锁超时 503 后恢复；非法
数据库值/连接池/策略/采集/渲染异常的脱敏与恢复；并发拒绝、取消传播与准入释放；
四个写方法 405。未跳过、放宽授权或用重试至绿替代根因修正。

固定提交复验新增失败：模板 199 passed（30.64 秒），Info 389 passed 后
`test_database_lock_timeout_releases_connection_and_recovers` 解除锁后仍为 503，
日志 TimeoutError。查明该旧测试把 50 ms 的故障预算注入整个函数，恢复期也被限制
为 50 ms，而生产值是 2 秒；不把当次几十毫秒延迟的内部来源擅自归咎于 OS/驱动。
串行复验立即停在 Info，没有继续 Knowledge/Investment。

模板先加恢复期合成 Redis 100 ms 正常慢响应（仍跑真实 PG），在旧注入范围下得到
**1 failed（0.99 秒），同一恢复断言 503 != 200**。随后将 50 ms 注入仅包住持锁
故障阶段，原立即恢复和 100 ms 慢响应两例都通过，模板初次修正后 200 passed
（31.51 秒）。这段延迟用于制造确定性红例，不是睡眠等待真实锁/竞态自己恢复；正式
代码和 2 秒预算未动，恢复期另有显式预算回归断言。
同类检查再收窄只读观测 statement-timeout 测试的 5 秒放宽预算，防止恢复期继续使用
非正式预算；30 ms Redis 负例本来没有恢复阶段，保持不变。两份共享测试修复重新在
模板最终提交上过全量后才串行实例；不把失败前的 HTTP 提交宣称最终已验证。

## 3. 固定源码与门禁

HTTP 首轮严格按模板→Info→Knowledge→Investment 完整验证，三个实例领域路由和
observer 保留。HTTP 部分模板/Info 各 6 文件；Knowledge/Investment 各 5 文件；
随后四仓另各修两份共享测试的故障范围。不动 models、migrations、
配置绑定、依赖、Worker/Scheduler、镜像或部署清单。

| 后端仓 | HTTP 首轮本地提交 | 首轮全量 | 该提交复验 |
| --- | --- | --- | --- |
| tpl-backend | `c66654a591b186ac814cadb907defc421e94aba6` | 199 passed，31.10 秒 | 199 passed，30.64 秒 |
| info-backend | `da870e0f1fa243d5b06e4de7b28a5c7d86a85c46` | 444 passed，59.94 秒 | 389 passed / 1 failed，45.85 秒；见上述根因 |
| knowledge-backend | `b786a2ca54e891330d642cd5c7984270c9848e94` | 359 passed，50.17 秒 | 因 Info 失败未继续 |
| investment-backend | `3b6c215fd80cc66057ea82bb762fd02fc42da30b` | 342 passed，55.48 秒 | 因 Info 失败未继续 |

首轮共 1,344 passed，四仓均零跳过且 Ruff/Pyright 通过。每仓新增 24 个 HTTP 参数化
用例；模板/Info 另各以 1 个已接线正向用例替代 2 个旧休眠参数例，所以合计净增 94。
各仓公共用例会重复运行，不宣称是 1,344 种互不相同场景。

最终检查点（包含上述 HTTP 提交和测试注入范围修复，逐仓提交后跑全量）：

| 后端仓 | 最终本地提交 | 完整门禁 |
| --- | --- | --- |
| tpl-backend | `cd89d1ffab432325c48be8c1a0af36927c58d3d6` | 200 passed，31.22 秒；Ruff/Pyright 通过 |
| info-backend | `a9f0d7b262e00b39b163c69dbaf39d2966679478` | 445 passed，61.77 秒；Ruff/Pyright 通过 |
| knowledge-backend | `ffc88f94d2dcfec728eef43a668f8c8756453e84` | 360 passed，50.81 秒；Ruff/Pyright 通过 |
| investment-backend | `681256f5c39941cfc7573b44a2e3702f0f7eaeb1` | 343 passed，56.40 秒；Ruff/Pyright 通过 |

最终合计 **1,348 passed / 0 skipped**，严格串行、均在上列固定提交上运行。
新增正常慢响应恢复参数例每仓多 1 项；超时泄漏根因已修复，不留“重跑绿了就算”的结论。

五份公共文件在四仓的 SHA-256 已逐字复核一致：

| 文件（后端根相对路径） | SHA-256 |
| --- | --- |
| `app/app/interfaces/http/internal/delivery_metrics.py` | `cf49ab553a5da334e048504a1267d6466a8cfa44c90c3e0463f2560e51f4c059` |
| `app/tests/test_delivery_metrics_http.py` | `6c5315f47ca1d04ba75b207f144a28bd89c895a926756348402db8c38e41744a` |
| `docs/delivery-observation.md` | `c511e1f0a6420edf52335e1ed4dc4cfec8b077dc55b9948ce46c6400c8e9ccca` |
| `app/tests/test_schema_readiness.py` | `cf57a6a1b694d5fec86a1b338331d10508bd1d1e4ec969a69b930162052ebb55` |
| `app/tests/test_delivery_observation.py` | `85f1470c68598c24e665b647860c14074cc25def3ec1986a09a7e3b066c64e47` |

模板父仓部署脚手架 8 项 unittest 另通过（0.211 秒）；没有执行 apply 的集群部署门禁，
不能把渲染/配置单测当运行态验收。

测试资源是仅回环暴露、有限内存的 B7h PG/RabbitMQ/MinIO/Redis 容器；使用合成凭据，
不挂业务卷，PG 库名为 `backlog_tests`，各测试自建/清理随机 schema。
最终按创建时完整容器 ID 再核名称/挂载后 stop、rm -v：PG `5968e2aa398e…`、
RabbitMQ `dff7ebb06ed2…`、MinIO `877a3a61b58e…`、Redis `1fc01f8c0a57…`。
四容器及本次自动生成的四个匿名卷已清理，只有可重建合成数据；Docker 镜像保留。
`docker ps -a` 复核只剩原三个 KIND 节点和原有三个月前退出的容器，未清理任何旧资源。
未更新四个父仓 gitlink，增量对齐报告仍留在 Luna 工作区等待最终统一集成。

## 4. 实际环境的只读发现与未关闭项

本机默认 kubectl 没有 current-context，直接查询退到 localhost:8080 被拒绝；这不是
集群故障证据。后续显式使用已确认存在的 `kind` 配置只读查询成功，没有写用户
kubeconfig 或输出凭据。2026-09-13 本次 Deployment/StatefulSet/DaemonSet 清单中
有 Flower、pgAdmin、RedisInsight，未见 Prometheus/Alertmanager；不推断外部环境
一定没有监控。没有部署新采集器、应用配置或 Secret。

当前三 App API/Worker/Scheduler Deployment 的镜像声明（不等于本包运行验收）：

| App | 后端镜像 digest |
| --- | --- |
| Info | `884dc222c2c7c3fc86787592ec03a5bb306a44a8bf069df10e3c9ed38806f1b9` |
| Knowledge | `36bc1dd6ac4631339070d29825f16373aa65a1f9fe65385d0f90a4564f87af17` |
| Investment | `6a30e2d50eb47735ba8cf449fb776a5d1c848d84311c7e4ce69e99ab8719a434` |

各 App 的三个角色声明相同镜像、API 2 副本，Worker/Scheduler 各 1；不能据 ready 副本数
推出业务进展。以上是 workload spec，不是 Pod 实际 imageID 或源码→镜像 provenance。
后续采集必须标记 App：同一 App 多个 API 实例扫描同一账本，不能把副本 gauge 直接
相加重复计数；采集目标/去重策略在正式作业中明确。鉴权、刷新、网络、失败与新鲜度
也必须整链验证，快照采用 DB 时间，未来时间戳/时钟偏差不能误当“最新”。

仍未关闭：采集主体及周期、真实采集/断采/凭据撤销、告警阈值及实际到达接收者、broker
queue 指标、Worker 真实消费进展、Scheduler 活性、保留/归档和其余环境门禁；B8
新计划接收也未完成。已询问所有者告警接收渠道，未擅自发消息或安装监控平台。
本包只关闭“受保护 HTTP 指标入口的源码缺口”，不把 B7 整体打勾。
