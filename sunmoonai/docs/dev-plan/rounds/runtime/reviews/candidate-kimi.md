参与方：kimi｜worktree：/home/zym/worktrees/kimi/k8s｜HEAD：4513bcbd6a47b9032f2db31d614430947c29fa5d

# 运行时架构：一个运行时，开发是它的第一个 Task Profile

> 轮次 runtime ① 候选（kimi）。依据：`runtime/h1:sunmoonai/docs/dev-plan/rounds/runtime/task.md`（427 行，
> sha256[:16] `c31aa01cff556abd`）。只读输入：`refact-fable.md`（927 行，sha256[:16] `89303624bfd9ef27`，
> master `7e8464c2`）与 `working/request-lifecycle.md`（647 行，sha256[:16] `6fcd3973ede30b88`，
> 末次提交 `70a7dd50`），本文不改动这两个文件；对内核的改法全部以「修订工作单元」形式写在正文（§2.4）。
> 引用按标题不按章节号。凡断言现状的句子附 `file:line` 或可复跑命令；行号以只读输入的冻结版本为准。

## 0. 摘要

1. **只有一个运行时。**它实现 `request-lifecycle.md`「两层状态机」定义的唯一状态机与全部对象
   （Task / Attempt / Interaction / Artifact / Event / Side Effect / Delivery）。今天的「开发」
   是跑在它上面的一个 Task Profile（`profile_id = "DEV"`，§1.2），五家助手是五个 Agent Profile（§1.3）。
   上一轮的 A/B 分层之所以是假分叉，自证在 `refact-fable.md:180`：杀「第三个分层」的那条理由
   （五格全同、只差 guard——同构分层与按场景另造状态词是同一类膨胀）对 A/B 本身逐字成立。
2. **Interaction 必须双向带载荷。**内核 `request-lifecycle.md:257` 的入向只有「消费令牌」一个布尔动作，
   装不下所有者的第 3 条判断（全部否定 / 部分否定 / 以人的方案替代）。这是内核缺口，按
   `request-lifecycle.md:627` 的修订纪律走规范修订工作单元（§2.4），不是在开发侧打补丁。
3. **可观测粒度是 Agent Profile 的登记字段，决定证据权威性。**进程级执行者的自报一律不采信，
   证据由运行时重新推导（§3.2）。`refact-fable.md:238` 把「`RUNNING` 判不了」归因于 git 载体——
   归因错了：换 PostgreSQL 一样判不了 CLI 进程内部，这是执行者属性（§3.2）。
4. **手工模式与运行时模式是同一 Task Profile 的两种 orchestrator 实现**（§1.4），等效判据
   给出可机械比对的轨迹四要素与比对规则（§1.5），并用 refact-fable 那一轮的真实产物导出一条
   trace 样例（§1.6）。
5. 对 OP-1 / OP-2 / OP-3 的表态：**改写 / 改写（含一处反对）/ 采纳但改写过强预设**（§5）。

**覆盖声明（P4）**：本文覆盖 task.md §3 的 P1/P2/P3 与必答 Q；不覆盖 §4 排除的四项
（文件树重画、R0–R5 重排、protocol-v2 五条待决、pipeline-task 轮）。未验证项逐处标 ⚠。

## 1. P1 — 一个运行时，开发是一个 Task Profile

### 1.1 对象层：唯一状态机，不多一个词

对象与状态全部取自 `request-lifecycle.md`「核心对象」与「两层状态机」（@ `70a7dd50`）：

```text
Task:    RECEIVED → VALIDATING → QUEUED → RUNNING ⇄ WAITING
                  → SUCCEEDED | FAILED | CANCELLED | REJECTED
Attempt: CREATED → RUNNING ⇄ WAITING
                  → COMPLETED | FAILED | CANCELLED | BUDGET_EXCEEDED
对象:    Interaction · Artifact · Event · Side Effect · Delivery
```

纪律沿用内核 `request-lifecycle.md:505`（新增领域应新增 Task Profile 和相容 Agent Profile，
不修改通用状态语义）与 `:580` 反模式表（修改通用状态机 → 第二套生命周期）。「开发」这个领域
因此只能落为一个 Task Profile；它的每一环节、每份产物、每种异常都要能指到唯一状态机里的
一个状态或一个对象——`refact-fable.md` §3.1.1 那张映射表（202 行起）已经做过这份练习，
其「无新词、无内核外的边、内核每个状态有落点」三条自检原样保留，只有一处归因要改（§3.2）。

**词的归位**：`request-lifecycle.md:103-104` 已定义 Task Profile 与 Agent Profile；上一轮稿里的
A/B 是它自造的第三个含义（持久层+执行者+通道+guard+状态判定的整套部署形态）。本文只用内核的两个词；
「部署形态」这类差异全部落为 **orchestrator 实现、载体、通道** 三个事实字段，不占用 Profile 这个词。

### 1.2 开发 Task Profile：`profile_id = "DEV"`

```toml
[task_profile]
profile_id      = "DEV"
version         = "0.1-draft"            # 首版须按其第一个开发工作单元的真实输入输出确认后发布
input_schema    = { 原始请求文本/结构化输入, 附件(稳定引用+校验值), 基线 commit, 题目边界 }
output_schema   = { 交付物(代码/文档/裁定), 证据, 副作用清单 }
renderer        = { diff | 全文 | 结构化摘要 }   # 与 §2 的 Interaction 出向 presentation 同一词表
acceptance      = 逐条编号、尽量机械可判；T0 只能引用已签策略里的任务类包（refact-fable.md §3.6）
evidence        = 按 §3.2 的证据权威性规则：自报不采信，运行时重新推导
strategy        = { tier ∈ T0/T1/T2, 预算=观察窗/轮次上限/回退上限, 重试=新 Attempt,
                    interrupt 策略=权力表（§7） }
```

两点说明：

- **DEV 不特殊化状态机。**它的「环节」（①–⑦）是 guard 表 + 必需产物表的投影，不是状态词；
  「档位」是同一状态机上的三张表（`refact-fable.md` §3.6「档位 = 三张表，不是三套状态」）。
- **开发的验收机械且便宜（测试、门禁、diff），财务分析的验收判断且昂贵**（task.md §2.5 风险 2）。
  DEV 作为第一个 Task Profile 只证明对象形状与状态转换跑得通；验收器对「判断且昂贵」那一半
  不能从 DEV 的经验外推，必须在财务 Profile 的第一个工作单元里用真实验收用例重证
  （内核 `request-lifecycle.md:521` 已有同义要求：每个 Profile 的首个开发工作单元确认字段后再发布）。

### 1.3 五个 Agent Profile

完整登记表（含可观测粒度字段）在 §6，此处给名单满足点名要求：

| agent_profile_id | provider | runtime（harness） | 调用方式 |
| --- | --- | --- | --- |
| `agent/luna` | openai | codex-cli | `codex exec`（`CODEX_HOME=~/.codex-official`） |
| `agent/kimi` | moonshot | codex-cli | `codex exec`（`CODEX_HOME=~/.codex-kimi`） |
| `agent/cursor` | 所有者口述 grok；⚠ 上一轮无记录不可倒推 | cursor-agent（CLI） | `agent -p` |
| `agent/fable` | anthropic（GUI 内选择，不可机械核验） | cursor-app（GUI） | 无命令行入口，手工投喂 |
| `agent/qwen` | — | qoder | `qoder -p` |

（调用方式与 ⚠ 项的事实来源：task.md §6.1、§6.2.1。）

**人不在登记表里，不是执行者 kind。**人是 principal（`owner`），持有权力表（§7）的行；
人的每次介入是唯一状态机的一条边上的 guard 触发，逐条对照见 §7.2。

### 1.4 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现

```text
            同一个 Task Profile「DEV」、同一套状态机与对象
   ┌────────────────────────────┬────────────────────────────┐
   │ 手工模式（今天，bootstrap） │ 运行时模式（目标态）        │
   ├────────────────────────────┼────────────────────────────┤
   │ orchestrator 实现：         │ orchestrator 实现：         │
   │ 人运行 round-status.py /    │ 运行时服务内嵌的确定性代码   │
   │ round-dispatch.py；分发靠   │（routing / 分发 / 观测 /    │
   │ 人逐家投喂（本轮即如此，    │ 回收 全自动）               │
   │ round.md「待自动化」）      │                             │
   │ 载体：git（commit/tag/      │ 载体：PostgreSQL + 对象存储  │
   │ 落盘文件/回执仓）           │（事务、租约、fencing 可验） │
   │ 通道：argv / 收件箱文件     │ 通道：ExecutorPort /        │
   │                            │ Interaction + resume token  │
   └────────────────────────────┴────────────────────────────┘
```

**orchestrator 是代码，不是角色。**这里要点出任务书自己造的一个同名物苗头（task.md §5 另注
邀请指出此类问题）：task.md §3.1 写「今天的 orchestrator 是人 + shell 脚本」——而
`refact-fable.md` §3.9 已立硬约束「orchestrator 必须是代码，不得是 agent 角色；过渡期由人
运行脚本是『可自动』欠账，不是角色」。把「人 + 脚本」命名为 orchestrator，等于把欠账重新
命名为组件，下一轮就会有人对着这个名字设计接口。本文统一：**orchestrator = 确定性代码；
手工模式里人是它的触发通道**（round-protocol「执行者与触发方式」判据：内容常量、只需送达 →
可自动，缺的只是可寻址通道）。

**git 载体那套是脚手架，要拆。**拆除条件（全部机械可判）：

1. 运行时模式对 DEV 的等效比对（§1.5）连续 **3 轮** T2 零不允许差异（载体与 orchestrator
   实现差异属允许项，不计）；
2. PostgreSQL 载体通过内核验收矩阵中依赖并发语义的三项：`AT-09`（租约/迟到写入）、
   `AT-14`（取消竞争）、`AT-15`（重启重建）——git 载体验不了这三样
   （`refact-fable.md` §3.11 已如实登记）；
3. `rounds/` 产物 → 运行时 Task/Event/Artifact 账的一次性迁移完成且抽样回放无缺口。

未满足前 git 载体继续服役；**但 §3.3 的三道边界不是脚手架**，不随拆除消失。

### 1.5 等效判据：轨迹四要素 + 比对规则（对 OP-1 的改写，理由见 §5.1）

**轨迹定义**（采纳 OP-1 的四要素，字段化）：

```text
trace = {
  task_states:        [ {state, entered_by_edge, evidence_ref} ],        # state ⊆ Task 状态集
  attempts:           [ {attempt_id, executor, states: [...],            # state ⊆ Attempt 状态集
                         input_artifact_versions, output_artifacts} ],
  interactions:       [ {interaction_id, direction, audience,
                         outbound: {subject_artifact_ref, presentation, editable_scope},
                         inbound: {response_kind, payload_ref}, edge} ],
  artifact_versions:  [ {artifact_id, version, author, supersedes} ]
}
```

**比对规则**（这是对 OP-1 的实质补充，四条）：

1. **逐要素 diff，白名单制。**允许不同（白名单）：载体（文件 ↔ 表）、orchestrator 实现、
   执行者可观测粒度。不允许不同：状态、边、对象、Interaction 形状、谁在哪条边上有权。
   白名单之外的差异一律判失败，不设「看起来等价」。
2. **比对粒度取较粗一腿，并声明未比对项。**手工模式的 trace 里没有逐工具调用事件
   （CLI 执行者进程级可观测，§3.1），所以事件级字段不参与判等，必须显式列为「未比对」——
   否则粒度较细一侧的天然丰富会被误判成差异，或反过来，粗一侧的缺失被默认成一致。
   这一条直接来自 P4（round-protocol「判据自身的质量」：覆盖不全比没有更危险）。
3. **两边的 trace 都要声明权威源。**手工模式的 trace 是从 git 提交**重建的投影**
   （`refact-fable.md` §3.11：权威是 commit，工作区文件永不作判据）；运行时模式的权威源是
   Event 账。投影参与比对前必须说明重建规则，否则比对的是两份各自编的故事。
4. **权限归因字段在 bootstrap 期强度为零，单列判。**「谁在哪条边上有权」属不允许不同项，
   但 R2（`opus:sunmoonai/docs/dev-plan/rounds/runtime/rulings.md`）登记：本机无签名、
   所有者与 agent 共用 git 身份，手工模式的「人批准」在账本上与 agent 提交不可区分。
   处置：该项仍比对（形状必须一致），但证据强度字段标 `bootstrap-zero`，
   **运行时模式不得把手工模式的回执继承为可信先例**；S1（所有者够得着的操作面）是该字段
   转为可判的前置（R2 已登记）。

### 1.6 trace 样例：从 refact-fable 轮真实产物导出

对象：产生 `refact-fable.md` 的那一轮（round id `refact-fable`）。全部锚点可复跑：

```bash
git for-each-ref 'refs/tags/refact/*' --format='%(refname:short) %(objectname:short)'
git log --oneline 7e8464c2 -- 'sunmoonai/docs/dev-plan/rounds/refact*'
```

```yaml
trace_sample:
  task_states:                                  # 全部 ⊆ 内核 Task 状态集（脚本可判）
    - {state: RECEIVED,   evidence: "rounds/refact-fable/ 目录首个 commit"}
    - {state: VALIDATING, evidence: "任务书 Artifact DRAFT（起草期多次修订）"}
    - {state: WAITING, reason: APPROVAL, evidence: "H1 冻结前等待；rulings R1 以所有者 commit 7e8464c2 生效"}
    - {state: VALIDATING, evidence: "H1 成立 → WAITING→VALIDATING（验证阶段恢复边）"}
    - {state: QUEUED,     evidence: "分发完成，候选期开始"}
    - {state: RUNNING,    evidence: "①–⑤ 各环节进行；五家候选 tags refact/{luna,kimi,cursor,qwen,...}"}
    - {state: SUCCEEDED,  evidence: "7e8464c2 冻结发布（H1，bootstrap 例外）"}
  attempts:                                     # 摘三个，状态全部 ⊆ Attempt 状态集
    - {id: "luna@①", executor: "agent/luna", states: [CREATED, RUNNING, COMPLETED],
       output_artifacts: ["refact/luna @ e41e646a"]}
    - {id: "kimi@①", executor: "agent/kimi", states: [CREATED, RUNNING, COMPLETED],
       output_artifacts: ["refact/kimi @ e33fac68"]}
    - {id: "integration@③", executor: "arbiter(fable 起草→各家吸收)", states: [CREATED, RUNNING, COMPLETED],
       output_artifacts: ["refact/integration @ 36bfa5c2"]}
  interactions:
    - {id: "H1-freeze", direction: out, audience: owner,
       outbound: {subject_artifact_ref: "refact-fable.md §8 九条", presentation: 全文, editable_scope: 无默认字段},
       inbound: {response_kind: approve, payload_ref: null},
       edge: "WAITING(APPROVAL) 恢复", evidence_strength: "bootstrap-zero（R2）"}
    - {id: "luna-request-changes", direction: in, audience: arbiter,
       inbound: {response_kind: amend, payload_ref: "luna 终审 REQUEST CHANGES → 12:40 版吸收（撤销）"},
       note: "手工模式下这次 amend 的载荷=自然语言评审+后续版本，形状是隐式的（见 §2.1）"}
  artifact_versions:                            # refact-fable.md 修订记录自证五版
    - {artifact_id: "refact-fable.md", version: "11:30", author: "fable"}
    - {artifact_id: "refact-fable.md", version: "11:45", author: "fable（吸收 opus/luna+所有者裁定）", supersedes: "11:30"}
    - {artifact_id: "refact-fable.md", version: "12:00", author: "fable（吸收 kimi/qoder+裁定）", supersedes: "11:45"}
    - {artifact_id: "refact-fable.md", version: "12:15", author: "fable（吸收 cursor+裁定）", supersedes: "12:00"}
    - {artifact_id: "refact-fable.md", version: "12:40→7e8464c2", author: "fable（吸收五家终审）", supersedes: "12:15"}
```

未比对项（按比对规则 2 声明）：逐工具调用事件、每次 Attempt 的内部进度、模型版本与 token 消耗——
手工模式无一落盘，属于粒度外字段，不是「已验证一致」。

## 2. P2 — Interaction 双向且带载荷

### 2.1 缺口：内核的入向是布尔的

`request-lifecycle.md:257` 的 Interaction 绑定字段：

```text
task_id, interaction_id, expected_state_version
question_or_action, audience, expires_at
resume_token_hash, idempotency_key, consumed_at
resume_target
```

入向只有 `resume_token_hash` + `consumed_at`——响应被压成「消费/未消费」一个布尔。
所有者的第 3 条判断（全部否定 / 部分否定 / 以自己的方案替代）装不下：
「部分否定一份分发方案」需要把「否定哪几条、改成什么」作为载荷带回来。

而且这三件事今天在手工模式里全是隐式的：「看哪个」靠 worktree 路径、「怎么看」靠人自己跑
`git diff`、「能做什么」靠通知里的自然语言（task.md §3.2 同此诊断）。手工模式**看起来**在跑，
实际没有可搬运的形状——§1.6 样例里 `luna-request-changes` 那行的 amend 载荷就是自然语言评审，
运行时模式下这种形状无法落账。

**为什么不能绕成「建新 Task」**：`request-lifecycle.md:297` 规定建新 Task 的条件是
「修改目标、口径、授权范围或 Profile 版本」。部分否定一份方案时目标、口径、授权都没变，
变的只是方案的若干条款——新建 Task 会白白丢失原 Task 的预算账、证据账与血缘（I1/I11），
且违反「终态不可转出、重开建新实体」的语义初衷（那是给「换目标」用的，不是给「改方案」用的）。

**这不是开发期特有**：财务分析 agent 交分析计划给人审、人改两条让它照改，形状完全相同。
所以按内核修订走，不在 DEV 侧打补丁。

### 2.2 扩展后的绑定字段表

出向（引擎 → 受众），在现有字段上**新增三个必填**：

```text
subject_artifact_ref   { artifact_id, version }        # 展示哪个 Artifact 的哪个版本
presentation           { render_mode: diff | full | structured_summary,
                         base_version }                # diff 模式必给基线版本
editable_scope         { scope: none | regions[...] | full_replace }  # 人可编辑范围，机器可判
```

入向（受众 → 引擎），把布尔响应**替换为三值 + 载荷**：

```text
response_kind          approve | reject | amend
amend_payload_ref      Artifact 引用；response_kind=amend 时必填
response_state_version 消费时校验 = task.state_version，不等即 stale 拒绝
```

规则：

1. **amend 载荷成为一个新 Artifact 版本**：`author = 应答 principal`，`supersedes =
   subject_artifact_ref.version`；越出 `editable_scope` 的 amend 拒收（editable_scope 是约束，
   不是展示提示——理由见 §5.2 对 OP-2 的反对）。
2. **该载荷成为下一次 Attempt 的输入**：恢复后按内核 `WAITING → QUEUED` 边走，
   新 Attempt `CREATED` 时 `input_artifact_versions` 钉到 amend 产生的新版本
   （内核 Attempt 字段已有 `input_artifact_versions`，`request-lifecycle.md:388` 区域）。
3. `approve` / `reject` 不带载荷；`reject` 的后续（重开 Attempt / FAILED / CANCELLED）按
   Task Profile 的策略走，不新增状态。
4. 出向 `presentation.render_mode` 与 DEV Profile 的 renderer 词表同源（§1.2），
   财务 Profile 复用同一词表加领域取值。

### 2.3 与手工模式的对照

今天手工模式下这三样的实际对应物（如实声明其隐式性）：

| 字段 | 手工模式今天是什么 | 缺什么 |
| --- | --- | --- |
| subject_artifact_ref | 通知里的 worktree 路径 + 分支名 | 版本由「当前 HEAD」隐式给出，评审对象可漂移 |
| presentation | 人自己跑 `git diff` | 渲染形式无登记，diff 基线靠人记 |
| editable_scope | 通知里的自然语言 | 无机器可判约束 |
| amend 载荷 | 评审文件 / 裁定文字 | 不成为 Artifact 版本，不进下次 Attempt 输入 |

等效判据（§1.5）比的是形状不是载体：手工模式要把这四样显式化（通知字段、Artifact 版本化），
才有资格谈与运行时模式逐条对应。这是等效判据逼出来的返工，属预期成本。

### 2.4 规范修订工作单元（按 `request-lifecycle.md:627` 修订纪律）

- **边界**：只动 Interaction 相关三处——`:257` 绑定字段表、「WAITING 与 Interaction」一节的
  恢复语义、`§6.2` 持久化账的 Interaction 行；以及 `AT-07` 扩一条（amend 载荷越界拒收、
  stale 拒绝）。不动 Task/Attempt 状态集与合法边（本次修订零新状态、零新边）。
- **影响分析**：(a) 事件 schema 升 `payload_schema_version`，旧客户端按 `AT-19` 兼容或明确拒绝；
  (b) 历史 Interaction 记录无 `response_kind`——迁移为 `legacy` 标记（语义=已消费，无载荷），
  不伪造三值回填；(c) `editable_scope` 无默认（P3：默认值属省事方向），缺省即 `none`（最严），
  想要可编辑必须显式声明；(d) 对 DEV：收件箱条目 schema 同步扩展（§2.3 表即其字段来源），
  `refact-fable.md` §3.4 的「必备字段」清单追加这三项。
- **迁移方案**：先加字段后改语义的两步——(1) 字段以可选进入，运行双写观察一轮；
  (2) 一轮无异常后升必填、布尔消费路径下线。修订记录保留旧语义（布尔消费）与变更原因，
  按 `:627` 要求不让曾经生效的合同无痕消失。

## 3. P3 — 可观测粒度进 Agent Profile 与证据权威性

### 3.1 粒度字段

Agent Profile 新增登记字段 `observability_granularity`，取值（至少三档，由细到粗）：

| 取值 | 运行时能看见什么 | 典型 |
| --- | --- | --- |
| `per_tool_call` | 每一次工具调用的输入输出，事中 | 运行时自家 agent（SDK 腿，沙箱由运行时提供） |
| `process_only` | argv / stdin / stdout / 退出码 / 事后文件系统 | luna、kimi、cursor、qwen（CLI 助手） |
| `fs_diff_only` | 仅文件系统前后差异；连 argv 都没有 | fable（GUI，无命令行入口；task.md §6.4 登记表形状问题即此） |

配套字段：`sandbox_owner`（`runtime` / `executor` / `unknown`）、`side_effect_interception`
（`in_band` / `outer_boundary_only`）。fable 这类条目同时回答 task.md §6.4 的形状问题：
登记表不得假定执行者可由 argv 调起，`invocation` 字段取值含 `manual`（存在但不可自动分发）。

### 3.2 证据权威性推论

**进程级（及更粗）执行者的自报证据一律不采信。**「我用了哪些工具、读了哪些文件、
测试全过」这类自报，运行时无法从事中记录验证，只能当线索；证据必须由运行时从工作区
**重新推导**：diff 比对、复跑命令（测试、门禁、脚本）、独立取证（`file:line` 复核）。
上一轮已有实样：qwen 拿休眠代码 `profiles.py:36-41` 当能力证据，九份评审无一发现
（task.md §2.1 记录）——自报被采信时的失败形态。

**`refact-fable.md:238` 的归因要改**（task.md §7 第 3 条「判据留、归因改」的执行）：
「`RUNNING` 目前判不了」被归因于 git 载体缺事件文件——错。换成 PostgreSQL 一样判不了：
CLI 进程内部对运行时不可见，缺交付是「未调用 / 在跑 / 崩了 / 失联 / 超时」五选一，
这不是账本载体的缺陷，是**执行者的可观测粒度属性**。更正后的表述：
`RUNNING` 的细分判据 = 载体事件（必要条件）× 执行者粒度（充分条件上限）；
`process_only` 执行者的 Attempt 在事中只能判「已分发未交付」，`QUEUED`/`RUNNING` 合并标 ⚠
的处置（`refact-fable.md` §8 第 3 条）保留，但 ⚠ 的原因改写为本段。

### 3.3 三道边界是架构组件，不随脚手架拆除

`refact-fable.md` §3.13.2 的三道边界（回执仓、主仓写权限移出 VM、签名口令不缓存）现在被归在
「bootstrap 威胁模型」里，会随 git 脚手架一起被拆掉——这是分类错误。CLI 助手内部 push、
内部出网，运行时事中拦不住，只剩外层边界：

| 边界 | 对 CLI 腿的含义 | 目标态归属 |
| --- | --- | --- |
| 凭据层 | agent 进程 credential domain 内不得有可写主仓/回执仓凭据（`check-no-owner-creds.sh`，§3.13.5 第 3 条；它是配置卫生检查不是边界） | 运行时供给工作区时的 env 构造规则 |
| 文件系统子树 | CLI 进程能看见整个宿主文件系统（见 §3.4） | 运行时只能收缩进程可见子树（容器/用户隔离），无法靠约定 |
| 出网 | 事中拦不住，只能外层断网/代理 | 运行时网络策略，按 Agent Profile 声明 |

所以这三样进运行时架构的**执行环境设计**，不进「bootstrap 待拆清单」。
产品运行时调 CLI 助手时一样需要（task.md §3.3 后果 2）。

### 3.4 独占工作区在 CLI 腿上是约定，不是隔离（如实声明）

provision 纯函数（`refact-fable.md` §3.7）两边一样，但强度不一样：

- **SDK 腿**：工作区挂进运行时提供的沙箱——真隔离，进程看不见沙箱外；
- **CLI 腿**：在宿主建目录、把路径传给进程——那个进程看得见整个文件系统，
  「独占」只是它不写的承诺，不是它不能读的约束。

本文不让两边看起来强度相同：登记表 `isolation_strength` 字段逐家填（§6），
CLI 腿一律 `convention_only`。后果：CLI 腿 Task 的授权范围声明（I3）只能依赖
「事后审计可发现越权读取」，不能依赖「事中读不到」；涉及第二租户/真实财务数据前，
CLI 腿的数据源必须经过运行时的数据网关，不得给裸库凭据。

### 3.5 R2 的极端案例：人当前没有 agent 够不着的操作面

R2 登记：本机无 GPG、git 未配签名、所有者 Cursor/Qoder 均 Remote 连入同一 VM，
H1 签发 `94558713` 与 agent 提交在账本上不可区分——权力表的回执形态当前证据强度为零。
方案处理三层：

1. **如实标强度**：权力表每行加 `receipt_strength` 字段（`cryptographic` / `bootstrap-zero`），
   本轮全部行为 `bootstrap-zero`；等效比对中权限归因项单列（§1.5 规则 4）。
2. **不得以弱回执为先例**：运行时模式的回执语义按 `cryptographic` 设计（回执仓 +
   主仓写权限移出，`refact-fable.md` §3.13.2）；bootstrap 期的弱回执只是让流程能走，
   不构成对设计目标的折让。
3. **前置登记**：R2 已把「所有者需要一个 agent 够不着的操作面」列为 S1 前置——本文采纳，
   并补一句：该操作面同时是 §1.5 规则 4 中权限归因项转为可判的前置；没有它，
   「谁在哪条边上有权」这条「不允许不同」项在两种模式下都只能判形状、判不了事实。

## 4. 必答 Q

### 4.1 分类规则

运行时省的不是「调用助手」的成本，是 orchestration + 记忆 + 留痕 + 审批的成本
（task.md §2.4 同此判断）。规则：

**走运行时净成本更低**（满足任一）：
- 需要跨会话续接（上下文重讲是手工模式最大的重复成本）；
- 需要留痕（决定了什么、为什么）或需要任何 `WAITING(APPROVAL)` 触点；
- 并行多执行者（T2）或 `write_actors ≥ 2`；
- 有副作用须幂等记账，或产物须入证据账；
- 同形状反复跑的活。

**走手工净成本更低**（全部满足）：单会话可完成、无审批、无副作用、产物一次性、无复用。

**机械可判规则（M1）**：由工单字段直接判——`write_actors ≥ 2` **或** `review_needed = true`
**或** acceptance 含任何非机械条目 **或** 副作用清单非空 → 必须走运行时；
四者皆否且 `est_exchanges ≤ 2`（提交时在工单上声明）→ 允许走手工。
判据挂在字段上不挂「读起来对」；`est_exchanges` 事后与实际值对照进观察值，虚报会留痕。

### 4.2 反例

**反例一：一次性提问。**例：「这个正则为什么匹配不上这段文本」。走运行时更贵，贵在固定开销：
建工单（`VALIDATING` 要固定归一化目标与完成契约）、RouteDecision 落账、Attempt 建档、
结果信封 + 事件落盘、⑦ 清理——约 6 个落盘动作；手工模式是 0 个（开终端一句话约十秒）。
而运行时卖的那四样（续接、留痕、审批、并行）对该类任务收益为零。净成本为正是
task.md §2.4 已预警的形态：对它收全套手续费，人就绕过，账本出洞。

**反例二：目标未定的探索性对话。**人还没想清楚要什么时，契约固定不了，
`VALIDATING` 会在「澄清—改目标—再澄清」间反复空转，每次往返都是一次 Interaction 全手续；
此时「修改目标」按 `:297` 还得建新 Task，一轮探索产生一摞短命 Task。手工聊天没有任何此类开销。
（这类任务一旦目标收敛，应升格建 Task——分类规则管的是入口，不是禁止升级。）

### 4.3 T0 开销上界判据

T0 不被绕过的可判上界（锚可数物，不锚时钟）：

| 指标 | 上界 | 超出则 |
| --- | --- | --- |
| 开工前人的必需动作数 | **0** | 该任务类不得留在 T0 包 |
| 全程人的必需动作数 | ≤ 1（H5 发布签名） | 同上 |
| 一次 T0 执行的落盘产物数 | ≤ 4（工单、RouteDecision、结果、验收记录） | 运行时减重或该类升 T1 |
| 从提交到分发的 orchestrator 步骤数 | ≤ 2（路由落账 → 分发） | 同上 |

上界按任务类包逐个考核（包即 `policies/tier-defaults.toml` 的条目，`refact-fable.md` §3.6），
实测值进观察值；哪个包持续超界，说明它装的不是 T0。

### 4.4 绕过的可观测性

先说限度：绕过发生在运行时之外，账本**天然看不见**——「完全可观测」不可达，
pretend 可达就违反 P4。方案是三层，没有一层承诺全知：

1. **让绕过无利**：主线写入只经 H5（凭据层强制，§3.3），绕过的产物永远进不了交付面；
   绕过的最大动机（快）被保留为合法路径（T0 上界，§4.3），次大动机（交付）被凭据层封死。
2. **采样对账**：⑦ 清理时与定期地，diff「分支/worktree 上有提交但账本无对应 Task」的集合；
   命中即作为绕过实例登记 `rulings.md` 观察值（task.md §2.4 的「绕过率」按既有纪律登记，
   不自动触发动作）。声明覆盖范围：此检查只看 git 可见面，看不见未落盘的绕过。
3. **成本侧归因**：绕过率按任务类统计；某类持续高绕过 = 运行时在那一类上开销超过价值的
   实证信号，触发对该类包设计或上界的重审（人触发，不自动）。

## 5. 对 OP-1 / OP-2 / OP-3 的表态

### 5.1 OP-1（等效判据形式化）：**改写**

采纳轨迹四要素与允许/不允许清单的骨架；反对其默认「两份 trace 可直接逐条比对」的隐含假设，
理由三条（已落进 §1.5 比对规则）：

1. 两腿可观测粒度不同（§3.1），事件级字段在手工腿上根本不存在——不比声明「未比对」，
   比对结果就把「粒度差」误读成「行为差」或「虚假一致」；
2. 手工 trace 是 git 重建投影，不声明重建规则与权威源，比对的是两份叙事而非两份事实；
3. R2 现状下权限归因强度为零，混入「不允许不同」项一起判，会把不可判项伪装成已判项。

没有这三条，OP-1 恰好犯它要治的病：把方法论口号变成**看起来**机械、实际不可复核的比对。

### 5.2 OP-2（Interaction 字段表）：**改写，含一处反对**

采纳三值（approve / reject / amend）+ amend 载荷成为新 Artifact 版本并进下次 Attempt 输入
的主结构。**反对把「人可编辑范围」定位为出向展示字段**：只展示不强制，它就会在第一个
「人改了范围外一条」的场景退化成自然语言提示，三值随之退化为「布尔 + 全文替换」。
`editable_scope` 必须是机器可判的**入向约束**：amend 载荷的 diff 越出声明范围即拒收，
拒收事件落账。另补两处 OP-2 没有的：`response_state_version` 并发校验（amend 到达时
Task 已前进则为 stale，拒绝——否则人会改一份已经不是当前版本的方案）；amend 版本必须带
`supersedes` 链（否则 Artifact 血缘断在最关键的一跳：人的修改覆盖了谁的版本）。

### 5.3 OP-3（必答 Q 四问形式）：**采纳，但改写过强预设**

四问结构采纳（四问全答见 §4）。一处改写：Q4 的措辞「怎么让它可观测」预设了绕过可观测——
而绕过按定义发生在账本外，**完全可观测不可达**；诚实的回答必须先承认限度再分层
（§4.4 的三层：无利、对账、归因）。这个问题形式若不改，会奖励「看起来有机制」的回答，
惩罚如实声明覆盖边界的回答——与 P4 的教训（覆盖不全的检查比没有更危险）同源。

## 6. 执行者登记表（Agent Profile 表）

唯一登记表；`roles_allowed` 只能取已注册角色（proposer / arbiter / acceptor）；
人不在表中（§1.3）。router 与 orchestrator 无 agent 实现（`refact-fable.md` §8 第 1 条幸存）。

| agent_profile_id | provider | runtime | model_family | invocation | observability_granularity | sandbox_owner | side_effect_interception | isolation_strength | roles_allowed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `agent/luna` | openai | codex-cli | （未钉） | `codex exec` | `process_only` | `executor` | `outer_boundary_only` | `convention_only` | proposer, acceptor |
| `agent/kimi` | moonshot | codex-cli | kimi-k3 | `codex exec` | `process_only` | `executor` | `outer_boundary_only` | `convention_only` | proposer, acceptor |
| `agent/cursor` | 口述 grok ⚠ | cursor-agent | `cursor-grok-4.6-high`（`protocol-v2` `8e552cb6` 已钉） | `agent -p` | `process_only` | `executor` | `outer_boundary_only` | `convention_only` | proposer, acceptor |
| `agent/fable` | anthropic（口述，GUI 选择不可机械核验 ⚠） | cursor-app | Claude Fable 5.1（`refact-fable.md:3` 记「Fable 5.1」，与 `agent --list-models` 的 `claude-fable-5-thinking-*` 对不上，task.md §6.2 已登记） | `manual`（无 argv） | `fs_diff_only` | `unknown` | `outer_boundary_only` | `convention_only` | proposer |
| `agent/qwen` | — | qoder | （未钉） | `qoder -p` | `process_only` | `executor` | `outer_boundary_only` | `convention_only` | proposer, acceptor |
| `agent/sdk-*`（目标态形态，未存在，⚠ 非能力证据） | — | 运行时内嵌 | — | ExecutorPort | `per_tool_call` | `runtime` | `in_band` | `sandboxed` | （目标态登记） |

⚠ 逐项：cursor 的模型口述为 grok、上一轮无记录不可倒推（task.md §6.2.1）；fable 的模型
与 NO ZDR 状态均为口述事实（task.md §6.2.1）；`agent/sdk-*` 行是形态声明不是现有能力。
luna/kimi 共用 codex-cli harness → 独立性按 `runtime` 分组键落同一组（`refact-fable.md` §3.2
折算首版）；cursor 与 fable 同厂共用内核程度未验证，按观察值登记（task.md §6.2.1）。

## 7. 权力表与人的介入对照

### 7.1 权力表（7 行）

强制点列写实处：`auto_policy = 无` 的行锚在凭据层或回执仓；本轮 `receipt_strength` 全为
`bootstrap-zero`（§3.5）。表结构沿用 `refact-fable.md` §3.3（≤10 行、强制点非空），
本文不再引入新行。

| 行 | 转换（唯一状态机的词） | eligible_principal | auto_policy | enforcement_point | receipt_strength（本轮） |
| --- | --- | --- | --- | --- | --- |
| H1 | 工单 Artifact `DRAFT → FROZEN`（Task guard：未 FROZEN 不得 `VALIDATING → QUEUED`） | owner | 无（T0 由已签策略承担） | 回执仓 / 开工门查策略包 | bootstrap-zero |
| H2 | `VALIDATING → QUEUED`（开工确认） | owner | 有（T0 + decide，落 RouteDecision） | `round-dispatch.py` 拒发 | bootstrap-zero |
| H3 | 省事方向裁定生效（中途触发时 `RUNNING → WAITING(APPROVAL)`，回执后 `WAITING → QUEUED`） | owner | 无 | 回执仓回执，无回执裁定行视同不存在 | bootstrap-zero |
| H4 | 扩权（预算/范围；Attempt `BUDGET_EXCEEDED` 后 `WAITING(APPROVAL) → QUEUED` 或 `FAILED`） | owner | 无 | 同 H3；目标态为工具网关 | bootstrap-zero |
| H5 | 不可逆 Side Effect（⑦ 的写共享路径/推主线；`RUNNING → SUCCEEDED` 的门） | owner | 无 | **凭据层**：主仓对 agent 只读 | bootstrap-zero |
| H6 | 推翻裁定/改冻结标准（guard 表本身变更，恢复边同 H3） | owner | 无 | 回执仓回执 + 冻结区逐字节校验 | bootstrap-zero |
| H7 | 非终态 `→ CANCELLED` | owner | 无 | `rulings.md` 行（表内唯一例外，失败安全方向） | bootstrap-zero |

### 7.2 人的介入 → 边 + 行（逐条，无缺项）

人的每一次介入都能指到唯一状态机的一条边与权力表的一行：

| # | 人的介入 | 唯一状态机的边 | 权力表行 |
| --- | --- | --- | --- |
| 1 | 冻结题目与验收标准 | Artifact `DRAFT → FROZEN`（guard 于 `VALIDATING → QUEUED`） | H1 |
| 2 | 开工确认（路由/档位/执行者/工作区） | `VALIDATING → QUEUED` | H2 |
| 3 | 省事方向裁定（降档/跳环节/缩窗/免家） | `WAITING(APPROVAL) → QUEUED`（裁定生效的恢复边） | H3 |
| 4 | 扩权（追加预算/范围） | Attempt `BUDGET_EXCEEDED` 后 Task `WAITING(APPROVAL) → QUEUED`（或 `FAILED`） | H4 |
| 5 | 发布（写共享最终路径/推主线） | `RUNNING → SUCCEEDED`（⑦ Attempt 的 Side Effect 过门后提交终态） | H5 |
| 6 | 推翻裁定/改冻结标准 | `WAITING(APPROVAL) → QUEUED`（guard 变更后恢复） | H6 |
| 7 | 取消 | 非终态 `→ CANCELLED` | H7 |

另外两类人的动作**不是权力表行**，如实说明：INPUT 类澄清（内核五类等待之一，走
Interaction，受「只有歧义实质改变结果/权限/成本/风险时才澄清」约束，`request-lifecycle.md:120`
区域）；以及 §2 的 amend——它是 Interaction 入向载荷，不是新的介入类型，
其边就是所在 Interaction 的恢复边。表外无未分类 interrupt（`refact-fable.md` §3.3 规则 1）。

## 8. 自述盲区与放弃项

- ⚠ `agent/sdk-*` 的目标态形态（`per_tool_call` 证据链、沙箱供给）只有架构意图，无实现证据；
  本文全部相关句子仅为设计，不充当能力证据。
- ⚠ §1.6 trace 的 Task 状态序列是从 commit/tag **重建**的投影，重建规则按 `refact-fable.md`
  §3.1.1 映射表；其中 `QUEUED/RUNNING` 的细分在手工腿上本来就判不了（§3.2），标为合并判。
- ⚠ cursor 与 fable 的实质差异程度本轮无数据（观察值，task.md §8 末段）；本文登记表按
  字面两组处理。
- **放弃项**：未写 R0–R5 之后的实施排期（task.md §4 明确不受理）；未展开财务 Profile 的
  字段（理由二只要求证明 DEV 的形状可搬运，财务字段属它自己的首个工作单元，内核 `:521`）；
  未设计多 principal 的 capability 列（`refact-fable.md` §7 风险 7：单 principal 时是空列）。
