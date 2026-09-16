# Agent 开发指导：一个产品运行时，一套开发纪律

### 1.2 四本账与单一权威写入面

预算、幂等、副作用和证据必须跨 run、跨进程死亡仍然正确，因此权威记录落 PostgreSQL；
外部 harness 的内存、Git 文件或日志只能是输入、Artifact 或可重建投影。产品 `I13` 要求一个
可变事实只有一个权威写入面，产品 `I4` 要求状态集中校验、事件只追加；出处为
`request-lifecycle.md @ ed0b5136:444-483`。当前实现已有幂等与副作用，预算与证据仍缺，
这只是 `development-plan.md @ ed0b5136:97-108` 的现状，不得写成目标已完成。

### 1.3 Agent 硬约束自检

| 约束 | 本文结论 |
| --- | --- |
| constraints A1：通用执行编排与领域能力分开 | `dev.change/1` 复用运行时；新增业务能力优先新增 Task Profile 与相容 Agent Profile |
| constraints A2：通用部分也要有纪律 | 执行纪律引用 competition-protocol，不把 harness 原语当协作纪律 |
| constraints A3：四本账落 PostgreSQL | Git 只作开发 Artifact 载体与手工投影，不作产品账本 |
| constraints A4：执行层租用不自建 | 依赖止于稳定 SDK，经 Port 隔离；不直接绑定裸协议 |
| constraints A5：领域概念不进 Port | Port 接受通用输入、能力与结果；投资组合等词留在领域 Profile |

上述五条见 `constraints.md @ ed0b5136:149-159`。涉及多仓还必须遵守 constraints T4/T5：
父仓不留悬空 gitlink，交付证据写“仓 + commit”，见 `constraints.md @ ed0b5136:95-103`。

## 2. 一个运行时的结构

### 2.1 确定性组件与适配层

| 名称 | 性质 | 唯一职责 | 不得做什么 |
| --- | --- | --- | --- |
| `router` | 确定性代码 | 由持久化字段与版本化策略产生 `decide / ask / refuse` 和 RouteDecision | 不让模型直接选路线 |
| `orchestrator` | 确定性代码 | 合法推进状态、派发、收集、观测、回退和停止 | 不评稿、不裁决内容 |
| `interaction service` | application service | 绑定 Task/状态版本/受众，鉴别响应者，一次性恢复 | 不自造另一套任务状态 |
| `validator` | 确定性代码 | 按冻结 Task Profile 跑机械验收并声明覆盖 | 不把判不了写成通过 |
| `executor adapter` | 适配层 | 调用某 Agent Profile 对应的 SDK/CLI，收集该粒度能得到的事件 | 不扩大能力、预算或数据面 |
| `principal channel` | 适配层 | 把 Interaction 送达正确人并取得经鉴别响应 | 不把通知送达当批准成立 |

router 和 orchestrator 都不是 agent 角色；过渡期由人运行脚本只是传输欠账。
模型若参与分类，只能输出固定 schema、无工具、低预算的建议和证据；
⚠ **分类节点的产出形状是「§2.5 那四条风险判据各自命中与否 + 证据」**，
由确定性规则表据此判 tier——**模型不给 tier，只给四条的命中证据**；确定性规则不能唯一落一条合法路线时，
结果必须是 `ask` 或 `refuse`，不得默认落“通用”。这延续产品 `F-DISPATCH-03` 与 constraints A2–A4，
并避免路由自身成为第三个自由 Agent。

### 2.2 内容角色

| 角色 | 职责 | 冲突限制 |
| --- | --- | --- |
| `proposer` | 独立产出候选 | 提案冻结前不可见其他候选 |
| `reviewer` | 按冻结标准比较全部候选 | 必须声明自己也是候选作者的利益冲突 |
| `arbiter` | 定基座、逐条吸收、处置异议 | 不兼 orchestrator；票数不是事实依据 |
| `objector` | 只核自己主张是否被误读 | 不代替 acceptor 评整稿 |
| `acceptor` | 按冻结标准独立验收 | 不得是 arbiter 或基座作者 |
| `publisher` | 在批准后执行发布 Attempt | 不能自己授予发布权限 |

角色分离以 competition-protocol“⑤ 验收 与 ⑥ 确认”为准，本文 [§3.19](../../../composition/protocol/competition-operations.md) 给出操作算法。
这些角色在产品运行时里是 Attempt 的 `kind` 或 principal 行为，不新增内核对象。

### 2.3 Task Profile 与 Agent Profile

`dev.change/1` 至少固定：目标、允许路径、基线 commit、带版本锚的只读输入、tier、执行者集合、
逐条 acceptance、最终路径、能力与副作用边界、预算和停止策略。它决定输入/输出/验收的契约。

Agent Profile 至少登记：`harness`、`provider`、`model` 与是否钉定、`dispatch`、
`observability`、`enforcement`、`sandbox`、`workspace_isolation`、`roles_allowed`、支持的 Task Profile。
它决定某次 Attempt 能被怎样调用、观察和限制。人登记在 principal 表，只有 channel 与授权关系，
没有 harness、执行粒度或执行角色。

Agent Profile 的字段值必须有探针或配置证据。字段非空只证明“填了”，不证明填对；未知值留空并标 ⚠，
不得从产品名或界面推断模型。静态登记集合与自动路由候选集分开：`dispatch = manual` 的执行器可以登记，
但没有审计桥接时不得被自动路由选中。

**独立性折算不得用单一 vendor 标签。**同一个厂牌下可以是不同 harness、不同模型；
不同厂牌也可能共用同一内核。所以分组要看 `(provider, harness, model)` 三者，
而不是「几家公司」——把四个执行者数成「四路独立信号」，是本项目已经踩过的形状：
其中两家同厂不同产品，共用多少 harness 内核**至今未知**。

⚠ 按处置记录，本条**只作观察值，不作硬规则**：单轮数据不足以定权重。
可以据它**降低**对「多家一致」的采信，**不得**据它给出一个折算系数当判据。
**「多家说法一致」不等于「多路独立信号」**——这一句现在就成立，
与折算算法是否成熟无关。

### 2.4 `dev.change/1` 工单

工单是 Artifact，不是 Task 状态。推荐形状：

```toml
[order]
id = "..."
tier = "T0|T1|T2"
artifact_state = "DRAFT|FROZEN"
goal = "..."
paths = ["..."]
baseline_commit = "..."
read_only_inputs = ["path@commit"]
final_paths = ["..."]
acceptance = ["A1 ..."]
route_proposal = "..."
route_effective = "..."
route_delta = "..."

[executors]
intake_author = "..."
proposers = ["..."]
arbiter = "..."
acceptor = "..."

[workspace]
write_actors = 1
review_needed = true
submodule_plan = "..."

[budget]
observation_window_rule = "..."
max_rollbacks = 2
```

**别名登记（不并存多个真源）**：`DEV`、`DEV_ROUND`、`DEVELOPMENT`、`dev.change.v1`
**均为 `dev.change` 的别名**，正式 id 取 `dev.change`。⚠ 不登记别名，下一轮就会有人
对着别名设计接口。

工单还须固定两项常被漏掉的：`privacy`——⚠ **财务数据任务在 NO ZDR 核实前不得跑**；
`budget.observation_window_rule`——观察窗 `W` 取**已交付各家用时的中位数**，
不取最长也不取平均；`freshness`——`baseline_commit` 固定，**基线移动即新 Task**。

⚠ **`acceptance` 里的硬门禁、质量偏好和待定项必须分开列，不得混成一串。**
硬门禁不过就是不过；质量偏好只用于同分决胜；待定项要么在冻结前定掉，要么显式标为不判。
三者混写会让「偏好没满足」被当成「门禁没过」，或者反过来。
工单还应固定 `tenant`、`agent_profile` 或其选择策略、`approval_points`、`deadline`、
`stop_condition`、`writable_roots`、`output_namespace`、`publication_target` 与 `integrator_id`
——最后四项是 [§3.6](../components/04-agent-execution/composition/agent-dev-guide.md) 命名空间纪律在工单上的落点。

`intake_author` 若替请求者起草意图与验收，同票不得再任 proposer、arbiter 或 acceptor；请求者直接给出并
冻结验收时可记 requester。`route_proposal` 保存建议与证据，`route_effective` 保存实际决定，
`route_delta` 保存人改了什么，三者不可合成一段自然语言。

### 2.5 路由只读可判字段

路由成本判断不读题目散文，至少从以下字段提取 `matched_features`：写者数、提案者数、只读输入是否钉版本、
是否依赖/续接、是否触及权威路径、是否有副作用、是否要求审计。风险档位则严格按 competition-protocol：
不可逆、权威层、已知对立、判据未定任一命中就是 T2；多文件或多仓且方向无争议为 T1；其余才可能 T0。
风险档位不能反过来充当成本证据，否则是循环论证。

### 2.11 派工契约、角色补充与隔离的诚实边界

**派工契约（Work Unit）与工单（§2.4）是两层**：工单冻结整个 Task，派工契约冻结**一个执行者
那一份**。至少固定：

```text
work_unit_id, parent_task_id, owner        objective, included_scope, excluded_scope
input_refs, baseline_commits, allowed_context
expected_output, acceptance, evidence      permissions, budget, deadline, stop_condition
dependencies                               checkpoint_location
workspace_path, exclusive_branch, forbidden_write_paths
output_namespace, publication_target, integrator            result_status
```

⚠ **`workspace_path`、`exclusive_branch`、`forbidden_write_paths` 必须在派工时写死，
且对每个执行者唯一。**`forbidden_write_paths` 至少包括：人的主 checkout、其他执行者的
worktree、共享发布面，以及非协调者不得写的单写者文件（如 `user-message.md`、`composition/`）。
**这三个字段不是描述性说明，是 [§3.10](../components/04-agent-execution/composition/agent-dev-guide.md) 写入前门禁的判定输入——派工时缺任一字段，
执行者不得开始写。**

派工**只能收窄**父 Task。父预算覆盖所有 Work Unit、Attempt、工具、评审和改进。
多个 Work Unit **不得同时权威写同一可变事实**；先划分所有权，无法划分则串行。

**人在这套模型里有三个角色，不可互相替代：**

1. **请求提出者**——提出有边界的工作，给原始意图、范围和验收期望；
2. **内容贡献者**——亲自实施部分工作，与助手交替推进；内容以本人署名的 Artifact 或 Interaction 响应进入系统，**不据此把人登记为 Agent Profile 或产品 Attempt 执行器**；
3. **principal**——批准、取消、追加成本和终审验收的最终权力。**第三种助手不能替代。**

⚠ 助手不得自我批准；**人也不得把终审责任外包给助手后不再复核**（§4.5 责任归属表）。

⚠ **候选隔离目前靠纪律，不靠机制。**候选冻结前只读同一任务包、基线和各自获准上下文，
不得读其他候选、**发起方偏好**或预设解法；看到已有答案之后产出的内容属于评审或改进，
**不再是独立候选**。但——

> **脚本化产生候选目前没有可用工具。**在此之前，
> **隔离靠纪律，而且无法事后证明某一次竞争真的独立。不得据此声称隔离由机制保证。**

### 3.3 Attempt 与状态投影

开发产物只投影到内核，不造新状态：

| 开发事实 | Task 投影 | Attempt 投影 |
| --- | --- | --- |
| 工单可靠创建 | `RECEIVED → VALIDATING` | — |
| 路由需关键输入 | `VALIDATING → WAITING → VALIDATING` | — |
| 受理后发现不可执行或越权 | `VALIDATING → REJECTED` | 不创建执行 |
| 有效取消请求使非终态安全收敛 | 按内核允许边进入 `CANCELLED` | 在途 Attempt 撤权、盘点副作用后进入 `CANCELLED`；未创建则无 Attempt |
| 契约冻结且可执行 | `VALIDATING → QUEUED` | `CREATED` |
| 首个执行取得有效租约 | `QUEUED → RUNNING` | `CREATED → RUNNING` |
| 某家提交候选 | 保持 `RUNNING` | `RUNNING → COMPLETED`；只表示有候选 |
| 某家逾期 | 仍有路可走则保持 `RUNNING` | `→ FAILED(timeout)` |
| Attempt 预算耗尽 | 按契约等待、重排或失败 | `→ BUDGET_EXCEEDED` |
| 执行中等待输入 | 无其他路可走才 `RUNNING → WAITING` | 可 `RUNNING → WAITING` |
| 同一执行从 checkpoint 续跑 | Task 先按内核合法回边 | 同一 Attempt `WAITING → RUNNING` |
| 评审/异议/验收打回 | 保持 `RUNNING` 或回 `QUEUED` | 新 Attempt；旧终态不重开 |
| 不可逆发布待批 | `RUNNING → WAITING(APPROVAL)` | publisher `CREATED` |
| 批准后发布完成 | `WAITING → QUEUED → RUNNING → SUCCEEDED` | publisher `→ RUNNING → COMPLETED` |
| 已无获准成功路径 | `→ FAILED` | 相关 Attempt 均终态 |

**这张表不是说明，是判据。**「只投影不造新状态」要成立，必须**三件同时满足**，
缺一条这个主张就没被证明：

1. **没有一个新状态词**——表右两列出现的词全部来自内核合法转换表；
2. **没有一条内核之外的边**——每一格的转换都能在内核那张表里找到；
3. **内核的每个状态都有落点**——反过来查：内核有而本表没出现的状态，
   要么说明流程还没覆盖到，要么说明表漏了。

⚠ **第 3 条最容易被跳过**，因为前两条查「本表有没有越界」是顺着看，
第 3 条查「内核有没有被漏」要倒着看。**只做前两条会得到一个自洽但不完整的映射。**

Artifact 可以有草稿、冻结、陈旧、被替代等版本属性；这些不是 Task/Attempt 状态。
评审、裁决、异议和验收均可作为 typed Artifact，由 Attempt 的 `output_artifacts` 引用；若要把它写入
内核合同，须先按规范修订程序确认这是类型细化而不是对象扩充。

### 3.4 T0/T1/T2 不是三套状态机

> 依据的通用规范：[多方竞争协议「档位」](../../../../dev-agent-standards/detailed-rules/protocol/competition-rules.md)

三档共享同一工单 schema、状态机和发布门，只改变 guard、必需 Artifact 和 Attempt 组：

| tier | 执行形态 | 独立信号 | 人工门 |
| --- | --- | --- | --- |
| T0 | 做 → 独立验收 → 确认 | 一个产出、一个独立验收 | 开工可由已批准窄包自动决定；不可逆发布仍由人确认 |
| T1 | 单稿 → 独立评审 → 验收 → 确认 | 一稿、一评、一验 | 工单冻结与开工可合成一次明确确认 |
| T2 | competition-protocol 七环节 | N 份隔离候选、互评、裁决、异议、独立验收 | 题目/判据冻结与参与方/路线确认分开 |

产物命名、候选冻结、处置表和验收方算法见 [§3.19](../../../composition/protocol/competition-operations.md)–[§3.22](../components/04-agent-execution/composition/agent-dev-guide.md)，来源为现行 competition-protocol。状态脚本从 commit 反推，工作区
不参与判定；空参与方不是“完成”；脚本首次增加判据时先与人工结论对照，并列出未检查范围。

⚠ **档位是风险轴，「建不建 Git 工作区」是载体轴，两者正交，不可互相推导。**
载体判据是另一组：不改持久文件、单 Attempt 单会话可完成、不需要 worktree/回滚/diff/固定源码版本、
外部副作用为零或已有独立副作用账、验收可直接针对结构化结果完成——**全部满足才可不建工作区**；
多文件改动、跨步骤跨会话跨执行者跨仓、需要 checkpoint/回滚/diff/固定候选、需要 fan-out、
以代码或可复现实验交付、错误代价要求独立评审——**任一命中就要建**。

⚠ **「不建工作区」只决定载体，不降低授权、证据、预算或验收。**
载体判定必须可审计：**不能为省供给成本把复杂任务塞进无状态 Attempt，也不能为形式统一
给一次只读问数建立空仓库**。执行中发现判据不成立时，停止当前 Attempt 并保存 checkpoint 后升级，
**执行者不得私自在获准工作区之外建仓**。

⚠ 把载体轴写成档位轴，与 §2.5「风险档位不能反过来充当成本证据」是同一种循环。

### 3.11 候选状态机

```text
DRAFT → FROZEN(commit/digest) → SUBMITTED
      → {SELECTED | REJECTED | STALE | SUPERSEDED}
      → INTEGRATED（仅被采用部分） → VERIFIED(final commit)
      → PUBLISHED → RETAINED / GARBAGE_COLLECTED
```

⚠ **这些是 Artifact 的版本属性，不是 Task/Attempt 状态**（§3.3 末段）。七条纪律：

- `DRAFT` 可改，但只存在于 owner 可写面，**不能被称为候选完成**；
- `FROZEN` 后**不得原地替换**，修订产生新 commit/digest 并用 `supersedes` 关联；
- `SELECTED` 只表示进入整合，**不表示已发布**；
- `INTEGRATED` 必须记录**实际吸收的 commit/patch/Artifact**，不能只写「已吸收」；
- `VERIFIED` 只针对 final commit；
- `PUBLISHED` 必须记录发布目标、发布者、版本和时间；
- 清理前必须证明**所需对象仍有可达 ref 或已进入持久 Artifact**。

### 3.17 内核对象 ↔ 开发载体对照

⚠ **「只有一套状态机」不是口号，这张表是它的证明**：开发侧每个产物都对应一个内核对象，
且 Task 状态**一律推导**，不另立。

| 内核对象 | 开发侧载体（手工态） | 产品侧载体（服务态） |
| --- | --- | --- |
| Task | 工单所属的那件事 | `task` 行 |
| **Task 状态** | ⚠ **纯推导**：由 Attempt 产物、裁定记录、受保护 tag 反推（§3.3） | `state`（Event 投影） |
| Attempt | 一家在一个环节的一次交付（一个 commit） | `attempt` 行 |
| Interaction | 收件箱条目 + 落盘回执 | `interaction` 行 + `resume_token` |
| Artifact | 工单、候选、评审、裁决稿、异议、验收稿（按 commit 冻结） | 对象存储 + `artifact` 行 |
| Event | git 提交历史 + 裁定记录（只追加） | `event` 行（只追加） |
| Side Effect | 写共享最终路径、push 主线（§4.2 H5 门） | 副作用账 |
| Delivery | 主线上的最终稿 + 检视 worktree | `F-DELIVERY-*` |
| RouteDecision | 工单 `route_effective` | `route_decision` 行 |
| 预算 | 观察窗规则、轮次上限、回退上限 | 预算账（`I10`） |

⚠ **左右两列换的是载体，不是语义。**§5.3 的等效判据就是在这张表上做的：
S 层比对象与边，R 层比一次执行的序列。

### 3.18 状态脚本的硬要求

**状态从产物反推，不从声明读取**——人的动作也不例外；需要人读的进度视图是投影，不是第二真源。

脚本「从产物反推、判据即命令、只生成不执行」这三条是对的，要补的是**判错时必须停**：

| 要求 | 违反会怎样 |
| --- | --- |
| 输出 **Task 状态（内核状态词）+ 当前环节 + 各 Attempt 状态**；⚠ **环节是投影，状态是判据** | 只输出「当前环节」，就把投影当成了真源 |
| 工单里若有 `status` 声明字段，**降为人读缓存并由脚本校验**：⚠ **推导值 ≠ 声明值即报错退出** | 声明与产物漂移，而没有人会发现 |
| 每次状态推导**同时输出「上一状态 → 本状态」**；⚠ **边不在内核合法转换表内即报错退出** | 只校验状态点会漏掉非法边——这是真实抓到过的漏检形态（§5.3 规则 6） |
| 分发前对照 `roles_allowed` 与角色分离禁令，**冲突即拒绝并给 reason** | 角色冲突要到验收时才暴露，那时已经晚了 |
| ⚠ **每条判定声明覆盖范围**（P4）：输出里「查了什么、没查什么」与结论并列；**零命中要能区分「真的没有」与「没查到」** | 门禁在边界上给假答案，而它看起来是绿的 |
| 按工单 `tier` 读取对应 guard 表与必需产物表，**不写死某一档** | 轻档位没有可执行形态，等于不存在（[§0.0](../../../composition/agent-dev-guide.md) 第 6 条） |

状态推导还须读取 orchestrator 单写的执行事件：产物未出现只能说明“尚无交付”，
不能区分未派发、执行中、崩溃、失联或超时。无法程序分发的执行器应输出明确投喂说明，
并记录实际的 `dispatch_event`；生成了一条命令不等于该命令已经执行。

#### 任务目录的状态怎么判

任务目录的结构见 [任务的生命周期「任务目录里放什么」](../../../../dev-agent-standards/lifecycle.md)。

状态**从文件和提交推出来，不在任何地方手写**；给人看的进度视图由此生成。
没有记录或进度文件：状态只从 `thread/`、`composition/`、`components/` 及它们的提交推出。

| 状态 | 判定依据 |
| --- | --- |
| 已建立 | 任务目录与第 01 个 turn 的 `user-message.md` 已提交 |
| 已派工 | turn 里有 `user-message.md`，还没有 `turn.md` |
| 已交回 | `turn.md` 已写，`status` 为 `completed` |
| 中断或失败 | `turn.md` 的 `status` 为 `interrupted` 或 `failed` |
| 已通过 | 有 `verifies` 指向**这个 turn** 的验收 turn，其 `turn.md` 的 `verdict` 为 `pass`；设计还须已整理进 `composition/` |
| 被打回 | `verifies` 指向这个 turn 的最新一份 UAT，其 `verdict` 为 `fail` |
| 停下待人 | 同一项交付物被打回的次数达到上限，还没有载有人的裁决的新 turn |
| 已取消 | 上层定稿写明已取消及原因 |
| 已完成 | 任务要求交回的每一项都「已通过」，且全部子任务「已完成」或「已取消」 |

一个任务可以同时有几项交付物处在不同状态；任务本身的「已完成」只看上表最后一行。

## 4. 人介入、Interaction 与权力

### 4.1 人的位置

> 通用部分见 [人的批准点](../../../../dev-agent-standards/detailed-rules/approvals.md)「人的位置」。

### 4.2 权力表

> 依据的通用规范：[人的批准点「谁批什么」](../../../../dev-agent-standards/detailed-rules/approvals.md)

| 行 | 受控动作或合法边 | principal | 默认 | 强制要求 |
| --- | --- | --- | --- | --- |
| H1 | 工单 Artifact 冻结；验证期 `WAITING → VALIDATING` | owner | 无；T0 由已批准任务类包承担 | validator 对照冻结 digest |
| H2 | `VALIDATING → QUEUED` 开工 | owner | 仅 T0 且 router `decide` | orchestrator 无有效决定不分发 |
| H3 | 降档、跳环节、缩窗或免除参与方后恢复 | owner | 无 | 裁定追加留痕，批准与目标版本绑定 |
| H4 | 冻结授权内追加预算或资源后恢复 | owner | 无 | 超出授权范围必须新建 Task，不在原 Task 扩权 |
| H5 | 不可逆 Side Effect；最终 `RUNNING → SUCCEEDED` | owner | 无 | 执行动作与批准分离，凭据/服务端校验不可由 executor 绕过 |
| H6 | 推翻裁定或改判冻结标准 | owner | 无 | 追加新记录，不覆盖原判断；标准变更重新验收 |
| H7 | 非终态安全收敛到 `CANCELLED` | owner | 无 | 先落取消意图、提高 fencing、盘点副作用 |
| H8 | 回答本 Task 的 `WAITING(INPUT)` | requester | 无 | interaction service 鉴别主体、Task、状态版本和一次性令牌 |

**H7 是表内唯一不要求仓外锚的行**，这是有意的：取消属**失败安全方向**——
伪造一条「取消」只会让流程停下来等人，不会让任何东西被发布出去。
其余各行朝的是「放行」，伪造即造成不可逆后果，所以强制点必须在 agent 够不着的地方。
⚠ 代价在**恢复**而不在取消本身：不知道已经产生了哪些副作用就不知道要回滚什么，
所以取消必须附**已产生副作用清单**，缺清单的取消不生效。

表外没有未分类的 APPROVAL。`DEPENDENCY / RESOURCE / EXTERNAL` 按产品 WAITING 规则处理；普通 INPUT
只有在歧义实质改变结果、权限、成本或风险时才问。H5 批准的是执行 Side Effect，不是把 Task 直接从
`WAITING` 写成成功；内核没有该捷径。

### 4.4 身份、批准与强制点

> 依据的通用规范：[人的批准点「批准怎样才成立」](../../../../dev-agent-standards/detailed-rules/approvals.md)

批准成立必须同时回答：谁、批准哪个 Task/版本、批准哪项动作、何时过期、是否已原子消费。
通知文件或聊天回复只证明“有文本”，不证明身份；executor 可修改的脚本、hook、权限位也不是对它的
安全边界。强制点必须落在 executor 够不着的服务端身份、凭据作用域、工具网关或生产写入口。

⚠ **取证结论的措辞必须限定到「这台宿主、这个身份、这个时刻」。**
下面这些是**单机观测**，不是平台事实：换一台机器、换一个跑 agent 的用户，
结论就可能翻转。写成「agent 有 root 权限」是把一次观测外推成属性；
正确写法是「**在本宿主上、以该用户运行时**，agent 与人共享同一凭据域」。
边界的表述也据此绑定到**凭据域是否共享**，而不绑定到「是不是 root」这个偶然事实。

**同期取证的另外三行现状事实**（同样绑定「这台宿主、这个身份、这个时刻」）：
本机**没有 GPG 密钥**，已有 tag 全部未签名——从零设计，无兼容包袱；
`~/.ssh/id_rsa` 对主仓**有写权限**，即任何 agent 都能以本机身份 push 分支与 tag；
人的第二台机器是 Windows 工作站，**其上也运行本地 agent**，
若凭据管理器缓存了推送凭据，它**不需要口令就能 push**。

基线取证显示宿主用户 `zym` 有免密 sudo，且当时能对两个主 remote 做 push dry-run；见
`forensics.md @ ed0b5136:18-45`。本轮在非沙箱宿主重跑 `sudo -n -l` 仍得到
`(ALL) NOPASSWD: ALL`。所以本机签名、仓内公钥表、本机 hook 与只读文件权限都只能当卫生检查或审计，
不能证明 Agent 无法伪造批准或绕过发布。

目标产品态应优先复用已有认证主体、授权服务、一次性 Interaction 恢复和 Side Effect 网关；若某条写路径
绕过这些组件，就先画出真实动作路径并在路径上设门，不增加旁路存储来制造安全感。当前手工进行的多方竞争的
人类确认仍是治理记录，证据等级应诚实标为 `reported`，不得声称身份已 `attested`。

**威胁模型要同时覆盖三件事**：伪造肯定的批准；没有批准仍能直接写交付面；
人的设备上另一个 agent 借缓存凭据代做批准。需要防的是共享凭据下的越权代劳，
不以执行者是否“恶意”作为前提。批准证据的鉴别与 Side Effect 入口的强制是两道不同的检查。

拥有凭据只说明有技术能力，不等于批准了某个 Task 的具体动作；只有一位 principal
也不免除 H5。远端保护只管经过远端的写路径，本地发布要在本地动作的可信边界上另作判断。
身份鉴别服务不可达、批准过期或配置漂移时失败关闭，并区分查询失败、未批准与策略拒绝。
边界可以防伪造/绕过，不能证明人读懂了对象；误签仍靠对象展示、独立验收与 L3 抽检降低。

### 4.5 权限公式与只有 principal 能做的动作

> 依据的通用规范：[人的批准点「权限取交集」](../../../../dev-agent-standards/detailed-rules/approvals.md)

有效权限是交集，不是并集：

```text
Attempt 内的执行
  有效权限 = 请求方授权 ∩ Task Profile ∩ Agent Profile
           ∩ sandbox / tool policy ∩ 当前批准 ∩ 有效租约

不在 Attempt 内的开发操作
  有效权限 = principal 授权 ∩ 仓库与环境策略 ∩ 当前批准
```

⚠ **租约是条件项，不是无条件交集。**不隶属任何 Attempt 的开发操作没有租约，
**不能因此在公式上算作无权限**。两条路径的差别只在约束来源，不在约束强度。

⚠ **授权不跨场景延续。**在 A 分支批准过推送，不等于 B 分支也可以；Task A 的授权不延续到
Task B；一次批准的破坏性动作**不构成下次的默许**。批准绑定 Task、动作、目标、版本和有效期。

下列动作**只有 principal 能做**，且各有留痕义务。协调职责不带来其中任何一项：

| 动作 | 必须留下 |
| --- | --- |
| 批准高风险或不可逆动作（推送、合并、发布、迁移、删远端资产） | 批准人、动作、目标、版本、有效期 |
| 取消 Task 或中止在途执行 | 取消依据、已产生副作用、需补偿项、需保留对象 |
| 追加预算或提高并行度 | 原上限、新上限、依据 |
| 最终验收终审 | 所验 final commit、逐条判定、门禁原始输出位置 |
| 降档（把完整选优改成最小选优或单路） | 降档依据、被省略的环节、承担的风险 |
| 推翻已有判定或改判冻结标准 | 原判断、错在哪、新判断、原标准与原始失败输出 |

⚠ **「我看着行」不是依据。依据要能被半年后的自己复核。**

**是否简化流程的裁量权在 principal，不在执行者。**执行者不得自行把完整选优降为单路，
也不得通过询问自己派出的 subagent 或取得多数同意来制造批准——**自我批准禁令在任何一次竞争
都成立**。

责任归属决定了这条禁令的理由：

| | 谁负责 |
| --- | --- |
| 决定做什么、不做什么 | **人** |
| 决定怎么做（在约束内） | 执行者 |
| 产出是否符合验收标准 | 未参与实施的一方；无人时由**人** |
| 上线后出问题 | **人**——agent 不承担后果 |

⚠ **agent 不得自我批准，不是因为不信任它的判断，是因为它不承担后果。**

### 4.6 三道正交门

> 依据的通用规范：[人的批准点「三道正交门」](../../../../dev-agent-standards/detailed-rules/approvals.md)

运行时的有效能力必须**同时**通过三道独立门；三者不能互相代替：

| 门 | 决定 | 硬规则 | 合同锚点 |
| --- | --- | --- | --- |
| **Tool Policy** | 哪些工具存在 | deny 优先；allow 非空时未列工具默认拒绝 | `F-EXEC-01/03`、`I3`、A2 |
| **Execution Scope** | 在哪里、对什么资源执行 | workspace/data/network/tenant/actor 逐次收窄，**不能由模型自报** | `F-EXEC-01/03/05`、`I3/I12/I14` |
| **Approval Policy** | 此次具体动作谁可批准 | 批准不能扩出前两门；缺失、过期或漂移一律 fail-closed | `F-EXEC-03`、`I3/I9/I12`、`AT-05/12/14` |

⚠ **Tool Policy 是硬停，不是 prompt 建议。**被拒绝的工具应当**不存在**：会话组装层在发给
模型前从 schema/catalog 移除；工具网关层即使收到伪造名称也再次 deny。前者减少诱导和误调用，
后者防绕过；**任何「工具仍在但描述为禁止」的方案都不满足 `F-EXEC-01`**。
可复核的机制参考：`~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:57-59` 的
`tools/pre-execute` allow/deny/ask 与 `ctx.tools.guard()` 单调 deny；
`~/repo/openclaw/docs/gateway/config-tools.md` 的 deny-wins 语义。**这里只借机制。**

⚠ **这三道门与 §5.1 的三个粒度字段是不同的轴**：粒度字段说「运行时**能看见/能拦在**哪」，
三道门说「一次动作**要过几关**」。`enforcement = outer-only` 时，Tool Policy 与
Execution Scope 只能落在进程外层，Approval Policy 只能事后审计——**此时必须标 `audit_after`，
不得声称事中拦截**。

### 4.8 principal 的裁量权与改判纪律

> 依据的通用规范：[人的批准点「裁量权的底线」](../../../../dev-agent-standards/detailed-rules/approvals.md)

人可以判断「这件事不值得走全流程」，执行者不可以。但裁量有底线，**五条不因规模而豁免**：

1. 不篡改原始意图；
2. 不越过权限与范围；
3. 结论有与风险相称的证据；
4. 「完成」可判定；
5. 发生改判时，交代触发与变化。

⚠ 省略任何一步都必须**显式写出「不适用」及理由**——**空着与「忘了」无法区分**。

**什么时候不能简化**：涉及安全边界、数据迁移、跨 App 契约、不可逆外部动作、生产发布——
这几类无论多小都走完整流程（与 §2.5 的 T2 触发条件一致）。

**改判三要素。**人比 agent 更容易改判——信息多、判断在变。
⚠ **改判本身不是问题，装作没改过才是。**每次改判必须写清三件事：

| | |
| --- | --- |
| **触发** | 什么新证据或什么情况变化 |
| **原判断错处** | 当初**哪一句**不再成立——不是「当时信息不全」，是具体哪一步推错了 |
| **新判断** | 现在以什么为准；**能独立成立**，不写「理由见上文」 |

不得装作从未判过，**也不得为了让检查变绿而静默删除旧标准**。修改验收标准时保留原标准、
原始失败输出和改判理由。把结论写进上游文档前**回读代码或实物重新取证**——
⚠ **文字改对了、代码里还是旧的，比不改更糟。**

### 5.1 三个粒度字段

| 字段 | 取值 | 问的问题 |
| --- | --- | --- |
| `observability` | `tool.enforced > tool.reported > process > fs-only` | 最细能看到什么 |
| `enforcement` | `tool-level | outer-only` | 能在动作前拦在哪里 |
| `sandbox` | `runtime | self | none` | 隔离环境由谁提供、策略归谁 |

四档 `observability` 各是什么（**从强到弱**，只给排序不给定义，读者无从判自己那家在哪一档）：

| 档 | 运行时看得见什么 | 能不能拦 |
| --- | --- | --- |
| `tool.enforced` | **每一次工具调用**，且调用**先经运行时批准**才发生 | **能**，在动作前 |
| `tool.reported` | 每一次工具调用，但是**执行器事后自报**的 | 不能——看见时已经发生了 |
| `process` | 只看得见**进程起没起、产物出没出** | 不能 |
| `fs-only` | 只看得见**文件系统的最终状态** | 不能 |

⚠ **只有 `tool.enforced` 的事件是证据**；`tool.reported` 是**索引**——
可以据它决定「该去重新推导什么」，不能据它下结论。

`dispatch_event` 指**人代运行时执行的一次传输动作**（把指令送到没有程序入口的执行器、
在正确的工作区打开它的界面）。**它不是权力，是欠账**：不占权力表的行，
但**必须可数**，因为成本上界（[§6.2](../components/02-intake/composition/agent-dev-guide.md)）和绕过口径（[§6.3](../components/02-intake/composition/agent-dev-guide.md)）都要数它。

三者不得合成一个“能力等级”。JSONL 工具事件可能细但仍是执行器自报；外层可以观察 argv/stdio 却不能
拦内部系统调用；自带沙箱也不等于运行时控制。`RUNNING` 能否可靠判断首先是执行器 observability 的问题，
不是把 Git 换成数据库就自动解决。

### 5.2 证据等级与采信规则

> 依据的通用规范：[UAT「证据采信」](../../../../dev-agent-standards/uat/uat-rules.md)

| 等级 | 来源 | 可支持的断言 |
| --- | --- | --- |
| E0 `ASSERTED` | executor/principal 自述或事后推断 | 待验证主张 |
| E1 `REDERIVED` | validator 从冻结 Artifact 重算 diff/hash/test | 仅重算覆盖内的结果 |
| E2 `PROCESS_OBSERVED` | 外层 argv/stdio/exit + E1 | 进程被调用及其外部结果 |
| E3 `TOOL_OBSERVED` | 运行时工具网关事件 + E1 | 经网关的调用与策略检查 |
| E4 `EXTERNAL_AUTHORITY` | 执行域外受保护审计/服务端事实 | 指定身份或外部 Side Effect |

采信等级取 `min(来源等级, 可见上限, 隔离强度, 验收独立性, 覆盖)`，任一未知就降级，不取平均。
`tool.reported` 事件是重算索引，不是结论；commit、diff、测试、锚点与远端状态由 validator 独立重算。
覆盖声明必须同时写 checked 与 not_checked；零命中只有在输入集合成功枚举时才能判 pass，否则是
`UNKNOWN`。这落实 competition-protocol“判据自身的质量”。

### 5.3 手工态与服务态的等效判据

等效分两层：

- S 层比较对象集合、状态词、合法边、权力行、Interaction 绑定、Agent Profile 字段；现在就能判；
- R 层比较同一 Task 的状态/Attempt/Interaction/Artifact 序列，经投影丢掉执行器私有事件和时间戳后逐项判。

每个轨迹条目至少含 `seq, layer, subject_id, from, to, actor, power_row, payload_ref,
provenance, evidence_ref`；⚠ **Artifact 的作者要拆成 `author_claimed` 与 `author_attested`
两个字段**——合成一个就没法表达「声称是谁写的」与「能证明是谁写的」之间的差距，
而目前这两者几乎从不相等（源稿 2.12 节 `channel_grade`）。**比较上下文**（源稿称 `TraceEnvelope`——本文不沿用该名，
因为它只是这一组字段的包装，另起一个名字会让读者以为多了一个对象）另含
Task Profile 版本、验收摘要、策略版本、principal 身份域、
输入摘要、Side Effect 摘要和证据权威摘要。比较规则：

1. 只允许载体、orchestrator 实现、时间和已声明私有事件不同；白名单外差异失败。
2. 比较粒度取较粗一腿，并列出未比对项。
3. 两边都声明权威源与重建规则；Git 工作区文件不作判据。
4. 结论只能在两条轨迹的最低 provenance 上宣称，并报告各类 `attested` 数量。
5. bootstrap 期身份归因强度为零，服务态不得继承成可信先例。
6. 先验证每个状态属于内核状态集、每条相邻边属于合法边，再比较序列。

轨迹只是 Event 投影，不是新内核对象；结构与比较规则已完整列在本节，执行时无需回读历史稿。
历史样例及 23 条里仅 2 条 `attested` 的读数见 源稿 5.11 节，说明“流程看起来发生过”不等于可搬运证据链。

### 5.4 Git 载体能与不能证明什么

> 依据的通用规范：[UAT「载体各能证明什么」](../../../../dev-agent-standards/uat/uat-rules.md)

Git 永久承担代码/文档 Artifact 的版本载体；手工阶段也可从 commit、裁定记录和执行事件重建投影。
分支是运输通道，工作区是可变草稿，只有钉定 commit 的产物可评审。发布时必须比较目标 ref 是否仍在
预期基线，冲突就新建整合 Attempt。

Git 不能证明产品 `F-ACCEPT-03` 的跨记录事务提交、Attempt 租约或产品 `I14` fencing；也不能证明
CLI 内部发生过哪些工具调用。手工态的价值是先跑通对象形状、合法边、Interaction 和协作纪律，
不是替 PostgreSQL 与工具网关完成并发、安全证明。

### 5.8 上下文路由与能力四级词典

> 依据的通用规范：[UAT「能力状态只用四级」](../../../../dev-agent-standards/uat/uat-rules.md)

**改哪一面，就必须连带读哪些东西**——否则断言的是记忆不是现状：

| 改动面 | 必须追加核对 |
| --- | --- |
| 项目总体边界 | 总体架构、`constraints.md` |
| Task/Attempt/Interaction/Delivery | 内核、生产代码与对应测试 |
| Agent runtime、恢复、预算、事件、副作用 | 当前事实文档、生产链代码和测试 |
| 跨 App 契约 | provider schema、consumer lock 和**双端**契约测试 |
| Admin/Web/API | 目标目录 `AGENTS.md`、认证边界和端到端测试 |
| 数据模型或迁移 | 迁移链、数据库约束、前滚/回滚和数据不变量 |
| K8s 或发布 | bundle、release、部署引用与运行门禁 |
| Git、远端或子模块 | 现行协作规范、各仓 HEAD 和 gitlink |

⚠ **历史 baseline、候选和聊天记录只作线索**；当前实现断言必须回到代码、测试或运行结果取证。

**陈述任何能力状态时只用四级词典**，不得自行发明「已实现」的判断口径：

| 级 | 含义 |
| --- | --- |
| `defined` | 有类、DTO、迁移或测试夹具**存在** |
| `wired` | 生产链**已接线**，会被真实请求走到 |
| `deployable` | 部署面（bundle、网络、凭据、配额）**已就位** |
| `runtime-verified` | 在目标环境**实跑验证过** |

⚠ **类、DTO、迁移或测试夹具存在，都不等于生产链已经接线。**
这是 [§12](../components/06-acceptance-commit/composition/agent-dev-guide.md)「拿休眠代码当能力证据」那条失败的词汇层防线；配套的可运行验证动作是
**回跑 dormant 测试**并同时确认「锚点仍在」与「能力仍未接线」两个方向（[§2.6](../components/04-agent-execution/composition/agent-dev-guide.md)）。

### 5.9 七种载体各能证明什么

> 依据的通用规范：[UAT「载体各能证明什么」](../../../../dev-agent-standards/uat/uat-rules.md)

⚠ **隔离靠 worktree + 命名分支，不靠文件名。**`-new`、时间戳、执行者名写进文件名，
都不能阻止「同一工作区、同一相对路径」被后写覆盖。不同载体的覆盖语义完全不同：

| 载体 | 覆盖会怎样 | 能证明 | **不能**证明 |
| --- | --- | --- | --- |
| **未提交工作区文件** | **后写直接覆盖先写：无冲突、无历史、无警告、无作者归属** | 磁盘此刻的内容 | 谁写的、谁先写完、被覆盖前是什么。**隔离单位是工作区，不是路径字符串** |
| commit | 新 commit 不摧毁旧对象；旧对象**需有 ref 才找得到** | 一组文件内容及父历史不可变 | 谁批准、测试是否通过、外部副作用状态 |
| branch | 指针可被快进、重置、强推；**像标签在移动** | 当前指向哪个 commit，便于运输和续接 | **稳定的评审对象**——分支头会移动 |
| worktree | 一分支只能被一棵 worktree 检出，Git 会拒绝第二处 | 某执行者当前可写目录和所检出分支 | 长期证据；目录可以删除 |
| tag/ref | 可被移动或删除，但所指对象仍在对象库 | 使对象可达并表达冻结点 | **不自动构成验收或发布** |
| patch | 应用到不同基线上结果不同 | 可传输的差异 | 完整父基线、未跟踪文件或外部状态 |
| 共享发布面 | 未授权写入等于闯入他人工作区或发布面 | 只有整合后的 final commit 算交付 | 任何未经整合的内容 |

⚠ **未提交工作区文件不能作为候选，也不能作为交卷物**：没有 commit、没有 digest、
没有作者归属，被覆盖后既难恢复也难归因。**交卷 = 自己分支上的可达 commit。**

候选和评审一律引用**完整 commit ID 与基线**，不能只给分支名。冻结候选后禁止 force-push
改写其可追溯历史；需要 rebase 时形成**新的候选 commit** 并保留旧→新映射。
删除 branch、worktree 或工作区前，必须确认仍需保留的 commit 已由持久 ref、获准远端或
Artifact bundle 保持可达——⚠ **「对象暂时还在 reflog」不是保留策略。**

### 5.13 历史取证怎样用于今天的开发

> 依据的通用规范：[UAT「历史证据怎样用」](../../../../dev-agent-standards/uat/uat-rules.md)

使用证据前固定 **仓库/SDK commit、配置或策略版本、主机、OS 身份、沙箱/容器上下文、
命令、退出码、原始输出引用及时间**；敏感字段去敏，不输出凭据本体。
权限实验针对被描述的实际环境；沙箱内观测不能直接外推宿主，受限环境不能代替生产同身份测试。
需要受限操作时走既有授权机制，不为取证绕开权限。

文档里记的“通过”只说明那个版本的那个用例。版本变化后核代码、消费者、部署与测试，
不能仅验证行号仍可达；原记录不得改成新日期，也不得拿本次文档校验冒充 SDK 或产品运行验证。
返回 UNKNOWN 时写清是未执行、输入不全、环境阻断，还是当前接入方式结构上无法观测。

源作者的事故数、候选排序、权限读数可以作为回归测试的线索，但没有独立重取证据时，
引用为“原作者记录”，不写成本次已核对事实。取证前提与覆盖也能被纠正，不能认为“测量永远不会错”。

## 7. 演进与退出脚手架

### 7.1 依赖顺序

| 步 | 产物 | 前置 | 退出条件 |
| --- | --- | --- | --- |
| G0 | 协议、状态脚本与分发脚本一致 | 无 | 历史已完成轮次和空轮次均得到人工一致的状态结果 |
| G1 | Interaction 现状 spike | G0 | 真实中断、同 thread 恢复、stale/重复/跨 Task 拒收有可复现实验 |
| G2 | 服务端 principal channel 与 Side Effect 强制点 | G1 | executor 无权伪造响应或直接写生产，失败关闭；不依赖本机可改门禁 |
| G3 | Agent Profile + executor adapter + 角色冲突门 | G1/G2 | 每个自动候选至少跑通一次 Attempt，字段值有探针证据 |
| G4 | `dev.change/1` 服务态与 T0/T1/T2 execution policy | G2/G3 | 三档真实 Task 与手工历史按 §5.3 等效，证据强度不下降 |
| G5 | 文档与脚手架收口 | G4 | 逐节迁移零缺口、引用清零、门禁全过、旧稿删除经人确认 |

G1 是本轮对旧路线的修正：先验证现有库原语，不先发明字段。G2 的判据针对真实写路径和服务端身份，
不以新增 Git 仓或轮换网络 key 代替产品授权。当前阶段游标见任务目录；目标顺序不因现状阻塞而改写。

### 7.2 从手工态拆到服务态

| 手工实现 | 服务实现 | 可拆条件 |
| --- | --- | --- |
| `round.md` Task 主档 | Task 表 | 三档至少各一条轨迹等效且 provenance 不下降 |
| commit + rulings + events 投影 | Event 表 | 同一历史轮次输出相同状态序列，新判据已人工对照 |
| 落盘通知与人工投喂 | executor adapter / principal channel | 自动执行器有进程入口；人工执行器有显式审计桥 |
| 多方竞争的环节判定 | acceptance runner | 对历史竞争逐条判定一致 |
| `git worktree add` | provision service | 独占、干净、基线判据进代码并有测试；worktree 载体可保留 |

事务、租约、fencing 只有服务态验收通过才算实现，不能用轨迹“相似”替代。

⚠ **而服务态那一侧已经验过了，这一栏因此不是「未来才能做的事」。**
产品仓（PostgreSQL 载体）现有测试全部通过，实跑 **156 passed, 2 skipped in 5.13s**：

| 项 | 测试 |
| --- | --- |
| fencing | `test_expected_version_prevents_two_workers_claiming_same_run` |
| 租约 / 并发 | `test_relational_schema_enforces_identity_and_concurrency_constraints`、`test_same_thread_rejects_second_non_terminal_run` |
| 副作用恰好一次 | `test_interrupt_resume_executes_side_effect_once`、`test_retry_after_crash_after_commit_does_not_repeat_effect` |
| 陈旧覆盖被拒 | `test_versioned_reducer_rejects_stale_plan_overwrite` |
| 取消先于副作用 | `test_cancelled_run_stops_before_side_effect_and_releases_thread` |

**所以缺的不是「并发语义没人验」，是「手工态与服务态的等效比对」还没做。**
两句话差别很大：前者指向一件未开工的事，后者指向一件已完成一半的事。

⚠ **这里容易写偏。**「**git 载体**验不了这三样」这句本身成立，
但只写这一句，**读起来像「本项目至今没验过」**。
教训：**「某载体证不了 X」与「X 未被证明」是两件事，不许合写。**

拆脚手架按组件逐项判，不因服务部署成功整批宣布完成：Task/Event 要比完整状态序列；
acceptance runner 至少对三轮可取得的历史产物逐条对照；每个拟自动路由的 Agent Profile
实际跑通一次 Attempt；人工桥接仍需记账；Interaction 还须证明响应者身份进入不同于执行者的
受保护凭据域。轨迹各类 attested 数量与最低 provenance 都不能退步。
这些是迁移验收条件，**不表示本次已完成等效实验**。

## 8. 本轮核查裁定

**这一节是隔离区，不是设计菜单。**它存在的唯一理由是**防止再犯**——
一个被推翻的设计如果只是悄悄消失，下一个人会照着同样的推理再走一遍。
所以两条形状规矩：

- **被证伪设计的裁定集中在本节，执行规则不得复活它们**（`amend_schema`、回执仓、候选仓、三道边界一类）。
  源稿 9 节 的历史取证记录与 源稿 10 节 的源标题只作来源辨认，不产生执行效力；词面检查须区分规范与历史引用；
- 本节每条必须**「独立观察」与「结论与落点」相邻**——
  只写结论不写观察，读者无从复核；只写观察不写落点，读者不知道它改变了什么。

### 8.1 六项逐条处置

以下命令均在 luna 自己的 worktree 或兄弟 `investment-app` 运行；不以任务书结论代替复核。

| # | 独立观察 | 结论与落点 |
| --- | --- | --- |
| K1 | `rg 'interrupt\(|Command\(resume=' investment-backend/app/app`；实际锚见 [§4.3](../components/05-interrupt-resume/composition/agent-dev-guide.md) | 出向和入向原语都接受业务值；删去平台自造的固定修订 schema，直接绑定产品 Interaction |
| K2 | 同一 `session_id → thread_id`，同一 checkpointer 上 `Command(resume=value)` | 原地恢复同一 Attempt；只有旧 Attempt 终态、重试或另一次执行才新建 Attempt |
| K3 | 宿主 `sudo -n -l` 返回 `NOPASSWD: ALL`；历史取证还记录 docker 与可写 remote | 同凭据域里的额外签名存储不能鉴别人和 agent；批准证据必须来自执行域外身份/服务 |
| K4 | `git branch -vv` 仅 master 有 upstream；全部参与分支是本地 worktree | Agent 产物以本地 commit 冻结和取件，不设计额外 push 中转作为前提 |
| K5 | `git ls-remote --tags origin` 只有 `2.0.0` 与 `pre-architecture-v2-final-20260813`，本地另有轮次标签 | 当前轮次发布/冻结不依赖远端 tag；换网络 key 不能控制本地 merge 或工作区写入 |
| K6 | K3–K5 显示待保护动作没有经过所设网络路径 | 撤销把三项旁路设施组合成安全架构的结论；逐条动作沿真实路径设置服务端强制点 |

远端 heads 在复核时为 `cursor/kimi/luna/master/opus/qwen` 六个同 SHA 分支；该事实只说明远端形状，
不证明任何身份或发布授权。`sudo` 与远端命令在受限沙箱内最初分别因 no-new-privileges 和 DNS 失败，
随后在宿主只读复核成功；两组结果不能混写成同一执行环境。

### 8.2 保留与撤销

保留：唯一内核、`dev.change/1`、五家 Agent Profile、确定性 router/orchestrator、权力表的“动作 + principal +
强制点”形状、工单、独占/干净/基线供给、Task/Attempt 投影、S/R 等效、比较上下文字段（不另立对象）、三维粒度、
E0–E4 证据等级、T0 成本上界、绕过的覆盖边界、四层验证、逐节迁移与删除门。

撤销：把人登记为执行器；把部署形态误命名成另一类 Profile；把自由 resume 原语扩成平台级编辑协议；
人介入后默认新开 Attempt；以及任何没有位于真实动作路径、却被宣称能强制授权或发布的旁路设计。

### 8.3 本次补吸收明确不采用的旧主张

冲突以底稿为准；只吸收成立的机制与证据纪律，不把相邻的旧结论一并恢复。

| 旧主张 | 本文处置与依据 |
| --- | --- |
| `agent-dev-refact`：已有凭据即批准、当前不用建任何边界、单 principal 无需区分 | **不采用**。技术可写不等于动作获批；§4.2 H5、§4.4 的身份与实际写路径强制仍成立 |
| 人自己写下一版就必须换 Attempt | **不采用这个触发条件**。人的内容归属保留；执行是否延续按 [§4.3](../components/05-interrupt-resume/composition/agent-dev-guide.md) checkpoint 和终态判，不按作者类型判 |
| 旧稿的固定编辑字段表与协议、介入后默认另开执行 | **不采用**。自由中断/恢复原语与产品 Interaction 已有绑定；未经真实需求不另造内核语义 |
| 把两种部署形式登记成两套 Profile；把人登记为执行器 | **不采用**。唯一产品运行时、Task Profile/Agent Profile 正交；人是 requester/principal 或内容贡献者 |
| 旧表把 H5 当作直接从等待写成功的边 | **不采用**。批准具体 Side Effect，再经合法排队、执行、验收和终态提交 |
| 旧表将取证/脚本/调用命令的存在当作当前已运行能力 | **不采用**。保留历史版本与未验证范围；现状按 §5.8 与 §5.13 重核 |
| 旧 R0–R5/S1 排期以及迁出多个目标文件的蓝图 | **不采用为现行路线**。目标顺序保留 §7.1 G0–G5；只保留相容的迁移、等效和删除条件 |
| 强制每个方案必须删掉至少一部分，不接受“都需要” | **部分采用**。保留“应检验必要性、允许更少机制”的问题，不预定必有可删项；必要性也须凭证据判 |
| “没有 Attempt 完成就绝不可能 Task 成功”的概括 | **不提升为内核不变量**。本文只约束开发链路候选须验收，不能从场景样例推全产品的充要条件 |
| 旧稿的历史状态、provider/model 表、经验计数可直接当今天事实 | **不采用**。作为指定版本的记录保存，不自动升为本次实测或当前路由配置 |

原稿各自“以本文为准”的页眉、独立文档存在理由、已过期归档状态也不继承其规范效力；
相容的背景、风险与方法已进正文，历史措辞只在来源索引中辨认。
