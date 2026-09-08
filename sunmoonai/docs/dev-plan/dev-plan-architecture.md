cursor

# `dev-plan/` 怎样长进 ①a 的流程（不是堆进去）

> **①b** ｜ 身份：worktree 目录名 `cursor`（`~/worktrees/cursor/k8s`）
> 流程结构见同目录 [`pipeline.md`](pipeline.md)。本文只做一件事：把
> [`inventory.md`](rounds/dev-plan-refact/inventory.md) 的 260 节安置进那套结构。
>
> **次序：**先写归属判据，再写每份文档的内部结构，再写拆并代价与锚点保全，
> **最后**才是 260 行落点表。表里的「判据」列引用的是本文前面的编号，不是事后贴的标签。

---

## 1. 归属判据（先于任何落点）

一条内容属于某一类，当且仅当它通过该类的正面条件，并且**通不过**相邻类的正面条件。
只说「§X 装了这些」不算。

### 1.1 类型判据（对 [`pipeline.md`](pipeline.md) 的 12 类）

| ID | 类型 | 什么样的内容属于这里 | 通不过这里、应去邻居的信号 |
| --- | --- | --- | --- |
| C-CONTRACT | 产品合同 | 必须落实为前端协议、后端持久化、Agent 执行纪律、运维控制或自动验收（合同自己 §0.1 的入门问题） | 谈 Git、worktree、轮次环节、助手怎么写代码 → 操作手册或协作协议 |
| C-CONTRACT-F | 同上·功能条款 | 用户链路上「必须能做什么」（F-*） | 「对象是什么」→ C-CONTRACT-DOM；「怎样算验收」→ C-CONTRACT-AT |
| C-CONTRACT-I | 同上·不变量 | 跨进程仍须成立的 I* | 开发侧硬约束（数据/身份/发布）→ C-DISC；两边都有 I1–I8，**按文件分，不按字母分** |
| C-CONTRACT-AT | 同上·产品验收 | AT-* 矩阵：用户 Task 怎样算做完 | 开发 Change 的验收 → 任务计划/协作协议 |
| C-CONTRACT-DOM | 同上·领域条款 | 七对象、两层状态机、Profile、子 Task、责任投影 | 运行时「这次用哪个 SDK 接入」→ C-TLD-RT |
| C-DISC | 硬约束 | 动代码前「违反则方案不进入讨论」的平台规则，按要动的面分组 | 用户 Task 必须怎样 → 产品合同；这一次改哪些文件 → 增量设计 |
| C-DISC-META | 硬约束·元规则 | 这些规则本身如何被机器或纪律执行 | 具体的 D/C/I/T/R/A 条文 → C-DISC |
| C-DISC-EV | 硬约束·证据采信 | 跨 Change 成立的「什么事实能信、什么不能外推」 | 某次测试输出 → 证据；某次怎么跑验证步骤 → 操作手册 |
| C-PROTO | 协作协议 | 多家（或人与 AI）怎么一起做决定、什么算产物、环节如何判定 | 「下一个要建的适配器」→ 任务计划；「一次执行的步骤」→ 操作手册 |
| C-OP | 操作手册 | 冷启动的执行者接到一个 Change 之后照做的步骤、入口、反模式 | 产品保证 → 合同；运行时目标结构 → 增量设计；历史落点收据 → 证据 |
| C-OP-STRUCT | 操作手册·自身结构 | 手册为什么分成这些章 | 沿用现有 14 章而不给理由 → 本轮否决条件；本候选给了重审结论（§2.2） |
| C-OP-HITL | 操作手册·人介入 | 执行中碰到人时做什么。权力的真源在协议；产品 Interaction 真源在合同 | 把权力表写成第二份协议 → 禁止（手册已自陈这是原来的病） |
| C-OP-VERIFY | 操作手册·验证边界 | 开发场景跑通不能外推到业务 Profile | 证据采信通则 → C-DISC-EV |
| C-TLD-RT | 增量设计 | **当前在做的**产品运行时怎么搭（执行层、Port、部署、Profile 字段） | 「每一次 Change 都要走的步骤」→ 操作手册；「三年路线」→ 方向 |
| C-DIR | 方向 | 要建什么、为什么、依赖顺序、有意不建什么 | 现在做到哪 → 状态；任务栏 → 任务计划 |
| C-PLAN | 任务计划 | 有栏可勾的任务本体：仓库、前置、实施、测试、验收、回滚、状态 | 为什么这么建 → 方向；执行步骤细则 → 操作手册 |
| C-DEC | 决定记录 | 一次拍板：选了什么、没选什么、谁拍的 | 完整审议过程可留在轮次目录，但决定必须能单独检索；操作步骤不是决定 |
| C-EV-RCPT | 证据 | 可复跑的取证、零丢弃收据、机械输出 | 日常还要照做的规则 → 操作手册或硬约束 |
| C-STATUS | 状态 | 现在到哪、卡在哪、什么不能倒退 | 论证、步骤、任务栏一律不准进 |
| C-INDEX | 索引 | 指路。不承载规范 | 写「必须/禁止」→ 写错类型 |
| C-PROJ | （投影，不是第 13 类） | 手册里复述合同或约束、并指向权威 | 投影写了权威没有的新结论 → 登记为发现，本轮不改（B3） |

C-PROJ 不是新类型。它标记「这段话现在写在手册里，权威在别处」。吸收时应当缩成指针，不得把投影养成第二真源。

### 1.2 阶段判据

阶段跟类型不是一张表的两列同义反复。阶段回答「这条内容是哪一次 Change 的过关物」，类型回答「它是哪种过关物」。

| 阶段 | 收入什么 | 不收入什么 |
| --- | --- | --- |
| 常驻面 | 每次 Change 都踩着走的规则与入口 | 某一次运行时设计、某一轮的裁定 |
| 提出 | 原话、以及「要不要进运行时」这种开工前判断 | 完成契约、任务栏 |
| 立约 | 产品保证与本 Change 完成契约 | 执行步骤 |
| 定向 | 路线与理由 | 进度 |
| 决策 | 拍板 | 还在争的审议过程可作证据附件，不是决定本身 |
| 本增量设计 | 这一次怎么改、当前运行时怎么搭 | 每一次怎么执行 |
| 实施 | 执行步骤、HITL 操作、反模式 | 产品状态机 |
| 验证 | 采信规则、机械收据 | 「验收内容对不对」（那是人） |
| 发布与交接 | 游标、删除门、不能倒退 | 下一步为什么这么建 |

---

## 2. 目标文档的内部结构（每一份都要被论证）

物理上本轮**不搬家**。理由在 §3。这里论证的是：吸收之后每份活文档凭什么还分成这些块；哪些块其实是寄居者。

### 2.1 `working/request-lifecycle.md` — 产品合同，保持一份

**内部结构（论证后保留）：**

| 块 | 现节 | 为什么是独立块 |
| --- | --- | --- |
| 边界 | §0、§12 | 决定什么能进合同、怎么改合同。与对象定义变更门槛不同 |
| 全景 | §1 | 给读者一张用户 Task 图。不是开发 Change 图（那张在 [`pipeline.md`](pipeline.md)） |
| 领域条款 | §2–§4、§7–§9 | 没有对象和状态机，功能项无处附着 |
| 功能 | §5 | F-* 是「必须能做什么」，读者是实现产品链路的人 |
| 不变量 | §6 | I* 是跨进程纪律，读者是写存储和运行时的人 |
| 产品反模式 | §10 | 与操作手册 §11 的开发反模式不是同一读者 |
| 产品验收 | §11 | AT-* 是用户 Task 的完工门，不是开发 G2 |

**为什么不按「PRD / 领域模型 / 规格」拆成三份文件：**

所有者起点是 ≈ PRD。起草者认为焊了三样。焊是真的，但三者是**同一份合同的条款种类**：功能项引用对象，验收引用功能项和不变量。拆成三份会制造三个真源，而合同自己的 I13 要求一个可变事实只有一个权威写入面。
本候选的处理是：**类型上承认条款种类，物理上保持一份**，并用 C-CONTRACT-* 在落点表里标出来。物理拆分留给将来一次专门 Change，且必须过 §4 的锚点保全。

**不沿用的：**把开发流程写进这份合同。合同 §0.1 已经禁止。现状里它仍指向两份已归档的 lifecycle 文当作「开发流程真源」——这是结论过期，登记为发现，本轮不改（见 [`findings.md`](rounds/dev-plan-refact/findings.md) 本候选追加的一条）。

### 2.2 `agent-dev-guide.md` — 操作手册，内部三类寄居者必须点名

现行 §0.2 为 14 章给过「独立存在的理由」。那些理由在**章这一层**说得通，但没有解释为什么 §2 可以装 12 个关于 SDK/Port/部署的小节，而日常执行者只想走 §3。任务书给的尺子正好是这次：吸收时把内容塞进最近的章，二级划分不再被审视。

**本轮的重审结论（C-OP-STRUCT）：**手册只保留「执行者照做」的部分。另外三类是寄居者，吸收时应迁出或缩成指针，**本轮先标记、不搬家**。

| 部分 | 现章 | 重审后身份 |
| --- | --- | --- |
| A 入口与投影 | §0、§1、§13 | **留。**§1 里对合同/约束的复述按 C-PROJ 缩指针 |
| B 操作闭环 | §3、§4、§6、§11、§12、§14 | **留。**这是操作手册的核心 |
| C 运行时结构 | §2、§7.2 | **寄居的增量设计（TLD）。**这是所有者说的「当前在做的」。目标：迁出为独立 TLD，或迁入任务计划的阶段〇/二 |
| D 证据采信 | §5 | **寄居的硬约束。**目标：constraints 增加「证据」组，或留作手册验证章但不再假装是运行时结构 |
| E 收据 | §8、§10 | **寄居的决定/证据。**目标：§8 回各轮 `rulings.md` 的索引；§10 进 `archive/` |
| F 游标碎片 | §7.4、§7.6 | **寄居的状态。**目标：handoff |

**为什么现在不按 A–F 把文件切开：**见 §3.2。切开的代价发生在引用和冷启动入口上；标记寄居者不发生这种代价，却已经满足「归属判据先于结果」。

**沿用且给理由的：**§3 按一次 Task 的时间顺序写（受理 → 工作区 → 执行 → 交付）。这不是继承历史，这是操作手册作为阶段「实施」过关物的内部逻辑。

**不沿用的：**把 §8–§10 当成「手册必须有的章」。零丢弃收据证明历史没丢，不证明读者每次开工都要读 294 行落点表。

### 2.3 `protocol/round-protocol.md` — 协作协议

**内部结构：按 T2 一条 Change 的加厚形态的时间顺序。**

§0 收到继续 → §1 档位 → §2 裁量 → §3 执行者轴 → §4–§16 七环节与清理 → §17 通用纪律。
这与 [`pipeline.md`](pipeline.md) 的「并行轮是同一条 Change 的参数」一致：协议文件的骨架就是 G1/G2 在 T2 上的展开，不是一份随便编过号的手册。

**沿用的理由：**顺序等于环节顺序。重排会让「命令即判据」的节号全部漂移，而脚本按节引用。

**不把 §8b 脚本用法并进 `implementation-plan.md`：**那是协议实现，必须和规范一起改（`protocol/README.md` 已论证）。

### 2.4 `protocol/README.md`

三节（设计约束、单一真源、已知不做）加封面。内部逻辑是「改这里的代码前先读」。保持。它不是索引类——它承载协议实现的约束。

### 2.5 `constraints.md` — 硬约束

**内部结构：按「你要动什么」分组**（数据/契约/身份/拓扑/发布/智能体），外加「怎么用」和「三层」。

理由：G1.5 要求开工前按变更面对照。按主题分组让执行者不必通读。三层元规则必须单独成块，否则机器/纪律会再被混进同一张「已保证」清单——文件自己已经为这件事付过学费。

**寄居目标：**把 guide §5 的采信规则收成「证据」组（本轮不搬）。

### 2.6 `development-plan.md` — 方向

块：起点（不延续 v5）→ 智能体两分 → 三个阶段 → 有意留白。
理由：方向文档必须能回答「为什么不那么建」。留白是决定不是欠账，所以必须留在方向里、不能进 handoff 的未决表（未决是还没定；留白是已经定了不建）。

**不沿用：**把阶段〇进度写进来。进度在 handoff。

### 2.7 `implementation-plan.md` — 任务计划

块：条目格式 → 测试层次 → 交付规则 → 阶段〇到三。
理由：缺栏视为未定义（G1.2）。阶段〇是开发框架自身的任务队列，**仍是任务计划**，不是第四种方向文档——改协议脚本也要有可勾的完工条件。

阶段一清单为空是状态（U1 未定），内容应在 handoff 出现，本文件只保留「空，因为 U1」这一句指针。现状如此，吸收时不要往空清单里填假任务。

### 2.8 `handoff.md` — 状态

块：当前阶段 → 已就位 → 未决 → 不能倒退 → 游标 → 框架进度 → 已完成轮次。
理由：接手先读。文件自己写了「只写状态」。结构已经符合 C-STATUS。

**吸收时要收进来的寄居者：**guide §7.4/§7.6 的未验证清单；不要收论证。

### 2.9 `README.md` — 索引

两节：入口表 + 「别混写」。这正是 C-INDEX。吸收后应改指针，指向 [`pipeline.md`](pipeline.md) 与本文，但仍不得把流程正文写进 README（B10）。

### 2.10 本轮两份新文档的位置

| 文件 | 类型 | 生命周期 |
| --- | --- | --- |
| [`pipeline.md`](pipeline.md) | 协作协议的总流程（常驻面）。轮次协议是它在 T2 上的展开 | 被采纳后成为常驻面真源之一；本文件作为候选只活在分支上 |
| 本文 | 一次重构 Change 的增量设计 + 证据（落点表） | 轮次结束后：结构结论并入活文档，落点表进 archive 或作为迁移图留下 |

它们不在 260 节之内。260 节是要被安置的存量。

---

## 3. 拆与并的代价

### 3.1 不拆 `working/request-lifecycle.md`

| 谁的引用会断 | 锚点怎么保全 | 读者检索路径怎么变 |
| --- | --- | --- |
| 任务书：71 个带行号的外部锚点、40 份文档引用 | 见 §4：本轮零编辑该文件 | 不变 |
| `agent-dev-guide.md` 多处 `request-lifecycle.md @ <sha>:<lines>` | 行号锚钉的是历史 commit，文件原地不动则未来新锚仍可钉新 sha | 不变 |
| 合同内部 F-* / AT-* / I* 互相引用 | 不分文件则不跨文件 | 若拆成三份，实现者要同时打开三份才能改一条功能——这是代价，不是收益 |

只说「拆了更清楚」不算论证。清楚已经由落点表的条款种类列提供。

### 3.2 不把 `agent-dev-guide.md` 当场切成三份

| 代价 | 具体 |
| --- | --- |
| 引用 | 手册内部大量 `§N` 互指；`doc-gate` 对自足文档核章节号。切开后要么同时改所有互指，要么留下大面积断链 |
| 冷启动 | 执行者现在「读一份 guide」。切成手册 + TLD + 收据三份，入口要改 README、GO.md、协议引用。这本身是一次 T2 Change |
| 寄居者迁出 | §2（运行时 TLD）迁走后，手册变薄，这是目标；但必须同期给 TLD 一个稳定路径，否则「当前在做的」再次无家可归 |

**分阶段（后续 Change，不是本轮）：**① 在手册目录处加「寄居者」声明（指针，不搬正文）→ ② 把 §8/§10 迁 archive，手册改链 → ③ 把 §2 迁成 `runtime-tld.md` 或并入阶段二任务的设计栏。每步单独过 G1/G2。

### 3.3 不把 `protocol/` 并进 `implementation-plan.md`

代价见 [`pipeline.md`](pipeline.md)「为什么 protocol 不是实施计划的一部分」：两拨读者、两种变更频率、脚本与规范必须同目录。并的收益只是少一个文件夹，不够支付这些代价。

### 3.4 要加的两样（本轮只命名）

| 加什么 | 谁的引用会断 | 检索路径怎么变 | 为什么值得 |
| --- | --- | --- | --- |
| `decisions/index.md` | 不断。已归档 `rulings.md` 不动（F4） | 查决定从「猜哪一轮的 R1」变成「全局 ID」 | Q9 今天就有痛感 |
| `working/traces/<id>/` | 不断 | 非轮次工作第一次有证据袋 | Q8 今天空缺 |

创建它们是另一次 Change。本轮若在分支上新建空目录，会被当成「交了架构」，其实没有内容——所以只命名。

### 3.5 零「故意不要」

260 节全部有落点。没有一节被丢进「以后再说」。寄居不是故意不要：内容保留在现行文件，类型已经改判。

---

## 4. B2 锚点保全（可执行）

内核 `working/request-lifecycle.md` 的外部锚是 **commit + 路径 + 行号**。改文件内容会让未钉 commit 的裸行号全部漂移；即使只在页首加一行说明，71 个行号也会 +1。

**本轮方案（吸收本轮组织结论时必须遵守）：**

1. **本轮及紧随的吸收不得编辑 `working/request-lifecycle.md` 的任何一行。**归属变化只存在于本文落点表。
2. 已钉 commit 的锚（`request-lifecycle.md @ <sha>:<lines>`）本来就不随工作区漂移；保持该文件路径不变，这些锚继续可解析。
3. 仓内 `anchor-gate.py` 已覆盖「钉 commit 的锚在该 commit 内解析、裸路径锚对当前索引解析」。任何将来的迁移 Change 必须把该脚本纳入 G2 机械条。
4. **若将来物理拆分或重排该文件**，必须在同一次 Change 里交付：
   - 迁移图：旧 `sha:行号范围` → 新 `路径 + 稳定节标题`（不要再用行号当稳定 ID）；
   - 40 份引用方的更新；
   - `anchor-gate.py` 全绿；
   - 原路径留下一份**跳转页**（不是规范副本）：只写「合同已迁到 X」，避免第二真源。跳转页会占用原路径，行号锚全部作废——所以这一步只能在引用方同时更新之后做。
5. 在第 4 步完成前，落点表里的 C-CONTRACT-* 是逻辑切分，不是物理切分。

无第 4 步的拆分方案视为不可行。本候选不提出本轮拆分。

---

## 5. 开放问题在落点上的答案

| # | 答案（落到文件） |
| --- | --- |
| Q1 | 42 节全部留在 `working/request-lifecycle.md`，类型=产品合同。条款种类见 C-CONTRACT-* |
| Q2 | `rounds/` 不在 260 节内。架构容得下它们：决定 → 决定记录；其余 → 证据。不重排已归档轮次 |
| Q3 | `protocol/` 61 节（含 README 4 节）→ 协作协议。不并入实施计划 |
| Q6 | 存量 260 节映射到 11 个已有类型（12 类里「原始请求」在 `request-baseline/`，不在 260 内） |
| Q8 | 260 节里几乎没有非轮次证据袋；guide §10 是唯一整节级的证据收据。新槽见 [`pipeline.md`](pipeline.md) |
| Q9 | 260 节里决定正文很少（guide §8 四节是吸收裁定）。检索靠将来的索引，不靠改这四节的历史措辞 |

---

## 6. 与 `project-guide/`、`request-baseline/`

- `project-guide/`：现状投影，本轮不吸收。边界见 [`pipeline.md`](pipeline.md)。
- `working/request-baseline/`：原始请求，位置已裁定，不动（B7）。不在 260 节内。

---

## 7. 覆盖声明

**查了：**`inventory.md` 全部 260 个标题；9 份文档的节结构；产品合同 §0–§2 正文；guide §0 与 §10 页首；constraints / development-plan / implementation-plan / handoff / 两个 README 全文；[`pipeline.md`](pipeline.md)。

**没查：**其他家候选；`inputs/` 除 README 与 readiness 题面以外的正文；`rounds/` 64 份逐份；guide §2–§14 每一节正文（落点按标题与所属章的判据，不假装逐字重读了 3082 行）。对 guide 子节若标题不能代表内容，以正文为准、登记修补——与 guide 自己 §10 对「覆盖索引不等于语义无缺」的纪律相同。

**机械：**落点表由脚本对照 `inventory.md` 生成，行数断言为 260。脚本不进仓（不是交付物）。

---

## 8. 落点表（260 节，一节不缺）

判据列的 ID 见 §1.1。物理落点写「寄居」时，现行文件仍是读点，目标迁出见 §2 与 §3。

| # | 源文件 | 行 | 标题 | 阶段 | 类型 | 物理落点 | 判据 | 为什么在这不在别处 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | working/request-lifecycle.md | 1 | Request Lifecycle：产品请求生命周期合同 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同封面：只收产品要求，不是开发流程 |
| 2 | working/request-lifecycle.md | 13 | 0. 规范边界与条款筛选 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同边界/用语，不是开发流程 |
| 3 | working/request-lifecycle.md | 15 | 0.1 只收产品要求 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同边界/用语，不是开发流程 |
| 4 | working/request-lifecycle.md | 29 | 0.2 本文负责什么 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同边界/用语，不是开发流程 |
| 5 | working/request-lifecycle.md | 52 | 0.3 规范用语 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同边界/用语，不是开发流程 |
| 6 | working/request-lifecycle.md | 58 | 1. 生命周期全景 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 用户 Task 全景，不是开发 Change 全景 |
| 7 | working/request-lifecycle.md | 92 | 2. 核心对象 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 8 | working/request-lifecycle.md | 106 | 2.1 Task 不等于 Attempt | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 9 | working/request-lifecycle.md | 120 | 2.2 Submission 不一定产生 Task | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 10 | working/request-lifecycle.md | 127 | 3. Task 契约 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 11 | working/request-lifecycle.md | 129 | 3.1 提交信封 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 12 | working/request-lifecycle.md | 147 | 3.2 持久化主档 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 13 | working/request-lifecycle.md | 166 | 3.3 解释、边界与完成契约 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 14 | working/request-lifecycle.md | 183 | 3.4 最终结果信封 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 15 | working/request-lifecycle.md | 203 | 4. 两层状态机 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 16 | working/request-lifecycle.md | 205 | 4.1 Task 状态机 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 17 | working/request-lifecycle.md | 247 | 4.2 WAITING 与 Interaction | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 18 | working/request-lifecycle.md | 279 | 4.3 取消意图与终态 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 19 | working/request-lifecycle.md | 292 | 4.4 终态、刷新与重新处理 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 20 | working/request-lifecycle.md | 304 | 4.5 Attempt / Run 状态机 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 21 | working/request-lifecycle.md | 346 | 5. 七阶段产品功能 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 22 | working/request-lifecycle.md | 351 | 5.1 提交（前端） | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 23 | working/request-lifecycle.md | 360 | 5.2 受理与校验（后端） | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 24 | working/request-lifecycle.md | 369 | 5.3 排队与可靠投递 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 25 | working/request-lifecycle.md | 377 | 5.4 Agent 执行 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 26 | working/request-lifecycle.md | 391 | 5.5 中断、批准与恢复 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 27 | working/request-lifecycle.md | 398 | 5.6 验收与完成提交 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 28 | working/request-lifecycle.md | 413 | 5.7 返回前端、失败与重试 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-F | 功能项 F-*：用户链路必须实现什么 |
| 29 | working/request-lifecycle.md | 442 | 6. 跨进程纪律与持久化账 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-I | 不变量 I*：实现必须遵守 |
| 30 | working/request-lifecycle.md | 444 | 6.1 全程不变量 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-I | 不变量 I*：实现必须遵守 |
| 31 | working/request-lifecycle.md | 467 | 6.2 持久化记录 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-I | 不变量 I*：实现必须遵守 |
| 32 | working/request-lifecycle.md | 485 | 7. Profile、Artifact 与扩展 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 33 | working/request-lifecycle.md | 487 | 7.1 Task Profile 与 Agent Profile | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 34 | working/request-lifecycle.md | 508 | 7.2 Profile 示例 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 35 | working/request-lifecycle.md | 520 | 8. 子 Task 与依赖编排 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 36 | working/request-lifecycle.md | 550 | 9. 前端、后端与 Agent 责任投影 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-DOM | 对象/状态机/Profile/编排：合同的领域条款 |
| 37 | working/request-lifecycle.md | 566 | 10. 反模式 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 产品侧反模式，不是开发操作反模式 |
| 38 | working/request-lifecycle.md | 586 | 11. 产品验收矩阵 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT-AT | 验收 AT-*：怎样算产品做完 |
| 39 | working/request-lifecycle.md | 623 | 12. 修订、落地与参考材料 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同自己的修订纪律 |
| 40 | working/request-lifecycle.md | 625 | 12.1 修订纪律 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同自己的修订纪律 |
| 41 | working/request-lifecycle.md | 637 | 12.2 参考材料边界 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同自己的修订纪律 |
| 42 | working/request-lifecycle.md | 643 | 12.3 生效边界 | 立约 | 产品合同 | working/request-lifecycle.md | C-CONTRACT | 合同自己的修订纪律 |
| 43 | agent-dev-guide.md | 1 | Agent 开发指导：一个产品运行时，一套开发纪律 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 活文档身份：操作入口，不以历史稿覆盖合同 |
| 44 | agent-dev-guide.md | 23 | 0. 先读结论 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 冷启动入口与阅读路径 |
| 45 | agent-dev-guide.md | 52 | 0.0 原来是什么样，为什么非改不可 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 冷启动入口与阅读路径 |
| 46 | agent-dev-guide.md | 70 | 0.1 文档边界 | 常驻面 | 索引 | agent-dev-guide.md（过渡） | C-INDEX | 真源表；权威不在本文件。目标：缩成入口指针 |
| 47 | agent-dev-guide.md | 87 | 0.2 为什么分成这些章 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP-STRUCT | 手册自身结构论证；本轮重审，不无理由沿用 |
| 48 | agent-dev-guide.md | 106 | 0.3 按工作阶段阅读，不按历史版本阅读 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 冷启动入口与阅读路径 |
| 49 | agent-dev-guide.md | 126 | 1. 不可变的契约与边界 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 合同/约束的操作入口，不是权威写入面 |
| 50 | agent-dev-guide.md | 128 | 1.1 唯一产品内核 | 常驻面 | 产品合同 | working/request-lifecycle.md（权威）；本节是投影 | C-PROJ | 内核条款的开发投影，禁止第二真源 |
| 51 | agent-dev-guide.md | 143 | 1.2 四本账与单一权威写入面 | 常驻面 | 产品合同 | working/request-lifecycle.md + development-plan.md | C-PROJ | 四本账是合同 I*；缺预算/证据是方向里的现状 |
| 52 | agent-dev-guide.md | 151 | 1.3 Agent 硬约束自检 | 常驻面 | 硬约束 | constraints.md（权威）；本节是投影 | C-PROJ | A1–A5 对照，权威在 constraints |
| 53 | agent-dev-guide.md | 164 | 1.4 开发验收不可外推 | 验证 | 操作手册 | agent-dev-guide.md | C-OP-VERIFY | 开发验收不可外推到业务 Profile：执行者必须知道的边界 |
| 54 | agent-dev-guide.md | 171 | 1.5 执行者的共同纪律 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 执行纪律与设计原则：每次 Change 都用，不是某次 TLD |
| 55 | agent-dev-guide.md | 187 | 1.6 七条设计原则 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 执行纪律与设计原则：每次 Change 都用，不是某次 TLD |
| 56 | agent-dev-guide.md | 213 | 1.7 先核前提，也核控制面 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 执行纪律与设计原则：每次 Change 都用，不是某次 TLD |
| 57 | agent-dev-guide.md | 235 | 2. 一个运行时的结构 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 58 | agent-dev-guide.md | 237 | 2.1 确定性组件与适配层 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 59 | agent-dev-guide.md | 255 | 2.2 内容角色 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 60 | agent-dev-guide.md | 269 | 2.3 Task Profile 与 Agent Profile | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 61 | agent-dev-guide.md | 293 | 2.4 `dev.change/1` 工单 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 62 | agent-dev-guide.md | 347 | 2.5 路由只读可判字段 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 63 | agent-dev-guide.md | 354 | 2.6 执行层：租用什么、自建什么 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 64 | agent-dev-guide.md | 408 | 2.7 两个官方 SDK：两个轴、非对称能力 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 65 | agent-dev-guide.md | 433 | 2.8 统一执行 Port 与三态能力探针 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 66 | agent-dev-guide.md | 483 | 2.9 Harness 腿的前置门禁与过渡补法 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 67 | agent-dev-guide.md | 511 | 2.10 双 runtime 的部署、进程与恢复 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 68 | agent-dev-guide.md | 548 | 2.11 派工契约、角色补充与隔离的诚实边界 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 69 | agent-dev-guide.md | 587 | 2.12 五家 Agent Profile 的历史取值示例 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居；目标迁出为运行时 TLD） | C-TLD-RT | 产品运行时怎么搭：这是『当前在做的』，不是每一次 Change 的步骤 |
| 70 | agent-dev-guide.md | 649 | 3. 一次开发 Task 怎样执行 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 71 | agent-dev-guide.md | 651 | 3.1 受理与冻结 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 72 | agent-dev-guide.md | 682 | 3.2 工作区供给 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 73 | agent-dev-guide.md | 704 | 3.3 Attempt 与状态投影 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 74 | agent-dev-guide.md | 741 | 3.4 T0/T1/T2 不是三套状态机 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 75 | agent-dev-guide.md | 767 | 3.5 交付、清理和恢复 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 76 | agent-dev-guide.md | 782 | 3.6 私有地产生，单写者发布 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 77 | agent-dev-guide.md | 822 | 3.7 并发场景处置表 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 78 | agent-dev-guide.md | 863 | 3.8 覆盖或来源不明时的事故规程 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 79 | agent-dev-guide.md | 893 | 3.9 冻结、迟到与取消 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 80 | agent-dev-guide.md | 914 | 3.10 物化门禁与写入前门禁 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 81 | agent-dev-guide.md | 969 | 3.11 候选状态机 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 82 | agent-dev-guide.md | 988 | 3.12 完成判据 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 83 | agent-dev-guide.md | 1009 | 3.13 执行形态、停止规则与成本 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 84 | agent-dev-guide.md | 1042 | 3.14 建立 worktree 的细则 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 85 | agent-dev-guide.md | 1055 | 3.15 发布协议：三个路径不是一个 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 86 | agent-dev-guide.md | 1078 | 3.16 保留与垃圾回收 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 87 | agent-dev-guide.md | 1093 | 3.17 内核对象 ↔ 开发载体对照 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 88 | agent-dev-guide.md | 1114 | 3.18 状态脚本的硬要求 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 89 | agent-dev-guide.md | 1131 | 3.19 T2 七环节的操作闭环 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 90 | agent-dev-guide.md | 1169 | 3.20 工作区能写，不代表 Git 能提交 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 91 | agent-dev-guide.md | 1199 | 3.21 通知、取件与人的检视面 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 92 | agent-dev-guide.md | 1224 | 3.22 停止、超时与回退不能省略 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 一次开发 Task 怎样执行：操作手册的核心 |
| 93 | agent-dev-guide.md | 1247 | 4. 人介入、Interaction 与权力 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 94 | agent-dev-guide.md | 1249 | 4.1 人的位置 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 95 | agent-dev-guide.md | 1261 | 4.2 权力表 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 96 | agent-dev-guide.md | 1284 | 4.3 直接沿用实际中断/恢复原语 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 97 | agent-dev-guide.md | 1347 | 4.4 身份、批准与强制点 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 98 | agent-dev-guide.md | 1383 | 4.5 权限公式与只有 principal 能做的动作 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 99 | agent-dev-guide.md | 1430 | 4.6 三道正交门 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 100 | agent-dev-guide.md | 1452 | 4.7 四档审批 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 101 | agent-dev-guide.md | 1481 | 4.8 principal 的裁量权与改判纪律 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 102 | agent-dev-guide.md | 1509 | 4.9 Attempt 内的三条硬禁令 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 103 | agent-dev-guide.md | 1528 | 4.10 人这一侧的义务 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 104 | agent-dev-guide.md | 1549 | 4.11 本轮已发生介入的实例级清单 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 105 | agent-dev-guide.md | 1580 | 4.12 人的收件箱：让批准具体、可读、可重取 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 106 | agent-dev-guide.md | 1605 | 4.13 执行器凭据、子进程与跨腿委派 | 实施 | 操作手册 | agent-dev-guide.md | C-OP-HITL | 执行中人介入。轮次权力以 protocol 为准；产品 Interaction 以合同为准。本节只写执行者碰到人时怎么做 |
| 107 | agent-dev-guide.md | 1629 | 5. 可观测性、证据与等效 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 108 | agent-dev-guide.md | 1631 | 5.1 三个粒度字段 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 109 | agent-dev-guide.md | 1659 | 5.2 证据等级与采信规则 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 110 | agent-dev-guide.md | 1674 | 5.3 手工态与服务态的等效判据 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 111 | agent-dev-guide.md | 1699 | 5.4 Git 载体能与不能证明什么 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 112 | agent-dev-guide.md | 1709 | 5.5 四层验证 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 113 | agent-dev-guide.md | 1721 | 5.6 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 114 | agent-dev-guide.md | 1747 | 5.7 证据账按流程分级 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 115 | agent-dev-guide.md | 1774 | 5.8 上下文路由与能力四级词典 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 116 | agent-dev-guide.md | 1804 | 5.9 七种载体各能证明什么 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 117 | agent-dev-guide.md | 1827 | 5.10 事实裁决表与整合纪律 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 118 | agent-dev-guide.md | 1851 | 5.11 轨迹实测：23 条里 2 条 attested | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 119 | agent-dev-guide.md | 1899 | 5.12 检查本身也必须接受检查 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 120 | agent-dev-guide.md | 1916 | 5.13 历史取证怎样用于今天的开发 | 验证 | 硬约束 | agent-dev-guide.md（寄居；证据采信是跨 Change 纪律） | C-DISC-EV | 什么事实能信：纪律，不是某次测试清单。不放进『流程跑完』 |
| 121 | agent-dev-guide.md | 1930 | 6. 什么时候运行时值得用 | 提出 | 操作手册 | agent-dev-guide.md | C-OP | 是否值得进运行时 / T0 上界：开工前的成本判断 |
| 122 | agent-dev-guide.md | 1932 | 6.1 机械分类 | 提出 | 操作手册 | agent-dev-guide.md | C-OP | 是否值得进运行时 / T0 上界：开工前的成本判断 |
| 123 | agent-dev-guide.md | 1947 | 6.2 三类反例与 T0 上界 | 提出 | 操作手册 | agent-dev-guide.md | C-OP | 是否值得进运行时 / T0 上界：开工前的成本判断 |
| 124 | agent-dev-guide.md | 1963 | 6.3 绕过只能部分可观测 | 提出 | 操作手册 | agent-dev-guide.md | C-OP | 是否值得进运行时 / T0 上界：开工前的成本判断 |
| 125 | agent-dev-guide.md | 1986 | 7. 演进与退出脚手架 | 定向 | 方向 | agent-dev-guide.md（寄居） | C-DIR | 演进总述：方向+运行时 TLD 的混合物，内部再按子节切开 |
| 126 | agent-dev-guide.md | 1988 | 7.1 依赖顺序 | 定向 | 方向 | development-plan.md（权威应在方向）；本节是运行时依赖顺序 | C-DIR | 依赖顺序是方向，不是操作步骤 |
| 127 | agent-dev-guide.md | 2002 | 7.2 从手工态拆到服务态 | 本增量设计 | 增量设计 | agent-dev-guide.md（寄居） | C-TLD-RT | 手工态到服务态：运行时演进设计 |
| 128 | agent-dev-guide.md | 2038 | 7.3 删除与迁移门 | 发布与交接 | 操作手册 | agent-dev-guide.md | C-OP | 删除与迁移门：执行者何时允许删旧稿 |
| 129 | agent-dev-guide.md | 2073 | 7.4 风险和未决 | 发布与交接 | 状态 | handoff.md（目标）；本节寄居手册 | C-STATUS | 未决/未验证清单是游标，不是规范 |
| 130 | agent-dev-guide.md | 2104 | 7.5 跨会话续接 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 跨会话续接是执行问题 |
| 131 | agent-dev-guide.md | 2140 | 7.6 执行器架构的未验证清单 | 发布与交接 | 状态 | handoff.md（目标）；本节寄居手册 | C-STATUS | 未决/未验证清单是游标，不是规范 |
| 132 | agent-dev-guide.md | 2159 | 7.7 需要改内核时，提交明确的修订工作单元 | 立约 | 产品合同 | working/request-lifecycle.md §12（权威）；本节是操作投影 | C-PROJ | 改内核必须走合同修订工作单元 |
| 133 | agent-dev-guide.md | 2178 | 8. 本轮核查裁定 | 决策 | 决定记录 | 原轮次 rulings（目标）；本节是吸收收据 | C-DEC | 核查裁定是决定，不应成为手册正文 |
| 134 | agent-dev-guide.md | 2189 | 8.1 六项逐条处置 | 决策 | 决定记录 | 原轮次 rulings（目标）；本节是吸收收据 | C-DEC | 核查裁定是决定，不应成为手册正文 |
| 135 | agent-dev-guide.md | 2206 | 8.2 保留与撤销 | 决策 | 决定记录 | 原轮次 rulings（目标）；本节是吸收收据 | C-DEC | 核查裁定是决定，不应成为手册正文 |
| 136 | agent-dev-guide.md | 2215 | 8.3 本次补吸收明确不采用的旧主张 | 决策 | 决定记录 | 原轮次 rulings（目标）；本节是吸收收据 | C-DEC | 核查裁定是决定，不应成为手册正文 |
| 137 | agent-dev-guide.md | 2235 | 9. 覆盖声明 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 138 | agent-dev-guide.md | 2241 | 9.1 查了什么 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 139 | agent-dev-guide.md | 2253 | 9.2 没查什么 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 140 | agent-dev-guide.md | 2299 | 9.3 自增内容及理由（`runtime-refact` 轮） | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 141 | agent-dev-guide.md | 2306 | 9.4 两份 lifecycle 的吸收轮（2026-09-07） | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 142 | agent-dev-guide.md | 2448 | 9.5 GPT-6 再吸收记录（2026-09-08） | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 143 | agent-dev-guide.md | 2507 | 9.6 取代前 opus 做的核验（2026-09-08） | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 覆盖声明：手册自己的证据边界，随手册走 |
| 144 | agent-dev-guide.md | 2554 | 10. 五份历史正文及目录说明的逐节处置 | 验证 | 证据 | archive/ 落点收据（目标）；现 §10 | C-EV-RCPT | 历史零丢弃表是证据，不是日常执行步骤 |
| 145 | agent-dev-guide.md | 2876 | 11. 反模式 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 机制反模式：给执行者。产品反模式在合同 §10 |
| 146 | agent-dev-guide.md | 2924 | 12. 常见失败方式与项目实例 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 本项目失败实例：给执行者当回归线索 |
| 147 | agent-dev-guide.md | 2965 | 12.1 七种“检查给出假答案”的回归线索 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 本项目失败实例：给执行者当回归线索 |
| 148 | agent-dev-guide.md | 2984 | 12.2 并行评审的收益与盲区 | 实施 | 操作手册 | agent-dev-guide.md | C-OP | 本项目失败实例：给执行者当回归线索 |
| 149 | agent-dev-guide.md | 3004 | 13. 词汇对照 | 常驻面 | 操作手册 | agent-dev-guide.md | C-OP | 词汇对照：执行入口。对象定义权威仍在合同 |
| 150 | agent-dev-guide.md | 3038 | 14. 开发 Task 持久记录模板 | 本增量设计 | 任务计划 | implementation-plan.md（格式权威）；本节是开发 Task 模板 | C-PLAN | 持久记录字段集是任务条目格式的实例 |
| 151 | protocol/round-protocol.md | 1 | 并行评优轮：流程 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 152 | protocol/round-protocol.md | 22 | 0. 收到「继续」时怎么办 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 153 | protocol/round-protocol.md | 52 | 1. 流程档位：这件事该走多重的流程 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 154 | protocol/round-protocol.md | 64 | 1.0 一套流程，靠参数覆盖三种协作形态 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 155 | protocol/round-protocol.md | 85 | 1.1 判据：命中任一条即 T2 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 156 | protocol/round-protocol.md | 99 | 1.2 升档随意，降档要理由——这条不对称是有意的 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 157 | protocol/round-protocol.md | 111 | 1.3 任何档位都不能省的三条 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 158 | protocol/round-protocol.md | 120 | 2. 裁量权：supervisor 可以临机决定什么 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 159 | protocol/round-protocol.md | 127 | 2.1 不可裁量的下限 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 160 | protocol/round-protocol.md | 138 | 2.2 可裁量的事项 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 161 | protocol/round-protocol.md | 143 | 2.3 方向不对称：这是本协议的统一原则 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 162 | protocol/round-protocol.md | 159 | 2.4 裁定记录：未记录的裁定无效 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 163 | protocol/round-protocol.md | 171 | 2.5 推翻 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 164 | protocol/round-protocol.md | 179 | 2.6 裁量是规则的孵化器 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 165 | protocol/round-protocol.md | 191 | 3. 执行者与触发方式：两个轴，不要混 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 166 | protocol/round-protocol.md | 197 | 3.1 两个轴 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 167 | protocol/round-protocol.md | 209 | 3.2 全部动作的归属 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 168 | protocol/round-protocol.md | 226 | 3.3 两类「人做」不可互相顶替 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 169 | protocol/round-protocol.md | 236 | 4. 七个环节（T2 专用） | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 170 | protocol/round-protocol.md | 263 | 5. 本轮定义：`round.md` | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 171 | protocol/round-protocol.md | 291 | 6. 产物、路径与命名 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 172 | protocol/round-protocol.md | 323 | 6.1 环节通知：组织者的产物，不是发起人的话术 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 173 | protocol/round-protocol.md | 344 | 7. 取件与检视面 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 174 | protocol/round-protocol.md | 349 | 7.1 取件：一律按 commit，不看工作区 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 175 | protocol/round-protocol.md | 365 | 7.2 检视面：需要人读时开临时 worktree | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 176 | protocol/round-protocol.md | 382 | 7.3 每个需要人读的环节都必须先有检视面 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 177 | protocol/round-protocol.md | 391 | 8. 环节判定：命令即判据 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 178 | protocol/round-protocol.md | 427 | 8.1 判据自身的质量：覆盖不全比没有更危险 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 179 | protocol/round-protocol.md | 465 | 8.2 立判据的人怎么约束自己 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 180 | protocol/round-protocol.md | 472 | 只写判据，不写答案 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 181 | protocol/round-protocol.md | 484 | 立据人的四条自我约束 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 182 | protocol/round-protocol.md | 492 | 难点清单：记下来是为了检验发起方 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 183 | protocol/round-protocol.md | 501 | 三条通用扣分规则 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 184 | protocol/round-protocol.md | 507 | 起草人回避 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 185 | protocol/round-protocol.md | 516 | 判据自身的失效条件 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 186 | protocol/round-protocol.md | 529 | 一票否决项要事先列 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 187 | protocol/round-protocol.md | 534 | 8b. 两个脚本怎么调 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 188 | protocol/round-protocol.md | 553 | 退出码 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 189 | protocol/round-protocol.md | 564 | 声明与计算对不上时 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 190 | protocol/round-protocol.md | 576 | 8c. 组织者的两条纪律 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 191 | protocol/round-protocol.md | 581 | 8c.1 环节进行中，组织者不得写入参与方的工作区 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 192 | protocol/round-protocol.md | 604 | 8c.2 代提交必须用 `--author`，且必须登记为欠账 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 193 | protocol/round-protocol.md | 619 | 9. ① 提案：隔离与冻结 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 194 | protocol/round-protocol.md | 624 | 9.1 隔离为什么是硬要求 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 195 | protocol/round-protocol.md | 644 | 9.2 工单发什么、不发什么 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 196 | protocol/round-protocol.md | 675 | 9.3 机制化隔离：曾经有过，已经删掉 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 197 | protocol/round-protocol.md | 690 | 10. ② 互评：评审文件写什么 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 198 | protocol/round-protocol.md | 713 | 11. ③ 裁决：定基座与吸收 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 199 | protocol/round-protocol.md | 724 | 12. ④ 异议：对整合权的唯一制衡 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 200 | protocol/round-protocol.md | 741 | 13. ⑤ 验收 与 ⑥ 确认 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 201 | protocol/round-protocol.md | 760 | 13.1 定向审核分两阶段，防止被产出方锚定 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 202 | protocol/round-protocol.md | 780 | 13.2 验收通过意味着什么，不意味着什么 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 203 | protocol/round-protocol.md | 789 | 14. 停止、超时与回退 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 204 | protocol/round-protocol.md | 803 | 14.1 参与方不可用：逾期、弃权与换人 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 205 | protocol/round-protocol.md | 883 | 15. 角色不分会怎样 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 206 | protocol/round-protocol.md | 902 | 16. ⑦ 清理与发布 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 207 | protocol/round-protocol.md | 917 | 17. 通用纪律 | 决策 | 协作协议 | protocol/round-protocol.md | C-PROTO | T2 加厚形态的规范；不是任务清单 |
| 208 | protocol/README.md | 1 | `protocol/` —— 流程规范与它的实现 | 常驻面 | 协作协议 | protocol/README.md | C-PROTO | 规范与实现必须同目录、一起改 |
| 209 | protocol/README.md | 23 | 三条设计约束，改这里的代码前先读 | 常驻面 | 协作协议 | protocol/README.md | C-PROTO | 规范与实现必须同目录、一起改 |
| 210 | protocol/README.md | 33 | 单一真源 | 常驻面 | 协作协议 | protocol/README.md | C-PROTO | 规范与实现必须同目录、一起改 |
| 211 | protocol/README.md | 39 | 已知不做的事 | 常驻面 | 协作协议 | protocol/README.md | C-PROTO | 规范与实现必须同目录、一起改 |
| 212 | constraints.md | 1 | 开发必须遵守的规则 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 213 | constraints.md | 13 | 怎么用 | 常驻面 | 硬约束 | constraints.md | C-DISC-META | 纪律与机器的分界：约束文件自己的元规则 |
| 214 | constraints.md | 40 | 数据 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 215 | constraints.md | 54 | 做数据迁移时 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 216 | constraints.md | 71 | 契约 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 217 | constraints.md | 82 | 身份 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 218 | constraints.md | 95 | 拓扑 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 219 | constraints.md | 105 | 什么时候才拆出专用 Worker | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 220 | constraints.md | 116 | 发布 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 221 | constraints.md | 128 | 改模板、同步实例时 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 222 | constraints.md | 137 | 清理镜像时 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 223 | constraints.md | 144 | 一条环境事实 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 224 | constraints.md | 149 | 智能体 | 常驻面 | 硬约束 | constraints.md | C-DISC | 按『你要动什么』分组的硬规则；动代码前对照 |
| 225 | constraints.md | 161 | 保证这些被遵守的三层 | 常驻面 | 硬约束 | constraints.md | C-DISC-META | 纪律与机器的分界：约束文件自己的元规则 |
| 226 | constraints.md | 181 | `doc-gate.py` 为什么不是第三个被删的脚本 | 常驻面 | 硬约束 | constraints.md | C-DISC-META | 纪律与机器的分界：约束文件自己的元规则 |
| 227 | development-plan.md | 1 | 开发计划 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 228 | development-plan.md | 10 | 起点：不延续 v5 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 229 | development-plan.md | 24 | 智能体分两部分 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 230 | development-plan.md | 36 | 四本账是两部分共用的地基 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 231 | development-plan.md | 44 | 执行层租用，不自建 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 232 | development-plan.md | 64 | 三个阶段 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 233 | development-plan.md | 68 | 一 · 前后端对接 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 234 | development-plan.md | 97 | 二 · agent 开发 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 235 | development-plan.md | 110 | 三 · 结构化数据问答（后期） | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 236 | development-plan.md | 134 | 有意留白的两处 | 定向 | 方向 | development-plan.md | C-DIR | 要建什么、为什么；不写进度、不写任务栏 |
| 237 | implementation-plan.md | 1 | 实施计划 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 238 | implementation-plan.md | 11 | 任务条目格式 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 239 | implementation-plan.md | 27 | 测试层次 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 240 | implementation-plan.md | 38 | 交付规则 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 241 | implementation-plan.md | 53 | 阶段〇 · 开发框架自身的实施路线（R0–R5） | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 开发框架自身也是任务队列，不是另一类文档 |
| 242 | implementation-plan.md | 77 | 阶段一 · 前后端对接 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 243 | implementation-plan.md | 79 | 任务清单 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 244 | implementation-plan.md | 86 | 阶段二 · agent 开发 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 245 | implementation-plan.md | 90 | 阶段三 · 结构化数据问答 | 本增量设计 | 任务计划 | implementation-plan.md | C-PLAN | 任务本体：怎么做、怎么算做完 |
| 246 | handoff.md | 1 | 交接 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 247 | handoff.md | 14 | 当前阶段 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 248 | handoff.md | 21 | 已经就位的（不用再做） | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 249 | handoff.md | 30 | 未决项 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 250 | handoff.md | 42 | U1 的已知输入 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 251 | handoff.md | 51 | U3 的已知输入 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 252 | handoff.md | 59 | U4 的已知输入 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 253 | handoff.md | 68 | 不能倒退的输入 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 254 | handoff.md | 80 | 文档面待办 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 255 | handoff.md | 93 | 任务游标 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 256 | handoff.md | 98 | 开发框架自身（R0–R5 路线）的进度 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 257 | handoff.md | 118 | 已完成的轮次 | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 258 | handoff.md | 127 | 不能倒退的两条（本轮新增） | 发布与交接 | 状态 | handoff.md | C-STATUS | 只写状态：到哪了、卡在哪、不能倒退什么 |
| 259 | README.md | 1 | dev-plan — 代码要符合什么、接下来建什么 | 常驻面 | 索引 | README.md | C-INDEX | 入口与分工。不承载规范 |
| 260 | README.md | 25 | 各文档的分工，别混写 | 常驻面 | 索引 | README.md | C-INDEX | 入口与分工。不承载规范 |
