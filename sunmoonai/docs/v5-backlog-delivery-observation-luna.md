# B7d：存量投递只读观测

2026-09-13；所有者原话“继续”，沿用单人 Luna 逐包实施与同步授权。

## 冻结范围与基线

两端 master/Luna 父仓已核对一致，云端干净；本地只有两份预置未跟踪协议草稿。
父仓 tpl@5487755、Info@253869f、Knowledge@dd8c7ff、Investment@6d6b014、k8s@9f480fa9。
后端 tpl@ed8d5dc、Info@d607d8e、Knowledge@40edfc2、Investment@85f8cb7。

本包处理旧 M1-105/M1-503 的存量投递观测基础：只读快照、CLI JSON/Prometheus text 输出、
测试、模板实例对齐和文档。暂不增加 HTTP 暴露面、scrape 部署、告警接收器或新鉴权方案。
Worker/Scheduler 的主动消费/周期活性探针、正式采集接线及归档仍在 B7，不能以指标为零
宣称 healthy，也不能将剩余旧账直接转入新产品计划。

| 规则 | 处置 |
| --- | --- |
| D1/D2/D8 | 从本 App 现有 Outbox/Inbox/租约/死信读快照，无第二状态表、无迁移、无启动写入 |
| C1/C2 | 不 claim/reconcile/replay；只复用既有 delivery policy 的 topic→consumer 和租约查询扩展 |
| C3/C4 | 不改变跨 App DTO；按四仓全量与共享契约门禁验证 |
| I1/I3/I8 | 仅本机 CLI，经现有 Settings/DB principal；只读事务与超时，不授权浏览器或暴露无鉴权端点 |
| R6/T3/T4/T5 | 模板固定提交门禁后，严格串行 Info→Knowledge→Investment；子仓先推，父仓快进与同步 |
| R1–R5/R7 | 不操作业务数据/Secret/镜像/部署，不改发布版本、bundle 或 release |

策略：公共观测器不依赖领域；显式 extension point 装配现有 DurableTasks，Investment
另装配实际 AgentDelivery，保留 agent.executor 与无业务 Inbox 的 notification 语义。
未知 topic 只输出聚合数量，不把 DB 字符串提升为无限标签；只输出计数、年龄和静态标签，
不输出消息 ID、用户、payload、错误正文或凭据。存量计数全部为 gauge，不伪装累计 counter。
只读 REPEATABLE READ、语句超时与整体取消预算；失败明确报错，不输出假零或半份快照。

硬门禁：真实 PG 的空库、已注册空 topic、未注册 topic、pending/延迟/发布/完成/死信/重放、
正确 consumer、公共与 Agent 租约、旧发布时间但仍在执行、故障/锁超时/取消与恢复；
只 SELECT/事务配置，表内容不变；CLI 安全错误与文本格式；四仓完整回归，禁止跳过冒充通过。
临时 PG/S3/Redis 只使用隔离容器和合成数据，结束后核精确 ID 清理。

## 固定源码验收

按模板→Info→Knowledge→Investment 串行通过，全部 Ruff/Pyright 通过。

| 后端 | 固定提交 | 完整回归 | 时间 |
| --- | --- | --- | --- |
| tpl-backend | `1f8941f66d8251aa49fb57ed3c45a3e9c68281f0` | 131 passed / 0 skipped | 13.46 秒 |
| info-backend | `9ea1c5ed05a4d825ce696ead2bda55fcf3f192a5` | 375 passed / 0 skipped | 41.51 秒 |
| knowledge-backend | `d16fb6cedfd36c3a405e515f571fdc66b1a9fd2a` | 286 passed / 0 skipped | 31.00 秒 |
| investment-backend | `7113e528bce0d69eed6f2ca46ad85abf5f18abc7` | 269 passed / 0 skipped | 30.52 秒 |

合计 1061 项（包含各仓重复的公共场景，并非 1061 种不同场景）。每仓新增 24 个公共
用例，Investment 另有 3 个领域用例。模板、Info、Knowledge 各 5 文件，Investment 6 文件；
CLI、聚合器、公共测试、说明四文件的 SHA-256 四仓逐字一致。第五个 observer 工厂在
前三仓相同，Investment 仅加领域实例；三个父仓各补本包模板增量对齐报告。

真实 PostgreSQL 只读事务验证，包括通过 SQL 函数偷偷 UPDATE 也被 DB 拒绝；专用角色
只有表 SELECT/Schema USAGE 可读，撤销即失败；表锁分别触发外层取消预算与服务器
statement_timeout，恢复后可再次读取。投递表内容不变；实际 claim/publish/consume/
reconcile/replay 仅用于合成测试准备，观测器本身不调用任何写路径。
正确 consumer、重放、delayed/backoff、活跃/过期租约、非法 header、未知 topic/有界标签、
静态注册及完整 CLI 输出/安全错误均测试；Investment 确认真实 Agent 租约和通知语义。
原全量含一次性 S3/Redis、契约向量和既有故障恢复；无实际业务 Provider 或身份验收。

文本格式据 [Prometheus 官方说明](https://prometheus.io/docs/instrumenting/exposition_formats/)
实现 gauge 家族、TYPE 在样本前、唯一静态标签和末尾换行；本包是 CLI 文本输出，
未运行 Prometheus server/promtool 或完成采集接线。输出包含快照起始 DB 时间，过期
判断与采集失败清除需要采集端落地，不能把旧文本当成功新采集。

## 失败记录与仍未验收项

首次静态检查发现行宽和 dict 泛型不变性，改排版及只读 Mapping 类型；首次文本单测
误把 HELP 内的 “counter” 说明当 TYPE counter，改为精确验证 TYPE 行，没有放宽格式要求。
Knowledge 首轮全量在重放后 publishable 计数预期 1、实际 0 处失败；停止串行推进。
单独复跑、150 次重放场景和 100 次原用例未复现；保持源码/断言不变，两次全量复跑
286 passed（30.91/31.00 秒）后才推进 Investment。根因未确定；与 B7c 抓取取消
consume=False 是否相关也未知，作为 B7 运行活性复核线索保留，不标为已修复。

仍未建立业务监控采集或角色健康证明；没有删除业务归档。后续 B7 需接线采集/新鲜度/
告警、Worker 队列匹配与实际消费、Scheduler 周期活性、归档引用闭包/重放窗/恢复和
其余实际环境门禁；未将这些旧账塞进未来 Agent 产品指标冒充处理完成。
B8/N1～N6 正式接收尚未完成。当前进入子仓先推、父仓锁定、master 快进及两端同步。
