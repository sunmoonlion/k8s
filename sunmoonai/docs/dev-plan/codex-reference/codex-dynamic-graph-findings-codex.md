# Codex 动态 Agent 图：源码结论

> 研究基线：`/home/zymun/repo/codex` @ `3929c99a97`，2026-08-28

## 一句话结论

Codex 当前实现的是运行时逐步生长的有根 Agent 树，不是持久化的通用 DAG。图的结构由模型通过工具调用动态提出，Rust 控制面逐次校验并落成线程、路径和消息；依赖关系仍主要存在于模型的计划与对话中。

## 1. 图到底存在哪里

结构真源是 `AgentRegistry.active_agents`：

```text
AgentControl (root-session scoped)
└── AgentRegistry
    ├── agent_tree: AgentPath -> AgentMetadata
    ├── thread_paths: ThreadId -> AgentPath
    ├── used_agent_nicknames
    └── total_count
```

`AgentMetadata` 只有 thread id、agent path、nickname、role（`core/src/agent/registry.rs:24-43`）。父子关系编码在层级 `AgentPath` 中；task name 在同一父路径下必须唯一，reservation 会在真正 spawn 前占位，避免并发重复（同文件 `245-275`）。

这是一棵寻址树。它没有单独的 edge 表、依赖类型、节点输入/输出 schema、完成条件或补偿动作，因此不能把它等同于 LangGraph、Temporal 或业务 DAG。

## 2. 动态性从哪里来

动态性来自循环中的模型工具调用：

1. 模型看到 `spawn_agent` 等工具定义与协作模式提示。
2. 模型生成一个 spawn 调用，携带 task name、任务消息和 fork 策略。
3. handler 计算深度、构建配置、校验覆盖项并创建子线程。
4. 子 Agent 也拥有同类工具时，可以继续生长子树。
5. 完成、消息或用户 steer 进入父 Agent mailbox，父 Agent再决定下一步。

所以它是“增量解释执行的图”，不是先由 planner 输出完整 JSON DAG，再由 scheduler 执行。即使根 Agent 先写了计划，计划也不是控制面的结构化输入。

## 3. 并发、深度与存活不是同一概念

- `AgentRegistry.total_count` 限制当前根树内登记的 spawned threads。
- `AgentExecutionLimiter` 限制同时执行 turn 的线程数。
- `next_thread_spawn_depth` 从 `SessionSource::ThreadSpawn.depth` 推导层级，超过配置深度即拒绝（`core/src/agent/registry.rs:64-78`）。
- V2 residency 可以卸载不活跃线程，之后从 rollout 恢复；因此“已登记节点”“内存 resident”“正在执行”是三种状态。

这项分离值得业务系统借鉴：不要用一个 `status=running` 同时表达拓扑存在、进程驻留和实际占用执行槽。

## 4. 消息边不是依赖边

V2 明确区分：

- `send_message`：投递但不触发 turn；
- `followup_task`：投递并触发 turn；
- `spawn_agent`：创建线程并用首条通信触发 turn。

通信记录 author/recipient 与 lineage，但没有表达 `A succeeds-before B`、`B requires A and C` 或 `on A failure skip B`。`wait_agent` 等的是当前 Agent input queue 的 mailbox/steer 活动，而不是指定依赖集合的 barrier（`multi_agents_v2/wait.rs:184-201`）。

因此从运行记录可以重建“谁创建了谁、谁给谁发过消息”，却不能可靠重建完整业务依赖语义。

## 5. 恢复能力的边界

线程历史和 metadata 可由 rollout/thread store 恢复，V2 还会恢复 Agent metadata 与 resident 状态。恢复的是会话树和对话执行环境，不是一个具备 exactly-once 语义的业务任务图。

具体风险：

- 子 Agent 在外部系统产生副作用后崩溃，不能仅凭回复历史判断是否重做。
- 共享文件编辑可能已经发生，但 final message 未送达。
- task name 的唯一性只在 live 根树控制面内成立，不是跨重启业务幂等键。
- 截断 fork 会丢弃工具调用与 inter-agent communication，需要重建世界状态。

## 6. 如果 Investment 需要“动态 DAG”

建议在现有 Run/Attempt/Invocation 与 LangGraph 之上新增最小持久图层，而不是把 Agent 对话当图数据库：

```text
Run
├── TaskNode(id, path, kind, input_ref, state, budget, idempotency_key)
├── TaskEdge(from, to, condition = success|failure|always)
├── TaskAttempt(node_id, attempt_no, lease, checkpoint_ref)
└── TaskResult(node_id, artifact_refs, evidence_refs, summary)
```

执行规则：

1. LLM 只能提交 `GraphPatch`（新增节点/边），不能直接启动任意副作用。
2. validator 检查无环、节点上限、深度、工具 allowlist、预算与 tenant scope。
3. 数据库事务写入 patch，并通过 outbox 激活 ready 节点。
4. scheduler 只运行所有入边条件已满足的节点。
5. 节点输出只保存版本化 DTO 与 artifact/evidence 引用。
6. fan-in 由结构化 join 完成；LLM 负责语义综合，不负责判定依赖是否完成。

## 7. 采用判断

| 场景 | 直接采用 Codex 式动态树 | 增加持久 DAG |
| --- | --- | --- |
| 并行查代码、搜资料、独立 review | 合适 | 不必要 |
| 只读投资观点的多路生成 | 可作为受控实验 | 视审计要求而定 |
| 交易、下单、通知、写数据库 | 不合适 | 必须 |
| 跨小时/跨重启研究任务 | 不足 | 必须 |
| 有明确前驱、审批、补偿 | 不足 | 必须 |

最终建议是“双层图”：LangGraph/持久任务 DAG 是执行真源，运行中的 Agent 树是可选的认知并行层。认知层可提出 patch 和产出候选结果，但不拥有副作用提交权。

## 源码索引

- 图注册结构：[registry.rs](/home/zymun/repo/codex/codex-rs/core/src/agent/registry.rs:24)
- 根树作用域：[control.rs](/home/zymun/repo/codex/codex-rs/core/src/agent/control.rs:99)
- spawn 路径构造：[spawn.rs](/home/zymun/repo/codex/codex-rs/core/src/tools/handlers/multi_agents_v2/spawn.rs:103)
- fork 过滤规则：[control/spawn.rs](/home/zymun/repo/codex/codex-rs/core/src/agent/control/spawn.rs:52)
- mailbox 等待：[wait.rs](/home/zymun/repo/codex/codex-rs/core/src/tools/handlers/multi_agents_v2/wait.rs:184)
