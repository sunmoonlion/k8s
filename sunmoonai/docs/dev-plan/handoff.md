# 交接

> 最后更新：2026-08-29
>
> **接手先读这份。**它回答"现在到哪了、什么不能倒退、卡在哪"。
>
> 要建什么见 [`development-plan.md`](development-plan.md)；
> 具体任务见 [`implementation-plan.md`](implementation-plan.md)；
> 代码必须符合的规则见 [`constraints.md`](constraints.md)。
>
> **本文件只写状态。**任何"应该怎样"的论证不写在这里，
> 任何任务的实施步骤也不写在这里。

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
| U2 | 执行层 Port 的接口形状 | 二 | 决定纪律层怎么被测试。本分支提案见 [`investment-agent-architecture-cursor.md`](investment-agent-architecture-cursor.md) §3 |
| U3 | **预算账与证据账**落 PG 的表结构与迁移 | 二 | 一切并行工作的前置——没有预算闸门就不能 fan-out |
| U4 | `AgentProfile` 的具体字段 | 二 | 专用部分的载体 |
| U5 | 外部 harness 的部署形态（服务端如何管理其进程与凭据） | 二 | 影响 U2。本分支提案见同一可行性文 §2 / §9 |

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

## 不能倒退的输入

以下已经定了，接手时**不要重新讨论**：

| | 结论 | 定于 |
| --- | --- | --- |
| 施工顺序 | 前后端对接 → agent 开发 → 问数 | 2026-08-29 |
| 问数的位置 | 专用智能体的一个实例（加一份 Profile + 一个工具），不是另一套架构 | 2026-08-29 |
| SQLBot / WrenAI | **参考资料，不是选型候选** | 2026-08-29 |
| v5 的地位 | 历史设计输入；其 §10 前后端对接仍有效且详尽，做阶段一时逐节引用 | 2026-08-29 |
| 四本账 | 幂等、副作用已接线；缺预算与证据 | 取证于 2026-08-29 |

## 文档面待办

评审吸收后留下的两项。**登记在这里,不在评审目录里**——那种目录用完就删，
写在里面等于没登记。

| # | 事项 | 验收条件 |
| --- | --- | --- |
| **D1** | 压缩总览与仓页/主题页的重复：同一事实**只在一处展开**，总览改为结论 + 指针 | 逐项检查总览 §5–§9 与 `repos/` `topics/` 无同型重复；判据用提出方给的：同一事实只在一处展开 |
| **D2** | 给"为什么"类内容独立去向：平台禁令、依赖方向等已进总览 §4.1，但四类"为什么"仍无统一载体 | 明确每类"为什么"落在投影、`development-plan.md` 还是拒绝写入，并各给一条理由 |

来源：luna B7 / B8。本轮判定为**不在本轮做**——总览刚净增 §4.1 / §8.1 / §8.2
三节（都是评审要求补的），此时压缩会与刚吸收的内容打架。

## 任务游标

**阶段一未开工**——U1 未定，[`implementation-plan.md`](implementation-plan.md)
的任务清单为空。
