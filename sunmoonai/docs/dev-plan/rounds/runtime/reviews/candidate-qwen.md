参与方：qwen｜worktree：/home/zym/worktrees/qwen/k8s｜HEAD：4513bcbd6a47b9032f2db31d614430947c29fa5d

# 产品运行时架构：开发作为第一个 Task Profile

> 本文件是 qwen 对轮次 runtime 的候选方案。
>
> 只读输入：
> - `working/request-lifecycle.md` @ `70a7dd50`（647 行，sha256[:16] `6fcd3973ede30b88`）
> - `refact-fable.md` @ `7e8464c2`（927 行，sha256[:16] `89303624bfd9ef27`）
>
> 本文不改以上两份只读输入；要改之处写进正文。

## 0. 核心主张

1. **只有一个产品运行时**，它实现 `request-lifecycle.md` 定义的通用对象与唯一状态机（`request-lifecycle.md:203-229`）。
2. 今天的开发工作不是第二个运行时，而是该产品运行时的第一个 **Task Profile**（`profile_id = "DEVELOPMENT"`）。
3. 五家 AI 助手不是运行时本身，而是执行该 Task Profile 的五个 **Agent Profile**。
4. 人的每一次介入都对应唯一状态机的一条边和权力表的一行；人不作为执行者 kind 登记。
5. 手工模式（人 + shell 脚本）与运行时模式是同一个 Task Profile 的两种 orchestrator 实现，必须通过**等效判据**校验。

## 1. P1：只有一个运行时，开发是一个 Task Profile

### 1.1 对象层：一个运行时 + 唯一状态机

运行时的对象层就是 `request-lifecycle.md:92-104` 定义的七类对象：

| 对象 | 在开发场景中的实例 |
| --- | --- |
| Task | 一次开发任务（如本轮 runtime） |
| Attempt | 一家在一个环节的一次交付（如 qwen 的提案 Attempt） |
| Interaction | H1/H2/H5 等人对 orchestrator 的响应 |
| Artifact | 工单、候选、评审、裁决、验收、最终稿 |
| Event | 状态转换、Attempt 创建与终态、Interaction 消费 |
| Side Effect | 写共享最终路径、push 主线 |
| Delivery | 候选通知、评审通知、最终稿发布 |

状态机只有 `request-lifecycle.md:206-229` 描述的那一套：

```text
Task:    RECEIVED → VALIDATING → QUEUED → RUNNING ⇄ WAITING
                         → SUCCEEDED | FAILED | CANCELLED | REJECTED
Attempt: CREATED → RUNNING ⇄ WAITING
                         → COMPLETED | FAILED | CANCELLED | BUDGET_EXCEEDED
```

开发任务不新增任何状态词，也不走内核没有的边。`refact-fable.md:187-213` 的映射表正是这条纪律的实例。

### 1.2 开发作为 Task Profile

```text
profile_id:        "DEVELOPMENT"
profile_version:   "1"
input_schema:
  - problem_statement      # 题目与范围
  - acceptance_criteria    # 逐条验收标准
  - baseline_commit        # 基线 commit
  - scope_boundary         # 明确不做什么
output_schema:
  - candidate_artifact_ref # 提案产物
  - review_artifact_ref    # 评审产物（T1/T2）
  - disposition_artifact_ref # 裁决处置记录（T2）
  - acceptance_artifact_ref  # 验收产物（T1/T2）
  - final_artifact_ref     # 最终稿
acceptance:
  - 机械门禁通过（doc-gate.py、链接检查、表格列数）
  - 轨迹与手工模式等价
  - 不出现禁用词（见 §8）
  - 登记表无禁用 kind
evidence:
  - git commit 序列
  - events.jsonl（Attempt 级事件）
  - Interaction 记录
policy:
  - tier: T0/T1/T2 按 `round-protocol.md:62-70` 判据
  - orchestrator: 人工+脚本（bootstrap） / 运行时服务（目标态）
```

该 Task Profile 的核心特殊之处仅在于：它正在建造运行时本身。一旦运行时建成，后续产品开发同样通过它进行，只是 orchestrator 从「人调脚本」变成「服务自动调度」。

### 1.3 五家 Agent Profile

| executor_id | kind | runtime | observability_granularity | roles_allowed |
| --- | --- | --- | --- | --- |
| luna | agent-cli | codex-cli | process | proposer, acceptor |
| kimi | agent-cli | codex-cli | process | proposer, acceptor |
| cursor | agent-cli | cursor-agent-cli | process | proposer, acceptor |
| fable | agent-app | cursor-app | process | proposer, acceptor |
| qwen | agent-cli | qoder-cli | process | proposer, acceptor |

说明：
- `kind` 取值只区分**触发通道**，不区分执行者是否是人。人不作为 kind 登记（`round.md:28-31` 已将 human kind 列为机械判禁用项）。
- `fable` 的 kind 为 `agent-app`，因为它没有命令行入口，由 Cursor 桌面应用触发（`task.md:269-284`）。这是 `agents.toml` 当前形状无法登记的特例，见 §3.4。
- `observability_granularity = process` 表示运行时只能看到进程级边界；这与 SDK 腿的 `tool_call` 粒度形成对比，见 §3。

### 1.4 bootstrap 与目标态的关系

今天的 orchestrator 是人运行 `round-status.py`、`round-dispatch.py`、写 `call-<环节>.md`、手工投喂 fable。目标态的 orchestrator 是运行时服务自己。

**这是同一个 Task Profile 的两种实现，不是两层架构。** git 载体（文件、tag、回执仓）是 bootstrap 脚手架，拆除条件：

1. 运行时服务能按 `request-lifecycle.md:3.2` 持久化 Task/Attempt/Event 主档；
2. 运行时服务能为每个 Attempt 供给隔离工作区；
3. 运行时服务能向全部五家执行者派发 Attempt；
4. 至少有一轮 T2 全程通过运行时跑通，并通过 §1.5 的等效判据；
5. 存在一个 agent 够不着的人的操作面（本轮 `rulings.md:R2` 已把这点列为 S1 前置）。

### 1.5 等效判据

同一个 Task Profile 的一次执行，手工模式与运行时模式产生的**轨迹**必须逐项对应。

```text
轨迹 = Task 状态序列
     + 每个 Attempt 的状态序列
     + Interaction 序列（含出向载荷与入向响应）
     + Artifact 版本序列（含每版作者）
```

允许不同：
- 载体：文件 ↔ 表；
- orchestrator 实现：人+脚本 ↔ 服务；
- 执行者可观测粒度：进程级 ↔ 工具调用级。

不允许不同：
- 状态词与合法转换边；
- 对象（Task / Attempt / Interaction / Artifact / Event / Side Effect / Delivery）；
- Interaction 形状（见 §2）；
- 谁在哪条边上有权（见 `refact-fable.md:3.3` 权力表）。

#### 1.5.1 用 refact-fable 轮的真实产物导出样例轨迹

以 `refact-fable` 轮为源，轨迹可抽象为：

```text
Task state sequence:
  RECEIVED → VALIDATING → QUEUED → RUNNING
  → WAITING(APPROVAL)   # H1 冻结题目
  → QUEUED → RUNNING
  → WAITING(APPROVAL)   # H2 开工确认
  → QUEUED → RUNNING
  → WAITING(APPROVAL)   # ⑤ 验收后 H5 发布确认
  → QUEUED → RUNNING → SUCCEEDED

Attempt state sequences (each proposer):
  CREATED → RUNNING → COMPLETED   # 提案 Attempt
  CREATED → RUNNING → COMPLETED   # 评审 Attempt
  CREATED → RUNNING → COMPLETED   # 验收 Attempt

Interactions:
  H1: outbound=工单草案 + 验收条； inbound=approve
  H2: outbound=路由/参赛者/工作区计划； inbound=approve
  H5: outbound=待发布 commit + diff； inbound=approve + acceptance 结论

Artifact versions:
  candidate-luna@v1  author=luna
  candidate-kimi@v1  author=kimi
  candidate-cursor@v1 author=cursor
  candidate-fable@v1  author=fable
  candidate-qwen@v1   author=qwen
  review-luna@v1      author=luna
  ...
  final@v1            author=opus(integrator) after H5
```

该样例中所有 Task 状态都 ⊆ `request-lifecycle.md:206-229` 的状态集合，所有边都 ⊆ 同节的「合法转换」表。

## 2. P2：Interaction 必须是双向且带载荷的

### 2.1 当前内核的缺口

`request-lifecycle.md:257-264` 的 Interaction 绑定字段只有：

```text
task_id, interaction_id, expected_state_version
question_or_action, audience, expires_at
resume_token_hash, idempotency_key, consumed_at
resume_target
```

响应只有「消费令牌」一个布尔动作。这装不下 `task.md:1.3` 第 3 条判断：人可全部否定、部分否定或以自己的方案替代。

### 2.2 扩展后的 Interaction 字段表

出向载荷（presented_to_principal）：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `artifact_ref` | string | 展示哪个 Artifact |
| `artifact_version` | int | 展示哪个版本 |
| `render_mode` | enum | `diff` / `full` / `summary` / `structured` |
| `editable_range` | object | 人可编辑的范围（行号 / 字段路径 / none） |
| `question_or_action` | string | 自然语言说明 |
| `allowed_decisions` | enum[] | 本 Interaction 允许的决策集合 |

入向载荷（principal_response）：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `decision` | enum | `approve` / `reject` / `amend` |
| `amend_artifact_ref` | string | amend 产生的新 Artifact（decision=amend 时必填） |
| `amend_artifact_version` | int | 版本号 |
| `principal` | string | 响应主体（权力表 eligible_principal） |
| `consumed_at` | timestamp | 消费时间 |

### 2.3 amend 载荷成为下次 Attempt 输入的路径

```text
Attempt N 产出 Artifact X@v1
  → Interaction 出向展示 X@v1
  → principal 选择 amend，提交 amend_payload
  → 运行时创建 Artifact X@v2，author = principal
  → Attempt N+1 的 input_artifact_versions 包含 X@v2
  → Attempt N+1 执行
```

这一点必须在 Attempt 记录中显式登记：`input_artifact_versions` 包含由 amend 产生的版本（`request-lifecycle.md:323-332` 已要求 Attempt 记录 input/output Artifact 版本，这里只是把 amend 来源写清楚）。

### 2.4 不能绕成「建新 Task」

`request-lifecycle.md:296-298` 规定，只有修改目标、口径、授权范围或 Profile 版本时才建新 Task。部分否定一份分发方案时目标未变，只是同一 Task 内的输入版本更新，因此走 Interaction 恢复 + 新 Attempt，不走新 Task。

### 2.5 这是内核修订，不是开发期特例

财务分析 agent 交一份分析计划给人审、人改两条让它照改，形状完全相同：出向展示 Artifact，入向返回 amend 载荷，amend 版本成为新 Attempt 输入。因此这不是某个 Task Profile 的私货，而是 `request-lifecycle.md` 的通用 Interaction 需要扩展。

#### 2.5.1 修订工作单元的边界

按 `request-lifecycle.md:625-636` 的修订纪律，本修订工作单元为：

- **边界**：`Interaction` schema 的出向/入向字段；`resume_token` 消费逻辑；`Attempt.input_artifact_versions` 的来源；原子消费边界。
- **影响分析**：所有使用 `APPROVAL` 类 Interaction 的 Task Profile 自动获得 amend 能力；现有 boolean `consumed_at` 逻辑需要改为 tri-value。
- **迁移方案**：
  - 新增 `interaction_schema_version = 2`；
  - 历史 v1 Interaction 保持 `approve/reject` 语义；
  - v2 Interaction 启用 tri-value + amend payload；
  - 支持 v1/v2 共存一个 minor 版本；
  - 下一 major 版本废弃 v1。

## 3. P3：执行者的可观测粒度进 Agent Profile

### 3.1 Agent Profile 增加粒度字段

| 字段 | 取值 | 含义 |
| --- | --- | --- |
| `observability_granularity` | `tool_call` | 运行时能看到每一次工具调用、每一次读写 |
| `observability_granularity` | `process` | 运行时只能看到 argv / stdin / stdout / 退出码 / 事后文件系统 diff |

当前五家均为 `process` 粒度（`task.md:201-208`）。未来运行时自己的 agent（SDK 腿）可登记为 `tool_call`。

### 3.2 证据权威性的后果

**对于 `process` 粒度执行者，自报证据一律不采信。** 运行时只能从工作区重新推导证据：

- 哪些文件被修改：工作区 diff；
- 修改内容是否匹配声称：逐字节比较；
- 命令是否可复跑：用相同 argv 在干净工作区重跑并比较结果。

`refact-fable.md:220-225` 把 `RUNNING` 不可判归因于 git 载体，这个归因错了。换成 PostgreSQL 载体，如果执行者仍是 `process` 粒度，运行时同样看不到进程内部，因此仍然无法判 `RUNNING`。真正决定可观测性的是 **Agent Profile 的粒度字段**，不是持久层载体。

### 3.3 三道边界是架构组件

`refact-fable.md:3.13` 的三道边界（工作区隔离、env 凭据、出网控制）不是 bootstrap 期的临时安全措施，而是调用 CLI 执行者时**必须保留**的架构组件。原因：CLI 助手内部 push、内部出网，运行时事中拦不住，只剩外层边界可用。

| 边界 | 对 SDK 腿（tool_call） | 对 CLI 腿（process） |
| --- | --- | --- |
| 工作区可见范围 | 真沙箱隔离 | 只能限定目录，进程仍可见整个文件系统 |
| env 凭据 | 由运行时注入，精确到 Attempt | 依赖宿主 env，只能过滤/覆盖 |
| 出网 | 工具网关逐调用审批 | 只能在外层防火墙/代理限制 |

### 3.4 CLI 腿上「独占工作区」只是约定

`refact-fable.md:3.7` 的 provision 函数两边一样，但隔离强度不同：

- SDK 腿：工作区挂在真沙箱内，进程文件系统视图被限制；
- CLI 腿：运行时在宿主建一个目录，把路径传给进程；该进程以宿主用户运行，看得见整个文件系统。独占性靠「运行时只传这个目录」的约定维持，不是隔离。

本方案如实声明这一差异，不在两边使用相同的措辞掩盖强度差别。

### 3.5 fable 的极端情形：连 argv 都没有

fable 是 GUI 应用触发，`agents.toml` 当前形状无法登记「存在但不可自动分发」的执行者（`task.md:353-361`）。对运行时可观测性而言，这是 `process` 粒度的极端：

- 看不到 argv；
- 看不到 stdin/stdout；
- 只能看到文件系统前后差异。

因此 fable 的 Agent Profile 必须额外声明 `dispatch_channel = "manual_feed"`，运行时只验证「该 worktree 下出现了预期的候选 commit」，不验证触发过程。

## 4. 必答 Q

### 4.1 Q1：分类规则

走运行时**净成本更低**的特征（至少满足一条）：

1. 需要跨会话续接；
2. 需要审计链；
3. 需要中途人审批；
4. 需要并行 fan-out（T2）；
5. 同形状反复执行，可模板化。

走运行时**净成本更高**的特征：

1. 一次性、一句话能说清的活；
2. 单文件、单点改动；
3. 无需留痕、无需审批、无需复现。

**机械可判规则**：若工单字段满足 `expected_interaction_count > 0 OR fan_out_count > 1 OR repetition_key IS NOT NULL`，则判定走运行时净成本更低。该规则直接由工单字段导出，不依赖「读起来对」。

### 4.2 Q2：反例

**反例：改一个 README 的笔误。**

手工模式成本：
1. 人打开文件；
2. 改一个字；
3. `git diff` 确认；
4. `git commit`。

运行时模式成本：
1. 创建 Task 记录；
2. 解析 Task Profile；
3. 分配 attempt_id；
4. provision 工作区（clone / checkout 基线）；
5. 派发 Attempt 给 agent；
6. agent 改文件；
7. 提交候选；
8. 跑机械门禁；
9. 生成 H5 Interaction；
10. 人审批；
11. 写共享最终路径 / push 主线。

贵在哪一步：
- **工作区供给**（步骤 4）和 **H5 确认**（步骤 9-11）把一次 10 秒的操作变成十步以上、跨分钟的操作。
- 对于无需审计、无需审批、无需复现的一次性改动，运行时的 orchestration + 留痕 + 审批开销超过其价值。
- 这正是 `task.md:125-126` 警告的失败模式：T0 若比开终端贵，人就会绕过它。

### 4.3 Q3：T0 开销上界判据

T0 不被绕过的可判上界（不锚时钟）：

```text
human_required_actions ≤ 1      # 只允许最终的 H5 确认
persisted_artifacts    ≤ 3      # Task 记录、diff、最终产物
commit_to_dispatch_steps ≤ 2    # RouteDecision 落账、dispatch
```

若任一指标超标，该任务不应标 T0，应升 T1/T2 或走手工。该判据可数、可机械检查、不受机器速度影响。

### 4.4 Q4：绕过的可观测性

绕过发生在运行时之外，账本天然看不见。本方案通过以下方式让它可观测：

1. **工作区路径审计**：所有合法产物必须出现在运行时 provision 的 worktree 路径下。出现在外部路径的修改即为疑似绕过。
2. **commit 元数据检查**：合法 commit 必须携带 `task_id` 与 `attempt_id`。缺失即为绕过。
3. **受保护路径扫描**：定期比对 `sunmoonai/docs/dev-plan/` 等权威路径的实际修改与 ledger 中的 Task 记录；无 Task 记录的修改记为绕过。
4. **人报告通道**：在 `handoff.md` 或 `rulings.md` 中登记「本次改动绕过了运行时」的声明，作为审计证据。
5. **绕过率观察值**：按任务类别统计实际走运行时的比例；某类任务比例过低即说明运行时在那一类上开销超过价值（`task.md:129-130`）。

## 5. 对 OP-1 / OP-2 / OP-3 的表态

### 5.1 OP-1：等效判据

**采纳，但须补充。**

OP-1 提出的轨迹四要素（Task 状态序列、Attempt 状态序列、Interaction 序列、Artifact 版本序列）与允许/不允许差异清单是必要基础。但轨迹等价只检查**动态行为**；本轮验收还需要**静态结构检查**（如禁用 Profile 词组、禁用 human kind、Agent Profile 字段完整性）。两者缺一不可。

因此本方案把 OP-1 作为 P1 的核心验收方式，同时保留 §8 的机械结构判据。

### 5.2 OP-2：Interaction 双向带载荷

**反对。**

OP-2 的字段表把「展示 Artifact + 渲染形式 + 可编辑范围」和「approve/reject/amend + amend 载荷」做成所有 Interaction 的通用扩展。这与 `request-lifecycle.md:180-181` 的纪律冲突：「只有歧义会实质改变结果、权限、成本或风险时才请求澄清」，而简单 `INPUT` 类 Interaction（如问一个缺失参数）不需要携带 Artifact 版本和 amend 载荷。

**改写建议**：在 Interaction schema 中增加 `interaction_class` 字段，把 payload-heavy 的 bidirectional schema 限定在 `APPROVAL_WITH_ARTIFACT` 类 Interaction；`INPUT`、`DEPENDENCY`、`RESOURCE`、`EXTERNAL` 仍用轻量 schema。这样既能满足人可部分否定/修改分发方案的需求，又不把重型载荷强加给所有 Interaction。

### 5.3 OP-3：必答 Q 的四问形式

**采纳第 1、2、4 问；改写第 3 问。**

第 3 问建议把 T0 开销上界锚在「人的必需动作数」「落盘产物数」「从提交到分发的步骤数」这类可数的东西上，方向正确，但单一项容易被 gaming。本方案改用**复合开销向量** `(human_required_actions, persisted_artifacts, commit_to_dispatch_steps)`，并规定任一维度超标即不标 T0。这样比单数上界更难绕开。

## 6. 其他关键纪律

### 6.1 禁用词检查

候选全文不出现 §8 所列禁用 Profile 词组。

本方案使用：
- 「产品运行时」或「运行时」；
- 「Task Profile `DEVELOPMENT`」；
- 「Agent Profile」。

### 6.2 人不作为执行者 kind

权力表引用 `principal = "owner"`，不引用 human kind。人的介入全部映射到唯一状态机的一条边（如 `WAITING(APPROVAL)`）和权力表的一行（H1-H7）。

### 6.3 只读输入未改动

本候选不修改 `refact-fable.md` 与 `working/request-lifecycle.md`；所有改法写进本文 §2.5、§3 等节。

### 6.4 锚定

本文中的现状断言均附 `file:line` 或可复跑命令：
- `request-lifecycle.md:203-229`（状态机）
- `request-lifecycle.md:257-264`（Interaction 当前字段）
- `request-lifecycle.md:296-298`（建新 Task 条件）
- `request-lifecycle.md:625-636`（修订纪律）
- `task.md:201-208`（可观测粒度对比表）
- `task.md:125-126`（绕过失败模式）
- `task.md:353-361`（fable 登记问题）
- `refact-fable.md:187-213`（开发任务映射表实例）
- `refact-fable.md:220-225`（RUNNING 不可判归因）
- `refact-fable.md:3.7` / `refact-fable.md:493-509`（工作区 provision）
- `refact-fable.md:3.13`（三道边界）
- `round.md:28-31`（禁用 human kind）

## 7. 与既有规则的衔接

### 7.1 与 `constraints.md` 的关系

- `constraints.md:A1`：新增业务智能体优先新增 Profile 而非 fork 代码。本方案把开发工作落为 Task Profile `DEVELOPMENT`、五家助手落为五个 Agent Profile，符合该条。
- `constraints.md:A3`：四本账必须落 PostgreSQL。本方案在目标态由运行时服务承担四本账；bootstrap 期用 git 事件 + 文件投影，并明确声明 bootstrap 期验证不了事务性、租约、fencing（`refact-fable.md:594-599`）。

### 7.2 与 `round-protocol.md` 的关系

本方案把 `round-protocol.md` 的七环节理解为运行时中 `DEVELOPMENT` Task Profile 在 `tier = T2` 时的 guard 表与必需产物表，不是第二个状态机。

## 8. 验收自检

| 验收标准 | 本方案处理位置 |
| --- | --- |
| §8-1 只有一个运行时 | §0、§1.1、§6.1 |
| §8-2 无 human kind | §1.3、§6.2 |
| §8-3 等效判据可执行 | §1.5、§1.5.1 |
| §8-4 Interaction 双向 | §2.2、§2.3、§2.4、§2.5 |
| §8-5 可观测粒度 | §3.1、§3.2、§3.3、§3.4 |
| §8-6 必答 Q 四问全答 + 反例 | §4.1、§4.2、§4.3、§4.4 |
| §8-7 对 OP-1/2/3 表态 | §5.1、§5.2、§5.3 |
| §8-8 锚定 | 全文 `file:line` |
| §8-9 只读输入未改动 | §6.3 |
| §8-10 身份自证 | 首行 |
