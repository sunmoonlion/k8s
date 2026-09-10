# Pipeline 任务：定义「AI 执行开发」的完整流程

> 建立：2026-09-04 ｜ 发起：项目所有者 ｜ 起草：opus
>
> **opus 本轮不参赛**，任评审与整合方：裁决选优、逐条整合、处理异议。不参与独立验收。
> 利益声明与角色划分见 §13。
>
> **本文是发给各助手的任务书，自足。**读它的人可能没有此前任何上下文，
> 所以 §0 讲怎么开工，第一部分把背景讲全，第二部分是要交付的东西。
> **除本文外不需要额外指令。**

> ⚠⚠ **本文已被取代（2026-09-08），不要照它开工。**
>
> 它是 2026-09-04 立的 `pipeline` 轮任务书，**题目是对的**——§6 交付物要的就是
> 「一份可直接发布的完整流程定义」，§13.1 也已处理「背景材料全部由 opus 起草」
> 这个利益冲突。**它没跑完**：判据已密封（`e7e37486`），四家产出从未出现。
>
> 2026-09-07 `dev-plan-refact` 轮另起任务书顶替了它，题目被改成「文档组织架构」，
> 并把 PRD/ADR/TLD 列为扣分项——那是本轮作废重开的直接原因，见
> [`../../rulings.md`](../../rulings.md) R1。
>
> **现行任务书**：[`../../dev-plan-refact.md`](../../dev-plan-refact.md)。
> 本文只作历史记录保留：它的 §7 七个问题与 §13.1 四条利益约束**已被现行任务书继承**。
> 文中出现的 `sunmoonai/docs/ai-dev-readiness/` 路径是**成文时的路径**，该目录
> 2026-09-08 已整体并入本轮 `inputs/`，不再存在。

---

## 0. 开工须知（先读这一节，再往下）

### 0.1 你是谁：看你的工作目录

你的当前工作目录形如 `~/worktrees/<X>/k8s`，**那个 `<X>` 就是你的名字**。
本文里所有 `<你的名字>` 一律替换成它。

```bash
pwd     # 应形如 /home/zym/worktrees/luna/k8s
```

**如果你的工作目录是 `~/master/k8s`，立即停下来问人。**那是主线共享 checkout，
本轮任何提案方都不得在那里写东西。

**如果 `~/worktrees/` 下没有以你命名的目录**，也停下来问人，不要自己创建。

### 0.2 本次只做环节 ①

本轮流程见 [`round-protocol.md`](../../../../protocol/round-protocol.md)，**你现在只做第一个环节**：

> **① 提案**：写出候选，提交，把候选文件的 SHA-256 与 commit 号回报给发起人。

**②互评现在做不了**，因为别人的候选还不存在。四家都交完①之后，发起人会通知你开始②。
**没接到通知就动手写评审，写出来的作废。**

### 0.3 提案期不许读什么

- **不读任何其他 worktree**（`~/worktrees/` 下除你自己以外的目录）；
- **不读 `~/codex-reference-archive/` 下除 `<你的名字>/` 以外的目录**；
- 看到别人答案之后写的内容属于评审或改进，不再是独立候选。

`~/master/k8s` **可读不可写**——本文与全部输入材料都在那里。

### 0.4 做完 ① 交什么

| # | 交付 | 位置（相对你 worktree 的仓根） |
| --- | --- | --- |
| 1 | 候选 | `sunmoonai/docs/ai-dev-readiness/pipeline.md`（**新建文件，本轮无基座**） |
| 2 | 提交 | 在你自己的分支上提交，**提交后不得再改** |
| 3 | 回报 | 把候选文件的 SHA-256 与 commit 号回给发起人 |

```bash
cd ~/worktrees/<你的名字>/k8s
sha256sum sunmoonai/docs/ai-dev-readiness/pipeline.md
git rev-parse HEAD
```

评审文件 `ai-dev-readiness/pipeline-review-<你的名字>.md` 属于环节 ②，**这次不要写**。

### 0.5 读的顺序

1. 本文全文
2. [`round-protocol.md`](../../../../protocol/round-protocol.md) — 本轮流程与纪律
3. [`constraints.md`](../../../../constraints.md) — 尤其「保证这些被遵守的三层」那节
4. `working/request-baseline/TEMPLATE.md` 与 `working/request-baseline/REQ-010-REQ模板完善/template-proposed.md` — **PRD 那一格的现状**
5. [`implementation-plan.md`](../../../../implementation-plan.md)、[`handoff.md`](../../../../handoff.md)、[`development-plan.md`](../../../../development-plan.md)
6. `working/request-lifecycle.md` — 产品契约，原则层，不动
7. 背景材料三份（见 §11），**注意它们各自的性质不同**

---

# 第一部分 · 背景

## 1. 这个项目在建什么，现在到哪了

investment-app 是一个多租户投资研究平台。用户在浏览器提出请求，后端受理成 Task，
交给 Agent 执行，结果持久化后返回前端。要建的是**全栈 agent 平台，含专业财务分析**。

**关键前提，先读懂再动手**：

> **本项目还没有进入实现阶段。现在主要在 PRD（需求定义）这一格。**

这不是细节，它决定本轮的重心：**现在写下的需求与验收标准，就是将来的测试**。
流程的前三格（需求 / 意图确认 / 验收与契约）要定得最细，后面几格现在只需留出位置
和判据，不必写成操作手册。

## 2. 为什么要立这一轮

**开发工作全部由 AI 助手承担。** 这个前提改变的不是开发速度，而是**错误的形状**：

| | 人类开发者 | AI 助手 |
| --- | --- | --- |
| 不懂时 | 会卡住、会问 | **会流畅地编**，语气与正确时无异 |
| 记纪律 | 会忘，但忘了心里有数 | 每次冷启动，纪律不在上下文里就等于不存在 |
| 产出速度 | 受限于打字 | 一夜可产出几千行自洽的散文 |
| 交叉检查 | 同事读得出味道不对 | 评审方也是 AI，可能被同一种"看起来对"骗过 |

由此推出一条本轮必须贯彻的判断：

> **AI 会 100% 声称满足一条无法被证伪的规则。**

这条不是修辞。本项目已经吃过一次亏：2026-09-03 有一次文档整合产出 1100 行自洽的稿子，
自编一套 8 条不变量与既有的 I1–I15 并存、还漏了三条，而**当时没有任何机器会因此变红**。

本仓自己在 [`constraints.md`](../../../../constraints.md)「保证这些被遵守的三层」里已经把道理写死了：

> **只有第一层不依赖人。**后两层是纪律，纪律会被忘。

**本轮就是把那句话做成一条完整的开发流程。**

## 3. 现状：已经查实的九条事实

以下由裁决方 2026-09-04 回源复核，带可复跑命令，**直接采信，不必重新论证**。
但**引用时要自己核一遍锚点还在不在**——本仓反复踩过的坑是「把"没找到"当成"不存在"」。

**① 规则大多还在纪律层。**

```bash
cd sunmoonai/docs/dev-plan
grep -cE "^\| [ACDITR][0-9]+ \|" constraints.md      # 40 条规则
```

40 条规则中 **22 条的「谁在执行」是 ⚠ 自检**，即纯纪律层。

**② 产品契约的编号一个都没进测试。**
`working/request-lifecycle.md` 定义了 15 条不变量 I1–I15、22 条验收 AT-01…AT-22、
10 条功能项 F-EXEC-01…08 / F-INTERACT-01…02，共 **47 个编号**。

```bash
cd investment-app/investment-backend/app
grep -rlnE "I1[0-5]|AT-[0-9]{2}" tests/      # 零命中
```

**没有任何测试按编号认领任何一条。** `tests/test_kernel_invariants.py` 测的是另一套
架构不变量，且不带编号锚定。

**③ 回路在新工作区里跑不起来。** 2026-09-04 实测：新 worktree 下
`python -m pytest` → `No module named pytest`。依赖声明是齐的
（`app/pyproject.toml` 的 `[dependency-groups].dev` 有 pytest / pytest-asyncio /
pyright / ruff），`uv` 也装了，但**每个新 worktree 需要先 `uv sync`，
而这件事没写在任何一个助手会先读到的地方**。仓内无 CI（无 `.github`）。

**④ 本仓已有两个"判据不依赖人"的样板，形状是对的，要沿用不要重造。**

| 样板 | 位置 | 对在哪 |
| --- | --- | --- |
| 文档门禁 | [`doc-gate.py`](../../../../doc-gate.py) + 版本化 `.githooks/pre-commit` | 不靠人记得跑；**结论不取决于工作区状态**（对照 git 索引而非文件系统） |
| 休眠能力登记表 | `investment-backend/app/tests/test_dormant_capabilities.py` | 每条判据**两个方向都能失败**：`anchor_exists`（锚点还在吗）+ `still_dormant`（还休眠着吗） |

两者共同的形状值得单独记住：

> **一个检查如果只能证明"没找到问题"，它就不是检查。
> 它必须同时能证明"我还找得到我要查的东西"。**

**⑤ 编号已经撞车。** `I3` 在本仓有两个互不相干的含义：
`constraints.md:88` 是「浏览器身份与服务身份互不通用」，
`working/request-lifecycle.md:450` 是「每次读取、工具调用和写入重新校验当前授权」。
`I1`–`I8` 两边都有。人读上下文能分清，**AI 跨文档检索时会混，且混了以后文字仍然通顺**。

**⑥ PRD 那一格的模板有两份并存，谁生效不明。**
`working/request-baseline/TEMPLATE.md`（39 行，四栏）与
`working/request-baseline/REQ-010-REQ模板完善/template-proposed.md`（93 行，七栏）。
后者明显更完备，但**没有任何地方声明它已生效**。

**⑦ 生产环境里现在没有 agent。**`ToolExecutionPort`、`SandboxPort` 生产引用为 0；
`CancelRunCommand` 在 `app/interfaces/` 下为 0；
bundle 里 `AGENT_V4_TRAFFIC_ENABLED` 与 `AGENT_PILOT_ENABLED` 都是 `'false'`。

**⑧ 业务数据 0 张表。**

```bash
grep -rn "create_table(" investment-backend/app/alembic/versions/ | wc -l   # 13
```

13 张表全是运行时基础设施（agent 运行时、LangGraph checkpoint、auth、outbox/inbox），
**没有标的、行情、财报、基本面、持仓、研报**。`tests/golden/` 下只有三份 graph 快照，
没有一条财务金标准。

**⑨ Profile 现在是审计字段，不是约束。**
`tests/test_dormant_capabilities.py:240` 已登记：`RunService.create_run` 解析 profile
并把 key/version 写进 run 行，但 `dispatch_agent_graph` 只传 `run_id` / `user_input` /
`security_context`，`effective_config` 到不了图里；两条生产图对 `allowed_tools`、
`denied_tools`、`model_key`、`system_prompt_id`、`memory_policy` 的引用数均为 0。

## 4. 题目边界：本轮管什么，不管什么

**这条最重要，不划清会和既有文档大面积撞车。**

| 文档 | 管什么 | 本轮 |
| --- | --- | --- |
| `working/request-lifecycle.md` | **产品契约**：Task/Attempt 对象、两层状态机、I1–I15、四本账、AT-01…AT-22 | **不动，原则层，只引用** |
| `working/development-lifecycle-agent.md` | **一个开发 Task 内部**怎么执行：受理、工作区物化、写入前门禁、执行内核、产出物与 commit、权限预算、证据验收 | **不动**（另有一轮正在重写它） |
| [`constraints.md`](../../../../constraints.md) | 代码必须符合的规则 | 不动，只引用规则号 |
| [`development-plan.md`](../../../../development-plan.md) | 要建什么、为什么 | 不动 |
| **本轮要产出的 `pipeline.md`** | **一个需求从提出到上线，经过哪些阶段与门** | **新建** |

用一句话记住分界：

> **`development-lifecycle-agent.md` 是 `pipeline.md` 中「实现」那一格的展开。**
> pipeline 管的是格子与门，不管格子内部怎么干活。

**凡是描述"agent 在一个 Task 内部怎么执行"的内容，本轮一律不写，只引用。**

## 5. 现有材料的家底

`dev-plan/` 现有 27 份文档。与本轮直接相关的：

| 文件 | 行 | 它在流程里是哪一格 |
| --- | --- | --- |
| `working/request-baseline/TEMPLATE.md` + `REQ-010/template-proposed.md` | 39 / 93 | **需求（PRD）**——两份并存 |
| `working/request-baseline/REQ-001…010/` | 14 份 | 已发生的需求记录（**是状态，不是流程**） |
| [`implementation-plan.md`](../../../../implementation-plan.md) | 69 | 任务模板（九栏）+ L1–L7 测试层次 |
| [`handoff.md`](../../../../handoff.md) | 96 | 状态与交接 |
| [`constraints.md`](../../../../constraints.md) | 214 | 规则 + 三层保证 |
| `working/request-lifecycle.md` | 647 | 产品契约 |
| `working/development-lifecycle-agent.md` | 1161 | 实现那一格的内部 |

一个值得注意的倒挂：**讲"该怎么干活"的文字有 2000 多行，而任务本体
`implementation-plan.md` 只有 69 行。** 元讨论远多于流程本身——本轮要产出的是后者。

---

# 第二部分 · 任务

## 6. 交付物

每家交**两份**，都写在**你自己的 worktree**，master 只读：

| # | 文件（相对仓根） | 内容 |
| --- | --- | --- |
| 1 | `sunmoonai/docs/ai-dev-readiness/pipeline.md` | **候选**：一份可直接发布的完整流程定义 |
| 2 | `sunmoonai/docs/ai-dev-readiness/pipeline-review-<你的名字>.md` | **自述 + 评优**，属环节 ②，**这次不写** |

**本轮无基座**，`pipeline.md` 是新建文件。四家写同一个路径不会冲突：
候选只活在各自分支，裁决方到各家 worktree 按 commit 取，**不合并任何候选分支**。

## 7. 候选必须回答的七个问题

这是本轮的题目。**不必按此顺序组织你的文档**，但七个都要有答案。

### 7.1 阶段与门（主干）

给出这条流程的**完整阶段划分**，每一格必须写清五件事：

| 列 | 内容 |
| --- | --- |
| 阶段 | 名称 |
| 谁做 | 人 / AI / 机器 |
| 产物 | 具体产出什么文件或对象 |
| 落点 | 落在仓内哪个路径（**要具体到目录或文件**） |
| 准入 / 准出 | 凭什么可以开始、凭什么算过 |

**准出判据必须同时标注它属于 `constraints.md`「三层」中的哪一层**：
随测试自动跑 / 随提交自动跑 / 纪律。**标"纪律"的要说明为什么做不成前两层**——
做不成的老实标 ⚠，不假装已机器化。

阶段数不限，但**每多一格都要说明它为什么不能并进相邻格**。

### 7.2 需求（PRD）那一格怎么落

**这是本轮权重最高的一格**，因为项目现在正在这里，而且现在写下的验收标准就是将来的测试。

现状是 §3⑥ 的两份模板。你要回答：

1. 两份模板取哪份、还要补哪几栏；
2. **"AI 复述需求 + 标出歧义 + 人确认"这一步要不要有、落在哪一栏。**
   现状：模板里有「决策点」表（AI 列取舍），但没有「我把你的需求理解成了什么」这一栏，
   歧义现在是隐式消化掉的；
3. **非功能需求（NFR）**放哪。现状七栏里一栏都没有，而 NFR 通常决定架构；
4. **验收标准与将来测试的对应关系**怎么建立。现状 `template-proposed.md` 第 ⑤ 栏要求
   "可由第三方判定、不含不可判定词、无此节不得进入 IMPLEMENTED"，但**没有要求每条
   指向一个测试标识**——§3② 的 47 个编号进不了测试，正是这一步缺失的后果；
5. **验收标准由谁写。** 现状实际是接请求的助手写，而它往往就是将来的实现方——
   出题方 = 答题方。这个要不要改、怎么改。

### 7.3 UI / 交互那一格

全仓检索不到 PRD / 原型 / 交互稿 / wireframe 一类实质材料，两个前端仓下也没有设计目录
（⚠ 只查了 `investment-web-frontend` 根级，你可自行复核）。

这一格要不要开、开的话产物是什么、由谁做、准出判据是什么？
注意本产品的特点：**长耗时 agent 任务**，空态 / 加载态 / 错误态的权重远高于普通 CRUD。

### 7.4 契约（API-first）放在哪一格

全栈开发的解耦点是契约先于两边实现存在。本项目现在有没有这个位置？没有的话放哪、
用什么形式、怎么保证它能被机器校验？

**注意**：这一条要和 `working/request-lifecycle.md` 已定义的对象分清——
那份定的是**领域对象与状态机**，不是 HTTP 契约。别把两件事混成一件。

### 7.5 判据从纪律层搬到测试层的办法

针对 §3① 的 22 条 ⚠ 自检规则与 §3② 的 47 个契约编号，给出可执行的做法。

要求：**分类处理，不追求一次全覆盖**——可机械判定的 / 需环境的集成测试 /
当前不可判定的（**必须显式列出并说明为什么**，否则"没测到"会被读成"测过了"）。

参考 §3④ 的两个既有样板，**沿用它们的形状而不是新发明一套**。

### 7.6 DoR / DoD 两个门落在哪

准入（可以开工了）与准出（做完了）的定义，落点建议是任务模板的栏位而不是流程文档——
**放流程文档里没人看，放任务模板里每开一个任务它就出现一次**。

现状：[`implementation-plan.md`](../../../../implementation-plan.md) 的九栏
（类型/仓库/前置/目标/实施/测试/验收/回滚/状态）已经是半个 DoR/DoD，
但没有区分准入与准出。你要给出具体的两张清单，以及它们落在哪。

### 7.7 角色分离与证据

回答三件事：

1. **出题方与答题方怎么分。** 自己写实现 + 自己写测试 + 自己报告通过 = 三位一体的自证。
   [`round-protocol.md`](../../../../protocol/round-protocol.md) 已经把角色分离想透了，但只用在大轮次上——
   **要不要下沉到日常任务？成本是否可接受（每个任务至少两个会话）？**
2. **人的评审审什么。** AI 会产出巨大 diff，"控制 PR 大小"这条纪律撑不住。
   人应当审哪几样、不审哪几样？
3. **证据怎么算数。** AI 自述"测试全绿"不可信——不是因为它撒谎，而是它可能跑的不是那件事、
   或环境不对而它没意识到。证据的形式要求是什么？

## 8. 明确不要写进去的

| 不写 | 为什么 |
| --- | --- |
| **一个开发 Task 内部怎么执行**（工作区物化、写入前门禁、checkpoint、supervisor 派工、commit 纪律） | 那是 `development-lifecycle-agent.md` 的地盘，见 §4。只引用 |
| **重新定义 `request-lifecycle.md` 已定义的对象**（Task、Attempt、Interaction、Artifact、Event、Side Effect、Delivery、四本账、I1–I15、AT-01…AT-22） | 一律引用，不重写 |
| **具体的工具表、Profile 字段表、模型选型** | 指南写怎么建，不写建成什么样；且业务数据为 0 张表，那些设计从没跑过真实输入 |
| **通用最佳实践散文**（"要写测试""要做 code review""要有 CI"） | 见 §12.2。不带本仓锚点的通用论述不计入 |
| **工时估点、燃尽图、需求追踪矩阵** | 仪式。判断标准：有没有人会回头读它、有没有机器会检查它，两者皆无就是仪式 |

## 9. 三件必须解掉的结构问题

### 9.1 与 `development-lifecycle-agent.md` 的接缝

pipeline 的「实现」那一格与那份文档的入口必须能对上：
**一个通过了 DoR 的任务，是怎么变成那份文档里的一个开发 Task 的？**
交接点上传递什么、谁负责传。不处理这条，两份文档会各自成立但接不起来。

### 9.2 编号体系

§3⑤ 的 `I3` 撞车已经存在。你新引入的任何编号（阶段号、门号、检查项号）
**不得与既有的 `A/C/D/I/T/R`、`I1–I15`、`AT-01…22`、`F-EXEC-*`、`REQ-***`、`Dn` 冲突**。
并给出一条能防止将来再撞的规矩。

### 9.3 这份文档自己的存续与落点

`pipeline.md` 落在 `sunmoonai/docs/ai-dev-readiness/` —— 本目录就是为解决 pipeline 而立的，
讨论材料、本任务书、定稿都在这里。**这是定值，不要改动落点**，
但你要回答它定稿之后的三个问题：

1. 它和 `ai-dev-readiness/README.md`、`dev-plan/README.md` 的关系——**谁是开发者的入口**？
2. `dev-plan/` 里既有的 27 份文档，哪些应当在 `pipeline.md` 里有位置、
   哪些应当被它取代或归档？**给出处置清单，不必执行。**
3. 怎么防止它变成第 28 份"讲流程的侧面"？
   （已知的坏味道：`dev-plan/` 讲"该怎么干活"的文字有 2000 多行，
   而任务本体 `implementation-plan.md` 只有 69 行。）

## 10. 一个必须自己判断的问题

**流程总量该变重还是变轻？**

一种直觉是"AI 快，流程可以更轻"。另一种判断是相反的：正因为实现变得几乎免费，
**前期定义与后期验证的相对重量必须加大**，否则产出量会淹没验证能力。

**本文不给结论。**这是本轮要你自己论证的核心判断之一，
它决定你设计的流程是几格、多少门、门有多硬。**给出结论并给出理由。**

## 11. 输入材料

**必读**

```text
sunmoonai/docs/dev-plan/constraints.md                    规则 + 三层保证
sunmoonai/docs/dev-plan/implementation-plan.md            任务模板与测试层次
sunmoonai/docs/dev-plan/handoff.md                        当前状态
sunmoonai/docs/dev-plan/development-plan.md               方向
sunmoonai/docs/dev-plan/round-protocol.md                 本轮流程
sunmoonai/docs/dev-plan/working/request-baseline/TEMPLATE.md
sunmoonai/docs/dev-plan/working/request-baseline/REQ-010-REQ模板完善/template-proposed.md
sunmoonai/docs/dev-plan/working/request-lifecycle.md      产品契约，只引用不动
```

**背景材料三份**，与本任务书同目录（`sunmoonai/docs/ai-dev-readiness/`）。
**三份性质不同，读的时候分清**：

| 文件 | 性质 | 怎么用 |
| --- | --- | --- |
| `standard-pipeline.md` | 行业通用实践的整理，**外部参照系** | 当尺子用，不是本项目规则 |
| `readiness.md` | 现状盘点与议题，**带取证** | 事实可采信（本文 §3 是它的蒸馏），议题的结论不采信 |
| `ai-pipeline.md` | 起草人一个人写的一份改法 | **只作为产物形状的范例**：它示范了"阶段 × 谁做 × 产物 × 落点 × 准入准出"这种写法 |

**关于 `ai-pipeline.md` 的严重提醒**：

> 它**不是基座**，它的八条改法**没有经过任何评审或取证**，其中一条判断已被起草人自己
> 推翻过（它说 REQ 模板"只有一半"，实际 `template-proposed.md` 已覆盖大部分）。
> **不得逐条继承它的判断。**要用其中任何一条，自己重新论证。
> 你的候选与它冲突，不构成缺点。

**参考**：`investment-app/investment-backend/app/tests/`（尤其
`test_dormant_capabilities.py`）、`sunmoonai/docs/evidence/`、
`sunmoonai/docs/project-guide/`。

## 12. 验收标准

1. **§7 的七个问题全部有答案**，每个都给出可执行的做法，不停在原则层。
2. **每条核心断言带锚点**：本仓 `file:line`、可复跑命令，或既有编号
   （`constraints.md` 的 A/C/D/I/T/R、`I1–I15`、`AT-01…22`、`F-EXEC-*`、`REQ-***`）。
   **不带锚点的通用最佳实践论述不计入。**上一次整合正是栽在这里。
3. **主干表完整**：每一格都有「谁做 / 产物 / 落点 / 准入 / 准出 / 属于三层中的哪层」。
4. **§4 的边界成立**：没有重写 `development-lifecycle-agent.md` 的内容，
   没有重新定义 `request-lifecycle.md` 的对象。
5. **§9 三件结构问题全部显式处理**，不得沉默略过。
6. **§10 的判断给出结论与理由。**
7. **PRD 那一格（§7.2）的五个子问题逐条有答案。**
8. 标"纪律层"的判据都说明了为什么做不成机器层；未验证的结论标 ⚠。
9. **没有工时估点、燃尽图、需求追踪矩阵一类仪式产物。**
10. 篇幅不设下限。**同等质量下更短的更好**——这份文档将来要被冷启动的助手读，
    每一行都在挤占它干活的上下文预算。

## 13. 本轮的角色

**流程本身见 [`round-protocol.md`](../../../../protocol/round-protocol.md)**——环节、产物落点、冻结与枚举、
评审四块、裁决与验收规则、清理顺序，全在那份里，本节不重复。**动手前先读完它。**

| 角色 | 谁 |
| --- | --- |
| 提案方 | **luna / kimi / cursor / qwen3.8 四家** |
| 评优方 | 同上四家 |
| 裁决与整合方 | **opus**（本轮不出候选、不写评审，不参与验收） |
| 验收方 | 裁决稿完成后由 opus 指定，规则见 `round-protocol.md` |
| 确认方 | 项目所有者 |

候选的枚举形状固定为：

```text
~/worktrees/*/k8s/sunmoonai/docs/ai-dev-readiness/pipeline.md
```

### 13.1 opus 的利益声明

`ai-dev-readiness/` 下三份背景材料**全部由 opus 起草**，而 opus 是本轮裁决方。
这构成利益冲突，因此额外约束：

1. 候选与 `ai-pipeline.md` 冲突时，**默认采纳候选**，除非有可复跑的取证支持后者；
2. 凡采纳与那三份一致的主张，处置记录必须写明**它比其他候选好在哪**，
   不得只写"与背景材料一致"；
3. `ai-pipeline.md` 已知有一处判断被推翻（§11 那条），整合时不得以任何形式复活；
4. 四家的候选**都不参考 opus 的候选**——本轮 opus 不出候选。

反例记在 [`round-protocol.md`](../../../../protocol/round-protocol.md)：2026-09-03 那次失败整合，
五条毛病全部源于角色不分。
