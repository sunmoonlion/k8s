# Codex 哪些机制能搬进 investment-app（Cursor 版）

> 最后更新：2026-09-02
>
> 性质：个人决策底稿，非 baseline、非 REQ。
> 筛选问题不是「Codex 有什么」，而是：总稿已经立的那套地基（一个 Agent、
> 熟路静态图、生路控制环、同一 `Run`），缺的治理件 Codex 怎么做的、搬不搬。
>
> 取证：`/home/zym/repo/codex` @ `7d6f808b97`。
> 判据沿用 `dev-plan/working/request-lifecycle.md`：跨 run 或进程死亡仍须成立
> 的不变量，必须由存储承担。

## 结论（能搬 / 对照 / 不搬）

| 机制 | 判定 | 落到我们哪 |
| --- | --- | --- |
| 槽位预留：先占后干，失败回滚 | **搬** | 生路 fan-out；计数必须进 PostgreSQL，不能抄进程内原子量 |
| 审批作用域：一次 / 本会话 / 改策略；拒绝带理由；超时独立 | **搬语义** | 人稿终审 + dry_plan 批准；现状二值不够 |
| 预算是持久状态，耗尽是正当中止 | **搬** | 已有 `RunBudget`，先接线，别先扩维 |
| 双写：JSONL 事件流 + 可查询投影 | **对照** | 现有 `session_events` 兼两职，以后再拆，不阻塞熟路 |
| 路径身份 + 显式上下文继承 | **生路对照** | `RunLineage` 已能表达树；不实现 `fork_turns` 工具 |
| 内核沙箱 | **不搬实现** | 见 `sandbox-extension-advice-cursor.md`，只借 `ExternalSandbox` + 网络正交 |
| 桌面 worktree / SSH / 跨机 handoff | **不搬** | Host 只有 Docker |

熟路第一天不依赖上表「生路」行。顺序仍是总稿：单 Run 闭环（容器、预算、
取消、事件）成立，再放生路。

## 1. 先占后干（最值得搬）

Codex 派生子 agent 前 `reserve_spawn_slot`：CAS 占位，拿不到就
`AgentLimitReached`。占到返回守卫，建成功才 commit；中间失败由 `Drop`
回滚计数和路径。

Python 没有 `Drop`，用 `try/finally` 或 contextmanager 就行。**不能照抄
`AtomicUsize`**：Codex 单进程长驻，计数在内存里死了就没了。我们是多
worker，槽位必须落库（一行计数 + 事务，或 `SELECT … FOR UPDATE`）。

这和 request-lifecycle 的副作用账是同一类洞：失败发生在「已执行」和
「已记录」之间。先扣后干是解法。

```bash
rg -n "try_increment_spawned|struct SpawnReservation|impl Drop for SpawnReservation" \
  /home/zym/repo/codex/codex-rs/core/src/agent/registry.rs
```

## 2. 审批不是二值

`ReviewDecision`（`protocol.rs`）至少要能区分：

- 只批这一次
- 本会话同类自动放行
- 拒绝但继续（理由回给模型）
- 拒绝并停
- **超时**（不是拒绝）

问数链的 `dry_plan` 对人批准、决策备忘录对人拍板，都该按这个拆。现在
pilot 拒绝后模型不知道为什么，该换路时容易直接死。

不把 Codex 的「修订 exec/MCP/网络策略」八个变体一次性搬完。先把「一次 /
继续 / 中止 / 超时」做对。

## 3. 预算是目标态，不是 assert

`TurnAbortReason` 里 `BudgetLimited` 和用户打断平级。`ThreadGoalStatus`
把 `UsageLimited`（账号配额）和 `BudgetLimited`（本目标预算）分开——处置
完全不同。

我们 `RunBudget` 四维已经建模，生产链不调用，`budget_exceeded` 不可达。
**先接线，别先加第五维。** 超限必须能中止 Run、写事件、让控制面看见，
而不是日志里 warn 一声。

沙箱 exec、`wren_query` 都是预算出口。两篇专文都写了「排在预算之后」，
这里再钉一次。

## 4. 事件流和当前态不要永远 stewed 在一张表

Codex：`rollout` JSONL 只追加、可重放；`state` SQLite 是投影、可查询。
我们 `session_events` 现在两职合一。熟路闭环不要求先拆。等要「按 Run
回放 + 按目标查当前态」同时变痛，再拆。不要为了像 Codex 先上第二套存储。

## 5. 生路才需要的对照

V2 工具集（`spawn_agent` / `followup_task` / `send_message` / `wait_agent` /
`interrupt_agent` / `list_agents` / `close_agent`）是控制环的零件，不是
我们的 API。总稿对象模型已经叠在 Session / Run / RunLineage / DomainEvent
上。

要做的是语义：

- 子任务是子 Run，不是「再来一个 Agent 进程」
- 上下文继承必须显式（全量 / 不要 / 最近 N），默认不要全量拷对话
- `send`（传数据）和 `followup`（触发一回合）分开
- wait 要有超时，禁止忙等

身份用已有 lineage，不必抄 `/root/...` 路径字符串——除非查询痛了再物化。

## 6. 明确不搬

- Landlock / seccomp / 三套桌面沙箱
- SSH、Cloud、跨机器 Handoff
- 把用户本机 IDE 目录当工作区
- `/fork` 整段聊天当竞赛主路径
- 模型现场规划整张图当默认整机

## 7. 边界

- 读了 protocol / agent registry / multi_agents(_v2) / sandbox policy /
  rollout 自述，约占全仓很小一块
- 未编译、未跑 Codex、未复现活会话
- 机制在 `7d6f808b97` 上抽查仍在；之后提交未跟踪
