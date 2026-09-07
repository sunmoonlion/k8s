# 重构方案：开发框架从「两条路径 + 多重 supervisor」改为「一套状态机、多个 Profile、一张权力表」

> ⚠ **历史档案，不再有规范效力**（`runtime-refact` 轮裁定 `R10`，所有者 2026-09-07）。
> 现行规范是 [`agent-dev-guide.md`](agent-dev-guide.md)；**本文与它冲突时以它为准**。
>
> **降级不等于作废**：本文仍可被引用为**当时的判断与取证**，
> 但不再作为「现在该怎么做」的依据。本文对若干设计的主张已被推翻，
> 逐条见 `agent-dev-guide.md` 的证伪清单一节。

> ⚠ **2026-09-05 取回，供所有者评阅怎么处置。不是现行规范。**
> 架构结论（§3.1「两个 Profile」）已被 `runtime` 轮推翻，现行架构见 `runtime-architecture.md`。
> 本文 §3.13 / §3.4 / §3.6 / §3.7 / §6 的内容已迁入 `runtime-architecture.md` 与
> `implementation-plan.md`，此处保留全文只为便于对照评估。

> 起草：2026-09-05 ｜ 起草者：fable（Claude Fable 5.1，经 Cursor）｜ **提案，不承担规范效力**
>
> 修订记录：
> - 11:30 吸收 opus 评审——补「签名回执的威胁模型与密钥分布」（R1 前置）；§8 第 6 条由行数改为判据锚点。
> - 11:45 吸收 luna 评审与所有者裁定——**确立「只有一套状态机，场景差异只在 Profile」为 P0 并贯彻全文**：
>   删去工单自己的状态集，补状态映射表；权力表加 `eligible_principal` / `enforcement_point` 两列、单列取消、
>   H4 扩为扩权、H7 移出转换表；supervisor 解为 orchestrator(代码) / arbiter / acceptor / approver；
>   Task 状态改为纯推导并新增「git 载体的语义映射」；工作区函数按独占与干净判据重写；
>   迁移映射改为「旧文全部标题 → 新落点」并配枚举脚本；引用清理由 5 处改为 13 个文件 + `doc-gate.py` 配置；
>   路线加 spike、角色冲突检查前移。R0 由 opus 直接修。
> - 12:00 吸收 kimi / qoder 评审与所有者两条裁定——**(a) T0 的 H1 在策略层完成**：T0 的验收条只能取自已签策略里的
>   机械门禁，不允许自定义验收条，因此 T0 开工前零触点与 H1「无默认」不再矛盾；**(b) 信任锚改为「回执仓」**：
>   所有者名下独立仓库，VM 只持只读凭据，不依赖 GitHub ruleset（私有仓 ruleset 需 Pro 及以上，已核官方文档）。
>   另：收件箱字段分级（无默认字段不得预填）；签名 tag message 携带逐条验收结论（内容门）；`ls-remote` 失败 fail-closed；
>   内核按 commit 引用；`independence` 折算首版；凭据检查清单入仓；触点耗时与改动幅度登记为观察值；
>   `human` kind 的四点差异单立一段；§1.2「第四套」改为「第三套的未定义别名」。逐条处置见 `rounds/refact-fable/reviews/`。
> - 12:15 吸收 cursor 评审与所有者裁定——**(a) 所有 `auto_policy = 无` 的权力表行一律回执仓签名回执**（**H7「取消」为表内唯一例外**，仍用 `rulings.md`），
>   删 H2 的「或 `rulings.md`」；**(b) T0 验收改为引用命名任务类包**（`paths` + `gates` + `covers`），禁止自拼门禁子集；
>   **(c) R0 / S1 立 `bootstrap` 档**，效力来自本文冻结而非 `policy/1`。另：3.1.1 映射表补 `WAITING → QUEUED` 恢复边与
>   `RECEIVED` / `BUDGET_EXCEEDED` 两行，§8 第 4 条加「边 ⊆ 内核合法转换」且集合比较改对称差；Profile C 删除，
>   协议演化 = 开发 Profile 钉 T2；摘要四词改五词并加 P0 范围限定；观察值加每票签名次数；「可逆出口」登记未决不加。
> - 12:40 吸收五家终审（opus / luna / cursor / kimi / qoder，原文在 `rounds/refact-fable/reviews/`）与所有者两条裁定——
>   **(a) 主仓写权限移出 VM**：agent 只推候选仓，主线 push 由 Windows 在签 H5 的同一会话执行（luna C2 / opus §3）；
>   **(b) §7-12 裁定：往协议补「机器可读块」算改协议，按 T2 开轮**，R0 只修脚本不碰协议正文。
>   另：3.13.1 取证纠错（沙箱 uid 映射致误判 root，见 3.13.0）并新增 §8 第 9 条；回执改为回执仓内自己的签名 commit + yaml
>   （luna C1，跨仓 tag 不成立）；VM 验签用在线公钥集（kimi F1）；T0 拆开工门 / 完工门（cursor F1）；任务类包 `paths`
>   不得覆盖权威文件与门禁脚本（cursor F3 / opus 4.3 / kimi F2）；§8 第 5 条改 T0/T1/T2 = 0/1/2 次（luna C4）；
>   状态与合法边落 `policies/state-machine.toml`（luna D4 / kimi F4 / opus 5.3）；Attempt 执行事件 `events.jsonl` 与
>   `RUNNING` 覆盖声明（luna C5）；`independence` 改两维登记（luna D3 / opus 4.1）；工单 `route_proposal / effective / delta`
>   与 `intake_author`（luna D1 / D2）；禁词表缩到 supervisor 及中文别名（luna D5）；`_probe` 统一 dry-run（opus 5.1）；
>   qoder C3「冻结 §8 是循环依赖」不采纳（冻结判据 ≠ 判据已满足）。逐条处置见 `rounds/refact-fable/reviews/review-final-fable-response.md`。
>
> ~~**引用钉定**：本文凡写「七环节」「流程档位」「⑥ 确认 / ⑦ 清理」，指的都是 `round-protocol.md@protocol-v2`；
> `master` 上仍是六环节（确认 = ⑤、清理 = ⑥）、无档位节。~~
> **本条已于 2026-09-06 失效**：R0 已合并，主线的 `round-protocol.md` 就是七环节带档位的版本。
>
> **冻结状态**：五家终审（`rounds/refact-fable/reviews/review-final-*.md`）于 12:49 全部同意冻结，luna 撤销 REQUEST CHANGES。
> §8 九条、3.1.1 映射表、3.13 威胁模型的冻结记录在 [`rounds/refact-fable/rulings.md`](rounds/refact-fable/rulings.md) R1，
> **以所有者 commit 为生效时刻**（H1 是人的动作；回执仓尚未建成，本次按 bootstrap 例外用 `rulings.md` + commit，见 R2）。
> 冻结后三处只能经 H6 改，其余章节仍可随实施轮修订。
>
> 本文是对 [`working/development-lifecycle-agent.md`](archive/development-lifecycle-agent.md)（1603 行）、
> `working/development-lifecycle-human.md`（823 行）与 [`round-protocol.md`](protocol/round-protocol.md)
> 三者关系的重构方案。它回应项目所有者 2026-09-05 提出的调整思路（HITL、前置路由、
> supervisor 选择、规划→subagent、仓库与 worktree 供给），但**不以那份思路为骨架**；
> 对它的逐条处置见「对原建议的处置」一节。
>
> 取证范围：`working/` 三份、`project-guide/` 总览、`constraints.md`、`development-plan.md`、
> `handoff.md`、`agent-discipline.md`、`ai-dev-readiness/` 五份、`refact-task.md`、
> `protocol-v2` 分支上的 `round-protocol.md` / `round-status.py` / `round-dispatch.py` / `agents.toml`。
> 本文引用它们时按标题，不按章节号（round-protocol「通用纪律」已立此规矩，理由同）。

---

## 0. 一页摘要

现有框架把「开发怎么做」写成了**两条平行路径**（Agent 路径由 FastAPI 建仓，Human 路径由人建仓），
再用「等位原则」声明两条路径后半段同构。结果是约两千行重复、三套同名 supervisor、
人的权力与流程步骤混写在一起，以及一个只能靠人声明、命令判不了的环节（⑥ 确认）。

本文提出的替代结构只有三句话：

1. **一套状态机，两个 Profile。**`request-lifecycle.md` 定义的 Task / Attempt 状态机就是唯一的状态机；
   开发过程与产品运行时是它在两个 **Profile** 下的运行——Profile 只定义
   转换门禁（guard）、必需产物和 interrupt 策略，**不新增任何状态词，也不走内核没有的转换边**。
   P0 约束的是状态词与转换边；**不宣称 git 载体具备内核的并发语义**（事务、租约、fencing 只有 PostgreSQL 载体能验，见 3.11）。
   开发 Profile 的持久层是 **git**，产品 Profile 的持久层是 **PostgreSQL**；执行者一边是四家 CLI，一边是 SDK。
   本协议自身的演化不是第三个 Profile，是开发 Profile 上 `tier = T2` 钉死的工单。
   round-protocol 已经证明开发 Profile 能跑（2026-09-04 refact 轮），它就是这套状态机的第一个实现。
2. **人是一种执行者，不是一条路径。**执行者有三种 kind：`agent-cli`、`agent-sdk`、`human`。
   人与 agent 走同一套「收固定指令 → 从产物定位 → 读落盘通知 → 在自己的可写面产出 → 按 commit 冻结」。
   差别只在**通道**（人通过收件箱被叫到）和**持有的权力**（一张表，见下）。
   某一步是否 interrupt，不由执行者 kind 决定，由「当前转换 + Profile + 权力表 + 当前执行者持有的权力」决定。
3. **权力表决定 interrupt 点，不是流程图上手画。**哪些状态转换需要特定 principal 的批准，
   写成一张不超过十行的表，每行注明**在哪里强制**；引擎遇到这些转换就产生 `WAITING(APPROVAL)` 并等待，
   其余按版本化默认策略走。所有者思路里的「interrupt 由人裁定、可设默认」由此自动导出，且**每个默认都可审计**。

在此之上，五件工程化的事：**路由三值化**（decide / ask / refuse，模型只建议）、**工单作为冻结 Artifact + 单次开工确认**
（把三次前置 interrupt 合成一次）、**工作区供给写成纯函数**（独占 × 干净 × 写者数 × 是否需人读）、
**人的确认也是产物**（锚在 VM 只读的回执仓里的签名回执，让 ⑥ 从「命令判不了」变成可判；主仓写权限移出 VM，让 H5 从审计点变成强制点），以及
**supervisor 解体**为五个各有定义的词：router 与 orchestrator 是代码，arbiter、acceptor、approver 才是角色。

文档形态随之从「两份 lifecycle」变为「内核一份 + 权力表一节 + 执行架构一份 + 档位 Profile」，
旧→新映射按旧文**全部标题**逐条给出并由脚本检查零缺口，见「文档重构」一节。

---

## 1. 诊断：现状的六个结构问题

以下每条都能在现有文档里找到自证，不是外部批评。

### 1.1 「两条路径」是假分叉

现文《两条同构路径》一节承认「入口差异到『可写工作区已经准备好』为止；后面的 supervisor 内核同构」。
`automation-roadmap.md`「三步推导」进一步指出：四家助手全部 CLI 化之后，**入口差异也消失了**。
于是两条路径的差异只剩「谁按了回车」——这不足以支撑两份文档。

### 1.2 supervisor 已有三套同名物，第三套还有一个未定义的别名

现文《两层监督职责与等位原则》消歧了「调度监督器 / 执行监督 Agent / 产品侧拆子 Task」三套，
并规定未加前缀的 supervisor 专指执行监督 Agent。round-protocol 的「轮次组织者」按此可读作第三套在 T2 里的别名
（qoder 评审指出这一点，采纳）；但 `rounds/refact/round.md` U2 之所以仍记为未决，是 round-protocol 从未定义这个角色的
职责边界，只借了名字。每加一层就加一个名字，说明抽象层级选错了：
真正稳定的概念不是「谁监督谁」，而是**「这个状态转换由谁执行、需要什么权力、在哪里强制」**。

### 1.3 权力与流程混写

现文 §9「权限、预算与副作用」列出「只有有权主体能做」的七类动作，散布在 1600 行流程叙述中；
human 版 §2–§9 又写了一遍。`automation-roadmap.md` 已给出正确形状——「一份流程 + 一节人独有的权力」——
但没有说**权力表如何驱动流程**。不驱动，它就只是另一份要人记得读的文字。

### 1.4 一个环节判不了

`round-status.py` 对 ⑥ 确认写的是 `done: None`——「人的动作，不可由命令判定」。
这与协议自己的原则（「状态不记在任何声明里」「判据一律是命令，对照 git 提交」）直接矛盾。
只要人的确认不是产物，整条状态机就有一个必须靠人说话的洞，而全自动化正好卡在这个洞上。

### 1.5 执行架构与开发流程装在同一份文件里

现文 §4.5–§4.11、§8.1、§9.1–§9.2 约 500 行是**产品执行层架构**：Codex/Harness SDK 能力矩阵、
双 runtime 部署与恢复、OpenClaw 取舍、审批四档与凭据边界。它们的读者是实现 investment-app 的人，
不是「接一个开发任务」的执行者。现文 §11.2 删除条件第 4 条已承认这块「已先迁入长期真源」才能删——
说明作者也知道它放错了地方，只是当时没有落点。

### 1.6 档位只有 T2 有正文

round-protocol「流程档位」定义了 T0/T1/T2，但七环节正文「只适用 T2」，T0/T1 各一行。
`ai-pipeline.md`「出题方与答题方必须分离」指出缺口：「缺的是把它从大轮次下沉到日常任务」。
没有 T0/T1 的可执行形态，日常任务就会绕过整套纪律——正是 2026-09-03 失败整合的形态（中途降档）。

---

## 2. 设计原则

六条，全部取自本仓已成文的判断或所有者裁定，本文只是把它们当成设计约束一致地用到底：

| # | 原则 | 出处 |
| --- | --- | --- |
| **P0** | **只有一套状态机（Task / Attempt），场景差异只体现在 Profile 的 guard、必需产物与 interrupt 策略；任何场景不得新增状态词** | 所有者裁定 2026-09-05；`request-lifecycle.md`「核心对象」Task Profile 行「不另造状态机」、「Profile、Artifact 与扩展」「不修改通用状态语义」、反模式表「Profile 修改通用状态机 → 新领域产生第二套生命周期」 |
| P1 | **同一事实只有一个权威写入面**；两份同构文档即两个真源 | 产品 I13；round-protocol「本轮定义」 |
| P2 | **状态从产物反推，不从声明读取**；人的动作也不例外 | round-protocol「收到『继续』时怎么办」 |
| P3 | **方向不对称**：朝严谨可自裁，朝省事须人确认；默认值属于省事方向 | round-protocol「裁量权」 |
| P4 | **判据必须声明覆盖范围**；覆盖不全比没有更危险 | round-protocol「判据自身的质量」 |
| P5 | **凡能落成代码、测试或门禁的纪律必须落成**；文字只描述意图 | 现文 §11.1 第 2 条；constraints「保证这些被遵守的三层」 |

两条推论：

- **一个只能靠人转述的环节等于没有环节**（P2 + P5）。它决定了本文对 interrupt 的全部设计。
- **P0 的适用层级是 Task 与 Attempt。**Artifact、Interaction 等对象各有自己的小生命周期
  （现文《候选状态机》的 `DRAFT → FROZEN → … → PUBLISHED`；内核的 `consumed_at`），
  那些不是「第二套状态机」，而是对象属性，并且同样跨场景共用、不得按场景另造。

---

## 3. 目标架构

### 3.1 一套状态机，两个 Profile

```text
                        ┌──────── 唯一状态机（request-lifecycle.md「两层状态机」）────────┐
                        │ Task:    RECEIVED → VALIDATING → QUEUED → RUNNING ⇄ WAITING          │
                        │                     → SUCCEEDED | FAILED | CANCELLED | REJECTED     │
                        │ Attempt: CREATED → RUNNING ⇄ WAITING                                │
                        │                     → COMPLETED | FAILED | CANCELLED | BUDGET_EXCEEDED│
                        │ 对象:    Interaction · Artifact · Event · Side Effect · Delivery     │
                        │ 合法边:  见其「合法转换」表；WAITING 只能回 VALIDATING / QUEUED 或终止  │
                        └──────────────────────────────────────────────────────────────────────┘
                                 ▲                                    ▲
   Profile A：开发（现在就在跑）                      Profile B：产品 agent 运行时（目标态）
   持久层    git（commit / tag / 落盘文件 / 回执仓）    PostgreSQL + 对象存储
   执行者    agent-cli × 4 + human                     agent-sdk（Codex 腿 / Harness 腿）+ human
   通道      agents.toml argv / 收件箱文件              AgentExecutorPort / Interaction+token
   guard     档位 T0/T1/T2 的环节表                     TaskRouter 的路由表
   必需产物  工单、候选、评审、裁决、验收                 输入、结果、证据、副作用回执
   状态判定  round-status.py（从产物反推）               Event 投影（I4）
```

原 11:45 版画了第三个 Profile「本协议自身的演化」，cursor 评审指出它与 A 五格全同、只差 guard 钉死 T2——那是
A 上的一个档位，不是 Profile；按场景另造同构 Profile 与按场景另造状态词是同一类膨胀。删去。
协议演化 = 开发 Profile 的工单 + `tier = T2`（改协议命中「不可逆 / 权威层」，按档位判据本就是 T2）。

**Profile 不新增状态词，也不走内核没有的边。**这不是类比，是要求：开发 Profile 的每个环节、每份产物、每种异常，
都要能说出它是唯一状态机里的哪个状态或哪个对象，每次状态变化都要是内核「合法转换」表里的一条边。
下表就是这份映射，也是 R1 之前要先冻结的东西；**内核每个 Task / Attempt 状态各占一行，不允许缺行**（cursor D2）。

#### 3.1.1 开发 Profile → 唯一状态机 的映射

| 开发 Profile 里的东西 | 在唯一状态机里是什么 |
| --- | --- |
| 工单文件被创建（`rounds/<id>/` 出现） | Task `RECEIVED`；**空转**：文件落盘成功即 `RECEIVED → VALIDATING`，不停留 |
| 工单 `DRAFT` / `FROZEN`（原 round.md 起草与冻结） | **Artifact 状态**（沿用《候选状态机》的词）；此时 Task = `VALIDATING` |
| H1 / H2 等人（T1/T2） | Task `WAITING(APPROVAL)`；回执成立 → `WAITING → VALIDATING`（验证阶段的等待回 `VALIDATING`）→ `QUEUED` |
| 路由 `refuse` | Task `VALIDATING → REJECTED` |
| 原 `status: ACTIVE` | 不是状态。Task 在 `QUEUED / RUNNING / WAITING` 之一，由产物推导 |
| 原 `status: DONE` | Task `SUCCEEDED` |
| 原 `status: ABORTED` | 按原因：`REJECTED`（不受理）/ `FAILED`（无获准成功路径）/ `CANCELLED`（有权主体终止） |
| 分发脚本已写 `call-<环节>.md`、执行者尚未开工 | Task `QUEUED`；该组 Attempt `CREATED` |
| 七环节 ①–⑤ | Task `RUNNING`；每环节 = 一组 Attempt（每参与方一个），环节完成 = 该组 Attempt 全部 `COMPLETED` |
| 环节内某家交付 | 该家 Attempt `COMPLETED`（产出候选，不等于 Task 成功） |
| 某家逾期 / 弃权 | 该家 Attempt `FAILED(failure_code=timeout)` 或未 `CREATED`；Task 不因此失败（I8） |
| 某家用尽观察窗 / 回退次数 | 该家 Attempt `BUDGET_EXCEEDED`（Attempt 终态）；Task 按内核第 7 条进 `WAITING(APPROVAL)`（H4 追加）或重新 `QUEUED` |
| 中途 H3 / H4 / H6 等人 | Task `WAITING(APPROVAL)`；回执成立 → **`WAITING → QUEUED`**（执行阶段的等待先回 `QUEUED`，Attempt 获租约再 `RUNNING`） |
| H7 取消 | Task `WAITING → CANCELLED` 或 `RUNNING → CANCELLED`；在跑的 Attempt `CANCELLED` |
| ④⑤⑥ 回到 ③ | 新 Attempt；旧 Attempt 终态不重开（I5） |
| ⑥ 确认（人未回执） | Task `WAITING(APPROVAL)`，Interaction = 收件箱条目 |
| ⑥ 回执成立 | **`WAITING → QUEUED`**（内核规定的恢复边，不是直达 `SUCCEEDED`） |
| ⑦ 清理与发布 | 一个 orchestrator Attempt：`CREATED → RUNNING → COMPLETED`；其 Side Effect（写共享最终路径、push 主线）过 H5 门后，Task **`RUNNING → SUCCEEDED`** |
| 无获准成功路径（全部候选被否且不再开新 Attempt） | Task `RUNNING → FAILED` |
| 候选 `STALE` / `SUPERSEDED` | Artifact 状态，不是 Task/Attempt 状态 |
| 档位 T0 / T1 / T2 | 同一状态机上的 **guard 表 + 必需产物表 + interrupt 策略**，见「工单」一节 |
| H1–H7 | 特定转换上的 guard；命中即产生 `WAITING(APPROVAL)` |

映射表里没有一个新词、没有一条内核之外的边、内核每个状态都有落点，这三件合起来才是 P0 的验收方式（§8 第 4 条）。
cursor D1 指出 11:45 版 ⑥→⑦ 隐含 `WAITING → SUCCEEDED`——内核没有这条边，只查词表抓不到，所以边也进判据。

**中途 H 视为全 Task 暂停**（cursor 终审残留 1）：H3/H4/H6 改的是所有 Attempt 共用的预算、环节或验收条，所以命中权力表的中途 H
让 Task 进 `WAITING(APPROVAL)`、在跑的 Attempt 进 `WAITING`；不按内核「有一路可推进则保持 RUNNING」处理。这是开发 Profile 的 guard 选择，不改内核语义。

**`RUNNING` 目前判不了，如实声明**（luna C5）：git 产物只能证明「已分发」（`call-<环节>.md`）与「已交付」（commit）；缺交付可能是
未调用、在跑、崩了没产物、机器失联、观察窗超时五种之一，`round-status.py` 区分不了。处置两步：
① orchestrator **单写**结构化执行事件 `rounds/<id>/events.jsonl`（`attempt-created / dispatched / started / finished / timeout / cancelled`，
每条带 `attempt_id / actor / input_commit / ts / observation_window`），分发脚本包一层即可产生 `started` / `finished`；
② 事件文件落地之前，脚本的覆盖声明把 `QUEUED` 与 `RUNNING` 合并显示为「已分发未交付」并标 ⚠ 不可判，§8 第 3 条不要求区分这两态。
事件文件在 agent 可写面，所以它是**投影不是权威**（3.11）；权威仍是 commit。

**Attempt 的产物类型，显式声明不静默扩充**（luna C5 第二点）：内核 Attempt 是「为完成 Task 发起的一次执行」；开发 Profile 把评审、裁决、
验收各家的交付也叫 Attempt，其产物是候选之外的 typed Artifact（`review / ruling / acceptance`）。本文选择「Attempt 可产出 typed Artifact」而非
「每环节一个 child Task」，理由是后者会让 T2 一轮生成七个 Task、状态推导复杂度翻倍。这是对 Attempt **产物类型**的细化，不改 Attempt 状态与边；
R5 的内核边界声明修订里显式写一句「Attempt 的产物是 Artifact，类型由 Profile 定义」，若内核维护者认为这是扩充，按 3.1 规则②走 T2。

`request-lifecycle.md` 在这个结构里是内核定义，**对象与状态不动**；要动的只有边界声明：
它「规范边界与条款筛选」一节已写「开发字段只能进入**开发 Profile** 或 development-lifecycle-agent.md」——
开发 Profile 这个位置它自己预留了；删除 lifecycle 两文时，把那句和另外两处引用改指 `lifecycle.md`，
并加一句「本文的对象与状态机是通用内核，开发 Profile 见 lifecycle.md」。按其「修订纪律」走一个规范修订工作单元，并入 R5。

**内核按 commit 引用，防双向耦合**（kimi D4，采纳）：`request-lifecycle.md` 是持续演化的产品真源，开发 Profile 若跟随其 HEAD，
产品侧每次改内核都会反向冲击开发流程文档与脚本——这是 1.1 批评的「两个真源」换形态复活。规则三条：
① `lifecycle.md` 与上表注明所引用的 `request-lifecycle.md` commit；② 内核对象名 / 状态名的任何修改按 T2；
③ 内核修改后必须重跑 §8 第 4 条（状态词集合比对），两个 Profile 都过才算合并。

这样做的直接收益是 U3 那条方法论：**「先在这一层跑通，再往下实现」**——但要说准跑通的是什么：
产品 Profile 要建的**对象形状、状态转换、Interaction 形状、验收器职责**，先在 git 载体上以文件和脚本跑过一遍；
git 载体**验证不了**事务性、租约与 fencing（见「git 载体的语义映射」），那三样只有 PostgreSQL 载体能验。

### 3.2 执行者模型：三种 kind，一张登记表

```toml
# 示意；agents.toml 的扩展形态
[luna]
kind          = "agent-cli"
provider      = "openai"             # 模型供应商
runtime       = "codex-cli"          # 执行 harness（二进制 + 提示词 + 工具集）
model_family  = "gpt-5.6"
roles_allowed = ["proposer", "acceptor"]
worktree      = "{home}/worktrees/luna/k8s"
argv          = [...]

[kimi]
kind          = "agent-cli"
provider      = "moonshot"
runtime       = "codex-cli"          # 与 luna 同一 harness、不同模型——单值 independence 判不了这对（opus 4.1）
model_family  = "kimi-k3"
roles_allowed = ["proposer", "acceptor"]

[opus]
kind          = "agent-cli"
provider      = "anthropic"
runtime       = "claude-code"
roles_allowed = ["arbiter", "acceptor"]   # 不参赛
...

[owner]
kind          = "human"
channel       = "inbox"              # 收件箱文件 + 回执仓签名回执
principal     = "owner"              # 权力表 eligible_principal 列引用的是这个名字，不是 kind
```

四点设计：

- **`human` 与 agent 在登记表里是同一类条目。**分发脚本对人的动作不再特殊处理：轮到人时，
  往人的收件箱落一份通知（与 `call-<环节>.md` 同构），人的回执是 commit 或回执仓里的签名回执。
  现在由人手工粘贴「继续」的那条欠账（`rounds/refact/round.md`「待自动化」）就此转为 orchestrator 的动作。
- **权力挂在 principal 上，不挂在 kind 上。**现在只有一个 principal（`owner`）持有全部权力，
  但权力表引用的是 principal 名，将来多用户、多仓或产品审批时只加 principal 与授权行，不改表结构。
  本轮**不**引入 capability 体系——只有一个 principal 时那是空列。
- **独立性按两维登记，不用单值。**U2 已指出「同源 subagent 的『一致』信息量低得多」。12:15 版用单值
  `independence = "cross-vendor"`，luna D3 / opus 4.1 指出两处错：「cross-vendor」是两个执行者**之间的关系**，不是成员共享的组名，
  按字面分组所有 cross-vendor 反而落同一组；且 luna 与 kimi 共用 `codex-cli` harness、模型不同，单值判不了这对。
  改为登记 `provider` / `runtime` / `model_family` 三个事实字段，独立性由算法从字段推导。
  **折算首版**（kimi D6 / qoder D6：允许粗糙，不允许缺席）：分组键 = `runtime`（同一 harness 的提示词与工具集相同，相关性最高）；
  独立信号数 = 持相同主张的执行者所属不同组的个数（同组 N 家只计 1）；组内任一家带 `file:line` 或可复跑命令取证，该组权重 ×2；
  裁决时先比独立信号数，相同则比带取证的组数。一家独立带取证（1×2）胜过三家同 runtime 无取证（1×1）。
  ⚠ 未验证：同 runtime 不同模型的相关性到底多高，要等「候选相似度」观测值；分组键届时可能改为 `(runtime, model_family)`。
  本表随 R3 进 `authority.md`，修改按 T2。产品 Profile 里 Harness 派生的多个专业 agent 同 runtime。
  评审之间若有引用关系（本轮 qoder 稿明引 kimi 稿），引用方在被引条目上视同同组——这是本票 evidence graph 上的关系，不改静态登记。
- **`roles_allowed` 由登记表约束，不由每轮口头指定。**round-protocol「角色分离」的禁令
  （裁决方不提案、验收方不得是基座作者）在分发时就能机械拦截。

**`kind = human` 的四点差异，单立一段而不另立一条路径**（qoder B3，部分采纳）。human 版 lifecycle 列的四处
「真实差异」在本结构里各有落点，`executor-architecture.md` 给 `human` 条目写一小节把它们指出来，
让人不必回内核文档才知道自己的地位：

| human 版列的差异 | 在本结构里是什么 |
| --- | --- |
| 有批准权 | `principal = owner` 持有权力表全部行；不是 kind 的属性 |
| 可裁量「不值得走全流程」 | H3（省事方向裁定）+ H6（推翻裁定）；裁量是权力表的行，不是表外自由 |
| 承担最终责任 | `authority.md` 治理条款：H5 签名者即对外责任人 |
| 可跨会话续接 | human 的 Attempt 无 checkpoint 义务，`handoff.md` 就是它的 checkpoint；但**不落盘的意图不是状态**（P2），别人接不上的记忆不受框架保护 |

不采纳「恢复人路径自足」：那正是 1.1 诊断要删的东西。

### 3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源

下表取代现文 §9 散布的「只有有权主体能做」清单与 human 版 §3，并且**不只是文字**：
`enforcement_point` 列写明每一行在哪里被强制——脚本、hook、还是 VM 无写权限的回执仓。没有强制点的行不许进表。

引擎（开发 Profile 里是 orchestrator 脚本，产品 Profile 里是 TaskRouter）在遇到左列转换时，
必须产生 Interaction 并停在 `WAITING(APPROVAL)`，直到出现 `eligible_principal` 的回执。

| # | 状态转换（唯一状态机的词） | 为什么需要批准 | eligible_principal | auto_policy | 回执形态（开发 Profile） | enforcement_point |
| --- | --- | --- | --- | --- | --- | --- |
| H1 | 工单 Artifact `DRAFT → FROZEN`（题目与验收标准冻结） | 出题方＝答题方则验收非独立 | `owner` | 无。**T0 例外不是默认**：T0 的 `acceptance` 只能引用 `policies/tier-defaults.toml` 里一个已签的**任务类包**，H1 已在策略签名时一次完成（3.6） | 回执仓签名回执 `transitions: [H1]`，`target_commit` = 工单 commit；T0 为策略回执 `policy/<n>` | `round-status.py` 查回执仓；T0 **开工门**只查包名 ∈ 已签策略（diff 此时不存在，见 3.6 两道门） |
| H2 | Task `VALIDATING → QUEUED`（开工确认：路由、档位、执行者、工作区计划） | 唯一一次把「AI 复述的理解」与人的意图对齐 | `owner` | **有**：T0 且路由 `decide` 时按 `policies/tier-defaults.toml` 自动放行，落 `RouteDecision` | 回执仓签名回执（T1 与 H1 同一份，`transitions: [H1, H2]`；T2 单独一份 `[H2]`） | `round-dispatch.py`：T1/T2 在回执出现前不分发；T0 + `decide` 在 `RouteDecision` 落账前不分发 |
| H3 | 省事方向裁定（降档、跳环节、缩观察窗、免除某家） | 自动化默认漂移方向永远是省事 | `owner` | 无 | 回执仓签名回执 `transitions: [H3]`，`target_commit` = 新增该条 `rulings.md` 行的 commit，带 `ruling_sha256` | `round-status.py` 校验回执存在、target commit 恰好新增该行、哈希与方向字段匹配 |
| H4 | 扩权：追加预算、提高并行度、新增数据 / 工具 / 网络范围 | 预算与范围是 fan-out 的唯一硬上限（产品 I10、I3）；**在 H5 之前就生效，事后追不回** | `owner` | 无 | 同 H3 | 同 H3；产品 Profile 为工具网关 |
| H5 | 不可逆 Side Effect：写共享最终路径、push / 合并主线、删除或迁移已有资产、生产发布（⑥ 确认） | 无法回退 | `owner` | 无 | 回执仓签名回执 `transitions: [H5]`，`target_commit` = 待发布 commit，含逐条验收结论 | **凭据层**：主仓对 VM 只读，agent 发不起主线 push；⑦ 的 push 由 Windows 在同一会话执行，发布前 `--verify-receipt`（便利，非边界）。VM 上的 hook 与脚本**不是**强制点（luna C2 / opus §3） |
| H6 | 推翻任一裁定 / 改判已冻结的验收标准 | 裁定本身是证据，只有更高权力能覆盖；**伪造 H6 可把验收条改窄再骗过 H5 内容门** | `owner` | 无 | 同 H3（`rulings.md` 追加不覆盖 + 回执仓回执） | `round-status.py` 拒绝对已冻结项的原地修改（冻结区逐字节）；H5 内容门比对的验收条集合以**有回执的**最新 H6 为准 |
| H7 | Task → `CANCELLED`（有权主体终止） | 取消要先持久化意图、盘点副作用，不是 agent 可顺手做的 | `owner` | 无 | `rulings.md` 一条，含已产生副作用清单。**表内唯一例外**：伪造取消只停工、不放行任何东西，属失败安全方向，不要求仓外锚 | `round-status.py` 只在裁定存在时判 `CANCELLED` |

**回执形态的统一规则**（cursor C1，采纳）：凡 `auto_policy = 无` 的行，回执一律是回执仓里的签名回执（3.13.3）；**H7「取消」是表内唯一例外**
（伪造取消只停工不放行，失败安全方向；qoder C4 提醒它仍有恢复成本，登记 §7）。`rulings.md` 保留为人读缓存，
但一条 H3/H4/H6 裁定行只有在回执仓存在对应回执时才有效，脚本对没有回执的裁定行视同不存在。
11:45–12:00 版只给 H1/H5 配了仓外锚，H2「或 `rulings.md` 一条」、H3/H4/H6「`rulings.md` 一条」全部可由 agent 独立写出——
规则三说「回执必须不可伪造」，主语是全表，锚却只打了两行。代价是每轮签名次数上升，登记为观察值（3.4）；
压缩次数的正道是**一条 tag 携带多个 transition**（`H2+H3`），不是把某行的锚拿掉。

**「承担最终责任」不在表里。**它不是状态转换，脚本判不了；写进 `authority.md` 的治理条款：
H5 的签名者即对外交付的责任人。

规则三条：

1. **表外无未分类 interrupt。**权力表只管 `WAITING(APPROVAL)`。内核「WAITING 与 Interaction」定义的另外四类
   （`INPUT` / `DEPENDENCY` / `RESOURCE` / `EXTERNAL`）按内核规则产生，不需要进表；但 `INPUT` 类问人
   受内核「解释、边界与完成契约」约束：**只有歧义会实质改变结果、权限、成本或风险时才请求澄清**。
   想让人插手却归不进这五类的，就是执行者在「问人以转移责任」。
2. **默认值是策略版本，不是代码兜底。**H2 的默认必须来自版本化配置，每次按默认跳过都落一条
   `RouteDecision{policy_version, matched_rule}`。理由是现文 §6.9 那条教训：
   「忘了传 handler」与「故意选自动批准」在代码里长得一样，必须显式化。
3. **回执必须是产物且不可伪造。**agent 的 worktree 与人的主 checkout 共享 `.git`，任何 agent 都能写一个
   `author = owner` 的 commit——所以所有 `auto_policy = 无` 的回执（H7 除外）用回执仓里的签名回执，且**判据锚在 agent 进程边界之外的回执仓**
   （VM 对它只读），本地 `git verify-tag` 只作参考显示。回执存在只证明「人做了签名推送动作」，
   所以回执还要过**内容门**：回执文件携带对每条冻结验收条的结论（3.13.4）。
   威胁模型见「签名回执的威胁模型与密钥分布」——**R1 开工前该节必须先冻结**。

### 3.4 人的通道：收件箱 + 回执

```text
sunmoonai/docs/dev-plan/rounds/<id>/inbox-owner.md     ← 引擎写，人读（与 call-<环节>.md 同构）
                                                          每条必备字段：interaction_id、transition、待决内容、截止判据；
                                                          凡产生回执仓回执的条目（H1–H6）另加 target_commit、diff_stat；H1/H5 再加冻结验收条编号表
                                                          （缺任一字段 = 条目无效，round-status.py 机械判）
签名回执（回执仓 main 上的签名 commit + yaml）           ← 人写，引擎读；rulings.md 只是它的人读缓存（H7 例外）
```

**字段分级：无默认的字段不得预填**（kimi D3，采纳——P3 说默认值属省事方向，预填等于把盖章做成阻力最小路径）：

| 分级 | 字段 | 规则 |
| --- | --- | --- |
| 无默认，必须显式填 | 验收条（H1 本身）、executors 名单（含 arbiter / acceptor）、`tier` | 收件箱留空；回执 target_commit 指向的工单里这三项为空即判无回执 |
| 可预填默认 | workspace 计划、预算窗、观察窗规则 | 预填值与人改后的值都落账，改动幅度是观察值 |

「T0 按版本化策略自动放行」与「T1/T2 收件箱预填人盖章」是两回事：前者有 `RouteDecision{policy_version, matched_rule}`
落账，且验收条来自已签策略；后者是默认漂移，禁止。

- 引擎判定「当前转换命中权力表」时，写收件箱并停下（Task `WAITING(APPROVAL)`）；分发脚本对 `kind = human`
  的条目输出的不是 argv，而是通知（终端提示、桌面通知、或将来的 IM）。**通知丢了不要紧，收件箱文件是真源**
  （对应产品 `F-DELIVERY-06`：流式通知不是结果唯一载体）。
- 人的回执**只认落盘**：对话里说「同意」不算，与 round-protocol「异议稿必须冻结提交」同理。
- 人不回执时的处置按 round-protocol「参与方不可用」：H1、H3–H7 等待，**不设超时默认**（最后一道关卡不默认通过）；
  只有 H2 在策略明确允许的 T0 场景可以按默认放行，且要落账。
- **每次 H 回执登记三个观察值**（kimi D7 / qoder D7 / cursor D5，采纳为观察值而非判据）：回执耗时（收件箱落盘 → 回执仓收到 tag）、
  相对预填值的改动项数、**每票签名次数按 H1/H2/H3–H4/H5/H6 分计**。⑦ 清理时汇总进 `rulings.md`，所有者自己看趋势；
  **不**由观测值自动触发 H6——H6 是权力，不是告警。签名次数是 C1 全表锚定的直接代价，T0 的主要摩擦预计在 H5 而不在 H2。

产品 Profile 里这一段的对应物已经全部定义好了：Interaction、`WAITING(APPROVAL)`、`resume_token_hash`、`AT-07`。
开发 Profile 先用文件与 tag 跑通同一形状。

### 3.5 路由：三值决策，模型只建议

现文《两层监督职责》已定死「模型不得决定路线」，本文不改这条，只把它做成可执行形状：

```text
输入：原始请求 + 附件 + 请求者上下文
  │
  ├─ 分类建议（可选；受限模型节点，无工具，固定 schema，低预算）
  │      → { tier_hint, domain_hint, complexity_hint, evidence[] }   ← 只是证据
  │
  └─ 确定性规则表（版本化）
         → decide  : 唯一命中 → RouteDecision{tier, executors, workspace_plan, policy_version, matched_rule}
         → ask     : 零命中或多命中 → 产生 H2 Interaction，收件箱里列候选与各自理由
         → refuse  : 命中拒绝规则（越权、不可受理）→ Task REJECTED，reason code
```

- 三值而不是二值，是为了让「不知道」不被压成「默认通用」——现文明令「不得默认落通用档」。
- 开发 Profile 里 `tier` 就是 T0/T1/T2，判据就是 round-protocol「判据：命中任一条即 T2」那四条
  （不可逆 / 权威层 / 已知对立 / 判据未定）。**分类节点的产出是「四条各自命中与否 + 证据」**，
  规则表据此判 tier；人只在 `ask` 时介入。
- 「专业 vs 通用」在开发 Profile 里对应的是**执行者选择**（哪几家参赛、谁裁决），不是另一条腿；
  产品 Profile 里才是 Codex 腿 / Harness 腿。两者共用 RouteDecision 的形状。
- **OpenClaw 的 gateway 不是这个东西。**现文 §4.11 已核过源码：它按 channel/account binding 确定性映射，
  「两层都不读取用户语义来决定专业领域」。可借的是「确定性 binding + `matchedBy` 落账 + fail-closed」，
  本文照借；不借的是用它的名字来指语义路由。

### 3.6 工单：一个冻结的 Artifact，一次确认

把 round-protocol 的 `round.md` 一般化为**工单**（Work Order）。**工单是 Artifact，不是 Task 状态。**
它只有 Artifact 的两个状态词 `DRAFT → FROZEN`（沿用《候选状态机》），Task 自身的状态由产物推导。任何档位都有工单，字段固定：

```toml
[order]
id, tier                    # tier 只选 guard 表，不是状态
artifact_state              # DRAFT | FROZEN
route_proposal              # 3.5 的输出：模型证据 + 确定性规则结果，含 policy_version（luna D1：建议与决定分开）
route_effective             # T0：= proposal，由策略放行；T1/T2：H2 回执确认后的值
route_delta                 # 人相对 proposal 改了哪些字段；空 = 全盘沿用（这是观察值「改动项数」的来源）
intent_restatement          # 执行者用自己的话复述需求 + 决策点清单 + 标出的歧义
acceptance = [...]          # 逐条编号，冻结后不改；每条尽量指向一个未来的机械检查；T0 为一个包名
frozen_sections = [...]
[executors]
intake_author               # 起草 intent_restatement / acceptance 的执行者（luna D2）：同票禁任 proposer / arbiter / acceptor，分发前机械拦；
                            # T2 的题目与验收条可由 owner 直接提供，此时 intake_author = owner
proposers, arbiter, acceptor, approver
[workspace]
source, baseline_commit, write_actors, review_needed, submodule_plan   # 3.7 的输入
[budget]
observation_window_rule, max_rounds, max_rollbacks
```

**档位 = 三张表，不是三套状态。**每个 tier 在 `round-protocol.md` 里对应：
一张 **guard 表**（哪些转换要过哪些门）、一张**必需产物表**（哪个 Attempt 组要交什么）、一份 **interrupt 策略**
（H2 能否默认）。T2 是现有七环节；T1 是「出稿 → 独立评审 → 验收 → 确认」；T0 是「做 → 独立验收 → 确认」。
三者读同一个工单 schema，脚本按 `tier` 取表。

**T0 的定义收紧：验收条只能来自已签策略里的机械门禁**（所有者裁定 2026-09-05，回应 kimi D2 / qoder B2）。
kimi 与 qoder 同时指出 11:30 版的矛盾：H1「无默认」× 「T0 开工前零触点」× 「T0/T1 一签两用」三者不能同时成立——
H2 默认放行了，工单却因 H1 无人签而停在 `DRAFT`。解法不是给 H1 加默认，而是让 T0 **不产生需要单独冻结的东西**：

- `policies/tier-defaults.toml` 定义若干**命名任务类包**（cursor C2：扁平门禁列表 + 任意子集会被「合法零件架空意图」——
  「修登录失败」配 `[lint, doc-gate]` 脚本全绿、意图为空）。每个包三项：

  ```toml
  [bundle.readiness-docs-typo]
  paths  = ["sunmoonai/docs/ai-dev-readiness/**/*.md"]   # 允许触及的文件（机械判：完工 diff 的文件集 ⊆ paths）
  gates  = ["gates/doc-gate", "gates/link-check"]         # 必须通过的门禁（机械判）；门禁脚本集中在 scripts/gates/
  covers = "仅改 readiness 文档的笔误与链接"               # 人读；策略签名时所有者签的就是这句话

  [bundle.round-scripts-fix]
  paths  = ["sunmoonai/docs/dev-plan/round-*.py"]         # 不含 doc-gate.py、不含 scripts/gates/
  gates  = ["gates/unit:round-scripts", "gates/lint"]
  covers = "仅改已有测试罩住的 round-* 脚本，不新增行为"
  ```

- **包纪律，加在包定义上、由 `check-policy.py` 在策略签名前校验**（cursor F3 / opus 4.3 / kimi F2 三家同点）：
  任何 T0 包的 `paths` 展开集**不得覆盖**权威层文件（`doc-gate.py` 的 `SELF_CONTAINED` 元组、`round-protocol.md`、
  `request-lifecycle.md`、`authority.md`、`lifecycle.md`、本文）、`policies/**`、以及 `scripts/gates/**` 与各 gate 的依赖文件——
  否则「改门禁」与「被门禁判」落在同一可写面，diff ⊆ paths 照样成立。12:15 版示例 `docs/**/*.md` 把 `constraints.md`、
  `round-protocol.md` 全包进去了，`covers` 不判等于没挡；示例已收窄。**宽包不许，多个窄包可以**（qoder C2 的「多放宽松包」不采纳）。
- **两道门，不是一道**（cursor F1：12:15 版把 `diff ⊆ paths` 绑在分发时，而分发时还没有 diff，空集 ⊆ 任何 paths 恒真）：

  | 何时 | 查什么 | 失败则 |
  | --- | --- | --- |
  | **开工门**（H2 / 分发） | 包名 ∈ 已签策略；T0 + `decide` 有 `RouteDecision` 落账；T1/T2 有回执仓回执 | 拒发 |
  | **完工门**（L0 / L1 / H5 前） | 实际 diff 文件集 ⊆ `paths`；`gates` 全过；H5 内容门 | 不进 H5，不判确认 |

- T0 工单的 `acceptance` 必须是**一个包名**，不得自拼门禁子集；
- **不**做 `covers` 与 `intent_restatement` 的字面匹配——自然语言包含判不了。T0 的诚实定义由此是：
  「题目能被『改动限于路径 X、通过门禁 Y』完全表达」；表达不了的就不是 T0，升 T1；跨包的题目**升 T1 而不是塞进宽包**；
- 于是 T0 的 H1 在策略签名时一次完成，不是被默认掉：所有者签的是「这类题目用这组门禁就够」，不是一张可任意挑选的零件清单；
- 包的增删改按 T2（策略修改本就是 T2）；策略文件首版由所有者签 `policy/1`（§7 风险 5）。
- 代价是 T0 口径变窄。这是正确方向：不能机械验收的东西本来就不该全自动。
- **T0 的承诺只是「开工前零触点」**（cursor D5）：它仍是「做 → 独立验收 → 确认」，发布仍要 H5 签名。
  「可逆、不写共享最终路径、免 H5」的出口是一条新的权力表行、属省事方向，本轮不加，登记 §7 未决，有签名次数数据后再定。

**开工确认（H2）**同时完成所有者思路里的四件事：确认路由、确认（或更换）arbiter
与参赛者、确认任务 list 与是否 fan-out、确认仓库与 worktree 计划。收件箱按 3.4 的字段分级呈现：
executors 名单与 tier 留空待人填，workspace 与预算预填默认。这同时也是 `ai-pipeline.md`「意图确认」那一格（AI 复述 + 决策点 + 人确认）。

工单冻结（H1，Artifact 转换）与开工确认（H2，Task 转换）是两个转换，**开工前触点数按档位是 0 / 1 / 2**（luna C4 指出 12:15 版
「T1/T2 恰好一次」与正文矛盾）：T0 = 0（H1 由已签策略承担，H2 按策略放行）；T1 = 1（H1+H2 合并为一份回执）；
T2 = 2（H1 与 H2 分离，因为 T2 的验收标准要在参赛者看到题目之前冻结，而参赛者名单本身可能要人再定）。§8 第 5 条随此改。

### 3.7 工作区供给：纯函数，判据是独占与干净

```text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan) →

  前置判据（任一不成立即新建，不复用）：
    现有工作区 owner == task_id 且 == 该执行者      # 独占
    git status --porcelain 为空                    # 干净；有人的未提交改动时按现文「用户工作树已有脏改动」处理：绕开，不 stash
    HEAD == baseline_commit                        # 基线一致

  数量规则：
    |write_actors| = 0   → 不建可写工作区；单文件 git show 即可，整仓只读时开 detached worktree
    |write_actors| = 1   → 一个独占工作区、一条命名分支
    |write_actors| = N   → 同一 baseline_commit 上 N 个 worktree、N 条命名分支 + 一个整合 worktree
    review_needed        → 额外一个 ~/review/<分支> 检视 worktree，用完删（round-protocol「检视面」）
    submodule_plan       → 多仓时逐仓钉 commit 并记父仓 gitlink（现文《物化步骤》第 3 步；constraints T4）
```

与所有者思路不同的判断：

- **worktree 的数量看写者数，要不要新建看独占与干净，两者都不看复杂度。**现文《命名空间》的判据是
  「同一 Task 出现第二名可写执行者时，supervisor 必须先建好各自的 worktree 和命名分支再派活」；
  luna 补的是「写者数 = 1 也可能撞上别的 Task 或人的脏改动」——所以独占与干净是前置判据。三者都可机械判定，复杂度不可。
- **「事先创建好的仓库」只能是 `source`，不能是工作区。**无仓任务从 `scratch_template@commit` clone 或开独占分支，
  Task 结束按清理策略回收（清理属现文《保留与垃圾回收》，不进本函数）。多个 Task 塞进同一个预建仓违反
  《物化门禁》「workspace 唯一归属本 Task」与《按 Task 塞入材料》「上一 Task 的仓库不得复用给下一 Task」。
- **来源一律钉 commit，不钉地址或分支。**「直接引用仓库地址」「拉取 master」都要落 `baseline_commit`；
  现文反模式表「只固定分支名 → 评审对象漂移」。

### 3.8 状态判定与分发：一般化现有脚本

`round-status.py` 与 `round-dispatch.py` 的设计（从产物反推、判据即命令、只生成不执行）是对的，
要改的全部是「一般化」而非「推翻」：

| 现在 | 改为 | 理由 |
| --- | --- | --- |
| 只认 T2 七环节 | 按工单 `tier` 读取对应 guard 表与必需产物表 | 诊断 1.6 |
| 输出「当前环节」 | 输出**Task 状态（唯一状态机的词）+ 当前环节 + 各 Attempt 状态**；环节是投影，状态是判据 | P0、P2 |
| `round.md` 的 `status` 字段是声明 | 删除，或降为人读缓存并由脚本校验：推导值 ≠ 声明值即报错退出 | luna 第 5 条；P1 |
| ⑥ `done: None` | `git fetch receipts main` 后查该轮 `transitions` 含 H5 的回执：签名 ∈ 在线公钥集、`target_commit` = 待确认 commit、`acceptance` 集合 = 冻结验收条集合，三者同时成立 → 可发布。**fetch / 公钥端点失败（网络 / 凭据 / 超时）一律判未确认（fail-closed）**，退出码区分「查到不存在」与「查询失败」。发布本身由 Windows 执行，脚本在 VM 上只报状态 | 诊断 1.4；P2；kimi D8；3.13 |
| `kind = human` 无处理 | 输出收件箱通知而非 argv | 3.4 |
| 角色由每轮口头指定 | 分发前对照 `roles_allowed` 与《角色分离》禁令，冲突即拒绝并给 reason | 3.2；路线 R3 |
| `rulings.md` 裁定行即生效 | H3/H4/H6 裁定行只在回执仓存在对应回执（`transitions` 含该行、`target_commit` 为新增该行的 commit、`ruling_sha256` 匹配）时生效；无回执的行视同不存在 | 3.3 回执统一规则；cursor C1 |
| 只看工作仓产物 | 加读 `rounds/<id>/events.jsonl`（orchestrator 单写）区分已分发 / 在跑 / 超时；落地前 `QUEUED`/`RUNNING` 合并显示并标 ⚠ | 3.1.1；luna C5 |
| 只判状态词 | 每次状态推导同时输出「上一状态 → 本状态」，边不在内核合法转换表内即报错退出 | 3.1.1；cursor D1 |
| 产物命名与协议正文不一致、toml 键未在协议出现、`--stage 4` 匹配不上、退出码文档与实现不符 | R0 一并修 | 2026-09-05 上午对 `protocol-v2` 的检视意见 |

**每条判定声明覆盖范围**（P4）：脚本输出里，「查了什么、没查什么」与结论并列；零命中要能区分「真的没有」
与「没查到」。

### 3.9 角色：supervisor 解体为五个各有定义的词

「supervisor」在现有文档里同时指四件事，解开后是：

| 词 | 是什么 | 开发 Profile 里的实体 | 产品 Profile 里的实体 |
| --- | --- | --- | --- |
| **router** | 确定性代码：产生 RouteDecision（tier、执行者、工作区计划） | 规则表 + `round-dispatch.py` 的选人逻辑 | TaskRouter |
| **orchestrator** | 确定性代码：推进状态、写环节通知、派发、观测逾期、收集迟到结果、触发回退、供给与回收工作区 | `round-status.py` + `round-dispatch.py` + 运行它们的人（过渡期） | 调度监督器（现文《两层监督职责》） |
| **arbiter** | agent 角色：定基座、逐条吸收、写处置记录、处置异议 | 工单 `arbiter` 字段指向的执行者 | 执行监督 Agent 的「选优整合」部分 |
| **acceptor** | agent 角色：按冻结标准独立验收 | 由处置表算出的一家 | validator |
| **approver** | principal：持有权力表某行的批准权 | `owner` | 有权用户 / 授权角色，经 Interaction |

两条硬约束：

- **router 与 orchestrator 必须是代码，不得是 agent 角色。**这是现文「调度监督器必须是可重放、可解释的确定性代码」
  的直接延续；把 orchestrator 写成 agent，就长出第五个 supervisor。过渡期由人运行脚本，那是「可自动」欠账，不是角色。
- **arbiter 不兼 orchestrator。**round-protocol 现在让「③ 之后的通知由裁决方写、截止由裁决方定」——
  那是把 orchestrator 的活塞给了 arbiter。改为：通知与截止由脚本按工单生成，arbiter 只写裁决与处置。

U2 由此关闭：不需要给「轮次组织者」定名，需要的是用上面五个词替换掉全部「supervisor」及其别名。

### 3.10 开发 Profile ↔ 内核对象对照

这张表是「一套状态机」不是口号的证明：开发 Profile 每个产物都对应一个内核对象，且 Task 状态一律推导。

| 内核对象 | 开发 Profile 载体 | 产品 Profile 载体 |
| --- | --- | --- |
| Task | 工单 `rounds/<id>/round.md`（Artifact）所属的那件事 | `task` 行 |
| Task 状态 | **纯推导**：由 Attempt 产物、裁定记录、受保护 tag 反推（3.1.1 映射表） | `state`（Event 投影） |
| Attempt | 一家在一个环节的一次交付（一个 commit） | `attempt` 行 |
| Interaction | 收件箱条目 + 回执仓签名回执（H7 为 `rulings.md`） | `interaction` 行 + `resume_token` |
| Artifact | 工单、候选、评审、裁决稿、异议、验收稿（按 commit 冻结） | 对象存储 + `artifact` 行 |
| Event | git 提交历史 + `rulings.md` 追加记录 | `event` 行（只追加） |
| Side Effect | 写共享最终路径、push 主线（H5 门） | 副作用账 |
| Delivery | 主线上的最终稿 + 检视 worktree | `F-DELIVERY-*` |
| RouteDecision | 工单 `route_decision` | `route_decision` 行 |
| 预算 | 观察窗规则、轮次上限、回退上限 | 预算账（I10） |

### 3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了

luna 指出 git 不天然提供 `state_version`、CAS、租约与 fencing。开发 Profile 必须说清自己怎么用 git，以及哪些内核性质它**验证不了**。

| 内核要求 | git 载体的落法 | 出处 |
| --- | --- | --- |
| 权威事件 | 工作仓：可从发布点 tag 到达的 commit；人的决定：回执仓 `main` 上的签名回执 commit（VM 只读） | round-protocol「取件：一律按 commit」 |
| branch / tag 是什么 | branch 是运输通道，不是评审对象；tag 仅在受保护模式下是权威引用 | 现文《未提交文件、commit、分支与 worktree 的不同语义》 |
| 比较交换（`state_version`） | 发布用 `--force-with-lease` / 校验目标 ref 仍指向开始时记录的 commit；不一致即失败并新建整合 Attempt | 现文《最终路径的发布协议》 |
| 终态不可重开（I5） | round id 全局不复用；回执仓 main 只追加（VM 无写权限；所有者自律不 force-push，纠错用 `supersedes` 新回执） | round-protocol「本轮定义」；3.13 |
| ref 被重置后的恢复 | 发布点与各家候选打 tag（refact 轮已这么做：`refact/{luna,kimi,cursor,qwen,integration,baseline-master}`） | `rounds/refact/round.md` |
| 工作区文件 | 永不作判据；判据只看提交 | round-protocol「环节判定」 |

**git 载体验证不了的三样，如实登记，不得宣称「已在开发层验过」：**

1. **事务性**——`F-ACCEPT-03` 要求结果、验收、预算结算与终态事件原子提交；git 的多 ref 更新不原子。
2. **租约**——Attempt 的 `lease_owner / lease_expires_at`；开发 Profile 只有观察窗判据，没有可自动拒绝迟到写入的运行时（现文《冻结、迟到结果与取消》已明写）。
3. **fencing**（I14）——过期 worker 的写入被拒；开发 Profile 靠整合方核对候选状态，不靠机制。

所以 U3「先在这一层跑通」的准确表述是：**跑通对象形状、状态转换与交互纪律；并发语义留给 PostgreSQL 载体。**

### 3.12 验证分层：谁判什么

| 层 | 谁 | 判什么 | 判据要求 |
| --- | --- | --- | --- |
| L0 机器门 | pre-commit / CI / `--verify` | 全部机械判据：链接、表格、冻结区逐字节、提交↔处置记录对账、锚点可达、必须零命中的正则、测试、角色冲突 | 声明覆盖范围；首跑先与人工对照再当门禁 |
| L1 独立验收 | `acceptor`（既得利益最小的一家，由处置表算出） | 冻结的验收标准逐条；机器判不了的部分 | 只能按冻结标准；判「标准过期」要写理由交 arbiter |
| L2 来源核对 | 被处置到的各家（异议环节） | 「我的主张有没有被误读」 | 条目 + 为什么错 + 应当是什么 + 可复跑证据 |
| L3 人抽三样 | `approver`（H5 前） | ① 意图是否被正确理解 ② 不可逆部分 ③ 抽样复算证据真实性 | 不逐行读；抽样规则写进工单 |

L3 就是 `ai-pipeline.md`「机器全审 + 人抽检三样」；L2 是 round-protocol「异议：对整合权的唯一制衡」。
顺序不可换：L0 不过不进 L1，L1/L2 不过不叫人。

### 3.13 签名回执的威胁模型与密钥分布

> 2026-09-05 补入，回应 opus 与 luna 评审；12:40 按五家终审重写（取证纠错、回执仓对象模型、发布权移出 VM、验签）。

**要防的三件事**（12:15 版只写了第一件，luna C2 / opus §3 / kimi F1 指出另两件）：

1. **伪造一条肯定的人类回执**（伪造否定回执等于不回执，流程只会停下等，不危险）；
2. **绕过回执直接产生不可逆 Side Effect**（有没有回执是一回事，没回执能不能 push 主线是另一回事）；
3. **签名动作被人的机器上的 agent 代做**（Windows 上的 Cursor 本地 agent 以人的账户运行）。

攻击者模型是**与人共享同一 credential domain、会流畅执行任何命令、不会犹豫的 agent 进程**——不是恶意，是「顺手代劳」。

#### 3.13.0 取证声明（先于事实）

12:15 版 3.13.1 写「本 VM 所有进程都是 root、`/home/zym` 属 root:root」——**错**。opus 与 luna 在同一台机器复核：
`uid=1003(zym)`，四家 CLI 均以 `zym` 运行。错因已查明：起草者（fable，经 Cursor）在 Cursor 沙箱内执行取证命令，
`cat /proc/self/uid_map` 输出 `0 1003 1`——沙箱用 user namespace 把宿主 uid 1003 映射为 0，所以沙箱内一切看起来都是 root。
取证工具自身有边界而未声明，正是 P4 禁止的事。由此立三条规则，也进 §8 第 9 条：

- 取证栏每条注明**主机、执行身份、是否在沙箱 / 容器内**（`hostname; id; cat /proc/self/uid_map`）；
- S1 的权限测试必须以**与生产 agent 完全相同的 OS 用户与进程环境**复跑，不在任何沙箱内；
- 边界的表述写成「agent 与人是否共享 credential domain」，不绑定「是不是 root」这个偶然事实。

#### 3.13.1 现状事实（2026-09-05；宿主身份由 opus / luna 复核，S1 前须按 3.13.0 重跑）

| 事实 | 取证 | 后果 |
| --- | --- | --- |
| 人的 shell、四家 CLI（`codex`、`claude`、`agent`、`qoder`）、vscode-server **全部以同一普通用户 `zym`（uid 1003）运行** | `id` → `uid=1003(zym)`；`ps -eo user,comm \| rg 'codex\|claude'` 全为 `zym`；`stat -c '%U:%G' /home/zym` → `zym:zym`（opus / luna 复核，宿主 shell） | **同 UID 即同权限**：`~/.gnupg`、`~/.ssh/id_rsa`、gpg-agent 套接字、仓内验证脚本、hook，agent 全部可读可改。结论与 12:15 版相同，理由不同 |
| `zym` 同时在 `sudo` 与 `docker` 组 | `id` 输出 `27(sudo),988(docker)`（opus 复核） | `docker` 组等价 root（可挂宿主文件系统）。B 档要成立，agent 专用用户必须**不在**这两个组 |
| 本机**没有 GPG 密钥**；已有 tag 全部未签名 | `gpg --list-secret-keys` 为空；`for-each-ref` 中 `refact/*` 与 `2.0.0` 无签名块 | 从零设计，没有兼容包袱 |
| `~/.ssh/id_rsa` 对 `git@github.com:sunmoonlion/k8s.git` **有写权限** | `git remote -v`；push 历史 | 任何 agent 都能以本机身份 push 分支与 tag 到主仓——这是要防的第二件事 |
| 人的第二台机器是 Windows 工作站（Cursor 客户端，经 Remote-SSH 连本 VM） | 会话资产路径 `c:\Users\zymun\...`；`last` 同一公网 IP | Windows 上**也运行 Cursor 本地 agent**，以人的账户运行；Git Credential Manager 若缓存了 GitHub 推送凭据，它不需要口令就能 push（kimi F1） |

> **在本 VM 上，任何本地验证（`git verify-tag`、读某个 pubkey 文件、跑 `round-status.py`、pre-push hook）都不是边界。**
> agent 能生成一把新钥、把公钥加进任何本地信任列表、改掉验证脚本或 hook、再签一条 tag。
> 「本地判定通过」只能作为**便利的参考显示**，不得作为任何 `auto_policy = 无` 行的强制点。

#### 3.13.2 三道边界都要放在 agent 的 credential domain 之外

| 要防的 | 边界 | 为什么 agent 够不着 | 所有者裁定 |
| --- | --- | --- | --- |
| ① 伪造回执 | **回执仓** `<owner>/receipts`：VM 只持只读 deploy key；回执是仓内自己的**签名 commit**（3.13.3）；VM 验签用的公钥集**在线取自 GitHub 账户端点**（`https://github.com/<owner>.gpg` / `.keys`），不落本地文件 | 写权限与账户端点都不在 VM；本地脚本可被改，但它改不了「回执仓里有没有那条 commit」 | 2026-09-05 采用 |
| ② 绕过回执发布 | **主仓写权限移出 VM**：`sunmoonlion/k8s` 对 VM 只读；agent 候选推到**候选仓** `<machine-user>/k8s-candidates`；⑦ 的主线 push 由 Windows 在签 H5 回执的同一动作里执行 | agent 根本发不起对主仓的写；H5 的强制点与签名点合一。不依赖 branch protection / ruleset（私有仓需 Pro） | **2026-09-05 采用**（luna C2 / opus §3；所有者「移」） |
| ③ 签名被代做 | Windows：gpg-agent `default-cache-ttl 0 / max-cache-ttl 0`；回执仓与主仓的推送**不走** Git Credential Manager，用带口令的专用 SSH key（`IdentitiesOnly yes`，不加进 ssh-agent）；或上 C 档硬件在场 | 每次签名与每次 push 都要人敲一次口令；Windows agent 拿不到 | 采用；C 档为加固 |

可选加固（不是替代）：

| 档 | 内容 | 现状评估 |
| --- | --- | --- |
| **A′. 工作仓 ruleset** | GitHub tag / branch ruleset 限定 `main` 与 `confirm/*` 只许所有者写 | **私有仓 ruleset 与 branch protection 都需 Pro 及以上**（官方文档「About rulesets」，已核）。所有者若在 Pro，可加做 |
| **B. 账户隔离** | 四家 CLI 各自以专用 Unix 用户运行、worktree 归各自用户，agent 用户**不在 `sudo` / `docker` 组** | 12:15 版写「运维改造大：以 root 跑」是基于错误取证。实际四家已是普通用户 `zym`，B 档成本 = 建四个用户 + 改 worktree 归属 + 拆组。仍不是本轮范围，但成本评估要改对（opus 2.2） |
| **C. 硬件在场** | YubiKey 等，签名与 SSH 认证需物理触碰 | 对 ①②③ 都是加强项 |

#### 3.13.3 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag

12:15 版写「在工作仓里 `git tag -s confirm/<id> <commit>` 再 push 到回执仓、回执仓不含工作仓历史、`ls-remote` 读 message」——
luna C1 给了可复跑证据，三处都不成立：annotated tag 指向 git 对象，push 会把被指向 commit 的**全部可达历史**复制进回执仓；
`ls-remote` 只返回 OID，读不到 message；要读 message 必须 fetch tag 对象。改为：

```text
<owner>/receipts（私有；VM 只读 deploy key；Windows 带口令 SSH key 可写）
└── main（只追加；所有者自律不 force-push，纠错用新回执 supersedes 旧回执）
    └── receipts/<work_repo_id>/<round>/<seq>-<transitions>.yaml     # 每份回执 = 一个签名 commit（git commit -S）
        例：receipts/k8s/refact-2/01-H1+H2.yaml
            receipts/k8s/refact-2/02-H3.yaml
            receipts/k8s/refact-2/03-H5.yaml
```

- **每份回执一个签名 commit**，commit 只改动这一个文件；`target_commit` 是 yaml 里的**普通字段**，不是跨仓对象引用，
  回执仓不含工作仓任何对象。
- VM 侧：`git fetch receipts main`（只读）→ 读 yaml → 用在线取得的所有者公钥集验证该 commit 签名 →
  用 `target_commit` 对照本地工作仓对象。三步任一失败、fetch 失败、端点不可达，一律 fail-closed，退出码单列。
- **按 transition 查找靠字段不靠文件名**：脚本扫该轮目录，`transitions` 字段含 `H3` 的即 H3 回执；组合回执
  （`[H1, H2]`、`[H5, H3]`）天然可被每个 transition 各自查到——这解决 cursor F2 的命名空间问题，不需要多重 ref。
- **只增不改**：纠错写新回执并填 `supersedes: <seq>`；旧文件不动，`round-status.py` 取「未被 supersede 的最新」。
- Windows 侧一次回执的动作：填 yaml（收件箱条目已给全字段，人只填结论）→ `git commit -S` → `git push receipts main`。
  可用一个本地脚本把「读收件箱 → 生成 yaml 骨架」自动化；签名与 push 两次口令不自动化。

#### 3.13.4 回执 schema

```yaml
receipt_version: 1
work_repo: sunmoonlion/k8s
round: <id>
transitions: [H1, H2]        # H1 | H2 | H3 | H4 | H5 | H6，可组合；H7（取消）不进回执仓——3.3 表内唯一例外
target_commit: <sha>         # 工作仓 commit；必须等于收件箱条目里列的 commit
                             # H3/H4/H6：是新增该条 rulings.md 行的 commit；脚本校验该 commit 的 diff 恰好新增该行
work_order_digest: <sha256>  # 工单 FROZEN 版本的哈希；H1/H2 必填
ruling_sha256: <sha256>      # H3/H4/H6 必填：裁定行文本哈希，防 rulings.md 事后被改
policy_version: <n>          # H2 记按哪版策略；T0 自动放行不产生回执，只落 RouteDecision
issued_at: <ISO>
expires: <ISO>               # 缺省 = 收件箱条目的截止判据；条目无截止则 issued_at + 24h（kimi F5 / opus 5.2）
                             # 只约束「该回执可用于放行的窗口」；放行发生后不追溯，不因过期回滚
supersedes: <seq>            # 可选；纠错时指向被取代的回执
acceptance:                  # H5 必填：对每条冻结验收条的结论，编号集合必须等于工单 acceptance 的编号集合
  A1: pass
  A2: pass
  A3: waived <理由>          # waived 是省事方向 = 一条 H3；本回执 transitions 必须含 H3，且 rulings.md 有对应行
```

缺字段、字段不匹配、签名不在公钥集、过期、`acceptance` 编号集合与冻结集合不等，一律判「无回执」，不判「可疑」——P4。

`acceptance` 块是**内容门**（qoder D3 + kimi D9）：回执存在只证明「所有者做了签名推送动作」，不证明读过；
把逐条结论写进被签的文件，人至少要对每条验收条各写一个词。它放在回执仓而不放 `rulings.md`，
是因为 `rulings.md` 在工作仓，agent 能写。

#### 3.13.5 两台机器的身份与凭据分布

```text
Windows 工作站（人）                                  VM-0-13-ubuntu（agent × 4 + 人经 SSH，全部 uid 1003 zym）
────────────────────────                              ────────────────────────────────────────────────────
签名私钥（GPG 或 SSH 签名；仅此一份）                  无签名私钥；无所有者账户凭据
  · 口令保护；gpg-agent TTL = 0；或硬件密钥            ~/.ssh/candidates_rw   → <machine-user>/k8s-candidates  读写
GitHub 所有者账户登录态                                ~/.ssh/k8s_ro          → sunmoonlion/k8s              只读
~/.ssh/owner_push（带口令，IdentitiesOnly，不进 agent） ~/.ssh/receipts_ro     → <owner>/receipts             只读
  → sunmoonlion/k8s 主线 push                          原 id_rsa（对主仓可写）：**撤销**
  → <owner>/receipts push
                                                       round-status.py：
回执动作：                                               git fetch receipts main → 读 yaml → 在线公钥集验签
  填 yaml → git commit -S → git push receipts main         → target_commit 对照本地对象 → 成立 / 未确认（fail-closed）
⑦ 发布动作（H5 回执之后，同一会话）：                   round-dispatch.py 与整合方：
  git fetch candidates <整合分支>                          只 push 候选仓；对主仓的 push 在凭据层面不可能
  round-status.py --verify-receipt H5 <sha>              本地 verify 只做参考显示
  git push origin <sha>:master
```

三点必须写进规则：

1. **强制点在凭据层，不在脚本层。**VM 上的 `round-status.py`、hook 可以被改，但改了也发不起对主仓与回执仓的写；
   Windows 上的发布脚本同样可被本地 agent 改，所以发布前的 `--verify-receipt` 也只是便利，真正的门是「push 要人敲口令」。
2. **Windows 上的本地 agent 同样是威胁。**签名口令不缓存、推送 key 不进 ssh-agent、不用 GCM。任一条不满足，③ 就破了。
3. **VM 上不得存在所有者账户的任何凭据**：`scripts/check-no-owner-creds.sh`（kimi D10；修改按 T2）。**它是配置卫生检查，不是边界**
   （qoder C5）——agent 能改它，它防的是人为疏漏。首版覆盖：`~/.ssh/` 全部私钥指纹对照、`~/.git-credentials`、`~/.netrc`、
   `credential.helper`、`~/.config/gh/hosts.yml`、shell rc 中的 `GH_TOKEN` / `GITHUB_TOKEN`、`~/.vscode-server` 凭据存储、
   `~/.docker/config.json`；再对主仓与回执仓各做一次 `git push --dry-run`，**任一成功即失败**。

#### 3.13.6 剩余风险（如实登记）

| 风险 | 说明 | 处置 |
| --- | --- | --- |
| 人被 agent 的输出误导而签了错的 commit | 边界防伪造与绕过，不防误签 | 收件箱 `target_commit` / `diff_stat` 必备（3.4）；`acceptance` 内容门（3.13.4）；L3「人抽三样」最后一道 |
| VM 上的判定代码被改（opus §3） | `round-status.py` / hook 全在 agent 可写面 | 不再是边界：改了也发不起主仓与回执仓的写。判定代码的正确性靠 §8 第 8 条「首跑与人工对照」与 L0 测试，不靠它不可改 |
| GitHub 不可用 | 信任锚与公钥端点都在外部 | 等。⑥ 本来就「不设逾期默认」；fail-closed。第二锚（自托管 bare 仓，所有者机器持写权限）列为可选 |
| 所有者账户被盗 | 超出本文范围 | 2FA；通用实践 |
| 回执仓 / 主仓的 VM 侧 key 漂移成可写 | 配置漂移 | 每轮 ⑦ 用 VM 身份对两仓各 `git push --dry-run`（**统一为 dry-run**，opus 5.1：真 push 一旦成功会永久留下假回执），任一成功即报警停轮 |
| 所有者把可写 key 复制到 VM「图方便」 | 人为绕过 | `check-no-owner-creds.sh` 的 dry-run 项 |
| 候选仓与主仓分离后，人在 Windows 多一步 fetch + push | 摩擦 | 与 H5 签名同一会话，不增触点；耗时进观察值 |
| Windows 本地 agent 在人敲口令的窗口内插入动作 | ③ 的残余 | TTL=0 把窗口缩到单次操作；彻底解决只有 C 档 |

---

## 4. 对原建议的处置

逐条对照所有者 2026-09-05 的思路。「采纳」指进入本文；「改造」指保留意图换形状；「不采纳」给理由。

| 原建议 | 处置 | 说明 |
| --- | --- | --- |
| 人不再是 supervisor，改为 HITL | **采纳** | 落为「人是一种执行者」+ 权力表。比 HITL 更强的一点：interrupt 点由表导出，不手画；且 interrupt 与否由转换 + Profile + 权力决定，不由执行者 kind 决定 |
| supervisor 之前设路由，先意图识别再选通用/专业 | **改造** | 路由三值化。意图识别保留为建议节点，**不得决策**——这是现文已立的硬规则，改它是另一个 T2 |
| 「openclaw 的 gateway 模式」 | **不采纳此命名** | OpenClaw gateway 按 channel binding 路由，不读语义（现文 §4.11 已核源码）。借其 fail-closed 与落账机制即可 |
| 路由后选 supervisor，可 interrupt，可默认 | **采纳并合并** | 并入 H2 单次开工确认。「supervisor」在工单里是 `arbiter` 字段 |
| supervisor 规划 list → 是否 subagent → interrupt 给人选 | **采纳并合并** | 同上，并入 H2。避免三次前置 interrupt 导致「确认退化成盖章」（roadmap 已预警） |
| 有 subagent 必须建 git 仓库 | **采纳** | 等价于 `write_actors ≥ 1 → 必有独占工作区` |
| 用户本轮就是仓库→引用地址；否则用事先创建好的仓库 | **改造** | 预建仓只能是 `source`，每 Task 独占 clone/分支；一律钉 commit |
| 拉取 master | **改造** | 落 `baseline_commit`，不认分支名 |
| worktree：agent 用看复杂度；人用为审核 | **一半采纳** | 人审核的检视 worktree 采纳（协议已有）；agent 侧改为按独占 / 干净 / 写者数判定，不按复杂度 |

---

## 5. 文档重构

### 5.1 目标文件树

```text
sunmoonai/docs/dev-plan/
├── lifecycle.md                  内核流程 + 开发 Profile，人机共用（预计 600–800 行，以合并后为准；行数只是观察值——qoder C6）
│                                 = 现 agent 文 §0.4、§1（合并为一条）、§2–§3、§4.1–§4.4、§5、§6、§7、§8、§10、§12、§13、§14
│                                 + human 文 §10–§18 中不重复的项目实例 + 本文 3.1.1 映射表、3.7、3.11
├── authority.md                  权力表 + 收件箱/回执 + 默认策略规则 + 治理条款（预计 ≈120 行）
│                                 = 本文 3.3–3.4、3.13 + 现 agent 文 §9 前半 + human 文 §2–§9 的授权模型
│                                 + round-protocol「执行者与触发方式」（它讨论的正是权力表的两个轴）
├── executor-architecture.md      产品执行层架构（基本原样迁出）
│                                 = 现 agent 文 §4.5–§4.11、§8.1、§9.1–§9.2、§11.3 未验证清单
├── round-protocol.md             改为 lifecycle 的档位 Profile：T0/T1/T2 各一张 guard 表 + 必需产物表
├── policies/tier-defaults.toml   H2 默认策略 + T0 任务类包（paths / gates / covers；版本化；修改按 T2；首版所有者签 policy/1）
├── policies/state-machine.toml   唯一状态机的机器可读形式：Task / Attempt 的 states 与 edges，头部 source = request-lifecycle.md @ <commit>
│                                 （luna D4 / kimi F4 / opus 5.3：§8 第 4 条比的是这份 schema 与脚本实现，不是全文 rg；它被「按 commit 引用」纪律罩住，不是第二真源）
├── scripts/check-policy.py       策略签名前校验：包 paths 不覆盖权威文件 / policies / scripts/gates；state-machine.toml 的 source commit 与当前引用一致
├── scripts/gates/                全部门禁脚本集中于此，任何 T0 包的 paths 不得覆盖
├── agents.toml                   执行者登记表（含 human 条目、principal、independence、roles_allowed）
├── round-status.py / round-dispatch.py   按 3.8 一般化
├── scripts/check-no-owner-creds.sh       3.13.5 第 3 条的凭据卫生检查（非边界；修改按 T2）
├── doc-gate.py                   SELF_CONTAINED 元组改指新文件；新增禁止词规则：仅 supervisor 及其中文别名（监督器 / 执行监督 / 轮次组织者），
│                                 三份新文档除「词汇对照」小节外零命中；dispatcher / coordinator 等合法组件词**不禁**（luna D5：树里就有 round-dispatch.py）。
│                                 职责唯一性靠 §8 第 1 条与 roles_allowed 只能取已注册角色，不靠禁词
└── working/                      只留 request-lifecycle.md（改边界声明与三处引用）；两份 lifecycle 删除
```

### 5.2 旧 → 新映射：按旧文全部标题，脚本检查零缺口

现文 §11.2 给的映射粒度是「几个大节」，不够。改为：**枚举两份旧文档全部 `##` / `###` 标题，每个标题必须有且只有一个落点**，
落点取值：`lifecycle.md#<标题>` / `authority.md#<标题>` / `executor-architecture.md#<标题>` / `round-protocol.md#<标题>` /
`删除：<理由>`。映射表本身是 R5 的产物 `rounds/<id>/migration-map.md`，由一个脚本生成骨架、检查零缺口，
并进 L0 机器门。行数不再出现在任何判据里。

粗粒度的方向（细表由脚本生成后人填）：

| 旧位置 | 新落点方向 |
| --- | --- |
| agent 文 §0.3 两层监督职责与等位原则 | 删除；由 3.9 五词与 3.10 对照表替代，「等位」不再需要声明 |
| agent 文 §1 两条同构路径 | `lifecycle.md` 一条路径；入口差异一行说明 |
| agent 文 §4.5–§4.11、§8.1、§9.1–§9.2、§11.3 | `executor-architecture.md` 原样迁出 |
| agent 文 §9 有权主体清单 | `authority.md` 权力表 H1–H7 + 治理条款 |
| agent 文 §11.1–§11.2 存续声明与删除条件 | 本节即其执行 |
| human 文 §2–§9 | `authority.md` |
| human 文 §10–§18 | 与 agent 文对应节合并进 `lifecycle.md`，重复部分删 |
| round-protocol 七环节 | 保留为 T2 Profile；`round.md` 字段表改为工单字段（3.6）；`status` 词改为推导 |
| round-protocol「执行者与触发方式」 | 并入 `authority.md` |

### 5.3 删除条件

两份 lifecycle 文档删除前，下列判据全部机械可判：

1. `lifecycle.md` + `authority.md` + `executor-architecture.md` 三份通过 `doc-gate.py`；
2. 引用清理：`rg -l 'development-lifecycle-(agent|human)' .`（`git log` 除外）**零命中**。
   2026-09-05 取证为 **13 个文件**，不是 §11.2 写的 5 处：`AGENTS.md`、`request-lifecycle.md`（5 处）、`constraints.md`、
   `refact-task.md`（18 处）、`doc-gate.py`（`SELF_CONTAINED` 元组第 61–65 行）、`project-guide/governance.md`、
   `project-guide/README.md`、`ai-dev-readiness/` 四份，以及两份旧文自身；
3. `migration-map.md` 零缺口（5.2 的脚本判）；
4. 现文 §11.3 未验证清单八条在 `executor-architecture.md` 逐条可寻，仍标 ⚠；
5. 一轮 T1 任务与一轮 T0 任务已按新 Profile 实跑并留痕。

---

## 6. 实施路线

每轮一个工单，前置不可跳。档位按 round-protocol 判据自判，**本路线不含任何降档**。

| # | 轮 | 档 | 产物 | 前置 | 机械验收判据 |
| --- | --- | --- | --- | --- | --- |
| R0 | 修 `protocol-v2` 的脚本↔协议不一致（命名、`--stage`、退出码）——**只改脚本，不改协议正文**。**由 opus 直接修，不走轮次** | **bootstrap** | 合并 `protocol-v2` | 无 | 新建空 `rounds/_smoke/` 按协议字面写 `round.md`，`round-status.py` 能解析且判 ① 未开始 |
| R0′ | 往 `round-protocol.md` 补「机器可读块」一节（`round.md` 的 toml 块进协议）。**所有者裁定 2026-09-05：这是改协议，按 T2 开轮**（§7-12 已决） | **T2** | `round-protocol.md` 一节 | R0 | 协议正文与 `round.md` 字段表一一对应；`round-status.py` 解析规则以协议为准，脚本单测覆盖每个字段 |
| S1 | **边界 spike**（3.13）：① 建回执仓、建候选仓；② VM 换三把 key（候选仓读写、主仓只读、回执仓只读），撤销原 `id_rsa`；③ 所有者在 Windows 提交两份测试回执（`[H5]` 含 `acceptance`、`[H3]` 含 `ruling_sha256`），用带口令 key 推；④ 首版 `check-no-owner-creds.sh`；⑤ 按 3.13.0 在宿主 shell 重跑取证 | **bootstrap**（可逆、可丢弃） | `rounds/_spike-sign/` 留痕 | **§8 判据已冻结**（冻结判据 ≠ 判据已满足——qoder C3 的循环不存在；3.13 随之冻结） | ⓪ 回执仓与候选仓建成，VM 身份对**主仓与回执仓** `git push --dry-run` 均被拒（配置导出留痕）；VM 身份对候选仓 push 成功；两份测试回执 `round-status.py` 判成立（签名 ∈ 在线公钥集、schema 合法、`acceptance` 集合完整 / `ruling_sha256` 匹配）；用 VM 上未登记的 key 签一份回执推候选仓再伪装路径，判不成立；`check-no-owner-creds.sh` 零命中；断网重跑判未确认且退出码为「查询失败」；取证栏每行附 `hostname; id; cat /proc/self/uid_map` 输出 |
| R1 | 权力表全表回执仓锚定 + 收件箱字段分级 + 回执内容门；`round-status.py` 读回执仓 yaml 并在线验签、状态推导输出边并按 `state-machine.toml` 校验；T0 两道门；`check-policy.py`；orchestrator 写 `events.jsonl` | **T2**（权威层、不可逆） | `authority.md`、`policies/tier-defaults.toml` 首版（所有者签 `policy/1`）、`policies/state-machine.toml`、`scripts/check-policy.py`、`scripts/gates/`、脚本改动 | R0、S1、3.1.1 映射表冻结 | `round-status.py --round refact` 对历史轮次输出唯一状态机的词与合法边；对 S1 测试回执判 H5 / H3 成立、对缺 `acceptance` 或签名不在公钥集的回执判不成立；无回执的 `rulings.md` 裁定行被判不存在；伪造 T0 工单四种（包名不存在 / 自拼门禁列表 / 完工 diff 越出 paths / 引用一个 paths 覆盖 `constraints.md` 的包）各被拒绝，其中第四种在 `check-policy.py` 层就拒绝签策略；`intake_author` 兼 proposer 的配置被拒发 |
| R2 | 执行架构迁出（含 `human` kind 一小节，3.2） | T1（大搬家但方向无争议） | `executor-architecture.md`；agent 文相应节改为指针 | R0（**不依赖 R1**：S1/R1 受阻不阻塞本轮） | `doc-gate` 通过；§11.3 八条逐条可寻 |
| R3 | 登记表加 `principal` / `provider` / `runtime` / `model_family` / `roles_allowed`；分发前机械拦角色冲突（含 `intake_author`）；独立性折算首版进 `authority.md` | T1 | `agents.toml`、`round-dispatch.py` | R1 | 故意配置「裁决方兼提案方」，分发拒绝并给 reason；正常配置放行；折算表存在且 3.2 的示例（1 家独立带证 vs 3 家同 runtime 无证）按表算出前者胜；luna 与 kimi 按表落同一组 |
| R4 | 工单一般化为 Artifact + T0/T1 guard 表与必需产物表 + 三值路由 + `status` 改推导 | **T2** | `round-protocol.md` 改版、`policies/tier-defaults.toml`、脚本读 tier | R1、R3 | 用一个**可丢弃的小题目**（roadmap §4.1 要求）分别跑一次 T0、T1；每次 H2 都有落账；脚本输出无一处非唯一状态机的词 |
| R5 | 两份 lifecycle 合并为 `lifecycle.md`；`request-lifecycle.md` 边界声明修订；13 文件引用清理；`doc-gate.py` 配置 | **T2** | `lifecycle.md`、`migration-map.md`、删两份旧文 | R1–R4 | 5.3 五条全部通过 |

调整说明：S1 是 luna 建议的 spike，插在 R1 前；R3（角色冲突检查）按 luna 建议前移到实跑 T0/T1 之前；
R4/R5 与 `automation-roadmap.md`「处理顺序」第 4、6 步一致。3.1.1 状态映射表是 R1 前置，因为权力表的转换列用的就是它的词。
qoder B1 说 R1 把文档重构扩成了基础设施改造——扩的部分只有「建一个仓 + 配一把只读 key」，且 R2 不等它；
但「把签名回执降为可选」不采纳：⑥ 不可机械判是 1.4 的核心诊断，去掉它，本方案只剩文档搬家。

**`bootstrap` 档**（cursor C3）：R0 与 S1 不适用 3.6 的 T0 定义——T0 要求验收条引用已签策略里的包，而策略首版是 R1 的产物，
S1 的验收条（回执仓建成、越权被拒……）不可能在尚不存在的策略里。它们的验收条就是本表「机械验收判据」列，
效力来自本文被所有者按 §8 冻结，不来自 `policy/1`。`bootstrap` 只用于这两行，之后不再出现；R1 起全部按 T0/T1/T2 自判。
qoder C3 说「所有者凭什么在 S1 前冻结 §8」——这把**冻结判据**与**判据已满足**混为一谈：先冻结验收标准再干活正是 H1 的定义，
S1 的产出是 §8 第 6 条的实证材料，不是冻结 §8 的前提。opus 4.2 说「新增档位说明档位判据偏紧」有道理，但判据在 round-protocol，是它的 T2，登记 §7-14。
原 R0 旁注（协议补「机器可读块」是否算改协议）**所有者已裁定**：算，按 T2 开轮，即 R0′。

---

## 7. 风险与未决

| # | 风险 / 未决 | 处置 |
| --- | --- | --- |
| 1 | 签名回执的边界依赖信任锚在 agent 进程之外；agent 与人同一 credential domain（uid 1003），本地验签与本地 hook 都不是边界 | 3.13：回执仓 + 主仓写权限移出 VM + 在线公钥集验签；A′ ruleset / B / C 为加固；公钥**不**登记在仓内文件 |
| 2 | 人只剩 H1–H7 七个触点，可能在 T2 里觉得「参与感」不足 | 这是设计目标不是缺陷。人可随时以 H6 推翻；但**不加表外 APPROVAL 触点** |
| 3 | 三值路由的规则表初期会大量 `ask` | 预期行为。每次 `ask` 的人工选择反哺规则表，按「裁量是规则的孵化器」升级为规则 |
| 4 | 产品 Profile（PostgreSQL 载体）何时开工 | 不在本文范围；本文只保证开发 Profile 先把形状跑通。`handoff.md` 阶段一仍是前置 |
| 5 | 权力表 H2 的默认策略本身谁审 | 策略文件的修改按 T2（权威层）；首版由所有者手写并签 tag |
| 6 | 独立性分组键（`runtime`）是否足够——同 harness 不同模型的相关性未测 | 先按 `runtime` 分组，后续由「候选相似度」观测值校验；届时可能改为 `(runtime, model_family)`；列为 ⚠ 未验证 |
| 7 | 单 principal 阶段的权力表在多用户场景是否够用 | 表结构已按 principal 设计（3.2）；capability 列等到出现第二个 principal 再加，避免空列 |
| 8 | 过渡期 orchestrator 由人运行脚本 | 登记为「可自动」欠账（round-protocol「执行者与触发方式」），不是角色；通道打通即转代码 |
| 9 | T0 口径收窄后，大量小题目会落到 T1，H2 触点增多；且 T0 本身仍要 H5，「零触点」只指开工前 | 预期行为。任务类包按「裁量是规则的孵化器」逐步增加；每次增加是 T2（改策略）。观察值：T0/T1 比例、每票签名次数（3.4） |
| 10 | `request-lifecycle.md` 演化冲击开发 Profile | 3.1 三条：按 commit 引用、内核改动 T2、改后重跑 §8 第 4 条 |
| 11 | 触点疲劳导致盖章化；C1 全表锚定后签名次数上升 | 3.4 三个观察值（耗时、改动项数、签名次数）；不设自动动作，所有者看趋势。压缩次数只能靠一条 tag 多个 transition，不能拿掉锚 |
| 12 | **已决（所有者 2026-09-05）**：往协议补「机器可读块」算改协议 | 拆为 R0′，按 T2 开轮；R0 只改脚本 |
| 13 | **未决（有数据后定）**：T0 的「可逆出口」——只落 worktree、不走 ⑦、免 H5 | 属省事方向的新权力表行，本轮不加。S1/R1 之后看两周签名次数观察值，若 T0 的 H5 成为主要摩擦，另开 T2 轮定其形状。弊端已知：留在 worktree 的成果在本框架里没有状态，堆积后一次批量 push 就是绕过 H5 的批量不可逆动作 |
| 14 | **未决**：round-protocol「命中任一条即 T2」的「权威层」几乎覆盖 `dev-plan/` 全部文件，六轮三轮 T2（opus 4.2） | 判据属 round-protocol，改它是它自己的 T2；本文不改、不绕（bootstrap 只用两行）。R4 改版 round-protocol 时一并审 |
| 15 | 回执仓 + 候选仓 + Windows 发布，日常摩擦可能让人绕过流程直接改（qoder C1） | 观察值：每票签名次数、回执耗时、T0/T1 比例；两周后若 T0 比例 < 20% 或出现绕流程的 commit，重审包设计与 §7-13 |
| 16 | 伪造 / 误触 H7 取消的恢复成本（qoder C4） | H7 仍不锚仓外（失败安全），但取消裁定必须附「已产生副作用清单」，格式由 L0 校验；误取消的重开是新 Task（I5），成本进观察值 |
| 17 | `RUNNING` 在 `events.jsonl` 落地前不可判（luna C5） | 3.1.1 已声明；脚本覆盖声明合并显示 `QUEUED`/`RUNNING` 并标 ⚠；R1 落地事件文件后解除 |

---

## 8. 本方案自身的验收标准（供开轮时冻结）

1. 新结构中 router / orchestrator / arbiter / acceptor / approver 五词各有唯一定义，且 **router 与 orchestrator 没有 agent 实现**
   （登记表里没有任何条目的 `roles_allowed` 含这两个词；`roles_allowed` 只能取已注册角色）；
2. 权力表 ≤ 10 行，每行 `enforcement_point` 非空，且强制点在**凭据层或回执仓**（VM 上可改的脚本与 hook 不算强制点）；
3. `round-status.py` 对任一已发布轮次能不靠人声明判出 H5 成立与否；`QUEUED` / `RUNNING` 在 `events.jsonl` 落地前允许合并显示并标 ⚠；
4. **只有一套状态机**：(a) `policies/state-machine.toml` 的 states 与 `request-lifecycle.md @ <其头部 commit>`「两层状态机」所列
   **对称差为空**，且脚本实现读的是这份 schema（不是全文 `rg`——历史说明、Artifact 词、代码示例都会干扰）；
   (b) 3.1.1 映射表与脚本状态推导中出现的每条边 ⊆ schema 的 edges（脚本判）；
   (c) T0/T1/T2 各有 guard 表与必需产物表，三档共用同一工单 schema；
5. 开工前 `APPROVAL` 类触点：**T0 = 0，T1 = 1（H1+H2 一份回执），T2 = 2（H1 与 H2 分离）**；T0 为零的前提是工单 `acceptance`
   引用已签策略中的一个任务类包且 `RouteDecision` 落账（开工门），完工 diff ⊆ 包 `paths` 且 gates 全过（完工门）——
   开工门不过拒发，完工门不过不进 H5；T0 的 H5 不免除；
6. 所有 `auto_policy = 无` 的权力表行（H7 除外）判据锚在 agent 的 credential domain 之外：`round-status.py` 读的是**回执仓**里的签名回执
   （签名 ∈ 在线公钥集、schema、`target_commit`、`acceptance` 集合或 `ruling_sha256`），本地验签只标「参考」；无回执的 `rulings.md` 裁定行
   被判不存在；fetch / 端点失败判未确认且退出码单列；VM 身份对**主仓与回执仓**的 `push --dry-run` 均被拒且输出已留痕；
7. `migration-map.md` 覆盖两份旧文**全部** `##`/`###` 标题、零缺口（脚本判）；5.3 五条删除条件全部通过；
8. 全部新增判据在首跑时与人工结论对照过一次，记录在 `rulings.md`；
9. **取证栏冻结前重跑**（opus §6）：3.13.1 每行附复跑命令与当日输出，并注明主机、执行身份、`/proc/self/uid_map`；
   结论与证据不一致的行必须改证据或改结论——本条存在的理由是 3.13.0 记录的那次沙箱误判。

第 1、2、4、5、6、7、9 条机械可判；第 3、8 条由脚本输出佐证；没有一条需要「读起来对」。

**观察值，不是判据**（opus、luna、kimi、qoder 评审一致）：两份 lifecycle 合计 2426 行，合并后各新文件的行数
（qoder T2 指出其中约 500 行是本就该迁出的执行架构，所以行数下降不是收益，重复段落消除才是）；
禁止词表在新文档中的命中数（`doc-gate.py` 规则本身是 L0 门禁，命中数是观察）；每次 H 回执的耗时与改动项数；每票签名次数按 H 行分计；T0/T1 比例。
全部在 ⑦ 清理时登记进 `rulings.md`，不进验收。
