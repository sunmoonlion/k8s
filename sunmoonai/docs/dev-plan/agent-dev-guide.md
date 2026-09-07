# Agent 开发指导：一个产品运行时，一套开发纪律

> **底稿**：`runtime-refact` 轮定稿 ｜ 基座作者：luna ｜ 2026-09-06 ｜ 裁决方 opus 吸收 11 条
> **扩充**：2026-09-07 由 opus 吸收 `archive/` 两份 lifecycle 共 118 节（所有者指令）。
> 扩充只**新增**章节号（§2.6–§2.10、§3.6–§3.9、§4.5–§4.8、§5.6–§5.7、§7.5、§11–§14），
> **未改动任何既有章节号**——本文内部有约 120 处 `§N` 自引用，重编等于制造静默失效。
> 逐节落点见 §10（182 行）；本次的覆盖与盲区单列于 §9.4，不混入 §9.1–§9.3。
>
> 本文面向今后实现和维护 Agent 能力的人。它把开发任务怎样进入产品运行时、怎样执行、
> 怎样取证和怎样发布放在一条路径里；不替代产品合同或协作协议。
>
> ⚠ **本文现在是这条谱系唯一的活文档。**`archive/` 下四份历史稿的内容已全部落点到本文，
> 与本文冲突时**一律以本文为准**。

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

### 0.0 原来是什么样，为什么非改不可

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

### 0.1 文档边界

| 真源 | 本文怎样使用 | 本文不做什么 |
| --- | --- | --- |
| [`request-lifecycle.md`](working/request-lifecycle.md) | 引用七对象、Task/Attempt 状态机、`I1`–`I15`、`F-*`、`AT-*` | 不重写对象定义、合法边或产品验收矩阵 |
| [`round-protocol.md`](protocol/round-protocol.md) | 引用 T0/T1/T2、隔离、互评、异议、确认和清理纪律 | 不复制七环节规范正文 |
| [`constraints.md`](constraints.md) | 开工前自检硬约束，尤其 A1–A5 | 不把自检改成建议 |
| [`development-plan.md`](development-plan.md) | 解释通用执行编排与领域能力的分工 | 不记录进度 |
| [`implementation-plan.md`](implementation-plan.md) | 记录可实施工作单元、依赖、测试和回滚 | 不承担架构真源 |
| [`handoff.md`](handoff.md) | 只读当前游标、阻塞和不能倒退的结论 | 不从状态反推目标规范 |
| [`working/request-baseline/`](working/request-baseline/) | **所有者的原始需求档案**：只解释来源，**不覆盖现行合同，也不证明当前能力**（`I1` 在本仓的实物） | 不据它断言现状 |
| [`archive/`](archive/) 四份历史稿 | **已全部吸收，见 §10**：两份 lifecycle、`refact-fable`、`runtime-architecture` | 不再引用其正文作为规范依据；它们与本文冲突时以本文为准 |

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
| §10 逐节落点 | 是四份源稿零遗漏的可审计索引，必须独立可枚举 |
| §11 反模式 | 机制描述，与 §8「已被推翻的设计」不同：前者是任何项目都会踩的做法 |
| §12 失败实例 | 本项目**实际**踩过的，按证据强度分三级；与 §11 分开，防止把「机制上必然」写成「此处已核对」 |
| §13 词汇对照 | 内核对象名与本文用语的映射，独立成表才能被机械核 |
| §14 Task 模板 | 持久记录的最小字段集；空栏必须写「不适用」及理由 |

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

### 1.5 执行者的共同纪律

不论单路还是并行，不论人还是 agent，八条都成立：

1. **不用计划覆盖原始请求**（`I1`）；
2. 只在范围、工具、数据、预算和副作用边界内行动；
3. **区分事实、推断、假设、缺失和未运行验证的结论**——四者不可混写；
4. 对可中断工作持久化 checkpoint；
5. 无法满足完成契约时请求输入或**明确失败**，不交半成品；
6. 在**最终固定版本**上运行与风险相称的验证；
7. 报告盲区、副作用和残余风险；
8. 未经授权不推送、合并、发布、删除远端资产或扩大外部影响。

⚠ 第 3 条是 §5.2 采信规则与 §12 三级证据分档的**前提**：分不清事实与推断，
后面两处的分级就无从谈起。

### 1.6 六条设计原则

全文的取舍都回到这六条。它们不是新主张，是把本仓已成文的判断当成设计约束用到底：

| # | 原则 |
| --- | --- |
| **P0** | **只有一套状态机（Task / Attempt）**，场景差异只体现在 Profile 的 guard、必需产物与 interrupt 策略；**任何场景不得新增状态词** |
| **P1** | **同一事实只有一个权威写入面**；两份同构文档即两个真源（`I13`，§1.2） |
| **P2** | **状态从产物反推，不从声明读取**——人的动作也不例外 |
| **P3** | **方向不对称**：朝严谨可自裁，朝省事须人确认；⚠ **默认值属于省事方向** |
| **P4** | **判据必须声明覆盖范围**；⚠ **覆盖不全比没有更危险**（§5.2） |
| **P5** | ⚠ **凡能落成代码、测试或门禁的纪律必须落成**；文字只描述意图，不构成机制 |

**两条推论：**

⚠ **一个只能靠人转述的环节等于没有环节**（P2 + P5）。这条决定了本文对人介入的全部设计：
§4.2 的每一行都要有 `enforcement_point`，§4.4 要求强制点落在执行者够不着的地方，
理由都在这里。

⚠ **P0 的适用层级是 Task 与 Attempt。**Artifact、Interaction 等对象各有自己的小生命周期
（§3.11 的 `DRAFT → FROZEN → … → PUBLISHED`、内核的 `consumed_at`）——
**那些不是「第二套状态机」，而是对象属性**，并且同样跨场景共用、不得按场景另造。
把对象属性误认成状态机，会导致每个场景各造一套；把状态机误认成对象属性，
会导致状态词失控增长。**两边都错，方向相反。**

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
——最后四项是 §3.6 命名空间纪律在工单上的落点。

`intake_author` 若替请求者起草意图与验收，同票不得再任 proposer、arbiter 或 acceptor；请求者直接给出并
冻结验收时可记 requester。`route_proposal` 保存建议与证据，`route_effective` 保存实际决定，
`route_delta` 保存人改了什么，三者不可合成一段自然语言。

### 2.5 路由只读可判字段

路由成本判断不读题目散文，至少从以下字段提取 `matched_features`：写者数、提案者数、只读输入是否钉版本、
是否依赖/续接、是否触及权威路径、是否有副作用、是否要求审计。风险档位则严格按 round-protocol：
不可逆、权威层、已知对立、判据未定任一命中就是 T2；多文件或多仓且方向无争议为 T1；其余才可能 T0。
风险档位不能反过来充当成本证据，否则是循环论证。

### 2.6 执行层：租用什么、自建什么

constraints A4 是「执行层租用不自建」。它的准确含义不是「什么都用现成的」，而是：
**租 agent loop，自建业务控制面。**loop（模型调用、工具循环、会话推进）用官方 SDK；
Task/Attempt/四本账/验收/授权是本平台的，不 fork runtime、不改 agent loop、
不复制协议类型、不 deep import 内部包、不维护私有 wire fork。

⚠ **先钉现状：生产环境里现在没有任何 agent 在跑。**本节结论一律处于 `defined`，
不是 `wired`，更不是 `runtime-verified`。可复核的休眠登记表在
`investment-backend/app/tests/test_dormant_capabilities.py`——它按
「锚点还在吗 + 还休眠着吗」两个方向立判据，**比 grep 计数稳**：
`:154` `RunBudget` 生产未接线、`:182` Attempt/Invocation 未落库、
`:208` `CancelRunCommand` 无 HTTP 端点、`:240` `AgentProfile` 只被记录不被执行。
开关 `AGENT_V4_TRAFFIC_ENABLED` 与 `AGENT_PILOT_ENABLED` 在 bundle 里都是 `'false'`。
**读本节任何一条都要带着这个前提，不得把目标态写成现状**——这正是 §5.2 推论 2
「拿休眠代码当能力证据」那个错误的机制来源。

**专用 Agent 的构建方法固定，具体 Profile 不冻结**：Profile/patch + 插件组合；
每个工具逐条声明输入/输出 schema 与数据、副作用边界；dry-plan 只产生可审计 Plan
Artifact，query 才执行；结果经显式 `submit_result` 提交，未提交不算 Attempt 完成，
提交只产生候选，validator 过 `F-ACCEPT-*` 后 Task 才可成功；两条 worker 凭据互斥。
**不冻结某个财务 Profile 的字段、工具清单、数据集或金标准**——内核要求首项工作以真实
输入确认契约，而当前业务数据源仍为空；未有真实数据和评测前，任何具体表都是 ⚠ 假设。

**OpenClaw：借机制，不转向。**它的 Gateway 是渠道接入与控制面，两层「路由」都不读用户
语义——channel/account/peer binding 是确定性映射并返回 `matchedBy`；provider/model route
选 runtime 且显式 plugin runtime 默认 fail-closed。可借的机制与本项目落点：确定性 binding +
命中规则 + 拒绝 reason code 存进 RouteDecision；agent/session/runtime/model 四者正交；
capability 支持与显式路线 fail-closed；host 先备好上下文、runtime 只跑 loop；来源路由与
回复交付分离。**不整体转向**：它「一 Gateway 一信任域」、多租户靠每租户一个仍属实验性的
cell，主档是 SQLite 不是共享 PostgreSQL，本身是 TypeScript/Node CLI；引入会重复现有控制面。
**其危险默认更不能继承**：sandbox 默认关闭、`tools.profile: full` 等于无限制、
`/elevated full` 可跳过 exec approval。明确不借：Gateway 当业务主档、channel binding 冒充
语义路由、本地会话存储取代 PostgreSQL、默认 host 执行、那三个逃生门、运行中静默跨 runtime
重放，以及把 Gateway 放进 BFF 与 FastAPI 之间。

### 2.7 两个官方 SDK：两个轴、非对称能力

**专业构建能力与生产控制能力是两个独立轴，不能合成一个「谁更强」。**

事实钉在 Codex `7d6f808b`、DeepSeek Harness `dd6322d6`。
**升级钉版必须重跑锚点，不得沿用本表结论。**

| 轴 / 能力 | Codex Python SDK | DeepSeek Harness Python SDK | 对本平台的结论 |
| --- | --- | --- | --- |
| 专业 Agent 组装 | 进程级配置为主，无 preset 一等概念 | preset 是一目录一 `agent.cordis.yml`，按会话组合 tools/prompt/skills/persona，一进程可跑多种 agent（`packages/preset/README.md:12`） | Harness 适合专用 Agent；**这不表示其生产控制面已合格** |
| 生命周期 | thread start/resume/list/read/fork/archive、turn interrupt（`sdk/python/src/openai_codex/client.py:430-469`、`:641-646`） | wire 只有 initialize、session/prompt、shutdown；事件对 runtime 全量且未过滤 | Port 必须**表达缺失**，锚 `F-EXEC-02/05`、`F-INTERACT-*` |
| 逐 Turn 结果 | run/turn 有 turn id、流与 `output_schema` | `SessionPromptResult.messageId` 只标识**入队的用户消息**，「does not identify a later assistant message, turn ending, or prompt result」（`packages/sdk/protocol/README.md:52`） | Harness 缺完成归属，**不能伪装 `COMPLETED`** |
| 取消 / 关闭 | 有 turn interrupt；thread 可 archive | 「**No cancel or session-close methods** — a client abandons a turn by closing the runtime process」（同上 `:115`） | 只能用进程级补法，**代价写入 Attempt** |
| 交互批准 | 可接 approval handler，**但默认自动接受**：`_default_approval_handler` 对 `commandExecution` 与 `fileChange` 一律返回 `{"decision": "accept"}`（`client.py:773-779`） | 「**Server→client requests are a dead capability** — the transport supports them, but the server never sends one」（同上 `:116`） | **Codex headless 必须覆盖默认 handler；Harness 不得声称原生 HITL** |
| provider 协议 | 已钉死 Responses API，`wire_api="chat"` 明确报错（`codex-rs/model-provider-info/src/lib.rs:57-88`） | 面向 DeepSeek 等自身 adapter 路线 | DeepSeek Chat Completions 经 Codex 需另建翻译代理，**是真实阻抗，不是无成本替代** |
| 系统 Node | 不适用 | wheel 携闭包，SDK 不需系统 Node | ⚠ 内网 PyPI 能否取得 wheel 未验证；**不得复活「缺 Node 阻断」** |

⚠ **这张表是「投喂 vs SDK」问题的证据底座。**它说明两件事：其一，CLI 投喂路径答不了审批
请求不是配置问题——Codex 侧默认就是自动接受，Harness 侧根本收不到请求；其二，
换 SDK 不等于自动获得 HITL，Harness 腿的审批要靠**平台工具网关**，不能靠 runtime 自批。

工具可通过插件注册，参数/输出校验与 policy hook 见
`~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:7-59`；这支持「不 fork agent loop」，
**不证明多租户授权、取消和恢复已接线**。

### 2.8 统一执行 Port 与三态能力探针

application 层只依赖中性 Port；签名里不得出现 ticker、portfolio、财报等领域词（A4/A5）：

```python
class AgentExecutorPort(Protocol):
    async def capabilities(self) -> ExecutorCapabilities: ...
    async def start(self, request: ExecutionRequest) -> ExecutionBinding: ...
    async def resume(self, binding: ExecutionBinding, value: ExecutionInput) -> None: ...
    async def cancel(self, binding: ExecutionBinding, reason: CancelReason) -> CancelReceipt: ...
    async def events(self, binding: ExecutionBinding,
                     cursor: ExecutionCursor | None) -> AsyncIterator[ExecutionEvent]: ...
    async def inspect(self, binding: ExecutionBinding) -> ExecutionSnapshot: ...
    async def close(self, binding: ExecutionBinding) -> None: ...
    async def submit_result(self, binding: ExecutionBinding,
                            payload: ResultEnvelope) -> SubmissionReceipt: ...
```

**`submit_result` 在签名里，不是 Adapter 私货。**结果必须经一个显式提交动作进入平台，
未提交不算 Attempt 完成，提交成功也**只产生候选**——validator 说了才算。放进 Adapter 内部
会让两条腿在「什么算完成」上出现两套语义。⚠ **Harness SDK 当前不存在这个方法**，
它是我们自建的约定，不是租来的能力。

**Port 存在的第一理由是可测性，不是「将来可能换执行器」。**有了它，纪律层可以用
`FakeAgentWorker` 跑完整状态机、超时、取消与恢复路径，不必每次真起 runtime、真发凭据、
真花模型钱。「将来可能换」是**收益**，可测性是**现在就成立**的理由——本仓
`ToolExecutionPort` 生产引用为 0，正说明没有可测载体时 Port 会停在 `defined`。

`ExecutionBinding` 必须可序列化并落 PostgreSQL：**SDK 侧的 thread/session id 不是 Task 的
真源**（`I13`），进程重启后要能只读持久载体接着做。

**能力探针是三态，不是布尔：**

| 状态 | 含义 | 调度规则 |
| --- | --- | --- |
| `available` | 钉版 SDK 与 runtime 已证明原生保真支持 | 仍须过 Attempt 准入 |
| `explicit_unsupported` | SDK 明确不支持且不得降级 | **fail-closed**；换路线必须新建 RouteDecision/Attempt |
| `implicit_fallback` | 有替代语义但会损失能力或改变边界 | 只有冻结政策明确允许且**代价落账**才可用；不得静默 |

⚠ **布尔 `true/false` 会把「明确不支持」和「悄悄降级」压成同一种事实**，
于是 `AT-09`、`AT-14`、`AT-20` 无法证明。探针必须带 runtime/SDK 版本、证据与探测时间；
dispatch 以所需能力集合做**硬过滤**，不能等 Adapter 内部临场降级。

### 2.9 Harness 腿的前置门禁与过渡补法

门禁卡的是「本平台的状态机能否管住 Harness」，**不是「能否用 Harness 建专业 Agent」**。
专业腿进入自动路由前，必须由上游在正式 SDK 同步实现并测试以下公开合同：

- session start/resume/read/close，按 cursor 读取 session events；
- turn start/read/steer/cancel，stable turn id，**逐 Turn completion correlation**；
- per-session preset 选择与逐 Turn 结构化输出合同；
- **模型不可见、不可改的 trusted context**：Task/Attempt、tenant/actor、授权策略版本、
  允许能力、数据集绑定、证据策略、deadline；
- async 且已证明不阻塞的 Python 面、cancel durable end、crash/restart/malformed-wire 测试、
  版本化 capability query。

门禁未过时**只允许显式、受限的过渡路线**，四条，且代价必须落账：

1. 取消时先持久化意图并 revoke Attempt 网关令牌，再按 teardown ladder 杀 runtime 进程；
2. 每个专业 Profile 必须提供显式 `submit_result` 工具；未调用不算 `COMPLETED`，
   调用成功只产生候选，仍由独立 validator 判 `F-ACCEPT-*`；
3. 高风险工具**不交给 runtime 自批**，全部经平台工具网关按审批分层决定；
4. 等待/恢复**创建新 Attempt**，从持久 Artifact 和现场快照恢复，不伪造原 Session 续跑。

代价：进程级取消粒度粗、上下文重建耗时、可能丢失未提交中间推理、重复计算增加预算、
不能原地 resume。相关项探针标 `implicit_fallback`，**不得标 `available`**。
若完成合同需要保真的原 Attempt 恢复或逐 Turn HITL，该路线保持 `explicit_unsupported`。

⚠ **注意这条与 §4.3 的关系**：`dev.change` 走的是 LangGraph checkpointer，**原地 resume 可用**
（§4.3 已实测）。本节说的是 Harness 腿——**两条腿的恢复语义不同，不可互相外推**。

### 2.10 双 runtime 的部署、进程与恢复

先按运行角色分 API、通用执行 worker、专业执行 worker。两类 worker 使用**互斥的服务身份、
队列、网络与凭据**，不能在同一进程里把两套 key 都做成环境变量。

当前部署有四条硬阻断，都是现状不是建议：

| 阻断 | 可复跑锚点 | 必须补的门禁 |
| --- | --- | --- |
| worker 无模型 API egress | `deployment/bundle/30-network-policies.yaml:221-268` 只放 PostgreSQL/Redis/RabbitMQ、Casdoor、Knowledge；`rg -n 'ipBlock' 该文件` 零命中 | 精确目的地/代理 egress，**在 Calico 环境实际验证**，锚 `I3/I12`、`AT-05` |
| root filesystem 只读 | `deployment/bundle/20-runtime.yaml:361-373` | `CODEX_HOME`、`DSH_HOME`、workspace、snapshot staging 分离到有配额的可写卷 |
| worker 内存上限 768Mi | `deployment/bundle/20-runtime.yaml:354-373` | 双 runtime 峰值与 prefork 并发实测后定 requests/limits |
| 模型配置/凭据未进 bundle | `deployment/bundle/00-prerequisites.yaml:106-119`；`rg -n 'AGENT_PILOT_LLM_' bundle` 零命中 | 代理 endpoint、短 TTL token issuer、Secret/ServiceAccount、启动 fail-closed |

⚠ **KIND 默认不执行 NetworkPolicy。**第一条阻断的「包级验证」只在生产 Calico 下成立；
开发用的 KIND 集群里策略写了也不生效，**会让人误以为出口已经封死**。

⚠ **这条进程纪律有死者，不是设计洁癖。**Celery worker 默认 prefork 数继承节点 CPU，
本仓曾因此起了 12 个子进程直接打爆 768Mi；模板已把并发钉成
`CELERY_WORKER_CONCURRENCY: '2'`。**在这个内存上限下再往每个子进程里塞一个 SDK runtime，
是同一个坑的第二次。**

SDK 进程纪律：Celery prefork **之后**按 Attempt 或受控槽创建 SDK client/runtime；
不得在 parent 初始化后跨 fork 共享 fd、锁、event loop 或子进程句柄；owner 记 PID/进程组与
binding。关闭按 `stop intake → revoke token → SDK cancel/close → 限时 TERM 进程组 →
限时 KILL → reap → 核对副作用账`，每步写证据。
⚠ Codex async 客户端内部把同步调用包到 worker thread（`async_client.py:161-183,293-295`），
**并发与 teardown 必须做负载/故障注入，不能由 `async` 关键字推断安全**。

可恢复执行现场按 `attempt_id + runtime_version + profile_version + digest` 内容寻址写对象
存储；PostgreSQL 只存引用与摘要。restore 在新可写面校验摘要、授权、fencing、
runtime/Profile 兼容性后继续，**不把 executor 本地目录当真源**。

**恢复必须有界**：Profile 固定 `max_attempts`；同一
`failure_fingerprint + profile_version + runtime_version` 连续失败达阈值就**熔断该版本路线**，
停止自动恢复并转 Interaction。Profile 升级**不得替历史 Task 静默解锁**。

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
worktree、共享发布面，以及非协调者不得写的单写者文件（如 `handoff.md`）。
**这三个字段不是描述性说明，是 §3.10 写入前门禁的判定输入——派工时缺任一字段，
执行者不得开始写。**

派工**只能收窄**父 Task。父预算覆盖所有 Work Unit、Attempt、工具、评审和改进。
多个 Work Unit **不得同时权威写同一可变事实**；先划分所有权，无法划分则串行。

**人在这套模型里有三个角色，不可互相替代：**

1. **请求提出者**——提出有边界的工作，给原始意图、范围和验收期望；
2. **执行者**——亲自实施部分工作，与助手交替推进；
3. **principal**——批准、取消、追加成本和终审验收的最终权力。**第三种助手不能替代。**

⚠ 助手不得自我批准；**人也不得把终审责任外包给助手后不再复核**（§4.5 责任归属表）。

⚠ **候选隔离目前靠纪律，不靠机制。**候选冻结前只读同一任务包、基线和各自获准上下文，
不得读其他候选、**发起方偏好**或预设解法；看到已有答案之后产出的内容属于评审或改进，
**不再是独立候选**。但——

> **脚本化产生候选目前没有可用工具**（曾有的 `parallel-proposals.py` 已于 2026-09-06 删除：
> 三轮一次没用过、真实模型调用从未验证、只覆盖 codex 系执行者）。在此之前，
> **隔离靠纪律，而且无法事后证明某一轮真的独立。不得据此声称隔离由机制保证。**

### 2.12 五家 Agent Profile 的实测取值

⚠ **本表是「登记表长什么样」的实例，不是可自动路由的名单**（§2.3 已立：静态登记集合与
自动路由候选集分开）。带 ⚠ 的格是**未核值**，不得据它反推能力。

```toml
[ap.luna]
harness = "codex-cli"    provider = "openai"     model = "gpt-5.6"   model_pinned = false  # ⚠ argv 未钉 --model
dispatch = "argv"        observability = "process"     # 可升 tool.reported：codex exec --json
enforcement = "outer-only"   sandbox = "self"    workspace_isolation = "convention"
roles_allowed = ["proposer","reviewer","objector","acceptor"]   supports = ["dev.change/1"]

[ap.kimi]
harness = "codex-cli"    provider = "moonshot"   model = "kimi-k3"   model_pinned = false  # ⚠ 同上
dispatch = "argv"        observability = "process"   enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"

[ap.cursor]
harness = "cursor-agent" provider = "xai"        model = "cursor-grok-4.6-high"   model_pinned = true
dispatch = "argv"        observability = "process"   enforcement = "outer-only"   sandbox = "self"

[ap.fable]
harness = "cursor-app"   provider = "anthropic"  model = "claude-fable-5.1"  model_pinned = false  # ⚠ GUI 内选择，不可机械核验
dispatch = "manual"      # 无 argv；分发由人代行，记 dispatch_event 而非权力表行
observability = "fs-only"    enforcement = "outer-only"   sandbox = "self"
roles_allowed = ["proposer","reviewer","objector"]      # 不得任 acceptor

[ap.qwen]
harness = "qoder"        provider = ""           model = ""   model_pinned = false  # ⚠ 留空：来源表该栏为「—」，推断不得进登记表取值
dispatch = "argv"        observability = "process"   enforcement = "outer-only"   sandbox = "self"

[ap.opus]                # 裁决方，不参赛
harness = "claude-code"  provider = "anthropic"  dispatch = "argv"   observability = "process"
enforcement = "outer-only"   sandbox = "self"    roles_allowed = ["arbiter","publisher"]

[principal.owner]        # 人：不是执行者，无 harness / dispatch / observability
channel = "inbox+commit"          channel_grade = "shared-credential"   # 与 agent 同机同身份，证据强度零
```

**读数三条：**

1. 四家 `process`（可升 `tool.reported`），**fable 为 `fs-only`**——`dispatch = manual`，
   没有进程句柄就没有 stdio；
2. **六家 `enforcement` 全为 `outer-only`，`sandbox` 全为 `self`，`workspace_isolation` 全为
   `convention`**；
3. ⚠ **目前没有一家是 `tool.enforced`**——那是 SDK 腿建成之后才会出现的取值（§2.9）。

⚠ **登记表的机械非空不等于填对。**真实案例：一份候选把 fable 填成 `process`，
而同一份的正文又写「看不到 argv / stdio」——**机械判「无空缺」会通过，事实是填错的**。
校验规则：`dispatch = manual` 的执行者，`observability` **只能**是 `fs-only`，脚本不许填高。

⚠ `[principal.owner]` 的 `channel_grade = shared-credential` 是 §4.4 那句
「人类确认只能标 `reported`」在登记表上的落点——**通道换掉之前，
轨迹里所有 `power_row ≠ —` 的条目 `response_grade` 一律 `reported`**。

**`codex exec --json` 的可升级依据**（本文复跑于 Codex `7d6f808b`）：
`codex-rs/exec/src/cli.rs:58-64` 的 `--json` 参数注释为 “Print events to stdout as JSONL”；
`codex-rs/exec/src/exec_events.rs:115` `CommandExecution(CommandExecutionItem)`、
`:118` `FileChange(FileChangeItem)`（结构体在 `:161` 与 `:186`）。
⚠ **可见性到工具调用级，但吐的是执行者自报**——运行时既拦不住（拦截点在进程内）也验不了，
**强制点仍在进程外**。所以它只能升到 `tool.reported`，升不到 `tool.enforced`（§5.1）。

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
⚠ **父仓推送不带子仓提交**：跨机同步脚本推的是父仓，拉取侧自动 `submodule sync/update` 对齐 gitlink，
**子仓的提交仍须自己推**（constraints T4）。只交父仓 gitlink 而子仓对象不可达，等于没交。

独占在 CLI/GUI 腿通常只是约定，因为同 OS 用户可能看见整个文件系统；只有 runtime 提供的 namespace、
文件挂载、凭据裁剪和出网网关才能构成事中限制。`workspace_isolation` 必须登记为 `enforced` 或
`convention`，不能把目录不同写成安全隔离。

⚠ **后果是一条硬约束，不是一句提醒**：`convention` 腿的授权范围声明（`I3`）只能依赖
「事后审计可发现越权读取」，不能依赖「事中读不到」。因此——
**涉及第二租户或真实财务数据之前，CLI 腿的数据源必须经运行时的数据网关，
不得给裸库凭据。**

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

三档共享同一工单 schema、状态机和发布门，只改变 guard、必需 Artifact 和 Attempt 组：

| tier | 执行形态 | 独立信号 | 人工门 |
| --- | --- | --- | --- |
| T0 | 做 → 独立验收 → 确认 | 一个产出、一个独立验收 | 开工可由已批准窄包自动决定；不可逆发布仍由人确认 |
| T1 | 单稿 → 独立评审 → 验收 → 确认 | 一稿、一评、一验 | 工单冻结与开工可合成一次明确确认 |
| T2 | round-protocol 七环节 | N 份隔离候选、互评、裁决、异议、独立验收 | 题目/判据冻结与参与方/路线确认分开 |

完整产物命名、候选冻结、处置表和验收方算法只引用 round-protocol。状态脚本从 commit 反推，工作区
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

### 3.5 交付、清理和恢复

validator 先跑机械条，acceptor 再判机器判不了的冻结条；验收失败在预算允许时产生新 Attempt，
不得改窄标准换取通过。不可逆动作由 principal 确认后，publisher 才写共享最终路径或生产面。
结果、验收、预算结算和终态事件必须原子提交或用不暴露半成品的等价协议；Delivery 只在之后通知，
断线可按 cursor 回放并按 Task 重新取得结果（产品 `F-ACCEPT-01`–`03`、`F-DELIVERY-01`–`10`，
`request-lifecycle.md @ ed0b5136:398-440`）。

开发分支清理只删本轮私有产物；主线原有文件不能在候选分支里为“整洁”而删。需要删除旧权威稿时，
先完成逐节迁移、引用清零、门禁、T0/T1 实跑与人工确认；Git 历史可恢复不等于新读者能找到。

### 3.6 私有地产生，单写者发布

**会话隔离、模型隔离和任务名称不同，都不等于文件系统隔离。**
任何可能并行的执行者都不得把共享路径当自己的草稿纸。

```text
private draft → owner candidate → frozen commit / immutable Artifact
              → 选优 → integrator workspace → final commit → 共享分支 / release / Delivery
```

共享发布面包括 `master/main`、公共工作树、约定的最终文件路径、共享对象存储键、正式 PR、
release、部署环境和用户可见结果。⚠ **用户要求的最终文件名是发布目标，不是所有候选都可
同时写的路径。**多个候选各自在独立 worktree 里改同一相对路径是安全的；共用一个物理工作树
就必须用 owner namespace，**不能靠「最后再改名」避免覆盖**。

推荐的逻辑命名（实际路径可调，隔离维度不能丢）：

```text
branch:    task/<task-id>/<owner-id>/<work-unit-id>
worktree:  <sandbox>/worktrees/<owner-id>/<work-unit-id>/
artifact:  <artifact-store>/<task-id>/<work-unit-id>/<attempt-id>/<name>
evidence:  <artifact-store>/<task-id>/<attempt-id>/evidence/<name>
integrate: task/<task-id>/integrate/<run-id>
```

若工具限制导致只能共享一个工作树，草稿必须写进明确的 owner namespace（如
`.work/<task-id>/<owner-id>/...`），共享最终路径保持只读。**共享工作树是降级方案，
不能声称具备 worktree 级隔离。**连 owner namespace 都保证不了，任务必须串行。

**本仓当前落点：**

| | 路径 | 权限 |
| --- | --- | --- |
| 人的主 checkout | `~/master/<仓>` | **只读**。可读、可对照，**不是投稿箱**，也不因为「原件在这里」就该写这里 |
| 执行者工作区 | `~/worktrees/<助手>/<仓>` | 该助手唯一可写面；提交到自己的命名分支 |
| 整合面 | 整合方 worktree 上的 `integrate/<run-id>` | 只有 integrator 写；**源是选定 commit，不是任何人的工作区文件** |

「一仓一个默认工作区」不够多执行者用。同一 Task 出现第二名可写执行者时，
必须先建好各自的 worktree 和命名分支再派活，**不往默认工作区加写者**。

### 3.7 并发场景处置表

每行四件事：场景、正确落点、禁止做法、**已发生时怎么收**。
恢复列给的是入口动作，统一规程见 §3.8。

| 场景 | 必须怎样做 | 禁止 | 已发生时 |
| --- | --- | --- | --- |
| 多执行者生成同名文档 | 各自在自己 branch/worktree 改同一相对路径，分别 commit | 一起写共享目录同一个 `.md` | **以 commit 认主，不以磁盘最后一版为准**；共享路径上的未提交文件视为污染，移进各自 namespace 后比 digest，声明哪些候选已不独立 |
| 只能共享物理目录 | 用 `owner_id/work_unit_id` namespace，最终路径只读 | 用时间先后或「谁最后保存」定结果 | 停写；分流进各自 namespace；由 integrator 裁决 |
| 单执行者单路任务 | 仍固定 owner、baseline 和 candidate commit | 在脏的共享 master 上直接写未跟踪结果 | 把脏工作区里属本任务的内容迁到自己分支并 commit |
| 人与 agent 混合 | 各有独占 worktree，统一登记 | 默认人的目录可被 agent 写 | 助手改动撤出人的工作区；**人的未提交改动优先保留** |
| 两个单元改同一文件 | 目标不同则各分支独立改由 integrator 解冲突；共同写同一事实则重划所有权或串行 | 同时共享写、事后凭 mtime 猜作者 | 停写；双写内容各自成 commit，交 integrator 判重复/互补/无关 |
| 多仓 / 子模块 | 每仓独立 owner branch/commit；子仓对象先可达再更新父仓 gitlink | 只交父仓 gitlink | 补齐每仓映射；**子仓对象不可达的 gitlink 不进整合** |
| 同一 Task 多 Attempt 重试 | 每次新 attempt/worktree/branch；旧结果标失败或 superseded | 在旧 Attempt 目录原地续写 | **旧目录冻结为失败现场**，新 Attempt 从固定 commit 重开 |
| 候选修订 | 新 commit + `supersedes` | 冻结后改 branch 再沿用旧评审 | 新哈希标为冻结后修订并记 `supersedes`，不进本轮比较 |
| 内容相同的重复候选 | 按 digest 去重，可共享内容对象，**保留各自 provenance** | 删一方记录后声称只有一个来源 | 合并内容对象，两份 provenance 都留 |
| 合并冲突 | integrator 在独占整合 worktree 解析，记冲突双方与裁决依据 | 让候选作者互相覆盖，或按时间自动取新 | 同左；**不按时间自动取新** |
| 一方删除、一方修改同一文件 | 作为语义冲突交 integrator 依 Task 裁决并补回归 | 机械采用 delete/modify 任一侧 | 升给 integrator，不机械取任一侧 |
| 用户工作树已有脏改动 | 视为用户所有；另建 worktree/分支或避开，先记 baseline | **stash、reset、checkout 或覆盖用户文件来「清理」** | 不 stash、不 reset、不 checkout；先记 baseline 再绕开 |
| 执行中发现共享路径又被改 | 立即停写并进 §3.8 | 继续保存，期待自己的内容最后覆盖回去 | 停写转 §3.8；从最新可确认版本建新整合 Attempt |
| formatter/codegen 同时跑 | 只在 owner worktree 执行，生成物归该 owner commit，固定工具版本 | 对共享目录启用后台自动写入 | 关掉共享目录自动写入；受影响文件从 owner commit 重生成 |
| 无 Git 的简单任务 | 每个 Attempt 用独立 Artifact key，以 digest/version 冻结 | 多 Attempt 写同一临时文件或对象键 | 迁到 Artifact + digest；同键多次写入按 provenance 拆开 |
| CI / 并行测试 | 每 job 独立输出目录与 Artifact 名，聚合器只读 | 并行 job 写同一 coverage/报告/缓存真源 | 单槽输出作废，重跑到绑 commit 的独立位置；**不采信被覆盖过的报告** |
| 跨 Task 共享缓存 | 按输入摘要寻址、内容不可变、命中可校验、失败可丢弃重建 | 把可变缓存当结果真源 | 疑似互相覆盖的条目**一律丢弃重建，不尝试修复** |
| 大文件 / 二进制 | 内容寻址存储，Git 记摘要、schema、来源和位置 | 多人向同一路径覆盖上传 | 以 digest 认主；取有 provenance 的那份，其余降为未验证参考 |
| 敏感产出 | 加密/受控存储，最短保留期，日志脱敏 | commit、PR、Artifact 或聊天中保存凭据 | **按泄露处理**：轮换凭据、清理副本与日志、记暴露窗口；**不能靠删文件了事** |
| symlink / 路径别名 | 写前解析规范路径并确认仍在获准 writable root 内 | 利用软链、`..` 或挂载别名写出 owner 空间 | 核对实际写出的规范路径；越界按覆盖事故处理 |
| 外部发布 / 数据库写入 | 唯一 side-effect owner + 幂等键 + fencing + 回执 | 因代码分支隔离就允许多候选同时写生产 | 查副作用账按幂等键判是否重复；需要时补偿，**不靠重跑覆盖** |
| 多执行者推远端 | 各推自己的远端 ref；integrator 独占发布 ref | 共推同名远端分支，non-fast-forward 后 force-push | ⚠ **不要强推回滚**。报告有权主体，由其决定 revert 或冻结该 ref |
| PR 评审后新增 commit | 原评审绑定旧 commit；新 HEAD 重触发受影响门禁与评审 | 沿用旧批准声明新 commit 已通过 | 原批准作废，新 HEAD 重跑 |
| 候选迟到 | 标 `STALE` 只读保留；需要时新开改进单元 | 写入 final path、覆盖已选 commit、再执行副作用 | 同左；**源仍是 commit** |
| 失败 / 取消 | 冻结失败现场和已产出对象，盘点副作用，再按策略回收 | 先删 worktree 导致无法复盘 | 先冻结再回收；已删的现场按证据缺口登记，**不补造** |
| 执行者崩溃 | 新执行者从 manifest/checkpoint 和固定 commit 恢复到新 worktree | 盲接旧进程的半写目录 | 不接管半写目录，重建 |
| 已交卷 commit 需修改 | 新 commit；旧哈希仍报给评审并记 `supersedes` | `commit --amend` 改写已被他人读过或已交卷的提交 | 原 commit 仍可达则继续作评审对象；新哈希标冻结后修订，**不静默替换** |
| 两执行者提交到同一分支 | 不应发生——派工时 `exclusive_branch` 互斥 | 共用 `tmp`/`new` 这类分支名却不拆所有者 | 停写；按作者拆成两条分支，原分支冻结 |
| 从共享目录拷走他人未提交稿 | 不拷。交卷只经收集到的 commit | 把别人的草稿当自己的起点 | **该路不再计作独立候选**；记录污染来源与时间窗口 |
| 整合时误拷工作区文件进共享主仓 | integrator 从**选定 commit** 取内容 | 把任何人的未提交文件复制进共享主仓 | 从主仓撤出，改从 commit cherry-pick/merge；撤出前先确认没覆盖他人内容 |
| 只读探索 | 不写；或只写一次性抛弃分支且不推送 | 探索性改动混进实施分支或共享主仓 | 探索提交不进选优，除非任务包事先允许 |
| 跨机 / 新会话接手 | 只凭分支 + commit 恢复；cwd 必须是自己的 worktree | 凭「上次写在共享目录里」接着写 | 先看 `worktree list` 与 `status`；共享工作区里的未跟踪文件先按覆盖事故处理 |
| master/main 发布 | 仅 integrator 在最终验收并获授权后更新 | 每个候选直接向 master/main 写 | 未经整合的写入撤出发布面，从选定 commit 重走整合与 final gate，**不在发布面上就地修补** |

### 3.8 覆盖或来源不明时的事故规程

⚠ **后到者赢在任何场景都不成立。**磁盘上的最后一版、时间戳最新的一份、最后推上去的那个
ref，都不因为「在后面」而获得正确性或所有权。**覆盖发生后唯一有效的认主依据是 commit、
digest 和 provenance。**

这是唯一一套事故规程，两档入口。

**四步前门**（单文件被覆盖、来源基本可判、无外部副作用、无发布竞争）：

1. **保全现场**：停止对该路径一切写入，先记录，不删除、不 reset、不 checkout；
2. **恢复归属**：从 Git 对象、reflog、Artifact 或备份取回各版本，各自恢复为归属者的独立
   分支或 owner namespace，交还归属者；
3. **判定关系**：由**非当事方**判定两份是重复、互补还是无关，据此取一、合并或都保留；
4. **留痕**：把覆盖窗口、受影响对象和恢复依据记入证据账。

任一条不成立——来源不明、涉及发布面或远端、已产生外部副作用、同一路径反复被改——
**立即升级为八步，不要在四步里硬撑**。

**八步完整规程**（内容、大小、hash、mtime、HEAD 或作者特征与预期不符时）：
① 停写（含自动格式化/生成任务）② 保全（记路径、stat、hash、`git status`、HEAD、进程）
③ 分流（各版本存进各自 namespace 或不可变 Artifact）④ 溯源（依 commit、checkpoint、
manifest、工具事件和内容特征判断；**mtime 只作线索**）⑤ 恢复（优先从 owner commit、
Git object、Artifact、备份）⑥ 裁决（由 integrator 决定选用/合并/全拒，
**不由最后写入者自动获胜**）⑦ 回归（在新 final commit 重跑门禁）⑧ 记录（覆盖窗口、
受影响对象、恢复依据、防复发控制）。

⚠ 来源无法确认时，**文件不得进入 final**；能恢复内容但不能恢复 provenance 时，
只能作为未验证参考。事故处理中**不得为了「恢复干净」破坏用户或其他执行者的未提交内容**。

### 3.9 冻结、迟到与取消

候选、评审、改进、最终结果和验收绑定不可变 commit。冻结后替换必须产生新 commit 并登记。
主线采纳后的在途结果标为 `STALE`，不得覆盖主线、执行副作用或推翻已交付结果。

**迟到判定分两层，机制不同，不要混用：**

| 层 | 判定依据 | 机制在哪 |
| --- | --- | --- |
| **产品侧**（Attempt 写回、副作用、终态提交） | Task/Attempt 状态、租约与 fencing token | 内核的目标合同。本文只引用，不重新定义 |
| **开发侧**（候选、评审、改进、整合） | 冻结 commit、候选状态、冻结时间戳 | 本文。⚠ **开发侧没有租约机制**：整合方吸收前必须显式核对四项——候选状态仍有效（非 `STALE`/`SUPERSEDED`/`REJECTED`）、commit 仍可达、提出方未撤回、基线未失效 |

⚠ **核对的对象是 commit 与候选状态，不是分支。**分支是可移动的运输通道，
「commit 还在某分支上」既**不必要**（可达即可核对）也**不充分**（分支可被重置或强推）。
把开发侧迟到写成租约，会让人误以为有一个运行时会自动拒绝迟到写入——没有。

取消：先持久化意图，再停止调度、撤销租约、终止执行、盘点副作用、固定需保留的 commit 和
Artifact，最后回收 worktree/sandbox。**取消与完成只能一个终态胜出。**
产品面的过期写入应由 fencing 拒绝；**开发面（分支、worktree、发布路径）没有等价运行时机制**，
只能靠条件式发布和整合方核对挡住，因此**开发侧的取消必须显式停止执行者，不能只靠标状态**。

### 3.10 物化门禁与写入前门禁

**两道门，时机不同：物化门禁在第一个 Attempt 启动前，写入前门禁在每次落笔前。**

**物化门禁（首个 Attempt 启动前必须证明）：**

1. Task 契约已可靠持久化；
2. workspace **唯一归属本 Task**，路径、配额和回收策略明确；
3. source ref、Artifact 摘要、commit 和 gitlink 可取得；
4. 初始 `git status` 符合 Profile，预置脏文件均有解释；
5. 指令范围可由目录层级确定；
6. 凭据、越权数据和无关材料未进入版本库；
7. **manifest 与实际文件一致**；
8. 工具、权限和预算不超过 Task 授权；
9. owner、独占可写根、候选产出位置和唯一 integrator 已明确；
10. **共享发布面为只读**，除非当前 Attempt 正是获准的整合 Attempt。

⚠ 失败时**不得把半成品工作区交给执行者「尽量执行」**。重试复用 Task 身份但**建立新
Attempt**，并隔离或安全清理残留 workspace。

**manifest 证明实际给了什么**（Task 决定该给什么，manifest 证明给了什么）：

```text
task_id, workspace_id, created_at        run_id, owner_id, work_unit_id, attempt_id
source repository + commit / gitlink     artifact source + digest + destination + access mode
generated task package + profile version effective instruction files and scope
excluded material + reason               secret references (never values)
initial commit                           writable roots + output namespace
publication target + integrator
```

⚠ **材料在工作区内可见，不自动构成使用授权。**有效权限仍由 Task、Profile、工具策略和
当前批准共同决定（§4.5 的交集公式）。**上一 Task 的工作区不得在未重新受理、授权和物化的
情况下复用给下一 Task。**

**写入前门禁（一票否决）。**动手写任何文件之前逐条核对，任一不成立则**停，不写任何文件**：

1. `cwd == workspace_path`；
2. 当前分支 `== exclusive_branch`；
3. 目标路径不在禁写集内，且**解析软链、`..` 和挂载别名后的规范路径**仍落在获准的
   writable root 内；
4. 目标路径上**没有他人产物**；若有，不覆盖——先让对方的内容形成可达 commit 或备份；
5. 本次**不是宽泛写入**（批量生成、`>` 重定向、脚本 sweep、先 `rm -rf` 后重建）；
   确需宽泛写入时收窄到明确路径逐个执行。

⚠ **这五条不是建议。宽泛写入和「路径归属不明仍继续写」是覆盖事故的两个主因**，
两者都发生在**写入前**，而事后恢复（§3.8）代价远高于停一次。

**冷启动核对（每次 Attempt 开始时）：**Task/Attempt ID、租约、fencing、预算与停止条件；
原始请求、范围、验收、批准点与预期 Artifact；当前目录、仓库根、分支、HEAD、子模块与
工作树状态；manifest 的输入、摘要、基线与实际文件；生效的 `AGENTS.md` 与目标代码附近测试；
依赖、权限与外部系统是否仍有效；**哪些判断是事实、推断、假设、缺失或尚未验证**。
不匹配会改变结果时**停止并发起 Interaction**——不得在错误仓库、错误分支、过期 commit
或失效租约上继续。

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

### 3.12 完成判据

⚠ **十三条同时满足才叫闭环**，缺一条都不能笼统说「完成」：

1. 受理幂等，原始请求与规范化 Task 可追溯；
2. 载体路由（是否建 Git 工作区）有依据；复杂 Task 的工作区、Git 与 manifest 可复现；
3. 范围、验收、权限、预算、批准点和基线已冻结；
4. 执行者接单核对了工作区、指令、租约和输入（§3.10）；
5. 按风险执行，角色冲突已处理（§2.2）；
6. 每个产出有 owner、namespace、状态、provenance 和**唯一** publication target/integrator；
7. 候选**没有**直接写共享路径或 `master/main`，发布只从独占整合面发生；
8. publication target 通过**预期 HEAD/version 的原子条件更新**，发布竞争没有变成静默覆盖；
9. 并行结果绑定 commit，迟到、失败和取消已处置（§3.9）；
10. final commit 上全部门禁和验收**逐条**通过；
11. 结果、证据、副作用、盲区和风险已持久化；
12. 提交唯一终态，请求方可重取结果；
13. Git 对象和 Artifact 可达、血缘可追溯且无活跃引用后，工作区才清理。

⚠ **缺项时只能称「已受理」「已物化」「候选完成」「本轮选定」「待验收」「交付待重试」
或「清理待处理」——不能笼统宣称完成。**这条对应 §11 的「『已派工』或『全部返回』当作完成」。

### 3.13 执行形态、停止规则与成本

档位（§3.4）定 guard，**执行形态**定这一次实际怎么排人：

| 形态 | 适用条件 |
| --- | --- |
| 单路实施 | 解法明确、局部、可被测试充分判定 |
| 定向审核 | 已有唯一产物，只需独立判断 |
| 最小选优 | 需要独立候选，但无需完整评审团 |
| 完整选优 | 解法不明确、跨层/跨仓、错误代价高 |
| **胜者改进** | 主线已选，只吸收独立局部优点 |

⚠ **选形态的人不能顺手改上层决定**：不得改动已落账的 RouteDecision、降低硬门禁、
换执行器、扩大权限或增加总预算（§4.9）。

**停止规则（六条）：**

- 使用**足以产生独立信号的最少候选**；
- 顶层验收满足后，其余在途单元停止、取消或降为**无副作用只读参考**；
- 连续一轮没有关闭阻断问题或新增可验证价值时**停止**；
- 达到轮次上限仍有结构分歧时，**请 principal 裁决或重开 Task**；
- 单元耗尽预算**不得静默借用**；
- 协调者退出前留下可恢复 checkpoint。

⚠ **「已派工」「全部返回」「多数一致」都不等于完成**（§3.12、§11）。

**成本纪律：**

- 资源上限、超时、外部副作用和人工批准点**必须在启动前写入任务包**；
- **完整交叉阅读是二次复杂度**——候选较多时采用平衡分配，但**每个候选获得相同评审覆盖**；
- 无法运行命令的评审保留价值，但**必须标注「未经事实验证」**，且不能替代验收方的运行结果；
- 自动化必须保证**单路失败、超时或缺席也进入记录**，不能由成功路线覆盖。

### 3.14 建立 worktree 的细则

- 每个并行单元**独立分支、独立可写 worktree**；候选从同一冻结 commit 开始；
- ⚠ **同一分支不能被两棵 worktree 同时检出**——Git 会拒绝第二处，这是机制不是约定；
- ⚠ **worktree 只隔离写入，不阻止读取共享 Git 对象**，隔离强度要在登记表里说明（§3.2）；
- 多仓单元固定每仓 commit 和父仓 gitlink；
- ⚠ **租约、凭据和产品状态不得提交进分支**；
- 建立、归属、基线和清理状态进入 manifest（§3.10）；
- ⚠ **删除 worktree 不等于删除证据**——commit 必须仍然可达；
- `master/main` 与其他共享分支**默认不是候选写入面**；
- 即使多个候选修改同一相对文件，也各自在自己的分支/worktree 里改；
- **只有 integrator** 在独占整合 worktree 中写最终路径并形成 final commit。

### 3.15 发布协议：三个路径不是一个

用户要 `path/to/result.md` 时，必须区分三个东西：

```text
candidate path:   每个 owner worktree 内的 path/to/result.md
publication path: integrator worktree 内的 path/to/result.md
published ref:    final commit / PR / release
```

候选作者只提交自己的相对路径，**不直接把文件复制到共享 master**。选定或逐项整合后，
由**唯一 integrator** 从冻结 commit 取内容，在独占整合 worktree 写 publication path，
跑 final gate，再形成 final commit。是否推主线仍受 §4.2 H5 约束。

⚠ **发布动作必须带预期版本**：Git 更新校验目标 ref 仍指向 integrator 开始时记录的 commit；
文件或对象存储用版本号、ETag、generation 或等价 compare-and-swap。目标已变化时
**发布失败并创建新的整合 Attempt**：读新基线、重解冲突、重跑受影响门禁，再尝试。
**不得以 force-push、无条件覆盖上传或先删后写绕过竞争。**发布重试用稳定幂等键；
「内容相同」也要保留本次发布回执和 provenance。

⚠ **若请求方明确只要多个可比较草案**，publication target 就是**候选集合及其 manifest**，
不是某个候选抢占正式路径。只有在作出选择之后，才产生单一 final 文件。

### 3.16 保留与垃圾回收

| 状态 | 默认保留 |
| --- | --- |
| `SELECTED`/`INTEGRATED`/`PUBLISHED` | final commit、来源映射、验收、证据、必要 Artifact |
| `REJECTED` | 候选 commit/digest、拒绝理由和必要证据；可按期限清理工作目录 |
| `STALE`/`SUPERSEDED` | 血缘和摘要；是否留全文按审计/复用价值决定 |
| `FAILED` | 最小复盘证据、副作用状态和可恢复 checkpoint |
| `CANCELLED` | 取消依据、已产生副作用、需补偿项和保留对象 |
| 敏感临时物 | 达到最短业务/审计要求后**尽快安全销毁** |

⚠ **垃圾回收是显式阶段，不是执行者退出的副作用。**删除前必须逐项验证：
发布结果可重取；所需 commit 可达；Artifact 摘要可校验；副作用已收敛；
没有活跃 Attempt 引用；保留期限已满足。清理记录至少含操作者、时间、对象、依据和失败项。

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

脚本「从产物反推、判据即命令、只生成不执行」这三条是对的，要补的是**判错时必须停**：

| 要求 | 违反会怎样 |
| --- | --- |
| 输出 **Task 状态（内核状态词）+ 当前环节 + 各 Attempt 状态**；⚠ **环节是投影，状态是判据** | 只输出「当前环节」，就把投影当成了真源 |
| 工单里若有 `status` 声明字段，**降为人读缓存并由脚本校验**：⚠ **推导值 ≠ 声明值即报错退出** | 声明与产物漂移，而没有人会发现 |
| 每次状态推导**同时输出「上一状态 → 本状态」**；⚠ **边不在内核合法转换表内即报错退出** | 只校验状态点会漏掉非法边——这是真实抓到过的漏检形态（§5.3 规则 6） |
| 分发前对照 `roles_allowed` 与角色分离禁令，**冲突即拒绝并给 reason** | 角色冲突要到验收时才暴露，那时已经晚了 |
| ⚠ **每条判定声明覆盖范围**（P4）：输出里「查了什么、没查什么」与结论并列；**零命中要能区分「真的没有」与「没查到」** | 门禁在边界上给假答案，而它看起来是绿的 |
| 按工单 `tier` 读取对应 guard 表与必需产物表，**不写死某一档** | 轻档位没有可执行形态，等于不存在（§0.0 第 6 条） |

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

**H7 是表内唯一不要求仓外锚的行**，这是有意的：取消属**失败安全方向**——
伪造一条「取消」只会让流程停下来等人，不会让任何东西被发布出去。
其余各行朝的是「放行」，伪造即造成不可逆后果，所以强制点必须在 agent 够不着的地方。
⚠ 代价在**恢复**而不在取消本身：不知道已经产生了哪些副作用就不知道要回滚什么，
所以取消必须附**已产生副作用清单**，缺清单的取消不生效。

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

**中断恢复在本项目已经端到端跑通**，不只是「库有原语」：

| 层 | 状态 | 取证 |
| --- | --- | --- |
| 抽象基类 `GraphRuntimeService.resume` | `raise NotImplementedError(...)` | `graph_runtime_service.py:26-31`——这是**抽象方法的正确写法**，不是功能缺失 |
| 适配器 `LangGraphRuntimeService.resume` | **已实现**：`Command(resume=…)` + 同 `thread_id` | `langgraph_runtime.py:13-21` |
| 端到端 | **通过**：中断 → `resume` → 原地续跑并产生副作用 | `test_graph_runtime_service.py:18-35`，`uv run pytest` → **2 passed** |

⚠ **这一段曾经写反过，教训比结论有用。**先前据抽象基类那行 `NotImplementedError`
断定「端到端未接线」——**错在只读了基类 18 行就停**，没搜谁继承、没搜谁调用、没跑测试。
把「留给实现方的空位」（**接口契约**）读成了「功能缺失」。

> **「打开文件自验」也会失败**：验了，但**验的范围是自己划的**，而范围划错了。
> 这与「没验就下结论」是两种错，**后者好防，前者难防**。

因此实现应把产品 Interaction 的 `question_or_action / audience / expires_at / resume_token_hash /
idempotency_key / consumed_at / resume_target` 绑定到这些原语，字段真源仍是
`request-lifecycle.md @ ed0b5136:247-277`。中断节点返回业务需要的 dict；恢复端鉴别主体、校验
Task 与状态版本、原子消费令牌，然后把经验证的响应作为 `Command(resume=value)` 送回同一 thread。
checkpoint 原地续跑时是同一 Attempt 的 `WAITING → RUNNING`，不因“人给了内容”另开 Attempt。

**`dev.change` 的 H8 具体这样接**（五步，缺一步就会长回自造协议）：

1. 需要人时，adapter 调库的 `interrupt(payload)`；**payload 的形状由 Task Profile 的入向约定声明**，
   不写进内核绑定字段——形状归 Profile，字段归内核，这样扩展不必动内核；
2. 人的答复经 **principal channel** 到达后，adapter 调 `Command(resume=答复)`，
   **同一 `thread_id` 原地续跑**；
3. **这不是新 Attempt，也不建新 Task。**内核 Attempt 状态机走 `WAITING → RUNNING`；
4. **只有**当答复实质改变了目标、口径、授权范围或 Profile 版本，才按内核建带 `supersedes`
   的新 Task——**四个条件之外的答复一律回原 Task**；
5. 过期、异键、跨 Task 的恢复**由库与内核既有校验拒绝**，不在 Profile 层再造一套。

⚠ **「需要载荷」这个需求，是被「恢复必须开新 Attempt」自己造出来的。**
库的恢复不换 Attempt，载荷就是 `resume` 的那个值。取消掉那个不该有的执行边界，
围绕它长出来的一整支设计（载荷、schema、过期校验、Task 级暂停）就一并消失。

若未来业务确需结构化编辑，先拿一个真实 Task Profile 的前端 payload、拒收用例和迁移数据立规范修订；
不要从自由 `resume` 值反推一套平台级 patch/replace 协议。修改目标、授权范围或 Profile 版本仍按产品
“终态、刷新与重新处理”建立新 Task；普通澄清只恢复原 Task。

### 4.4 身份、批准与强制点

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
绕过这些组件，就先画出真实动作路径并在路径上设门，不增加旁路存储来制造安全感。当前手工轮次的
人类确认仍是治理记录，证据等级应诚实标为 `reported`，不得声称身份已 `attested`。

### 4.5 权限公式与只有 principal 能做的动作

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
也不得通过询问自己派出的 subagent 或取得多数同意来制造批准——**自我批准禁令在任何轮次
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

### 4.7 四档审批

审批策略固定四档，具体动作由 Task/Profile 风险分类映射：

| 档 | 适用 | 决策者 | 纪律 |
| --- | --- | --- | --- |
| `auto-deny` | 未声明、越权、不可满足门禁 | 确定性 policy | 直接拒绝并留 reason code |
| `auto-allow` | 冻结政策明确的低风险、可逆、范围内动作 | 确定性 policy | 仍逐次验权、记预算/副作用 |
| `llm-review` | 只需语义检查且政策明确允许委托的中风险动作 | 独立受限 reviewer | **必须落账**模型/版本/输入摘要/判定/理由；否则等于产出者自我批准 |
| `human-approval` | 高风险、不可逆、发布、扩权、追加预算 | principal 经 Interaction | 一次性、短时、精确绑定，**不可转授** |

每份批准绑定 `task/attempt/action/target/policy_version` 与待执行 canonical payload、
计划/diff/Artifact 的内容哈希；**执行前重算，任一字节、目标、权限或版本漂移即作废**。
批准有短 TTL，超时 fail-closed。

⚠ **不得把 Codex 默认 accept 当任何一档批准**（`client.py:773-779`，见 §2.7），
**也不得让生成候选的同一 Agent 充当 `llm-review`**。

⚠ **超时是独立的审计结果与 reason code，不折成 `auto-deny`。**两者行为后果相同
（都不放行、都 fail-closed），**审计含义不同**：`auto-deny` 是策略作出了拒绝判断，
超时是**没有任何人作出判断**。压成同一个 reason code 会污染审计账——
事后无法区分「策略拒绝率上升」和「审批链路卡死」。落账写 `approval_timeout`，
带等待时长与待审对象哈希。

⚠ **四档与 §4.2 权力表是两条正交的轴，不是一张表的两种写法。**权力表回答
「**哪个 principal** 可以走**哪条合法边**」；四档回答「**一次具体动作**经过**什么样的审批
形态**」。`llm-review` 在权力表里没有行，因为它不是 principal 的权力——
⚠ 它是否可用于任何 `auto_policy = 无` 的行，**本文不裁**，登记 §7.4 未决。

### 4.8 principal 的裁量权与改判纪律

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

### 4.9 Attempt 内的三条硬禁令

上层路由完、权限收窄之后，Attempt 内还需要**可执行的边界**——抽象声明容易被绕过。
任一条被突破即为越权，按 `I3`、`I10`、`I15` 与 constraints A2/A4 处理：

| # | 禁令 | 具体形态 |
| --- | --- | --- |
| 1 | **不得改路由** | 执行器种类在 Attempt 创建时钉死并落账；不得因为「这个单元更像财务」而在 Attempt 内改投另一条腿 |
| 2 | **不得换执行器** | 不得在 Attempt 内自行构造新的 runtime 客户端实例绕开已固定的 Adapter；换腿只能由上层**新建 Attempt** |
| 3 | **不得扩权** | 不得重新注册已被 deny 的工具，**不得把 `human-approval` 降级为执行器默认的自动批准**，不得追加预算 |

⚠ **第 3 条的现实动因见 §2.7**：Codex Python SDK 的默认审批处理器对命令执行与文件改动
一律返回 `accept`，而**该兜底发生在构造函数里**——

> **「忘了传 handler」与「故意选自动批准」在代码里长得一样。**

所以这条**必须由 Adapter 强制显式传入 handler，不能靠纪律**。这是「机制优于自律」
在本文里最具体的一处落点。

### 4.10 人这一侧的义务

⚠ **不只是执行者有纪律。人这边同样有，而且被违反时后果更大——因为 agent 会照做。**

| 人的义务 | 违反会怎样 |
| --- | --- |
| 请求写清**边界**：含什么、不含什么、不含的归谁 | 执行者会自行扩大范围，或漏掉本该做的 |
| 给**可判定的验收标准**，不给倾向性结论 | 候选向你的结论收敛，**等于白问** |
| 并行提案时**不泄露其他方案** | 独立信号退化成改写（§2.11） |
| 派活前先建好各自的 worktree 和命名分支 | 多个执行者写同一工作区，后写覆盖先写（§3.6） |
| 收到「我不确定」时**不追问到它给出确定答案** | **逼出的确定性是编的** |
| 执行者说「没查过某处」时**当作真话对待** | 声明盲区的动力被消灭，下次它不说了 |

⚠ **最后一条最容易被忽略：盲区声明是自愿的，只要说了就受罚，很快就没人说了。**
这与 §9.2「如实写『不能排除』不扣分，隐瞒才扣」是同一条规则的两侧——
一侧约束写的人，一侧约束读的人。

**委派转移的是执行，不是最终责任。**派活时必须给出范围、权限、预算、停止条件和可验收
输出；对超范围、追加成本、不可逆动作和规范修改及时批准或拒绝；**亲自验收，或指定未参与
实施的验收方**（§4.5 责任归属表）。

### 4.11 本轮已发生介入的实例级清单

⚠ **类型级权力表（§4.2）不能代替实例级清单。**这一条是上一轮 ⑤ 验收 `C-1` 明确抓出来的
缺项——**没有实例，就无法验证权力表是否真的被用过、被正确地用过**。

下表是 `runtime` 轮实际发生的介入，逐条对应唯一状态机的边与权力表的行：

| # | 介入（可复核出处） | 状态机的边 | 权力行 |
| --- | --- | --- | --- |
| 1 | 所有者提出四条推翻性判断 | **不是任何边**：前一 Task 已 `SUCCEEDED`，终态不可转出 → 建新 Task 并记 `supersedes` | —（内核规则，非权力） |
| 2 | 解冻上一轮三处冻结物 | `WAITING(APPROVAL) → VALIDATING` | **H6** |
| 3 | 冻结本轮验收十条并签发 | `WAITING(APPROVAL) → VALIDATING → QUEUED` | **H1** ⚠ 与 H2 合并于一次触点，与「T2 = 2 个触点」不符，登记为观察值 |
| 4 | 裁定本轮协议版本 | `WAITING(INPUT) → VALIDATING` | **H8**（approve option） |
| 5 | 接受零强度回执形态，继续 bootstrap 例外 | 同上 | **H3**（更省事方向） |
| 6 | 固定投喂指令加指路补丁 | 同上 | **H8** |
| 7 | 判别命令硬化、删除产品映射句 | **不占权力行**：中性偏严谨，裁决方自裁 | —（记裁定行） |
| 8 | 裁定某条从属于另一条并签发 | `WAITING(APPROVAL) → QUEUED` | **H6** |
| 9 | ①②④⑤ 对四家 CLI 的手工投喂 | 各家 Attempt `CREATED → RUNNING`；Task `QUEUED → RUNNING` | —（`dispatch_event{mode=manual}` ×N） |
| 10 | 对 `dispatch = manual` 执行者的手工投喂 | 同上 | —（`dispatch_event`，`observability = fs-only`） |
| 11 | 所有者执行发布脚本把环节产物写入主线（本轮 5 次） | Side Effect：写共享路径 | ⚠ **未经 H5 门**——见下 |
| 12 | ⑥ 确认 | `WAITING(APPROVAL) → QUEUED` → publisher `RUNNING → COMPLETED` → Task `RUNNING → SUCCEEDED` | **H5** |

⚠ **第 1 行「没有边」是正确答案，不是缺项**——它恰好说明「推翻一个已完成的 Task」
在内核里的落点是 `supersedes` 建新 Task，**不是 Interaction**。

⚠ **第 11 行是一个真缺口，如实登记。**五次执行发布脚本、把环节产物写入主线，
都是**写共享路径的 Side Effect**，按权力表属 H5 管辖，但实际未经 H5 门——
它们被当作常规动作处理了。**原因是 H5 只对准「⑦ 发布最终稿」，没有区分最终稿发布与
轮内产物发布**。两者不可逆性不同（后者可 revert，前者进交付面），但**都写主线**。
处置见 §7.4 第 4 行（`H5-final` / `H5-round` 拆分），**本文不擅自改权力表行数**。

## 5. 可观测性、证据与等效

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
但**必须可数**，因为成本上界（§6.2）和绕过口径（§6.3）都要数它。

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
provenance, evidence_ref`；⚠ **Artifact 的作者要拆成 `author_claimed` 与 `author_attested`
两个字段**——合成一个就没法表达「声称是谁写的」与「能证明是谁写的」之间的差距，
而目前这两者几乎从不相等（§2.12 `channel_grade`）。**比较上下文**（源稿称 `TraceEnvelope`——本文不沿用该名，
因为它只是这一组字段的包装，另起一个名字会让读者以为多了一个对象）另含
Task Profile 版本、验收摘要、策略版本、principal 身份域、
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
| L1 | 独立 acceptor（⚠ **既得利益最小的一家，由处置表算出**，不由谁指定） | 冻结标准中机器判不了的内容；标准过期须交回裁决。⚠ **作者自检不能代替独立验收**；没有第二个执行者时由独立验收器或人验收，验收方**只能按冻结标准判定，不能为通过而静默改标准** |
| L2 | 被处置主张的原作者 | 是否被误读；异议必须带处置条目与可复跑证据 |
| L3 | principal | 意图是否正确、不可逆项、抽样复算证据真实性。⚠ **不逐行读——抽样规则写进工单**，否则「抽检」会退化成「翻一翻」 |

顺序不可倒：L0 未过不进 L1，L1/L2 未过不请求最终批准。新增机器判据首跑必须与人工结论对照；
锚点存在但不支持断言，比没有锚点更危险。

### 5.6 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵

状态按 §2.8 的三态探针标注。⚠ **探针词与「已支持 / 需补法 / 当前缺失」的对应固定如下，
读表一律按右列判定，不得只看探针词：**

| 探针状态 | 三档判定 | 含义 |
| --- | --- | --- |
| `available` | **已支持** | SDK 原语直接满足该条义务；平台仍需归一并记账 |
| `implicit_fallback` | **需补法** | SDK 有近似原语但不满足义务，平台/Adapter 必须补齐 |
| `explicit_unsupported` | **当前缺失** | 协议显式否定该能力，须走上游门禁或过渡补法 |

⚠ **不得把 SDK 原语冒充产品能力**：把 `implicit_fallback` 读成「已支持」是一次真实的措辞坑。
矩阵只投影内核的稳定 ID，不重新定义其义务；证据锚点一律注明出自哪个仓——
⚠ **不得拿本仓自己的代码当租用 SDK 的能力证据**（真实案例：某候选以本仓休眠的
`AgentProfile.permits_tool` 佐证 Harness 腿工具门）。

| 功能 ID | Codex 腿 | Harness 腿 | 需补法与验收 |
| --- | --- | --- | --- |
| `F-EXEC-01` | `available`：sandbox/approval/tool 面可配置；**但 headless 默认 approval handler 会自动 accept** | `implicit_fallback`：**进程内**工具门是真的（`adding-a-tool.md:59` 的单调 deny，preset 按会话组合 tools/prompt/skills）；但 wire 无可信逐 Task context，也无 per-session preset 选择 | Attempt 准入取 Task/Profile/当前批准的交集；**Codex 必须覆盖默认 handler**；Harness 工具网关逐次验权。`AT-05` |
| `F-EXEC-02` | `available`：thread/turn/event 可关联，仍需归一并写平台账 | `implicit_fallback`：`sessionId` 可作 Attempt 级关联的**输入**，但只是来源标签，不自动完成唯一 binding、全 runtime 事件过滤、子 session 递归归属与证据持久化 | 平台强制 binding、过滤、递归登记、补齐版本并持久化。⚠ **逐 Turn completion correlation 另属上游门禁**（`SessionPromptResult.messageId` 不标识 turn 结束或结果，`protocol/README.md:52`）；需要逐 Turn 保真的路线**在 dispatch 前 fail-closed** |
| `F-EXEC-03` | `available`：approval callback 可逐动作接平台复核，**默认实现不可用** | `explicit_unsupported`：**server→client request 不发生**（`protocol/README.md:116`） | 高风险动作**只经工具网关**；审批绑定动作/产物哈希并落账。`AT-05/07/12` |

⚠ **这张矩阵是 §2.7 那张表在内核功能 ID 上的投影。**两张表口径必须一致：
`F-EXEC-03` 的 Harness 腿判 `explicit_unsupported`，依据就是 §2.7「交互批准」那一行。
**升级钉版时两张表必须同时重跑。**

### 5.7 证据账按流程分级

⚠ **不能只有「全套」与「零记录」两档。**

| 流程 | 最小留证 |
| --- | --- |
| 单路实施 | 请求记录或 PR 中固定最终 commit、验收方、门禁命令及原始输出位置 |
| 定向审核 | 任务包链接、评审、处置、最终 commit 与验证结果 |
| 最小选优 | 任务包链接、参与者清单、候选 commit 映射、决策、处置与验证结果 |
| 完整选优 | 下列完整记录 |

```text
request          # 原始意图、边界、基线、门禁、资源上限
manifest         # 角色、参与者、耗时、状态、异常
candidates       # 匿名编号、commit、覆盖和验证声明
reviews          # 独立审、对照审、逐条主张裁决
decision         # 门禁、偏好评分、决胜与选定 commit
improvements     # 主张 ID、来源、commit、测试与冲突
dispositions     # 接受/部分接受/拒绝及证据
verification     # 最终 commit 上的回归结果
```

载体可以分散，但必须由**一个稳定的主记录**串起全部链接，并**能由第三方读取**。
⚠ **任何流程都不得只在聊天中宣称测试通过；另一个人不能恢复和复核的内容视为未持久化。**
候选 commit 必须来自该候选自己的分支——共享工作区里的未提交文件、从别人路径拷来的稿，
**不得写入候选清单**。

### 5.8 上下文路由与能力四级词典

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
这是 §12「拿休眠代码当能力证据」那条失败的词汇层防线；配套的可运行验证动作是
**回跑 dormant 测试**并同时确认「锚点仍在」与「能力仍未接线」两个方向（§2.6）。

### 5.9 七种载体各能证明什么

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

### 5.10 事实裁决表与整合纪律

**评审分两阶段**：先只读原始请求、匿名 commit 和统一标准**独立审**；冻结后再读候选自评、
盲区和验证记录**对照审**。评审必须写明 commit、覆盖范围、阻断问题、证据，
以及**哪些结论真的运行过**。

**先裁决事实，再谈偏好**：

| 主张 ID | 候选 commit | 证据/命令 | 结论 | 理由 |
| --- | --- | --- | --- | --- |
| `<ID>` | `<commit>` | `<位置/输出>` | **证实 / 证伪 / 未决** | `<说明>` |

⚠ 测试失败、违反硬约束或范围、存在阻断风险、commit/证据不可取得、隔离不可恢复的候选，
**不进入偏好评分**。**全体一致不是免检理由**（§12）。只有合格候选之间才比较维护成本、
结构和命名；维度与权重**在候选产出前冻结**，结果称「**本轮选定**」，
**不称「已证明正确」**。

**整合纪律**：选定 commit 冻结为**只读基线**。局部改进从它建新 worktree，
⚠ **一条独立主张一个提交**；整体重写或耦合改动作为**新候选重开**。
整合方逐项记录接受、部分接受或拒绝**及证据**；冲突按原始请求、约束和证据解决，
**不按票数、作者或提交时间覆盖**。

⚠ **所有有效门禁必须在 final commit 重跑——候选的绿色结果不能证明整合结果正确。**

### 5.11 轨迹实测：23 条里 2 条 attested

§5.3 引用过这个读数，**这里是支撑它的表**——⚠ **只留读数不留表，就是「结论在、证据不在」**。

数据来源可复跑（⚠ **必须钉 commit**：不钉 ref 时会在包含后续发布点的分支上多出一行）：

```bash
git log <round-commit> --format='%h %ad %an' --date=iso -- <最终稿路径> <该轮目录>
git ls-tree -r --name-only <round-commit> -- <该轮目录>
```

| seq | 层 | 边 | actor | 权力行 | provenance |
| --- | --- | --- | --- | --- | --- |
| 1 | task | — → `RECEIVED` | owner | — | reported（无工单文件） |
| 2 | task | `RECEIVED → VALIDATING → QUEUED` | orchestrator | **H1/H2 缺** | **inferred**（无工单、无冻结验收条） |
| 3 | task | `QUEUED → RUNNING` | 执行者 | —（`dispatch_event`） | reported |
| 4 | attempt | A1 `CREATED → RUNNING → COMPLETED` | 执行者 | — | reported（产出 v0，**无 commit**） |
| 5,8,13,16,19,21 | artifact | v0→v1→…→v6 | claimed / **attested none** | — | reported（六个版本**零 commit**） |
| 6,7 | attempt | A2/A3 reviewer `COMPLETED` | — | — | reported（**产物未归档**） |
| 9,14,17 | attempt | A4–A6、A7–A11 `COMPLETED` | — | — | **inferred**（由文件存在性推出） |
| 10,11,15,18 | interaction | request → approve / **reject** | owner | **H8** | reported（同 commit、同身份） |
| 12 | task | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | orchestrator | H8 | **inferred**（账本无边） |
| 20 | attempt | A12 `COMPLETED` | — | — | reported（**无产物**） |
| 22 | interaction | R1 冻结 → approve | owner | **H1** | **attested**（存在）/ reported（身份） |
| 23 | task | `RUNNING → WAITING(APPROVAL) → QUEUED → RUNNING → SUCCEEDED` | publisher | H1+H5 | **attested**（终态）/ inferred（中间边） |

**读数**：23 条里 `attested` **2** 条（且身份都不 attested），`reported` 15 条，`inferred` 6 条；
Artifact 六个版本**零 commit**；两个 reviewer Attempt **有事件无产物**；
H1 与 H5 由同一 commit 承担，**账本分不开**；`VALIDATING` 阶段**没有任何契约产物**。

这条轨迹与「按 `dev.change/1` 跑一遍 T2」的目标轨迹**在边上对得上**，
但**只能在 `reported` 等级上宣称等效**（§5.3 规则 4）。
这就是「手工模式看起来在跑、实际没有可搬运的形状」的账本版。

**对照组**：另一轮的整合分支有 **28 条**逐主张提交，③④⑤ 每条处置各占一个 commit——
同一 Task Profile、同一 orchestrator 实现，`attested` 条目**数量级不同**。
⚠ **差别不在载体，在纪律是否落成动作。**

**样例的引用纪律（两条，对应两种真实失败形态，防法不同、不可互相替代）：**

1. ⚠ **每个引用对象须先核验其属于所声明的那一轮。**引用真实存在、哈希可验、
   但**属于另一轮**的对象，叫**张冠李戴**——只查「对象是否存在」抓不到，
   必须查「**属于哪一轮**」；
2. ⚠ **无 ⚠ 声明的样例条目一律按「已核验」读，因此凭空构造即为假证据。**
   另一种失败是**把本轮形状倒灌进历史**——写出账本上根本不存在的对象
   （如「五份并行候选」「验收产物」）而不作任何声明。前一条防法查不到它：
   **对象压根不存在，「属于哪一轮」无从查起**，只能靠「**无声明即假**」。

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

⚠ **这一段也曾写偏过。**「**git 载体**验不了这三样」这句本身成立，
但整份文档只写了这一句，**读起来像「本项目至今没验过」**。
教训：**「某载体证不了 X」与「X 未被证明」是两件事，不许合写。**

### 7.3 删除与迁移门

源稿或现行生命周期文档删除前必须同时满足：

1. 新文档通过 `doc-gate.py --all` 与 anchor gate；
2. 全仓旧文件名引用零命中，历史归档除外并有说明；
3. **四份**源稿全部 `##`/`###` 标题在 §10 恰有一个落点或充分的故意不要理由；
4. **每个落点已验到正文级**——不是「本稿有那么一节」，而是「该节确实承载了源节的内容」，
   且抽查记录可复核；
5. 原未验证清单在新真源逐条可寻且仍标 ⚠；
6. 一条真实 T0 与一条真实 T1 已按新路径留痕；
7. 删除作为不可逆动作经人确认。

⚠ **第 4 条是 2026-09-07 补的，补的是一个真实漏洞。**原第 3 条只要求「恰有一个落点」，
而**一张只验到标题级的表就能满足它**——于是六条可以全绿，同时 §9.4 自报的
「未逐行比对正文」那笔欠账被一起删掉，**再没有人能发现**。

⚠ **这正是 `refact-fable.md` §5.2 当年的形状**：它承诺「按旧文全部标题、脚本检查零缺口」的
映射表，把判据写进了**计划**，没写进**验收条件**，结果 `migration-map.md` 从未产出而
流程照走。**承诺产出但不进验收，等于没承诺。**

**由此得出 `archive/` 的存续条件**：只要 §10 还有任何一行的落点没验到正文级，
`archive/` 下对应的源稿**就不能删**——它是那一行**唯一可抽查的对象**。
§10 的开头写着「核它的办法是抽查落点、以正文为准」；把被抽查的对象删掉，
这张表就从「可证伪」变成「不可证伪」，而不可证伪的覆盖声明比没有更差。
⚠ **git 历史里有，不算数**：§3.5 已立「Git 历史可恢复不等于新读者能找到」。

### 7.4 风险和未决

**逐条登记，每条带处置。**只写「有风险」而不写「现在怎么办、什么条件下才动」的清单，
下一轮没人知道该不该碰它。

| # | 事项 | 状态与处置 |
| --- | --- | --- |
| 1 | Agent Profile 的实际模型、GUI 内部事件与部分 CLI 工具事件不可机械核验 | ⚠ 未验证；登记表相应字段标 ⚠，**不得用未核值反推能力** |
| 2 | 无进程入口的分发者永久需要人工桥 | 登记为**可计数的欠账**（`dispatch_event{mode=manual}`），**不伪装成自动化** |
| 3 | principal 确认与 agent 共享宿主身份 | 证据只能标 `reported`；身份边界未落地前不得写成 `attested` |
| 4 | **H5-final / H5-round 拆分**：轮内产物写主线的管辖 | 未决；已由前轮登记，**本文不擅自改权力表行数** |
| 5 | **H5 的机制化强制点** | 两个有效方向均需所有者动作；现状登记为「人的显式动作」 |
| 6 | **响应者身份鉴别**（Interaction 服务化的前置） | 未决；**信任域收紧前不拆** |
| 7 | typed review／ruling／acceptance 是否只是 Artifact 类型细化 | 未决；若属对内核 Attempt 定义的扩充，按内核修订纪律另起工作单元 |
| 8 | **结构化修订（部分否定／替代）的规范形状** | 未决；**必须用库原语构造**，不得反推平台级 patch 协议 |
| 9 | `retroactive` 登记与内核 `I1`「原始输入不被后续解释覆盖」的关系 | 未验证；建单时一并核 |
| 10 | 独立性按 `harness` 或 `(harness, model)` 分组 | ⚠ 无跨题数据；**只能作观察值**，由「候选相似度」校验后再定 |
| 11 | **T0 的「可逆出口」**（只落 worktree、免 H5） | 未决；属**省事方向**的新权力表行，须有签名次数数据后再议 |
| 12 | **「命中任一条即 T2」中「权威层」覆盖面过宽** | 判据属流程规范，改它由该规范自己的轮次处理 |
| 13 | **触点疲劳导致盖章化** | 观察值：回执耗时、相对预填的改动项数、每类触点次数；**不设自动动作** |
| 14 | **单 principal 阶段的权力表在多用户场景是否够用** | 表结构已按 principal 设计；capability 列等出现第二个 principal 再加 |
| 15 | **三值路由初期大量 `ask`** | 预期行为；每次 `ask` 的人工选择按「裁量是规则的孵化器」反哺规则表 |
| 16 | 内核演化冲击本文 | 三条：按 commit 引用内核、内核改动按最重档、改后重跑状态词比对 |
| 17 | **`QUEUED` / `RUNNING` 在事件落地前不可判** | 已声明；脚本合并显示并标 ⚠ |
| 18 | **H1 与 H5 落在同一 commit 时账本上的歧义** | 未决（服务态应是两个 Interaction；手工态今天做不到） |
| 19 | 运行时外的绕过天然不完备 | principal 侧指标在共享身份下是 `UNKNOWN`，**不得写成零** |
| 20b | **`llm-review` 能否用于任何 `auto_policy = 无` 的权力表行** | 未决。§4.7 立了四档审批，但 `llm-review` 不是 principal 的权力，在 §4.2 权力表里没有行。⚠ **本文不裁**——它要么是 H 行的一个前置过滤器，要么根本不该出现在需人批准的路径上，两种读法后果不同 |
| 20 | 预算账、证据账与 Agent Profile 生效仍是后续工作 | 见 `handoff.md @ ed0b5136:14-19`、`handoff.md @ ed0b5136:30-66` |

### 7.5 跨会话续接

⚠ **判据只有一句：把今天的记忆抹掉，另一个人只读持久载体能否接着做？不能，就是没落盘。**

- 当前推进哪件事、卡在哪、下一动作，落在 [`handoff.md`](handoff.md)，不落在脑子里；
- **「不能倒退的输入」必须写下来**——已经定过的事下次不重新讨论，这是 `handoff.md`
  最有价值的一节；
- 停下来之前，先让 `handoff.md` 能回答：「接手的人一分钟内要知道什么？」

⚠ **交接投影不是第二真源**，不得在 handoff 里复制整张覆盖矩阵。
checkpoint 是恢复输入，不是第二份代码真源，**也不保存凭据**。

⚠ **`handoff.md` 是单写者面。**多名执行者并行时只有协调者写它，各执行者的进度写在
**自己的 worktree** 里，由协调者投影上去。判据不是「内容重不重要」，而是
「同一事实只能有一个权威写入者」（`I13`，§1.2）——**多人各自往同一份 handoff 追加，
就是在共享路径上并发写**。

同一判据对 agent 与人都成立，只是理由不同：**agent 是记不住，人是记得但传不出去。**

### 7.6 执行器架构的未验证清单

⚠ **§2.6–§2.10 描述的执行层，在本清单清空之前一律按 `defined` 对待**（§5.8 四级词典）。
本节只登记「未验证」；「已知不支持」在 §5.6 矩阵里，两者不可混。

| # | 未验证的事 | 位置 | 验证方式 |
| --- | --- | --- | --- |
| 1 | 两条执行腿的部署门禁与 Harness wire 门禁**均无运行证据** | §2.6、§2.9 | Gate 0 spike |
| 2 | 「租用 loop、自建控制面」的硬条件全部未实证 | §2.6 | Gate 0 spike，逐条给退出判定 |
| 3 | Harness sdk-runtime wheel 能否从**内网 PyPI 镜像**取得 | §2.7 系统 Node 行 | 供应链验证，非文档问题 |
| 4 | worker egress 的包级验证**在 KIND 上不成立** | §2.10 | 另起 Calico 环境实测 |
| 5 | 双 runtime 峰值内存与 prefork 并发的**实测值** | §2.10 | 负载测试后再定 requests/limits |
| 6 | Codex async 客户端在并发/teardown 下的行为 | §2.10 | 负载与故障注入，**不得由 `async` 关键字推断** |
| 7 | **未跑过任何 SDK 端到端**、未联调 OpenClaw、未做故障注入 | §2.6–§2.10 全部 | Gate 0 |
| 8 | 多租户配额的产品语义尚未设计 | 本条即登记 | 属产品契约侧 |

⚠ **本清单不是免责声明。**它的用途是：读到 §2.6–§2.10 任何一节时，能立刻判断那一节是
`defined` 还是 `runtime-verified`。**清单为空之前，那五节描述的是目标形状，不是现状。**

## 8. 本轮核查裁定

**这一节是隔离区，不是设计菜单。**它存在的唯一理由是**防止再犯**——
一个被推翻的设计如果只是悄悄消失，下一个人会照着同样的推理再走一遍。
所以两条形状规矩：

- **被证伪的专名只在本节出现**（`amend_schema`、回执仓、候选仓、三道边界一类）。
  正文其他地方出现它们，机械门会判为复活；
- 本节每条必须**「独立观察」与「结论与落点」相邻**——
  只写结论不写观察，读者无从复核；只写观察不写落点，读者不知道它改变了什么。

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

⚠ **这一节还要能装下「不确定」**，不是只装「查了」与「没查」两档。
凡出现「**我不能排除**某事发生过」的情形，就如实写进来，
**不要因为它难看就压成「没查」**——两者的含义不同：

| 写法 | 含义 |
| --- | --- |
| 查了 | 有观测，有结论 |
| 没查 | 没有观测，**明知自己不知道** |
| **不能排除** | **有观测但不足以定论**，或存在自己控制不到的路径 |

**「没查」还要按类别分列，不能混成一段。**三类的性质完全不同，混写会让读者
以为环境事实与外部授权是同一种不确定：

| 类别 | 例 | 性质 |
| --- | --- | --- |
| **宿主恒等** | `hostname; id; cat /proc/self/uid_map` | **可当场复跑**；没查是因为没跑，跑了就有结论 |
| **远端与授权** | `git ls-remote --heads/--tags`；分支保护、部署 key、账户公钥 | 部分可读、**写授权不可只读验证**（`ls-remote` 是读取，不是 push dry-run） |
| **执行者内部** | GUI 里选的模型、沙箱内的工具调用 | **结构上够不着**，换个接入方式才可能有结论 |

第三类是唯一「不改变接入方式就永远查不了」的。**把它和前两类并排写成「没查」，
会让人以为再跑几条命令就能补上**——不能。

**如实写「不能排除」不扣分，隐瞒才扣。**本项目已有实例：某轮一份产物在覆盖声明里
主动披露「某个规划子代理可能经宽泛搜索见过被禁读的文件，无访问记录」——
它没有把不确定性压成「未读」，因而该条被裁决记为**范本**，而非违规。


- 没有登录 GitHub/Gitee 管理面，未核 deploy key、branch protection、账户公钥或 remote 的实际写授权；
  `ls-remote` 是读取，不是 push dry-run。
- ~~没有读取外部 `codex`、DeepSeek Harness、OpenClaw 仓的具体实现行号；本稿不据它们宣称工具级能力。~~
  ⚠ **该条已于 2026-09-07 被 §9.4 的吸收轮取代**：§2.6–§2.10 与 §5.6 现在**确实**据这三个仓的
  实现行号宣称工具级能力。**本节其余各条仍是 `runtime-refact` 轮成文时的声明，不改写**——
  改写他人的覆盖声明等于伪造取证记录。本次新增的覆盖与盲区一律另列于 §9.4。
- 没有复跑产品数据库迁移、API、SSE、预算账或证据账测试；相关现状只按允许输入引用并标为现状。
- 没有穷读三轮每份候选和评审全文；读取了归档索引、处置/验收结论与本题相关证据。因此本文不重做
  旧轮排序，也不声称旧轮所有来源主张均已重新验证。
- 没有验证 GUI 内模型、内部工具调用或沙箱之外的文件读取；这些保持 ⚠ / `UNKNOWN`。
- 依仓库 `AGENTS.md` 强制入口，在读本轮任务书前读了未列入只读输入的
  `working/development-lifecycle-agent.md`。这是本轮输入边界偏差；本文不把它作为断言锚点，也未据其
  结构起稿。除该项外遵守了任务书的禁止读取和提案隔离。
  ⚠ **2026-09-07 后记**：这条自报是对的，而**真正的错在任务书**——它把该文与
  `development-lifecycle-human.md`、`agent-dev-refact.md` 共 197 节划到只读输入之外，
  于是整合者守规就必然丢内容。§9.4 的吸收轮补的正是这一笔。

### 9.3 自增内容及理由（`runtime-refact` 轮）

本稿新增三点：第一，把 K1/K2 直接收敛为“产品 Interaction → LangGraph 原语”的最小绑定，理由是已有代码
足以表达中断恢复；第二，把安全设计改成“逐动作画真实路径再设服务端强制点”，理由是 K3–K6 证明旁路
不经过待保护动作；第三，把原 R0–R5 改成 G0–G5 的证据依赖顺序，先做原语 spike 与身份强制，再做服务态
等效。三点都有 §4.3、§4.4、§8.1 的代码或命令证据，不以通用最佳实践作为依据。

### 9.4 两份 lifecycle 的吸收轮（2026-09-07）

**作者与时间与 §9.1–§9.3 不同，故单列，不混入上面的声明。**
执行者 opus；所有者指令：「你逐节对照，把两份 lifecycle 吸收进 `agent-dev-guide.md`」。

**查了：**

- 逐节读取 `archive/development-lifecycle-agent.md`（73 个 `##`/`###`）与
  `archive/development-lifecycle-human.md`（45 个），§10 新增 118 行；
- **复跑了吸收进来的外部仓锚点**，三个仓都在源稿钉的提交上（Codex `7d6f808b`、
  Harness `dd6322d6`、OpenClaw `173f41d6`）。逐字复核过的关键两条：
  `codex/sdk/python/src/openai_codex/client.py:773-779` 的 `_default_approval_handler`
  对 `commandExecution` 与 `fileChange` **一律返回 `{"decision": "accept"}`**；
  `deepseek-harness/packages/sdk/protocol/README.md:116`「**Server→client requests are a
  dead capability** — the transport supports them, but the server never sends one」，
  同文件 `:115` 无 cancel/session-close、`:52` `messageId` 不标识 turn 结束；
- 用 `difflib` 实测两份 lifecycle 的重复率（≥8 行的节，重合度 ≥0.55 者 222/563 = 39%），
  重复节在 §10 注明同源与重合度。

**没查（本次新增的盲区）：**

| 类别 | 内容 | 性质 |
| --- | --- | --- |
| 外部仓 | §2.7 表里**其余各行**的锚点（preset README、adding-a-tool、model-provider-info、async_client、openclaw 各文档）**只核了行号可达，未逐字复核内容** | 可当场复跑，只是没跑完 |
| 部署 | §2.10 四条硬阻断的 bundle 行号**未复跑**，转录自源稿 | 可复跑 |
| 休眠登记 | §2.6 的 `test_dormant_capabilities.py` 四个行锚**未复跑** | 可复跑 |
| ~~判定口径~~ | ~~只比对标题与存在性，未逐行比对正文~~ | **已于同日补做，见下** |

**正文级抽查（2026-09-07，同日补做）**

⚠ **上面那条盲区不是假设——抽出来 13 处真缺，其中 1 处是落点判错。**

抽查范围：118 行按风险分流为「本次新写 32 行」「判落在既有章节 79 行」「故意不要 7 行」，
**对 79 行中内容最实的约 20 行逐节读源稿正文并回读本文对应节**。

| # | 源节 | 原判 | 实际 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | agent §4.4 物化门禁 | §3.2 复用前置判据 | §3.2 只有 3 条复用判据，**十条门禁全缺** | 补 §3.10 |
| 2 | agent §5.1 冷启动核对 | §1.3、§3.2 | 两处均无；**「写入前门禁五条（一票否决）」整段缺失** | 补 §3.10 |
| 3 | agent §4.3 塞入材料 | §3.2 | manifest 字段表与「材料可见 ≠ 使用授权」缺 | 补 §3.10 |
| 4 | agent §5.2 上下文路由 | §2.5 | §2.5 是**路由成本字段**，与「改哪一面要读什么」不是同一件事 | 补 §5.8 |
| 5 | agent §5.3 共同纪律 | §3.5、§11 | §11 只有反面形式，**无正面纪律** | 补 §1.5 |
| 6 | agent §6.9 三条硬禁令 | §4.5、§2.2 | 缺；含「忘了传 handler 与故意自动批准在代码里长得一样」 | 补 §4.9 |
| 7 | agent §7.4 候选状态机 | §3.3 末段 | 末段只有一句「Artifact 有版本属性」，**八态状态机全缺** | 补 §3.11 |
| 8 | agent §12 完成判据 | §5.5、§3.5 | 十三条与「缺项只能称…」全缺 | 补 §3.12 |
| 9 | agent §2.3 Task 契约 | §2.4 | §2.4 字段表**缺一半**；「硬门禁/质量偏好/待定项必须分开」缺 | 补入 §2.4 |
| 10 | agent §3.1/§3.2 简单与复杂 | §3.4 T0/T2 行 | ⚠ **落点判错**：简单/复杂是**载体轴**，T0/T2 是**风险轴**，两轴正交 | 改落 §3.4 载体轴段 |
| 11 | agent §0.1 | §0.1 | 跨机同步与「子仓要自己推」缺 | 补入 §3.2 |
| 12 | agent §0.2 | §1.2、§5.2 | `request-baseline`「只解释来源，不覆盖现行合同」缺 | 补入 §0.1 |
| 13 | agent §5.4 单路实施 | §3.4 T1 | 「作者自检不能代替独立验收」缺 | 补入 §5.5 L1 |

⚠ **第 10 条最值得记**：把载体轴写成风险轴，与 §2.5 自己警告的「风险档位不能反过来充当
成本证据」是同一种循环——**我在做落点时犯了本文正文明写禁止的那个错**。

修补后本文由 1659 增至 1858 行，新增 §1.5、§3.10–§3.12、§4.9、§5.8，20 行落点更正。

**第二轮（同日，抽完剩余 65 行）：又出 16 处，累计 29 处。**

| # | 源节 | 原判 | 实际 | 处置 |
| --- | --- | --- | --- | --- |
| 14 | agent §6.1 展开条件 | §6.1 | ⚠ **落点判错**：guide §6.1 是「机械分类」（运行时值不值得用），与 fan-out 形态无关；五形态含「胜者改进」全缺 | 补 §3.13 |
| 15 | agent §6.2 Work Unit 契约 | §2.4 | §2.4 是工单（整个 Task），**派工契约是另一层**；三字段派工纪律全缺 | 补 §2.11 |
| 16 | agent §6.3 建立 worktree | §3.2 | 十条里缺 4 条（同分支不可双检出、只隔离写入不阻读、凭据不得进分支、删 worktree ≠ 删证据） | 补 §3.14 |
| 17 | agent §6.4 候选隔离 | §2.2 | **「隔离靠纪律不靠机制、无法事后证明某轮真独立」缺**——这是诚实性条款 | 补 §2.11 |
| 18 | agent §6.6 评审裁决 | §2.2 | 事实裁决表（证实/证伪/未决）、两阶段评审、「不合格候选不进偏好评分」全缺 | 补 §5.10 |
| 19 | agent §6.7 整合 | §3.5、§5.5 | 「一条独立主张一个提交」「候选的绿不证明整合正确」缺 | 补 §5.10 |
| 20 | agent §6.8 停止规则 | §2.4 budget | 六条全缺 | 补 §3.13 |
| 21 | agent §7.5 载体语义 | §3.9、§5.4 | §5.4 只有散文，**七载体对照表缺**；「reflog 里还在不是保留策略」缺 | 补 §5.9 |
| 22 | agent §7.7 发布协议 | §3.5、§5.4 | candidate/publication/published **三路径区分缺**；「只要草案时 target 是候选集合」缺 | 补 §3.15 |
| 23 | agent §7.9 保留与 GC | §3.5 | 六档表、「GC 是显式阶段不是退出副作用」、删除前六项验证全缺 | 补 §3.16 |
| 24 | agent §11.3 未验证清单 | §7.4、§9.2 | 八条全缺；**「清单为空前一律按 `defined` 对待」缺**——这条管着怎么读 §2.6–§2.10 | 补 §7.6 |
| 25 | human §2 人的三个角色 | §4.1 | 提出者/执行者/principal 三分缺 | 补 §2.11 |
| 26 | human §7 人的义务 | §4.1、§4.5 | 六条全缺，含**「盲区声明是自愿的，只要说了就受罚，很快就没人说了」** | 补 §4.10 |
| 27 | human §8.3 委派 | §3.4 | 「委派转移执行，不转移最终责任」缺 | 补 §4.10 |
| 28 | human §14 成本与停止 | §6 | 「交叉阅读是二次复杂度」「未经事实验证要标注」「失败/超时/缺席也进记录」缺 | 补 §3.13 |
| 29 | 本文自身 | — | ⚠ **§4.7 写了「登记 §7.4 未决」，而 §7.4 里没有这条**——我自己犯了正在批的「承诺不进验收」 | 补 §7.4 第 20b 行 |

⚠ **第 14 条是第二次落点判错**（第一次是把载体轴写成风险轴）。两次都是**把源节挂到一个
名字相近、实质不同的节上**——这正是标题级验证抓不到、只有读正文才能抓到的错法。

⚠ **第 29 条是本文自己身上的**：我在 §4.7 承诺登记到 §7.4 却没登记。
与 `refact-fable.md` §5.2 承诺 `migration-map.md` 从未产出，是同一个形状。

**反向覆盖检查**：全文 `§N` 自引用扫描，指向不存在章节的 10 处**全部位于 §10 落点表
第三列的「同 agent 文 §X」中，指的是源稿节号**，非本文缺节；已统一改写为「同 agent 文 §X」
以免误读。除此之外未发现本文写入源稿所无的规范性主张（编辑性串联除外，如 §2.9 末尾
指出 Harness 腿与 §4.3 LangGraph 腿恢复语义不同——这是两个源之间的连接，不是新主张）。

**第三轮（同日，抽 `refact-fable` 31 行 + 兑现 `runtime-architecture` 33 行的旧账）：
再出 21 处，累计 50 处。**

`runtime-architecture` 的 33 行本已在同日一份独立审计里做过正文级对照，查出 15 处——
⚠ **但只记录、未修补**。⚠ 那份审计一度被放进 `rounds/dev-plan-refact/`，
**等于宣告那一轮是做审计的**；现已撤销，内容并入本节（该文件不再存在）。
本轮兑现其中 14 处
（第 11 项 `audit_after` 已由 §4.6 顺带补上）：

| 源节 | 缺的是什么 | 补到 |
| --- | --- | --- |
| §2.3 | **五家登记表本体**（36 行取值 + `channel_grade`）——§2.3 只说「至少登记这些字段」，无取值 | §2.12 |
| §2.4 | **本轮已发生介入的实例级清单 12 行**——⚠ 正是上一轮 ⑤ 验收 `C-1` 抓出的缺项，**连丢两轮** | §4.11 |
| §2.8 | **23 条轨迹表本体** + 对照组 + 引用纪律两条——§5.3 只留读数，**结论在、证据不在** | §5.11 |
| §4.2 | 读数三条 + 「机械非空不等于填对」的实例 | §2.12 |
| §4.5 | **数据网关 / 不得给裸库凭据**（硬约束） | §3.2 |
| §4.7 | 三行现状事实：无 GPG 密钥、`id_rsa` 对主仓可写、Windows 侧亦跑本地 agent | §4.4 |
| §2.2 | 别名登记、`privacy`(NO ZDR)、观察窗中位数、`freshness` | §2.4 |
| §2.7 | `author_claimed` / `author_attested` 拆分 | §5.3 |
| §4.1 | `codex exec --json` 锚点（本次复跑于 `7d6f808b`） | §2.12 |

`refact-fable` 的 31 行**此前只抽过 3 处**，本轮补抽，出 7 处：

| 源节 | 缺的是什么 | 补到 |
| --- | --- | --- |
| §2 | **六条设计原则 P0–P5**；尤其 **P5「凡能落成代码/测试/门禁的纪律必须落成」**，与推论**「一个只能靠人转述的环节等于没有环节」**——整段无落点 | §1.6 |
| §2 | P0 的适用层级：**对象的小生命周期不是第二套状态机** | §1.6 |
| §3.10 | **内核对象 ↔ 开发载体对照表**——§3.3 是状态投影表，与它不是同一张 | §3.17 |
| §3.8 | 状态脚本硬要求：**推导值 ≠ 声明值即报错**、**边不在合法表即报错退出**、分发前角色冲突拒绝 | §3.18 |
| §3.12 | acceptor「既得利益最小、由处置表算出」；L3「抽样规则写进工单」 | §5.5 |
| §3.5 | 「分类节点只给四条判据的命中证据，**不给 tier**」 | §2.1 |

⚠ **`runtime-architecture` 那 15 处是「查出来了没修」**——审计写完之后
在一份独立文件里躺了几个小时，没有回到被审对象上。
**这与 `refact-fable.md` §5.2「承诺产出但不进验收」是同一个形状的第三次出现**：
第一次是 `migration-map.md` 从未产出，第二次是我在 §4.7 承诺登记到 §7.4 而没登记，
第三次是这份审计只记不修。**记录不等于修补，审计不等于验收。**

**查过但确认「不是缺」的，一并记下，免得下次重查：**

| 曾疑 | 实际 |
| --- | --- |
| 合法转换全集（五行状态表） | 本文**故意不重写**——§0.1 边界写明「不重写对象定义、合法边」，改为按 commit 引用内核。**这是对的** |
| git 的两个角色（载体永久 / 账本要拆） | §5.4 有，措辞不同 |
| `runtime-architecture` §2.5 产物→状态机 16 行 | §3.3 有 13 行 + 散文补 3 行，且**多一行**「同一执行从 checkpoint 续跑」——是 K1/K2 的新发现 |
| `H5-final` / `H5-round` 拆分 | §7.4 风险 4 有 |
| 三道边界的**机制** | §3.2 有（撤销的是「组合成安全架构」这个结论，不是机制本身） |
| §2.7 六条比对规则 / `TraceEnvelope` | §5.3 全有；`TraceEnvelope` 明说不沿用该名但保留字段，并给了理由 |
| `lifecycle-agent` §5.4「作者自检不能代替独立验收」 | 已补入 §5.5 L1 |

**四份源稿 182 行全部抽到正文级，本轮抽查完成。**
累计 50 处真缺、2 处落点判错，本文 827 → 2352 行。

## 10. 四份源稿逐节落点

**这张表是覆盖的索引，不是覆盖的证明。**声称落在某节而该节没有对应内容，
比不写这张表更差——那是伪取证。核它的办法是抽查落点、以正文为准，
**不以表格自称的覆盖为准**。

**两条让它可被机械核的规矩：**

1. **表的骨架机械生成**，不手抄——源稿的全部 `##` / `###` 标题按 commit 枚举后填入左两列，
   人只填第三列。手抄的表会漏行，而漏掉的那行**不会有人发现**（它根本不在表里）；
2. **一个源稿标题恰有一处落点**。允许写多个章节号，但不允许**同一标题出现两行**——
   出现两行说明拆分了却没说清哪部分去了哪里，核的人无从抽查。

表中标题按源稿呈现；HTML 实体只用于让已撤销设计的字面不被机械门误判为正文复活，渲染后的标题不变。

⚠ **2026-09-07 扩表**：由两份源稿（64 行）扩为**四份**（182 行），新增
`archive/development-lifecycle-agent.md` 73 节与 `archive/development-lifecycle-human.md` 45 节。
这两份从未进入 `runtime-refact` 轮的只读输入集，因此本文初版没有它们的落点——
**这是起草任务书时的输入边界失误，不是整合者漏做**。

⚠ **`human` 文有 39% 与 `agent` 文近乎逐字重复**（实测：≥8 行的节共 563 行，
重合度 ≥0.55 的 222 行）。重复节的落点栏注明「同 agent 文 §X」并给出重合度——
**一个源稿标题仍恰有一处落点**，注明同源是为了让抽查的人知道该去比哪一节。

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
| refact-fable | 2. 设计原则 | **§1.6** P0–P5 + 两条推论；⚠ **抽查发现原缺**：P5「凡能落成代码的纪律必须落成」与「只能靠人转述的环节等于没有环节」整段无落点 |
| refact-fable | 3. 目标架构 | §2–§5 |
| refact-fable | 3.1 一套状态机，两个&#32;Profile | §1.1、§2.3；撤销部署形态分层，保留内核两种契约对象 |
| refact-fable | 3.2 执行者模型：三种 kind，一张登记表 | §2.3、§4.1；纠正人为 principal 而非 executor |
| refact-fable | 3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源 | §4.2 |
| refact-fable | 3.4 人的通道：收件箱 + 回执 | §4.1、§4.4；保留通道/身份分离，撤销未经真实路径证明的具体存储 |
| refact-fable | 3.5 路由：三值决策，模型只建议 | §2.1、§2.5；「分类节点只给四条判据的命中证据，不给 tier」补入 §2.1（**抽查发现原缺**） |
| refact-fable | 3.6 工单：一个冻结的 Artifact，一次确认 | §2.4、§3.1 |
| refact-fable | 3.7 工作区供给：纯函数，判据是独占与干净 | §3.2 |
| refact-fable | 3.8 状态判定与分发：一般化现有脚本 | **§3.18** 六条硬要求；⚠ **抽查发现原缺**「推导值 ≠ 声明值即报错」「边不在合法表即报错退出」「分发前角色冲突拒绝」 |
| refact-fable | 3.9 角色：supervisor 解体为五个各有定义的词 | §2.1、§2.2 |
| refact-fable | 3.10 开发&#32;Profile ↔ 内核对象对照 | **§3.17** 对照表本体（**抽查发现原缺**：§3.3 是状态投影表，与「对象↔载体」不是同一张） |
| refact-fable | 3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了 | §5.4 |
| refact-fable | 3.12 验证分层：谁判什么 | §5.5；acceptor「既得利益最小、由处置表算出」与 L3「抽样规则写进工单」补入（**抽查发现原缺**） |
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
| runtime-architecture | 2.2 Task Profile `dev.change` 版本 1 | §2.3、§2.4、§3；别名登记、`privacy`(NO ZDR)、观察窗中位数、`freshness` 四项补入 §2.4（**抽查发现原缺**） |
| runtime-architecture | 2.3 五个 Agent Profile：登记表 | **§2.12** 登记表本体 + `channel_grade`；⚠ **抽查发现原缺**（§2.3 只说「至少登记这些字段」，无取值） |
| runtime-architecture | 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行 | §4.1、§4.2、**§4.11** 实例级清单；⚠ **抽查发现原缺**——而实例级清单正是上一轮 ⑤ 验收 `C-1` 抓出的缺项，**连丢两轮** |
| runtime-architecture | 2.5 `dev.change` 的产物 → 唯一状态机 | §3.3 |
| runtime-architecture | 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现 | §5.4、§7.2 |
| runtime-architecture | 2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文 | §5.3；`author_claimed` / `author_attested` 拆分补入（**抽查发现原缺**） |
| runtime-architecture | 2.8 trace 样例：`refact-fable` 轮的真实产物 | **§5.11** 轨迹表本体 + 对照组 + 引用纪律两条；⚠ **抽查发现原缺**——§5.3 只留了「23 条里 2 条」的读数，**结论在、证据不在** |
| runtime-architecture | 3. P2 — Interaction 双向带载荷：一个内核修订工作单元 | §4.3、§8.1 K1–K2；核查后不启动该修订 |
| runtime-architecture | 3.1 缺口 | §4.3；故意不要原缺口判断，因为现有自由 resume 原语已覆盖所述形状 |
| runtime-architecture | 3.2 扩展后的绑定字段表 | §4.3；故意不要自造字段表，缺少真实消费者与拒收用例 |
| runtime-architecture | 3.3 <code>am&#101;nd</code> 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task | §3.3、§4.3；故意不要另开 Attempt，checkpoint 应原地恢复 |
| runtime-architecture | 3.4 与权力表的对应 | §4.2–§4.3；只保留实际 Interaction 与权力动作绑定 |
| runtime-architecture | 3.5 修订工作单元（按 `request-lifecycle.md:627` 修订纪律） | §1.1、§4.3；故意不要该单元，因其前提已被代码证伪 |
| runtime-architecture | 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果 | §5.1–§5.2 |
| runtime-architecture | 4.1 粒度是三个字段，不是一个；至少四档 | §5.1；`codex exec --json` 的锚点取证补入 §2.12（**抽查发现原缺**，本次已复跑于 `7d6f808b`） |
| runtime-architecture | 4.2 五家的取值 | **§2.12** 读数三条 + 「机械非空不等于填对」的实例（**抽查发现原缺**） |
| runtime-architecture | 4.3 证据权威性：由粒度推导，不由执行者声明 | §5.2 |
| runtime-architecture | 4.4 三道&#36793;界是架构组件，不随脚手架拆 | §4.4、§8.1 K3–K6；故意不要组合设计，真实动作未经过这些设施 |
| runtime-architecture | 4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离 | §3.2；「涉及第二租户或真实财务数据前必须经数据网关、不得给裸库凭据」补入（**抽查发现原缺**） |
| runtime-architecture | 4.6 R2：principal 通道也有粒度 | §4.4、§5.2 |
| runtime-architecture | 4.7 取证纪律与当前事实 | §4.4（含新补的三行现状事实：无 GPG 密钥、`id_rsa` 对主仓可写、Windows 侧亦跑本地 agent）、§8.1、§9 |
| runtime-architecture | 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线 | §6 |
| runtime-architecture | 5.1 分类规则（机械可判，全部由工单字段直接判） | §2.5、§6.1 |
| runtime-architecture | 5.2 反例（三类走运行时反而更贵的任务） | §6.2 |
| runtime-architecture | 5.3 T0 开销上界（复合向量，任一维超标即不标 T0） | §6.2 |
| runtime-architecture | 5.4 绕过的可观测性 | §6.3 |
| runtime-architecture | 6. 对 OP-1 / OP-2 / OP-3 的裁定 | §5.3、§6、§8.2；保留 OP-1/OP-3，按 K1/K2 撤销 OP-2 |
| runtime-architecture | 7. 覆盖声明、盲区与未验证项 | §7.4、§9 |
| runtime-architecture | 8. 自检：对照 `task.md` §8 十条 | §1.3、§8、§9、§10 |
| lifecycle-agent | 0. 边界和共同模型 | §0.1 |
| lifecycle-agent | 0.1 本文负责什么 | §0.1；跨机同步与「子仓要自己推」补入 §3.2（**抽查发现原缺**） |
| lifecycle-agent | 0.2 事实、目标和执行记录分开 | §1.2、§5.2、**§1.5 第 3 条**；`request-baseline` 的地位补入 §0.1（**抽查发现原缺**） |
| lifecycle-agent | 0.3 两层监督职责与等位原则 | **故意不要**：§0.0 第 2 条判定「supervisor 一词三义」；由 §2.1 五个组件词与 §2.2 内容角色替代，「等位原则」不再需要单独声明 |
| lifecycle-agent | 0.4 产出物的根本原则：私有地产生，单写者发布 | §3.6 |
| lifecycle-agent | 1. 两条同构路径 | **故意不要**：§0.0 第 1 条——两条路径的差异只剩「谁按了回车」，撑不起两份文档 |
| lifecycle-agent | 1.1 Agent 路径 | 同上；入口差异并入 §3.1 |
| lifecycle-agent | 1.2 Human 路径 | 同上；人的位置改由 §4.1 表达 |
| lifecycle-agent | 2. Submission 与 FastAPI 受理 | §3.1 |
| lifecycle-agent | 2.1 前端提交 | §3.1 第 1 条 |
| lifecycle-agent | 2.2 FastAPI 建立开发 Task | §3.1 第 1–2 条；⚠ **故意不要框架名**——FastAPI 属实现，不属规范 |
| lifecycle-agent | 2.3 Task 契约 | §2.4；⚠ **抽查发现原落点缺一半字段**，已补「硬门禁/质量偏好/待定项必须分开」与 8 个字段 |
| lifecycle-agent | 3. 简单与复杂任务 | **故意不要**该二分：§0.0 第 6 条，由 §3.4 三档取代 |
| lifecycle-agent | 3.1 简单 Task | §3.4 **载体轴段**；⚠ **原落点判错**——简单/复杂是载体轴，T0/T2 是风险轴，两轴正交，混写即 §2.5 警告的循环 |
| lifecycle-agent | 3.2 复杂 Task | §3.4 载体轴段；同上 |
| lifecycle-agent | 4. sandbox、Git 物化与执行器接入架构 | §3.2、§2.6 |
| lifecycle-agent | 4.1 谁建立什么 | §3.2 |
| lifecycle-agent | 4.2 物化步骤 | §3.2 |
| lifecycle-agent | 4.3 按 Task 塞入材料 | **§3.10** manifest 字段表 + 「材料可见 ≠ 使用授权」（**抽查发现原缺**） |
| lifecycle-agent | 4.4 物化门禁 | **§3.10** 物化门禁十条；⚠ **原落点 §3.2 只有 3 条复用判据，十条全缺**（抽查发现） |
| lifecycle-agent | 4.5 执行层路线：租用 loop，自建业务控制面 | §2.6 |
| lifecycle-agent | 4.6 两个官方 SDK：两个轴、非对称能力 | §2.7 |
| lifecycle-agent | 4.7 统一执行 Port 与三态能力探针 | §2.8 |
| lifecycle-agent | 4.8 Harness SDK 前置门禁与过渡补法 | §2.9 |
| lifecycle-agent | 4.9 双 runtime 的部署、进程与恢复 | §2.10 |
| lifecycle-agent | 4.10 专用 Agent 的构建方法，不冻结具体 Profile | §3.2 |
| lifecycle-agent | 4.11 OpenClaw Gateway：借机制，不转向 | §3.2 |
| lifecycle-agent | 5. Agent 执行内核 | §3 |
| lifecycle-agent | 5.1 冷启动核对 | **§3.10** 冷启动七条 + **写入前门禁五条（一票否决）**；⚠ **原落点两处均无此内容**（抽查发现） |
| lifecycle-agent | 5.2 上下文路由 | **§5.8** 八个改动面 + 能力四级词典；⚠ **原落点 §2.5 是路由成本字段，不是同一件事**（抽查发现） |
| lifecycle-agent | 5.3 共同纪律 | **§1.5** 八条（**抽查发现原缺**；§11 只有反面形式，无正面纪律） |
| lifecycle-agent | 5.4 单路实施 | §3.4 T1 行；「作者自检不能代替独立验收」补入 §5.5 L1（**抽查发现原缺**） |
| lifecycle-agent | 5.5 Checkpoint 与恢复 | §4.3、§2.10 |
| lifecycle-agent | 5.6 失败、澄清与改判 | §4.8 |
| lifecycle-agent | 6. Attempt 内的执行监督 Agent | **部分故意不要**：「执行监督 Agent」是 §0.0 第 2 条判掉的同名物；其纪律落 §2.2 与 round-protocol，不保留该角色名 |
| lifecycle-agent | 6.1 展开条件 | **§3.13** 五种执行形态；⚠ **原落点判错**——guide §6.1 是「机械分类」（运行时值不值得用），与 fan-out 形态无关（抽查发现） |
| lifecycle-agent | 6.2 Work Unit 契约 | **§2.11**；⚠ 原落点 §2.4 是工单（整个 Task），派工契约是另一层，三字段派工纪律全缺（抽查发现） |
| lifecycle-agent | 6.3 建立 worktree | **§3.14** 十条细则（**抽查发现原缺** 4 条：同分支不可双检出、只隔离写入、凭据不得进分支、删 worktree ≠ 删证据） |
| lifecycle-agent | 6.4 候选隔离 | §2.2、**§2.11**；⚠ 「隔离靠纪律不靠机制、无法事后证明独立」**原缺**（抽查发现） |
| lifecycle-agent | 6.5 角色分离 | §2.2 |
| lifecycle-agent | 6.6 评审、裁决和选优 | **§5.10** 事实裁决表 + 两阶段评审 + 「不合格候选不进偏好评分」（**抽查发现原缺**） |
| lifecycle-agent | 6.7 改进、整合和回归 | **§5.10** 整合纪律；⚠ 「一条独立主张一个提交」与「候选的绿不证明整合正确」**原缺**（抽查发现） |
| lifecycle-agent | 6.8 停止规则 | **§3.13** 六条（**抽查发现原缺**） |
| lifecycle-agent | 6.9 内层的三条硬禁令 | **§4.9**（**抽查发现原缺**）；含「忘了传 handler 与故意自动批准在代码里长得一样」 |
| lifecycle-agent | 7. 产出物与 commit 的全生命周期 | §3.6–§3.9 |
| lifecycle-agent | 7.1 先确定身份、所有权和发布权 | §3.6 |
| lifecycle-agent | 7.2 命名空间 | §3.6 |
| lifecycle-agent | 7.3 产出物分类与载体 | §3.3 末段 Artifact 版本属性 |
| lifecycle-agent | 7.4 候选状态机 | **§3.11** 八态 + 七条纪律；⚠ **原落点只有一句「Artifact 有版本属性」，状态机全缺**（抽查发现） |
| lifecycle-agent | 7.5 未提交文件、commit、分支与 worktree 的不同语义 | **§5.9** 七载体对照表 + 「reflog 里还在不是保留策略」；⚠ 原落点 §5.4 只有散文，无对照表（抽查发现） |
| lifecycle-agent | 7.6 各种并发场景的处置 | §3.7 |
| lifecycle-agent | 7.7 最终路径的发布协议 | **§3.15** 三路径 + compare-and-swap + 「只要草案时 target 是候选集合」（**抽查发现原缺**） |
| lifecycle-agent | 7.8 覆盖或来源不明时的事故处理 | §3.8 |
| lifecycle-agent | 7.9 保留与垃圾回收 | **§3.16** 六档表 + 「GC 是显式阶段不是退出副作用」+ 删除前六项验证（**抽查发现原缺**） |
| lifecycle-agent | 8. 冻结、迟到结果与取消 | §3.9 |
| lifecycle-agent | 8.1 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵 | §5.6 |
| lifecycle-agent | 9. 权限、预算与副作用 | §4.5 |
| lifecycle-agent | 9.1 三道正交门与工具不可见原则 | §4.6 |
| lifecycle-agent | 9.2 四档审批、哈希绑定与凭据边界 | §4.7 |
| lifecycle-agent | 10. 证据、验收、交付和清理 | §5、§3.5 |
| lifecycle-agent | 10.1 最小证据账 | §5.7 |
| lifecycle-agent | 10.2 最终验收 | §5.5 L1/L3、**§3.12** 十三条（抽查：七条中六条已在 §3.12，「声称完成/全返回不算成功」在 §3.12 与 §11） |
| lifecycle-agent | 10.3 Delivery | §3.5 |
| lifecycle-agent | 10.4 sandbox 清理 | §3.5 |
| lifecycle-agent | 11. Human 与 Agent 对照 | **故意不要**：§0.0 第 1 条；两路径合一后无对照对象 |
| lifecycle-agent | 11.1 本文的生效边界 | §0.1 |
| lifecycle-agent | 11.2 本文的删除条件与清理清单 | §7.3 |
| lifecycle-agent | 11.3 本轮未验证清单 | **§7.6** 八条 + 「清单为空前一律按 `defined` 对待」；⚠ **原落点两处均无此八条**（抽查发现） |
| lifecycle-agent | 12. 完成判据 | **§3.12** 十三条 + 「缺项只能称已受理…不能笼统宣称完成」（**抽查发现原缺**） |
| lifecycle-agent | 13. 反模式 | §11 |
| lifecycle-agent | 14. 常见失败方式与项目实例 | §12 |
| lifecycle-agent | 附录 A：词汇对照 | §13 |
| lifecycle-agent | 附录 B：开发 Task 持久记录模板 | §14 |
| lifecycle-human | 1. 为什么要单独一份 | **故意不要**：§0.0 第 1 条 |
| lifecycle-human | 1.1 为什么本文必须自足 | 同上 |
| lifecycle-human | 1.2 两条路径的差异总表 | 同上；两路径差异并入 §4.1 |
| lifecycle-human | 2. 人的三个角色 | §4.1、**§2.11**（提出者/执行者/principal 三分**原缺**，抽查发现） |
| lifecycle-human | 3. 人独有的权力，及其义务 | §4.5 |
| lifecycle-human | 4. 跨会话续接：靠文档，不靠记忆 | §7.5 |
| lifecycle-human | 5. 小请求的裁量权 | §4.8 |
| lifecycle-human | 6. 改判三要素 | §4.8 |
| lifecycle-human | 7. 人与 agent 协作时，人的义务 | **§4.10** 六条 + 「盲区声明是自愿的，说了就受罚就没人说」（**抽查发现原缺**） |
| lifecycle-human | 8. 提出与委派一项开发工作 | §3.1 |
| lifecycle-human | 8.1 冻结工作单元 | §3.1、§2.4 |
| lifecycle-human | 8.2 工作区从哪来 | §3.2 |
| lifecycle-human | 8.3 委派 | §3.4、**§4.10**「委派转移执行不转移责任」（**抽查发现原缺**） |
| lifecycle-human | 9. 终审与责任归属 | §4.5 责任归属表 |
| lifecycle-human | 10. 执行内核 | §3（与 agent 文 §5 同源，重合度 0.4–0.85） |
| lifecycle-human | 10.1 动手前的核对与写入前门禁 | **§3.10**（同 agent 文 §5.1，重合 0.66；随该行一并更正） |
| lifecycle-human | 10.2 上下文路由与范围门禁 | **§5.8**（同 agent 文 §5.2，重合 0.84；随该行一并更正） |
| lifecycle-human | 10.3 共同纪律 | **§1.5**（同 agent 文 §5.3，重合 0.85；随该行一并更正） |
| lifecycle-human | 10.4 单路实施与定向审核 | §3.4 T1、§5.5 L1（同 agent 文 §5.4） |
| lifecycle-human | 10.5 冻结、迟到与取消 | §3.9（同 agent 文 §8） |
| lifecycle-human | 11. 人作为协调者：fan-out | §2.2、§3.4 |
| lifecycle-human | 11.1 展开条件 | **§3.13**（同 agent 文 §6.1；随该行一并更正） |
| lifecycle-human | 11.2 派工契约 | **§2.11**（同 agent 文 §6.2；随该行一并更正） |
| lifecycle-human | 11.3 建立 worktree | §3.2、**§3.14**（同 agent 文 §6.3） |
| lifecycle-human | 11.4 候选隔离 | §2.2、**§2.11**（同 agent 文 §6.4，重合 0.76） |
| lifecycle-human | 11.5 角色分离 | §2.2（同 agent 文 §6.5，重合 0.70） |
| lifecycle-human | 11.6 评审、裁决和选优 | **§5.10**（同 agent 文 §6.6，重合 0.57） |
| lifecycle-human | 11.7 改进、整合和回归 | **§5.10**（同 agent 文 §6.7） |
| lifecycle-human | 11.8 停止规则 | **§3.13**（同 agent 文 §6.8） |
| lifecycle-human | 12. 产出物与 commit 的落地纪律 | §3.6–§3.9（与 agent 文 §7 同源） |
| lifecycle-human | 12.1 根本原则：私有地产生，单写者发布 | §3.6（同 agent 文 §0.4，重合 0.64） |
| lifecycle-human | 12.2 本仓的具体落点 | §3.6 本仓落点表 |
| lifecycle-human | 12.3 未提交文件、commit、分支与 worktree 的不同语义 | **§5.9**（同 agent 文 §7.5，重合 0.84） |
| lifecycle-human | 12.4 产出物分类 | §3.3、**§3.11**（同 agent 文 §7.3/§7.4） |
| lifecycle-human | 12.5 各种场景的处置 | §3.7（同 agent 文 §7.6） |
| lifecycle-human | 12.6 覆盖或来源不明时的事故处理 | §3.8（同 agent 文 §7.8，重合 0.88） |
| lifecycle-human | 12.7 最终路径的发布协议 | **§3.15**（同 agent 文 §7.7） |
| lifecycle-human | 12.8 保留与清理 | **§3.16**（同 agent 文 §7.9） |
| lifecycle-human | 13. 证据账 | §5.7 |
| lifecycle-human | 14. 成本与停止规则 | **§3.13** 成本纪律四条；⚠ 「交叉阅读是二次复杂度」「未经事实验证要标注」「失败/超时/缺席也进记录」**原缺**（抽查发现） |
| lifecycle-human | 15. 完成判据 | **§3.12**（同 agent 文 §12；随该行一并更正） |
| lifecycle-human | 16. 反模式 | §11 |
| lifecycle-human | 17. 常见失败方式与项目实例 | §12 |
| lifecycle-human | 18. 边界 | §0.1 |
| lifecycle-human | 附录 词汇对照 | §13 |

## 11. 反模式

**这一节是机制描述，不是训诫。**每行左边是做法，右边是它**怎样失败**——
没有失败方式的条目不该进表。与 §8 的区别：§8 是本项目**已被推翻的设计**，
本节是**任何项目都会踩的做法**。

| 反模式 | 失败方式 |
| --- | --- |
| 只保存整理稿，不保存原话 | 原始意图不可追溯（违 `I1`） |
| Task 未落库就建仓或调度 | 无主 sandbox、不可恢复执行 |
| 把所有资料塞进工作区 | 越权、泄密、上下文污染 |
| 执行者猜仓库、分支或目录 | 修改落错可写面 |
| 在获准工作区之外另建仓 | 绕过供给、授权和回收 |
| **会话隔离当作文件隔离** | 多个执行者仍写同一物理文件，**最后保存者覆盖前者** |
| **用 `-new` / 时间戳 / 执行者名当隔离** | **文件名不是工作区。**共享路径上照样后写覆盖先写，且制造虚假安全感——以为改了名就安全，于是继续都写同一个目录 |
| 把人的主 checkout 当文档原件投放点 | 既覆盖人的未提交改动，也覆盖其他执行者的草稿；**被覆盖方无痕消失** |
| 未提交就让别人到「同一路径」接盘 | 拷走的是没有归属的污染源，**接盘者不再是独立候选** |
| 交卷报路径不报 commit | 路径会漂移、会被覆盖，**评审对象丢失** |
| 每个执行者都写共享 `handoff.md` | 单写者面被互相覆盖，交接游标失真 |
| 所有候选直接写用户指定的最终路径 | **路径成为竞态，选优在写入时被偷偷决定** |
| 多个执行者直接改 master/main | 未经整合的草稿互相覆盖并污染发布面 |
| 发布时不校验目标 HEAD/version | 新结果静默覆盖别人的更新，或旧结果覆盖新结果 |
| non-fast-forward 后 force-push | **用运输命令抹掉并发历史和已评审对象** |
| 用 mtime 判断作者或采用版本 | 时钟和后续复制会误导溯源，provenance 丢失 |
| 未跟踪文件作为唯一交付 | 无 commit/digest，覆盖后难以恢复和归因 |
| 并行单元共用工作树 | 相互覆盖、无法归因 |
| 候选读取其他候选 | **独立信号退化成改写** |
| 候选阶段偷看发起方倾向 | 同上；候选向倾向收敛，选优失效 |
| 作者自评自收、自我批准 | 同一判断链为缺陷背书 |
| 候选人互投制造独立性 | 被审方兼任判定方，**独立性是假的** |
| 多数票覆盖失败测试 | 偏好压过事实 |
| 全体一致的共同盲区 | 多个相似模型可能共享盲区，一致不等于正确 |
| 只固定分支名 | 评审对象漂移 |
| 冻结后原地替换，或把迟到 commit 算进本轮 | 比较对象漂移，无法复核 |
| final commit 不回归 | 整合缺陷未被发现 |
| 大补丁混合多条主张 | 无法逐条处置，接受与拒绝被绑在一起 |
| 把会话记忆或人脑当状态账 | 接手者无法恢复现场，决定无痕丢失 |
| 只靠自律执行纪律 | **换人或换会话后纪律蒸发** |
| Git 充当授权、预算或副作用账 | 恢复后越权或重复动作 |
| 删除分支/worktree 前不建立持久 ref | commit 变成不可达对象，可能被回收 |
| 复制文件代替整合记录 | 内容存在但来源、取舍和验证对象不明 |
| 「已派工」或「全部返回」当作完成 | **内部动作冒充用户结果** |
| 成功后立即删工作区 | commit 和证据丢失 |
| 静默扩大范围 | 越权副作用无人批准 |
| 伪造完整结果掩盖缺口 | 验收被污染，缺口被当成已完成 |
| 通知失败改写终态 | Delivery 故障污染结果 |
| 人当协调者就跳过隔离与角色分离 | 独立信号退化成改写——**协调者身份不豁免纪律** |

## 12. 常见失败方式与项目实例

§11 是机制，本节是**本项目实际遇到过的失败**，按**证据强度**分三级。
⚠ **三级不是修辞差别，是能不能独立复核的差别：**

- **已核对事实**：证据当前仍可独立取得并复核（commit、blob、文件存在性、可重跑命令）；
- **事故报告**：确实发生过，但现场已灭失，只能按当事方陈述记录，**不能独立复核**；
- **设计风险**：机制上成立，但本项目尚未实际踩到，或原始证据出处已不可取得。

⚠ **三级不可互相升格。**尤其**不得**把「机制上必然如此」当成「此处已核对」——
这正是 §3.8 第 4 步要求的态度：**能证明的和推断出来的分开写。**

| 失败 | 证据性质 | 控制在哪 |
| --- | --- | --- |
| **隔离来自 worktree + 命名分支，不来自文件名** | **已核对事实（2026-09-02）**：三方在各自 worktree 与命名分支上持有**同名且不带后缀**的同一文件，内容互不相同且**全部得以保留**，各自 commit 与 blob 可独立复核。故后缀**非必要**；又因同一工作树内两方写同一带后缀的路径照样互相覆盖，后缀亦**非充分** | §3.6、§11 |
| **未提交的同路径写入没有任何保护** | **已核对事实**：Git 对未跟踪/未提交文件的同路径写入不提供冲突检测、不留历史、不留作者归属。这是 Git 语义，**可随时复现** | §3.6、§3.7 |
| 多执行者写进共享 checkout 造成覆盖 | **事故报告（2026-09-02），现场已灭失**：当事方陈述有产出被后写覆盖。共享路径上的文件事后已被清走，**具体发生过哪一次覆盖、写入顺序和责任人均不可独立复核**，本表不作此断言 | §3.6、§3.8 |
| 以工作区最后一版代替 commit 做交卷或比选 | **已核对事实**：磁盘上的「当前文件」不携带作者归属，也不能证明谁先写完 | §3.7 |
| 只写分支名，不固定 commit | **事故报告（2026-08-27）**：当事方记录评审曾引用旧提交而主方已前进；原始记录可取回，但其中**未找到**对应条目，**故不升为已核对** | §3.9 |
| 评审意见的处置边界由被审方单方划定 | **已核对事实（2026-08-27）**：处置记录逐条由被审方判定采纳或拒绝，其中一条门禁因「三台机器分别报 0 / 4 / 95 条失败」被判为误报并删除。⚠ **「优胜作者拒绝改进」这一更强的说法未获记录支持，不采用** | §2.2、§5.5 |
| 评审给出的验收标准无人回跑 | **已核对事实（2026-08-27）**：处置记录末节自记一份验收标准「**未回跑**」、一份「**待评审方执行**」、一份仅第 3 条通过 | §5.5 L1 |
| 只测一端就宣布跨仓契约完成 | **现行硬规则**（constraints C4）：单仓 CI 只跑自己那半，provider 改了、consumer 锁没跟，两边各自都绿 | §1.3 |
| 拿休眠代码当能力证据 | **已核对事实**：一家以本仓休眠的 `AgentProfile.permits_tool` 佐证租用 SDK 的工具门，**九份评审无一发现** | §2.6、§5.2、§5.6 |
| 取证工具自身有边界而未声明 | **已核对事实**：在助手自带沙箱内跑取证命令，`/proc/self/uid_map` 为 `0 1003 1`，于是沙箱内一切看起来都是 root，据此写出「本机所有进程都是 root」。⚠ **取证栏必须注明主机、执行身份、是否在沙箱内** | §4.4 |
| 把「某载体证不了 X」写成「X 未被证明」 | **已核对事实**：见 §7.2 的更正 | §7.2 |
| 候选提前读取其他方案 | 设计风险：机理清楚，本项目原始记录出处已不可取得 | §2.2 |
| 多数票覆盖失败测试 / 全体一致的共同盲区 | 设计风险：多个相似模型可能共享盲区 | §2.3、§11 |
| 候选人互投决定胜负 | 设计风险：结构上「被审方兼任判定方」已出现过，但候选互投这一具体流程尚未实跑 | §2.2 |
| 大补丁混合多条主张 | 设计风险，尚未实跑 | §11 |
| 整合时拷贝未提交文件进共享主仓 | 设计风险：绕过选定哈希，**主仓变成公共投稿箱** | §3.6、§3.7 |
| 工作区回收后证据不可达 | 设计风险：工作区是临时供给，**不是档案** | §3.5 |
| **完整选优流程本身** | **本项目尚未完整实跑**：独立裁判、匿名随机评审和停止规则目前是制度设计，**不得写成既成能力** | §2.2、§3.4 |

⚠ **本表的分级本身就是纪律的示范。**2026-09-02 那一例被拆成三行：两行是任何人现在都能
复核的事实，一行是现场已灭失的事故报告。**不写「谁覆盖了谁」**——后者虽是当事方陈述且
机制上成立，但现场已被清走，按 §3.8 第 4 步，mtime 与「最后一版」只是线索，不足以单独证明
写入顺序或责任人。

纪律的效力不依赖那次覆盖是否可复核：前两行已核对事实足以支撑 §3.6 的全部要求。
⚠ **用不可复核的叙述去加强一条本来就成立的规则，只会削弱整份文档的证据标准。**

## 13. 词汇对照

产品对象名只在这里对照，**不把产品状态机搬进本文**。

| 内核用语 | 本文对应物 |
| --- | --- |
| Submission | 原始请求来源；人直接提出时由人冻结请求与验收（§3.1） |
| Task | 一件有边界的开发工作及其冻结契约（§2.4） |
| Attempt | 一次实施、候选或修复轮次（§3.3） |
| Work Unit | 派出的子工作单元；**不是产品子 Task** |
| Artifact | 代码、补丁、报告、测试输出、证据（§3.6） |
| Interaction | 向 principal 的澄清或批准请求（§4.3） |
| Event | 追加式改判与证据记录（§5.7） |
| Delivery | 最终回复与可重取产物（§3.5） |
| Handoff | [`handoff.md`](handoff.md)；**单写者面**（§7.5） |
| 工作区 / worktree | 每个可写执行者的并行隔离工作区（§3.2、§3.6） |
| 命名分支 | 一执行者一分支；commit 的**运输通道，不是评审对象**（§3.9） |
| 未提交工作区文件 | 仅本地草稿；**同一工作区同一路径后写覆盖先写**（§3.7） |
| 人的主 checkout | 如 `~/master/<仓>`；**只读参照，不是投稿箱**（§3.6） |
| Attempt 租约 / fencing | **产品侧机制**，语义见内核；**开发侧无等价运行时**，迟到判定靠冻结 commit 与整合方核对（§3.9） |
| `dispatch_event` | 人代运行时执行的一次传输动作；**不是权力，是可计数的欠账**（§5.1） |

## 14. 开发 Task 持久记录模板

载体可以是数据库、Issue、PR、事件流或仓库文件，但**不能丢失原始请求、边界、验收、基线、
证据和改判历史**。⚠ **空栏必须写「不适用」及理由——空着与「忘了」无法区分。**

```markdown
# DEV-<ID>：<短名>

## ① 原始请求
<用户原话，不改写>

## ② 受理、边界和授权
- 规范化目标：            - 包含：                - 不包含：
- 不包含部分归属：        - 权限与批准点：
- 预算、期限和停止条件：  - run / owner / work unit：
- 可写根与 output namespace：
- publication target / integrator：

## ③ 基线与工作区
- Task / Attempt：        - workspace：           - source refs：
- baseline commit / gitlinks：                    - 适用指令：

## ④ 决策点
| ID | 问题 | 结论与理由 | 证据 |

## ⑤ Work Units 与落地去向
| Work Unit | owner | branch/worktree/namespace | output commit/digest | publication target | status |

## ⑥ 验收标准与证据
| ID | 标准 | 判定 | 证据 |

## ⑦ 依赖、Interaction 与副作用
- 依赖：                  - 澄清/批准：           - 副作用账：

## ⑧ 状态流转与改判
| 时间 | 状态/改判 | 触发 | 原判断错处 | 新判断 |

## ⑨ 交付与清理
- final commit / Artifact：                       - provenance / supersedes：
- published ref / publisher：                     - 未覆盖与残余风险：
- Delivery：                                      - 工作区清理：
```

⚠ ⑧ 的四列对应 §4.8 的改判三要素——**「原判断错处」栏写「当时信息不全」不算填**，
要写出具体哪一步推错了。
