# Codex 源码深挖第二轮：通信协议、预算提醒、压缩、角色与 code-mode（qwen3.8 版）

> 最后更新：2026-08-19
>
> 性质：源码研究增量笔记（个人参考），非 baseline、非 REQ。
> 前置：`codex_dynamic_graph_research-chatgpt.md`（chatgpt 对话记录，§13 三问）与
> `codex-dynamic-graph-findings-kimi.md`（三问的源码答案）。本轮专挖 findings §7
> 列出的三个未竟区——V2 inter-agent 通信协议、RolloutBudget 计量细节、
> 实验性编排机制——外加既有文档都没碰的"无聊 80%"（上下文压缩）与子 Agent
> 角色配置。全部锚点今日亲自 grep/read 核实；源码 = `~/repo/codex`（codex-rs）。
> 提醒：本目录既有文档里的 `~/xxx.md` 路径引用已全部失效（文件都搬进了
> `~/codex-reference/`），引用时加目录前缀。

---

## 0. 前置对话记录的定性（2026-08-22 补）

`codex_dynamic_graph_research-chatgpt.md` **不是"通用任务怎么编排"的操作手册，
是一份对照研究的问题提纲与证伪记录**。我的定性与 chatgpt 版回答一致，补三点
使用纪律：

1. **它最大的产出是证伪不是方案**。核心问题"任意复杂任务为何能在运行时变成
   Task/Agent Graph"（§2）当时被假设成"运行时动态建图"（§3.2 Dynamic Macro
   Graph），随后被源码证伪（§6 update_plan 不是 DAG 引擎、§7 spawn_agent/
   AgentControl 才是机制）——通用性来自通用工具基座 + 模型能力 + 受约束的
   循环，不来自图引擎。这个证伪直接落成了架构决策 D2（不建 DAG 引擎）。
2. **按证据分层读**：§3 是"当时的认识"（L4 级假设，含文章概念如 /orchestrate
   实验性）；§6 起才是源码确证的结论。引用时只引后者，前者当思想史。
3. **正确的阅读链**：research-chatgpt（提出问题）→ findings-kimi（三问的源码
   答案）→ 本文（三个未竟区深挖）→ architecture-qwen3.8（决策收敛）。它是第一环，
   只负责"问题提对"，不负责给答案。

另注：对话是快照，源码是移动靶——它的结论对当时 repo 状态成立，最新锚点以
findings-kimi 与本文为准。

## 1. findings 的锚点抽查：全部为真

先做交叉验证（REQ-002 纪律）：`agent/status.rs:23 is_final`、`control.rs:513
maybe_start_completion_watcher`、`registry.rs SpawnReservation`、
`codex_thread.rs:518 inject_user_message_without_turn`、
`tools/handlers/multi_agents/{spawn,wait,send_input,resume_agent,close_agent}.rs`
五件套——逐一命中，findings 的结论链可信，本轮在其上叠加。

## 2. 增量一：V2 通信协议——push 通道其实可驱动推进（修正 findings §5）

**数据结构**（`protocol/src/protocol.rs:738` `InterAgentCommunication`）：

```text
author: AgentPath          recipient: AgentPath
other_recipients: Vec<AgentPath>
content / encrypted_content（加密通道已预留）
trigger_turn: bool         ← 关键字段
```

消息分四类（`agent_communication.rs:8` `AgentCommunicationKind`）：
Spawn / Message / Followup / Result，并走 OTel 目标
`codex_otel.agent_communication` 记录——**inter-agent 通信在 Codex 里是可观测事件**。

**trigger_turn 的运行时语义**（`agent/control.rs:210-267`、`session/handlers.rs:89-98`）：

- `trigger_turn=true`：先过 `ensure_execution_capacity_for_turn_start` 容量检查，
  携带父/根 turn_id 投递，**直接开启收件方新 Turn**；
- `trigger_turn=false`：进 mailbox 排队（`session/input_queue.rs:79`
  `mailbox_pending_mails: VecDeque`，带 `core.mailbox.pending` 指标），等收件方
  下次 Turn 时投递（`handlers.rs:98`：trigger_turn 或存在 durable sleep 才启动处理）。

**对 findings 的修正**：findings §5"不该移植"第 1 条说 push 通道"注入消息等下次
推理顺便看到"，建议服务端改用事件驱动边。深挖后发现 Codex V2 协议本身就把这做成了
**开关**——完成通知 watcher 用 `trigger_turn=false`（`control.rs:579`）是桌面场景
的选择，不是机制的限制。**investment-app 直接取 `trigger_turn=true` 语义即可**：
run 完成事件 = 带"开启下一节点"语义的结构化消息，不需要另发明事件驱动机制。
协议形态照抄：author/recipient/turn 血缘（对应你的 RunLineage）+ 四类 Kind 直接
映射成 DomainEvent 的编排子类型（Spawn 派单 / Message 指令 / Followup 追问 /
Result 结果）。

## 3. 增量二：RolloutBudget 不是硬闸门，是"全树共享账本 + 提醒阶梯"

源码：`rollout_budget.rs`（核心账本）+ `session/rollout_budget.rs`（投递）+
`config/mod.rs:1184` `RolloutBudgetConfig`。四个此前未知的机制：

1. **全树共享账本**：注释明说 "Shared accounting ... for one root-thread session
   tree"——预算记在**根会话树**上，所有子 Agent 共摊一份。这直接回答 fan-out
   的成本问题：N 路子任务不是 N 份独立预算，是一棵树共享一个总额。
2. **加权计量**：优先用模型返回的 `codex_rollout_budget_units`；否则
   `输出 token × sampling_weight + 非缓存输入 token × prefill_weight`
   （`rollout_budget.rs:50-64`）——推理输出比缓存输入贵，权重分开配。
3. **提醒阶梯**（最重要的移植点）：`reminder_at_remaining_tokens: Vec<i64>`
   （启用预算时**必填**，`config/mod.rs:2776`）。剩余量每跌穿一个阈值，
   `pending_reminder` 产出一条提醒；**每个子线程独立去重**
   （`deliveries: HashMap<ThreadId, ThreadBudgetDelivery>`，按 window_id +
   reminder_index），保证"每个线程都看到每次阈值穿越"；投递标记在**写入历史之后**
   才打（`mark_reminder_delivered` 注释：取消可重试，投递不丢）；`rearm_reminder`
   （`handlers.rs:341`）可强制下次请求重述余额。
4. **软通知 + 硬停止两层**：提醒只是注入上下文让模型知情；真正的闸门是
   `record_usage` 返回耗尽。模型在跌穿阈值时收到"余额 X"的提醒，可以主动
   收敛（砍分支、缩短分析），而不是突然撞墙。

**对 investment-app 的移植**（修正 agent-architecture §4"约束在建 run 时预留检查"
的单一表述——预留制只是入口，运行时还要这两件）：

- RunBudget 加"提醒阶梯"：配置如 `[80%, 50%, 20%]` 三阈值，跌穿时向当前图执行
  注入结构化提醒消息，让分析 agent 优雅降级（跳过可选分支、压缩中间结论），
  而非直接 `budget_exceeded` 终态；
- fan-out 场景建"根预算账本"：Supervisor 派生的 N 个 run 共享一份总额
  （对应你的 Session 或 root run 层级），子 run 各自记份额——否则 N 路 fan-out
  = N 份 120k token 预算，成本失控；
- 投递纪律照抄：提醒写入事件流成功后才标记已投递；resume/重试时重新武装。

## 4. 增量三：上下文压缩（compaction）——investment-app 缺失的"无聊 80%"

既有四份文档都没碰这块，但长 run 的财务分析必然撞上。源码事实：

- 配置三键（`config/mod.rs:582,586,1086`）：`model_auto_compact_token_limit`、
  限额作用域（全量/增量，`AutoCompactTokenLimitScope`）、
  `auto_compact_fallback_buffer_tokens`（配 fallback prompt 时必填）；
- 压缩用独立摘要 prompt（`SUMMARIZATION_PROMPT`，`compact.rs:55,122`，可被
  配置覆盖）；截断**从头部裁**——注释明说"preserve cache (prefix-based) and
  keep recent messages intact"（`compact.rs:311`）：保前缀缓存、保最近消息；
- 有 Pre/PostCompact hook（`hook_runtime`）、完整遥测（trigger/reason/strategy/
  phase/status/implementation，`codex_analytics::CompactionEvent`）、还有远程
  压缩变体（`compact_remote_v2.rs`——摘要可外包给独立服务）；
- 连用户提示都写好了（`compact.rs:390`）："长线程和多次压缩会降低准确性，
  尽可能开新线程"——**压缩是有损的，官方态度是能不开新上下文就不压缩**。

**对 investment-app 的移植**：当前只有 `WindowMemoryPolicy`（session 级最近 20 条），
没有 run 内压缩策略。财务分析 run 会长（多轮取数、证据累积），需要：

1. 阈值触发压缩节点（对齐 `auto_compact_token_limit` 语义）；
2. **领域化摘要模板**：通用摘要会丢财务分析最不能丢的两样——数字与 citation。
   压缩 prompt 必须写明"保留所有数值、SQL、evidence_id，可丢推理过程"；
3. 裁剪从旧到新、保最近（照抄 prefix-cache 友好的方向）；
4. 压缩本身落 DomainEvent（你已有事件溯源，天然满足 Codex 用遥测才能做到的事）；
5. 采纳"能分 run 就不压缩"的态度：Supervisor 拆小 run 优于单 run 硬扛长上下文
   ——这给"何时该 spawn 子任务"加了一条工程判据。

## 5. 增量四：子 Agent 角色 = 声明式 TOML 配置（含一个便宜的 awaiter 模式）

`agent/builtins/`：

- **`awaiter.toml`**（全文已读）：一个专职"等待者"——低 reasoning effort
  （`model_reasoning_effort = "low"`）、长后台超时（3600000ms），指令核心是
  "轮询直到终态，只报告不解释；不许修改任务、不许优化任务、不许幻觉完成；
  超时指数递增"。**用便宜模型干等待这种不需要智能的活**。
- **`explorer.toml` 是空文件（0 字节）**——今日实测 `wc -c` 为 0，占位性质，
  不要引用其内容（写出来防后人踩坑）。
- 角色配置模型（`agent/role.rs:38-42`）：`developer_instructions + model +
  reasoning_effort + reasoning_summary + verbosity` + skills 开关——
  **角色 = 一份配置，不是一段代码**。

**对 investment-app 的移植**：

1. `profiles.py` 已有 `model_key` + allowed/denied tools，扩展成完整角色配置：
   加 instructions 模板与 reasoning 档位。财务域至少三个角色：
   analyst（强模型做分析）/ checker（中模型做校验）/ **awaiter（最便宜模型
   盯长任务：行情拉取、批量回测这类长 job 不该占着贵模型的上下文等）**；
2. awaiter 的指令纪律直接翻译："只等待与报告、不修改任务、超时指数退避、
   禁止幻觉完成"——这四条对财务数据 job 的轮询节点同样成立。

## 6. 增量五：code-mode——第三种编排范式（findings 未覆盖的 B 类机制之一）

研究文档 §12 说"实验性 /orchestrate 需单独研究"。实查结果：本 repo 中与
"orchestrate"相关的活跃机制是 **code-mode**（`codex-rs/code-mode-*` 四 crate）：

- `exec` 工具 = 在**全新 V8 isolate** 里跑 JavaScript 来编排工具调用
  （`code-mode-protocol/src/description.rs:15` 起）；所有嵌套工具挂在
  全局 `tools` 对象上（`await tools.exec_command(...)`）；
- 沙箱语义写死在描述里："no Node, no file system, no network access"——
  编排代码自己就在沙箱里；
- 会话内持久化靠 `store(key,value)/load(key)`；长脚本用 `yield_control()`
  先交出输出、`wait(cell_id)` 再收割——**脚本版的 spawn/wait 语义**；
- `ALL_TOOLS` 元数据 + 延迟嵌套工具（defer_loading 的工具面在 code-mode 里
  对应"按 name/description 过滤查找"）。

**定性**：这是介于"静态图"与"LLM 自由循环"之间的第三范式——**模型写确定性
代码来编排工具，一次生成、确定执行**。它是"确定性下沉"的源码级背书：连 Codex
都在给模型提供"把编排写成代码"的出口，而不是全靠逐轮 tool call。
**对 investment-app**：不必移植 JS/V8（你的等价物就是 LangGraph 图本身——
Supervisor 的"受约束动态档"决策输出的是图参数，由图确定性执行）；但这个机制
确认了 agent-architecture §4 首条决策（不建 DAG 引擎、动态性在模型循环）之外
还有一条中间路：**批量编排意图 → 一次性结构化成执行计划 → 确定性执行器跑**，
比"每步问一次 LLM"省 token 且可审计。财务工作流的"多表联查分析"这类固定套路
适用。

## 7. 对既有文档的修订清单

| 文档 | 修订 |
| --- | --- |
| `codex-dynamic-graph-findings-kimi.md` §5 | "push 不触发推进"是 V1/完成通知的选择；V2 协议 `trigger_turn=true` 原生支持确定性推进，investment-app 取 true 语义即可 |
| `investment-app-agent-architecture-kimi.md` §4 | "约束在建 run 时预留检查"补全为三件：入口预留（SpawnReservation 式）+ 全树共享账本（fan-out 共摊）+ 提醒阶梯（软降级先于硬停止） |
| 同上 §5"必须自建的五样" | 追加第六样：**run 内压缩策略**（领域化摘要保数字与 citation）——Codex 有完整机制，你目前为零 |
| 同上 角色设计 | profiles.py 扩成完整角色配置；加 awaiter 角色（便宜模型等长任务） |
| 全部 | `~/xxx.md` 路径引用失效，一律改为 `~/codex-reference/xxx.md` |

## 8. 本轮锚点速查

```text
protocol/src/protocol.rs:738              InterAgentCommunication（author/recipient/trigger_turn/加密）
core/src/agent_communication.rs:8         四类 Kind：Spawn/Message/Followup/Result + OTel
core/src/agent/control.rs:210-267         send_inter_agent_communication：trigger_turn 容量检查与 turn 血缘
core/src/session/input_queue.rs:79,143    mailbox：VecDeque 排队 + has_trigger_turn_mailbox_items
core/src/rollout_budget.rs:50-130         加权计量/提醒阶梯/投递去重/rearm
core/src/session/rollout_budget.rs:14-22  提醒投递（先写历史后标记）
core/src/config/mod.rs:582,1086,1184,2776 压缩三键 + RolloutBudgetConfig（reminder 阈值必填）
core/src/compact.rs:55,122,311,390        摘要 prompt/头部裁剪/hook/用户提示
core/src/agent/builtins/awaiter.toml      等待者角色（低推理+只等待不解释）
core/src/agent/builtins/explorer.toml     空文件（0 字节），勿引用
core/src/agent/role.rs:38-42              角色配置模型
code-mode-protocol/src/description.rs:15+ exec：V8 isolate JS 编排工具调用
```
