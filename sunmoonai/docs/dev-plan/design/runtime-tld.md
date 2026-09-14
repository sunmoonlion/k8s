# 运行时总体设计（TLD）

> TLD｜S2。先立 PRD 与开发场景边界，再定组件/角色/持久责任，再解释开发状态投影，最后列取舍和禁止复活的旧设计；不能从实现方便反推需求。
>
> 2026-09-14 按 [dev-plan-architecture.md](../dev-plan-architecture.md) 第八节从 `1d0adde3` 迁入。每节前的 `<!-- Ixx-xxx -->` 是安置表 ID，冻结原文用 architecture 的 `show` 取。

## 目标与共同语言

S1 结果怎样约束架构、名词怎样保持同义；先读边界再看组件，历史版本说明跟随原主张。

<!-- I02-002 -->
### 先读结论

平台只建设一个产品运行时。它以
[`request-lifecycle.md`](../working/request-lifecycle.md) 定义的 Task、Attempt、Interaction、Artifact、
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

<!-- I02-003 -->
### 原来是什么样，为什么非改不可

**新读者先读这一节。**只看目标形状会觉得「本来就该这样」，
从而在下一次设计时把同样的坑再挖一遍。六个结构问题都是**在既有文档里能自证**的，
不是外部批评：

| # | 原来的问题 | 为什么它不是小毛病 |
| --- | --- | --- |
| 1 | 开发被写成**两条平行路径**（一条由服务建仓、一条由人建仓），再声明「后半段同构」 | 两条路径的差异最后只剩「**谁按了回车**」，撑不起两份文档，却制造了两份会各自漂移的真源 |
| 2 | 「supervisor」一个词同时指**三套不同的东西**，第三套还有个从没定义过职责边界的别名 | **每加一层就加一个名字，说明抽象层级选错了**。稳定的概念不是「谁监督谁」，是「这个状态转换由谁执行、需要什么权力、在哪里强制」 |
| 3 | 人的权力与流程步骤**混写**在上千行叙述里，另一份文档又抄一遍 | 那样的权力表是**第二份说明书，不是机制**——它不驱动任何东西，只能靠人记得读 |
| 4 | 有**一个环节命令判不了**（人的确认），只能靠人声明 | 与「状态从产物反推、不从声明读取」直接冲突，而**全自动化正好卡在这个洞上** |
| 5 | 产品**执行层架构**与开发流程装在同一份文件里，约五百行 | 两拨读者被迫读对方的东西；改一处要担心影响另一处 |
| 6 | 档位只有最重的那一档有正文，轻的两档各一行 | 没有可执行形态的档位**等于不存在**，日常任务只能绕过整套纪律 |

**本文的形状是这六条的答案**：一个运行时（对 1、5）、五个各有定义的角色词（对 2）、
一张驱动流程的权力表（对 3）、人的确认也落成可判的产物（对 4）、三档都有正文（对 6）。

<!-- I02-004 -->
### 文档边界

| 真源 | 本文怎样使用 | 本文不做什么 |
| --- | --- | --- |
| [`request-lifecycle.md`](../working/request-lifecycle.md) | 引用七对象、Task/Attempt 状态机、`I1`–`I15`、`F-*`、`AT-*` | 不重写对象定义、合法边或产品验收矩阵 |
| [`round-protocol.md`](../protocol/round-protocol.md) | `agent-dev-guide.md`「T2 七环节的操作闭环」至「停止、超时与回退不能省略」 汇总执行所需的阶段、取件、超时规则 | 不另立协议版本；协议改变时同步修订本导读 |
| [`constraints.md`](../constraints.md) | 开工前自检硬约束，尤其 A1–A5 | 不把自检改成建议 |
| [`development-plan.md`](../development-plan.md) | 解释通用执行编排与领域能力的分工 | 不记录进度 |
| [`implementation-plan.md`](../implementation-plan.md) | 记录可实施工作单元、依赖、测试和回滚 | 不承担架构真源 |
| [`handoff.md`](../handoff.md) | 只读当前游标、阻塞和不能倒退的结论 | 不从状态反推目标规范 |
| [`working/request-baseline/`](../working/request-baseline/) | **所有者的原始需求档案**：只解释来源，**不覆盖现行合同，也不证明当前能力**（`I1` 在本仓的实物） | 不据它断言现状 |
| 历史 archive 五稿及 README | 相容内容在本文正文，取舍与来源见 `records/development-history.md`「五份历史正文及目录说明的逐节处置」；只用于历史复核 | 不作为开发前置阅读；被撤销主张集中在 「本轮核查裁定」，不恢复其规范效力 |

内核的对象和状态以 `request-lifecycle.md @ ed0b5136:92-343` 为准；协作阶段以
`round-protocol.md @ ed0b5136:52-706` 的标题为准。本文出现的表都是开发投影或实现要求，
不是第二份产品定义。

<!-- I02-007：原章标题「不可变的契约与边界」无正文，不单列 -->

<!-- I02-008 -->
### 唯一产品内核

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

<!-- I02-013 -->
### 七条设计原则

全文的取舍都回到这七条。它们不是新主张，是把本仓已成文的判断当成设计约束用到底：

| # | 原则 |
| --- | --- |
| **P0** | **只有一套状态机（Task / Attempt）**，场景差异只体现在 Profile 的 guard、必需产物与 interrupt 策略；**任何场景不得新增状态词** |
| **P1** | **同一事实只有一个权威写入面**；两份同构文档即两个真源（`I13`，「四本账与单一权威写入面」） |
| **P2** | **状态从产物反推，不从声明读取**——人的动作也不例外 |
| **P3** | **方向不对称**：朝严谨可自裁，朝省事须人确认；⚠ **默认值属于省事方向** |
| **P4** | **判据必须声明覆盖范围**；⚠ **覆盖不全比没有更危险**（`design/evidence-sdd.md`「证据等级与采信规则」） |
| **P5** | ⚠ **凡能落成代码、测试或门禁的纪律必须落成**；文字只描述意图，不构成机制 |
| **P6** | **设计机制前，先核实它要处理的动作实际发生在哪里、由谁执行、经过什么路径**；未核前提只能标假设，验证办法见 `delivery/verification.md`「先核前提，也核控制面」 |

**两条推论：**

⚠ **一个只能靠人转述的环节等于没有环节**（P2 + P5）。这条决定了本文对人介入的全部设计：
`design/authority-sdd.md`「权力表」 的每一行都要有 `enforcement_point`，`design/authority-sdd.md`「身份、批准与强制点」 要求强制点落在执行者够不着的地方，
理由都在这里。

⚠ **P0 的适用层级是 Task 与 Attempt。**Artifact、Interaction 等对象各有自己的小生命周期
（「候选状态机」 的 `DRAFT → FROZEN → … → PUBLISHED`、内核的 `consumed_at`）——
**那些不是「第二套状态机」，而是对象属性**，并且同样跨场景共用、不得按场景另造。
把对象属性误认成状态机，会导致每个场景各造一套；把状态机误认成对象属性，
会导致状态词失控增长。**两边都错，方向相反。**

<!-- I02-107 -->
### 词汇对照

本表是阅读辅助；产品对象的精确定义与合法边仍归现行合同，**不另立一套产品状态机**。
读流程时尤其区分：Attempt 完成表示执行结束，Task 成功还要求冻结验收与交付条件成立。

| 内核用语 | 本文对应物 |
| --- | --- |
| Submission | 原始请求来源；人直接提出时由人冻结请求与验收（`agent-dev-guide.md`「受理与冻结」） |
| Task | 一件有边界的开发工作及其冻结契约（「`dev.change/1` 工单」） |
| Attempt | 一次实施、候选或修复轮次（「Attempt 与状态投影」） |
| Work Unit | 派出的子工作单元；**不是产品子 Task** |
| Artifact | 代码、补丁、报告、测试输出、证据（`agent-dev-guide.md`「私有地产生，单写者发布」） |
| Interaction | 向 principal 的澄清或批准请求（`design/executor-sdd.md`「直接沿用实际中断/恢复原语」） |
| Event | 只追加的事实记录，状态由其投影；可包含改判与证据引用（`delivery/verification.md`「证据账按流程分级」） |
| Side Effect | 对外部世界产生作用的动作及其持久意图/回执/补偿；不可逆部分受 H5 控制（`design/authority-sdd.md`「权限公式与只有 principal 能做的动作」） |
| Task Profile | 这类任务的输入、输出、验收、证据和策略契约，如 dev.change/1（「Task Profile 与 Agent Profile」） |
| Agent Profile | 执行器的能力、调用方式、粒度与边界；不是业务主档（「Task Profile 与 Agent Profile」） |
| principal / requester | 持有某项决定权的主体 / 提出请求的主体；身份与执行器分开（`design/authority-sdd.md`「人的位置」） |
| harness / executor adapter | 执行外壳（程序、提示词、工具）/ 将其公开 SDK 接到统一 Port 的适配层（`design/executor-sdd.md`「执行层：租用什么、自建什么」至「统一执行 Port 与三态能力探针」） |
| router / orchestrator | 确定性路由 / 状态推进、派发、收集与停止组件，不是自由 Agent 角色（「确定性组件与适配层」） |
| provenance | attested 为可实证归因、reported 为自报、inferred 为推断；具体采信还受覆盖与隔离限制（`design/evidence-sdd.md`「证据等级与采信规则」） |
| S / R / 投影 Π | 结构等效 / 轨迹等效 / 比较前只丢弃约定私有事件与时间戳（`design/evidence-sdd.md`「手工态与服务态的等效判据」） |
| 登记集合 / 自动路由候选集 | 知道某执行器存在 / 已具备获准自动调用与审计能力的子集（「Task Profile 与 Agent Profile」） |
| 未归因效应 | 外部观察到但找不到对应账目的变更；只记录，不伪造事前 Task（`design/evidence-sdd.md`「绕过只能部分可观测」） |
| H1–H8 / T0–T2 / E0–E4 | 权力行 / 风险流程档位 / 证据等级，三个不同维度（`design/authority-sdd.md`「权力表」、「T0/T1/T2 不是三套状态机」、`design/evidence-sdd.md`「证据等级与采信规则」） |
| Delivery | 最终回复与可重取产物（`agent-dev-guide.md`「交付、清理和恢复」） |
| Handoff | [`handoff.md`](../handoff.md)；**单写者面**（`agent-dev-guide.md`「跨会话续接」） |
| 工作区 / worktree | 每个可写执行者的并行隔离工作区（`agent-dev-guide.md`「工作区供给」、`agent-dev-guide.md`「私有地产生，单写者发布」） |
| 命名分支 | 一执行者一分支；commit 的**运输通道，不是评审对象**（`agent-dev-guide.md`「冻结、迟到与取消」） |
| 未提交工作区文件 | 仅本地草稿；**同一工作区同一路径后写覆盖先写**（`agent-dev-guide.md`「并发场景处置表」） |
| 人的主 checkout | 如 `~/master/<仓>`；**只读参照，不是投稿箱**（`agent-dev-guide.md`「私有地产生，单写者发布」） |
| Attempt 租约 / fencing | **产品侧机制**，语义见内核；**开发侧无等价运行时**，迟到判定靠冻结 commit 与整合方核对（`agent-dev-guide.md`「冻结、迟到与取消」） |
| `dispatch_event` | 人代运行时执行的一次传输动作；**不是权力，是可计数的欠账**（`design/evidence-sdd.md`「三个粒度字段」） |

## 组件责任与派工接口

Task/四账/Profile/路由/角色分工作为架构责任一起定义；SDK 包级调用留 executor SDD，批准强制留 authority SDD。

<!-- I02-015：原章标题「一个运行时的结构」无正文，不单列 -->

<!-- I02-016 -->
### 确定性组件与适配层

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
⚠ **分类节点的产出形状是「「路由只读可判字段」 那四条风险判据各自命中与否 + 证据」**，
由确定性规则表据此判 tier——**模型不给 tier，只给四条的命中证据**；确定性规则不能唯一落一条合法路线时，
结果必须是 `ask` 或 `refuse`，不得默认落“通用”。这延续产品 `F-DISPATCH-03` 与 constraints A2–A4，
并避免路由自身成为第三个自由 Agent。

<!-- I02-009 -->
### 四本账与单一权威写入面

预算、幂等、副作用和证据必须跨 run、跨进程死亡仍然正确，因此权威记录落 PostgreSQL；
外部 harness 的内存、Git 文件或日志只能是输入、Artifact 或可重建投影。产品 `I13` 要求一个
可变事实只有一个权威写入面，产品 `I4` 要求状态集中校验、事件只追加；出处为
`request-lifecycle.md @ ed0b5136:444-483`。当前实现已有幂等与副作用，预算与证据仍缺，
这只是 `development-plan.md @ ed0b5136:97-108` 的现状，不得写成目标已完成。

<!-- I06-003 -->
### 智能体分两部分

| | 通用部分 | 专用部分 |
| --- | --- | --- |
| 内容 | 执行编排：轮次、隔离、中断恢复、审批、工具协议 | 领域：提示、工具绑定、权限、memory policy、领域约束 |
| 载体 | 执行运行时 + [`round-protocol.md`](../protocol/round-protocol.md) | `AgentProfile` |
| 纪律 | 隔离、三阶段、提案包构造、评审协议、重叠分歧判据 | 零证据即失败、citation 只回同源、结论可复现 |

**两部分都必须有纪律**，不存在"通用部分不需要约束"。

新增一个业务智能体，**优先是新增一份 Profile，而不是 fork 一套代码**。

<!-- I06-004 -->
#### 四本账是两部分共用的地基

预算、幂等、副作用、证据四本账**不属于任何一侧，且必须落 PostgreSQL**。

判据：**跨 run、或跨进程死亡仍须正确的不变量，必须由存储承担。**
任何把账放在执行进程本地的方案（含外部 harness 自带的存储）都不满足——
投资研究跑在多 worker 上，进程可被杀。

<!-- I02-017 -->
### 内容角色

| 角色 | 职责 | 冲突限制 |
| --- | --- | --- |
| `proposer` | 独立产出候选 | 提案冻结前不可见其他候选 |
| `reviewer` | 按冻结标准比较全部候选 | 必须声明自己也是候选作者的利益冲突 |
| `arbiter` | 定基座、逐条吸收、处置异议 | 不兼 orchestrator；票数不是事实依据 |
| `objector` | 只核自己主张是否被误读 | 不代替 acceptor 评整稿 |
| `acceptor` | 按冻结标准独立验收 | 不得是 arbiter 或基座作者 |
| `publisher` | 在批准后执行发布 Attempt | 不能自己授予发布权限 |

角色分离以 round-protocol“⑤ 验收 与 ⑥ 确认”为准，本文 `agent-dev-guide.md`「T2 七环节的操作闭环」 给出操作算法。
这些角色在产品运行时里是 Attempt 的 `kind` 或 principal 行为，不新增内核对象。

<!-- I02-018 -->
### Task Profile 与 Agent Profile

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

<!-- I02-026 -->
### 派工契约、角色补充与隔离的诚实边界

**派工契约（Work Unit）与工单（「`dev.change/1` 工单」）是两层**：工单冻结整个 Task，派工契约冻结**一个执行者
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
worktree、共享发布面，以及非协调者不得写的单写者文件（如 `handoff.md`）。
**这三个字段不是描述性说明，是 `agent-dev-guide.md`「物化门禁与写入前门禁」 写入前门禁的判定输入——派工时缺任一字段，
执行者不得开始写。**

派工**只能收窄**父 Task。父预算覆盖所有 Work Unit、Attempt、工具、评审和改进。
多个 Work Unit **不得同时权威写同一可变事实**；先划分所有权，无法划分则串行。

**人在这套模型里有三个角色，不可互相替代：**

1. **请求提出者**——提出有边界的工作，给原始意图、范围和验收期望；
2. **内容贡献者**——亲自实施部分工作，与助手交替推进；内容以本人署名的 Artifact 或 Interaction 响应进入系统，**不据此把人登记为 Agent Profile 或产品 Attempt 执行器**；
3. **principal**——批准、取消、追加成本和终审验收的最终权力。**第三种助手不能替代。**

⚠ 助手不得自我批准；**人也不得把终审责任外包给助手后不再复核**（`design/authority-sdd.md`「权限公式与只有 principal 能做的动作」 责任归属表）。

⚠ **候选隔离目前靠纪律，不靠机制。**候选冻结前只读同一任务包、基线和各自获准上下文，
不得读其他候选、**发起方偏好**或预设解法；看到已有答案之后产出的内容属于评审或改进，
**不再是独立候选**。但——

> **脚本化产生候选目前没有可用工具**（曾有的 `parallel-proposals.py` 已于 2026-09-06 删除：
> 三轮一次没用过、真实模型调用从未验证、只覆盖 codex 系执行者）。在此之前，
> **隔离靠纪律，而且无法事后证明某一轮真的独立。不得据此声称隔离由机制保证。**

<!-- I02-019 -->
### `dev.change/1` 工单

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
——最后四项是 `agent-dev-guide.md`「私有地产生，单写者发布」 命名空间纪律在工单上的落点。

`intake_author` 若替请求者起草意图与验收，同票不得再任 proposer、arbiter 或 acceptor；请求者直接给出并
冻结验收时可记 requester。`route_proposal` 保存建议与证据，`route_effective` 保存实际决定，
`route_delta` 保存人改了什么，三者不可合成一段自然语言。

<!-- I02-020 -->
### 路由只读可判字段

路由成本判断不读题目散文，至少从以下字段提取 `matched_features`：写者数、提案者数、只读输入是否钉版本、
是否依赖/续接、是否触及权威路径、是否有副作用、是否要求审计。风险档位则严格按 round-protocol：
不可逆、权威层、已知对立、判据未定任一命中就是 T2；多文件或多仓且方向无争议为 T1；其余才可能 T0。
风险档位不能反过来充当成本证据，否则是循环论证。

## 内核在开发场景的投影

把已有产品对象映射到开发载体；候选版本不是新 Task 状态。状态脚本只能投影，不另立内核。

<!-- I02-031 -->
### Attempt 与状态投影

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

<!-- I02-032 -->
### T0/T1/T2 不是三套状态机

三档共享同一工单 schema、状态机和发布门，只改变 guard、必需 Artifact 和 Attempt 组：

| tier | 执行形态 | 独立信号 | 人工门 |
| --- | --- | --- | --- |
| T0 | 做 → 独立验收 → 确认 | 一个产出、一个独立验收 | 开工可由已批准窄包自动决定；不可逆发布仍由人确认 |
| T1 | 单稿 → 独立评审 → 验收 → 确认 | 一稿、一评、一验 | 工单冻结与开工可合成一次明确确认 |
| T2 | round-protocol 七环节 | N 份隔离候选、互评、裁决、异议、独立验收 | 题目/判据冻结与参与方/路线确认分开 |

产物命名、候选冻结、处置表和验收方算法见 `agent-dev-guide.md`「T2 七环节的操作闭环」至「停止、超时与回退不能省略」，来源为现行 round-protocol。状态脚本从 commit 反推，工作区
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

⚠ 把载体轴写成档位轴，与 「路由只读可判字段」「风险档位不能反过来充当成本证据」是同一种循环。

<!-- I02-039 -->
### 候选状态机

```text
DRAFT → FROZEN(commit/digest) → SUBMITTED
      → {SELECTED | REJECTED | STALE | SUPERSEDED}
      → INTEGRATED（仅被采用部分） → VERIFIED(final commit)
      → PUBLISHED → RETAINED / GARBAGE_COLLECTED
```

⚠ **这些是 Artifact 的版本属性，不是 Task/Attempt 状态**（「Attempt 与状态投影」 末段）。七条纪律：

- `DRAFT` 可改，但只存在于 owner 可写面，**不能被称为候选完成**；
- `FROZEN` 后**不得原地替换**，修订产生新 commit/digest 并用 `supersedes` 关联；
- `SELECTED` 只表示进入整合，**不表示已发布**；
- `INTEGRATED` 必须记录**实际吸收的 commit/patch/Artifact**，不能只写「已吸收」；
- `VERIFIED` 只针对 final commit；
- `PUBLISHED` 必须记录发布目标、发布者、版本和时间；
- 清理前必须证明**所需对象仍有可达 ref 或已进入持久 Artifact**。

<!-- I02-045 -->
### 内核对象 ↔ 开发载体对照

⚠ **「只有一套状态机」不是口号，这张表是它的证明**：开发侧每个产物都对应一个内核对象，
且 Task 状态**一律推导**，不另立。

| 内核对象 | 开发侧载体（手工态） | 产品侧载体（服务态） |
| --- | --- | --- |
| Task | 工单所属的那件事 | `task` 行 |
| **Task 状态** | ⚠ **纯推导**：由 Attempt 产物、裁定记录、受保护 tag 反推（「Attempt 与状态投影」） | `state`（Event 投影） |
| Attempt | 一家在一个环节的一次交付（一个 commit） | `attempt` 行 |
| Interaction | 收件箱条目 + 落盘回执 | `interaction` 行 + `resume_token` |
| Artifact | 工单、候选、评审、裁决稿、异议、验收稿（按 commit 冻结） | 对象存储 + `artifact` 行 |
| Event | git 提交历史 + 裁定记录（只追加） | `event` 行（只追加） |
| Side Effect | 写共享最终路径、push 主线（`design/authority-sdd.md`「权力表」 H5 门） | 副作用账 |
| Delivery | 主线上的最终稿 + 检视 worktree | `F-DELIVERY-*` |
| RouteDecision | 工单 `route_effective` | `route_decision` 行 |
| 预算 | 观察窗规则、轮次上限、回退上限 | 预算账（`I10`） |

⚠ **左右两列换的是载体，不是语义。**`design/evidence-sdd.md`「手工态与服务态的等效判据」 的等效判据就是在这张表上做的：
S 层比对象与边，R 层比一次执行的序列。

<!-- I02-046 -->
### 状态脚本的硬要求

脚本「从产物反推、判据即命令、只生成不执行」这三条是对的，要补的是**判错时必须停**：

| 要求 | 违反会怎样 |
| --- | --- |
| 输出 **Task 状态（内核状态词）+ 当前环节 + 各 Attempt 状态**；⚠ **环节是投影，状态是判据** | 只输出「当前环节」，就把投影当成了真源 |
| 工单里若有 `status` 声明字段，**降为人读缓存并由脚本校验**：⚠ **推导值 ≠ 声明值即报错退出** | 声明与产物漂移，而没有人会发现 |
| 每次状态推导**同时输出「上一状态 → 本状态」**；⚠ **边不在内核合法转换表内即报错退出** | 只校验状态点会漏掉非法边——这是真实抓到过的漏检形态（`design/evidence-sdd.md`「手工态与服务态的等效判据」 规则 6） |
| 分发前对照 `roles_allowed` 与角色分离禁令，**冲突即拒绝并给 reason** | 角色冲突要到验收时才暴露，那时已经晚了 |
| ⚠ **每条判定声明覆盖范围**（P4）：输出里「查了什么、没查什么」与结论并列；**零命中要能区分「真的没有」与「没查到」** | 门禁在边界上给假答案，而它看起来是绿的 |
| 按工单 `tier` 读取对应 guard 表与必需产物表，**不写死某一档** | 轻档位没有可执行形态，等于不存在（「原来是什么样，为什么非改不可」 第 6 条） |

状态推导还须读取 orchestrator 单写的执行事件：产物未出现只能说明“尚无交付”，
不能区分未派发、执行中、崩溃、失联或超时。无法程序分发的执行器应输出明确投喂说明，
并记录实际的 `dispatch_event`；生成了一条命令不等于该命令已经执行。

## 已决定的取舍及其依据

哪些旧方案不能重新成为设计菜单；独立观察与结论相邻，撤销项仍可追溯。产品取舍不是某次运行进度。

<!-- I06-002 -->
### 起点：不延续 v5

`mooc-manus-langgraph-longterm-plan-v5.md` 及其实施计划降级为**历史设计输入**。

理由是它的重心不对：主体是前后端对接（§10 消息/事件/投影/流式 200 行，
而 §14 多智能体架构只有 23 行；实施计划 17 个前端任务对 14 个 Runtime 任务，
多智能体只有一个"薄切"且 `NOT_STARTED`）。

**它的前后端对接部分仍然有效且详尽**，做那一阶段时逐节引用。
但它不是智能体架构的依据。

不做版本号延续——叫 v6 会隐含继承那个以前端为重心的框架，
而我们恰恰要摆脱它。

<!-- I06-010 -->
### 有意留白的两处

模板提供了原语但实例没接，这是**决定**，不是欠账。投影只能证明"零调用"，
证明不了"有意"——所以理由和重新审视的触发条件写在这里。

| 项 | 为什么现在不接 | 什么时候重新审视 |
| --- | --- | --- |
| 共享 Outbox / Inbox | 没有业务需要之前接上去，等于凭空加一块要维护、要监控、要排障的面 | **第一个跨 App 异步事件落地时**，届时一并定投递语义与去重键 |
| Celery `beat_schedule` | 同上 | **第一个定时任务落地时**，届时须解决 beat 的多副本重复触发 |

<!-- I08-008 -->
### 不能倒退的输入

以下已经定了，接手时**不要重新讨论**：

| | 结论 | 定于 |
| --- | --- | --- |
| 施工顺序 | 前后端对接 → agent 开发 → 问数 | 2026-08-29 |
| 问数的位置 | 专用智能体的一个实例（加一份 Profile + 一个工具），不是另一套架构 | 2026-08-29 |
| SQLBot / WrenAI | **参考资料，不是选型候选** | 2026-08-29 |
| v5 的地位 | 历史设计输入；其 §10 前后端对接仍有效且详尽，做阶段一时逐节引用 | 2026-08-29 |
| 四本账 | 幂等、副作用已接线；缺预算与证据 | 取证于 2026-08-29 |

<!-- I02-091 -->
### 本轮核查裁定

**这一节是隔离区，不是设计菜单。**它存在的唯一理由是**防止再犯**——
一个被推翻的设计如果只是悄悄消失，下一个人会照着同样的推理再走一遍。
所以两条形状规矩：

- **被证伪设计的裁定集中在本节，执行规则不得复活它们**（`amend_schema`、回执仓、候选仓、三道边界一类）。
  `records/development-history.md`「覆盖声明」 的历史取证记录与 `records/development-history.md`「五份历史正文及目录说明的逐节处置」 的源标题只作来源辨认，不产生执行效力；词面检查须区分规范与历史引用；
- 本节每条必须**「独立观察」与「结论与落点」相邻**——
  只写结论不写观察，读者无从复核；只写观察不写落点，读者不知道它改变了什么。

<!-- I02-092 -->
### 六项逐条处置

以下命令均在 luna 自己的 worktree 或兄弟 `investment-app` 运行；不以任务书结论代替复核。

| # | 独立观察 | 结论与落点 |
| --- | --- | --- |
| K1 | `rg 'interrupt\(|Command\(resume=' investment-backend/app/app`；实际锚见 `design/executor-sdd.md`「直接沿用实际中断/恢复原语」 | 出向和入向原语都接受业务值；删去平台自造的固定修订 schema，直接绑定产品 Interaction |
| K2 | 同一 `session_id → thread_id`，同一 checkpointer 上 `Command(resume=value)` | 原地恢复同一 Attempt；只有旧 Attempt 终态、重试或另一次执行才新建 Attempt |
| K3 | 宿主 `sudo -n -l` 返回 `NOPASSWD: ALL`；历史取证还记录 docker 与可写 remote | 同凭据域里的额外签名存储不能鉴别人和 agent；批准证据必须来自执行域外身份/服务 |
| K4 | `git branch -vv` 仅 master 有 upstream；全部参与分支是本地 worktree | Agent 产物以本地 commit 冻结和取件，不设计额外 push 中转作为前提 |
| K5 | `git ls-remote --tags origin` 只有 `2.0.0` 与 `pre-architecture-v2-final-20260813`，本地另有轮次标签 | 当前轮次发布/冻结不依赖远端 tag；换网络 key 不能控制本地 merge 或工作区写入 |
| K6 | K3–K5 显示待保护动作没有经过所设网络路径 | 撤销把三项旁路设施组合成安全架构的结论；逐条动作沿真实路径设置服务端强制点 |

远端 heads 在复核时为 `cursor/kimi/luna/master/opus/qwen` 六个同 SHA 分支；该事实只说明远端形状，
不证明任何身份或发布授权。`sudo` 与远端命令在受限沙箱内最初分别因 no-new-privileges 和 DNS 失败，
随后在宿主只读复核成功；两组结果不能混写成同一执行环境。

<!-- I02-093 -->
### 保留与撤销

保留：唯一内核、`dev.change/1`、五家 Agent Profile、确定性 router/orchestrator、权力表的“动作 + principal +
强制点”形状、工单、独占/干净/基线供给、Task/Attempt 投影、S/R 等效、比较上下文字段（不另立对象）、三维粒度、
E0–E4 证据等级、T0 成本上界、绕过的覆盖边界、四层验证、逐节迁移与删除门。

撤销：把人登记为执行器；把部署形态误命名成另一类 Profile；把自由 resume 原语扩成平台级编辑协议；
人介入后默认新开 Attempt；以及任何没有位于真实动作路径、却被宣称能强制授权或发布的旁路设计。

<!-- I02-094 -->
### 本次补吸收明确不采用的旧主张

冲突以底稿为准；只吸收成立的机制与证据纪律，不把相邻的旧结论一并恢复。

| 旧主张 | 本文处置与依据 |
| --- | --- |
| `agent-dev-refact`：已有凭据即批准、当前不用建任何边界、单 principal 无需区分 | **不采用**。技术可写不等于动作获批；`design/authority-sdd.md`「权力表」 H5、`design/authority-sdd.md`「身份、批准与强制点」 的身份与实际写路径强制仍成立 |
| 人自己写下一版就必须换 Attempt | **不采用这个触发条件**。人的内容归属保留；执行是否延续按 `design/executor-sdd.md`「直接沿用实际中断/恢复原语」 checkpoint 和终态判，不按作者类型判 |
| 旧稿的固定编辑字段表与协议、介入后默认另开执行 | **不采用**。自由中断/恢复原语与产品 Interaction 已有绑定；未经真实需求不另造内核语义 |
| 把两种部署形式登记成两套 Profile；把人登记为执行器 | **不采用**。唯一产品运行时、Task Profile/Agent Profile 正交；人是 requester/principal 或内容贡献者 |
| 旧表把 H5 当作直接从等待写成功的边 | **不采用**。批准具体 Side Effect，再经合法排队、执行、验收和终态提交 |
| 旧表将取证/脚本/调用命令的存在当作当前已运行能力 | **不采用**。保留历史版本与未验证范围；现状按 `design/evidence-sdd.md`「上下文路由与能力四级词典」 与 `design/evidence-sdd.md`「历史取证怎样用于今天的开发」 重核 |
| 旧 R0–R5/S1 排期以及迁出多个目标文件的蓝图 | **不采用为现行路线**。目标顺序保留 `development-plan.md`「依赖顺序」 G0–G5；只保留相容的迁移、等效和删除条件 |
| 强制每个方案必须删掉至少一部分，不接受“都需要” | **部分采用**。保留“应检验必要性、允许更少机制”的问题，不预定必有可删项；必要性也须凭证据判 |
| “没有 Attempt 完成就绝不可能 Task 成功”的概括 | **不提升为内核不变量**。本文只约束开发链路候选须验收，不能从场景样例推全产品的充要条件 |
| 旧稿的历史状态、provider/model 表、经验计数可直接当今天事实 | **不采用**。作为指定版本的记录保存，不自动升为本次实测或当前路由配置 |

原稿各自“以本文为准”的页眉、独立文档存在理由、已过期归档状态也不继承其规范效力；
相容的背景、风险与方法已进正文，历史措辞只在来源索引中辨认。
