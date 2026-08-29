# 实施计划

> 最后更新：2026-08-29
>
> **这里回答"现在做什么、卡在哪"。**为什么这么建见
> [`development-plan.md`](development-plan.md)；代码必须符合的规则见
> [`constraints.md`](constraints.md)。
>
> **本文件写状态，且只写状态。**任何"应该怎样"的论证不写在这里。

## 当前阶段

**一 · 前后端对接。**

阶段二（agent 开发）与阶段三（问数）尚未开工，见
[`development-plan.md`](development-plan.md)。

## 已经就位的（不用再做）

| | 状态 | 取证 |
| --- | --- | --- |
| web 面 7 条路由 | 已存在 | `/api/web/v1/runs` `…/{id}` `…/events` `…/actions` `…/cancel` `…/citations/{id}/source` `…/reference/sources/{id}` |
| internal 面 5 条路由 | 已存在，Pilot 链路在跑 | `/api/internal/v1/investment/runs` `…/{id}` `…/commands` `…/events` `…/citations/{id}/source` |
| 前端栈 | 八个前端 Next.js 16.2.2 + React 19.2.4 | `package.json` |
| 四本账之幂等、副作用 | 已落表并接线 | `idempotency_key`、`tool_side_effects` |

## 未决项

**每项定下来之前不要开工依赖它的部分。**

| # | 未决 | 阶段 | 为什么它卡着别的 |
| --- | --- | --- | --- |
| **U1** | **web 面生产适配器的形状**：薄转发（web → internal 面），还是自己持有会话与投影？ | 一 | 决定 v5 §10.2 事务原则与 §10.3 SSE 对账落在哪一层 |
| U2 | 执行层 Port 的接口形状 | 二 | 决定纪律层怎么被测试 |
| U3 | **预算账与证据账**落 PG 的表结构与迁移 | 二 | 一切并行工作的前置——没有预算闸门就不能 fan-out |
| U4 | `AgentProfile` 的具体字段 | 二 | 专用部分的载体 |
| U5 | 外部 harness 的部署形态（服务端如何管理其进程与凭据） | 二 | 影响 U2 |

### U1 的已知输入

- 规则 **I1**：接口分面共享 application 用例，不是三套应用层
- 规则 **I4**：Next.js 可做同源 BFF / session 边界，但不得拥有领域数据
- 规则 **I5**：授权分工必须有显式契约；**不信任任何上游声明的身份**
- 两扇门的身份不同：internal 面认服务令牌 + `X-Delegated-Actor-ID` 头声明的用户；
  web 面**不能信浏览器的声明**，必须从会话取
- 现成参照：`ReferenceWebInteractionAdapter` 的 `_authorize`

### U3 的已知输入

- 现有 `RunBudget` 在 `domain/agent/runtime.py`，是**内存态 pydantic model**，
  随 graph state 传递，进程一死即失——**载体要换，不是接线**
- 唯一消费者 `first_m1_graph` 只被 `scripts/agent_golden.py` 与一个 golden 测试用到
- 生产链路 `pilot_service` 只有一行 `budget_exceeded → failed` 状态映射
- 字段可沿用：steps / tool_calls / llm_calls / input_tokens 的上限与已用量

### U4 的已知输入

- `AgentProfile` 已存在于 `domain/agent/profiles.py`，已有两个实例
  （`default_research`、`literature_review`）
- **但 Profile 目前不生效**：`RunService.create_run` 解析并把 key/version 写进
  run 行，`dispatch_agent_graph` 只传 run_id / user_input / security_context，
  两条生产图对 `allowed_tools` 等的引用数为 0。**它现在是审计字段，不是约束**
- `mooc-manus-langgraph-longterm-plan-v4.md` §20 有一份 102 行的结构可作输入

## 阶段一的任务

**U1 定下来之前不列任务。**适配器是薄转发还是自持投影，决定了要写什么、
测什么、有没有迁移——现在列出来的任何任务都会作废。

U1 一定，本节即刻填充。
