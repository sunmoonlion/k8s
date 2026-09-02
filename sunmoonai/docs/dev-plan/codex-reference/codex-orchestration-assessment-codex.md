# Codex 多 Agent 编排：源码评估

> 研究基线：`/home/zymun/repo/codex` @ `3929c99a97`，2026-08-28

## 结论

Codex 的多 Agent 核心不是一个预先定义的工作流引擎，而是“模型决策 + 线程树控制面”。模型在运行中决定是否 `spawn_agent`、给谁发消息以及何时等待；Rust 运行时负责身份树、线程生命周期、容量、上下文继承、消息投递、持久化恢复和可观测事件。

这个分工适合并行探索、代码检索、独立审查等开放任务；它并不直接提供业务工作流所需的显式依赖 DAG、节点幂等键、补偿事务、条件汇聚或可审计的结果契约。Investment 不应复制整个 Codex 控制面，而应吸收它的边界设计。

## 1. 控制面的真实所有者

`AgentControl` 按根线程树创建并由所有子 Agent 共享，而不是挂在全局 `ThreadManager` 上。它持有会话 ID、弱引用的线程管理器、根树内 `AgentRegistry`、V2 residency、并发执行限制器和整棵树共享的 rollout budget（`core/src/agent/control.rs:99-121`）。这带来两个重要性质：

1. Agent 名称与线程 ID 的可见范围是根会话树，而不是进程全局。
2. 控制面不会通过强引用让已结束线程被意外保活。

`AgentRegistry` 同时维护 `agent_path → metadata` 与 `thread_id → path` 两个索引，并用原子计数限制子线程总数（`core/src/agent/registry.rs:17-35`）。spawn 先取得 `SpawnReservation`，再保留路径和昵称；只有线程成功建立才 commit，失败或提前返回由 `Drop` 自动回滚计数和路径（同文件 `81-100, 245-294, 297-342`）。这是比“先创建、失败后人工清理”更稳的资源预留模型。

## 2. V2 工具语义

| 工具 | 运行时语义 | 关键边界 |
| --- | --- | --- |
| `spawn_agent` | 创建子线程并立即投递触发 turn 的初始通信 | task name 形成层级 `AgentPath`；深度、容量、角色与模型覆盖在创建前校验 |
| `send_message` | 向活跃 Agent 投递消息，不强制启动新 turn | 适合运行中的旁路信息，不应被当作任务队列 |
| `followup_task` | 投递消息并触发 idle Agent 的新 turn | 受执行并发容量约束 |
| `interrupt_agent` | 对目标线程发送 `Op::Interrupt` | 根不是 spawned agent，不能按同一路径被中断 |
| `list_agents` | 列出当前根树或路径前缀下的 live Agent | 是运行态视图，不是完整历史图 |
| `wait_agent` | 等 mailbox 或用户 steer 活动，或超时 | 返回“有活动”，不直接承载子 Agent 最终正文 |

V2 spawn handler 从当前 session source 计算子深度，构建子配置，应用角色/模型/service tier/runtime overrides，再构造带 task name 的 `ThreadSpawn` source 和首条 `InterAgentCommunication`（`core/src/tools/handlers/multi_agents_v2/spawn.rs:41-171`）。因此“子 Agent 是一个独立线程”是实现事实，不只是提示词拟人化。

`wait_agent` 订阅根 Agent 自己的 input queue activity；它等待 mailbox、用户 steer 或 timeout，并将过小 timeout 钳制到配置下限（`core/src/tools/handlers/multi_agents_v2/wait.rs:37-93, 135-201`）。这说明等待是事件驱动的协作原语，而非对子线程轮询状态的 join 操作。

## 3. 上下文继承不是内存克隆

V2 支持三种 `fork_turns`：

- `none`：新上下文，不 fork 历史；
- `all`：完整历史；
- 正整数：仅最后 N 个 turn。

解析规则在 `multi_agents_v2/spawn.rs:231-265`。fork 时只保留系统/开发者/用户消息和带 `final_answer` phase 的 assistant 消息；工具调用、工具结果、reasoning、Agent 消息和安全分数等被过滤。完整 fork 可保留 world-state/turn-context 基线，截断 fork 必须首轮重建（`core/src/agent/control/spawn.rs:52-104`）。

所以 fork 是经过筛选的模型可见历史，不是复制父线程的所有执行状态。共享的是文件系统与运行环境；线程上下文、生命周期和消息队列仍彼此独立。

## 4. “智能”与“机械保证”的边界

模型负责：

- 判断任务是否值得拆分；
- 设计子任务粒度与 task name；
- 选择 fork 范围；
- 综合子 Agent 回传；
- 决定何时追问、打断或继续派工。

运行时机械保证：

- 路径唯一、容量与深度限制；
- spawn 失败时资源回滚；
- 线程状态订阅与失效线程清理；
- 消息接收者解析；
- 父/根 turn lineage 传播；
- 工具调用和 Agent 活动事件。

提示词只影响模型是否使用能力。V2 的默认模式会根据推理强度或配置生成 `ExplicitRequestOnly`、`Proactive` 或自定义策略，并作为 bounded world-state fragment 注入；自定义文本最多 400 tokens（`core/src/session/multi_agents.rs:145-185`、`core/src/context/world_state/multi_agent_mode.rs:13-32`）。策略不是调度器本身。

## 5. 可靠性边界

### 已有的强项

- 原子容量预留与失败回滚。
- 稳定的层级 task path，支持相对路径寻址。
- turn lineage 和跨 Agent 通信事件。
- 完整/截断/空上下文 fork 的明确语义。
- mailbox 驱动等待，避免高频 busy polling。
- resident Agent 可卸载并按需恢复，执行并发与存活线程数分开管理。

### 不是它的职责

- 没有声明式任务依赖边和拓扑排序。
- 没有“所有前驱成功才激活”这类 join 条件。
- task name 唯一不等于业务幂等。
- 共享工作区没有文件级所有权或合并事务；并发编辑冲突靠任务划分与 Git 检查规避。
- Agent 的 final answer 是通信内容，不是版本化的业务 DTO。
- wait 唤醒只表示 mailbox/steer 活动，不保证某个目标节点已成功完成。

## 6. 对 Investment 的可复用部分

建议复用设计原则，而不是复用 Codex crate：

1. 用 `Run → InvocationPath → Attempt` 建业务身份树；路径用于寻址，UUID 用于持久主键。
2. 创建 Invocation 前先做原子容量/预算 reservation，成功后 commit，异常自动 release。
3. 把“消息是否触发执行”做成显式枚举，等价于 `send_message` 与 `followup_task` 的分离。
4. 上下文 fork 必须白名单投影，禁止复制工具结果、凭据、长正文和未验证 reasoning。
5. 等待基于持久事件/队列，不做数据库状态忙轮询。
6. LangGraph/Celery 继续承担可恢复业务流程；LLM 只在受控节点内提出动态 fan-out，不成为唯一调度真源。

## 7. 关键源码索引

- 控制面：[control.rs](/home/zymun/repo/codex/codex-rs/core/src/agent/control.rs:99)
- 注册与 reservation：[registry.rs](/home/zymun/repo/codex/codex-rs/core/src/agent/registry.rs:17)
- spawn 与上下文过滤：[spawn.rs](/home/zymun/repo/codex/codex-rs/core/src/agent/control/spawn.rs:52)
- V2 spawn 工具：[multi_agents_v2/spawn.rs](/home/zymun/repo/codex/codex-rs/core/src/tools/handlers/multi_agents_v2/spawn.rs:41)
- V2 wait 工具：[wait.rs](/home/zymun/repo/codex/codex-rs/core/src/tools/handlers/multi_agents_v2/wait.rs:37)
- 协作模式解析：[multi_agents.rs](/home/zymun/repo/codex/codex-rs/core/src/session/multi_agents.rs:145)
