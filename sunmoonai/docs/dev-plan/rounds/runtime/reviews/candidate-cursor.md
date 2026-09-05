参与方：cursor｜worktree：/home/zym/worktrees/cursor/k8s｜HEAD：4513bcbd

# 运行时架构：一个运行时，开发是第一个 Task Profile

> 提案。不承担规范效力。只读输入未改：`refact-fable.md` @ `7e8464c2`（927 行，sha256[:16] `89303624bfd9ef27`）；
> `working/request-lifecycle.md` @ `70a7dd50`（647 行，sha256[:16] `6fcd3973ede30b88`）。
> 要改它们的句子写在正文，不改文件。
>
> 取件自证：`task.md` @ `runtime/h1` 427 行 `c31aa01cff556abd`；`round.md` @ `runtime/h1` 109 行 `27118cf7717cb737`；
> 协议 @ `runtime/protocol` 601 行；`rulings.md` @ `opus` 20 行。
>
> 身份（仓根）：`r=$(git rev-parse --show-toplevel) && basename "$(dirname "$r")"` → `cursor`。
> 路径是唯一证据。本轮同厂有两个产品（`cursor` = CLI，`fable` = GUI），模型自称与界面名一律不作身份。

---

## 0. 主张（三句）

1. **只有一个产品运行时**，对应 `request-lifecycle.md`「两层状态机」那一套 Task / Attempt 状态与边。
   「开发」是跑在它上面的 Task Profile `DEV_ROUND`；luna / kimi / cursor / fable / qwen 是五个 Agent Profile。
2. **今天的人+脚本与明天的运行时服务，是同一个 Task Profile 的两种 orchestrator 实现**，不是两层架构。
   git 载体是脚手架，拆除条件见 §1.4。
3. **人不是执行者。**人是权力表上的 principal，每次介入落在唯一状态机的一条边。
   登记表不把人列为执行者。人代跑脚本（粘贴固定指令、给不可分发的执行者投喂）是 orchestrator 欠账，不是权力。

上一轮终稿把持久层、执行者、通道、guard、状态判定五格的**取值差**画成了一对部署形态
（`refact-fable.md:170-177`）。结构相同、只差取值——按它自己 `:180` 杀掉「第三套」的同一把刀，
这五格也站不住。`task.md` §2.1 记：cursor 离得最近（杀掉第三套），但没把刀转向那一对。
原因不是刀钝，是当时把「取值」误认为「部署形态」——五格像架构图上的两列，不像状态机上的档位。
内核已经有 Task Profile / Agent Profile（`request-lifecycle.md:103-104`），上一轮没用这两个词，
另造了第三义。本轮把词还回去。

---

## 1. P1 — 一个运行时，开发是一个 Task Profile

### 1.1 对象层

运行时拥有且只拥有内核「核心对象」表里的那些东西（`request-lifecycle.md:91-104`）：
Task、Attempt、Interaction、Artifact、Event、Side Effect、Delivery，外加 Task Profile 与 Agent Profile。
状态词与合法边以「两层状态机」为准（`:208-228`、`:312-318`）。任何领域不得新增状态词，
也不得走表外的边（内核反模式「Profile 修改通用状态机」，`:580`）。

```text
产品运行时（唯一）
├── 状态机：Task 九态 + Attempt 七态，边集固定
├── Task Profile 们：DEV_ROUND（本轮要钉的第一个）· DATA_QUERY · RESEARCH · ACTION · …
└── Agent Profile 们：luna · kimi · cursor · fable · qwen · （将来的 SDK 腿）
```

orchestrator 是代码（确定性：推进状态、写通知、派发、观测逾期、供给工作区）。
bootstrap 期由人按脚本跑，目标态由服务跑。**实现可换，对象与边不可换。**

### 1.2 Task Profile `DEV_ROUND`

| 契约项 | 取值 |
| --- | --- |
| `profile_id` | `DEV_ROUND` |
| `profile_version` | `1`（首版；升级不得静默改变已受理 Task，内核 `:502-503`） |
| 输入 | 冻结工单（`round.md` + 可选 `task.md`）：题目、档位、验收条、只读输入锚、参与方名单 |
| 输出 | 共享最终路径上的已发布 Artifact；处置记录；本轮 `rulings.md` |
| 验收 | 工单冻结的验收条。T0 只能引用已签任务类包（上一轮 `refact-fable.md` 3.6 的形状仍可用，不绑部署形态） |
| 证据 | 各 Attempt 的 commit；评审 / 裁决 / 异议 / 验收 Artifact 的 hash；权力表行对应的回执（见 §3.4） |
| 策略 | 档位 T0/T1/T2 = 三张 guard / 必需产物 / interrupt 表，不是三套状态。`APPROVAL` 触点 T0=0 / T1=1 / T2=2（上一轮 §8 第 5 条幸存） |

`DEV_ROUND` 特殊只在一件事：我们正用现有助手开发运行时本身。运行时起来之后，后续开发仍走
`DEV_ROUND`，只是 orchestrator 从「人跑脚本」换成「运行时调助手」。财务分析是另一个 Task Profile，
共用同一状态机——这是 `task.md` §2.3「运行时的对象就是产品的对象」。

内核 `:26-27` 仍把开发字段指向一个已不再使用的落点名。这是内核自己的同名物残留。
修订写法见 §2.5，不在本文件外改内核。

### 1.3 五个 Agent Profile

| `agent_profile_id` | `kind` | `runtime` | 通道 | `observability` | 可自动分发 |
| --- | --- | --- | --- | --- | --- |
| `luna` | `agent-cli` | `codex-cli` | argv（`CODEX_HOME=~/.codex-official`） | `process` | 是 |
| `kimi` | `agent-cli` | `codex-cli` | argv（`CODEX_HOME=~/.codex-kimi`） | `process` | 是 |
| `cursor` | `agent-cli` | `cursor-agent` | argv（`agent -p`；`--model` 已钉在 `protocol-v2` `8e552cb6`） | `process` | 是 |
| `fable` | `agent-gui` | `cursor-app` | 无 argv；所有者在 GUI 投喂 | `session` | **否** |
| `qwen` | `agent-cli` | `qoder` | argv（`qoder -p`） | `process` | 是 |

`observability` 取值见 §3.1。`kind` 只取执行形态：`agent-cli` / `agent-gui` / `agent-sdk`。
没有第四种。人在这张表里不出现。

`agents.toml` 每条都假定可 argv 调起（`task.md` §6.4）。这是登记表的形状缺陷：
装得下 cursor，装不下 fable。目标形态加一个可空字段：

```text
dispatch = "argv" | "manual"
argv     = [...]          # dispatch=argv 时必填
channel  = "gui-session"  # dispatch=manual 时必填：人把固定指令送到哪
```

`dispatch = "manual"` 的执行者，运行时只能看见会话前后的文件系统差异——这是 `observability = session`
的定义，不是权宜。落点由所有者定（`protocol-v2` 或本轮工单）；本轮以 `task.md` §6.1 表为登记事实。

⚠ cursor 与 fable 同厂、共用多少 harness 内核未知（`task.md` §6.2.1）。按 `runtime` 字面是两组；
若 GUI 与 CLI 共用同一套工具面，独立性低于「两组」。本轮把两份稿的实质差异当观察值，不把「两组」当硬事实。
cursor 侧能核验的只有 argv 与 `--model` 钉死；fable 的模型在 GUI 里选，不可机械核验——
独立性折算里唯一不可复核的输入，照实登记。上一轮 cursor 用的什么模型没有记录，不能倒推。

### 1.4 bootstrap 与拆除

| | 今天（bootstrap） | 目标态 |
| --- | --- | --- |
| Task Profile | `DEV_ROUND` | 同一个 |
| 状态机 | 同一套 | 同一套 |
| orchestrator | 人 + `round-status.py` / `round-dispatch.py` + 手工投喂 | 运行时服务 |
| 载体 | git 文件 / commit / 分支 | PostgreSQL + 对象存储 |
| 分发 | 四家 argv + 一家手工 | 登记表 `dispatch` 字段；manual 仍要人，但 Interaction 有形状 |

git 载体是脚手架。**拆除条件（四条同时成立，缺一条不拆）**：

1. PostgreSQL 已持久化 Task / Attempt / Interaction / Event，且 I4（事件只追加、状态是投影，`:453`）有自动测试；
2. 至少 N 次真实 `DEV_ROUND` Task 在两种 orchestrator 下通过 §1.5 的**投影等价**（N 由所有者定，建议先 3，含一次 T0、一次 T2）；
3. 存在 agent 够不着的操作面（本轮 `rulings.md` `R2`：这是 S1 的前置；没有它，回执仓只是同一信任域搬家）；
4. T0 路径对人的必需动作数满足 §5.3 的上界——否则人绕过，账本有洞，拆了更糟。

拆除的是载体与 orchestrator 实现，不是对象、边、Interaction 形状、权力表。
`refact-fable.md` 3.13 的三道边界**不随脚手架拆除**（§3.3）。

git 载体验不了的三样，上一轮已经登记（`refact-fable.md` 3.11）：事务性、租约、fencing。
本轮不假装换了说法就能验。等价判据的「允许不同」包含载体，正是因为这三样只能在目标载体上验。

### 1.5 等效判据：两层，不是一条轨迹对到底

采纳 OP-1 的意图（同一 Task Profile 的一次执行，手工与运行时必须能对上），**反对它的形式**。

OP-1 把轨迹写成四要素一次比完，并规定 Interaction 形状不允许不同、执行者可观测粒度允许不同。
这两句放在一起，缺一个投影。理由：

- Interaction 是「向用户/审批者请求输入，以及对方的响应」（内核 `:98`），不是工具调用。
  SDK 腿看得见每一次工具调用；CLI / GUI 腿看不见。若把工具调用放进 Interaction 序列，
  两种模式永远不等价；若工具调用是 Event，OP-1 的「Interaction 序列」必须先声明它不含执行者私有事件。
- 手工模式的 Interaction **今天没有形状**（`task.md` §3.2：「看哪个」靠路径、「怎么看」靠人跑 diff、
  「能做什么」靠通知里的自然语言）。用上一轮真实产物做等价，只能**事后重建**，不是观测。
  重建是解释，解释不是机械比对。OP-1 当作本轮核心验收方式，在手工侧尚未被仪器化之前循环。

上一轮 cursor D1 抓到 ⑥→⑦ 隐含 `WAITING → SUCCEEDED`——内核没有这条边，只查词表抓不到
（`task.md` §2.1；`refact-fable.md:214-215`）。同一教训：轨迹若只比状态词、不比边，S 层是漏的。
OP-1 的「不允许不同」写了边，但没把边放进四要素的字段里——样例会只列状态点，漏掉非法边。

改写为两层：

| 层 | 比什么 | 何时可机械判 |
| --- | --- | --- |
| **S 层（schema）** | 对象集合、状态词、**边**、权力表行、Interaction 绑定字段 | 现在。候选给出字段即判 |
| **R 层（run）** | 同一 Task 的四条序列，经投影 Π 之后逐条对应 | 两种 orchestrator 都按同一 schema 落账之后 |

```text
轨迹（R 层，投影前）=
    Task 状态序列          # 每步是边 from→to，不是孤立状态点
  + 每个 Attempt 的状态序列
  + Interaction 序列（仅 human-facing：WAITING 的 INPUT/APPROVAL 及入向决策）
  + Artifact 版本序列（每版作者 = principal 或 agent_profile_id）

Π = 丢掉执行者私有 Event（工具调用、内部 token、GUI 会话内部步骤）
    保留 Task/Attempt 的边、权力表命中的 Interaction、Artifact 版本与作者

允许不同：载体、orchestrator 实现、Π 丢掉的那些 Event、执行者可观测粒度。
不允许不同：状态、边、对象、Interaction 形状（投影后）、谁在哪条边上有权（这是 S 层，不是 R 层字段）。
```

「谁在哪条边上有权」是权力表，是静态约束，不该塞进一次 run 的轨迹里比。
OP-1 把它放进「不允许不同」是对的，放进轨迹四要素是错的。

字段定义（R 层，投影后）：

| 要素 | 每条记录的字段 | 取值域 ⊆ |
| --- | --- | --- |
| Task 状态序列 | `at, from, to, reason_code?` | 内核 `:224-228` 的边；状态 ∈ {`RECEIVED`,`VALIDATING`,`QUEUED`,`RUNNING`,`WAITING`,`SUCCEEDED`,`REJECTED`,`FAILED`,`CANCELLED`} |
| Attempt 状态序列 | `attempt_id, agent_profile_id, at, from, to, failure_code?` | 内核 `:312-318`；状态 ∈ {`CREATED`,`RUNNING`,`WAITING`,`COMPLETED`,`FAILED`,`CANCELLED`,`BUDGET_EXCEEDED`} |
| Interaction 序列 | `interaction_id, direction, artifact_ref?, decision?, payload_artifact_id?` | §2.2 |
| Artifact 版本序列 | `artifact_id, version, type, author, parent_version?` | author ∈ 权力表 principal ∪ Agent Profile id |

样例见 §4。样例标注 ⚠ **重建**：上一轮没有按此 schema 落账，序列从 commit 与 `rulings.md` 反推。
它证明 S 层能装下真实历史；它**不**证明 R 层已可机械比对。这正是反对 OP-1 当本轮核心验收方式的证据。

---

## 2. P2 — Interaction 必须双向且带载荷

### 2.1 内核缺口（不是开发期特有）

现行绑定字段（`request-lifecycle.md:257-264`）：

```text
task_id, interaction_id, expected_state_version
question_or_action, audience, expires_at
resume_token_hash, idempotency_key, consumed_at
resume_target
```

出向是一句话；入向是布尔消费。所有者第 3 条（全部否定 / 部分否定 / 以自己的方案替代）装不进去。
`:297` 建新 Task 的条件是「修改目标、口径、授权范围或 Profile 版本」——部分否定一份分发方案时目标没变，
**不能绕成建新 Task**。财务分析交计划、人改两条让它照改，形状相同。所以这是内核缺口，
按 `:627` 走规范修订工作单元。

### 2.2 字段表：采纳双向，改写 OP-2

反对 OP-2 把「渲染形式 / 人可编辑范围」放进内核绑定，也反对入向只有 `approve / reject / amend` 三值。

理由：

- 所有者原话第三项是**以自己的方案替代**，不是在原文上改两个字。`amend`（范围内编辑）与
  `replace`（新 Artifact 整份顶替）对「下一次 Attempt 的输入」不同：前者是 base 版本 + 补丁，
  后者是新版本为唯一输入。压成一个 `amend` 会在财务计划场景里丢「人重写了整份计划」。
- `question_or_action` 已经是给人看的；渲染形式（diff / 全文 / 摘要）是 Delivery / `client_context`
  （内核提交信封已有 `client_context`，`:140`），不是 Interaction 身份字段。放进内核会让每次 UI 改动变规范修订。
- 可编辑范围是 `amend_schema`（哪些字段允许变），不是「人可编辑范围」这句自然语言。
- 入向若还要「再问一句」，那是新的 `WAITING(INPUT)`，不是 APPROVAL 的第四个值。不要塞进决策枚举。

**内核绑定字段（修订后）**：

```text
# 现行保留
task_id, interaction_id, expected_state_version
audience, expires_at
resume_token_hash, idempotency_key, consumed_at
resume_target

# 出向：替代 question_or_action 的结构化部分；旧字段保留一版作兼容投影
prompt_ref                  # 给人看的短问句（可空，若展示以 Artifact 为准）
subject_artifact_id
subject_artifact_version
decision_schema             # 本 Interaction 允许的入向决策集合
amend_schema                # decision 含 amend 时：允许改的字段 / 路径；否则空
# 渲染形式不在此。Delivery 按 audience 的 client_context 选 diff / 全文 / 摘要

# 入向
decision                    # approve | reject | amend | replace
response_artifact_id        # amend / replace 必填；approve / reject 可空
response_artifact_version
decision_note               # 短理由，不是载荷正文
```

入向四值与所有者原话：

| 所有者 | `decision` | 下一次 Attempt 的输入 |
| --- | --- | --- |
| 全部接受（隐含） | `approve` | `subject` 原版本 |
| 全部否定 | `reject` | 无；Task 按 Profile 超时/拒绝策略进 `FAILED` / 重新 `QUEUED`（换方案须新 Attempt，目标不变） |
| 部分否定 | `amend` | `subject` 为 base，`response` 为补丁，合并版本作者 = principal |
| 以自己的方案替代 | `replace` | `response` 为唯一输入，作者 = principal；`subject` 标 `SUPERSEDED`（Artifact 状态，不是 Task 状态） |

`response` 是新 Artifact 版本，成为**下一次 Attempt 的 `input_artifact_versions`**（内核 Attempt 已有此字段，`:326`）。
不建新 Task。

Delivery 侧（不进内核绑定）：`render_hint ∈ {diff, full, summary}`，由前端按 `client_context` 选；
缺省 `diff`（有父版本时）否则 `full`。这是投影，改它不改 Interaction 身份。

### 2.3 手工模式必须先长出这个形状

等效判据逼出来的不是「运行时要比手工多几个字段」，是**手工今天在跑的隐式动作必须显式化**。
否则 R 层永远在重建。bootstrap 期的最小仪器化（拆脚手架之前就要有）：

- 收件箱条目必填 `subject_artifact_id/version`（上一轮 3.4 已要求 `target_commit` / `diff_stat`，差的是 Artifact 身份）；
- 回执 yaml 加 `decision` + 可选 `response` 引用；
- 人在对话里说「同意」仍不算（`round-protocol.md`「异议稿必须冻结提交」同构）。

本轮对 fable 的投喂是样本：所有者把固定指令粘进 GUI，相当于一次隐式 Interaction，
但没有 `interaction_id`、没有 `subject`、没有 `decision`。账本看见的是「后来某分支多了一个 commit」。
S 层能描述这件事（orchestrator 的 manual dispatch）；R 层今天记不住「人看了哪份通知、做了什么决策」。
cursor 自己是 argv 分发，orchestrator 至少看得到「调了哪条命令」；GUI 那条腿连这点都没有。
仪器化必须按最弱腿设计，否则等价只对四家 CLI 成立。

### 2.4 这不是开发特有

`DATA_QUERY` / `RESEARCH` 把分析计划交人审，用同一张表。`F-INTERACT-01`（`:393-394`）
「把等待问题具体化为可直接回答的输入或可明确批准的动作」已经要求具体化；缺的是载荷与决策枚举。
`AT-07`（`:598`）继续覆盖令牌原子消费；加 `AT-07b`：`amend`/`replace` 产生的 Artifact 版本成为下一 Attempt 输入，
且不新建 Task。

### 2.5 修订工作单元

| | |
| --- | --- |
| **边界** | 只改 Interaction 绑定字段、`F-INTERACT-*`、`AT-07` 及新增 `AT-07b`。Task / Attempt 状态词与边不动。Delivery 的 `render_hint` 不进内核 |
| **顺带** | `:26-27` 那处过时落点名改指 Task Profile `DEV_ROUND`；`:18-19`「开发 Agent 与人的工作流程分别由 … 规定」改为「开发走 Task Profile `DEV_ROUND`，人的权力见权力表」。这是引用修复，不是状态修订 |
| **影响** | 已发出、未消费的 resume token：旧客户端只懂布尔消费，视为 `decision=approve` 且无 `response`（兼容一版，`payload_schema_version` 旧值）。新客户端必须带 `decision`。历史 Interaction 无 `subject` 的，投影为 `prompt_ref = question_or_action`，`subject` 空 |
| **迁移** | 事件 schema +1；旧行可读；新 Interaction 按新字段校验。工单 / 收件箱 / 回执 yaml 同步加字段，缺字段 = 条目无效（与上一轮 3.4「缺任一字段 = 无效」同构） |
| **验收** | `AT-07` 原集 + `AT-07b` + 「部分否定分发方案不建新 Task」一条可复现实验 |
| **不在本单元** | 文件树重画、R0–R5 路线、`protocol-v2` 五条待决、`pipeline-task.md` |

---

## 3. P3 — 可观测粒度是 Agent Profile 字段，决定证据权威

### 3.1 三档，不是两档

`task.md` §3.3 的表只写了 SDK 腿 vs CLI 腿。本轮有一个更弱的存在：fable——连 argv 都没有。
cursor 自己是 CLI，落在 `process` 档；两档装不下 GUI 那条腿。Agent Profile 必填 `observability`：

| 取值 | 运行时能看见 | 谁 |
| --- | --- | --- |
| `tool` | 每一次工具调用（参数、结果、时序） | 将来的 SDK 腿；运行时提供沙箱 |
| `process` | argv / stdin / stdout / 退出码 / 事后文件系统 | luna、kimi、**cursor**、qwen |
| `session` | 会话开始与结束时的文件系统差异；无 argv、无退出码、无 stdin 边界 | fable |

`F-EXEC-01`（只用 Agent Profile 允许的工具，`:381`）在 `tool` 档可执行；在 `process` / `session` 档
**执行不了**，只能事后审计。副作用拦截同理：`tool` 事中在工具层；另外两档事中拦不住，只剩外层边界。

cursor 作为 `process` 档的具体含义：orchestrator 看得到 `agent -p ...` 的 argv、退出码、工作区 diff；
看不见本次会话里读了哪些文件、调了哪些工具。自报「我只用了允许的工具」不采信。

### 3.2 证据权威性

```text
observability < tool  → 执行者自报一律不采信
                      → 证据由运行时从工作区重新推导（diff、复跑命令、门禁）
observability = tool  → 运行时自己记下的工具 Event 是权威；执行者自报仍不采信
```

`refact-fable.md:220-224` 把「`RUNNING` 目前判不了」归因于 git 载体。**归因错了**：
换成 PostgreSQL，看不见的仍是进程内部。这是执行者属性。`round-status.py` 把 `QUEUED`/`RUNNING`
合并标 ⚠（上一轮 §8 第 3 条，判据留、归因改）——对。事件文件落地也只证明 orchestrator 认为
「已派发 / 已回收」，证明不了进程内部到了哪一步。对 `session` 档，连「已派发」都只是
「人说已经把字粘进去了」。

本轮 `R2` 是同一条推论在**身份**上的极端例：所有者与 agent 共用 git 身份
`sunmoonlion <13701819268@163.com>`，无签名。commit 的 `author` 是自报，权威性与
`process` 档的 stdout 自报同类——**不采信**。要证明「人做了 H1」，必须从 agent 够不着的操作面
重新推导。那个面当前不存在（`R2` 原文）。所以本轮凡写「所有者确认」的行，证据强度为零；
方案把「S1 先有操作面」当作权力表所有 `auto_policy = 无` 行的强制点前提，而不是把
`rulings.md` + 同身份 commit 继续写成交接完成。

### 3.3 三道边界是架构组件，不随脚手架拆除

`refact-fable.md` 3.13.2 的三道边界：回执仓（防伪造回执）、主仓写权限移出 VM（防绕过发布）、
签名口令不缓存（防代签）。它们被写在「bootstrap 威胁模型」标题下，会有人跟着 git 载体一起拆。
**不能拆。**产品运行时调 CLI / GUI 助手时，内部 push、内部出网，事中同样拦不住。
外层仍是：进程能看见哪棵子树、env 里有没有凭据、出网走不走。

强制点在凭据层（上一轮 §8 第 2、6 条变强）：脚本与 hook 在 agent 可写面，不是边界。
`session` 档比 `process` 档更需要这三道——GUI 助手的内部工具面运行时完全看不见。
cursor 的 CLI 进程同样以 `zym` 跑在本 VM（`refact-fable.md` 3.13.1），够得着同一棵文件系统。

### 3.4 独占工作区：函数两边一样，强度两边不一样

`provision(...)` 的前置判据（独占 × 干净 × 基线，`refact-fable.md` 3.7）两边都用。
但：

| | `agent-sdk`（`observability=tool`） | `agent-cli` / `agent-gui` |
| --- | --- | --- |
| 工作区怎么来 | 挂进运行时沙箱 | 宿主上建目录，把路径告诉进程 |
| 进程看见什么 | 沙箱根 | **整个文件系统**（本 VM 上各 CLI 与 GUI 后端都以 `zym` 跑，`refact-fable.md` 3.13.1） |
| 「独占」是什么 | 隔离 | **约定**。打破约定的动作，运行时事中看不见 |

不得把两边写成同一强度。B 档账户隔离（专用 Unix 用户、不在 `sudo`/`docker` 组）能把约定抬成
OS 隔离，那是运维加固，不是 `provision` 函数已经给了的东西。

上一轮终稿把「fable 借用 cursor 目录」记为违反独占前置（`task.md` §6.1）。
那是约定被打破的实样：两个 Agent Profile 写同一 worktree，`git diff` 分不清作者。
本轮的纪律是路径隔离；运行时在 `process`/`session` 档**执行不了**这条纪律，只能事后从
「同一 worktree 上出现两个 `agent_profile_id` 的 commit」推导违约。

### 3.5 人的介入：边 + 权力表（登记表无人）

人不是 kind。人是 `principal = owner`（将来可加其他 principal，表结构不改）。
`DEV_ROUND` 里人会做的事，逐条落到边和行。**「把固定指令粘给不可分发的执行者」不在表里**——
那是 orchestrator 的 `dispatch=manual`，目标态仍可能由人做，它不是批准。

| # | 人的动作 | Task / Artifact 边 | 权力表行 | 回执 |
| --- | --- | --- | --- | --- |
| H1 | 冻结题目与验收条 | Artifact `DRAFT → FROZEN`；Task 在 `VALIDATING`，命中则 `VALIDATING → WAITING`，回执后 `WAITING → VALIDATING` | `P-FREEZE` | 操作面签名回执；本轮无操作面，证据强度为零（`R2`） |
| H2 | 开工确认（路由 / 名单 / 工作区） | `VALIDATING → QUEUED` | `P-ADMIT` | 同上；T0 由已签策略承担，落 `RouteDecision`，不产生回执 |
| H3 | 省事方向裁定 | 不改边；裁定行生效条件 = 回执存在 | `P-RELAX` | 同上 |
| H4 | 扩预算 / 扩范围 | 不改边；未批准不得派发超范围 Attempt | `P-EXPAND` | 同上 |
| H5 | 不可逆 Side Effect（写最终路径、push 主线） | ⑦ 的 orchestrator Attempt `COMPLETED` 后 `RUNNING → SUCCEEDED`；**没有** `WAITING → SUCCEEDED` 这条边（内核 `:228`） | `P-PUBLISH` | 凭据层：主仓对 VM 只读 |
| H6 | 推翻裁定 / 改已冻验收条 | 不覆盖旧行；新行 + 回执 | `P-OVERRIDE` | 同上 |
| H7 | 终止 | 非终态 → `CANCELLED`（先持久化意图，`:281-287`） | `P-CANCEL` | 失败安全，可不进回执仓 |
| I* | 回答 Interaction | 验证阶段 `WAITING → VALIDATING`；执行阶段 `WAITING → QUEUED`（`:269-270`） | `P-DECIDE`（audience 行） | `decision` + 可选 `response` Artifact |

`P-DECIDE` 的 `eligible_principal` 是 Interaction 的 `audience`，不一定是 `owner`
（产品侧可以是授权角色）。开发轮次里 audience 就是 `owner`。

H1–H7 的强制点、T0 任务类包、回执 schema，上一轮 3.3–3.4、3.13.4 仍适用——
那些段落绑的是权力与边界，没绑被推翻的那对部署形态。本轮不重写一遍，只改两处：
强制点前提加上「agent 够不着的操作面先存在」（`R2`）；Interaction 回执按 §2.2。

---

## 4. 轨迹样例：从 `refact-fable` 真实产物重建

⚠ **重建，不是观测。**上一轮没有按 §1.5 schema 落账。序列从 `7e8464c2` 上的文件反推。
用于证明 S 层装得下真实历史；R 层机械比对要等仪器化。

对象锚：

| 对象 | 出处 | 证据 |
| --- | --- | --- |
| Task | 重构方案本身（当时未赋 `task_id`；重建为 `T-refact-fable`） | `refact-fable.md` @ `7e8464c2` |
| 工单 Artifact v1 FROZEN | 同 commit 的 `rounds/refact-fable/rulings.md` R1 | 「三处进入 FROZEN」 |
| 候选 Artifact | `refact-fable.md` 927 行，sha256[:16] `89303624bfd9ef27` | 文件头冻结记录 |
| 评审 Artifact ×9 | `rounds/refact-fable/reviews/` @ `7e8464c2` | `git ls-tree` 九份 |
| 裁定 Artifact | 同目录 `rulings.md` R1–R8 | 「人确认 = 是」 |

Task 状态序列（每态 ⊆ 内核 `:233-242`；每步 ⊆ `:224-228`）：

| at（文档内时间，2026-09-05） | from → to | 依据 |
| --- | --- | --- |
| 起草开始 | （建单）→ `RECEIVED` | 文件被创建；空转进入下一态 |
| 同刻 | `RECEIVED → VALIDATING` | 工单在写，验收条未冻 |
| 11:30–12:40 多轮改稿 | 保持 `VALIDATING` | 修订记录在 `refact-fable.md:5-33`；并行 Attempt 在推进，按内核 `:276-277` 有一路可推进则保持（重建选择：当时没有把「等人」做成 Task 级 WAITING，人的意见在对话里——这是仪器化缺口） |
| 12:49 五家终审同意冻 | `VALIDATING → WAITING` | `waiting_reason=APPROVAL`；R1 依据栏 |
| 所有者签发 `7e8464c2` | `WAITING → VALIDATING` | 验证阶段等待回 `VALIDATING`（`:269`） |
| 同 commit 工单冻结完成 | `VALIDATING → QUEUED` | 契约固定（`:168`） |
| 发布进 master | `QUEUED → RUNNING` | ⑦ 类 Side Effect 开始（写共享路径） |
| 同 commit | `RUNNING → SUCCEEDED` | 结果已持久化。**不是** `WAITING → SUCCEEDED` |

中间若把「等人点头」做成 Task 级 WAITING，当时并行的评审 Attempt 按内核应把等待记在 Attempt 上、
Task 保持 `RUNNING`。上一轮终稿选择「中途 H 视为全 Task 暂停」（`refact-fable.md:217-218`）——
那是 `DEV_ROUND` 的 guard，不改内核边。本重建按**实际发生**（人在对话里点头、仓里一个 commit 收口）
走，所以 11:30–12:40 标为 `VALIDATING`/`RUNNING` 含糊。⚠ 含糊本身是证据：手工模式判不了
`QUEUED` vs `RUNNING` vs 「人正在看」。

Attempt 状态序列（子集；每态 ⊆ `:312-318`）：

| attempt_id | agent_profile_id | 序列 | 产物 |
| --- | --- | --- | --- |
| A-draft-* | `fable` | `CREATED → RUNNING → COMPLETED`（多次；每次改稿一次 Attempt，旧的不重开） | 候选各版 |
| A-rev-cursor | `cursor` | `CREATED → RUNNING → COMPLETED` | `review-refact-fable-cursor.md` + `review-final-cursor.md` |
| A-rev-kimi | `kimi` | 同上 | 对应两份 |
| A-rev-qoder | `qwen` | 同上 | 对应两份（文件名仍写 qoder） |
| A-rev-luna | `luna` | `… → COMPLETED`；曾 `RUNNING` 出 REQUEST CHANGES，后撤销 | `review-final-luna.md`；rulings R1 记 12:49 撤销 |
| A-rev-opus | （裁决方，非本轮参赛名单） | `COMPLETED` | `review-final-opus.md` |
| A-dispose | `fable` | `CREATED → RUNNING → COMPLETED` | `review-final-fable-response.md` |

Interaction 序列（重建；当时无 `interaction_id`）：

| 重建 id | direction | subject | decision | 实际载体 |
| --- | --- | --- | --- | --- |
| I-R3 | 入向 | T0 与零触点矛盾 | `replace`（人采纳第四种，不是在三个旧选项上 amend） | 对话 + 事后回填 `rulings.md` R3 |
| I-R7 | 入向 | 主仓写权限是否移出 VM | `approve`（「移」） | 对话 + R7 |
| I-H1 | 出向 | `refact-fable.md` 冻结稿 + §8 | （等人） | 终审文件 |
| I-H1-ack | 入向 | 同上 | `approve` | `7e8464c2`；回执形态 = rulings 行 + 同身份 commit（`R2` 已声明强度为零） |

Artifact 版本序列：

| artifact | version | author | 注 |
| --- | --- | --- | --- |
| `refact-fable.md` | 11:30 … 12:40 各一版 | `fable` | 文件头修订记录 |
| `refact-fable.md` | `7e8464c2` | `owner`（名义） | author 字段不可信，见 §3.2 |
| `rulings.md` | R1–R8 一次提交 | 同上 | R3–R8 备注写明是回填 |
| reviews ×9 | 各 1 | 各 Agent Profile | blob 在 `7e8464c2` |

投影 Π 之后，对话里的中间意见全部丢掉，只留带 commit 的决策。这就是手工模式「看起来在跑、
没有可搬运形状」的定量说法：I-R3 / I-R7 的出向 Artifact 与 `amend_schema` 都不可复原。

---

## 5. 必答 Q — 开销盈亏线

### 5.1 分类规则

运行时省的是 orchestration + 记忆 + 留痕 + 审批，不是「调用助手」本身（`task.md` §2.4）。

**机械规则**（只看工单字段，不看「读起来对」）：

```text
runtime_cheaper ≡
     executor_count >= 2
  OR tier ∈ {T1, T2}
  OR acceptance 含须人签的权力表行（H1/H2/H5 等，T0 除外）
  OR work_order.needs_resume = true          # 跨会话续接，工单布尔字段
  OR work_order.needs_audit_trail = true     # 审计链是完成契约的一条

runtime_dearer ≡ ¬ runtime_cheaper
               ∧ executor_count = 1
               ∧ tier = T0
               ∧ needs_resume = false
```

`executor_count`、`tier` 已在工单；`needs_resume` / `needs_audit_trail` 是本方案给工单加的两个布尔，
缺省 `false`。规则不读题目自然语言。

边界说明（非机械，防误读）：同形状反复跑、中途审批、并行评优，落在 `runtime_cheaper`。
一次性提问、单文件改动、一句话能说完，落在 `runtime_dearer`。

### 5.2 反例

**反例：改一处文档笔误，且落在已签 T0 任务类包的 `paths` 内。**

贵在哪一步：建工单（即使能自动填包名）+ 供给工作区 + 派发 + 回收 + 记 Event。
人开终端让助手改一行，约一次调用。运行时这边每步都是落盘与状态转换；对「改一个错字」
没有任何 orchestration / 记忆 / 审批收益可抵。

上一轮 §8 第 5 条把 T0 的 `APPROVAL` 触点钉成 0，不管总开销。本反例就是那条漏掉的部分。
若仍强制走运行时，人会开终端——账本出现一笔没有 Task 的改动。

不接受的说法：「都值得走，因为留痕总是好的。」留痕的成本高于这笔改动的价值时，留痕不会发生，
发生的是绕过。

### 5.3 T0 开销上界（不锚时钟）

T0 不被绕过，当且仅当对人来说，走运行时不比开终端多出可感知手续。可数上界：

| 计数 | 上界 | 怎么数 |
| --- | --- | --- |
| 人的必需动作 | **0**（开工到分发）+ **1**（H5 发布，若写共享最终路径） | 收件箱条目数 + 口令次数。T0 策略放行不得再要人点一次 |
| 落盘产物 | **≤ 4** | 工单、Attempt 产物、验收记录、（可选）H5 回执。多一张表即超 |
| 从提交到分发的步骤 | **≤ 2** | ① 幂等建单 ② 派发。中间不得再有「确认理解」「选执行者」「选工作区」 |

超任何一条，这条任务在策略上就不是 T0，应升 T1 或允许绕过并登记。
H5 仍在，是因为写共享最终路径不可逆（`P-PUBLISH`）；上一轮故意没加「可逆出口」（`refact-fable` rulings R6）。
本轮维持：免 H5 是省事方向，要单独开权力表行，不在这里偷加。

### 5.4 绕过的可观测性

反对 OP-3 第 4 问的前提：绕过发生在运行时之外，**运行时内没有观测点**。
方案不能承诺「让账本看见它看不见的东西」。能做的是另找采样面，并声明覆盖。

| 采样面 | 信号 | 覆盖 | 不覆盖 |
| --- | --- | --- | --- |
| 工作区脏状态 | `git status` 非空且无对应 `task_id` | 有人在 worktree 里干活没建单 | 纯只读提问；在 GUI 里看完没写盘 |
| 无主 commit | 分支上出现 `task_id` 对不上的 commit | 改被提交了 | 改了又扔 |
| GUI 会话 | 编辑器窗口打开在某 worktree，但无 `active_task_id` | fable 所在的那类面；投喂若没绑 Task，就是绕过候选 | CLI 助手在别的终端 |
| 终端历史 | 对 `codex`/`agent`/`qoder` 的直接调用，argv 不含 `task_id` | 四家 CLI 的手工调用（**含 cursor 自己**） | 加密历史、别的机器 |

处置：命中记一条 `BYPASS_CANDIDATE` Event（或 bootstrap 期 `rulings.md` 观察值），
**不自动变 Task、不自动惩罚**。与 `task.md` §2.4「按既有纪律登记，不自动触发任何动作」一致。
覆盖声明：这些信号是候选不是证明；零命中不能写成「没有绕过」——那是「没查到」
（`round-protocol.md`「判据自身的质量」）。

cursor 自己若被直接 `agent -p` 且 argv 不含 `task_id`，就是上表「终端历史」的一列。
要把 CLI 调用绑上 Task，派发脚本必须把 `task_id` 写进 argv 或环境；手册粘贴的调用默认算候选绕过。

---

## 6. 对 OP-1 / OP-2 / OP-3 的表态

| 编号 | 表态 | 理由 |
| --- | --- | --- |
| OP-1 | **改写** | 意图留：同一 Task Profile 的一次执行必须能对上。形式拆成 S 层 / R 层，中间加投影 Π。权力表是 S 层，不进轨迹四要素。边必须进状态序列字段（D1 同类漏检）。手工侧未仪器化之前，R 层样例只能重建，不能当本轮核心机械验收。§1.5 |
| OP-2 | **改写** | 双向带载荷留。入向四值 `approve/reject/amend/replace`，区分部分否定与整份替代。渲染形式出内核、进 Delivery。可编辑范围改 `amend_schema`。§2.2 |
| OP-3 | **部分反对** | Q1–Q3 的形式留（分类、反例、可数上界）。Q4 的问法不成立：绕过在账本外，方案只能提名外部采样面并声明覆盖，不能承诺内生可观测。给不出反例按未答——这条留，§5.2 给了反例 |

「同意框架」不计入优点。以上三处是有理由的改写 / 反对。

---

## 7. 本任务书里的同名物（加分项，不是范围外闲话）

内核已经用 Task Profile / Agent Profile。本任务书大部分时候用对了。还活着的风险：

1. **内核 `:26-27` 仍指向过时落点名**——规范自己的第三义还在正文里。§2.5 纳入修订单元。
2. **「轨迹」不是内核对象。**OP-1 把它当验收原语，不声明它是 Event 序列的投影，会变成第四个「Profile」。
   本方案把轨迹定义为投影后的四条序列，权威仍是 Event。
3. **「绕过」不是内核对象。**Q4 若诱使各家造一个 Bypass 状态，就走了反模式。本方案只加
   `BYPASS_CANDIDATE` 观察 Event，不进状态机。
4. **orchestrator**：代码角色，bootstrap 期由人按脚本执行。说「人是 orchestrator」会让人重新变成执行者。
   本方案说「人跑 orchestrator 脚本」，人不是那个角色。

---

## 8. 人的权力与 `DEV_ROUND` 生命周期对照（供脚本扫「无缺项」）

```text
RECEIVED ──→ VALIDATING ──┬── WAITING(APPROVAL/H1) ──→ VALIDATING ──→ QUEUED
                          ├── WAITING(INPUT)           ──→ VALIDATING
                          └── REJECTED

QUEUED ──→ RUNNING ──┬── WAITING(APPROVAL/H3-H6 或 I*) ──→ QUEUED
                     ├── WAITING(DEPENDENCY/RESOURCE/EXTERNAL) ──→ QUEUED
                     ├── SUCCEEDED          （H5 门后的 Side Effect 已落）
                     ├── FAILED
                     └── CANCELLED          （H7）
```

Attempt 组：每一家在每一环节一次 Attempt；产物是 typed Artifact（候选 / 评审 / 异议 / 验收）。
选择「Attempt 可产 typed Artifact」而不是「每环节一个 child Task」——后者让 T2 一轮七个 Task。
这是产物类型细化，不改 Attempt 边。若内核维护者视为扩充，并入 §2.5 的修订单元写一句声明。

---

## 9. 盲区与不做

- 未读他家本轮候选（① 隔离）。
- 未在宿主复核 3.13.1 的 uid 表；引用上一轮已复核事实，并受 `R2` 约束。
- cursor 实际模型按所有者口述 + `protocol-v2` 钉死登记；fable 模型不可核验。独立性数字本轮不当硬输入。
- 未设计文件树、未重排 R0–R5、未碰 `protocol-v2` 五条待决、未预判 `pipeline-task.md`。
- 财务分析 Task Profile 的验收（判断且昂贵）只声明「不要用开发门禁冒充」，本轮不设计它的验收器。
- `N` 次投影等价的具体数字留给所有者；这里只把条件写下。

做不成的标 ⚠ 的，都在正文里：R 层样例是重建；本轮回执证据强度为零；`session` 档看不见派发。
