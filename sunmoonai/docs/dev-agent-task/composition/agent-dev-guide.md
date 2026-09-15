# Agent 开发指导：一个产品运行时，一套开发纪律

> 迁自 `dev-plan/agent-dev-guide.md`（tag `dev-plan-final`） 的以下各节（`49d4ecb7`，2026-09-14）。节号沿用原文件；原文件其余各节的去向见 MIGRATION.md（2026-09-15 删除，原文见提交 `e7ab0e0b`）。

## 0. 先读结论

平台只建设一个产品运行时。它以
[`request-lifecycle.md`](request-lifecycle.md) 定义的 Task、Attempt、Interaction、Artifact、
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

当前基于 Git 的多方竞争是这条链的手工实现，也是验证对象形状和协作纪律的脚手架；它不能证明数据库事务、
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
| [`request-lifecycle.md`](request-lifecycle.md) | 引用七对象、Task/Attempt 状态机、`I1`–`I15`、`F-*`、`AT-*` | 不重写对象定义、合法边或产品验收矩阵 |
| [`competition-protocol.md`](protocol/competition-protocol.md) | [§3.19](protocol/competition-operations.md)–[§3.22](../components/backend/components/04-agent-execution/agent-dev-guide.md) 汇总执行所需的阶段、取件、超时规则 | 不另立协议版本；协议改变时同步修订本导读 |
| [`constraints.md`](constraints.md) | 开工前自检硬约束，尤其 A1–A5 | 不把自检改成建议 |
| [`development-plan.md`](../components/backend/composition/development-plan.md) | 解释通用执行编排与领域能力的分工 | 不记录进度 |
| 各 turn 的 `user-message.md` | 每次派工的任务书：写明交回哪一种，以及背景、范围、验收、约束 | 随 turn 冻结，执行者不改 |
| `thread/` | 每次派工到交回（turn）的发出内容与交回物；进度由任务目录推出 | 交回即冻结，改只能开新 turn |
| `working/request-baseline/`（已删除，见 tag `dev-plan-final`） | **所有者的原始需求档案**：只解释来源，**不覆盖现行合同，也不证明当前能力**（`I1` 在本仓的实物） | 不据它断言现状 |
| 历史 archive 五稿及 README | 相容内容在本文正文，取舍与来源见 源稿第 10 节（tag `dev-plan-final` 中的 dev-plan/agent-dev-guide.md）；只用于历史复核 | 不作为开发前置阅读；被撤销主张集中在 [§8](../components/backend/composition/agent-dev-guide.md)，不恢复其规范效力 |

内核的对象和状态以 `request-lifecycle.md @ ed0b5136:92-343` 为准；协作阶段以
`round-protocol.md @ ed0b5136:52-706` 的标题为准。本文出现的表都是开发投影或实现要求，
不是第二份产品定义。

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

### 1.5 执行者的共同纪律

> 依据的通用规范：[总则「执行者的共同纪律」](../../dev-agent-standards/general-rules.md)

不论单路还是并行，不论人还是 agent，八条都成立：

1. **不用计划覆盖原始请求**（`I1`）；
2. 只在范围、工具、数据、预算和副作用边界内行动；
3. **区分事实、推断、假设、缺失和未运行验证的结论**，不可混写；
4. 对可中断工作持久化 checkpoint；
5. 无法满足完成契约时请求输入或**明确失败**，不交半成品；
6. 在**最终固定版本**上运行与风险相称的验证；
7. 报告盲区、副作用和残余风险；
8. 未经授权不推送、合并、发布、删除远端资产或扩大外部影响。

⚠ 第 3 条是 [§5.2](../components/backend/composition/agent-dev-guide.md) 采信规则与 [§12](../components/backend/components/06-acceptance-commit/agent-dev-guide.md) 三级证据分档的**前提**：分不清事实与推断，
后面两处的分级就无从谈起。

### 1.6 七条设计原则

> 依据的通用规范：[SDD「设计必须满足」](../../dev-agent-standards/deliverables/sdd/sdd-rules.md)

全文的取舍都回到这七条。它们不是新主张，是把本仓已成文的判断当成设计约束用到底：

| # | 原则 |
| --- | --- |
| **P0** | **只有一套状态机（Task / Attempt）**，场景差异只体现在 Profile 的 guard、必需产物与 interrupt 策略；**任何场景不得新增状态词** |
| **P1** | **同一事实只有一个权威写入面**；两份同构文档即两个真源（`I13`，[§1.2](../components/backend/composition/agent-dev-guide.md)） |
| **P2** | **状态从产物反推，不从声明读取**——人的动作也不例外 |
| **P3** | **方向不对称**：朝严谨可自裁，朝省事须人确认；⚠ **默认值属于省事方向** |
| **P4** | **判据必须声明覆盖范围**；⚠ **覆盖不全比没有更危险**（[§5.2](../components/backend/composition/agent-dev-guide.md)） |
| **P5** | ⚠ **凡能落成代码、测试或门禁的纪律必须落成**；文字只描述意图，不构成机制 |
| **P6** | **设计机制前，先核实它要处理的动作实际发生在哪里、由谁执行、经过什么路径**；未核前提只能标假设，验证办法见 [§1.7](../components/backend/components/06-acceptance-commit/agent-dev-guide.md) |

**两条推论：**

⚠ **一个只能靠人转述的环节等于没有环节**（P2 + P5）。这条决定了本文对人介入的全部设计：
[§4.2](../components/backend/composition/agent-dev-guide.md) 的每一行都要有 `enforcement_point`，[§4.4](../components/backend/composition/agent-dev-guide.md) 要求强制点落在执行者够不着的地方，
理由都在这里。

⚠ **P0 的适用层级是 Task 与 Attempt。**Artifact、Interaction 等对象各有自己的小生命周期
（[§3.11](../components/backend/composition/agent-dev-guide.md) 的 `DRAFT → FROZEN → … → PUBLISHED`、内核的 `consumed_at`）——
**那些不是「第二套状态机」，而是对象属性**，并且同样跨场景共用、不得按场景另造。
把对象属性误认成状态机，会导致每个场景各造一套；把状态机误认成对象属性，
会导致状态词失控增长。**两边都错，方向相反。**

### 7.4 风险和未决

**逐条登记，每条带处置。**只写「有风险」而不写「现在怎么办、什么条件下才动」的清单，
下一轮没人知道该不该碰它。

| # | 事项 | 状态与处置 |
| --- | --- | --- |
| 1 | Agent Profile 的实际模型、GUI 内部事件与部分 CLI 工具事件不可机械核验 | ⚠ 未验证；登记表相应字段标 ⚠，**不得用未核值反推能力** |
| 2 | 无进程入口的分发者永久需要人工桥 | 登记为**可计数的欠账**（`dispatch_event{mode=manual}`），**不伪装成自动化** |
| 3 | principal 确认与 agent 共享宿主身份 | 证据只能标 `reported`；身份边界未落地前不得写成 `attested` |
| 4 | **H5-final / H5-round 拆分**：竞争内产物写主线的管辖 | 未决；已由前轮登记，**本文不擅自改权力表行数**（原 handoff：所有者五次执行 `publish-*.sh` 写主线，都是 H5 管辖的 Side Effect 但未经 H5 门；见 tag `dev-plan-final` 中 runtime 那次竞争的 runtime-disposition.md「L.1」） |
| 5 | **H5 的机制化强制点** | 两个有效方向均需所有者动作；现状登记为「人的显式动作」 |
| 6 | **响应者身份鉴别**（Interaction 服务化的前置） | 未决；**信任域收紧前不拆** |
| 7 | typed review／ruling／acceptance 是否只是 Artifact 类型细化 | 未决；若属对内核 Attempt 定义的扩充，按内核修订纪律另起工作单元 |
| 8 | **结构化修订（部分否定／替代）的规范形状** | 未决；**必须用库原语构造**，不得反推平台级 patch 协议 |
| 9 | `retroactive` 登记与内核 `I1`「原始输入不被后续解释覆盖」的关系 | 未验证；建单时一并核 |
| 10 | 独立性按 `harness` 或 `(harness, model)` 分组 | ⚠ 无跨题数据；**只能作观察值**，由「候选相似度」校验后再定 |
| 11 | **T0 的「可逆出口」**（只落 worktree、免 H5） | 未决；属**省事方向**的新权力表行，须有签名次数数据后再议 |
| 12 | **「命中任一条即 T2」中「权威层」覆盖面过宽** | 判据属流程规范，改它由该规范自己的多方竞争处理 |
| 13 | **触点疲劳导致盖章化** | 观察值：回执耗时、相对预填的改动项数、每类触点次数；**不设自动动作** |
| 14 | **单 principal 阶段的权力表在多用户场景是否够用** | 表结构已按 principal 设计；capability 列等出现第二个 principal 再加 |
| 15 | **三值路由初期大量 `ask`** | 预期行为；每次 `ask` 的人工选择按「裁量是规则的孵化器」反哺规则表 |
| 16 | 内核演化冲击本文 | 三条：按 commit 引用内核、内核改动按最重档、改后重跑状态词比对 |
| 17 | **`QUEUED` / `RUNNING` 在事件落地前不可判** | 已声明；脚本合并显示并标 ⚠ |
| 18 | **H1 与 H5 落在同一 commit 时账本上的歧义** | 未决（服务态应是两个 Interaction；手工态今天做不到） |
| 19 | 运行时外的绕过天然不完备 | principal 侧指标在共享身份下是 `UNKNOWN`，**不得写成零** |
| 20b | **`llm-review` 能否用于任何 `auto_policy = 无` 的权力表行** | 未决。[§4.7](../components/backend/components/05-interrupt-resume/agent-dev-guide.md) 立了四档审批，但 `llm-review` 不是 principal 的权力，在 [§4.2](../components/backend/composition/agent-dev-guide.md) 权力表里没有行。⚠ **本文不裁**——它要么是 H 行的一个前置过滤器，要么根本不该出现在需人批准的路径上，两种读法后果不同 |
| 20 | 预算账、证据账与 Agent Profile 生效仍是后续工作 | 见 `handoff.md @ ed0b5136:14-19`、`handoff.md @ ed0b5136:30-66` |
| 21 | 历史产物只在单机的可恢复性 | ⚠ 旧稿报告部分产物/冻结标签只在本机；本次未核当前远端。不外推为“现在仍只有一份”，交付前按 [§3.16](../components/backend/components/06-acceptance-commit/agent-dev-guide.md) 核持久 ref/获准副本及重取能力，不以此擅自 push |
| 22 | 库的完整 API 面、多次中断与版本兼容 | ⚠ 历史记录只覆盖若干用法；SDK/库升级前按 [§5.13](../components/backend/composition/agent-dev-guide.md) 重核，不把原地恢复样例推广到未经验证的路线 |
| 23 | **U1 web 面生产适配器的形状**：薄转发（web → internal 面），还是自己持有会话与投影？ | 未决（阶段一）：决定 v5 §10.2 事务原则与 §10.3 SSE 对账落在哪一层；已知输入见下文 |
| 24 | U2 执行层 Port 的接口形状 | 未决（阶段二）：决定纪律层怎么被测试。cursor 提案见 `~/codex-reference-archive/cursor/investment-agent-architecture-cursor.md` §3 |
| 25 | U3 **预算账与证据账**落 PG 的表结构与迁移 | 未决（阶段二）：一切并行工作的前置——没有预算闸门就不能 fan-out；已知输入见下文 |
| 26 | U4 `AgentProfile` 的具体字段 | 未决（阶段二）：专用部分的载体；已知输入见下文 |
| 27 | U5 外部 harness 的部署形态（服务端如何管理其进程与凭据） | 未决（阶段二）：影响 U2。本分支提案见同一可行性文 §2 / §9 |
| 28 | **⑥ 确认的回执强度为零**：全流程唯一不可逆的一步，其回执恰恰最不可验证（`rulings.md` `R2`） | 未决；原记于 handoff「不能倒退的两条」 |

#### U1、U3、U4 的已知输入

（原 handoff「未决项」，2026-08-29。）

##### U1 的已知输入

- 规则 **I1**：接口分面共享 application 用例，不是三套应用层
- 规则 **I4**：Next.js 可做同源 BFF / session 边界，但不得拥有领域数据
- 规则 **I5**：授权分工必须有显式契约；**不信任任何上游声明的身份**
- 两扇门的身份不同：internal 面认服务令牌 + `X-Delegated-Actor-ID` 头声明的用户；
  web 面**不能信浏览器的声明**，必须从会话取
- 现成参照：`ReferenceWebInteractionAdapter` 的 `_authorize`

##### U3 的已知输入

- 现有 `RunBudget` 在 `domain/agent/runtime.py`，是**内存态 pydantic model**，
  随 graph state 传递，进程一死即失——**载体要换，不是接线**
- 唯一消费者 `first_m1_graph` 只被 `scripts/agent_golden.py` 与一个 golden 测试用到
- 生产链路 `pilot_service` 只有一行 `budget_exceeded → failed` 状态映射
- 字段可沿用：steps / tool_calls / llm_calls / input_tokens 的上限与已用量

##### U4 的已知输入

- `AgentProfile` 已存在于 `domain/agent/profiles.py`，已有两个实例
  （`default_research`、`literature_review`）
- **但 Profile 目前不生效**：`RunService.create_run` 解析并把 key/version 写进
  run 行，`dispatch_agent_graph` 只传 run_id / user_input / security_context，
  两条生产图对 `allowed_tools` 等的引用数为 0。**它现在是审计字段，不是约束**
- `mooc-manus-langgraph-longterm-plan-v4.md` §20 有一份 102 行的结构可作输入

### 7.7 需要改内核时，提交明确的修订工作单元

> 依据的通用规范：[SDD「修改已冻结的契约」](../../dev-agent-standards/deliverables/sdd/sdd-rules.md)

开发投影表达不了的能力，先证明是内核缺口，不能在 Profile、Adapter 或文档里偷加语义。
工作单元至少写清：

| 项 | 要交代什么 |
| --- | --- |
| 原始请求与证据 | 谁提的、原话、可复核的缺口或拒收用例，不只写“感觉不够用” |
| 改与不改 | 具体定义块、字段、F/AT/I 编号；状态、合法边、终态、幂等/租约哪些保持不变 |
| 影响 | 前端、后端、执行器、验收器分别要改什么，不改会怎样 |
| 迁移与回滚 | schema 版本、读写兼容、活动对象处理和退出条件 |
| 验收 | 原有用例集、必要新增用例、一条可复现实验 |
| 旧语义的处置 | 原先是什么意思、为何不够、谁依赖它；保留判断被改动的理由 |

新增字段以带 schema 版本的可选字段引入；旧数据标“旧格式”，**不回填为无法证明的新语义**。
例如 `consumed_at` 只证明 Interaction 被消费，不能批量改写成“人已批准”。
新写入方不得回写旧版本语义；双读期按版本分别统计；活动旧对象归零后再退出旧写入方，
历史读取保留到展示和审计需求结束。具体迁移仍由产品合同修订批准，不因本节而自动生效。

## 13. 词汇对照

本表是阅读辅助；产品对象的精确定义与合法边仍归现行合同，**不另立一套产品状态机**。
读流程时尤其区分：Attempt 完成表示执行结束，Task 成功还要求冻结验收与交付条件成立。

| 内核用语 | 本文对应物 |
| --- | --- |
| Submission | 原始请求来源；人直接提出时由人冻结请求与验收（[§3.1](../components/backend/components/02-intake/agent-dev-guide.md)） |
| Task | 一件有边界的开发工作及其冻结契约（[§2.4](../components/backend/composition/agent-dev-guide.md)） |
| Attempt | 一次实施、候选或修复轮次（[§3.3](../components/backend/composition/agent-dev-guide.md)） |
| Work Unit | 派出的子工作单元；**不是产品子 Task** |
| Artifact | 代码、补丁、报告、测试输出、证据（[§3.6](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| Interaction | 向 principal 的澄清或批准请求（[§4.3](../components/backend/components/05-interrupt-resume/agent-dev-guide.md)） |
| Event | 只追加的事实记录，状态由其投影；可包含改判与证据引用（[§5.7](../components/backend/components/06-acceptance-commit/agent-dev-guide.md)） |
| Side Effect | 对外部世界产生作用的动作及其持久意图/回执/补偿；不可逆部分受 H5 控制（[§4.5](../components/backend/composition/agent-dev-guide.md)） |
| Task Profile | 这类任务的输入、输出、验收、证据和策略契约，如 dev.change/1（[§2.3](../components/backend/composition/agent-dev-guide.md)） |
| Agent Profile | 执行器的能力、调用方式、粒度与边界；不是业务主档（[§2.3](../components/backend/composition/agent-dev-guide.md)） |
| principal / requester | 持有某项决定权的主体 / 提出请求的主体；身份与执行器分开（[§4.1](../components/backend/composition/agent-dev-guide.md)） |
| harness / executor adapter | 执行外壳（程序、提示词、工具）/ 将其公开 SDK 接到统一 Port 的适配层（[§2.6](../components/backend/components/04-agent-execution/agent-dev-guide.md)–[§2.8](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| router / orchestrator | 确定性路由 / 状态推进、派发、收集与停止组件，不是自由 Agent 角色（[§2.1](../components/backend/composition/agent-dev-guide.md)） |
| provenance | attested 为可实证归因、reported 为自报、inferred 为推断；具体采信还受覆盖与隔离限制（[§5.2](../components/backend/composition/agent-dev-guide.md)） |
| S / R / 投影 Π | 结构等效 / 轨迹等效 / 比较前只丢弃约定私有事件与时间戳（[§5.3](../components/backend/composition/agent-dev-guide.md)） |
| 登记集合 / 自动路由候选集 | 知道某执行器存在 / 已具备获准自动调用与审计能力的子集（[§2.3](../components/backend/composition/agent-dev-guide.md)） |
| 未归因效应 | 外部观察到但找不到对应账目的变更；只记录，不伪造事前 Task（[§6.3](../components/backend/components/02-intake/agent-dev-guide.md)） |
| H1–H8 / T0–T2 / E0–E4 | 权力行 / 风险流程档位 / 证据等级，三个不同维度（[§4.2](../components/backend/composition/agent-dev-guide.md)、[§3.4](../components/backend/composition/agent-dev-guide.md)、[§5.2](../components/backend/composition/agent-dev-guide.md)） |
| Delivery | 最终回复与可重取产物（[§3.5](../components/backend/components/06-acceptance-commit/agent-dev-guide.md)） |
| Handoff | 不再单独维护：进度由任务目录（`thread/`、`composition/`、`components/`）推出，不能倒退的决定写在 [`development-plan.md`](development-plan.md)「不能倒退的决定」；`composition/` 与各 turn 的 `user-message.md` 是**单写者面**（[§7.5](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| 工作区 / worktree | 每个可写执行者的并行隔离工作区（[§3.2](../components/backend/components/04-agent-execution/agent-dev-guide.md)、[§3.6](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| 命名分支 | 一执行者一分支；commit 的**运输通道，不是评审对象**（[§3.9](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| 未提交工作区文件 | 仅本地草稿；**同一工作区同一路径后写覆盖先写**（[§3.7](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| 人的主 checkout | 如 `~/master/<仓>`；**只读参照，不是投稿箱**（[§3.6](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| Attempt 租约 / fencing | **产品侧机制**，语义见内核；**开发侧无等价运行时**，迟到判定靠冻结 commit 与整合方核对（[§3.9](../components/backend/components/04-agent-execution/agent-dev-guide.md)） |
| `dispatch_event` | 人代运行时执行的一次传输动作；**不是权力，是可计数的欠账**（[§5.1](../components/backend/composition/agent-dev-guide.md)） |

### 13.1 与 Codex 的对应

执行这一层向 Codex 看齐：本任务的对象在 Codex 里都有对应，模仿它的机制时先查本表。
事实钉在 Codex `7d6f808b`（2026-08-28），出处路径相对 `~/repo/codex/codex-rs`；**升级钉版必须重核本表，不得沿用结论。**
对象名先不改（合同、各文档与现有代码已在用），语义以本表对齐。研究材料见 `~/codex-reference-archive/`。

| 本任务的对象 | Codex 对应 | 出处 | 差别 |
| --- | --- | --- | --- |
| Submission | `Submission { id, op, parent_turn_id, root_turn_id }`（提交队列） | `protocol/src/protocol.rs:190` | 名称与作用一致 |
| Task（任务节点） | 云端 `Task`：状态 Pending / Ready / Applied / Error，带结果 diff、是否评审、best-of-N 尝试数；本地 `ThreadGoal`：目标、状态（Active / Paused / Blocked / UsageLimited / BudgetLimited / Complete）、token 预算与已用 | `cloud-tasks-client/src/api.rs:25-56`、`protocol/src/protocol.rs:3941-3967` | 云端 Task 最近：持久、多次尝试、结果要「应用」回来；本任务的 Task 另有冻结的验收契约 |
| Attempt（一个 turn） | 云端 `TurnAttempt`：turn_id、第几次尝试、状态、diff、messages；本地 `Turn`：Completed / Interrupted / Failed / InProgress | `cloud-tasks-client/src/api.rs:56-67`、`app-server-protocol/src/protocol/v2/thread_data.rs:355` | 一一对应；best-of-N 就是同一 Task 下多个 Attempt |
| turn 的任务书（`user-message.md`） | `ThreadItem::UserMessage { id, client_id, content: Vec<UserInput> }`；发起 turn 时 `turn/start` 的 `input` | `app-server-protocol/src/protocol/v2/item.rs:236`、`app-server-protocol/src/protocol/v2/turn.rs` | 名称对齐；交回物对应同一 turn 里的 AgentMessage、FileChange 等条目 |
| 执行会话，即任务目录下的 `thread/` | `Thread`（thread-store 持久化） | `app-server-protocol/src/protocol/v2/thread_data.rs:202` | 执行绑定存 thread id，不作 Task 身份 |
| Event | `EventMsg` 事件队列；只追加的 `RolloutItem` / `RolloutLine` | `protocol/src/protocol.rs:1335`、`history/src/lib.rs:96` | 本任务要求落 PostgreSQL、状态由其投影；Codex 落本地文件与 SQLite 元数据 |
| Interaction | 命令执行审批、打补丁审批、权限请求、用户输入、Elicitation 五类请求及对应回复 Op；Guardian 由模型审 | `protocol/src/approvals.rs:245-423`、`protocol/src/request_user_input.rs:55` | Guardian 即 7.4 第 20b 条的 llm-review；⚠ SDK 默认自动批准，不照搬 |
| Side Effect | 执行命令、MCP 工具、打补丁、动态工具的 Begin / End 成对事件（意图与回执） | `protocol/src/protocol.rs:1335` | Codex 无补偿与幂等账 |
| Artifact | `TurnDiff`、FileChange、生成图片；云端 diff 摘要 | `protocol/src/protocol.rs:1335`、`cloud-tasks-client/src/api.rs:107` | 本任务要求不可变、内容哈希 |
| 验收（UAT） | `Op::Review` + `ReviewRequest`、`ReviewTask`、进入 / 退出 review mode | `protocol/src/protocol.rs:3332`、`core/src/tasks/review.rs:45` | review 另起一个任务，恰是「验收 agent 不是执行 agent」 |
| Delivery | 云端 `ApplyStatus`（把 diff 应用回来）、`TurnComplete` 的最终消息 | `cloud-tasks-client/src/api.rs:78` | Codex 最弱：无可重取、无独立重试的通知 |
| 预算账 | `RolloutBudget`：一棵根会话树共享计量与提醒阶梯；`TokenCount` 事件 | `core/src/rollout_budget.rs:18` | 研究结论是事后计量加提醒；本任务要求请求前预留、跨进程正确 |
| 子 Task / 工作单元 | 子 agent 生成、交互、等待、关闭事件；`SubAgentActivity`；agent-graph-store 父子拓扑 | `agent-graph-store/src/lib.rs` | 对应合同第 8 节 |
| 取消、恢复、检查点 | `Interrupt`、`TurnAborted`、`RecoverTurn`、`SuspendTurnAndShutdown`、`Compact`、`ThreadRollback` | `protocol/src/protocol.rs:573` | 本任务要求取消意图先持久化 |
| Task Profile / Agent Profile | agent-roles、协作模式模板、`ThreadSettings` / `TurnSettings`、skills | — | ⚠ 字段未核 |

可以照搬的：best-of-N 尝试、review 另起任务、根会话树共享预算与提醒阶梯、Guardian 式自动审批、`parent_turn_id` / `root_turn_id` 串血缘。
要自建的：交付与重取、四本账的跨进程持久化、副作用补偿；审批不得默认放行。
