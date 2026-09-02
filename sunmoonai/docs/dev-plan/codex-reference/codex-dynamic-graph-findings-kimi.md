# Codex 动态 Graph 源码追踪结论（回答研究文档 §13 三问 · kimi 版）

> 最后更新：2026-08-19
>
> 性质：源码研究结论，回答 `~/codex-reference/codex_dynamic_graph_research.md` §13 的问题 A/B/C，
> 并对接 `~/codex-reference/codex-orchestration-assessment-kimi.md` 的移植设计。
> 源码版本：`~/repo/codex`（openai/codex，Rust 核心 `codex-rs/`），追踪时间 2026-08-19。
> 研究原则遵循原文档 §17：每个结论锚定到文件/函数；源码事实与架构解释分开。

---

## 1. 完整调用链（全部锚点已核实）

```text
父 Agent 模型推理
  ↓ tool call: spawn_agent
tools/handlers/multi_agents/spawn.rs           # 工具入口
  ↓
agent/control.rs  AgentControl                  # 约束检查与创建（depth/并发/budget 预留制 SpawnReservation）
  ├─ agent/registry.rs                          # AgentRegistry：路径/昵称注册
  ├─ 创建子线程（SubAgentSource::ThreadSpawn { parent_thread_id, agent_path }）
  └─ maybe_start_completion_watcher（control.rs:510）# 后台 tokio watcher 等终态
  ↓
子线程独立执行（自己的 model/instructions/sandbox/context）
  ↓ 子 Session 每发一个事件
session/mod.rs:2144  deliver_event_raw
  └─ agent/status.rs:6  agent_status_from_event
       TurnComplete → AgentStatus::Completed(last_agent_message)
       TurnAborted → Interrupted / Errored
       Error       → Errored
  └─ session/mod.rs:2148  agent_status.send_replace(status)   # 写入该线程的 watch 通道
       （session/session.rs:42  agent_status: watch::Sender<AgentStatus>）
  ↓ 终态判定 agent/status.rs:24  is_final()
       （Completed/Errored/Shutdown/NotFound 为终态；Interrupted 不是）
  ↓
两条返回路径（见 §2）
  ↓
父 Agent 下一次模型推理看到结果 → 自行决定 update_plan / spawn_agent / send_input
```

## 2. 问题 A：Child Result 如何返回 Parent？——双通道

**拉通道（同步，父主动等）**：

1. 父调 `wait_agent(targets, timeout_ms)`（`tools/handlers/multi_agents/wait.rs:51`）。
2. 对每个目标 `agent_control.subscribe_status(id)`（`control.rs:406`）拿到
   `watch::Receiver<AgentStatus>`。
3. `wait_for_final_status`（`wait.rs:307`）阻塞在 `status_rx.changed()` 直到 `is_final()`；
   多目标用 `FuturesUnordered` 实现 wait-any（第一个到终态即返回，再顺手收割已完成的）。
4. 结果打包 `WaitAgentResult { status: {agent路径: AgentStatus}, timed_out }`，
   经 `to_response_item` 转成 **function-call-output——即 wait_agent 这次工具调用的
   普通返回值**，进入父上下文。

**推通道（异步，父没等也送到）**：

1. spawn 时 `maybe_start_completion_watcher`（`control.rs:510`）为
   `ThreadSpawn` 来源的子 Agent 起一个后台 tokio watcher，同样订阅 watch 通道等终态。
2. 子到终态后分两代实现：
   - V1：`format_subagent_notification_message`（`session_prefix.rs:20`）→
     `parent_thread.inject_user_message_without_turn(message)`（`codex_thread.rs:518`）——
     把一条 user 角色通知**写入父线程历史但不开启新 Turn**，静静躺在上下文里等父
     Agent 下一次推理时看到。
   - V2：`format_inter_agent_completion_message`（`session_prefix.rs:27`）→
     `send_inter_agent_communication(parent_thread_id, ..., trigger_turn=false)`
     （`control.rs:575-590`），结构化 inter-agent 消息。
3. 此外子 Session 自身在 `TurnComplete/TurnAborted` 时也主动结算终态
   （`session/mod.rs:1952-1978`，含 `terminal_error` → `Errored` 的覆盖逻辑）。

## 3. 问题 B：Parent 如何看到 Child Result？——数据结构

**结果的载体是 `AgentStatus::Completed(Option<String>)`：子 Agent 最后一个 Turn 的
最后一条 assistant 消息**（`TurnComplete.last_agent_message`）。不是结构化报告，
不是 transcript 摘要，就是一段文本。

进入父上下文的两种形态：拉通道 = 工具调用输出 item；推通道 = user 角色注入消息
（不触发新 Turn）。两者都是**普通上下文条目**，没有任何特殊的"结果通道"。

推论（对移植极重要）：**子 Agent 的"返回值"就是它的最后一条消息**，父子之间唯一的
信息管道（除 artifacts 外）就是这段文本。这就是子 Agent prompt 必须有"返回格式"
纪律的源码级原因——`session_prefix.rs:33-40` 显示错误也会被截断后格式化注入
（`truncate_text(Tokens(ERROR_MAX_TOKENS))`），父 Agent 拿到的永远是受限文本。

## 4. 问题 C：Re-planning 在哪里发生？——不在任何运行时里

**源码确认：不存在图修改引擎，动态 Graph 是模型循环推理的涌现。** 证据链：

1. `update_plan` 的 schema 无 `depends_on`/`parent`/`children`（原文档 §6.1 已确认）——
   plan 只是展示性状态，不是 DAG。
2. Agent 之间的关系只有 `AgentPath` 树（父子层级，`control.rs:384-402` 的路径解析）
   和 `AgentRegistry`（注册/预留），**没有任务依赖图这种数据结构**。
3. "Re-plan" 的物理过程 = 结果经 §2 双通道进父上下文 → 父 Agent 下一次模型推理 →
   模型自己决定再 spawn / 再 update_plan。运行时只做约束（depth/并发/budget，
   spawn 时 SpawnReservation 预留制检查）与生命周期，不做规划。

所以原文档 §3.2 的猜想被证实，且可以更精确：

> **Dynamic Macro Graph = model-driven emergent graph + runtime-constrained execution。**
> 图从未作为数据结构存在；它是模型行动序列在 AgentPath 树上的投影。

这也回答了原文档 §2 的核心问题——"动态 Graph 是不是 Codex 通用性的关键来源"：
**是，但实现机制出人意料地轻**。不需要图引擎，需要的是三件事：(1) 子任务在隔离
上下文中执行；(2) 结果可靠回注父上下文（双通道）；(3) 模型围绕"计划-派生-等待-
再推理"可靠循环。复杂度全在第三件的上下文工程与约束上，不在"图"上。

## 5. 对 investment-app 的移植清单

与 `~/codex-reference/codex-orchestration-assessment-kimi.md` 的"语义映射、机制替换"对接，本次源码追踪
新增/修正如下：

**该移植的（domain-independent）**：

1. **"结果 = 最后一条消息"约定**：子任务/子图的返回值约定为最终消息文本 +
   artifacts 引用。配合 prompt 的返回格式纪律（对应原文五段式模板第五段）。
2. **双通道结果返回**：pull（Supervisor 的 `wait_runs` 工具）+ push（run 完成事件
   注入 Supervisor 上下文）。我们已有 `event_sink`，push 通道天然成立。
3. **极简状态通道**：`watch::channel<AgentStatus>` 一个枚举走天下 + 单一 `is_final()`
   判定。investment-app 的 Run 状态机照此收敛：**状态枚举 + 结果挂在终态上**，
   不要为结果另建管道。
4. **约束在运行时不在模型**：depth/并发/budget 在建 run 时预留检查（对齐
   `SpawnReservation` 思路），模型永远不需要知道限额存在——对应 RunBudget 接线 +
   celery 并发上限 + LangGraph `recursion_limit`。
5. **"不要 DAG 引擎"的源码背书**：Codex 自己都没有 DAG 引擎。财务 Agent 的动态性
   应来自"静态骨架 + 模型在骨架内循环 spawn"——这为 assessment 文档的"确定性下沉"
   原则提供了源码级证据：**连 Codex 的动态性都是模型循环的涌现，不是图算法**。

**不该移植的**：

1. `inject_user_message_without_turn`（push 不触发推进）：桌面会话形态下"等下一次
   推理顺便看到"可以接受；服务端长任务需要**确定性推进**——run 完成事件应驱动
   图节点继续执行（LangGraph 的 interrupt/resume 或事件驱动边），不能躺在上下文里等。
2. "结果 = 纯文本消息"：对财务系统太弱。 Supervisor 与 worker 之间走结构化
   outputSchema（assessment 已定），文本消息只做人读摘要。

## 6. 与研究文档 §14 目标模型的对照

§14 那张目标图的每个箭头，现在的源码对应：

| §14 箭头 | 源码实体 |
| --- | --- |
| Model → update_plan | plan 工具（展示态，无 DAG 语义） |
| Model → spawn_agent | `multi_agents/spawn.rs` → `AgentControl` |
| AgentControl → Child A/B/C | `AgentRegistry` + `AgentPath` 树 + depth/budget 约束 |
| Child → Child Results | `deliver_event_raw` → `agent_status_from_event` → watch 通道 |
| Child Results → Parent Context | 拉：wait_agent 工具输出；推：注入消息（不触发 Turn） |
| Parent Context → Parent Model | 普通上下文条目参与下一次推理 |
| Parent Model → Re-planning | **模型自身行为，无运行时实体** |
| Re-planning → New Tasks/Agents | 再次 spawn_agent，循环 |

研究文档 §18 的"下一步"至此完成。剩余可深挖（按需）：`/orchestrate` 实验性
coordinator（§12 的 B 类，与本文机制是两套）、V2 inter-agent communication 的完整
协议、`RolloutBudget` 的计量细节。

## 7. 关键文件速查

```text
codex-rs/core/src/agent/control.rs            # AgentControl：spawn/约束/watcher/通知
codex-rs/core/src/agent/status.rs             # 事件→状态映射 + is_final
codex-rs/core/src/agent/registry.rs           # AgentRegistry：路径/昵称/预留
codex-rs/core/src/tools/handlers/multi_agents/wait.rs   # wait_agent（拉通道）
codex-rs/core/src/tools/handlers/multi_agents/spawn.rs  # spawn_agent 入口
codex-rs/core/src/codex_thread.rs:518         # inject_user_message_without_turn（推通道 V1）
codex-rs/core/src/session/mod.rs:2144         # deliver_event_raw：事件流喂状态通道
codex-rs/core/src/session_prefix.rs:20,27     # 通知消息格式化（V1/V2）
```
