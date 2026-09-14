<!-- I08-001 -->
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

> 交接 / 当前工作游标｜S6→S0/S3。先列截至原日期的就位能力和游标，再列未决输入，最后聚合风险与验证债；接手者能知道下一步为何被挡。
>
> 2026-09-14 按 [dev-plan-architecture.md](dev-plan-architecture.md) 第八节从 `1d0adde3` 迁入。每节前的 `<!-- Ixx-xxx -->` 是安置表 ID，冻结原文用 architecture 的 `show` 取。

## 当前观察与游标

状态是带时点的观察，不能写成保证现在仍具备的能力；不据此修改 PRD。

<!-- I08-002 -->
### 当前阶段

**一 · 前后端对接。**

阶段二（agent 开发）与阶段三（问数）尚未开工，见
[`development-plan.md`](development-plan.md)。

<!-- I08-003 -->
### 已经就位的（不用再做）

| | 状态 | 取证 |
| --- | --- | --- |
| web 面 7 条路由 | 已存在 | `/api/web/v1/runs` `…/{id}` `…/events` `…/actions` `…/cancel` `…/citations/{id}/source` `…/reference/sources/{id}` |
| internal 面 5 条路由 | 已存在，Pilot 链路在跑 | `/api/internal/v1/investment/runs` `…/{id}` `…/commands` `…/events` `…/citations/{id}/source` |
| 前端栈 | 八个前端 Next.js 16.2.2 + React 19.2.4 | `package.json` |
| 四本账之幂等、副作用 | 已落表并接线 | `idempotency_key`、`tool_side_effects` |

<!-- I08-010 -->
### 任务游标

**阶段一未开工**——U1 未定，[`implementation-plan.md`](implementation-plan.md)
的任务清单为空。

## 未决及开工输入

U1–U5、已知材料、文档待办和未处置批准问题是待判输入；未决不是自动选了某方案。

<!-- I08-004 -->
### 未决项

**每项定下来之前不要开工依赖它的部分。**

| # | 未决 | 阶段 | 为什么它卡着别的 |
| --- | --- | --- | --- |
| **U1** | **web 面生产适配器的形状**：薄转发（web → internal 面），还是自己持有会话与投影？ | 一 | 决定 v5 §10.2 事务原则与 §10.3 SSE 对账落在哪一层 |
| U2 | 执行层 Port 的接口形状 | 二 | 决定纪律层怎么被测试。cursor 提案见 `~/codex-reference-archive/cursor/investment-agent-architecture-cursor.md` §3 |
| U3 | **预算账与证据账**落 PG 的表结构与迁移 | 二 | 一切并行工作的前置——没有预算闸门就不能 fan-out |
| U4 | `AgentProfile` 的具体字段 | 二 | 专用部分的载体 |
| U5 | 外部 harness 的部署形态（服务端如何管理其进程与凭据） | 二 | 影响 U2。本分支提案见同一可行性文 §2 / §9 |

<!-- I08-005 -->
#### U1 的已知输入

- 规则 **I1**：接口分面共享 application 用例，不是三套应用层
- 规则 **I4**：Next.js 可做同源 BFF / session 边界，但不得拥有领域数据
- 规则 **I5**：授权分工必须有显式契约；**不信任任何上游声明的身份**
- 两扇门的身份不同：internal 面认服务令牌 + `X-Delegated-Actor-ID` 头声明的用户；
  web 面**不能信浏览器的声明**，必须从会话取
- 现成参照：`ReferenceWebInteractionAdapter` 的 `_authorize`

<!-- I08-006 -->
#### U3 的已知输入

- 现有 `RunBudget` 在 `domain/agent/runtime.py`，是**内存态 pydantic model**，
  随 graph state 传递，进程一死即失——**载体要换，不是接线**
- 唯一消费者 `first_m1_graph` 只被 `scripts/agent_golden.py` 与一个 golden 测试用到
- 生产链路 `pilot_service` 只有一行 `budget_exceeded → failed` 状态映射
- 字段可沿用：steps / tool_calls / llm_calls / input_tokens 的上限与已用量

<!-- I08-007 -->
#### U4 的已知输入

- `AgentProfile` 已存在于 `domain/agent/profiles.py`，已有两个实例
  （`default_research`、`literature_review`）
- **但 Profile 目前不生效**：`RunService.create_run` 解析并把 key/version 写进
  run 行，`dispatch_agent_graph` 只传 run_id / user_input / security_context，
  两条生产图对 `allowed_tools` 等的引用数为 0。**它现在是审计字段，不是约束**
- `mooc-manus-langgraph-longterm-plan-v4.md` §20 有一份 102 行的结构可作输入

<!-- I08-013 -->
### 不能倒退的两条（本轮新增）

- **H5 未分层**：所有者五次执行 `publish-*.sh` 写主线，都是 H5 管辖的 Side Effect 但未经 H5 门。
  建议拆 `H5-final` / `H5-round`，见 `rounds/runtime/runtime-disposition.md` §L.1。
- **⑥ 确认的回执强度为零**：全流程唯一不可逆的一步，其回执恰恰最不可验证（`rulings.md` `R2`）。

## 跨阶段风险与未验证

风险表与执行器未验证清单要在派工前可见，不能仅存在于历史审计中。

<!-- I02-087 -->
### 风险和未决

**逐条登记，每条带处置。**只写「有风险」而不写「现在怎么办、什么条件下才动」的清单，
下一轮没人知道该不该碰它。

| # | 事项 | 状态与处置 |
| --- | --- | --- |
| 1 | Agent Profile 的实际模型、GUI 内部事件与部分 CLI 工具事件不可机械核验 | ⚠ 未验证；登记表相应字段标 ⚠，**不得用未核值反推能力** |
| 2 | 无进程入口的分发者永久需要人工桥 | 登记为**可计数的欠账**（`dispatch_event{mode=manual}`），**不伪装成自动化** |
| 3 | principal 确认与 agent 共享宿主身份 | 证据只能标 `reported`；身份边界未落地前不得写成 `attested` |
| 4 | **H5-final / H5-round 拆分**：轮内产物写主线的管辖 | 未决；已由前轮登记，**本文不擅自改权力表行数** |
| 5 | **H5 的机制化强制点** | 两个有效方向均需所有者动作；现状登记为「人的显式动作」 |
| 6 | **响应者身份鉴别**（Interaction 服务化的前置） | 未决；**信任域收紧前不拆** |
| 7 | typed review／ruling／acceptance 是否只是 Artifact 类型细化 | 未决；若属对内核 Attempt 定义的扩充，按内核修订纪律另起工作单元 |
| 8 | **结构化修订（部分否定／替代）的规范形状** | 未决；**必须用库原语构造**，不得反推平台级 patch 协议 |
| 9 | `retroactive` 登记与内核 `I1`「原始输入不被后续解释覆盖」的关系 | 未验证；建单时一并核 |
| 10 | 独立性按 `harness` 或 `(harness, model)` 分组 | ⚠ 无跨题数据；**只能作观察值**，由「候选相似度」校验后再定 |
| 11 | **T0 的「可逆出口」**（只落 worktree、免 H5） | 未决；属**省事方向**的新权力表行，须有签名次数数据后再议 |
| 12 | **「命中任一条即 T2」中「权威层」覆盖面过宽** | 判据属流程规范，改它由该规范自己的轮次处理 |
| 13 | **触点疲劳导致盖章化** | 观察值：回执耗时、相对预填的改动项数、每类触点次数；**不设自动动作** |
| 14 | **单 principal 阶段的权力表在多用户场景是否够用** | 表结构已按 principal 设计；capability 列等出现第二个 principal 再加 |
| 15 | **三值路由初期大量 `ask`** | 预期行为；每次 `ask` 的人工选择按「裁量是规则的孵化器」反哺规则表 |
| 16 | 内核演化冲击本文 | 三条：按 commit 引用内核、内核改动按最重档、改后重跑状态词比对 |
| 17 | **`QUEUED` / `RUNNING` 在事件落地前不可判** | 已声明；脚本合并显示并标 ⚠ |
| 18 | **H1 与 H5 落在同一 commit 时账本上的歧义** | 未决（服务态应是两个 Interaction；手工态今天做不到） |
| 19 | 运行时外的绕过天然不完备 | principal 侧指标在共享身份下是 `UNKNOWN`，**不得写成零** |
| 20b | **`llm-review` 能否用于任何 `auto_policy = 无` 的权力表行** | 未决。`design/authority-sdd.md`「四档审批」 立了四档审批，但 `llm-review` 不是 principal 的权力，在 `design/authority-sdd.md`「权力表」 权力表里没有行。⚠ **本文不裁**——它要么是 H 行的一个前置过滤器，要么根本不该出现在需人批准的路径上，两种读法后果不同 |
| 20 | 预算账、证据账与 Agent Profile 生效仍是后续工作 | 见 `handoff.md @ ed0b5136:14-19`、`handoff.md @ ed0b5136:30-66` |
| 21 | 历史产物只在单机的可恢复性 | ⚠ 旧稿报告部分产物/冻结标签只在本机；本次未核当前远端。不外推为“现在仍只有一份”，交付前按 `agent-dev-guide.md`「保留与垃圾回收」 核持久 ref/获准副本及重取能力，不以此擅自 push |
| 22 | 库的完整 API 面、多次中断与版本兼容 | ⚠ 历史记录只覆盖若干用法；SDK/库升级前按 `design/evidence-sdd.md`「历史取证怎样用于今天的开发」 重核，不把原地恢复样例推广到未经验证的路线 |

<!-- I02-089 -->
### 执行器架构的未验证清单

⚠ **`design/executor-sdd.md`「执行层：租用什么、自建什么」至「双 runtime 的部署、进程与恢复」 描述的执行层，在本清单清空之前一律按 `defined` 对待**（`design/evidence-sdd.md`「上下文路由与能力四级词典」 四级词典）。
本节只登记「未验证」；「已知不支持」在 `design/executor-sdd.md`「`F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵」 矩阵里，两者不可混。

| # | 未验证的事 | 位置 | 验证方式 |
| --- | --- | --- | --- |
| 1 | 两条执行腿的部署门禁与 Harness wire 门禁**均无运行证据** | `design/executor-sdd.md`「执行层：租用什么、自建什么」、`design/executor-sdd.md`「Harness 腿的前置门禁与过渡补法」 | Gate 0 spike |
| 2 | 「租用 loop、自建控制面」的硬条件全部未实证 | `design/executor-sdd.md`「执行层：租用什么、自建什么」 | Gate 0 spike，逐条给退出判定 |
| 3 | Harness sdk-runtime wheel 能否从**内网 PyPI 镜像**取得 | `design/executor-sdd.md`「两个官方 SDK：两个轴、非对称能力」 系统 Node 行 | 供应链验证，非文档问题 |
| 4 | worker egress 的包级验证**在 KIND 上不成立** | `design/executor-sdd.md`「双 runtime 的部署、进程与恢复」 | 另起 Calico 环境实测 |
| 5 | 双 runtime 峰值内存与 prefork 并发的**实测值** | `design/executor-sdd.md`「双 runtime 的部署、进程与恢复」 | 负载测试后再定 requests/limits |
| 6 | Codex async 客户端在并发/teardown 下的行为 | `design/executor-sdd.md`「双 runtime 的部署、进程与恢复」 | 负载与故障注入，**不得由 `async` 关键字推断** |
| 7 | **未跑过任何 SDK 端到端**、未联调 OpenClaw、未做故障注入 | `design/executor-sdd.md`「执行层：租用什么、自建什么」至「双 runtime 的部署、进程与恢复」 全部 | Gate 0 |
| 8 | 多租户配额的产品语义尚未设计 | 本条即登记 | 属产品契约侧 |

⚠ **本清单不是免责声明。**它的用途是：读到 `design/executor-sdd.md`「执行层：租用什么、自建什么」至「双 runtime 的部署、进程与恢复」 任何一节时，能立刻判断那一节是
`defined` 还是 `runtime-verified`。**清单为空之前，那五节描述的是目标形状，不是现状。**
