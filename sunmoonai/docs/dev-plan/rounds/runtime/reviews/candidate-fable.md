参与方：fable｜worktree：/home/zym/worktrees/fable/k8s｜HEAD：4513bcbd

# 运行时架构：只有一个运行时，开发是它的第一个 Task Profile

> 起草：2026-09-05 ｜ 起草者：fable ｜ **候选，不承担规范效力** ｜ 轮次 `runtime` ① 提案
>
> 身份判别：`basename "$(git rev-parse --show-toplevel | xargs dirname)"` → `fable`（本 worktree 实跑）。
>
> **取证声明（先于事实，按 `refact-fable.md` 3.13.0 的规矩）**：本文命令分两档跑，`hostname` 均为 `VM-0-13-ubuntu`。
> 沙箱档：`id` → `uid=0(root)`，`cat /proc/self/uid_map` → `0 1003 1`——宿主 uid 1003 被映射为 0；worktree 可写，
> 仓外 `.git` 不可达（`git rev-parse` 退出 128），网络受限。提权档（本会话后半，为取 git 对象）：
> `id` → `uid=1003(zym)`，`uid_map` → `0 0 4294967295`。
> **同一执行者、同一会话、两套身份**——切换发生在助手自带沙箱里，运行时看不见也没批准过策略。
> 这就是 P3 的现场证据，也是 3.13.0 那次「沙箱 uid 映射致误判 root」的同形复发（见「P3」一节）。
>
> 只读输入按锚定版本引用：`request-lifecycle.md @ 70a7dd50`（647 行，sha256[:16] `6fcd3973ede30b88`）；
> `refact-fable.md`（927 行，sha256[:16] `89303624bfd9ef27`，master `7e8464c2`）；两文件本候选未改动一字。
> 协议按标签 `runtime/protocol`（601 行，sha256[:16] `1c1f0cf9383df450`）。引用一律按标题不按章节号；
> 凡 `文件:行` 锚点均在本分支索引或 `~/repo/codex` 可达。

---

## 0. 一页摘要

1. **对象层只有一个运行时**，它就是 `request-lifecycle.md`「两层状态机」那一个状态机加七个对象的**写入面**。
   开发落为 Task Profile **`dev.change`**（版本 1）；五家助手落为 Agent Profile
   **`ap.luna` / `ap.kimi` / `ap.cursor` / `ap.fable` / `ap.qwen`**（裁决方 `ap.opus` 不参赛但同表登记）。
   人不是执行者，是 **principal**：登记在 `[principal.owner]`，权力表引用它的名字。
2. **bootstrap 与目标态是同一个 Task Profile 的两种 orchestrator 实现**：`orch.manual`（人 + `round-*.py`，git 当账本）
   与 `orch.service`（服务，PostgreSQL 当账本）。git 有两个角色要拆开看：**当账本是脚手架，当 Artifact 载体是永久的**。
   每件脚手架各写一条拆除条件（「bootstrap 与目标态」一节），条件全部是「服务态轨迹在**来源等级**上不低于手工态」。
3. **等效判据（改写 OP-1）**：轨迹条目除四要素外必须带**来源等级** `attested / reported / inferred` 与**权力行**。
   理由是实证：`refact-fable` 那一轮全部产物落在**一个** commit（`7e8464c2`）里，六个版本、八条裁定、五家终审，
   账本上可证实的只有两条。手工模式「看起来在跑」，轨迹却基本不可复原——不带来源等级的等效比对会把这当成「全等」。
4. **Interaction 双向带载荷是内核修订**（改写 OP-2）：出向加 `artifact_ref / render / editable / evidence_grade / options[]`，
   入向加 `decision ∈ {approve, reject, amend}` + `amend{base_version, …}`；amend 载荷成为**新 Artifact 版本（作者 = principal）**
   并进入下一个 Attempt 的 `input_artifact_versions`。响应者身份由运行时鉴别，**不在载荷里自报**——这是 R2 那条极端案例的落点。
5. **可观测粒度是 Agent Profile 的三个字段，不是一个**：`observability`（能看多细）、`enforcement`（能在哪拦）、
   `sandbox`（谁提供）。只有 `tool.enforced` 的事件算证据；其余全部是**主张**，证据由运行时从工作区重新推导。
   现场取证：`codex exec --json` 能逐工具调用吐 JSONL（`~/repo/codex/codex-rs/exec/src/cli.rs:60`），但那是执行者**自报**，
   运行时拦不住也验不了，所以它是介于两档之间的第三档 `tool.reported`。
6. **必答 Q**：四条机械分类规则（工单字段直接判）；反例是「单文件笔误 / 一次性提问 / 对 `dispatch = manual` 执行者的分发」；
   T0 上界 = **人的必需动作 ≤ 2 且不多于手工同一任务**；绕过靠**底座对账**（每条落到受控分支的 commit 必须归属某个 Attempt）
   而不是靠账本自省——账本看不见绕过，但 git 看得见「没登记的提交」。
7. **任务书自己造了一个同名物**：`runtime` 在本轮同时指「产品运行时」「内核 §0.1 的 Agent runtime」和登记表分组键（= codex-cli 这类 harness）。
   建议登记表字段改名 **`harness`**。

---

## 1. 利益申报：上一稿错在哪，我为什么不辩护

我是 `refact-fable.md` 的起草者，本轮的前提是那份稿子的 A/B 分层错了。先把这条说清，再写方案。

上一稿把「持久层 git ↔ PG、执行者 CLI ↔ SDK、通道、guard、状态判定」五格取值不同的两种部署形态各自叫成一个 Profile
（`sunmoonai/docs/dev-plan/refact-fable.md:180` 用来杀第三个 Profile 的理由——「五格全同只差 guard，是档位不是 Profile」——
对 A/B 同样成立，只是差的是取值而不是结构）。更糟的是用词：内核 `sunmoonai/docs/dev-plan/working/request-lifecycle.md:103-104`
已经定义了 Task Profile 与 Agent Profile，上一稿在这两个词之外造了第三个「Profile」含义。这正是它自己 §1.2 诊断的「同名物」病。

**幸存的部分我照用**：3.1.1 那张「产物 → 唯一状态机」映射表的**边**没有错（cursor D1 抓过 `WAITING → SUCCEEDED`，已改）；
3.3 权力表的形状（转换 + eligible_principal + enforcement_point）没有错；3.11「git 验不了事务 / 租约 / fencing」没有错；
3.13 三道边界没有错——错的是把它归在「bootstrap 威胁模型」里。本文把这几样换到正确的对象上：**映射表的左列不再是某个
「Profile 里的东西」，而是 Task Profile `dev.change` 的产物；权力表不再是「某个 Profile 的 guard」，而是运行时对所有 Task Profile 共用的 principal 权力模型。**

另一条要如实登记：`refact-fable` 那一轮**起草者兼整合者**（五家评审由我自己吸收），按协议「角色不分会怎样」这是缺角色的形态。
它能过，是因为所有者当天亲自裁了八条（`sunmoonai/docs/dev-plan/rounds/refact-fable/rulings.md:11-16`）。下面的 trace 样例会把这件事的账本后果摆出来。

---

## 2. P1 — 一个运行时、唯一状态机、`dev.change`、五个 Agent Profile

### 2.1 运行时是什么：内核对象的唯一写入面，加上四个确定性组件

不造新词。运行时 = 内核七个对象（Task / Attempt / Interaction / Artifact / Event / Side Effect / Delivery）的**唯一权威写入面**（I13），
加上四个必须是确定性代码的组件（沿用 `refact-fable.md` 3.9 的五词，其中 arbiter / acceptor / approver 是角色，不是组件）：

| 组件 | 职责 | 内核依据 |
| --- | --- | --- |
| **router** | 从请求算出 Task Profile 版本、tier、执行者候选、工作区计划；三值 `decide / ask / refuse` | 「解释、边界与完成契约」；`F-ADMIT-*` |
| **orchestrator** | 推进 Task / Attempt 状态（只走「合法转换」表里的边）、派发、收集、观测逾期、回退 | I4「状态转换集中校验」 |
| **interaction service** | 产生 Interaction、鉴别响应者、原子消费、把 amend 落成 Artifact 版本 | 「WAITING 与 Interaction」；`F-INTERACT-01` |
| **validator** | 按 Task Profile 版本跑 acceptance 的机械部分；判不了的显式交给 acceptor 角色 | `F-ACCEPT-01`；协议「判据自身的质量」 |

再加两个**适配层**，它们是 P3 的落点：**executor adapter**（按 Agent Profile 的粒度字段选择怎么调、怎么看、怎么拦）与
**principal channel**（人怎么被叫到、怎么回，且响应者身份如何鉴别——R2 说现在这个通道的证据强度为零）。

### 2.2 Task Profile `dev.change` 版本 1

按内核「Task Profile 是版本化产品契约」的字段（`request-lifecycle.md` 「Task Profile 与 Agent Profile」）逐项给出：

```text
profile_id            dev.change
version               1
input_schema          工单：goal(自然语言) · paths[]＝允许触及的路径集 · baseline_commit · read_only_inputs[]＝路径+版本锚
                      · tier ∈ {T0,T1,T2}(router 建议、人可改) · executors{proposers[], arbiter, acceptor}(T1/T2)
                      · acceptance[]＝逐条编号；T0 = 一个已签任务类包名
output_schema         一个或多个 Artifact 落在 final_path(s)，版本 = commit；T1/T2 另有 disposition Artifact
frontend_renderer     diff / 全文 / 结构化摘要 三种（与 Interaction 出向 render 同一枚举）
normalization_rules   goal → 可判定 acceptance 条；歧义实质改变结果/权限/成本/风险时才 ask（内核 :180）
required_context      read_only_inputs 按版本锚取；候选不得改动它们（本轮 §8-9 就是这条的实例）
acceptance            机械条（validator 跑：零命中正则、冻结区逐字节、锚点可达、diff ⊆ paths、身份行）
                      + 判断条（acceptor Agent Profile 跑，按冻结标准逐条给结论，不得改标准）
evidence              每条断言现状的句子附 file:line 或可复跑命令；证据等级按 P3 规则重新推导
freshness             baseline_commit 固定；基线移动 → 新 Task（内核「终态、刷新与重新处理」）
allowed_capabilities  读整仓、写自己 worktree、不 push 主线（H5 在凭据层）
default budget        观察窗规则 W = 已交付各家用时中位数（协议「参与方不可用」）、max_rollbacks = 2
retry                 逾期 → 该家 Attempt FAILED(timeout)，Task 不失败（I8）；N 降到 1 停轮 ask
approval              权力表行 H1–H8（2.4）；tier 决定开工前 APPROVAL 触点数 0/1/2（沿用 refact-fable §8 第 5 条）
privacy               文档任务无；财务数据任务另由其 Task Profile 定（NO ZDR 核实前不得跑，task.md §6.2.1）
```

**tier 不是三个 Task Profile**，是 `execution_policy` 里的一个字段——它改的是 Attempt 的组数与审批触点，不改输入 / 输出 / 验收的**形状**。
T2 的七环节在这个契约里是 **execution_policy 定义的 Attempt 阶段图**：① N 个并行 proposer Attempt → ② N 个 reviewer Attempt →
③ 一个 arbiter Attempt → ④ 被处置到的家各一个 objector Attempt → ⑤ 一个 acceptor Attempt → ⑥ 一次 `WAITING(APPROVAL)` → ⑦ 一个 publisher Attempt。
每个阶段的 Attempt 记 `attempt.kind ∈ {proposer, reviewer, arbiter, objector, acceptor, publisher}`，产物是 typed Artifact。
这是 `refact-fable.md` 3.1.1 的选择（「Attempt 可产出 typed Artifact」而非「每环节一个子 Task」），理由不变：子 Task 方案要让协调 Task
等全部子 Task 完成，与内核「协调 Task 不等待被协调 Task 全部完成」相撞。⚠ 这一条仍是对 Attempt **产物类型**的细化，是否算内核扩充要在 3.5 的修订单元里一并裁。

### 2.3 五个 Agent Profile：登记表

按内核「Agent Profile 声明执行能力：模型、prompt、工具绑定、权限边界、memory policy 和支持的 Task Profile」，再加 P3 的三个粒度字段与登记形状修正。
**字段 `harness` 取代上一稿的 `runtime`**（理由见 6.4）。

```toml
[ap.luna]
harness        = "codex-cli"          # 二进制 + 提示词 + 工具集
provider       = "openai"
model          = "gpt-5.6"            # ⚠ argv 未钉 --model，实际取 $CODEX_HOME 配置；未核
model_pinned   = false
dispatch       = "argv"               # argv | manual
observability  = "process"            # 现值；可升 tool.reported（codex exec --json，见 4.1）
enforcement    = "outer-only"         # 见 4.4
sandbox        = "self"               # 助手自带；策略可经 -s 请求，执行不可验
workspace_isolation = "convention"    # 见 4.5
roles_allowed  = ["proposer", "reviewer", "objector", "acceptor"]
supports       = ["dev.change/1"]

[ap.kimi]
harness = "codex-cli"     provider = "moonshot"   model = "kimi-k3"   model_pinned = false   # ⚠ 同上
dispatch = "argv"         observability = "process"   enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"   roles_allowed = ["proposer", "reviewer", "objector", "acceptor"]

[ap.cursor]
harness = "cursor-agent"  provider = "xai"        model = "cursor-grok-4.6-high"   model_pinned = true   # 所有者口述 + argv 已钉
dispatch = "argv"         observability = "process"   # 可升 tool.reported：agent --help 列 --output-format stream-json；⚠ 是否含工具调用未核
enforcement = "outer-only"   sandbox = "self"    # agent --help 列 --sandbox <mode>
workspace_isolation = "convention"   roles_allowed = ["proposer", "reviewer", "objector", "acceptor"]

[ap.fable]
harness = "cursor-app"    provider = "anthropic"  model = "claude-fable-5.1"   model_pinned = false   # ⚠ GUI 内选择，不可机械核验
dispatch = "manual"       # 无 argv；分发 = 所有者打开应用于 worktree 并粘贴指令（权力表 H0）
observability = "fs-only" # 无 argv、无 stdout；运行时只能看 commit 与文件系统前后差
enforcement = "outer-only"   sandbox = "self"    # 本文取证声明：uid_map 0 1003 1；策略由应用定
workspace_isolation = "convention"   # 本会话读了 ~/repo/codex 与 /tmp——沙箱允许读整机
roles_allowed = ["proposer", "reviewer", "objector"]   # 本轮不得任 acceptor（task.md §9）

[ap.qwen]
harness = "qoder"         provider = "alibaba"    model = ""   model_pinned = false   # ⚠ task.md §6.2.1 provider 栏为「—」，此处为推断
dispatch = "argv"         observability = "process"   # qoder --help 列 -o/--output-format；⚠ 内容未核
enforcement = "outer-only"   sandbox = "self"    # ⚠ 未核
workspace_isolation = "convention"   roles_allowed = ["proposer", "reviewer", "objector", "acceptor"]

[ap.opus]                 # 裁决方，不参赛
harness = "claude-code"   provider = "anthropic"  dispatch = "argv"   observability = "process"
enforcement = "outer-only"   sandbox = "self"   workspace_isolation = "convention"
roles_allowed = ["arbiter", "publisher"]

[principal.owner]         # 人：不是执行者，没有 harness / dispatch / observability
channel        = "inbox+commit"       # 现状；目标态 = 运行时鉴别的响应端点（4.6）
channel_grade  = "shared-credential"  # R2：与 agent 同机、同 git 身份，证据强度零
```

`observability` 五家逐条已填（§8-5 机械判）；表中没有任何条目以 `kind` 标人（§8-2 机械判）。⚠ 标注的全是未核项，不是缺项。

### 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行

权力表沿用 `refact-fable.md` 3.3 的 H1–H7（该轮 §8 第 2 条幸存），**加两行**：

| 行 | 状态转换（唯一状态机的词） | eligible_principal | auto_policy | enforcement_point |
| --- | --- | --- | --- | --- |
| **H0** | **代行 orchestrator 的传输动作**：Attempt `CREATED → RUNNING` 的派发、`COMPLETED` 的收集 | `owner` | **有**：目标态全自动；现状对 `dispatch = manual` 的执行者为人 | 无（它不是权力，是欠账；进表是为了**可数**——Q3/Q4 都要数它） |
| H1 | 工单 Artifact `DRAFT → FROZEN`；Task `WAITING(APPROVAL) → VALIDATING` | `owner` | 无；T0 由已签任务类包承担 | validator 查回执 |
| H2 | Task `VALIDATING → QUEUED`（开工确认） | `owner` | 有：T0 + `decide` | orchestrator 不分发 |
| H3 | 省事方向裁定 | `owner` | 无 | validator 校验裁定行 + 回执 |
| H4 | 扩权 | `owner` | 无 | 同 H3；目标态为工具网关 |
| H5 | 不可逆 Side Effect（写共享最终路径 / push 主线 / 发布） | `owner` | 无 | **凭据层**（主仓对 agent 域只读） |
| H6 | 推翻裁定 / 改冻结验收条 | `owner` | 无 | 冻结区逐字节 + 回执 |
| H7 | Task → `CANCELLED` | `owner` | 无 | 裁定行（表内唯一不锚仓外的行） |
| **H8** | **回答本 Task 的 `WAITING(INPUT)` Interaction，含 amend**：`WAITING → VALIDATING`（验证期）或 `WAITING → QUEUED`（执行期） | `requester`（开发任务里 = `owner`） | 无 | interaction service 鉴别响应者；amend 越出 `editable` 判无效响应 |

九行，≤ 10。H8 是 P2 逼出来的：上一稿说「权力表只管 APPROVAL，INPUT 类按内核规则产生」，但**谁有权回答、回答能不能带内容改动**，
内核没说、表也没说，于是 `refact-fable` 轮里所有者对 R3–R8 的实质裁决在账本上没有落点。

**§8-2 逐条清单：本轮（`runtime`）与上一轮已发生的每一次人的介入**

| # | 介入（可复核出处） | 唯一状态机的边 | 行 |
| --- | --- | --- | --- |
| 1 | 所有者 09-05 提出四条推翻性判断（`task.md` §1.2）——对已 `SUCCEEDED` 的 `refact-fable` Task 而言是「推翻旧决定」 | 不是任何边：终态不可转出 → 建**新 Task** `runtime`，`supersedes = refact-fable`（`request-lifecycle.md:297-301`） | — （内核规则，非权力） |
| 2 | I-01 H6 解冻 `refact-fable` R1 三处（`sunmoonai/docs/dev-plan/rounds/runtime/inbox-owner.md:13`） | `runtime` Task `WAITING(APPROVAL) → VALIDATING` | H6（朝省事的半条：§8-7 作废） |
| 3 | I-02 H1 冻结 `task.md` §8 十条（`inbox-owner.md:41`），签发 `94558713` | `runtime` Task `WAITING(APPROVAL) → VALIDATING → QUEUED` | H1（+ H2 合并：T2 本应分离，本轮合并了——⚠ 与 refact-fable §8 第 5 条「T2 = 2」不符，登记为观察值） |
| 4 | R1 选协议版本、R3 指路补丁的「人确认 = 是」（`opus:…/rounds/runtime/rulings.md`） | 同上一 Interaction 内消费 | 中性偏严谨：agent 记录即可，人签是附带，不另计触点 |
| 5 | R2 回执强度为零仍沿用 bootstrap 例外 | 同上 | H3（更省事） |
| 6 | 所有者打开 Cursor 于 `~/worktrees/fable/k8s`、粘贴固定指令 + 取件命令（本次） | `ap.fable` 的 proposer Attempt `CREATED → RUNNING`；Task `QUEUED → RUNNING` | **H0** |
| 7 | 将来的 ⑥ 确认 | `WAITING(APPROVAL) → QUEUED` → publisher Attempt `RUNNING → COMPLETED` → Task `RUNNING → SUCCEEDED` | H5 |
| 8 | `refact-fable` 轮 R3（T0 的 H1 在策略层完成）、R4（回执仓）、R7（主仓写权限移出）、R8（R0′ 按 T2）——所有者在选项间裁 | `WAITING(INPUT) → QUEUED`（执行期澄清） | **H8**（approve 某一 option） |
| 9 | `refact-fable` 轮 R6（T0 可逆出口**不加**） | 同上 | **H8**（reject） |
| 10 | `refact-fable` 轮 R5（全表回执仓锚定） | 同上 | H8（approve）；方向更严谨 |
| 11 | `refact-fable` 轮 R1 冻结 §8 + commit `7e8464c2` 进 master | `WAITING(APPROVAL) → QUEUED` → publisher → `SUCCEEDED` | H1 + H5 合并在一个 commit 里（⚠ 两个不同的权力行由同一动作承担，账本无法区分） |

无缺项：每行都有边、都有行。第 1 行是「没有边」的正确答案而不是缺项——它恰好说明「全部否定」在内核里的落点是 `supersedes`，不是 Interaction。

### 2.5 `dev.change` 的产物 → 唯一状态机（替换上一稿 3.1.1）

只列与上一稿不同或需重述的行；状态词与边全部 ⊆ 内核（`request-lifecycle.md:222-228`、Attempt 图）。

| `dev.change` 的产物 / 事件 | Task | Attempt | 说明 |
| --- | --- | --- | --- |
| 工单文件出现 | `RECEIVED` → 即刻 `VALIDATING` | — | 空转不停留 |
| 工单 `DRAFT`（Artifact 状态） | `VALIDATING` | — | Artifact 状态不是 Task 状态 |
| router `ask`（tier / executors 待人填） | `VALIDATING → WAITING(INPUT)` → 回 `VALIDATING` | — | H8 |
| H1 冻结 | `WAITING(APPROVAL) → VALIDATING` | — | 验证期等待回 `VALIDATING`（内核 :269） |
| H2 开工 | `VALIDATING → QUEUED` | — | T0 按策略放行 |
| 派发（`call-①.md` 落盘或 adapter 起进程） | `QUEUED → RUNNING`（首个 Attempt 获租约） | `CREATED → RUNNING` | **fable 这一步由 H0 承担** |
| 某家交付并 commit | `RUNNING` | `RUNNING → COMPLETED` | 产出 typed Artifact，不等于 Task 成功 |
| 某家逾期 | `RUNNING` | `FAILED(timeout)` | I8 |
| 执行期澄清 / 所有者裁选项（R3–R8 型） | `RUNNING → WAITING(INPUT)` → `QUEUED` → `RUNNING` | 在跑的 → `WAITING`（`refact-fable` 3.1.1「中途 H 视为全 Task 暂停」） | H8；执行期等待先回 `QUEUED`（内核 :269-270） |
| ④⑤⑥ 回到 ③ | `RUNNING` | 新 Attempt；旧的终态不重开 | I5 |
| ⑥ 确认待人 | `RUNNING → WAITING(APPROVAL)` | — | H5 |
| ⑥ 回执成立 | `WAITING → QUEUED` | publisher `CREATED` | 不是 `WAITING → SUCCEEDED` |
| ⑦ 发布 | `RUNNING → SUCCEEDED` | publisher `COMPLETED` | Side Effect 过凭据层 |
| 无获准成功路径 | `RUNNING → FAILED` | — | |
| H7 | `→ CANCELLED` | 在跑的 `CANCELLED` | |

### 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现；脚手架清单与拆除条件

先把 git 的两个角色拆开：

- **git 当 Artifact 载体**——代码与文档 Artifact 的版本就是 commit，`baseline_commit` 就是 `input_artifact_versions`。**这是永久的**，
  `dev.change` 的 output_schema 就长这样；财务分析 Task Profile 的 Artifact 载体会是对象存储，各 Profile 自己定。
- **git 当账本**——用 commit 历史 + `rulings.md` + `events.jsonl` 反推 Task / Attempt 状态，用 `round.md` 的 toml 当 Task 主档。**这是脚手架。**

| 运行时组件 | `orch.manual`（现状） | `orch.service`（目标态） | 拆除条件（全部机械） |
| --- | --- | --- | --- |
| Task 主档 | `rounds/<id>/round.md` toml 块 | `task` 表 | 服务态对 ≥1 个 T0、T1、T2 真实 Task 产出的轨迹，与手工态同 tier 的历史轨迹按 2.7 比对**全等**，且每个条目类别的 `attested` 计数 ≥ 手工态 |
| Event 日志 | commit 历史 + `rulings.md` + `events.jsonl`（agent 可写面，是投影） | `event` 表（只追加） | 同上；另加：`round-status.py` 与服务态状态投影对同一历史轮次输出相同状态序列（新判据首跑先与人工对照） |
| Interaction | `call-<环节>.md` + `inbox-owner.md` + 裁定行 + 所有者 commit | `interaction` 表 + 鉴别响应者的端点 | **R2 前置**：所有者拥有 agent 够不着的操作面，响应者身份 `attested`；在此之前服务态的 Interaction 与手工态一样是 `reported`，**不得拆** |
| 派发 / 收集 | `round-dispatch.py` 生成命令 + 人粘贴（H0） | executor adapter | 该 Agent Profile 的 `dispatch = argv` 且 adapter 已对它跑通一次 Attempt；`dispatch = manual` 的（fable）**永远由 H0 承担**，不是拆除对象而是登记对象 |
| validator | `round-status.py --verify` | acceptance runner | 对 `refact` / `refact-fable` / `runtime` 三轮的历史产物，两者判定逐条一致 |
| 工作区供给 | 人或脚本 `git worktree add` | provision 服务 | `git worktree` 本身留（它是载体侧）；供给的**判据**（独占 × 干净 × 基线）进代码并有测试 |
| principal 通道 | 共享 git 身份 + 回执仓（S1 产物） | 运行时鉴别的会话 | 与 Interaction 行相同；回执仓是「鉴别响应者」这条**架构要求**的手工态实现，拆它的条件是服务态提供了强度不低于它的鉴别 |

「先在这一层跑通，再往下实现」（`refact-fable.md:242`）的准确表述由此是：**手工态跑通的是对象形状、边、Interaction 形状与权力行；
它跑不通的是并发语义（事务 / 租约 / fencing，`refact-fable.md` 3.11）和证据的 `attested` 等级——后者是 P3 的结论，与载体无关。**

### 2.7 等效判据：带来源等级的轨迹（对 OP-1 的改写）

轨迹条目 schema：

```text
trace_entry = {
  seq                      Task 内单调
  layer                    task | attempt | interaction | artifact
  subject_id               task_id / attempt_id / interaction_id / artifact_id
  from → to                状态边（task/attempt 层）；version_from → version_to（artifact 层）；request → decision（interaction 层）
  actor                    执行者 Agent Profile id，或 principal id，或 orchestrator
  power_row                触发本边的权力表行（H0–H8）或 "—"
  payload_ref              interaction 层：出向 artifact_ref + 入向 decision/amend 的 Artifact 版本
  at                       时间（载体差异，不参与比对）
  provenance               attested | reported | inferred      ← 新增
  evidence_ref             commit / 表行 / 文件:行                ← 新增
}
```

`provenance` 三值：**attested** = 由运行时从它控制的底座直接取得（账本里的 commit 哈希、经鉴别的响应）；**reported** = 执行者或人的自报
（修订记录、对话、`rulings.md` 里写的时间）；**inferred** = 事后读产物推出来的。

**比对规则**：两条轨迹**等效**，当且仅当把 `at / provenance / evidence_ref` 投影掉之后，`(layer, subject 角色, from→to, actor 角色, power_row)`
的序列相同，且 Artifact 版本的血缘图（`derived_from`）同构。**允许不同**：载体、orchestrator 实现、`at`、执行者粒度**的取值**；
**不允许不同**：状态词、边、对象、Interaction 形状、`power_row`。

**在 OP-1 之上加的两条**：

1. **等效只能在两条轨迹的最低来源等级上宣称。**一条全是 `reported` 的手工轨迹与一条全是 `attested` 的服务轨迹「全等」，
   证明的只是服务态**没有多走边**，证明不了手工态**真的走过那些边**。所以比对结论必须附 `attested` 计数，拆除条件用的就是它。
2. **Artifact 版本的作者拆成 `author_claimed` 与 `author_attested`。**下面样例里全部版本 `author_attested = none`。

### 2.8 trace 样例：`refact-fable` 轮的真实产物

数据来源全部可复跑：`git log --format='%h %ad %an' --date=iso -- sunmoonai/docs/dev-plan/refact-fable.md sunmoonai/docs/dev-plan/rounds/refact-fable/`
只有**一条**：`7e8464c2 2026-09-05 13:05:50 +0800 sunmoonlion`。其余时间来自 `sunmoonai/docs/dev-plan/refact-fable.md:5-40` 的修订记录与
`sunmoonai/docs/dev-plan/rounds/refact-fable/rulings.md:9-16` 的裁定行。Task id 记为 `refact-fable`；状态词全部 ⊆ `request-lifecycle.md @ 70a7dd50`。

| seq | layer | subject | from → to / version | actor | power_row | at | provenance | evidence_ref |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | task | refact-fable | — → `RECEIVED` | owner | — | 09-05 上午 ⚠ | reported | `refact-fable.md:45`「回应所有者 2026-09-05 提出的调整思路」；无工单文件 |
| 2 | task | refact-fable | `RECEIVED → VALIDATING → QUEUED` | orchestrator(人) | H1/H2 **缺** | — | inferred | 无 `round.md`、无冻结验收条；契约事后由 §8 补 |
| 3 | task | refact-fable | `QUEUED → RUNNING` | ap.fable | H0 | — | reported | 所有者在 Cursor 里投喂（且在 cursor 的目录，`refact-fable.md:3`「经 Cursor」） |
| 4 | attempt | A1 fable proposer | `CREATED → RUNNING → COMPLETED` | ap.fable | — | ≤11:30 | reported | 产出 v0；无 commit |
| 5 | artifact | refact-fable.md | v0 → v1 | claimed fable / attested none | — | 11:30 | reported | `refact-fable.md:6`「吸收 opus 评审」 |
| 6 | attempt | A2 opus reviewer | `COMPLETED` | ap.opus | — | <11:30 | reported | **产物未归档**：`reviews/` 无 opus 首轮评审文件 |
| 7 | attempt | A3 luna reviewer | `COMPLETED` | ap.luna | — | <11:45 | reported | **产物未归档**（同上） |
| 8 | artifact | refact-fable.md | v1 → v2 | claimed fable | — | 11:45 | reported | `refact-fable.md:7` |
| 9 | attempt | A4 kimi / A5 qoder reviewer | `COMPLETED` | ap.kimi / ap.qwen | — | <12:00 | inferred | `reviews/review-refact-fable-kimi.md`（150 行）、`-qoder.md`（210 行）存在于 `7e8464c2` |
| 10 | interaction | R3 | request(T0 的 H1 如何解) → **approve** option#4 | owner | H8 | 11:56 | reported | `rulings.md:11`；同 commit、同身份 |
| 11 | interaction | R4 | request(信任锚) → approve「回执仓」 | owner | H8 | 11:56 | reported | `rulings.md:12` |
| 12 | task | refact-fable | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | orchestrator | H8 | 11:56 | inferred | 由 10–11 推出，账本无边 |
| 13 | artifact | refact-fable.md | v2 → v3 | claimed fable | — | 12:00 | reported | `refact-fable.md:13` |
| 14 | attempt | A6 cursor reviewer | `COMPLETED` | ap.cursor | — | <12:15 | inferred | `reviews/review-refact-fable-cursor.md`（274 行） |
| 15 | interaction | R5 / R6 | approve（全表锚定）/ **reject**（可逆出口） | owner | H8 | 12:13 | reported | `rulings.md:13-14`「所有者 12:13 点头」 |
| 16 | artifact | refact-fable.md | v3 → v4 | claimed fable | — | 12:15 | reported | `refact-fable.md:19` |
| 17 | attempt | A7–A11 五家 reviewer（终审） | `COMPLETED` ×5 | 五家 | — | <12:40 | inferred | `reviews/review-final-*.md` 五份存在 |
| 18 | interaction | R7 / R8 | approve「移」/ approve「按 T2」 | owner | H8 | 12:34 | reported | `rulings.md:15-16` |
| 19 | artifact | refact-fable.md | v4 → v5 | claimed fable | — | 12:40 | reported | `refact-fable.md:24` |
| 20 | attempt | A12 luna（撤销 REQUEST CHANGES） | `COMPLETED` | ap.luna | — | 12:49 | reported | `refact-fable.md:38`；「终端记录」原文在 `rounds/refact-fable/rulings.md:9`；**无产物** |
| 21 | artifact | refact-fable.md | v5 → v6（927 行） | claimed fable | — | 12:58 | reported | `rulings.md:5` 哈希 `89303624bfd9ef27` |
| 22 | interaction | R1 | request(冻结 §8 九条) → approve | owner | H1 | 13:05 | **attested**（存在）/ reported（身份，R2） | commit `7e8464c2` 存在且含 R1 行 |
| 23 | task | refact-fable | `RUNNING → WAITING(APPROVAL) → QUEUED → RUNNING → SUCCEEDED` | orchestrator / publisher | H1 + H5 | 13:05:50 | **attested**（终态）/ inferred（中间边） | `7e8464c2` 在 master |

**读数**：23 条里 `attested` 2 条（且身份都不 attested），`reported` 15 条，`inferred` 6 条；Artifact 六个版本零 commit；
两个 reviewer Attempt（opus、luna 首轮）**有事件无产物**；H1 与 H5 由同一 commit 承担，账本分不开；Task 的 `VALIDATING` 阶段没有任何契约产物。
这条轨迹与「一个运行时按 `dev.change/1` 跑一遍 T2」的目标轨迹在**边**上对得上（这正是 OP-1 想要的），但**只能在 `reported` 等级上宣称等效**。
这就是「手工模式看起来在跑、实际没有可搬运的形状」（`task.md:167` 之后那段）的账本版。

对照组（不在 §8-3 要求内，附作参考）：`refact` 轮的整合分支 `refact/baseline-master..refact/integration` 有 **28 条**逐主张提交，
③④⑤ 每条处置各占一个 commit——同一个 Task Profile、同一 orchestrator 实现，`attested` 条目数量级不同。差别不在载体，在纪律是否落成动作。

---

## 3. P2 — Interaction 双向带载荷：一个内核修订工作单元

### 3.1 缺口

内核 Interaction 绑定字段（`request-lifecycle.md:257-264`）只有 `question_or_action` 一个出向自由文本、`resume_token_hash + consumed_at` 一个布尔入向。
所有者第 3 条判断（全部否定 / 部分否定 / 以人的方案替代）三者之中，只有「全部否定」能用现有形状表达——而且是错误地表达：
拒绝一条分发方案后若走内核 :297「建新 Task」，目标没变、口径没变、授权没变、Profile 版本没变，四个条件一个都不命中；
它就是同一个 Task 的下一个 Attempt。

2.8 的样例把这条缺口量化了：R3–R8 六次所有者裁决全部是 H8 型响应，账本上**没有一条**是 Interaction 对象——它们以 `rulings.md` 的行存在，
而那是**执行者**写的文件。

### 3.2 扩展后的绑定字段表

```text
—— 出向（运行时 → 受众）——
task_id, interaction_id, expected_state_version          # 不变
wait_reason            INPUT | APPROVAL | DEPENDENCY | RESOURCE | EXTERNAL     # 不变（内核 :249-255）
power_row              H1..H8 中的一行；INPUT 类固定 H8                        # 新增：让「谁在哪条边上有权」进轨迹
question_or_action     不变，但降为「人读摘要」，不再是唯一载荷
artifact_ref           {artifact_id, version}   展示哪个 Artifact 的哪个版本   # 新增
render                 diff{base_version} | full | summary{schema}            # 新增：与 Task Profile 的 frontend_renderer 同一枚举
editable               [json_pointer | path_glob]   人可编辑的范围            # 新增：机械可判的集合，不是散文
evidence_grade         attested | reported | inferred   被展示 Artifact 的证据等级（P3 推导值）   # 新增
options[]              [{option_id, summary, artifact_ref?}]   选项型审批（R7「移」这种）   # 新增
audience, expires_at, resume_target                     # 不变

—— 入向（受众 → 运行时）——
resume_token_hash, idempotency_key, consumed_at         # 不变
decision               approve | reject | amend                                # 新增：三值
reason                 reject 必填；approve/amend 可选                         # 新增
option_id              decision = approve 且出向有 options[] 时必填            # 新增
amend                  {base_version, patch | full_content, target ⊆ editable} # 新增
responder              由运行时从鉴别上下文确定，不由载荷自报（同内核 :143 对 requester 的要求）   # 新增
response_grade         attested | reported   响应者身份的证据等级（现状全部 reported，R2）      # 新增
```

### 3.3 amend 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task

1. interaction service 校验 `amend.target ⊆ editable`；越界 → **无效响应**（拒绝消费令牌，`AT-07` 的「异键」类），不是新 Task、也不是新版本。
2. 通过则写一个新 Artifact 版本：`author = responder`（principal），`derived_from = amend.base_version`，`created_by_interaction = interaction_id`。
   **部分否定**：`base_version` = 被审的 agent 版本；**以人的方案替代**：`base_version` = 上一个人类版本或空（血缘不接 agent 版本）。
   三值够用，不需要第四值——「替代」和「修改」的区别在血缘边上，不在 decision 上。
3. 原子消费令牌后 Task 按内核回边：验证期 `WAITING → VALIDATING`，执行期 `WAITING → QUEUED`；orchestrator 建新 Attempt，
   `input_artifact_versions` 含该人类版本。**内核 Attempt 记录已有这个字段（`request-lifecycle.md:325-327`）**，不必新增。
4. `reject`：不写版本；Task 回边后由 execution_policy 决定新 Attempt 或 `FAILED`。`approve`：不写版本；若有 `option_id` 落入 Event。

**它不是开发期特有的**：财务分析 agent 交一份分析计划（Artifact `plan` v3）给人审，出向 `render = diff{v2}`、`editable = ["/steps/*/data_source", "/assumptions"]`；
人改两条数据源 → `amend{base_version: v3, target: ["/steps/2/data_source", …]}` → `plan` v4（author = 人）→ 下一 Attempt 照 v4 执行。
形状与本轮 I-01 / I-02 完全相同。

### 3.4 与权力表的对应

| 行 | wait_reason | 典型 artifact_ref | render | editable | 允许的 decision |
| --- | --- | --- | --- | --- | --- |
| H1 | APPROVAL | 工单 `DRAFT` 版本 | full | `acceptance[]`, `executors`, `tier`（上一稿「无默认必填」三项） | approve / reject / amend |
| H2 | APPROVAL | RouteDecision | summary | `executors`, `workspace_plan` | approve / amend |
| H3/H4/H6 | APPROVAL | 裁定行草稿 | diff | 全行 | approve / reject |
| H5 | APPROVAL | 待发布 commit | diff{baseline} | **空**——不可逆动作不接受 amend，要改回 ③ | approve / reject |
| H7 | APPROVAL | 副作用清单 | full | 空 | approve / reject |
| H8 | INPUT | 被澄清的 Artifact 版本 | diff / full | 由 Attempt 声明 | approve(option) / reject / amend |

### 3.5 修订工作单元：边界、影响分析、迁移

按 `request-lifecycle.md:627` 的修订纪律。**显式声明：这是内核修订，不是 Task Profile 层能自己解决的。**

| 项 | 内容 |
| --- | --- |
| **原始请求** | 所有者第 3 条判断；本文 3.1 的量化证据（2.8 样例第 10、11、15、18 行） |
| **边界（改哪）** | ①「WAITING 与 Interaction」的绑定字段块（:257-264）→ 3.2 表；② `F-INTERACT-01` 加「响应可携带 amend 载荷并成为 Artifact 版本」；③「核心对象」表 Interaction 行的定义由「请求输入以及对方的响应」改为「…响应含决定与可选的 Artifact 修订」；④ §6.2 持久化记录 Interaction 行（:479）加 decision / amend 版本引用；⑤ `AT-07` 加两条：越界 amend 被拒；amend 版本进入下一 Attempt 输入。**顺带**：:26-27 那句用了本轮禁用的 Profile 用法，改为「只能进入 Task Profile `dev.change` 或 development-lifecycle-agent.md」 |
| **不改** | 状态词、合法转换表、Task / Attempt 终态语义、幂等与租约纪律。amend 全部走既有边 `WAITING → VALIDATING | QUEUED` |
| **影响分析** | 前端：Interaction 投影要能渲染 `artifact_ref + render + editable`（`F-DELIVERY-*` 的展示侧）；后端：Artifact 版本写入面多一个来源（principal）；Agent：`F-EXEC-07` 请求输入时**必须**给 `artifact_ref` 与 `editable`（不给 = 只能 approve/reject 的旧形状，仍合法）；验收器：`F-ACCEPT-01` 检查结果时要能看到「哪些输入版本是人写的」——`I11` 证据账已有「生成者」栏 |
| **迁移** | 字段全部可选新增，旧 Interaction 视为 `editable = []`、响应视为 `decision = approve`；`payload_schema_version` 递增；历史 Task 不回填。手工态：`inbox-owner.md` 条目加 `artifact_ref / render / editable` 三字段，`rulings.md` 裁定行加 `decision` 列——**从本轮 ③ 起可用**，不必等服务态 |
| **验收** | `AT-07` 两条新用例；一次真实 H8 amend 在手工态留痕（建议：本轮 ③ 若所有者对裁决稿部分否定，就按 3.3 记） |
| **保留旧语义** | 修订记录写明 v1 响应为布尔、为什么不够（本文 3.1） |

⚠ 2.2 提到的「Attempt 可产出 typed Artifact」是否算对 Attempt 定义的扩充，并入本工作单元一并裁，不单开。

---

## 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果

### 4.1 粒度是三个字段，不是一个；且至少有四档

`task.md:202-208` 那张表用一列「运行时自己的 agent / 现有 CLI 助手」把三件不同的事绑在一起了：**能看多细**、**能在哪拦**、**沙箱谁提供**。
它们可以分开取值——例证就是 `codex exec`：

- `--json` 把每次命令执行、每次文件修改作为 `CommandExecution` / `FileChange` 项逐条吐 JSONL
  （`~/repo/codex/codex-rs/exec/src/cli.rs:60`；`~/repo/codex/codex-rs/exec/src/exec_events.rs:118`、`:186`）——**可见性到工具调用级**；
- 但吐的是执行者**自报**，运行时既拦不住（拦截点在 codex 进程内），也验不了（事件流与实际文件系统动作之间没有运行时可校验的绑定）——**强制点仍在进程外**；
- `-s/--sandbox` 让调用方**请求**一个沙箱策略，但执行是 codex 自己的——**策略可请求、执行不可验**。

所以 Agent Profile 登记三个字段：

| 字段 | 取值 | 含义 |
| --- | --- | --- |
| `observability` | `tool.enforced` ＞ `tool.reported` ＞ `process` ＞ `fs-only` | 运行时**能看见**的最细粒度：运行时自己的工具层事件 / 执行者自报的工具级事件流 / argv + stdio + 退出码 + 事后 fs diff / 只有 commit 与 fs diff（无 argv、无 stdio） |
| `enforcement` | `tool-level` / `outer-only` | 运行时**能拦**在哪：工具网关（事中）/ 只有进程外层三道边界（文件子树、env 凭据、出网） |
| `sandbox` | `runtime` / `self` / `none` | 沙箱由谁提供、策略由谁定 |

§8-5 要求「至少区分逐工具调用与仅进程级」——`tool.enforced` 与 `tool.reported` 都是逐工具调用，`process` 与 `fs-only` 都是进程级及以下；四档覆盖并细于两档。

### 4.2 五家的取值

见 2.3 登记表。摘要：luna / kimi `process`（可升 `tool.reported`，加 `--json` 即可）；cursor `process`（`--output-format stream-json` 存在，⚠ 内容未核）；
qwen `process`（`-o` 存在，⚠ 内容未核）；**fable `fs-only`**——它是 `task.md:360` 说的「连 argv 都没有」那一类的实例，运行时只能看 commit 与文件系统前后差。
六家 `enforcement` 全部 `outer-only`，`sandbox` 全部 `self`。**目前没有一家是 `tool.enforced`**——那是 SDK 腿建成之后才会出现的取值。

### 4.3 后果一：证据权威性由粒度推导，不由执行者声明

规则：

1. **只有 `tool.enforced` 的事件是证据。**`tool.reported` 的事件流是**索引**——运行时可以据它决定去重新推导什么（复跑哪条命令、diff 哪个文件），但不能据它下结论。
   `process` / `fs-only` 的自报（「我跑了测试」「我核过源码」）一律是**主张**。
2. **证据由运行时从工作区重新推导**：commit 存在与哈希（attested）、diff 文件集 ⊆ `paths`（attested）、锚点可达（attested，validator 已做）、
   命令复跑结果（attested，validator 跑而不是执行者跑）。`refact-fable` 轮 qwen 拿休眠代码当能力证据、九份评审无人发现（`task.md` §2.1），
   就是把 `process` 级执行者的主张当了证据。
3. **每个 Attempt 的 `evidence_refs` 带 `grade`**，Artifact 的 `evidence_grade` = 其输入 Attempt 的最低 grade——这就是 3.2 出向字段 `evidence_grade` 的来源。
   人在批之前先看到「你看的这份东西是几级证据」。
4. **`RUNNING` 判不了的归因改正**：`refact-fable.md:220` 把它归给 git 载体，错了——`round-status.py` 看不见的是**进程内部**，换成 PG 一样看不见。
   它是 `observability ≤ process` 的执行者属性；`events.jsonl`（`refact-fable.md:225` 已承认是投影）只能把它提到 `reported`。

### 4.4 后果二：三道边界是架构组件，不随脚手架拆

对 `enforcement = outer-only` 的执行者，`F-EXEC-01`（`request-lifecycle.md:381`）**只能**靠三道外层边界实现：

| 边界 | 机制 | 为什么是永久的 |
| --- | --- | --- |
| 文件子树 | 进程能看见哪些路径（bind / namespace / 或至少凭据隔离的 OS 用户） | 产品运行时调 CLI 助手时同样看不见它内部读了什么 |
| env 凭据 | 进程 env 里没有主仓写凭据、没有所有者账户凭据（`refact-fable.md` 3.13.5 第 3 条的卫生检查） | H5 的强制点在凭据层（该轮 §8 第 2 条「变强」） |
| 出网 | 进程能不能出网、走哪 | 财务数据的数据流出边界（`task.md` §2.2 第 3 件）对 CLI 腿只有这一层 |

它们登记为 executor adapter 的**环境策略**，是 Agent Profile `enforcement = outer-only` 时的**必填配置**，不是 bootstrap 威胁模型的附件。
`refact-fable.md:651` 那节的内容不变，**归属**从「签名回执的威胁模型」挪到「executor adapter 的环境策略」。

### 4.5 后果三：独占工作区在 CLI / GUI 腿是约定，不是隔离

`refact-fable.md:493-505` 的 provision 函数两边一样；差别在建好之后：SDK 腿把工作区挂进运行时提供的沙箱，进程只看得见它；
CLI / GUI 腿是在宿主建目录、把路径传给进程，**进程看得见整个文件系统**。现场证据：本会话在 `~/worktrees/fable/k8s` 起草，却读了
`~/repo/codex`、`/tmp`、`~/worktrees/` 下的其他目录（沙箱说明写「对其余文件系统可读」）。登记字段 `workspace_isolation = enforced | convention`，
六家全 `convention`。**协议「① 提案：隔离目前靠纪律不靠机制」那条 ⚠ 由此有了登记字段，不再只是文字。**

### 4.6 R2：principal 通道也有粒度

R2 说的是极端情形：不只执行者，**人的回执**也没有 attested 通道——所有者与 agent 同机、同 git 身份，H1 签发 `94558713` 在账本上与 agent 提交不可区分。
所以 `[principal.owner]` 登记 `channel_grade`，现值 `shared-credential`。后果：

- 2.7 的轨迹里所有 `power_row ≠ —` 的条目 `response_grade = reported`，直到通道换掉；
- 2.6 的拆除条件里 Interaction 行**不得**在此之前拆——服务态若在同一信任域里提供响应端点，只是把 `reported` 搬了个家；
- S1 的前置按 R2：先有 agent 够不着的操作面（所有者自己的设备 + 不被 agent 共享的凭据），再谈回执仓与三把 key。
- 同形复发已登记为本轮 `R4` / `R5`：身份判别命令在仓外吐 `.` 而非报错，产品映射句被当成身份证据——
  `cursor` 参与方据此自判为 `fable`。身份只能来自 worktree 目录名；产品 / 模型 / 界面一律不是证据。
  `dispatch = manual` 的执行者每一次 H0 都必须重跑这条命令，不能凭「我在 Cursor 里」推断。

### 4.7 登记表形状：`dispatch` 字段

`task.md:352-361` 指出 `agents.toml` 没有「存在但不可自动分发」的形状。补 `dispatch = argv | manual`：`manual` 时 `argv` 可缺省，
`round-dispatch.py` 对它输出的是给人的投喂说明而不是命令，并记一条 H0。`observability` 对 `dispatch = manual` 的执行者**只能**是 `fs-only`
（没有进程句柄就没有 stdio），脚本据此校验不许填高。

---

## 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线

前提先说清：开销是 **(任务, orchestrator 实现)** 的函数，不是任务单独的函数。下面的规则对 `orch.service` 成立；
对 `orch.manual`，凡 `dispatch = manual` 的执行者每个 Attempt 至少多一个 H0，所以 fable 在现状下**任何**任务走运行时都比直接在 Cursor 里说一句贵。

### 5.1 分类规则

**机械可判（全部由工单字段直接判）**：

| 规则 | 字段判据 | 结论 | 省在哪 |
| --- | --- | --- | --- |
| M1 | `|executors.proposers| ≥ 2` | 走运行时更便宜 | 独占工作区供给、按 commit 取件、作者归属、评审枚举——手工做等于把 orchestrator 的活让人做 |
| M2 | 计划中 `power_row ∈ {H1,H2,H3,H4,H6,H8}` 的触点数 ≥ 1（即 tier ≥ T1，或 T0 但 router `ask`） | 走运行时更便宜 | 中途审批不必人盯；amend 有落点 |
| M3 | `read_only_inputs[]` 非空且带版本锚，或 Task 依赖另一 Task（`WAITING(DEPENDENCY)`） | 走运行时更便宜 | 跨会话续接：上下文由输入版本承载，不靠人重讲 |
| M4 | `paths ∩ 权威层路径集 ≠ ∅`（`constraints.md`、`request-lifecycle.md`、协议、策略、门禁脚本） | **必须**走运行时（无关便宜） | 这是 H5 与冻结纪律的适用范围 |
| M0 | 以上皆否：单执行者、零触点、无版本化输入、不碰权威层 | 走运行时**更贵**，除非满足 5.3 的上界 | — |

**非机械（判断）**：留痕本身的价值——「决定了什么、为什么」将来会不会被人问起。判不了就按 M0 处理，不要为了留痕把 T0 做重。

### 5.2 反例

三类走运行时反而更贵的任务，逐个说贵在哪一步：

1. **单文件笔误 / 死链修补**（`refact-fable.md` 3.6 的 `readiness-docs-typo` 包就是为它设的）。手工：一句话 + 一次 commit/push = 2 个人的动作。
   运行时 T0：即使 H1 由已签包承担、H2 自动放行，仍要 **(a) 建工单**（哪怕是从 prompt 生成，人要看一眼 router 选的包对不对）、
   **(b) 供给独占 worktree**（`git worktree add` + 之后回收）、**(c) H5 发布**。贵在 (b)：一个不需要隔离的任务被强制隔离，
   多出建 / 切 / 删三步，任务本体十秒，手续一分钟。
2. **一次性提问 / 探索性阅读**（「这个函数在哪被调」「帮我读一下 X 的 §3 讲什么」）。它没有 Artifact 落盘，运行时的 output_schema 必须有一个 final_path——
   于是要么造一个没人再读的 Artifact，要么在 `VALIDATING` 阶段把「回答」翻译成契约。**贵在 `VALIDATING`：为一个不需要契约的任务形成契约。**
   这类任务在内核里本就不该是 Task（`request-lifecycle.md` 「Submission 不一定产生 Task」是同一精神）。
3. **对 `dispatch = manual` 执行者的任何分发**——就是本轮对我的这次投喂。手工：所有者在 Cursor 里说一句。运行时（哪怕是服务态）：
   所有者要**先把应用打开在正确的 worktree、跑身份判别、粘固定指令 + 取件命令**（H0 三个动作），因为运行时对这个执行者
   `observability = fs-only`，只能靠身份行与目录名事后核对。**贵在派发与身份核对**：运行时看不见的执行者，它的每一次调用都要人替它证明「是谁、在哪」。
   这条反例的意义是：**不可观测的执行者对运行时是净负担**，与任务大小无关。

### 5.3 T0 开销上界判据

定义「**人的必需动作**」= 没有它 Task 就不能推进的、由 principal 做出的动作，计数单位是一次经鉴别的响应或一次 commit/push 或一次 H0：
提出请求 = 1；每次 Interaction 响应 = 1；每次 H0 = 1；发布（H5）= 1。

手工模式下一个 T0 任务的基线 = **2**（说一句 + 一次 commit/push）。上界：

> **T0 走运行时的人的必需动作数 ≤ 2，且 ≤ 同一任务手工模式的动作数；其中 H0 = 0，人须撰写的落盘产物 = 0（请求文本本身就是工单），从请求到派发的人的步骤 = 0。**

推论：T0 的工单必须**从请求自动生成**（router `decide` 选包、tier、执行者），不能让人另写一份；H5 必须**折进人本来就要做的那次 push**
（凭据在人手里，push 本身就是回执——`refact-fable.md` 3.13.5 已把 push 放在 Windows），不能再要一次单独签名。
两条任一做不到，上界就破，M0 类任务就会绕过。

**机械度量**：每个 Task 从账本数 `Interaction(responder = principal)` 数 + H0 事件数 + principal 的 commit 数；T0 Task 该值 > 2 即判「超上界」，
超上界的 Task 按包分类汇总——这就是 `task.md:129` 说的绕过率观察值的**分母侧**数据。

### 5.4 绕过的可观测性

账本看不见绕过，**底座看得见**：开发任务的一切最终都落在 git 里，而 git 不区分「经运行时」与「没经」。所以：

1. **底座对账**（主机制）：每个 Attempt `COMPLETED` 时登记它的 commit 集；每个 publisher Attempt 登记它推的 ref 移动。定期扫
   `git log --all --since=<上次对账>` 减去账本里全部 Attempt 的 commit 集，差集 = **未登记提交**。绕过率 = 未登记提交数 / 全部提交数，
   按 diff 文件集对照任务类包的 `paths` 归类——直接回答「哪类任务被绕过」。手工态：⑦ 清理时跑一次脚本；服务态：候选仓的 pre-receive
   （它在 agent 域之外）+ 账本侧对账作业。
2. **降低绕过的成本，让它变成可观测的「事后登记」**：提供 `register --from-commit <sha>` 一步把已发生的改动登记为 T0 Task
   （`intake = retroactive`，acceptance = 机械门禁对该 diff 复跑）。它把「绕过」变成账本里一个**带标记**的合法对象；`retroactive` 的比例本身是超上界的信号。
   ⚠ 这与 I1「原始输入不被后续解释覆盖」的关系需在 3.5 修订单元一并核：retroactive Task 的 original_input 就是那个 commit。
3. **如实声明看不见的**：未提交的工作区改动、纯对话的问答，任何机制都看不见。不为它们造代理指标。

---

## 6. 对 OP-1 / OP-2 / OP-3 的表态

### 6.1 OP-1（等效判据的形式化）——**改写**

采纳四要素与「允许 / 不允许不同」清单的骨架。改四处，理由在 2.7–2.8：

1. **加 `provenance`**。不加，`refact-fable` 那条 23 行的轨迹会被判「与目标态全等」，而它 21 行是自报或推断。
2. **加 `power_row`**。OP-1 把「谁在哪条边上有权」列进不允许不同，轨迹四要素里却没有这一项——写进去才可比对。
3. 「允许不同：执行者可观测粒度」改为「**允许取值不同，但必须记录，且等效只在最低等级上宣称**」。否则服务态用 `tool.enforced` 执行者跑出的轨迹
   会被拿来「证明」手工态那条也成立。
4. Artifact 版本作者拆 `claimed / attested`。

### 6.2 OP-2（Interaction 字段表）——**改写**

采纳出向三样、入向三值 + amend 的方向。改五处，理由在 3.2–3.3：

1. `editable` 必须是**机械可判的集合**（JSON pointer / path glob），否则「越界 amend 该怎么处理」判不了，最后又滑回「建新 Task」。
2. 出向加 `evidence_grade`——人在批之前要知道看的是几级证据，这是 P2 与 P3 的接口。
3. 出向加 `options[]`——R7「移」、R4「回执仓」这类选项型裁决占了上一轮六次裁决的四次，没有它们响应仍是散文。
4. amend 加 `base_version`——「以人的方案替代」用血缘表达，不加第四个 decision 值。
5. `responder` 由运行时鉴别、**不在载荷里**，并登记 `response_grade`——否则 R2 那条极端案例在字段表里无处落。

### 6.3 OP-3（必答 Q 的四问形式）——**部分采纳**

四问保留并已逐问回答。两点不同：

1. 四问把开销当成任务的属性；它是 **(任务, orchestrator 实现)** 的属性。本轮的 fable 就是实例：对它而言现状下没有任何任务走运行时更便宜（5.2 反例 3）。
   第 3 问的上界因此要分别对 `orch.manual` 与 `orch.service` 陈述——前者的 H0 ≠ 0 是结构性的。
2. 第 4 问的提法「绕过发生在运行时之外，账本天然看不见」把问题锁在账本上；正确的观察面是**底座**（git），它看得见没登记的提交（5.4）。
   问题应改为「运行时如何对账底座」。

### 6.4 任务书自造的同名物：`runtime`

`task.md` §6.2.1 的分组键叫 `runtime`（沿用 `refact-fable.md:253` 的登记表字段，取值 `codex-cli` / `claude-code`……），同时全文用「运行时」指产品运行时，
内核 §0.1 又有「Agent runtime」为六方之一。**一个词三义**，与上一轮 supervisor 三套同名物同形。建议：登记表字段改名 **`harness`**（上一稿 :253 的注释本来就写着「执行 harness」），
分组键随之为 `harness`；「运行时」只留给产品运行时；内核 §0.1 的 Agent runtime 在修订单元里注明「即本文所称运行时的 Agent 执行部分」。
本文登记表已按 `harness` 写。

另一处**不算**同名物但要说清：协议的「⑤ 验收 / 验收方」与内核的「验收器 / `F-ACCEPT-*`」是同一件事的两个实现者——机械部分是 validator（组件），
判断部分是 acceptor（角色，由处置表算出的 Agent Profile）。一个运行时里它们是 acceptance 契约的两半，不是两套验收。

---

## 7. 与 `refact-fable.md` §8 处置的对齐

| 条 | `task.md` §7 处置 | 本文落点 |
| --- | --- | --- |
| 1 五词唯一、router / orchestrator 无 agent 实现 | 留 | 2.1；登记表 `roles_allowed` 无此二词 |
| 2 权力表 ≤10 行、强制点在凭据层或回执仓 | 留且变强 | 2.4 九行；H5 凭据层；H0 明写「无强制点」是欠账不是行 |
| 3 `RUNNING` 判据留、归因改 | 改 | 4.3 第 4 条 |
| 4 (a)(b)(c) | (c) 扩为共用 schema | 2.5 映射表；2.7 轨迹 schema 两态共用 |
| 5 T0/T1/T2 = 0/1/2 触点 | 留 | 2.2 approval；⚠ 本轮 H1+H2 合并实为 1，登记观察值（2.4 表第 3 行） |
| 6 判据锚在 credential domain 之外 | 留变强 | 4.6：principal 通道也登记等级 |
| 7 migration-map | 作废 | 本文不画文件树（task.md §4） |
| 8 新判据首跑对照 | 留 | 2.6 拆除条件里 validator 行 |
| 9 取证栏冻结前重跑 | 留 | 本文头部取证声明 |

---

## 8. 覆盖声明、盲区与未验证项

**查了**：`request-lifecycle.md @ 70a7dd50` 全文；`refact-fable.md` 全文；`round-protocol.md`（601 行版）全文；`task.md` / `round.md` / `rulings.md`（本轮）/ `inbox-owner.md`；
`rounds/refact-fable/` 全部产物的存在性与行数；`refact/*` 标签的提交序列；`~/repo/codex` 的 `exec` crate 源码；本机三家 CLI 的 `--help`。

**没查**：任何他家本轮候选（隔离）；`agent -p --output-format stream-json` 与 `qoder -o` 输出的**内容**是否含工具级事件（只确认参数存在）；
luna / kimi 实际模型（`$CODEX_HOME` 配置未读）；qwen 的 provider（推断）；fable 的模型（不可机械核验）。

**盲区**：我是被推翻那份稿子的作者，对「哪些该幸存」有既得利益，第 1 节与第 7 节请按此折算。
本文的 trace 样例用了我自己起草的修订记录当 `reported` 来源——这本身就是 4.3 规则 1 说的「主张」，所以我把它标成 `reported` 而不是证据。

**未验证**（⚠）：2.3 登记表全部 ⚠ 项；2.2「Attempt 产出 typed Artifact」是否算内核扩充；5.4 第 2 条 retroactive Task 与 I1 的关系；
H1 + H5 同 commit 的账本歧义在服务态如何拆（应是两个 Interaction，但手工态今天做不到）。

**故意没写**：文件树与旧→新映射（§4 不受理）；R0–R5 重排（同）；`protocol-v2` 五条待决（同）；财务分析 Task Profile 的具体契约（那是它自己的第一个工作单元）。

---

## 9. 自检：对照 `task.md` §8 十条

| 条 | 自检 |
| --- | --- |
| 1 | 全文无禁用词组（`rg` 自查零命中）；`profile_id = dev.change`；五个 Agent Profile 名单在 2.3 |
| 2 | 登记表无 `kind` 标人；2.4 第二张表逐条 边 + 行，无缺项 |
| 3 | 2.7 字段定义；2.8 用 `7e8464c2` 与 `rounds/refact-fable/` 真实产物导出 23 行；状态词 ⊆ 内核 |
| 4 | 3.2 字段表含出向三样、入向三值 + amend + 进入下次 Attempt 的路径；3.5 显式声明内核修订并给边界 / 影响 / 迁移 |
| 5 | 4.1 字段与四档；4.3 推论；2.3 五家逐条填 |
| 6 | 5.1–5.4 四问；5.2「反例」小节三例 |
| 7 | 6.1 / 6.2 / 6.3 各自小节，改写与部分采纳均给理由 |
| 8 | 断言现状处附 `文件:行` 或命令；未核处标 ⚠；休眠代码未用作能力证据（codex `--json` 是已发布的 CLI 参数，`--help` 可复跑） |
| 9 | 本分支相对 `7e8464c2` 只新增本文件 |
| 10 | 首行身份行；`<名>` = 目录名 `fable` |
