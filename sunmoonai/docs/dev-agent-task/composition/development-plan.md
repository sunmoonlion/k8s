# 开发计划

> 迁自 `dev-plan/development-plan.md`（tag `dev-plan-final`） 的以下各节（`49d4ecb7`，2026-09-14）。节号沿用原文件；原文件其余各节的去向见 MIGRATION.md（2026-09-15 删除，原文见提交 `e7ab0e0b`）。

> 最后更新：2026-08-29
>
> **这里回答"要建什么、为什么这么建"。**
> 任务书见 [`task.md`](../task.md)，
> 进度见 [`log.md`](../log.md)，
> 代码必须符合的规则见 [`constraints.md`](constraints.md)。

## 三个阶段

**一 前后端对接 → 二 agent 开发 → 三 问数。**

### 一 · 前后端对接

**缺口是确切的：两边路由已经对称，缺中间那个适配器。**

```
浏览器 → /api/web/v1/runs …（7 条，已存在）
              ↓
      WebInteractionPort ← 只有两个实现，都不能用于生产
              ↓
      /api/internal/v1/investment/runs …（5 条，已存在，Pilot 链路在跑）
```

| 实现 | 状态 |
| --- | --- |
| `UnavailableWebInteractionAdapter` | 生产默认，一律 **503** |
| `ReferenceWebInteractionAdapter` | 确定性夹具，**生产配置明令拒绝**（检出 `REFERENCE_INTERACTION_ENABLED` 为真即拒绝启动） |

即：**web 面没有任何生产实现**，四个仓都是这个状态。

前端栈不是缺口：八个前端均 Next.js 16.2.2 + React 19.2.4，与 v5 §10.10 的
目标态一致（唯一差异：v5 要求 Admin 用 Ant Design 6，实际未引入）。

做这一阶段时逐节引用 v5 §10：§10.1 对象边界 · §10.2 事务原则 · §10.3 SSE 对账 ·
§10.4 前端 API 边界 · §10.5 Web 交互状态机 · §10.7 安全与隐私 · §10.9 观测与测试。

**§10.4 的 BFF 问题仍然开放**，别当它已被否决：Next.js 可以承担浏览器同源
BFF / session 边界，但不得成为领域数据所有者；且授权分工必须有显式契约
（规则 I4、I5）。用不用 BFF 是这一阶段要定的事。

### 二 · agent 开发

即上面「智能体分两部分」几节。

**四本账已有两本是真的**，不是从零建四张表：

| 账 | 表 | 生产接线 |
| --- | --- | --- |
| 幂等 | `idempotency_key` | ✅ 8 个源文件在用 |
| 副作用 | `tool_side_effects` | ✅ `tasks/agent_graph.py` 的 `record_once` |
| **预算** | 无 | ❌ 只有内存 `RunBudget`，跨进程即失 |
| **证据** | 无 | ❌ citation 只在事件流里，不落表 |

### 三 · 结构化数据问答（后期）

归**专用部分**——它是专用智能体的一个实例，加一份 Profile 加一个工具，
不是另一套架构。

理由是范围控制，不是能力归属：定位为通用会诱导第一版支持任意数据源与 schema，
在跑通一条真实链路之前先铺抽象。**抽象推迟到第二个领域需要时再做**——
不到第二个用例，不知道通用的边界在哪；提前抽出的"通用"多半是投资的形状
套了通用的名字，比不抽更糟。

**开工前必须先解决一件事：投资仓现在没有任何业务数据表。**13 张表全是运行时
基础设施（agent 运行时 / LangGraph checkpoint / outbox / auth），全仓
`portfolio|holding|ticker|instrument` 命中数为 0。**没有数据就没有问数。**

参考资料在 `~/codex-reference-archive/`（2026-08-29 核）：

| | 现状 |
| --- | --- |
| `sqlbot-opus.md` | SQLBot 是**完整问数应用**，SQL 安全防护默认开启 |
| `wrenai-opus.md` | WrenAI **已转型**为"给 agent 用的语义上下文层"，旧 GenBI 应用冻结在 `legacy-v1` 分支 |

两者不再是同类产品的两个选项。**两份调研都未评估准确率**——真要选型时，
那是核心指标。
