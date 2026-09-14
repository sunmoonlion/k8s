# 实施计划

> 迁自 [`dev-plan/implementation-plan.md`](../../dev-plan/implementation-plan.md) 的以下各节（`49d4ecb7`，2026-09-14）。节号沿用原文件；原文件其余各节的去向见 [MIGRATION.md](../MIGRATION.md)。

> 最后更新：2026-08-29
>
> **这里是任务本体：每件事怎么做、怎么算做完。**
>
> 现在到哪了、什么不能倒退，见 [`handoff.md`](../../dev-plan/handoff.md)；
> 为什么这么建见 [`development-plan.md`](../components/backend/composition/development-plan.md)；
> 代码必须符合的规则见 [`constraints.md`](../../dev-plan/constraints.md)。

## 测试层次

```
L1 Unit                    L5 Failure Injection
L2 Component Integration   L6 Evaluation/Quality
L3 Contract                L7 Deployment/Operations
L4 Cross-app E2E
```

P0 / P1 任务必须写明适用层次。

## 后续运维接收 · N4-OPS-01 监控采集与告警送达

2026-09-13 所有者要求：“那你把它放到未来的dev-plan吧。继续”。本条接收
[v5 处置清单](../../v5-backlog-disposition-luna.md)中监控部署与告警接线的后续工作，
不代表全部 N4/B8 已接收，也不把未部署能力写成已验收；其余旧任务继续按原清单处置。

| 栏 | 内容 |
| --- | --- |
| 类型/优先级 | OPS / P1；未来实施，本轮不安装、不发通知 |
| 仓库 | k8s 为监控部署与规则主载体；tpl-app 提供公共受保护观测能力，按模板优先、Info → Knowledge → Investment 串行同步；四 App 仅在接线确需代码/配置变化时修改，不跨域读库 |
| 前置 | 实施前冻结目标环境、资源/存储预算、采集周期/保留期、负责人、告警阈值与通知接收渠道；核对是否已有可复用监控，确定受保护指标接口的精确服务身份、令牌更新和网络策略；按授权批准部署对象及回滚 |
| 目标 | 从真实指标采集到故障触发、通知到达和恢复解除形成可复验链路，不靠人持续盯日志 |
| 实施 | 分阶段配置 Prometheus 采集/规则，再配置 Alertmanager 路由、去重/分组/静默和批准的接收端；复用 delivery HTTP 指标，补 scrape 失败/数据缺失与新鲜度、broker queue 及已交付角色观测的采集适配；配置资源限额、保留/存储和最小权限，不新增业务主档或开放匿名指标 |
| 测试 | L1 规则正反例；L2 身份/采集失败与恢复；L5 停采、过期、队列积压等受控故障及通知失败；L7 在获准环境验证组件、规则加载、接收端回执和恢复通知。数据与通知用明确合成标识，禁止擅自向真实接收人发送 |
| 验收 | 采集身份越权被拒；正常采集有新鲜度证据；缺失/失败不能显示为健康零值；同一 App 多 API 副本的同一数据库 gauge 不重复求和；规则按冻结窗口触发并恢复；Alertmanager 能分组去重及按批准策略恢复通知；“已送达”必须有接收端时间/合成告警 ID 对应证据，页面 firing 或发送请求成功不能替代；保存去敏配置、版本和复验步骤 |
| 回滚 | 恢复前版采集/规则/通知路由，或停用本任务新增资源；不删除业务账本或指标历史卷。通知测试前设停止条件与精确静默范围，故障时停止测试通知；不因采集故障自动重启业务角色 |
| 状态 | NOT_STARTED · 2026-09-13：已接收进入未来计划，尚未部署/接线/送达验收；组件安装和外部通知不在本轮授权内 |

已有输入：[B7d 只读账本指标](../../v5-backlog-delivery-observation-luna.md)、
[B7h 受保护 HTTP 入口](../../v5-backlog-metrics-http-luna.md)。这些源码和测试证据
不等于当前镜像已含修复。Worker 消费进展、Scheduler 本机活动及安全探针语义仍由 B7
继续补齐，不因本条迁入而销账。监控是部署适配，不将 Kubernetes 或 Prometheus
变成未来 Electron/本机 Agent 内核的强依赖；云端先交付但架构始终兼容本机。

## 阶段一 · 前后端对接

### 任务清单

**空。**U1（web 面生产适配器的形状）未定——薄转发还是自持投影，决定了要写
什么、测什么、有没有迁移。现在列出来的任何任务都会作废。

U1 一定，本节即刻填充。U1 的已知输入见 [`handoff.md`](../../dev-plan/handoff.md)。

## 阶段二 · agent 开发

未开工。见 [`development-plan.md`](development-plan.md)。

## 阶段三 · 结构化数据问答

未开工，且有一个开工前置：投资仓现在没有任何业务数据表。
见 [`development-plan.md`](development-plan.md)。
