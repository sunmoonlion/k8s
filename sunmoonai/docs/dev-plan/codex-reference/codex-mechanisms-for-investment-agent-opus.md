# Codex 的执行机制，以及哪些能搬进 investment-app

> 取证时点：2026-08-27 ｜ 作者：opus ｜ 源码：`/home/zym/repo/codex` @ `3929c99a97`（2026-08-19）
>
> **本文只写我自己读源码读到的东西。**每条断言附取证命令，跑命令即可复核。
> 撰写时未读其他助手的 codex-reference 正文（仅看了文件名以确定选题范围）——
> 理由见 `k8s/sunmoonai/docs/architecture/multi-assistant-workflow.md` §2 隔离原则。

## 0.0 版本：已更新到 `main` 最新，并复核了 8 天内的 449 个提交

初稿对 `3929c99a97`（2026-08-19，`rust-v0.151.0-alpha.8`）取证。
该 checkout 已落后上游 **449 个提交**，现已更新到 `main` @ `7d6f808b97`（2026-08-28）。
规模从 3218 文件 / 143 万行 涨到 **3430 文件 / 153 万行**。

**七个机制逐条复核：全部仍然成立，无一被推翻。**锚点文件的改动性质：

| 文件 | 改动 | 对本文结论的影响 |
| --- | --- | --- |
| `core/src/agent/registry.rs` | +66 / −7 | **无**。`thread_paths` 值类型由 `String` 改为 `RegisteredAgent{path, evicted_environments}`，纯增量；`try_increment_spawned` / `SpawnReservation` / `Drop` 一行未动 |
| `protocol/src/protocol.rs` | +178 / −10 | 无。`ReviewDecision` / `TurnAbortReason` 语义不变 |
| `core/src/config/mod.rs` | +203 / −38 | 无。`effective_agent_max_threads` 的绑定关系不变 |
| `app-server-protocol/.../v2/turn.rs` | +98 | 无。`output_schema` 仍是 turn 级参数 |
| `core/src/tools/handlers/multi_agents_spec.rs` | +1 / −1 | 无 |
| `state/src/model/thread_goal.rs` | 无改动 | 无 |

**这 8 天的结构性变化**（不影响本文结论，但值得知道）：

| 变化 | 提交 | 说明 |
| --- | --- | --- |
| 新增 `agent-roles` crate（592 行） | `fb9311db5c` (#40487) | 把 agent 角色加载**抽取**成独立 crate，不是新功能 |
| 新增 `worktree` crate（368 行） | `f832b2fe7b` (#40624) | **新功能**：git worktree 设置解析。对应指南提到的"Worktree 为 App 独占" |
| `ext/guardian` → `ext/guardian-v2` | `e741cd9ace` (#39474) | **合并重构，不是删除**。`core/src/guardian` 仍在，全树 220 个文件引用 |
| `registry` 增加环境驱逐追踪 | — | 与 worktree 相关：agent 的执行环境可被驱逐并记住 |

**复核方法**（约一分钟）：

```bash
cd /home/zym/repo/codex && git pull --ff-only
for s in try_increment_spawned "impl Drop for SpawnReservation" \
         "enum ReviewDecision" "enum ThreadGoalStatus" fork_turns output_schema; do
  printf '%-36s %s\n' "$s" "$(git grep -l "$s" -- '*.rs' | head -1)"
done
```

> **方法教训**：本轮我四次凭"文件/符号找不到"下结论，四次都错
> （§3 的并发上限、指南的工具名、`registry.rs` 的符号、Guardian 的"删除"）。
> 现已改为**先查提交历史再下结论**——`git log --diff-filter=A/D -- <路径>`
> 能区分"删除"与"移动/改名"，而 grep 不能。

## 0.1 一个被此前分析留作悬案的问题：V1/V2 两代并存

`~/note/Codex编排能力完全指南.md` 与 kimi 的实测在工具名上对不上，
kimi 判为"版本漂移"（其 C 级证据），qwen3.8 采纳了该判断未再独立追查。
**实际不是漂移，是两代多智能体实现同时存在于代码里：**

| | V1 | V2 |
| --- | --- | --- |
| 目录 | `core/src/tools/handlers/multi_agents/` | `.../multi_agents_v2/` |
| 消息工具 | `send_input.rs` · `resume_agent.rs` | `send_message.rs` · `followup_task.rs` · `message_tool.rs` |
| 上下文继承 | `fork_context`（布尔） | `fork_turns`（`all`/`none`/正整数） |

选择逻辑在 `core/src/config/mod.rs`：

```rust
fn multi_agent_version_from_features(&self) -> MultiAgentVersion {
    self.multi_agent_version_override().unwrap_or_else(|| {
        if self.features.enabled(Feature::Collab) { MultiAgentVersion::V1 }
        else { MultiAgentVersion::Disabled }
    })
}
```

**即：开启 `Collab` 特性时默认落到 V1，V2 必须显式 override。**
所以 kimi 的活会话看到 V1 工具是正常默认行为，指南描述的是 V2——两边都没错。

**对 investment-app 的实际影响**：本文 M2 描述的是 **V2** 语义
（`fork_turns` 三档、消息类型二分）。若要参照，应明确参照 V2，
因为 V1 的 `fork_context` 只有布尔两档，表达力弱得多。

```bash
ls codex-rs/core/src/tools/handlers/multi_agents/ codex-rs/core/src/tools/handlers/multi_agents_v2/
sed -n '/fn multi_agent_version_from_features/,/^    }/p' codex-rs/core/src/config/mod.rs
```

## 0. 这份文件回答什么

不是"Codex 有哪些功能"。是这一个问题：

> **investment-app 已知有两处真缺口（`RunBudget` 未接线、证据账缺失），
> 还有一批"已设计未接线"的东西。Codex 是怎么解决同类问题的，哪些能搬？**

筛选判据沿用本项目已立的那条（`architecture/request-lifecycle.md` §7）：
**跨 run、或跨进程死亡仍须正确的不变量，必须由存储承担，不能靠执行者自律。**
凡是 Codex 在这个判据上有实现的，本文才收；纯提示词层面的约定不收。

**规模与边界**：Codex 是 3218 个 Rust 文件 / 143 万行。我读的是
`protocol` `core/agent` `core/session` `core/tools/handlers` `state` `rollout` 六处，
约占全仓 5%。**其余部分我不背书**（盲区见 §7）。

## 1. 分层：它把"不变量"放在哪

```
protocol/     纯类型：Op（输入 27 种）· EventMsg（输出 81 种）· 审批决策 · 沙箱策略
   ↑ 无状态，可跨进程传
core/         执行引擎：session / turn / tools / agent registry
   ↓ 两路持久化
state/        SQLite（27 个迁移）：thread_goal · audit · memories · graph — 可查询的当前态
rollout/      JSONL 追加：`~/.codex/sessions/rollout-<ts>-<uuid>.jsonl` — 可重放的事件流
```

**双写不是冗余，是两种语义**：JSONL 只追加、可重放、是证据；SQLite 是投影、可查询、是当前态。
这与本项目 `governance.md` §1 区分"ADR 只追加 / 投影覆盖式重写"是同一个思路，
只是 Codex 把它落到了存储层。

investment-app 现状：`session_events` 表兼当两者——既是事件流又被直接查询，没有分离。

```bash
ls codex-rs/state/src/model/          # SQLite 侧的实体
sed -n '1,5p' codex-rs/rollout/src/recorder.rs   # JSONL 侧自述
```

## 2. 七个值得细看的机制

### M1 · 槽位预留：预扣—提交—回滚，用 RAII 兜住"两条指令之间"

**这是本文最值得搬的一条。**

`core/src/agent/registry.rs`：派生子 agent 前先 `reserve_spawn_slot(max_threads)`，
它用 CAS 循环原子占位；占不到返回 `AgentLimitReached`。占到后返回一个
`SpawnReservation` 守卫，`active: true`。

```rust
fn try_increment_spawned(&self, max_threads: usize) -> bool {
    let mut current = self.total_count.load(Ordering::Acquire);
    loop {
        if current >= max_threads { return false; }
        match self.total_count.compare_exchange_weak(current, current + 1, ...) {
            Ok(_) => return true,
            Err(updated) => current = updated,
        }
    }
}
```

成功建好子 agent 才 `commit()`（置 `active = false` 并登记）；
**若在预留与提交之间任何一步失败，`Drop` 自动回滚**——释放已占的路径名，并把计数减回去。

```rust
impl Drop for SpawnReservation {
    fn drop(&mut self) {
        if self.active {
            if let Some(agent_path) = self.reserved_agent_path.take() {
                self.state.release_reserved_agent_path(&agent_path);
            }
            self.state.total_count.fetch_sub(1, Ordering::AcqRel);
        }
    }
}
```

**为什么这条最要紧**：本项目 `request-lifecycle.md` §7 把"副作用账"列为四本账之一，
理由正是"失败发生在'已执行'与'已记录'两条指令**之间**"。Codex 给出的是可直接照抄的解法——
**先扣后干，干成才提交，没提交就自动退**。

**搬到 Python**：没有 `Drop`，等价物是 `contextlib.contextmanager` 或 `try/finally`：

```python
@contextmanager
def reserve_slot(registry, limit):
    if not registry.try_increment(limit):   # 原子，须落库或用 SELECT ... FOR UPDATE
        raise AgentLimitReached(limit)
    committed = False
    def commit(): nonlocal committed; committed = True
    try:
        yield commit
    finally:
        if not committed:
            registry.decrement()
```

⚠ 但有一处**不能照抄**：Codex 的计数是进程内 `AtomicUsize`，进程一死计数就没了——
它靠单进程长驻规避。investment-app 是多 worker + 进程可能被杀，
**计数必须落 PostgreSQL**，否则跨进程根本不成立。这正是四本账"必须由存储承担"的原意。

```bash
sed -n '/fn try_increment_spawned/,/^    }/p' codex-rs/core/src/agent/registry.rs
sed -n '/impl Drop for SpawnReservation/,/^}/p' codex-rs/core/src/agent/registry.rs
```

### M2 · 多智能体：路径身份 + 显式上下文继承

工具集恰好七个（`core/src/tools/handlers/multi_agents_spec.rs`）：

```
spawn_agent  followup_task  send_message  wait_agent  interrupt_agent  list_agents  close_agent
```

三个设计决定值得注意：

**a) 身份是路径**：根 agent 是 `/root`，子孙是 `/root/...`，可递归派生。
`AgentRegistry` 内部按 `agent_tree: HashMap<String, AgentMetadata>` + `thread_paths` 双向索引。
→ 与本项目 REQ-006 D1 讨论过的"物化路径"是同一结论，且已有实现可参照。

**b) 上下文继承是显式参数，不是隐式**：`fork_turns` 取 `"all"` / `"none"` / 正整数字符串。
文档明确写了两端的代价：`"none"` 会让子 agent 缺上下文而做不成事，
`"all"` 则全量继承。另有一条约束：**全量继承时不允许覆盖 model 与 reasoning_effort**，
只有 `fork_turns` 为 `none` 或正整数时才准覆盖。

→ REQ-006 曾把"上下文继承控制"判为"不必自建，prompt 构造即可"。
**这个判断偏乐观**：Codex 把它做成了一等参数，还附带了模型覆盖的耦合约束——
说明它不是纯 prompt 问题，而是"继承多少上下文"与"用哪个模型"存在真实耦合。

**c) 消息有类型**：`NEW_TASK | MESSAGE | FINAL_ANSWER`，且 `send_message` 与
`followup_task` 的区别是**是否触发对方一个 turn**。
→ investment-app 目前没有 agent 间消息层，若要做，这个"传消息 vs 触发执行"的二分值得抄。

**d) 等待有超时区间**：`min 10s / default 30s / max 3600s`，
且提示词明确要求"prefer longer waits (minutes) to avoid busy polling"。

```bash
grep -oE 'name: "(spawn_agent|followup_task|send_message|wait_agent|interrupt_agent|list_agents|close_agent)"' \
  codex-rs/core/src/tools/handlers/multi_agents_spec.rs | sort -u
grep -n "DEFAULT_MULTI_AGENT_V2_.*WAIT_TIMEOUT_MS" codex-rs/core/src/config/mod.rs
```

### M3 · 审批不是二值，是"批准的作用域"

`ReviewDecision`（`protocol/src/protocol.rs`）有 8 个变体，可归三类：

| 类 | 变体 | 语义 |
| --- | --- | --- |
| 批准 | `Approved` | 仅此一次 |
| | `ApprovedForSession` | 本会话内同类自动放行 |
| | `ApprovedExecpolicyAmendment` / `ApprovedMcpPolicyAmendment` / `NetworkPolicyAmendment` | **修订策略**，跨会话生效 |
| 拒绝 | `Denied { rejection: String }` | 拒绝但**继续**，且带理由字符串回给模型 |
| | `Abort` | 拒绝并**停止**，等用户下一条指令 |
| 无决定 | `TimedOut` | 超时是**独立结局**，不折叠进拒绝 |

三点对 investment-app 直接有用：

1. **拒绝要带理由并回给模型**——现状 pilot 链的 approval 是二值，拒绝后模型不知道为什么。
2. **"拒绝但继续"与"拒绝并中止"必须分开**——合并会让 agent 在该换路时直接死掉。
3. **超时不能当成拒绝**——两者的重试语义不同（同本项目 `request-lifecycle.md` §3 失败三分类）。

```bash
sed -n '/pub enum ReviewDecision/,/^}/p' codex-rs/protocol/src/protocol.rs
```

### M4 · 预算：是持久化状态，不是内存里的一次检查

`TurnAbortReason` 四值：`Interrupted / Replaced / ReviewEnded / **BudgetLimited**`——
预算耗尽是**中止一个 turn 的正当理由**，与用户打断平级。

更要紧的是它落在哪：`state/src/model/thread_goal.rs` 的 `ThreadGoalStatus` 是
**SQLite 里的持久状态**：

```
Active · Paused · Blocked · UsageLimited · BudgetLimited · Complete
```

注意它把 **`UsageLimited`（账号配额用尽）与 `BudgetLimited`（本目标预算用尽）分开**——
两者的处置完全不同：前者换账号/等配额，后者要么加预算要么放弃目标。

**与 investment-app 的对照非常直接**：本项目 `RunBudget` 定义了四维限额、写了超限抛错，
但两条生产链都不调用它，`budget_exceeded` 状态在生产中不可达
（见 `architecture/repos/investment-app.md` §4.5）。Codex 的做法给出了完整参照：
预算是**目标级的持久状态**，不是 run 内的一次断言。

```bash
sed -n '/pub enum TurnAbortReason/,/^}/p' codex-rs/protocol/src/protocol.rs
sed -n '/pub enum ThreadGoalStatus/,/^}/p' codex-rs/state/src/model/thread_goal.rs
```

### M5 · 恢复：三种不同粒度，别混

`Op` 里有三个形似而语义不同的操作：

| Op | 粒度 | 用途 |
| --- | --- | --- |
| `RecoverTurn` | 一个 turn | 崩溃后恢复正在跑的那一轮 |
| `ThreadRollback { num_turns }` | N 个 turn | **主动回退**已完成的若干轮 |
| `Compact` | 上下文 | 压缩历史以腾出 token 窗口 |

investment-app 只有第一类（`Command(resume=...)`），另两类没有对应物。
其中 `ThreadRollback` 对投资研究场景可能有实际价值——"这三轮的结论基于错误证据，退回去重来"。

上下文压缩另有多套实现并存（`compact.rs` / `compact_remote.rs` / `compact_remote_v2.rs` /
`compact_token_budget.rs`），说明这块在 Codex 里也仍在演进，**不是可以直接抄的稳定形态**。

### M6 · 结构化产出：`output_schema` 是 turn 级参数，不是全局契约

`app-server-protocol/src/protocol/v2/turn.rs:146`：

```rust
/// Optional JSON Schema used to constrain the final assistant message for
/// this turn.
pub output_schema: Option<JsonValue>,
```

它与 `effort` / `summary` / `personality` 并列——**同一个 thread 里，每一轮都能单独指定
"这一轮的产出必须符合什么形状"**，而不是整个会话固定一套契约。

**与 investment-app 的差别**：本项目的契约 DTO（`frozen` + `extra=forbid`）是**接口级固定**的，
一个端点一套 schema。Codex 是**调用级动态**的——编排方在派发子任务时就规定返回形状。

这个差别对编排很关键：`request-lifecycle.md` §7 的映射表把"验收标准逐条可判定"
对到"结构化产出契约"，但固定契约只能保证**格式**合法，不能保证**这一次任务**的验收标准
被满足。per-turn schema 才能做到"这次派出去的活，返回必须含这三个字段"。

另有一处相关的：`turn/steer` 与 `turn/start`、`turn/interrupt` 是**三个独立 RPC**
（`app-server-protocol/src/protocol/common.rs:967`，实现在
`app-server/src/request_processors/turn_processor.rs:217`）——
向**正在跑的** turn 追加方向，与"新起一轮"和"打断"都不同。

→ REQ-005 曾把 steering 判为"不必自建：`agent.send` 追加轮次"。
**追加轮次与向当前轮追加方向不是一回事**，前者要等当前轮结束。该判断需要重新评估。

```bash
sed -n '/Optional JSON Schema/,/output_schema/p' codex-rs/app-server-protocol/src/protocol/v2/turn.rs
grep -n "TurnSteer =>" codex-rs/app-server-protocol/src/protocol/common.rs
```

### M7 · 沙箱：四档策略，三套平台实现

`SandboxPolicy` 四档：`DangerFullAccess` / `ReadOnly{network_access}` /
`ExternalSandbox{network_access}` / `WorkspaceWrite{writable_roots, network_access, ...}`。
实现分三处：`linux-sandbox`（Landlock + seccomp）、`windows-sandbox-rs`（token/AppContainer）、
`sandboxing`（公共层）。

**这一条的判断我后来更正过**——investment-app 有 `SandboxPort`（动作含 `shell`/`python`）
但只有 fake 实现、生产零调用。不需要的是内核级实现，不是沙箱本身。
详见 [`sandbox-extension-advice-opus.md`](sandbox-extension-advice-opus.md)。

## 3. 一处值得学的细节：告诉模型的限额与强制的限额同源

并发上限的两端看起来是分开的，实际由一个函数绑定：

```
配置 features.multi_agent_v2.max_concurrent_threads_per_session
   │
   ├─→ session/multi_agents.rs:110   拼提示词："There are N available
   │                                  concurrency slots, ... including you"
   │
   └─→ config/mod.rs effective_agent_max_threads(V2)
          = max_concurrent_threads_per_session.saturating_sub(1)
       → agent/control/spawn.rs:409,977
       → registry.reserve_spawn_slot(max_threads)  ← 真正的强制点
```

`saturating_sub(1)` 是因为**根 agent 不计入配额**——这与 `release_spawned_thread`
里排除 root 的判断一致（`!metadata.agent_path.is_some_and(AgentPath::is_root)`），
也与提示词"including you"的措辞吻合：提示词里的 N 含自己，强制值 N−1 只数子 agent。

**这条值得学**：告诉模型的数字与代码强制的数字**必须同源**，否则前者只是安慰剂。
investment-app 若要做并发限额，应从同一个配置派生这两处，并把"根是否计入"写清楚。

> **更正记录**：本节初稿曾断言"提示词与强制值不同源、无绑定代码"，
> 依据是一次范围过窄的 grep（只在 `codex-rs/` 内且漏看了 `config/mod.rs:1504`）。
> 复核调用链后证伪，已改写。原判断作废，保留此记录以说明结论是怎么被推翻的。

```bash
sed -n '/fn effective_agent_max_threads/,/^    }/p' codex-rs/core/src/config/mod.rs
grep -rn "effective_agent_max_threads" --include='*.rs' codex-rs/ \
  | grep -v target | grep -v test | grep -v "fn effective"
```

## 4. 可迁移性判定

| 机制 | 判定 | 理由 |
| --- | --- | --- |
| M1 槽位预留（预扣—提交—回滚） | **直接可迁，优先级最高** | 补的正是本项目已识别的"副作用账"缺口；但计数必须落 PG，不能学它用进程内原子量 |
| M4 预算作为持久状态 + `UsageLimited`/`BudgetLimited` 分离 | **直接可迁** | `RunBudget` 未接线是已知缺口；这给出了"接到哪"的答案：目标级持久状态，不是 run 内断言 |
| M3 审批作用域化 + 拒绝带理由 + 超时独立 | **可迁，改造小** | pilot 链已有 interrupt/approval，只需把二值扩成枚举 |
| M2b `fork_turns` 显式上下文继承 | **可迁，但需重新评估** | REQ-006 曾判"不必自建"，Codex 的实现说明该判断偏乐观 |
| M2a 路径身份 | 可迁 | 与 REQ-006 D1 结论一致，有实现可参照 |
| M2c 消息类型二分（传消息 vs 触发 turn） | 可迁 | investment-app 目前无 agent 间消息层 |
| M6 `output_schema` 调用级结构化产出 | **可迁，价值高** | 固定契约只保证格式合法，保证不了「这次任务的验收标准被满足」 |
| M6 `turn/steer`（向运行中的轮追加方向） | **需重新评估** | REQ-005 判为「不必自建」，但它与「追加下一轮」不是一回事 |
| M5 `ThreadRollback` | **值得评估，非急需** | 投资研究"退回 N 轮重来"有真实场景，但不是当前缺口 |
| M5 上下文压缩 | **暂不迁** | Codex 内部四套实现并存，形态未稳定 |
| M7 沙箱 | **不迁** | 见下 |
| Guardian / Elicitation / 动态工具 | **不迁** | 见下 |

## 5. 明确不建议照搬的，及理由

**根本差异**：Codex 是**编码 agent**——它执行任意命令、改文件、访问网络，
所以必须有沙箱、审批、Guardian、网络策略。
investment-app 是**研究 agent**——它调 knowledge 检索、调 LLM 生成草稿、等人批准，
**不执行任意代码**。

由此：

| 不迁 | 理由 |
| --- | --- |
| 沙箱三件套（Landlock/seccomp/AppContainer） | **判断已更正**：investment-app 有 `SandboxPort`，动作集含 `shell`/`python`，设计意图包含执行代码，只是未接线。不迁的是**内核级实现**（k8s 上 Pod 即隔离单元），不是沙箱本身。详见 [`sandbox-extension-advice-opus.md`](sandbox-extension-advice-opus.md) |
| 网络策略与 execpolicy 修订 | 同上。investment-app 的出站只有 knowledge 与 LLM 两个已知端点，用 allowlist 即可（现状已有） |
| Guardian 评估层 | 它拦的是危险的**代码操作**；研究 agent 的风险在结论质量，不在操作破坏性 |
| 81 种事件的事件模型 | 规模不匹配。investment-app 现有 7 种领域事件 + 6 种浏览器事件够用；照搬会让前端与存储成本暴涨 |
| Realtime 语音族 | 与场景无关 |

**一条容易踩的误判**：Codex 的多智能体是"所有 agent 共享同一个文件系统与 cwd"
（提示词里明写 "edits made by one agent are immediately visible to all other agents"）。
这个前提在 investment-app 不成立——它没有共享工作区，
子 run 之间只能通过数据库和契约通信。**照抄其协作语义前，先确认共享介质是什么。**

## 6. 建议的落地顺序

按"补已知缺口 + 改动面小"排序，不按机制的精巧程度：

1. **M1 槽位预留**（落 PG）——它同时是 M2 派生子 run 的前置
2. **M4 预算持久化**——把 `RunBudget` 接到目标级状态上，让 `budget_exceeded` 可达
3. **M3 审批枚举化**——二值扩成作用域 + 拒绝理由 + 超时独立
4. 之后再谈 M2 的多智能体，此时 1、2 已经就位，派生才有账可记

这个顺序与本项目 REQ-006 ④ D7 的结论一致（"先接线单 Run 预算，再设计父子语义"），
Codex 的实现只是为"接到哪"提供了具体答案。

## 7. 本文的盲区（不背书的部分）

| 盲区 | 说明 |
| --- | --- |
| **覆盖率约 5%** | 143 万行里我读了六个 crate 的关键路径；`tui`(26.7 万行)、`core-plugins`、`exec-server`、`app-server` 基本未读 |
| **未运行** | 全部结论来自静态读码，没有编译、没有跑测试、没有实跑 Codex |
| **版本单点** | 只看了 `3929c99a97` 一个提交，未看演进历史，无法判断哪些是稳定设计、哪些是正在改的 |
| **`core` 只读了 session/agent/tools 三块** | 43.4 万行的 core 我读的是与多智能体、预算、审批相关的路径 |
| **SQLite schema 未逐表读** | 只确认了 27 个迁移与 `thread_goal` 一张表的状态集 |
| **"没找到"是最弱的证据，本轮错了两次** | ① §3 初稿断言并发上限"不同源"，因 grep 范围过窄被证伪；② 事后核对 `note/Codex编排能力完全指南.md` 时，我按工具名 grep 判定 `handoff_thread` 等五个原语"不存在"，换关键词后发现 `handoff` 命中 43 个文件——**指南写的是工具面名字，Rust 内部标识符不同**。凡"我没找到 X"的断言都应换 2–3 个关键词复验后才写 |

**复核入口**：本文每节末尾的命令都可在 `/home/zym/repo/codex` 直接跑。
若某条跑不出我说的结果，以代码为准，并请指出。
