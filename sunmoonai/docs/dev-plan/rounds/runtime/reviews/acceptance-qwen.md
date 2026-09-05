参与方：qwen｜worktree：/home/zym/worktrees/qwen/k8s｜HEAD：798e200888be67f0bdd29865900a24c2110a76fc

# ⑤ 验收：轮次 runtime 裁决稿（验收方 qwen）

> 本文按 `runtime-call-⑤.md` 交付。验收方由 ③ 处置表算出（qwen，既得利益 2 条，唯一最小），
> 非指定。判定对象：裁决稿 `runtime-architecture.md` @ `opus`/`ac0615d8`（755 行）。
> 判定标准：`task.md` §8 十条 @ `runtime/h1`（冻结点，427 行）。未改动任何标准。

## 结论（置前）

**有条件通过。** 十条中八条满足、两条部分满足（§8-2、§8-10），无不满足项。
两条部分满足均给出可执行的补足条件（见下）。另登记三处证据描述勘误（不阻塞，见 §四）。

**条件（补足后即为通过）**：

| # | 条目 | 条件 |
| --- | --- | --- |
| C-1 | §8-2 | 补**本轮（runtime 轮）已发生介入**的逐条清单：每条介入（I-01、I-02、R1–R6、① 对 fable 的手工投喂、E-9 重发的所有者确认等）指到唯一状态机的一条边 + 权力表一行或 `dispatch_event`。落裁决稿，或由裁决方明示其正式落点（如随 `rulings.md` 维护）。目的：使冻结判据「逐条列表（脚本判：无缺项）」对本轮介入可执行。 |
| C-2 | §8-10 | 裁决稿首行补 `HEAD：<commit>`；或由裁决方明示口径「裁决稿类产物的版本钉定由环节通知的对象事实表承担、首行第三段记环节」——该口径是对冻结格式的偏离，须明示而非默认，处置权在裁决方/所有者（见 §五）。 |

## 一、取件与对象事实核对

| 对象 | 钉版 | 本人复跑 sha256[:16] | 判 |
| --- | --- | --- | --- |
| 裁决稿 `runtime-architecture.md` | 755 行 `3a6d6919ba05117c` | 一致 | ✓ |
| 处置记录 `runtime-disposition.md` | 359 行 `d6e3bfc9c2ca3b1d` | 一致 | ✓ |
| 验收标准 `task.md` @ `runtime/h1` | 427 行 `c31aa01cff556abd` | 一致 | ✓ |
| `rulings.md`（R1–R6） | 34 行 | 一致 | ✓ |

身份判别：`basename "$(dirname "$(git rev-parse --show-toplevel)")"` → `qwen`。
④ 两条异议（O-L1 / O-Q1）均被采纳且不触基座结构（处置记录 §K），⑤ 未作废，验收方仍为 qwen——已核对。

## 二、十条逐条判定

| 条 | 判定 | 依据（本人复跑） |
| --- | --- | --- |
| 1 只有一个运行时 | **满足** | 禁用词组零命中（`grep -cE '开发 Profile\|产品 Profile\|Profile A\|Profile B\|两个 Profile'` = 0）；`profile_id = dev.change`（裁决稿 :84）+ 四别名登记一行（:103-104）；五个 Agent Profile 名单在 §2.3（luna/kimi/cursor/fable/qwen，另 opus 不参赛） |
| 2 人不作为执行者 kind | **部分满足** | 机械判通过：`kind = "human"` 零命中；权力表八行各带边、各行 `enforcement_point` 非空（H0 已按 D-3 移出为 `dispatch_event`）。但「逐条列表（脚本判：无缺项）」只对**上一轮**成立（§2.8 trace 的 `power_row` 列），**本轮**已发生介入无逐条清单——基座候选有（`f053bd84:193-209`，11 行双轮清单），裁决稿未保留。详见 §三.1 |
| 3 等效判据可执行 | **满足** | 四要素字段定义（§2.7.2 `trace_entry`，`layer` 覆盖 task/attempt/interaction/artifact）；§2.8 以真实产物导出 23 条样例，数据源逐项复核成立；状态与边 ⊆ 内核（见 §三.2）。两处证据描述瑕疵登记于 §四，不影响判定 |
| 4 Interaction 双向 | **满足**（按 R6 口径） | 出向含 `subject_artifact_ref{artifact_id,version}`、`amend_schema`（JSON Pointer/path_glob）、`evidence_grade`、`options[]`；render 归 Delivery 并给 `client_context` 选择规则与缺省规则——等价或更强的结构化字段表。入向三值 + `amend{mode: patch\|replace, base_version, target ⊆ amend_schema}` + `response_state_version`；载荷成为下次 Attempt 输入的路径完整（§3.3，锚内核 :326 本人复核成立）。§3.5 显式声明内核修订，边界/影响/迁移齐备（additive + version gate，`legacy_resume`） |
| 5 可观测粒度 | **满足** | 三字段四档（`tool.enforced > tool.reported > process > fs-only`），区分逐工具调用与仅进程级；「自报不采信、运行时重新推导」推论在 §4.3 推论 1/2（明确「由 validator 跑，不由执行者跑」）；五家逐条填且无空缺（§2.3：luna/kimi/cursor/qwen = `process`，fable = `fs-only`——修正了本候选此前的 `process` 错标） |
| 6 必答 Q 四问全答 + 反例 | **满足** | §5.1–5.4 四问全答；§5.2「反例」小节三类反例各指明贵在哪一步；分类规则 M0–M5 全由工单字段直接判且明令禁止 tier 反推；T0 上界锚可数向量不锚时钟 |
| 7 OP-1/2/3 表态 | **满足** | §6：三项均「改写」（OP-3 部分采纳两处改写），逐项给出处与理由 |
| 8 锚定 | **满足**（一处锚点错位登记） | 全稿锚点本人逐条抽取复跑：内核 13 处、`refact-fable.md` 10 处、`rulings.md` 4 处、`~/repo/codex` 源码 3 处（裁决方自陈未复跑，**本人实跑复核成立**）、对照组 28 commits（`git rev-list --count refact/baseline-master..refact/integration` = 28，③④⑤ 逐处置 commit 抽查相符）。一处错位见 §四（E-c）。登记表「cursor argv 已钉 --model」经 `protocol-v2:agents.toml` 实锚验证成立。休眠代码未充当能力证据，§8 覆盖声明列 checked / not_checked |
| 9 只读输入未改动 | **满足** | `git diff --name-only 7e8464c2 opus -- <refact-fable.md> <request-lifecycle.md>` 为空 |
| 10 身份自证 | **部分满足** | 首行 `参与方：opus（裁决方）｜worktree：/home/zym/worktrees/opus/k8s｜环节：③ 裁决稿`：`<名>`与目录名一致（opus）、worktree 绝对路径正确；但冻结格式第三段规定 `HEAD：<commit>`，现稿为「环节」字段，HEAD 缺位。详见 §三.3 |

## 三、两条部分满足的理由

### 1. §8-2：类型级完整，实例级清单缺本轮

裁决稿对「每一次介入 → 一条边 + 一行」完成了**类型级**覆盖：权力表 H1–H8 八行各带边
（边全部 ⊆ 内核合法转换表，本人逐条核），H0 形状的介入由 `dispatch_event` 承担且明示不是权力行；
并且对**上一轮**（refact-fable）的介入给出了实例级逐条映射——§2.8 trace 的 `power_row` 列把
R3/R4、R5/R6、R7/R8 落 H8，R1 落 H1，终态落 H1+H5，投喂落 `dispatch_event`。

缺的是**本轮**：I-01（H6 解冻）、I-02（H1 冻结 + H2 合并）、R1–R6、① 对 fable 的手工投喂、
E-9 重发触发的所有者确认——这些已发生的介入在裁决稿中没有逐条的「边 + 行」清单。
基座候选有这份清单（`f053bd84:193-209`，11 行，覆盖两轮），裁决稿未保留；
其 §9 自检也只主张「权力表八行 + 每行的边」，未主张实例清单。

为什么按部分满足而不是满足：本判据的可执行部分就是「脚本判：无缺项」——枚举已发生介入、
逐条验证映射，无缺项才算过。这正是本轮 ②③ 的既定口径：本人 ② 评审对 kimi 判部分满足，
理由即「I-01/I-02 及 R3–R8 的介入若不算权力表行，脚本扫描会报缺项」；③ 处置对 luna 补
`AUTH-FREEZE`、对 kimi 补 H8，同样以实际发生的介入为驱动。同一把尺子量到裁决稿：
本轮介入未被枚举，「无缺项」不可执行，且本轮出现了上一轮没有的介入形状（如 ④ 异议处置后的
重发确认），恰好是最需要验证模型覆盖的地方。这是**产出未达标**（基座有、裁决稿丢了），
不是标准腐坏。补足条件即 C-1。

### 2. §8-3 的核验细节（判满足的支撑）

- 状态 ⊆ 内核：trace 样例 Task 层用词 {RECEIVED, VALIDATING, QUEUED, RUNNING, WAITING, SUCCEEDED}
  ⊆ 内核 Task 状态集；Attempt 层 {CREATED, RUNNING, COMPLETED} ⊆ 内核 Attempt 状态集
  （内核 :313 状态图）；`WAITING(INPUT)` / `WAITING(APPROVAL)` 是内核 :247-253 的结构化
  wait_reason 码，不是新状态。seq 20 的「REQUEST CHANGES」是评审结论标签，出现在 subject 列，
  不在状态序列列。
- 边 ⊆ 合法转换：seq 2（RECEIVED→VALIDATING→QUEUED）、seq 3（QUEUED→RUNNING）、
  seq 12（RUNNING→WAITING→QUEUED→RUNNING）、seq 23（RUNNING→WAITING→QUEUED→RUNNING→SUCCEEDED）
  逐条比对内核 :222-228 全部合法。
- 真实性：样例证据逐项复核——`rulings.md` R1–R8 行（:9-16）与 trace 的 R3/R4（:11-12）、
  R5/R6（:13-14）、R7/R8（:15-16）对应；`refact-fable.md` 修订记录时间戳 :6/:7/:13/:19/:24
  与 v0→v6 各版本对应；「产物未归档」与 ls-tree（无 opus/luna 首轮评审文件）相符；
  「只有一条 commit」对 7e8464c2 而言成立（见 §四 E-a 的限定）。

### 3. §8-10：防串号实质达成，格式偏离冻结文本

首行的两项机械核心通过：`<名>` 与 worktree 目录名一致（opus = opus，含「（裁决方）」角色注释）、
worktree 绝对路径正确。防串号的实质目的（task.md §8-10 末句）已达成。

但冻结格式规定首行三段为 `参与方｜worktree｜HEAD：<commit>`，裁决稿第三段是「环节：③ 裁决稿」，
HEAD 缺位。按硬纪律 1，本人不静默放宽标准也不自行改标准：判部分满足，补足路径二选一（C-2）。
该偏差有可辩解的成因（裁决稿在轮内多次修订，版本钉定实际由环节通知的对象事实表承担，
比自报 HEAD 更强），是否按「标准未预期裁决稿类产物」处置，属裁决方/所有者的权力（见 §五）。

## 四、勘误登记（不阻塞通过，供 ⑥ 确认与 ⑦ 清理）

| # | 位置 | 错漏 | 可复跑证据 | 应为 |
| --- | --- | --- | --- | --- |
| E-a | 裁决稿 §2.8 | 「第一条**只有一行**：7e8464c2…」不可跨 worktree 复现：数据源命令未钉 ref，而 `4513bcbd`（发布本轮工单，含 `rounds/refact-fable/open-questions.md`）**不在 opus 分支历史内**，故该命令在裁决方 checkout 只出一行，在五家 worktree 出两行 | `git merge-base --is-ancestor 4513bcbd opus`（退出非 0）；`git log --format='%h' -- sunmoonai/docs/dev-plan/rounds/refact-fable/`（本仓出两行） | 命令钉 ref：`git log 7e8464c2 --format='%h %ad %an' -- <路径>`，则处处一行。**结论不受影响**（4513bcbd 只新增 open-questions.md，非候选/验收产物） |
| E-b | 裁决稿 §2.8 | 「九份评审 + 一份 response + rulings.md」按加法读为 11 个文件，实际 **10** 个（9 份 `review-*`，其中一份即 fable 的 response，加 `rulings.md`） | `git ls-tree -r --name-only 7e8464c2 -- sunmoonai/docs/dev-plan/rounds/refact-fable/ \| wc -l` → 10 | 「九份评审（其一为 fable 的 response）+ rulings.md，共 10 个文件」 |
| E-c | 裁决稿 §2.2 | 「内核 `:521` 已有同义要求」——:521 是空行（「子 Task 与依赖编排」节内），所引要求「每个 Profile 的第一项开发工作单元必须用真实输入、输出、前端 renderer 和验收用例确认字段」实际在 `:516-517` | `sed -n '516,517p' working/request-lifecycle.md @ 70a7dd50` | 锚点改 `:516-517`。主张本身成立 |

## 五、标准腐坏判别（按硬纪律 2，交裁决方处置，本人不改标准）

§8-10 是唯一一条本人认为**可能存在标准腐坏**的判据：冻结文本以「候选稿」为对象规定
`HEAD：<commit>` 首行格式，其功能（钉作者所在 commit、防串号）对候选一次性交付成立；
裁决稿是轮内多次修订、由环节通知对象事实表钉版本的产物，自报 HEAD 反而会随每次修订失真。
两种处置均合法：(a) 判产出未达标，要求补 HEAD（C-2 第一支）；(b) 判标准对该产物类型部分过期，
明示「裁决稿版本钉定 = 通知对象事实表」的口径（C-2 第二支）。本人不代裁，故 §8-10 按现有
冻结文本记部分满足。

§8-2 无腐坏问题——判据可执行且本应可执行，缺的是产出侧的清单（C-1）。

## 六、覆盖声明

**查了**：裁决稿 755 行全文；处置记录 359 行全文（含 §K）；`task.md` 427 行全文；
`rulings.md`（runtime 轮 R1–R6 与 refact-fable 轮 R1–R8）；内核
`request-lifecycle.md @ 70a7dd50` 的状态机、wait_reason、Interaction 绑定、Attempt 记录、
修订纪律、反模式表各节；`refact-fable.md` 的修订记录与被引各行；裁决稿全部 30 处 `file:line`
锚点逐条复跑（含 `~/repo/codex` 三处源码锚，裁决方自陈未复跑，本人实跑复核成立）；
`protocol-v2:agents.toml` 的 cursor `--model` 钉法；对照组 28 commits 的提交形态抽查；
基座候选 `f053bd84` 的 §8-2 清单存在性。

**没查**：luna / kimi 的实际模型（`$CODEX_HOME` 未读）；fable 的模型（不可机械核验）；
裁决稿 §2.3 登记表其余 ⚠ 项（与裁决稿自陈一致，均标 ⚠ 未核）；
trace 样例 `attested/reported/inferred` 的 2/15/6 计数（seq 22/23 为混合等级、seq 10-11
合并行，计数口径依赖约定；标题读数「attested 仅 2」经本人独立复数成立，不影响任何判定）。

**利益申报**：本人为本轮 ⑤ 验收方（由 ③ 处置表算出，既得利益最小），且本候选在 ③ 被判
三条不满足——对本裁决稿通过与否的动机最弱，但上述 §8-2 判定与本候选当年被扣分的是同一条
判据、同一把尺子（本人 ② 对 kimi 的部分满足判定与此同构）。
