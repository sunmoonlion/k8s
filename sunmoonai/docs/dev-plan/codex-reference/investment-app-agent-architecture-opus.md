# investment-app 的 agent 架构：现状诊断与演进建议

> 取证时点：2026-08-28 ｜ 作者：opus
> 对象：`/home/zym/worktrees/opus/investment-app` ｜ 参照：Codex `main` @ `7d6f808b97`
>
> 每条断言附取证命令。与
> [`codex-mechanisms-for-investment-agent-opus.md`](codex-mechanisms-for-investment-agent-opus.md)
> 的分工：那份写 Codex 有什么，这份写**我们自己现在是什么样、该往哪走**。

## 1. 一句话诊断

**agent 域是"设计完整、接线稀疏"**——领域层把状态机、预算、工具、沙箱、记忆、
命令都定义了，但两条生产链只用到其中很窄的一条路径。

这不是笼统印象，是可数的：

| 领域构件 | 定义 | **生产层引用** |
| --- | --- | --- |
| `RunBudget`（四维限额） | 有 | **0** |
| `SandboxPort`（含 shell/python 动作） | 有 | **0** |
| `ToolExecutionPort` | 有 | **0** |
| `CancelRunCommand` | 有 | **0** |
| `AgentMemoryService` | 有 | 1（非两条主链） |
| `AgentProfile` | 有 | 2 |

```bash
cd investment-app/investment-backend/app
for s in RunBudget SandboxPort ToolExecutionPort CancelRunCommand; do
  echo "$s: $(grep -rln "$s" app/tasks/ app/application/ 2>/dev/null | wc -l)"
done   # 全为 0
```

**两条生产链实际用到的**（看它们的 import 就能穷举）：

```
agent_graph.py       → DBEventSink · ToolSideEffectService · RunLineage ·
                       RedisSessionLock · checkpointer · walking_skeleton
pilot_agent_graph.py → PilotRepository · KnowledgeRetrieval · PilotLLM ·
                       checkpointer · pilot_graph
```

**没有一条链 import 了 `RunBudget`、`SandboxPort`、`ToolExecutionPort`。**

```bash
grep -E "^from app\." app/tasks/agent_graph.py app/tasks/pilot_agent_graph.py
```

## 2. 已经做对的四件事（不要重做）

对照 Codex 逐条比过，这四处 investment-app 的形态是好的，甚至更适合本场景：

| 项 | 现状 | 与 Codex 对比 |
| --- | --- | --- |
| **Run 状态机集中校验** | `RUN_STATUS_TRANSITIONS` + `validate_run_status_transition()`，七态四终态，出边为空集 | Codex 的 turn 中止只有四个原因枚举，没有等价的完整状态机。**我们更严** |
| **幂等建 run** | 两套键：`session_id+idempotency_key`、`owner_actor_id+idempotency_key` | Codex 无对应物 |
| **副作用一次性** | `tool_side_effects` 以 `tool_call_id` 为 PK + `ON CONFLICT DO NOTHING` | Codex 的 `SpawnReservation` 是**进程内**计数；我们落库，**跨进程更强** |
| **恢复令牌原子消费** | `consume_resume` 置位后不可复用 | Codex 的 `RecoverTurn` 未见等价的一次性保证 |

**结论**：不要因为"Codex 有个 registry"就去重做记账层——
我们在存储侧本来就比它强。要补的是**接线**，不是重建。

## 3. 四个真缺口，按该做的顺序

### 缺口一 · 预算无闸门（最急）

`RunBudget` 定义了四维限额（steps / tool_calls / llm_calls / input_tokens，默认 20/20/20/120000）
并会抛 `AgentError(budget_exceeded)`，但**两条生产链都不调用**，
`budget_exceeded` 这个状态在生产中不可达。

**为什么最急**：一旦开始做并行（fan-out），没有闸门等于把无限额乘以并行度。
任何多智能体工作都必须排在它后面。

**Codex 给出的答案是"接到哪"**：预算不是 run 内的一次断言，而是**目标级的持久状态**——
`ThreadGoalStatus` 落在存储里，取值含 `BudgetLimited`，且与 `UsageLimited`
（账号配额用尽）分开。两者处置不同：前者加预算或放弃目标，后者等配额。

**建议**：
1. 在两条链的每步检查处调 `budget.check()`（改动面小）
2. 把预算状态落库到 run/goal 级，不要只存在内存对象里
3. 区分"本任务预算用尽"与"外部配额用尽"——现状两者都会落到 `failed`

### 缺口二 · 证据账缺失

每条落库结论应带：**依据（来源指针）· 执行者标识（模型/版本）· 时点**。
现状 `session_events` 记了事件，但没有把"这条结论用了哪个模型、哪天、依据什么"绑在一起。

**理由不是审计偏好，是可复现性**：模型列表会演进，`auto` 档由服务端选型。
不记执行者标识，同一份代码两个月后给出不同结论且无从归因——
**这对投资研究结论是不可接受的**。

Codex 的对应物是 `state/src/audit.rs` 的 `ThreadStateAuditRow`（我只确认了它存在，未细读）。

### 缺口三 · 事件流与投影混在一张表

`session_events` 现在既是事件流（追加）又被直接查询（当前态）。

Codex 把这两件事**物理分开**：JSONL rollout 只追加、可重放、是证据；
SQLite state 是可查询的当前态。这与我们自己在 `governance.md` §1 立的
"ADR 只追加 / 投影覆盖式重写"是同一条原则，只是我们没落到存储层。

**不建议现在就拆表**——收益在"能重放"，而当前还没有重放需求。
但**新增字段时应有意识**：这个字段是"发生了什么"（进事件流）还是
"现在是什么"（进投影）？混着加会让以后拆不开。

### 缺口四 · 失败原因码有，分流没有

库内已能区分 `dispatch_failed`（没派出去）与 `resume_dispatch_failed`，
但**消费侧没有按原因码分流的重试逻辑**。

这与 `request-lifecycle.md` §3 的失败三分类是同一件事：
未开工的可直接重试；执行中失败的重试前必须先查副作用账；验收不通过的重试无意义。

Codex 在审批侧做了对应的区分（`Denied` 继续 / `Abort` 停止 / `TimedOut` 独立），
说明这个三分在实践中确实需要。

## 4. 关于多智能体：建议暂缓，先补账

REQ-006 讨论过多智能体编排。基于本轮对 Codex 的读码，我的判断是：

**该做，但不是现在。**顺序上它必须排在缺口一（预算）之后，理由在 §3。

真要做的时候，Codex 有三处具体做法值得参照（**参照 V2，不是 V1**——
两代并存，`Feature::Collab` 默认落 V1，V2 表达力更强）：

| 参照点 | Codex 怎么做 | 我们该怎么改 |
| --- | --- | --- |
| **槽位预扣** | `reserve_spawn_slot` CAS 占位 → guard → `commit()` 或 `Drop` 回滚 | 同样的预扣—提交—回滚，但**计数落 PG**（它用进程内原子量，进程死了就没了） |
| **路径身份** | `/root/...` 物化路径 + 双向索引 | 与 REQ-006 D1 结论一致 |
| **上下文继承显式化** | `fork_turns` 三档（all/none/N），且全量继承时禁止覆盖模型 | REQ-006 曾判"prompt 构造即可"，**该判断偏乐观**——它与模型选择存在真实耦合 |

**一条不该照抄的**：Codex 的所有 agent 共享同一个文件系统与 cwd
（"edits made by one agent are immediately visible to all other agents"）。
我们没有共享工作区，子 run 之间只能经数据库与契约通信。
**照搬其协作语义前先确认共享介质是什么。**

## 5. 一个被忽略的设计意图：沙箱

`SandboxPort` 的动作集含 `shell` 与 `python`——**设计意图明确包含执行代码**。
这条在此前的架构文档里没有被登记为休眠项，本轮补上。

它改变了"investment-app 是研究 agent、不执行代码"这个说法：
那是**现状**，不是**设计**。详见
[`sandbox-extension-advice-opus.md`](sandbox-extension-advice-opus.md)。

## 6. 不建议做的三件事

| 不建议 | 理由 |
| --- | --- |
| 重建记账层去对标 Codex 的 registry | §2——我们在存储侧本来就更强，缺的是接线 |
| 把事件模型扩到 Codex 那种规模（81 种） | 现有 7 种领域事件 + 6 种浏览器事件够用；扩张会让前端与存储成本暴涨 |
| 现在拆 `session_events` 表 | §3 缺口三——收益在"能重放"，而当前无此需求。有意识地加字段即可 |

## 7. 落地顺序

```
1. 接线 RunBudget（落库、区分 Budget/Usage 两类耗尽）   ← 一切并行工作的前置
2. 证据账（结论带来源/执行者/时点）
3. 失败原因码分流重试
4. 槽位预扣（落 PG）—— 多智能体的前置
5. 之后再谈多智能体拓扑
```

与 REQ-006 ④ D7 的结论一致（"先接线单 Run 预算，再设计父子语义"），
本轮对 Codex 的读码只是补上了"接到哪"的具体答案。

## 8. 边界

| 边界 | 说明 |
| --- | --- |
| 未运行 investment-app | 全部结论来自静态读码 + `grep` 计数，未起进程、未连数据库 |
| "生产层引用为 0"的判定方法 | `grep -rln <符号> app/tasks/ app/application/`。若存在动态注入或字符串反射调用，该方法会漏判 |
| Codex 侧只读了约 5% | 见另一份文档 §7 |
| 未读 investment-app 前端 | 本文只涉及后端 agent 域 |
| 沙箱的设计意图是推断的 | 从 `SandboxAction` 的取值反推，未找到写明意图的 ADR |
