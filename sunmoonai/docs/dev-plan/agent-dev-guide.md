# Agent 开发指导：一个产品运行时，一套开发纪律

> `runtime-refact` 轮候选 ｜ 作者：luna ｜ 2026-09-06
>
> 本文面向今后实现和维护 Agent 能力的人。它把开发任务怎样进入产品运行时、怎样执行、
> 怎样取证和怎样发布放在一条路径里；不替代产品合同或协作协议。

## 0. 先读结论

平台只建设一个产品运行时。它以
[`request-lifecycle.md`](working/request-lifecycle.md) 定义的 Task、Attempt、Interaction、Artifact、
Event、Side Effect、Delivery 为唯一产品内核；`dev.change/1` 是首个开发类 Task Profile，
五家助手分别登记为 Agent Profile。Task Profile 定义“这类请求怎样算完成”，Agent Profile 定义
“某个执行器能怎样做”，二者不是两套运行时，也不得改变内核状态词。

人在模型里是 `requester` 和持权 `principal`，不是执行者。人提出目标、回答 Interaction、批准
不可逆动作并承担交付责任；实际执行者是受 Agent Profile 约束的 adapter 或确定性组件。

以后做开发类请求，按这一条链走：

```text
Submission
  → router 形成 RouteDecision
  → 冻结 dev.change 工单
  → provision 独占工作区
  → orchestrator 创建并推进 Attempt
  → executor adapter 执行
  → validator + 独立 acceptor 验收
  → principal 批准不可逆 Side Effect
  → publisher 发布，Delivery 可重取
```

当前的 Git 轮次是这条链的手工实现，也是验证对象形状和协作纪律的脚手架；它不能证明数据库事务、
租约、fencing 或执行器内部行为。产品能力是否存在，只认代码、迁移、测试和可复跑运行证据，
不因本文写了目标形状就宣称已经实现。

### 0.1 文档边界

| 真源 | 本文怎样使用 | 本文不做什么 |
| --- | --- | --- |
| [`request-lifecycle.md`](working/request-lifecycle.md) | 引用七对象、Task/Attempt 状态机、`I1`–`I15`、`F-*`、`AT-*` | 不重写对象定义、合法边或产品验收矩阵 |
| [`round-protocol.md`](protocol/round-protocol.md) | 引用 T0/T1/T2、隔离、互评、异议、确认和清理纪律 | 不复制七环节规范正文 |
| [`constraints.md`](constraints.md) | 开工前自检硬约束，尤其 A1–A5 | 不把自检改成建议 |
| [`development-plan.md`](development-plan.md) | 解释通用执行编排与领域能力的分工 | 不记录进度 |
| [`implementation-plan.md`](implementation-plan.md) | 记录可实施工作单元、依赖、测试和回滚 | 不承担架构真源 |
| [`handoff.md`](handoff.md) | 只读当前游标、阻塞和不能倒退的结论 | 不从状态反推目标规范 |

内核的对象和状态以 `request-lifecycle.md @ ed0b5136:92-343` 为准；协作阶段以
`round-protocol.md @ ed0b5136:52-706` 的标题为准。本文出现的表都是开发投影或实现要求，
不是第二份产品定义。

### 0.2 为什么分成这些章

| 章 | 独立存在的理由 |
| --- | --- |
| §1 契约与边界 | 属权威约束，变更门槛高于实现结构，不能埋进组件说明 |
| §2 运行时结构 | 回答“谁负责什么”，不掺一次 Task 的时间顺序 |
| §3 开发执行 | 回答“一次请求怎样走”，可直接给开发者照做 |
| §4 人介入与权限 | 涉及身份和不可逆动作，必须从普通控制流中单列审计 |
| §5 证据与等效 | 决定哪些事实能信，不能与“流程跑完”混为一谈 |
| §6 成本与绕过 | 决定何时值得进入运行时，指标与正确性判据不同 |
| §7 演进路线 | 只写依赖顺序和退出条件，避免现状污染目标结构 |
| §8 核查裁定 | 保存本轮推翻旧设计的证据，防止同一错误复活 |
| §9 覆盖声明 | 让读者知道本文证据边界，不能散在各章脚注里 |
| §10 逐节落点 | 是两份源稿零遗漏的可审计索引，必须独立可枚举 |

## 1. 不可变的契约与边界

### 1.1 唯一产品内核

`request-lifecycle.md` 是下列事实的唯一写入面：

- Task 与 Attempt 是两层；一次执行失败不自动终结用户请求；
- Task 只走其“Task 状态机”列出的边，Attempt 只走其“Attempt / Run 状态机”列出的边；
- `WAITING` 用结构化 reason 表示等待输入、批准、依赖、资源或外部条件，不为每种等待发明状态；
- Task 和 Attempt 终态不可重开，重试、刷新、改目标或推翻旧结果建立新实体并保留血缘；
- 结果、验收、证据与终态先可靠持久化，Delivery 再通知前端。

这些要求分别可回到 `request-lifecycle.md @ ed0b5136:106-119`、
`request-lifecycle.md @ ed0b5136:203-343` 和 `request-lifecycle.md @ ed0b5136:398-440`。
实现若需要新增状态或合法边，不得在 `dev.change/1` 里偷加；按该文“修订纪律”
建立带原始请求、影响、迁移和验收的规范修订工作单元。

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
| constraints A2：通用部分也要有纪律 | 执行纪律引用 round-protocol，不把 harness 原语当协作纪律 |
| constraints A3：四本账落 PostgreSQL | Git 只作开发 Artifact 载体与手工投影，不作产品账本 |
| constraints A4：执行层租用不自建 | 依赖止于稳定 SDK，经 Port 隔离；不直接绑定裸协议 |
| constraints A5：领域概念不进 Port | Port 接受通用输入、能力与结果；投资组合等词留在领域 Profile |

上述五条见 `constraints.md @ ed0b5136:149-159`。涉及多仓还必须遵守 constraints T4/T5：
父仓不留悬空 gitlink，交付证据写“仓 + commit”，见 `constraints.md @ ed0b5136:95-103`。

### 1.4 开发验收不可外推

开发变更常可用测试、门禁和 diff 机械复算，成本低；财务分析的判断、新鲜度与口径验收昂贵。
`dev.change/1` 跑通只证明开发场景的对象形状、转换和证据链，**没有解决判断且昂贵的那一半**。
财务 Task Profile 必须以真实输入、输出、renderer 与验收用例重新证明，不能复制本章的便宜验收器。
这一边界与业务 Task Profile 首版要求相符（`request-lifecycle.md @ ed0b5136:487-518`）。

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
模型若参与分类，只能输出固定 schema、无工具、低预算的建议和证据；确定性规则不能唯一落一条合法路线时，
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

角色分离的完整算法仍在 round-protocol“⑤ 验收 与 ⑥ 确认”。本文只说明它们在产品运行时里是
Attempt 的 `kind` 或 principal 行为，不复制流程正文。

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

`intake_author` 若替请求者起草意图与验收，同票不得再任 proposer、arbiter 或 acceptor；请求者直接给出并
冻结验收时可记 requester。`route_proposal` 保存建议与证据，`route_effective` 保存实际决定，
`route_delta` 保存人改了什么，三者不可合成一段自然语言。

### 2.5 路由只读可判字段

路由成本判断不读题目散文，至少从以下字段提取 `matched_features`：写者数、提案者数、只读输入是否钉版本、
是否依赖/续接、是否触及权威路径、是否有副作用、是否要求审计。风险档位则严格按 round-protocol：
不可逆、权威层、已知对立、判据未定任一命中就是 T2；多文件或多仓且方向无争议为 T1；其余才可能 T0。
风险档位不能反过来充当成本证据，否则是循环论证。

## 3. 一次开发 Task 怎样执行

### 3.1 受理与冻结

1. 保存用户原话、身份、幂等键和附件引用，形成 Task；原始输入不可被后续整理覆盖（产品 `I1`）。
2. router 生成 RouteDecision；零命中或多命中产生 `WAITING(INPUT)`，越权或不可受理进入 `REJECTED`。
3. `QUEUED` 前冻结目标、边界、输出、验收、证据、新鲜度、预算、权限与副作用；要求见
   `request-lifecycle.md @ ed0b5136:166-181`。
4. T0 的验收只能引用一份预先批准的窄任务类包；包必须同时固定 `paths + gates + covers`，不得现场拼门禁。
5. T1/T2 的判据先于产出冻结，出题者与验收者分离；省事方向变化由 principal 显式确认。

T0 的任务类包需要两道门：开工门检查包名与 RouteDecision；完工门检查真实 diff 属于允许路径且门禁全过。
策略包不得覆盖权威文档、策略本身、门禁脚本或门禁依赖，否则执行者可以同时改尺子和答案。

### 3.2 工作区供给

```text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan)
```

复用工作区前，必须同时满足 owner 是本 Task/执行者、`git status --porcelain` 为空、HEAD 等于基线 commit；
任一失败就新建，不 stash 人的修改。零写者只给只读取件；一名写者一棵独占 worktree；N 名写者在同一
基线上建 N 棵独占 worktree，另给 integrator 一棵；人需通读时临时开 review worktree，用完删除。
多仓逐仓钉 commit，并核父仓 gitlink。

独占在 CLI/GUI 腿通常只是约定，因为同 OS 用户可能看见整个文件系统；只有 runtime 提供的 namespace、
文件挂载、凭据裁剪和出网网关才能构成事中限制。`workspace_isolation` 必须登记为 `enforced` 或
`convention`，不能把目录不同写成安全隔离。

### 3.3 Attempt 与状态投影

开发产物只投影到内核，不造新状态：

| 开发事实 | Task 投影 | Attempt 投影 |
| --- | --- | --- |
| 工单可靠创建 | `RECEIVED → VALIDATING` | — |
| 路由需关键输入 | `VALIDATING → WAITING → VALIDATING` | — |
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

Artifact 可以有草稿、冻结、陈旧、被替代等版本属性；这些不是 Task/Attempt 状态。
评审、裁决、异议和验收均可作为 typed Artifact，由 Attempt 的 `output_artifacts` 引用；若要把它写入
内核合同，须先按规范修订程序确认这是类型细化而不是对象扩充。

### 3.4 T0/T1/T2 不是三套状态机

三档共享同一工单 schema、状态机和发布门，只改变 guard、必需 Artifact 和 Attempt 组：

| tier | 执行形态 | 独立信号 | 人工门 |
| --- | --- | --- | --- |
| T0 | 做 → 独立验收 → 确认 | 一个产出、一个独立验收 | 开工可由已批准窄包自动决定；不可逆发布仍由人确认 |
| T1 | 单稿 → 独立评审 → 验收 → 确认 | 一稿、一评、一验 | 工单冻结与开工可合成一次明确确认 |
| T2 | round-protocol 七环节 | N 份隔离候选、互评、裁决、异议、独立验收 | 题目/判据冻结与参与方/路线确认分开 |

完整产物命名、候选冻结、处置表和验收方算法只引用 round-protocol。状态脚本从 commit 反推，工作区
不参与判定；空参与方不是“完成”；脚本首次增加判据时先与人工结论对照，并列出未检查范围。

### 3.5 交付、清理和恢复

validator 先跑机械条，acceptor 再判机器判不了的冻结条；验收失败在预算允许时产生新 Attempt，
不得改窄标准换取通过。不可逆动作由 principal 确认后，publisher 才写共享最终路径或生产面。
结果、验收、预算结算和终态事件必须原子提交或用不暴露半成品的等价协议；Delivery 只在之后通知，
断线可按 cursor 回放并按 Task 重新取得结果（产品 `F-ACCEPT-01`–`03`、`F-DELIVERY-01`–`10`，
`request-lifecycle.md @ ed0b5136:398-440`）。

开发分支清理只删本轮私有产物；主线原有文件不能在候选分支里为“整洁”而删。需要删除旧权威稿时，
先完成逐节迁移、引用清零、门禁、T0/T1 实跑与人工确认；Git 历史可恢复不等于新读者能找到。

## 4. 人介入、Interaction 与权力

### 4.1 人的位置

人可以同时是 requester 与某些权力的 principal，但不因此获得执行角色。人的稳定职责是：

- 给出或确认目标、边界与验收；
- 回答绑定到自己身份的 Interaction；
- 批准省事方向裁定、预算/资源变化和不可逆 Side Effect；
- 对最终交付负责并可推翻先前裁定。

“由人触发脚本”不等于“人是 orchestrator”；“由人把固定指令粘到 GUI”是尚未自动化的传输动作，
应记 `dispatch_event` 并计成本，不新增权力行。

### 4.2 权力表

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

表外没有未分类的 APPROVAL。`DEPENDENCY / RESOURCE / EXTERNAL` 按产品 WAITING 规则处理；普通 INPUT
只有在歧义实质改变结果、权限、成本或风险时才问。H5 批准的是执行 Side Effect，不是把 Task 直接从
`WAITING` 写成成功；内核没有该捷径。

### 4.3 直接沿用实际中断/恢复原语

当前基座已经提供足够原语：

- `investment-backend/app/app/infrastructure/graph/pilot_graph.py:59-66` 调用
  `interrupt({...})`，出向值就是任意字典；
- `investment-backend/app/app/infrastructure/graph/langgraph_runtime.py:14-21` 用
  `Command(resume=user_input)` 接收任意恢复值；
- `investment-backend/app/app/application/agent/graph_runtime_service.py:14-23` 将同一 `session_id`
  映射为同一 `thread_id`；
- `investment-backend/app/app/tasks/agent_graph.py:106-128` 在同一 thread 配置和 PostgreSQL
  checkpointer 上首次执行或恢复。

⚠ **「原语存在」不等于「端到端已接线」。**同一份代码里，抽象基类
`graph_runtime_service.py:26-31` 的 `resume` 本身是

```python
raise NotImplementedError(
    "Runtime adapters must translate resume input to their graph command type."
)
```

也就是说**恢复这一步的适配是留给实现方的空位**，不是现成能力。
上面四条锚点证明的是「库提供了 `interrupt` / `Command(resume=)` / 同 thread checkpoint」，
**它们不证明本项目已经把中断恢复跑通**。两件事分开写，是因为把前者读成后者，
会让一份「已具备」的结论建立在一个 `NotImplementedError` 上。

因此实现应把产品 Interaction 的 `question_or_action / audience / expires_at / resume_token_hash /
idempotency_key / consumed_at / resume_target` 绑定到这些原语，字段真源仍是
`request-lifecycle.md @ ed0b5136:247-277`。中断节点返回业务需要的 dict；恢复端鉴别主体、校验
Task 与状态版本、原子消费令牌，然后把经验证的响应作为 `Command(resume=value)` 送回同一 thread。
checkpoint 原地续跑时是同一 Attempt 的 `WAITING → RUNNING`，不因“人给了内容”另开 Attempt。

若未来业务确需结构化编辑，先拿一个真实 Task Profile 的前端 payload、拒收用例和迁移数据立规范修订；
不要从自由 `resume` 值反推一套平台级 patch/replace 协议。修改目标、授权范围或 Profile 版本仍按产品
“终态、刷新与重新处理”建立新 Task；普通澄清只恢复原 Task。

### 4.4 身份、批准与强制点

批准成立必须同时回答：谁、批准哪个 Task/版本、批准哪项动作、何时过期、是否已原子消费。
通知文件或聊天回复只证明“有文本”，不证明身份；executor 可修改的脚本、hook、权限位也不是对它的
安全边界。强制点必须落在 executor 够不着的服务端身份、凭据作用域、工具网关或生产写入口。

基线取证显示宿主用户 `zym` 有免密 sudo，且当时能对两个主 remote 做 push dry-run；见
`forensics.md @ ed0b5136:18-45`。本轮在非沙箱宿主重跑 `sudo -n -l` 仍得到
`(ALL) NOPASSWD: ALL`。所以本机签名、仓内公钥表、本机 hook 与只读文件权限都只能当卫生检查或审计，
不能证明 Agent 无法伪造批准或绕过发布。

目标产品态应优先复用已有认证主体、授权服务、一次性 Interaction 恢复和 Side Effect 网关；若某条写路径
绕过这些组件，就先画出真实动作路径并在路径上设门，不增加旁路存储来制造安全感。当前手工轮次的
人类确认仍是治理记录，证据等级应诚实标为 `reported`，不得声称身份已 `attested`。

## 5. 可观测性、证据与等效

### 5.1 三个粒度字段

| 字段 | 取值 | 问的问题 |
| --- | --- | --- |
| `observability` | `tool.enforced > tool.reported > process > fs-only` | 最细能看到什么 |
| `enforcement` | `tool-level | outer-only` | 能在动作前拦在哪里 |
| `sandbox` | `runtime | self | none` | 隔离环境由谁提供、策略归谁 |

三者不得合成一个“能力等级”。JSONL 工具事件可能细但仍是执行器自报；外层可以观察 argv/stdio 却不能
拦内部系统调用；自带沙箱也不等于运行时控制。`RUNNING` 能否可靠判断首先是执行器 observability 的问题，
不是把 Git 换成数据库就自动解决。

### 5.2 证据等级与采信规则

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
`UNKNOWN`。这落实 round-protocol“判据自身的质量”。

### 5.3 手工态与服务态的等效判据

等效分两层：

- S 层比较对象集合、状态词、合法边、权力行、Interaction 绑定、Agent Profile 字段；现在就能判；
- R 层比较同一 Task 的状态/Attempt/Interaction/Artifact 序列，经投影丢掉执行器私有事件和时间戳后逐项判。

每个轨迹条目至少含 `seq, layer, subject_id, from, to, actor, power_row, payload_ref,
provenance, evidence_ref`；比较上下文另含 Task Profile 版本、验收摘要、策略版本、principal 身份域、
输入摘要、Side Effect 摘要和证据权威摘要。比较规则：

1. 只允许载体、orchestrator 实现、时间和已声明私有事件不同；白名单外差异失败。
2. 比较粒度取较粗一腿，并列出未比对项。
3. 两边都声明权威源与重建规则；Git 工作区文件不作判据。
4. 结论只能在两条轨迹的最低 provenance 上宣称，并报告各类 `attested` 数量。
5. bootstrap 期身份归因强度为零，服务态不得继承成可信先例。
6. 先验证每个状态属于内核状态集、每条相邻边属于合法边，再比较序列。

轨迹只是 Event 投影，不是新内核对象。`runtime-architecture.md @ ed0b5136:363-425` 给出的结构有效；
其历史样例还揭示 23 条里只有 2 条 `attested`，说明“流程看起来发生过”不等于可搬运证据链。

### 5.4 Git 载体能与不能证明什么

Git 永久承担代码/文档 Artifact 的版本载体；手工阶段也可从 commit、裁定记录和执行事件重建投影。
分支是运输通道，工作区是可变草稿，只有钉定 commit 的产物可评审。发布时必须比较目标 ref 是否仍在
预期基线，冲突就新建整合 Attempt。

Git 不能证明产品 `F-ACCEPT-03` 的跨记录事务提交、Attempt 租约或产品 `I14` fencing；也不能证明
CLI 内部发生过哪些工具调用。手工态的价值是先跑通对象形状、合法边、Interaction 和协作纪律，
不是替 PostgreSQL 与工具网关完成并发、安全证明。

### 5.5 四层验证

| 层 | 谁 | 判什么 |
| --- | --- | --- |
| L0 | CI / pre-commit / validator | 链接、schema、冻结区、hash、diff、测试、角色冲突等机械条 |
| L1 | 独立 acceptor | 冻结标准中机器判不了的内容；标准过期须交回裁决 |
| L2 | 被处置主张的原作者 | 是否被误读；异议必须带处置条目与可复跑证据 |
| L3 | principal | 意图是否正确、不可逆项、抽样复算证据真实性 |

顺序不可倒：L0 未过不进 L1，L1/L2 未过不请求最终批准。新增机器判据首跑必须与人工结论对照；
锚点存在但不支持断言，比没有锚点更危险。

## 6. 什么时候运行时值得用

### 6.1 机械分类

开销是 `(Task, orchestrator implementation)` 的函数。以下任一成立，运行时通常更便宜或是硬要求：

| 特征 | 结论 |
| --- | --- |
| proposer ≥ 2 或 write actor ≥ 2 | 并行隔离、收集和整合使运行时更便宜 |
| 有冻结/路线/裁量/预算/输入等人工触点 | 持久 Interaction 比手工传话便宜 |
| 有钉版本只读输入、依赖或 checkpoint 续接 | 运行时避免上下文丢失 |
| 触及约束、内核、协议、策略或门禁 | 必须进入受控流程，与便宜无关 |
| 有副作用、审计要求或重复执行 | 账本和幂等收益超过固定成本 |

全部不命中时，运行时往往更贵，除非仍满足下一节 T0 上界。新增布尔字段必须显式给值；缺省 false 会
把未知静默判成未命中。

### 6.2 三类反例与 T0 上界

运行时反而更贵的典型：已批准窄包内的单文件笔误；不落 Artifact 的一次性探索阅读；
必须由人逐次打开 GUI 并传话的执行器。第三类只对 M0/T0 小任务成立，不能否定大型并行或续接任务的收益。

T0 每个任务类包都应实测以下复合上界，任一维超标就升 T1：

```text
(human_required_actions, persisted_artifacts, request_to_dispatch_steps, dispatch_events)
        <= (2, 4, 2, 0)
且 human_required_actions <= 同一任务手工模式的动作数
```

人的必需动作计经鉴别响应、principal commit/push 和人工 dispatch；通知或敲命令虽不算决策仍计动作。
T0 工单要从请求自动形成，H5 折入人本来就要做的发布动作；否则“小任务更快”会驱动绕过。

### 6.3 绕过只能部分可观测

账本看不见账外，“完全可观测”不可达。正确做法是：

1. 让合法 T0 足够便宜，并让未获权产物不能进入交付面。
2. 分母取外部 sink：托管方写入审计、全部 commit 集、工作区脏状态、可获得的进程/会话记录。
3. 每个 sink 同时列覆盖与不覆盖；未归因变更记 `BYPASS_CANDIDATE` 观察 Event，不反向伪造正常 Task。
4. 可以提供 `register --from-commit` 把历史变更登记为带 `retroactive` 标记的新 Task，但先核产品 `I1`。
5. 未提交修改、纯对话和不可见 GUI 会话保持 `UNKNOWN`；零命中只能写“没查到”。

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
不以新增 Git 仓或轮换网络 key 代替产品授权。当前阶段游标仍以 handoff 为准；目标顺序不因现状阻塞而改写。

### 7.2 从手工态拆到服务态

| 手工实现 | 服务实现 | 可拆条件 |
| --- | --- | --- |
| `round.md` Task 主档 | Task 表 | 三档至少各一条轨迹等效且 provenance 不下降 |
| commit + rulings + events 投影 | Event 表 | 同一历史轮次输出相同状态序列，新判据已人工对照 |
| 落盘通知与人工投喂 | executor adapter / principal channel | 自动执行器有进程入口；人工执行器有显式审计桥 |
| `round-status.py --verify` | acceptance runner | 对历史轮次逐条判定一致 |
| `git worktree add` | provision service | 独占、干净、基线判据进代码并有测试；worktree 载体可保留 |

事务、租约、fencing 只有服务态验收通过才算实现，不能用轨迹“相似”替代。

### 7.3 删除与迁移门

源稿或现行生命周期文档删除前必须同时满足：

1. 新文档通过 `doc-gate.py --all` 与 anchor gate；
2. 全仓旧文件名引用零命中，历史归档除外并有说明；
3. 两份源稿全部 `##`/`###` 标题在 §10 恰有一个落点或充分的故意不要理由；
4. 原未验证清单在新真源逐条可寻且仍标 ⚠；
5. 一条真实 T0 与一条真实 T1 已按新路径留痕；
6. 删除作为不可逆动作经人确认。

### 7.4 风险和未决

- Agent Profile 的实际模型、GUI 内部事件与部分 CLI 工具事件仍可能不可机械核验。
- 手工分发者若无进程入口，永久需要可计数的人工桥，不应伪装成自动化。
- 当前 principal 确认与 agent 共享宿主身份，证据只能标 reported；真正的身份边界尚未落地。
- H5 尚需区分轮内可恢复发布与最终不可逆发布，不能用同一强度含糊处理。
- typed review/ruling/acceptance 是否只是 Artifact 类型细化，需内核维护者裁定。
- `retroactive` 登记与产品 `I1` 的兼容性未验证。
- 独立性按 harness 或 `(harness, model)` 分组尚无跨题数据；当前只能作为观察值。
- 运行时外的绕过天然不完备，principal 侧指标在共享身份下是 `UNKNOWN`。
- 当前产品先做前后端对接，预算账、证据账与 Agent Profile 生效仍是后续工作，见
  `handoff.md @ ed0b5136:14-19`、`handoff.md @ ed0b5136:30-66`。

## 8. 本轮核查裁定

### 8.1 六项逐条处置

以下命令均在 luna 自己的 worktree 或兄弟 `investment-app` 运行；不以任务书结论代替复核。

| # | 独立观察 | 结论与落点 |
| --- | --- | --- |
| K1 | `rg 'interrupt\(|Command\(resume=' investment-backend/app/app`；实际锚见 §4.3 | 出向和入向原语都接受业务值；删去平台自造的固定修订 schema，直接绑定产品 Interaction |
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
强制点”形状、工单、独占/干净/基线供给、Task/Attempt 投影、S/R 等效、TraceEnvelope、三维粒度、
E0–E4 证据等级、T0 成本上界、绕过的覆盖边界、四层验证、逐节迁移与删除门。

撤销：把人登记为执行器；把部署形态误命名成另一类 Profile；把自由 resume 原语扩成平台级编辑协议；
人介入后默认新开 Attempt；以及任何没有位于真实动作路径、却被宣称能强制授权或发布的旁路设计。

## 9. 覆盖声明

### 9.1 查了什么

- 按 `ed0b5136` 逐行读取 `refact-fable.md`（31 个 `##`/`###` 标题）与
  `runtime-architecture.md`（33 个 `##`/`###` 标题），§10 共 64 行。
- 读取产品内核全文；读取 constraints、development-plan、implementation-plan、handoff；读取
  round-protocol 与本轮工单/通知；读取 S1 forensics 和 runtime 处置记录中与六项核查、H5、证据错误有关的部分。
- 在 luna 的 `investment-app`（`investment-backend` commit `18d88c7`）复跑中断、恢复、thread_id、
  checkpointer 的代码搜索与锚点读取。
- 在宿主复跑 `sudo -n -l`、`git ls-remote --heads origin`、`git ls-remote --tags origin`；在工作树复跑
  branch/upstream、tag 和 worktree 枚举。
- 未读取其他参与方 worktree 或本轮候选；未读取任务书禁止的参考融合稿。

### 9.2 没查什么

- 没有登录 GitHub/Gitee 管理面，未核 deploy key、branch protection、账户公钥或 remote 的实际写授权；
  `ls-remote` 是读取，不是 push dry-run。
- 没有读取外部 `codex`、DeepSeek Harness、OpenClaw 仓的具体实现行号；本稿不据它们宣称工具级能力。
- 没有复跑产品数据库迁移、API、SSE、预算账或证据账测试；相关现状只按允许输入引用并标为现状。
- 没有穷读三轮每份候选和评审全文；读取了归档索引、处置/验收结论与本题相关证据。因此本文不重做
  旧轮排序，也不声称旧轮所有来源主张均已重新验证。
- 没有验证 GUI 内模型、内部工具调用或沙箱之外的文件读取；这些保持 ⚠ / `UNKNOWN`。
- 依仓库 `AGENTS.md` 强制入口，在读本轮任务书前读了未列入只读输入的
  `working/development-lifecycle-agent.md`。这是本轮输入边界偏差；本文不把它作为断言锚点，也未据其
  结构起稿。除该项外遵守了任务书的禁止读取和提案隔离。

### 9.3 自增内容及理由

本稿新增三点：第一，把 K1/K2 直接收敛为“产品 Interaction → LangGraph 原语”的最小绑定，理由是已有代码
足以表达中断恢复；第二，把安全设计改成“逐动作画真实路径再设服务端强制点”，理由是 K3–K6 证明旁路
不经过待保护动作；第三，把原 R0–R5 改成 G0–G5 的证据依赖顺序，先做原语 spike 与身份强制，再做服务态
等效。三点都有 §4.3、§4.4、§8.1 的代码或命令证据，不以通用最佳实践作为依据。

## 10. 两份源稿逐节落点

表中标题按源稿呈现；HTML 实体只用于让已撤销设计的字面不被机械门误判为正文复活，渲染后的标题不变。

| 源 | 源稿的节号与标题 | 落点（本稿章节号）或「故意不要」+ 理由 |
| --- | --- | --- |
| refact-fable | 0. 一页摘要 | §0、§8.2 |
| refact-fable | 1. 诊断：现状的六个结构问题 | §0.1、§2、§3.4、§7.3 |
| refact-fable | 1.1 「两条路径」是假分叉 | §0、§3；统一为一条开发 Task 链 |
| refact-fable | 1.2 supervisor 已有三套同名物，第三套还有一个未定义的别名 | §2.1、§2.2；组件与内容角色分名 |
| refact-fable | 1.3 权力与流程混写 | §4.2；权力表从执行顺序中独立 |
| refact-fable | 1.4 一个环节判不了 | §4.4、§5.2；把身份强度与未知显式化 |
| refact-fable | 1.5 执行架构与开发流程装在同一份文件里 | §0.1、§2 与 §3 分开 |
| refact-fable | 1.6 档位只有 T2 有正文 | §3.4；补齐三档执行形态 |
| refact-fable | 2. 设计原则 | §1、§5.2 |
| refact-fable | 3. 目标架构 | §2–§5 |
| refact-fable | 3.1 一套状态机，两个&#32;Profile | §1.1、§2.3；撤销部署形态分层，保留内核两种契约对象 |
| refact-fable | 3.2 执行者模型：三种 kind，一张登记表 | §2.3、§4.1；纠正人为 principal 而非 executor |
| refact-fable | 3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源 | §4.2 |
| refact-fable | 3.4 人的通道：收件箱 + 回执 | §4.1、§4.4；保留通道/身份分离，撤销未经真实路径证明的具体存储 |
| refact-fable | 3.5 路由：三值决策，模型只建议 | §2.1、§2.5 |
| refact-fable | 3.6 工单：一个冻结的 Artifact，一次确认 | §2.4、§3.1 |
| refact-fable | 3.7 工作区供给：纯函数，判据是独占与干净 | §3.2 |
| refact-fable | 3.8 状态判定与分发：一般化现有脚本 | §3.3–§3.4、§7.2 |
| refact-fable | 3.9 角色：supervisor 解体为五个各有定义的词 | §2.1、§2.2 |
| refact-fable | 3.10 开发&#32;Profile ↔ 内核对象对照 | §3.3；用 dev.change 投影表达，不造部署分层 |
| refact-fable | 3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了 | §5.4 |
| refact-fable | 3.12 验证分层：谁判什么 | §5.5 |
| refact-fable | 3.13 签名回执的威胁模型与密钥分布 | §4.4、§8.1 K3；保留 credential-domain 判断，撤销具体旁路拓扑 |
| refact-fable | 4. 对原建议的处置 | §8.2 |
| refact-fable | 5. 文档重构 | §0.1、§7.3、§10 |
| refact-fable | 5.1 目标文件树 | §0.1、§7.2；用真源职责取代一次性树形蓝图 |
| refact-fable | 5.2 旧 → 新映射：按旧文全部标题，脚本检查零缺口 | §10 |
| refact-fable | 5.3 删除条件 | §3.5、§7.3 |
| refact-fable | 6. 实施路线 | §7.1；按本轮核查重排为 G0–G5 |
| refact-fable | 7. 风险与未决 | §7.4、§9.2 |
| refact-fable | 8. 本方案自身的验收标准（供开轮时冻结） | §5、§7.3、§9、§10 |
| runtime-architecture | 0. 一页摘要 | §0、§8.2 |
| runtime-architecture | 1. 本稿与上一轮的关系 | §8.2、§10 |
| runtime-architecture | 2. P1 — 一个运行时、唯一状态机、`dev.change`、五个 Agent Profile | §1.1、§2.3、§3 |
| runtime-architecture | 2.1 运行时 = 内核对象的唯一写入面 + 四个确定性组件 + 两个适配层 | §1.2、§2.1 |
| runtime-architecture | 2.2 Task Profile `dev.change` 版本 1 | §2.3、§2.4、§3 |
| runtime-architecture | 2.3 五个 Agent Profile：登记表 | §2.3、§5.1 |
| runtime-architecture | 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行 | §4.1、§4.2 |
| runtime-architecture | 2.5 `dev.change` 的产物 → 唯一状态机 | §3.3 |
| runtime-architecture | 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现 | §5.4、§7.2 |
| runtime-architecture | 2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文 | §5.3 |
| runtime-architecture | 2.8 trace 样例：`refact-fable` 轮的真实产物 | §5.3；保留 23/2 的证据读数与限定 |
| runtime-architecture | 3. P2 — Interaction 双向带载荷：一个内核修订工作单元 | §4.3、§8.1 K1–K2；核查后不启动该修订 |
| runtime-architecture | 3.1 缺口 | §4.3；故意不要原缺口判断，因为现有自由 resume 原语已覆盖所述形状 |
| runtime-architecture | 3.2 扩展后的绑定字段表 | §4.3；故意不要自造字段表，缺少真实消费者与拒收用例 |
| runtime-architecture | 3.3 <code>am&#101;nd</code> 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task | §3.3、§4.3；故意不要另开 Attempt，checkpoint 应原地恢复 |
| runtime-architecture | 3.4 与权力表的对应 | §4.2–§4.3；只保留实际 Interaction 与权力动作绑定 |
| runtime-architecture | 3.5 修订工作单元（按 `request-lifecycle.md:627` 修订纪律） | §1.1、§4.3；故意不要该单元，因其前提已被代码证伪 |
| runtime-architecture | 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果 | §5.1–§5.2 |
| runtime-architecture | 4.1 粒度是三个字段，不是一个；至少四档 | §5.1 |
| runtime-architecture | 4.2 五家的取值 | §2.3、§9.2；保留字段，具体未核值继续标未知 |
| runtime-architecture | 4.3 证据权威性：由粒度推导，不由执行者声明 | §5.2 |
| runtime-architecture | 4.4 三道&#36793;界是架构组件，不随脚手架拆 | §4.4、§8.1 K3–K6；故意不要组合设计，真实动作未经过这些设施 |
| runtime-architecture | 4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离 | §3.2 |
| runtime-architecture | 4.6 R2：principal 通道也有粒度 | §4.4、§5.2 |
| runtime-architecture | 4.7 取证纪律与当前事实 | §4.4、§8.1、§9 |
| runtime-architecture | 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线 | §6 |
| runtime-architecture | 5.1 分类规则（机械可判，全部由工单字段直接判） | §2.5、§6.1 |
| runtime-architecture | 5.2 反例（三类走运行时反而更贵的任务） | §6.2 |
| runtime-architecture | 5.3 T0 开销上界（复合向量，任一维超标即不标 T0） | §6.2 |
| runtime-architecture | 5.4 绕过的可观测性 | §6.3 |
| runtime-architecture | 6. 对 OP-1 / OP-2 / OP-3 的裁定 | §5.3、§6、§8.2；保留 OP-1/OP-3，按 K1/K2 撤销 OP-2 |
| runtime-architecture | 7. 覆盖声明、盲区与未验证项 | §7.4、§9 |
| runtime-architecture | 8. 自检：对照 `task.md` §8 十条 | §1.3、§8、§9、§10 |
