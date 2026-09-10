参与方：opus（裁决方）｜worktree：/home/zym/worktrees/opus/k8s｜HEAD：876dd1ea

# 运行时架构：只有一个运行时，开发是它的第一个 Task Profile

> ⚠ **历史档案，不再有规范效力**（`runtime-refact` 轮裁定 `R10`，所有者 2026-09-07）。
> 现行规范是 [`agent-dev-guide.md`](../agent-dev-guide.md)；**本文与它冲突时以它为准**。
>
> **降级不等于作废**：本文仍可被引用为**当时的判断与取证**，
> 但不再作为「现在该怎么做」的依据。本文对若干设计的主张已被推翻，
> 逐条见 `agent-dev-guide.md` 的证伪清单一节。

> 轮次 `runtime` ③ 裁决稿 ｜ 2026-09-05 ｜ **本稿经 ⑤ 验收「有条件通过」，条件已补足；未经 ⑥ 确认，不承担规范效力**
>
> 首行 `HEAD` 取 ③ 起草时的基线（② 发布点 `876dd1ea`），与五家候选填 ① 基线的惯例一致。
> ⚠ 本稿在轮内多次修订，**权威的版本钉定是各环节通知的「对象事实」表（行数 + sha256），不是首行的 HEAD**——
> 这是 ⑤ 验收 `C-2` 指出的形式偏差的实际成因，此处如实说明而非默认。
>
> **基座**：fable `f053bd84`（四家推荐）。并入 luna / cursor / kimi / qwen 各家主张 21 条，
> 逐条出处与理由见同目录 [`runtime-disposition.md`](../rounds/runtime/runtime-disposition.md)。
> 本稿不重复处置理由，只写结论。
>
> **只读输入（本稿未改动一字）**：
> `working/request-lifecycle.md @ 70a7dd50`（647 行，sha256[:16] `6fcd3973ede30b88`）；
> `refact-fable.md @ 7e8464c2`（927 行，sha256[:16] `89303624bfd9ef27`）。
> 协议按标签 `runtime/protocol`（601 行）。引用按标题不按章节号。
>
> **裁决方利益申报**：本稿的 OP-1 / OP-2 / OP-3 由裁决方在 ① 之前提出，五家均有理由地推翻或改写。
> 本稿对三者的处置见 §6——**三项全部被改写，无一原样保留**。按 `task.md` §5，这三条的最终裁定权在所有者。

---

## 0. 一页摘要

1. **只有一个产品运行时。**它是内核七个对象（Task / Attempt / Interaction / Artifact / Event /
   Side Effect / Delivery）的唯一权威写入面，加四个确定性组件（router / orchestrator /
   interaction service / validator）与两个适配层（executor adapter / principal channel）。
2. **开发是它的第一个 Task Profile `dev.change`（版本 1）**，五家助手是五个 Agent Profile。
   人不是执行者，是 principal，登记在 `[principal.owner]`。
3. **等效判据分两层**：S 层（对象、状态、**边**、权力表、Interaction 绑定字段）现在就可判；
   R 层（一次执行的四条序列）经投影 Π 之后逐条对应，且**每条带来源等级**，
   **等效只能在两条轨迹的最低来源等级上宣称**。四要素之外另钉 `TraceEnvelope`（契约 / 策略 / 身份 /
   副作用摘要），否则两条同形轨迹可能一条获权、一条越权。
4. **Interaction 必须双向带载荷**，是内核修订（§3.5 给出边界 / 影响 / 迁移）。
   入向 `approve / reject / amend`，`amend.mode ∈ {patch, replace}`；`editable_scope` 是**入向拒收约束**
   （JSON Pointer / path glob），不是展示提示；重载荷按 `interaction_class` 只绑
   `APPROVAL_WITH_ARTIFACT`，轻量 INPUT 保持轻 schema；**render 属 Delivery，不进内核绑定**。
5. **可观测粒度是 Agent Profile 的三个字段四档**：`observability`（能看多细）、`enforcement`（能在哪拦）、
   `sandbox`（谁提供）。证据采信 = `min(来源等级, 可见上限, 隔离强度, 验收独立性, 覆盖)`，
   任一未知即降级，不取平均。**目前没有一家是 `tool.enforced`。**
6. **必答 Q**：分类规则机械可判；三类反例；T0 上界用复合向量；绕过的分母取**外部 sink**，
   允许结论为 `UNKNOWN`——账本看不见账外，git 对账只是其中一个有覆盖边界的 sink。
7. **本轮实测**：上一轮的真实轨迹 23 条里 `attested` 仅 2 条。手工模式「看起来在跑」，
   轨迹基本不可复原——这是「先在这一层跑通再往下实现」这句方法论的账本版读数。

---

## 1. 本稿与上一轮的关系

上一轮终稿 `refact-fable.md @ 7e8464c2` 把「持久层 / 执行者 / 通道 / guard / 状态判定」五格**取值**不同的两种部署形态
各叫成一个 Profile。它自己 `:180` 用来杀第三个的理由——五格全同、只差 guard，是档位不是 Profile——
对那一对同样成立。更糟的是用词：内核 `working/request-lifecycle.md:103-104` 已定义 Task Profile 与
Agent Profile，上一稿在这两个词之外造了第三义，正是它 §1.2 诊断的「同名物」病。

**幸存并被本稿沿用的**：3.1.1 映射表的**边**；3.3 权力表的形状（转换 + `eligible_principal` +
`enforcement_point`）；3.11「git 验不了事务 / 租约 / fencing」；3.13 三道边界——
错的只是把最后一样归在「bootstrap 威胁模型」下（§4.4 改正归属）。

**一处归因更正**：`refact-fable.md @ 7e8464c2:220`「`RUNNING` 目前判不了」被归因于 git 载体——归因错了。
换成 PostgreSQL 一样判不了 CLI 进程内部；这是**执行者属性**，不是账本载体缺陷（§4.3 第 4 条）。
⚠ 本轮任务书 `task.md:214` 把该段错锚成 `:238`（实为 `:220`），并被一份候选照抄——
错锚会被下游继承，登记在处置记录 E-1。

---

## 2. P1 — 一个运行时、唯一状态机、`dev.change`、五个 Agent Profile

### 2.1 运行时 = 内核对象的唯一写入面 + 四个确定性组件 + 两个适配层

| 组件 | 职责 | 内核依据 |
| --- | --- | --- |
| **router** | 从请求算出 Task Profile 版本、tier、执行者候选、工作区计划；三值 `decide / ask / refuse` | 「解释、边界与完成契约」；`F-ADMIT-*` |
| **orchestrator** | 推进 Task / Attempt 状态（只走「合法转换」表里的边）、派发、收集、观测逾期、回退 | `I4`「状态转换集中校验」 |
| **interaction service** | 产生 Interaction、**鉴别响应者**、原子消费、把 amend 落成 Artifact 版本 | 「WAITING 与 Interaction」；`F-INTERACT-01` |
| **validator** | 按 Task Profile 版本跑 acceptance 的机械部分；判不了的显式交给 acceptor 角色 | `F-ACCEPT-01`；协议「判据自身的质量」 |
| *适配层* **executor adapter** | 按 Agent Profile 的粒度字段决定怎么调、怎么看、怎么拦 | §4 |
| *适配层* **principal channel** | 人怎么被叫到、怎么回，**响应者身份如何鉴别** | §4.6 |

**orchestrator 是确定性代码，不是角色。**过渡期由人运行脚本，人是它的**触发通道**，不是这个组件。
（`refact-fable.md @ 7e8464c2` §3.9 已立此约束；本轮任务书 §3.1 写「今天的 orchestrator 是人 + shell 脚本」是同名物，
两家独立指出，登记在处置记录 E-2。把欠账重命名为组件，下一轮就会有人对着这个名字设计接口。）

### 2.2 Task Profile `dev.change` 版本 1

```text
profile_id            dev.change
version               1
input_schema          工单：goal · paths[]（允许触及的路径集）· baseline_commit
                      · read_only_inputs[]（路径 + 版本锚）· tier ∈ {T0,T1,T2}（router 建议、人可改）
                      · executors{proposers[], arbiter, acceptor}（T1/T2）
                      · acceptance[]（逐条编号；T0 = 一个已签任务类包名）
output_schema         一个或多个 Artifact 落在 final_path(s)，版本 = commit；T1/T2 另有 disposition Artifact
normalization_rules   goal → 可判定 acceptance 条；歧义实质改变结果 / 权限 / 成本 / 风险时才 ask（内核 :180）
required_context      read_only_inputs 按版本锚取；候选不得改动它们
acceptance            机械条（validator 跑）+ 判断条（acceptor 角色跑，按冻结标准逐条给结论，不得改标准）
evidence              每条断言现状的句子附 file:line 或可复跑命令；采信等级按 §4.3 计算
freshness             baseline_commit 固定；基线移动 → 新 Task
allowed_capabilities  读整仓、写自己 worktree、不 push 主线（H5 在凭据层）
budget                观察窗 W = 已交付各家用时中位数；max_rollbacks = 2
retry                 逾期 → 该家 Attempt FAILED(timeout)，Task 不失败（I8）
approval              权力表 H1–H8（§2.4）；tier 决定开工前 APPROVAL 触点数 0/1/2
privacy               文档任务无；财务数据任务另由其 Task Profile 定（NO ZDR 核实前不得跑）
```

**别名登记**（不并存多个真源）：`DEV`（kimi）、`DEV_ROUND`（cursor）、`DEVELOPMENT`（qwen）、
`dev.change.v1`（luna）**均为 `dev.change` 的别名**，正式 id 取 `dev.change`。

**tier 不是三个 Task Profile**，是 `execution_policy` 的一个字段——改的是 Attempt 组数与审批触点，
不改输入 / 输出 / 验收的**形状**。T2 的七环节是 execution_policy 定义的 Attempt 阶段图，
每个 Attempt 记 `kind ∈ {proposer, reviewer, arbiter, objector, acceptor, publisher}`，产物是 typed Artifact。
⚠ 「Attempt 可产出 typed Artifact」是否算对 Attempt 定义的扩充，并入 §3.5 的修订单元一并裁。

**一条不得外推的边界**：开发的验收**机械且便宜**（测试、门禁、diff），财务分析的验收**判断且昂贵**。
`dev.change` 只证明对象形状与状态转换跑得通；验收器对「判断且昂贵」那一半不能从它外推，
必须在财务 Profile 的第一个工作单元里用真实验收用例重证（内核 `:516-517` 已有同义要求；⑤ 验收 `E-c` 更正原锚 `:521`——那是空行）。

#### 2.2.1 工单：一个冻结的 Artifact，一次确认

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

### 2.3 五个 Agent Profile：登记表

**字段 `harness` 取代上一稿的 `runtime`**——`runtime` 在上一轮任务书里同时指产品运行时、
内核「Agent runtime」与登记表分组键，一词三义，与 supervisor 三套同名物同形（处置记录 D-4 / E-5）。
`refact-fable.md @ 7e8464c2:253` 该字段的注释本来就写「执行 harness」，证据自洽。

```toml
[ap.luna]
harness = "codex-cli"   provider = "openai"    model = "gpt-5.6"   model_pinned = false   # ⚠ argv 未钉 --model
dispatch = "argv"       observability = "process"    # 可升 tool.reported：codex exec --json
enforcement = "outer-only"   sandbox = "self"   workspace_isolation = "convention"
roles_allowed = ["proposer","reviewer","objector","acceptor"]   supports = ["dev.change/1"]

[ap.kimi]
harness = "codex-cli"   provider = "moonshot"  model = "kimi-k3"   model_pinned = false   # ⚠ 同上
dispatch = "argv"       observability = "process"   enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"   roles_allowed = ["proposer","reviewer","objector","acceptor"]

[ap.cursor]
harness = "cursor-agent"  provider = "xai"     model = "cursor-grok-4.6-high"   model_pinned = true
dispatch = "argv"       observability = "process"   enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"   roles_allowed = ["proposer","reviewer","objector","acceptor"]

[ap.fable]
harness = "cursor-app"  provider = "anthropic"  model = "claude-fable-5.1"   model_pinned = false  # ⚠ GUI 内选择，不可机械核验
dispatch = "manual"     # 无 argv；分发由人代行，记 dispatch_event 而非权力表行（§2.4）
observability = "fs-only"    enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"
roles_allowed = ["proposer","reviewer","objector"]      # 本轮不得任 acceptor（task.md §9）

[ap.qwen]
harness = "qoder"       provider = ""          model = ""   model_pinned = false   # ⚠ 留空：task.md §6.2.1 该栏为「—」，推断不得进登记表取值
dispatch = "argv"       observability = "process"   enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"   roles_allowed = ["proposer","reviewer","objector","acceptor"]

[ap.opus]                # 裁决方，不参赛
harness = "claude-code" provider = "anthropic"  dispatch = "argv"   observability = "process"
enforcement = "outer-only"   sandbox = "self"   workspace_isolation = "convention"
roles_allowed = ["arbiter","publisher"]

[principal.owner]        # 人：不是执行者，无 harness / dispatch / observability
channel = "inbox+commit"          channel_grade = "shared-credential"    # R2：与 agent 同机同身份，证据强度零
```

登记表**没有任何条目以 `kind` 标人**。`dispatch = manual` 的执行者，`observability` 只能是 `fs-only`
（没有进程句柄就没有 stdio），脚本据此校验不许填高。

### 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行

**权力表八行**（H0 已按处置记录 D-3 移出——它没有强制点，是欠账不是权力）：

| 行 | 状态转换（唯一状态机的词） | eligible_principal | auto_policy | enforcement_point |
| --- | --- | --- | --- | --- |
| H1 | 工单 Artifact `DRAFT → FROZEN`；Task `WAITING(APPROVAL) → VALIDATING` | `owner` | 无；T0 由已签任务类包承担 | validator 查回执 |
| H2 | Task `VALIDATING → QUEUED`（开工确认） | `owner` | 有：T0 + `decide` | orchestrator 不分发 |
| H3 | 省事方向裁定生效：`WAITING(APPROVAL) → QUEUED` | `owner` | 无 | 回执仓回执；无回执的裁定行视同不存在 |
| H4 | 扩权（预算 / 范围）：`WAITING(APPROVAL) → QUEUED` 或 `→ FAILED` | `owner` | 无 | 同 H3；目标态为工具网关 |
| H5 | 不可逆 Side Effect（写共享最终路径 / push 主线）：⑦ 的 publisher Attempt `COMPLETED` 后 `RUNNING → SUCCEEDED` | `owner` | 无 | **凭据层**：主仓对 agent 域只读 |
| H6 | 推翻裁定 / 改冻结验收条：`WAITING(APPROVAL) → QUEUED` | `owner` | 无 | 冻结区逐字节 + 回执 |
| H7 | 非终态 `→ CANCELLED`（先持久化取消意图） | `owner` | 无 | 裁定行（表内唯一不锚仓外的行，失败安全方向） |
| H8 | 回答本 Task 的 `WAITING(INPUT)` Interaction，含 amend：验证期 `WAITING → VALIDATING`，执行期 `WAITING → QUEUED` | `requester`（开发任务里 = `owner`） | 无 | interaction service 鉴别响应者；amend 越出 `editable_scope` 判无效响应 |

三条纪律：

- **`AUTH-EFFECT` 类不得直达成功终态**：H5 批准的是执行动作，Task 的 `SUCCEEDED` 由 publisher Attempt
  `COMPLETED` 之后提交；**内核没有 `WAITING → SUCCEEDED` 这条边**（上一轮 cursor D1 抓过同形漏检）。
- **H1 属验证阶段**，恢复边是 `WAITING → VALIDATING`（内核 `:269`），不是 `WAITING → QUEUED`。
- **改授权范围不属 in-Task 修订**：按内核 `:292-301` 应建带 `supersedes` 的新 Task。
  H4 的范围收窄为「冻结授权范围内的预算 / 资源额度」。

**`dispatch_event`（不是权力表行）**：人代行 orchestrator 的传输动作（把固定指令送到
`dispatch = manual` 的执行者、打开其界面于正确 worktree、跑身份判别）记为
`dispatch_event{mode = manual, agent_profile_id, attempt_id}`。它**必须可数**——
Q3 的 T0 上界与 Q4 的绕过口径都要数它（§5）；但它不是批准，不占权力表行。

#### 2.4.1 本轮（`runtime`）已发生介入的逐条清单

⑤ 验收 `C-1` 指出：类型级权力表已完整，但缺**本轮已发生介入**的实例级清单（基座候选有，本稿初稿丢了）。补：

| # | 介入（可复核出处） | 唯一状态机的边 | 行 |
| --- | --- | --- | --- |
| 1 | 所有者提出四条推翻性判断（`task.md` §1.2） | **不是任何边**：`refact-fable` Task 已 `SUCCEEDED`，终态不可转出 → 建新 Task `runtime`，`supersedes = refact-fable`（内核 `:292-301`） | —（内核规则，非权力） |
| 2 | `I-01` 解冻 `refact-fable` R1 三处冻结物（`inbox-owner.md`） | `WAITING(APPROVAL) → VALIDATING` | **H6** |
| 3 | `I-02` 冻结 `task.md` §8 十条，签发 `94558713` | `WAITING(APPROVAL) → VALIDATING → QUEUED` | **H1**（⚠ 与 H2 合并于一次触点，与「T2 = 2」不符，登记观察值） |
| 4 | `R1` 裁定本轮协议版本 = `runtime/protocol` | `WAITING(INPUT) → VALIDATING` | **H8**（approve option） |
| 5 | `R2` 接受零强度回执形态，继续 bootstrap 例外 | 同上 | **H3**（更省事方向） |
| 6 | `R3` 固定投喂指令加指路补丁 | 同上 | **H8** |
| 7 | `R4` / `R5` 判别命令硬化、删除产品映射句 | **不占权力行**：中性偏严谨，裁决方自裁 | —（记 `rulings.md`） |
| 8 | `R6` 裁定 §8-4 从属于 §8-7，签发 `023bd75d` | `WAITING(APPROVAL) → QUEUED` | **H6** |
| 9 | ①②④⑤ 对四家 CLI 的手工投喂 | 各家 Attempt `CREATED → RUNNING`；Task `QUEUED → RUNNING` | —（`dispatch_event{mode = manual}` ×N） |
| 10 | ① 起对 `ap.fable` 的手工投喂（无 argv） | 同上 | —（`dispatch_event{mode = manual}`，`observability = fs-only`） |
| 11 | 所有者执行 `publish-*.sh` 把环节产物写入主线（本轮 5 次） | Side Effect：写共享路径 | ⚠ **未经 H5 门**——见下方登记 |
| 12 | 将来的 ⑥ 确认 | `WAITING(APPROVAL) → QUEUED` → publisher `RUNNING → COMPLETED` → Task `RUNNING → SUCCEEDED` | **H5** |

**第 1 行是「没有边」的正确答案，不是缺项**——它恰好说明「推翻一个已完成的 Task」在内核里的落点是
`supersedes` 建新 Task，不是 Interaction。

⚠ **第 11 行是本轮暴露的一个真缺口，如实登记**：所有者在本轮五次执行发布脚本、把环节产物写入主线，
这些都是**写共享路径的 Side Effect**，按权力表属 H5 的管辖范围，但实际未经 H5 门——
它们被当作 orchestrator 的常规动作处理了。原因是权力表的 H5 只对准「⑦ 发布最终稿」，
没有区分**最终稿发布**与**轮内产物发布**。两者不可逆性不同（后者可 revert，前者进交付面），
但都写主线。处置建议：H5 拆为 `H5-final`（最终稿，现有强制点不变）与
`H5-round`（轮内产物，`auto_policy = 有`，凭据层同一强制点），**本稿不擅自改权力表行数**，
登记待 ⑥ 或下一轮裁。

**合法转换全集**（内核 `:222-228`，本稿全部边 ⊆ 此集）：

```text
RECEIVED    → VALIDATING | CANCELLED
VALIDATING  → QUEUED | WAITING | REJECTED | CANCELLED
QUEUED      → RUNNING | WAITING | FAILED | CANCELLED
RUNNING     → QUEUED | WAITING | SUCCEEDED | FAILED | CANCELLED
WAITING     → VALIDATING | QUEUED | FAILED | CANCELLED
```

### 2.5 `dev.change` 的产物 → 唯一状态机

| 产物 / 事件 | Task | Attempt | 说明 |
| --- | --- | --- | --- |
| 工单文件出现 | `RECEIVED` → 即刻 `VALIDATING` | — | 空转不停留 |
| 工单 `DRAFT` / `FROZEN` | `VALIDATING` | — | **Artifact 状态**，不是 Task 状态 |
| router `ask` | `VALIDATING → WAITING(INPUT)` → 回 `VALIDATING` | — | H8 |
| H1 冻结 | `WAITING(APPROVAL) → VALIDATING` | — | 验证期恢复边 |
| H2 开工 | `VALIDATING → QUEUED` | — | T0 按策略放行 |
| 派发 | `QUEUED → RUNNING`（首个 Attempt 获租约） | `CREATED → RUNNING` | `dispatch = manual` 的由 `dispatch_event` 承担 |
| 某家交付并 commit | `RUNNING` | `RUNNING → COMPLETED` | 产出 typed Artifact，**不等于 Task 成功** |
| 某家逾期 | `RUNNING` | `FAILED(timeout)` | Task 不因此失败（I8） |
| 某家用尽观察窗 | `RUNNING` | `BUDGET_EXCEEDED` | Task 按内核第 7 条进 `WAITING(APPROVAL)`（H4）或重新 `QUEUED` |
| 执行期澄清 / 裁选项 | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | 在跑的 → `WAITING` | H8；执行期等待先回 `QUEUED` |
| ④⑤⑥ 回到 ③ | `RUNNING` | 新 Attempt；旧的终态不重开（I5） | |
| ⑥ 确认待人 | `RUNNING → WAITING(APPROVAL)` | — | H5 |
| ⑥ 回执成立 | `WAITING → QUEUED` | publisher `CREATED` | **不是** `WAITING → SUCCEEDED` |
| ⑦ 发布 | `RUNNING → SUCCEEDED` | publisher `COMPLETED` | Side Effect 过凭据层 |
| 无获准成功路径 | `RUNNING → FAILED` | — | |
| 候选 `STALE` / `SUPERSEDED` | — | — | **Artifact 状态**，不是 Task/Attempt 状态 |

**没有一个新词，没有一条内核之外的边，内核每个状态都有落点。**

### 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现

先把 git 的两个角色拆开：

- **git 当 Artifact 载体**——代码与文档 Artifact 的版本就是 commit。**这是永久的。**
- **git 当账本**——用 commit 历史 + `rulings.md` + `events.jsonl` 反推状态，用 `round.md` 当 Task 主档。
  **这是脚手架，要拆。**

| 组件 | `orch.manual`（现状） | `orch.service`（目标态） | 拆除条件（全部机械可判） |
| --- | --- | --- | --- |
| Task 主档 | `rounds/<id>/round.md` toml | `task` 表 | 服务态对 ≥1 个 T0、T1、T2 真实 Task 的轨迹，与手工态同 tier 历史轨迹按 §2.7 比对**全等**，且**每类条目的 `attested` 计数 ≥ 手工态** |
| Event 日志 | commit 历史 + `rulings.md` + `events.jsonl`（agent 可写面，是投影） | `event` 表（只追加） | 同上；另加 `round-status.py` 与服务态投影对同一历史轮次输出相同状态序列，且新判据首跑先与人工对照 |
| 并发语义 | **验不了** | `AT-09` 租约 / `AT-14` 取消竞争 / `AT-15` 重启重建 三项通过 | git 载体验不了事务、租约、fencing（`refact-fable.md @ 7e8464c2` §3.11 已登记），本稿不假装换说法就能验 |
| Interaction | `call-<环节>.md` + `inbox-owner.md` + 裁定行 + 所有者 commit | `interaction` 表 + 鉴别响应者的端点 | **R2 前置**：所有者拥有 agent 够不着的操作面，响应者身份 `attested`。**在此之前不得拆**——服务态若在同一信任域里提供端点，只是把 `reported` 搬了个家 |
| 派发 / 收集 | `round-dispatch.py` 生成命令 + 人粘贴 | executor adapter | 该 Agent Profile `dispatch = argv` 且 adapter 已对它跑通一次 Attempt。`dispatch = manual` 的**永远由人承担，不是拆除对象而是登记对象** |

**`dispatch = manual` 的两条硬约束**（④ 采纳 luna `O-L1`）：无命令行入口的执行者，
**要么**经显式桥接（`dispatch_event{mode = manual}`，产生可审计 Delivery），
**要么**不得进入**自动路由候选集**——**不得靠不可见的手工粘贴冒充自动分发**。
两条都不满足时它退出自动路由候选集，但**仍保留在 Agent Profile 登记表里**：
「登记集合」与「自动路由候选集」是两个集合，前者记「存在」，后者记「可被 router 选中」。
| validator | `round-status.py --verify` | acceptance runner | 对 `refact` / `refact-fable` / `runtime` 三轮历史产物，两者判定逐条一致 |
| 工作区供给 | `git worktree add` | provision 服务 | worktree 本身留（属载体侧）；供给**判据**（独占 × 干净 × 基线）进代码并有测试 |

「先在这一层跑通，再往下实现」的准确表述由此是：
**手工态跑通的是对象形状、边、Interaction 形状与权力行；它跑不通的是并发语义与证据的 `attested` 等级——
后者是 P3 的结论，与载体无关。**

### 2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文

#### 2.7.1 S 层与 R 层

| 层 | 比什么 | 何时可机械判 |
| --- | --- | --- |
| **S 层（schema）** | 对象集合、状态词、**边**、权力表行、Interaction 绑定字段、Agent Profile 字段 | **现在**。候选给出字段即判 |
| **R 层（run）** | 同一 Task 的四条序列，经投影 Π 之后逐条对应 | 两种 orchestrator 都按同一 schema 落账之后 |

**「谁在哪条边上有权」属 S 层，是静态约束，不塞进一次 run 的轨迹里比。**
（OP-1 把它列进「不允许不同」是对的，放进轨迹四要素是错的——裁决方原稿的一处结构错误。）

#### 2.7.2 R 层的轨迹条目

```text
trace_entry = {
  seq          Task 内单调
  layer        task | attempt | interaction | artifact
  subject_id
  from → to    状态边（task/attempt）；version_from → version_to（artifact）；request → decision（interaction）
  actor        Agent Profile id / principal id / orchestrator
  power_row    触发本边的权力表行（H1–H8）或 "—"
  payload_ref  interaction 层：出向 artifact_ref + 入向 decision / amend 的 Artifact 版本
  at           时间（载体差异，不参与比对）
  provenance   attested | reported | inferred
  evidence_ref commit / 表行 / 文件:行
}

Π = 丢掉执行者私有 Event（工具调用、内部 token、GUI 会话内部步骤）与 at
    保留 Task/Attempt 的边、权力表命中的 Interaction、Artifact 版本与作者
```

`provenance` 三值：**attested** = 运行时从它控制的底座直接取得；**reported** = 执行者或人的自报；
**inferred** = 事后读产物推出来的。Artifact 作者拆 `author_claimed` 与 `author_attested`。

#### 2.7.3 `TraceEnvelope`（比较上下文，不是第五条序列）

```text
TraceEnvelope = { task_profile_id/version, acceptance_contract_digest, policy_version,
                  principal 身份域, 输入摘要, Side Effect 摘要, Evidence authority 摘要 }
```

**没有它，四序列单独不足以证明等效**：两次运行可以状态、Attempt、Interaction、版本全同，
而其中一次用**未获权凭据**发布到生产——不比策略版本、授权 principal 与 Side Effect 摘要，
算法会误报等效。

#### 2.7.4 比对规则（六条）

1. **白名单制。**允许不同：载体（文件 ↔ 表）、orchestrator 实现、执行者可观测粒度**的取值**、
   Π 丢掉的那些 Event、`at`。不允许不同：状态、边、对象、Interaction 形状（投影后）、`power_row`。
   白名单之外的差异一律判失败，不设「看起来等价」。
2. **比对粒度取较粗一腿，并显式列出「未比对项」。**手工腿没有逐工具调用事件，
   事件级字段不参与判等——不声明就会把「粒度差」误读成「行为差」，或反过来把粗腿的缺失默认成一致。
3. **两边都要声明权威源与重建规则。**手工态轨迹是从 commit **重建的投影**（权威是 commit，
   工作区文件永不作判据）；服务态权威源是 Event 账。不声明重建规则，比对的是两份各自编的故事。
4. **等效只能在两条轨迹的最低来源等级上宣称。**一条全 `reported` 的手工轨迹与一条全 `attested` 的
   服务轨迹「全等」，证明的只是服务态**没有多走边**，证明不了手工态**真的走过那些边**。
   比对结论必须附各类条目的 `attested` 计数——拆除条件用的就是它。
5. **权限归因项在 bootstrap 期强度为零，单列判。**该项仍比对（形状必须一致），
   但证据强度标 `bootstrap-zero`；**服务态不得把手工态的回执继承为可信先例**。
6. **验证每个状态 ⊆ 内核状态集，每条相邻边 ⊆ 内核合法转换表**，然后才比序列。

**「轨迹」不是内核对象**，是 Event 序列的投影；不得据它另造第五个对象或新状态。

### 2.8 trace 样例：`refact-fable` 轮的真实产物

数据来源可复跑：

```bash
git log 7e8464c2 --format='%h %ad %an' --date=iso -- sunmoonai/docs/dev-plan/refact-fable.md \
                                                     sunmoonai/docs/dev-plan/rounds/refact-fable/
git ls-tree -r --name-only 7e8464c2 -- sunmoonai/docs/dev-plan/rounds/refact-fable/
```

第一条**只有一行**：`7e8464c2 2026-09-05 13:05:50 +0800 sunmoonlion`。
⚠ 该命令**必须钉 `7e8464c2`**：不钉 ref 时，在包含本轮工单发布点 `4513bcbd` 的分支上会出两行
（`4513bcbd` 只新增 `open-questions.md`，非候选/验收产物，结论不变）。此为 ⑤ 验收 `E-a` 的更正。
第二条共 **10 个文件**：九份 `review-*`（其中一份即 fable 的 disposition response）+ `rulings.md`——
**没有任何候选文件，没有任何验收产物**。（⑤ 验收 `E-b` 更正：response 本身就是那九份之一，不另计。）
其余时间来自 `refact-fable.md @ 7e8464c2:5-40` 的修订记录与 `rounds/refact-fable/rulings.md:9-16` 的裁定行。

| seq | layer | subject | from → to | actor | power_row | provenance | evidence_ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | task | refact-fable | — → `RECEIVED` | owner | — | reported | `refact-fable.md @ 7e8464c2:45`；无工单文件 |
| 2 | task | refact-fable | `RECEIVED → VALIDATING → QUEUED` | orchestrator | H1/H2 **缺** | inferred | 无 `round.md`、无冻结验收条 |
| 3 | task | refact-fable | `QUEUED → RUNNING` | ap.fable | — （`dispatch_event`） | reported | 所有者在 Cursor 里投喂，且在 cursor 的目录（`refact-fable.md @ 7e8464c2:3`） |
| 4 | attempt | A1 fable proposer | `CREATED → RUNNING → COMPLETED` | ap.fable | — | reported | 产出 v0；**无 commit** |
| 5 | artifact | refact-fable.md | v0 → v1 | claimed fable / attested none | — | reported | `refact-fable.md @ 7e8464c2:6` |
| 6 | attempt | A2 opus reviewer | `COMPLETED` | ap.opus | — | reported | **产物未归档** |
| 7 | attempt | A3 luna reviewer | `COMPLETED` | ap.luna | — | reported | **产物未归档** |
| 8 | artifact | refact-fable.md | v1 → v2 | claimed fable | — | reported | `refact-fable.md @ 7e8464c2:7` |
| 9 | attempt | A4 kimi / A5 qoder reviewer | `COMPLETED` | ap.kimi / ap.qwen | — | inferred | `reviews/review-refact-fable-{kimi,qoder}.md` 存在 |
| 10–11 | interaction | R3 / R4 | request → approve（option#4 / 回执仓） | owner | H8 | reported | `rounds/refact-fable/rulings.md @ 7e8464c2:11-12`；同 commit、同身份 |
| 12 | task | refact-fable | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | orchestrator | H8 | inferred | 由 10–11 推出，**账本无边** |
| 13 | artifact | refact-fable.md | v2 → v3 | claimed fable | — | reported | `refact-fable.md @ 7e8464c2:13` |
| 14 | attempt | A6 cursor reviewer | `COMPLETED` | ap.cursor | — | inferred | `reviews/review-refact-fable-cursor.md` |
| 15 | interaction | R5 / R6 | approve（全表锚定）/ **reject**（可逆出口） | owner | H8 | reported | `rounds/refact-fable/rulings.md @ 7e8464c2:13-14` |
| 16 | artifact | refact-fable.md | v3 → v4 | claimed fable | — | reported | `refact-fable.md @ 7e8464c2:19` |
| 17 | attempt | A7–A11 五家终审 | `COMPLETED` ×5 | 五家 | — | inferred | `reviews/review-final-*.md` |
| 18 | interaction | R7 / R8 | approve（「移」/「按 T2」） | owner | H8 | reported | `rounds/refact-fable/rulings.md @ 7e8464c2:15-16` |
| 19 | artifact | refact-fable.md | v4 → v5 | claimed fable | — | reported | `refact-fable.md @ 7e8464c2:24` |
| 20 | attempt | A12 luna（撤销 REQUEST CHANGES） | `COMPLETED` | ap.luna | — | reported | **无产物** |
| 21 | artifact | refact-fable.md | v5 → v6（927 行） | claimed fable | — | reported | sha256 `89303624bfd9ef27` |
| 22 | interaction | R1 | request（冻结 §8 九条）→ approve | owner | H1 | **attested**（存在）/ reported（身份） | commit `7e8464c2` |
| 23 | task | refact-fable | `RUNNING → WAITING(APPROVAL) → QUEUED → RUNNING → SUCCEEDED` | orchestrator / publisher | H1 + H5 | **attested**（终态）/ inferred（中间边） | `7e8464c2` 在 master |

**读数**：23 条里 `attested` **2** 条（且身份都不 attested），`reported` 15 条，`inferred` 6 条；
Artifact 六个版本**零 commit**；两个 reviewer Attempt **有事件无产物**；
H1 与 H5 由同一 commit 承担，账本分不开；`VALIDATING` 阶段没有任何契约产物。

这条轨迹与「按 `dev.change/1` 跑一遍 T2」的目标轨迹在**边**上对得上——这正是 OP-1 想要的——
但**只能在 `reported` 等级上宣称等效**。这就是「手工模式看起来在跑、实际没有可搬运的形状」的账本版。

**对照组**（参考，不在 §8-3 要求内）：`refact` 轮的整合分支 `refact/baseline-master..refact/integration`
有 **28 条**逐主张提交，③④⑤ 每条处置各占一个 commit——同一 Task Profile、同一 orchestrator 实现，
`attested` 条目数量级不同。**差别不在载体，在纪律是否落成动作。**

**样例的引用纪律（两条，各对应一种本轮实际发生的失败形态）**：

1. **每个引用对象须先核验其属于所声明的那一轮。**⚠ 本表不得引用 `refact/*` 标签作为本轮对象——
   那是上上轮 `refact` 的产物。这种失败叫**张冠李戴**：引用对象真实存在、哈希可验，但属于另一轮，
   只查「对象是否存在」抓不到，必须查「属于哪一轮」。
2. **无 ⚠ 声明的样例条目一律按「已核验」读，因此凭空构造即为假证据。**另一种失败是
   **把本轮形状倒灌进历史**——写出账本上根本不存在的对象（如「五份并行候选」「⑤ 验收产物」）
   而不作任何声明。防法是前一条查不到的：对象压根不存在，所以「属于哪一轮」无从查起，
   只能靠「无声明即假」。

两条都在本轮有实例，且**防法不同**，不可互相替代。

---

## 3. P2 — Interaction 双向带载荷：一个内核修订工作单元

### 3.1 缺口

内核绑定字段（`request-lifecycle.md:257-264`）出向只有 `question_or_action` 一段自由文本，
入向只有 `resume_token_hash + consumed_at` 一个布尔。所有者的三条（全部否定 / 部分否定 /
以自己的方案替代）里只有第一条能表达，而且表达得不对：拒绝一份分发方案后若按 `:297` 建新 Task，
「修改目标、口径、授权范围、Profile 版本」四个条件一个都不命中——它就是同一 Task 的下一个 Attempt。

§2.8 把缺口量化了：**上一轮六次所有者裁决（R3–R8）在账本上没有一条是 Interaction 对象**，
它们以 `rulings.md` 的行存在，而那是**执行者**写的文件。

**不是开发期特有**：财务分析 agent 交计划（Artifact `plan` v3）给人审，人改两条数据源 →
`plan` v4（author = 人）→ 下一 Attempt 照 v4 执行。形状完全相同。

### 3.2 扩展后的绑定字段表

**按 `interaction_class` 分层**（守住内核 `:180-181`「只有歧义实质改变结果 / 权限 / 成本 / 风险时才澄清」——
问一个缺失参数不该背 Artifact 版本与 amend 载荷）：

| class | 出向必填 | 入向可用 decision |
| --- | --- | --- |
| `APPROVAL_WITH_ARTIFACT` | 全部下表字段 | `approve` / `reject` / `amend` |
| `INPUT_LIGHT` | `question_or_action`、`audience`、`expires_at` | `approve`（= 提交答复）/ `reject` |
| `DEPENDENCY` / `RESOURCE` / `EXTERNAL` | 现行字段不变 | 现行语义不变 |

```text
—— 出向（运行时 → 受众）——
task_id, interaction_id, expected_state_version, audience, expires_at, resume_target   # 不变
wait_reason            INPUT | APPROVAL | DEPENDENCY | RESOURCE | EXTERNAL             # 不变
interaction_class      APPROVAL_WITH_ARTIFACT | INPUT_LIGHT | …                        # 新增
power_row              H1..H8；INPUT 类固定 H8                                          # 新增
question_or_action     保留，降为「人读摘要」，不再是唯一载荷
subject_artifact_ref   { artifact_id, version }                                        # 新增
amend_schema           [json_pointer | path_glob]  允许改的字段/路径；空集 = 只可整单批准/否定   # 新增
evidence_grade         attested | reported | inferred  被展示 Artifact 的证据等级（§4.3 推导值） # 新增
options[]              [{option_id, summary, artifact_ref?}]  选项型审批                # 新增

—— 入向（受众 → 运行时）——
resume_token_hash, idempotency_key, consumed_at                                        # 不变
decision               approve | reject | amend                                        # 新增
amend { mode: patch | replace, base_version, patch | full_content, target ⊆ amend_schema }  # 新增
option_id              decision = approve 且出向有 options[] 时必填                     # 新增
reason                 reject 必填；approve / amend 可选                                # 新增
response_state_version 消费时校验 = task.state_version，不等即 stale 拒绝               # 新增
responder              **由运行时从鉴别上下文确定，不由载荷自报**                        # 新增
response_grade         attested | reported  响应者身份的证据等级（现状全部 reported，R2） # 新增
```

**`render` 不在内核绑定**（处置记录 D-2；所有者 R6 已裁 §8-4 的「必含」从属于 §8-7）：
渲染形式属 Delivery，由前端按 `audience` 的 `client_context`（内核 `:140` 已有）选
`diff{base_version} / full / summary`，缺省有父版本时 `diff`，否则 `full`。
理由：把渲染放进内核会让**每次 UI 改动都变成规范修订**。
`evidence_grade` 留在出向绑定——它不是展示形式，是被展示对象的属性，人在批之前要知道看的是几级证据。

### 3.3 `amend` 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task

1. interaction service 校验 `amend.target ⊆ amend_schema`。**越界即无效响应：拒绝消费令牌**
   （落 `AT-07` 的「异键」类），不是新 Task、也不是新版本。
   `amend_schema` 是**入向拒收约束**，不是出向展示提示——只展示不强制，第一次「人改了范围外一条」
   就会退化成自然语言提示，三值随之退回「布尔 + 全文替换」。
2. 校验 `response_state_version`：amend 到达时 Task 已前进则 stale，拒绝。
3. 通过则写新 Artifact 版本：`author = responder`（principal），`supersedes = amend.base_version`，
   `created_by_interaction = interaction_id`。
   - `mode = patch`（**部分否定**）：`base_version` = 被审的 agent 版本；
   - `mode = replace`（**以人的方案替代**）：`base_version` 不接 agent 版本，血缘另起。
   两者在轨迹里**机械可判**，不必增第四个 decision 枚举值。
4. 原子消费令牌后 Task 按内核回边：验证期 `WAITING → VALIDATING`，执行期 `WAITING → QUEUED`；
   orchestrator 建新 Attempt，`input_artifact_versions` 含该人类版本
   （内核 Attempt 记录已有此字段，`request-lifecycle.md:326`）。
5. `reject`：不写版本；Task 回边后由 execution_policy 决定新 Attempt 或 `FAILED`。
   `approve`：不写版本；有 `option_id` 则落 Event。

### 3.4 与权力表的对应

| 行 | class | 典型 subject | amend_schema | 允许的 decision |
| --- | --- | --- | --- | --- |
| H1 | `APPROVAL_WITH_ARTIFACT` | 工单 `DRAFT` 版本 | `acceptance[]`、`executors`、`tier` | approve / reject / amend |
| H2 | `APPROVAL_WITH_ARTIFACT` | RouteDecision | `executors`、`workspace_plan` | approve / amend |
| H3 / H4 / H6 | `APPROVAL_WITH_ARTIFACT` | 裁定行草稿 | 全行 | approve / reject |
| H5 | `APPROVAL_WITH_ARTIFACT` | 待发布 commit | **空**——不可逆动作不接受 amend，要改回 ③ | approve / reject |
| H7 | `APPROVAL_WITH_ARTIFACT` | 副作用清单 | 空 | approve / reject |
| H8 | 按需 | 被澄清的 Artifact 版本 | 由 Attempt 声明 | approve(option) / reject / amend |

### 3.5 修订工作单元（按 `request-lifecycle.md:627` 修订纪律）

**显式声明：这是内核修订，不是 Task Profile 层能自己解决的。**

| 项 | 内容 |
| --- | --- |
| **原始请求** | 所有者第 3 条判断；§3.1 的量化证据（§2.8 第 10、11、15、18 行：六次裁决零 Interaction 对象） |
| **边界（改哪）** | ①「WAITING 与 Interaction」绑定字段块（`:257-264`）→ §3.2 表；②「核心对象」表 Interaction 行定义改为「…响应含决定与可选的 Artifact 修订」；③ `F-INTERACT-01` 加「响应可携带 amend 载荷并成为 Artifact 版本」；④ §6.2 持久化账 Interaction 行（`:479`）加 decision / amend 版本引用 / responder 鉴别来源；⑤ `AT-07` 加三条：越界 amend 拒收、stale 拒绝、amend 版本进入下一 Attempt 输入且不建新 Task |
| **不改** | 状态词、合法转换表、Task / Attempt 终态语义、幂等与租约纪律。amend 全部走既有边 |
| **影响分析** | 前端：Interaction 投影按 `client_context` 选 render，`amend_schema` 服务端校验；后端：Artifact 版本写入面多一个来源（principal）；Agent：`F-EXEC-07` 请求输入时应给 `subject_artifact_ref` 与 `amend_schema`（不给 = 只能 approve/reject 的旧形状，仍合法）；验收器：`F-ACCEPT-01` 要能看到「哪些输入版本是人写的」（`I11` 证据账已有「生成者」栏） |
| **迁移** | **additive + version gate**：(1) 新字段以可选进入，`interaction_schema_version = 2`，v1 读取保持原语义；(2) **历史 v1 响应只能标 `legacy_resume`（语义 = 已消费，无载荷），严禁回填成 `approve`**——旧 token 只证明 consumed，不证明批准；(3) 新发布的 Task Profile 版本强制 v2，旧的活动 Task 继续 v1 到终态；(4) 双读期指标按 schema version 分开统计，v2 writer 禁止回写 v1；(5) 活动 v1 归零且回放完成后移除 v1 writer，reader 只为历史展示保留 |
| **验收** | 原 `AT-07` 全集 + 三条新用例 + 「部分否定分发方案不建新 Task」一条可复现实验 |
| **保留旧语义** | 修订记录写明 v1 响应为布尔、为什么不够 |
| **顺带** | 内核 `:26-27` 仍指向一个过时落点名（内核自己的同名物残留），并入本单元作引用修复 |

⚠ §2.2 的「Attempt 可产出 typed Artifact」是否算对 Attempt 定义的扩充，并入本单元一并裁。

---

## 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果

### 4.1 粒度是三个字段，不是一个；至少四档

`task.md` 那张两列表把三件不同的事绑在了一列：**能看多细**、**能在哪拦**、**沙箱谁提供**。
它们可以分开取值——例证是 `codex exec --json`：逐条吐 `CommandExecution` / `FileChange` 的 JSONL
（`~/repo/codex/codex-rs/exec/src/cli.rs:60`；`exec_events.rs:118`、`:186`；该锚点经一家评审实跑复核），
**可见性到工具调用级**；但吐的是执行者**自报**，运行时既拦不住（拦截点在进程内）也验不了——
**强制点仍在进程外**。

| 字段 | 取值 | 含义 |
| --- | --- | --- |
| `observability` | `tool.enforced` ＞ `tool.reported` ＞ `process` ＞ `fs-only` | 运行时能看见的最细粒度：运行时自己的工具层事件 / 执行者自报的工具级事件流 / argv + stdio + 退出码 + 事后 fs diff / 只有 commit 与 fs diff |
| `enforcement` | `tool-level` / `outer-only` | 运行时能拦在哪：工具网关（事中）/ 只有进程外层三道边界 |
| `sandbox` | `runtime` / `self` / `none` | 沙箱由谁提供、策略由谁定 |

### 4.2 五家的取值

见 §2.3。摘要：luna / kimi / cursor / qwen 为 `process`（可升 `tool.reported`）；
**fable 为 `fs-only`**——`dispatch = manual`，没有进程句柄就没有 stdio。
六家 `enforcement` 全部 `outer-only`，`sandbox` 全部 `self`。
**目前没有一家是 `tool.enforced`**——那是 SDK 腿建成之后才会出现的取值。

⚠ 一份候选把 fable 填成 `process` 而正文又写「看不到 argv / stdio」——机械判「无空缺」会通过，
事实是填错的。**登记表的机械非空不等于填对**，这是本轮的一个直接教训。

### 4.3 证据权威性：由粒度推导，不由执行者声明

**采信等级 = `min(provenance, observability 可见上限, isolation 实际强度, verifier 独立性, coverage)`，
任一未知即降级，不取平均。**

| 等级 | 观察来源 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| `E0 ASSERTED` | executor / principal 自述 | 仅作为待验证主张 | 行为发生、作者身份、完整性 |
| `E1 REDERIVED` | 运行时从冻结 workspace / Artifact 重算 diff、hash、测试 | 重算范围内的结果 | 未覆盖的进程内部动作 |
| `E2 PROCESS_OBSERVED` | 外层记录 argv / stdio / 退出码 + E1 | 调过哪个进程及其外部结果 | 内部逐工具调用、内部未留痕的出网 |
| `E3 TOOL_OBSERVED` | 运行时工具网关逐调用 Event + E1 | 经网关发生的调用与策略检查 | 绕过网关的系统调用，除非外层同时阻断 |
| `E4 EXTERNAL_AUTHORITY` | executor 凭据域**外**的受保护日志 / 签名 / 审计 API | 指定主体或外部副作用的权威事实 | 人是否充分理解；仍需内容门 |

与轨迹 `provenance` 的映射：`E0` = `reported` / `inferred`；`E1`–`E4` = `attested` 的子档。

四条推论：

1. **只有 `tool.enforced` 的事件是证据。**`tool.reported` 的事件流是**索引**——可据它决定去重新推导什么
   （复跑哪条命令、diff 哪个文件），不能据它下结论。`process` / `fs-only` 的自报一律是**主张**。
2. **证据由运行时从工作区重新推导**：commit 存在与哈希、diff 文件集 ⊆ `paths`、锚点可达、
   命令复跑结果——**由 validator 跑，不由执行者跑**。
   上一轮实样：一家拿休眠代码 `profiles.py:36-41` 当能力证据，九份评审无一发现。
3. **覆盖声明必须同时列 `checked` 与 `not_checked`。零命中只有在输入集合可枚举且枚举成功时才是 `E1`；
   否则结果是 `UNKNOWN`，不是 pass。**（协议「判据自身的质量」：覆盖不全的检查比没有更危险。）
4. **`RUNNING` 判不了的归因更正**：不是 git 载体缺事件文件，是 `observability ≤ process` 的执行者属性。
   `events.jsonl` 只能把它提到 `reported`。`QUEUED` / `RUNNING` 合并标 ⚠ 的处置保留，⚠ 的原因改写为本条。

### 4.4 三道边界是架构组件，不随脚手架拆

对 `enforcement = outer-only` 的执行者，`F-EXEC-01`（`request-lifecycle.md:381`）**只能**靠外层实现：

| 边界 | 机制 | 为什么是永久的 |
| --- | --- | --- |
| 文件子树 | 进程能看见哪些路径（namespace / bind / 至少专用 OS 用户） | 产品运行时调 CLI 助手时同样看不见它内部读了什么 |
| env 凭据 | 进程 env 里没有主仓写凭据、没有所有者账户凭据 | H5 的强制点在凭据层 |
| 出网 | 默认拒绝直连；获准流量经带 Task/Attempt 身份的 egress proxy，域名 / 动作 / 字节预算 / 响应摘要落账 | 财务数据的数据流出边界对 CLI 腿只有这一层 |

**归属更正**：它们是 **executor adapter 的环境策略**，`enforcement = outer-only` 时的**必填配置**——
不是「签名回执威胁模型」的附件，不随 git 脚手架拆除。
无法外层阻断时必须标 `audit_after`，**不得声称事中拦截**。


#### 4.4.1 三道边界的具体形态

| 要防的 | 边界 | 为什么 agent 够不着 | 所有者裁定 |
| --- | --- | --- | --- |
| ① 伪造回执 | **回执仓** `<owner>/receipts`：VM 只持只读 deploy key；回执是仓内自己的**签名 commit**（§2.3）；VM 验签用的公钥集**在线取自 GitHub 账户端点**（`https://github.com/<owner>.gpg` / `.keys`），不落本地文件 | 写权限与账户端点都不在 VM；本地脚本可被改，但它改不了「回执仓里有没有那条 commit」 | 2026-09-05 采用 |
| ② 绕过回执发布 | **主仓写权限移出 VM**：`sunmoonlion/k8s` 对 VM 只读；agent 候选推到**候选仓** `<machine-user>/k8s-candidates`；⑦ 的主线 push 由 Windows 在签 H5 回执的同一动作里执行 | agent 根本发不起对主仓的写；H5 的强制点与签名点合一。不依赖 branch protection / ruleset（私有仓需 Pro） | **2026-09-05 采用**（luna C2 / opus §3；所有者「移」） |
| ③ 签名被代做 | Windows：gpg-agent `default-cache-ttl 0 / max-cache-ttl 0`；回执仓与主仓的推送**不走** Git Credential Manager，用带口令的专用 SSH key（`IdentitiesOnly yes`，不加进 ssh-agent）；或上 C 档硬件在场 | 每次签名与每次 push 都要人敲一次口令；Windows agent 拿不到 | 采用；C 档为加固 |

可选加固（不是替代）：

| 档 | 内容 | 现状评估 |
| --- | --- | --- |
| **A′. 工作仓 ruleset** | GitHub tag / branch ruleset 限定 `main` 与 `confirm/*` 只许所有者写 | **私有仓 ruleset 与 branch protection 都需 Pro 及以上**（官方文档「About rulesets」，已核）。所有者若在 Pro，可加做 |
| **B. 账户隔离** | 四家 CLI 各自以专用 Unix 用户运行、worktree 归各自用户，agent 用户**不在 `sudo` / `docker` 组** | 12:15 版写「运维改造大：以 root 跑」是基于错误取证。实际四家已是普通用户 `zym`，B 档成本 = 建四个用户 + 改 worktree 归属 + 拆组。仍不是本轮范围，但成本评估要改对（opus 2.2） |
| **C. 硬件在场** | YubiKey 等，签名与 SSH 认证需物理触碰 | 对 ①②③ 都是加强项 |

#### 4.4.2 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag

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

#### 4.4.3 回执 schema

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

### 4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离

`provision(...)` 的前置判据（独占 × 干净 × 基线）两边都用，但建好之后的保证不同：

| | `agent-sdk`（`observability = tool.*`） | `agent-cli` / `agent-gui` |
| --- | --- | --- |
| 工作区怎么来 | 挂进运行时提供的沙箱 | 宿主上建目录，把路径传给进程 |
| 进程看见什么 | 沙箱根 | **整个文件系统**（本 VM 上各 CLI 与 GUI 后端都以同一用户跑） |
| 「独占」是什么 | 隔离 | **约定**。打破约定的动作，运行时事中看不见 |

登记字段 `workspace_isolation = enforced | convention`，**六家全 `convention`**。
后果：CLI 腿 Task 的授权范围声明（`I3`）只能依赖「事后审计可发现越权读取」，不能依赖「事中读不到」；
**涉及第二租户或真实财务数据前，CLI 腿的数据源必须经运行时的数据网关，不得给裸库凭据。**

本轮现场证据两则：其一，一份候选在自己的 worktree 起草却读了 `~/repo/codex`、`/tmp` 与其他 worktree；
其二，同一执行者同一会话内 `id` 先报 `uid=0(root)`（`uid_map: 0 1003 1`）后报 `uid=1003`——
**身份切换发生在助手自带沙箱里，运行时看不见也没批准过策略。**

#### 4.5.1 工作区供给：纯函数，判据是独占与干净

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

### 4.6 R2：principal 通道也有粒度

不只执行者，**人的回执也没有 attested 通道**：所有者与 agent 同机、同 git 身份、无签名，
H1 签发在账本上与 agent 提交不可区分。故 `[principal.owner]` 登记 `channel_grade = shared-credential`。
后果三条：

1. 轨迹里所有 `power_row ≠ —` 的条目 `response_grade = reported`，直到通道换掉；
2. §2.6 的 Interaction 行**不得在此之前拆**——服务态若在同一信任域里提供响应端点，只是把 `reported` 搬了个家；
3. **S1 的前置**：先有 agent 够不着的操作面（所有者自己的设备 + 不被 agent 共享的凭据），
   再谈回执仓与三把 key；否则是在同一信任域里搬家。

同形复发已登记：身份判别命令在仓外吐 `.` 而非报错；产品映射句被当成身份证据，一家据此自判为另一家。
**身份只能来自 worktree 目录名；产品 / 模型 / 界面一律不是证据。**

---

#### 4.6.1 人的通道：收件箱 + 回执

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

#### 4.6.2 两台机器的身份与凭据分布

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

#### 4.6.3 剩余风险（如实登记）

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

### 4.7 取证纪律与当前事实

**取证声明（先于事实）**

12:15 版（原 §3.13.1）写「本 VM 所有进程都是 root、`/home/zym` 属 root:root」——**错**。opus 与 luna 在同一台机器复核：
`uid=1003(zym)`，四家 CLI 均以 `zym` 运行。错因已查明：起草者（fable，经 Cursor）在 Cursor 沙箱内执行取证命令，
`cat /proc/self/uid_map` 输出 `0 1003 1`——沙箱用 user namespace 把宿主 uid 1003 映射为 0，所以沙箱内一切看起来都是 root。
取证工具自身有边界而未声明，正是 P4 禁止的事。由此立三条规则，也进 §8 第 9 条：

- 取证栏每条注明**主机、执行身份、是否在沙箱 / 容器内**（`hostname; id; cat /proc/self/uid_map`）；
- S1 的权限测试必须以**与生产 agent 完全相同的 OS 用户与进程环境**复跑，不在任何沙箱内；
- 边界的表述写成「agent 与人是否共享 credential domain」，不绑定「是不是 root」这个偶然事实。

**现状事实**

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

⚠ **上表已被 S1 的宿主取证修订**：本机 `zym` 拥有免密 sudo（`(ALL) NOPASSWD: ALL`）且在 docker 组，
因而**本机一切本地强制点对 agent 无效**——我能 `sudo` 就能改门禁脚本、改验签、改任何 hook。
只有托管方的 key 作用域与账户公钥端点有效。复跑记录见 `rounds/_spike-sign/forensics.md`，**读本节以该记录为准**。

## 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线

**前提**：开销是 **(任务, orchestrator 实现)** 的函数，不是任务单独的函数。
对 `orch.manual`，凡 `dispatch = manual` 的执行者每个 Attempt 至少多一次人代行的传输动作。

### 5.1 分类规则（机械可判，全部由工单字段直接判）

| 规则 | 字段判据 | 结论 |
| --- | --- | --- |
| M1 | `|executors.proposers| ≥ 2` 或 `write_actors ≥ 2` | 走运行时更便宜 |
| M2 | 计划中 `power_row ∈ {H1,H2,H3,H4,H6,H8}` 的触点数 ≥ 1（tier ≥ T1，或 T0 但 router `ask`） | 走运行时更便宜 |
| M3 | `read_only_inputs[]` 非空且带版本锚，或 Task 依赖另一 Task（`WAITING(DEPENDENCY)`），或 `needs_resume = true` | 走运行时更便宜 |
| M4 | `paths ∩ 权威层路径集 ≠ ∅`（约束册、内核、协议、策略、门禁脚本） | **必须**走运行时（无关便宜） |
| M5 | 副作用清单非空，或 `needs_audit_trail = true`，或 `recurrence_key ≠ null` | 走运行时更便宜 |
| M0 | 以上皆否 | 走运行时**更贵**，除非满足 §5.3 的上界 |

规则**不读题目自然语言**；路由结果必须保存 `matched_features`，不能只写「简单 / 复杂」。
财务数据 Task 即使只问一句，只要 M4 或 M5 命中也不因文本短而降级。
⚠ **不得用 `tier` 作为「走运行时更便宜」的输入**——档位由不可逆性 / 权威层等风险判据定，
用档位反推成本是循环，判的是代理变量。新增布尔字段缺省 `false` 会 fail-open，须在工单上显式声明。

### 5.2 反例（三类走运行时反而更贵的任务）

1. **单文件笔误 / 死链修补**，且落在已签 T0 任务类包的 `paths` 内。手工：一句话 + 一次 commit = 2 个人的动作。
   运行时即使 H1 由已签包承担、H2 自动放行，仍要建工单 + **供给独占 worktree** + H5 发布。
   **贵在供给**：一个不需要隔离的任务被强制隔离，多出建 / 切 / 删三步，任务本体十秒，手续一分钟。
2. **一次性提问 / 探索性阅读**（「这个函数在哪被调」「这个正则为什么不匹配」）。它没有 Artifact 落盘，
   而 output_schema 必须有 final_path——于是要么造一个没人再读的 Artifact，要么在 `VALIDATING` 把「回答」
   翻译成契约。**贵在 `VALIDATING`：为一个不需要契约的任务形成契约。**
   目标未定时更糟：契约固定不了，会在「澄清—改目标—再澄清」间空转，而改目标按 `:297` 还要建新 Task，
   一轮探索产生一摞短命 Task。
3. **对 `dispatch = manual` 执行者的任何分发。**手工：在应用里说一句。运行时（哪怕服务态）：
   人要先把应用打开在正确的 worktree、跑身份判别、粘固定指令与取件命令——因为运行时对这个执行者
   `observability = fs-only`，只能靠身份行与目录名事后核对。
   **贵在派发与身份核对：运行时看不见的执行者，它的每一次调用都要人替它证明「是谁、在哪」。**
   ⚠ 该反例的成立范围是 **M0 / T0 类**；固定一次传输动作不会压过任意大的续接 / 并行收益。

**不接受的说法**：「都值得走，因为留痕总是好的。」留痕成本高于这笔改动的价值时，留痕不会发生，发生的是绕过。

### 5.3 T0 开销上界（复合向量，任一维超标即不标 T0）

定义**人的必需动作** = 没有它 Task 就不能推进的、由 principal 做出的动作；
计数单位 = 一次经鉴别的响应，或一次 commit / push，或一次 `dispatch_event`。
手工模式下一个 T0 任务的基线 = **2**（说一句 + 一次 commit / push）。

```text
(human_required_actions, persisted_artifacts, request_to_dispatch_steps, dispatch_events)
        ≤ (        2,              4,                  2,                     0        )
且 human_required_actions ≤ 同一任务手工模式的动作数
```

| 维 | 上界 | 怎么数 |
| --- | --- | --- |
| 人的必需动作 | ≤ 2，且 ≤ 手工同任务 | 收件箱条目数 + principal 的 commit 数 + `dispatch_event` 数 |
| 落盘产物 | ≤ 4 | 工单、Attempt 产物、验收记录、（可选）H5 回执 |
| 从请求到分发的步骤 | ≤ 2 | ① 幂等建单 ② 派发。中间不得再有「确认理解」「选执行者」「选工作区」 |
| `dispatch_event` | **= 0** | T0 不得用 `dispatch = manual` 的执行者 |

两条推论：T0 的工单必须**从请求自动生成**（router `decide` 选包、tier、执行者），不能让人另写一份；
H5 必须**折进人本来就要做的那次 push**（凭据在人手里，push 本身就是回执），不能再要一次单独签名。
两条任一做不到，上界就破，M0 类任务就会绕过。
**通知送达或敲命令不算决策，但仍计动作**——防止把传声筒成本藏掉。

上界按任务类包逐个考核，实测值进观察值；哪个包持续超界，说明它装的不是 T0。

### 5.4 绕过的可观测性

**先说限度：绕过发生在运行时之外，账本天然看不见。「完全可观测」不可达；宣称可达就违反
「判据自身的质量」。** 方案是三层，没有一层承诺全知。

1. **让绕过无利。**主线写入只经 H5（凭据层强制），绕过的产物永远进不了交付面；
   绕过的最大动机（快）被保留为合法路径（§5.3 的上界），次大动机（交付）被凭据层封死。
2. **对账，分母取外部 sink。**
   ```text
   bypass_rate = 未归因的合格变更数 / 全部合格变更数
   分母取【外部权威 sink 的审计】，不取运行时自己看见的事件
   ```
   sink 清单与各自的覆盖边界必须显式列出：

   | sink | 信号 | 覆盖 | **不**覆盖 |
   | --- | --- | --- | --- |
   | 主仓 / 候选仓的 pre-receive（在 agent 域外） | 无有效 `task_id + side_effect_id + capability` 的写被拒 | 一切要进交付面的变更 | 本地未推送的改动 |
   | git 底座对账 | `git log --all --since=<上次对账>` 减去账本里全部 Attempt 的 commit 集 | 已提交的改动 | 改了又扔、未提交 |
   | 工作区脏状态 | `git status` 非空且无对应 `task_id` | 有人在 worktree 里干活没建单 | 纯只读提问 |
   | 终端 / 会话历史 | 对 CLI 的直接调用，argv 不含 `task_id` | 四家 CLI 的手工调用 | GUI 会话、别的机器、加密历史 |

   找不到运行时 Event 的变更写成 `UnattributedEffect`，**不得反向补造一个正常 Task**。
   命中记 `BYPASS_CANDIDATE` 观察 Event，**不自动变 Task、不自动惩罚**。
   **「绕过」不是内核对象**，不得据此新增状态。
3. **降低登记成本**：提供 `register --from-commit <sha>` 一步把已发生的改动登记为 T0 Task
   （`intake = retroactive`，acceptance = 机械门禁对该 diff 复跑），把绕过变成账本里一个**带标记的合法对象**；
   `retroactive` 的比例本身就是超上界的信号。
   ⚠ 与 `I1`「原始输入不被后续解释覆盖」的关系需在 §3.5 修订单元一并核。
4. **如实声明看不见的**：未提交的工作区改动、纯对话的问答，任何机制都看不见——不为它们造代理指标。
   **零命中只能写成「没查到」，不能写成「没有绕过」。**
   在 R2 当前条件下 git author 无法区分人与 agent，**principal 侧的绕过指标为 `UNKNOWN`**。

---

## 6. 对 OP-1 / OP-2 / OP-3 的裁定

三项均由裁决方在 ① 之前提出。**三项全部被改写，无一原样保留。**
按 `task.md` §5，最终裁定权在所有者；本节记裁决方的处置与理由出处。

| | 裁定 | 主要依据（出处） |
| --- | --- | --- |
| **OP-1** 等效判据的形式化 | **改写，四处** | ① 拆 S 层 / R 层 + 投影 Π，权力表归 S 层不进轨迹四要素（cursor）；② 每条带 `provenance`，等效只在最低来源等级宣称（fable）；③ 加 `TraceEnvelope` 防「同形越权」（luna）；④ **边必须进状态序列字段**，只比状态点会漏掉非法边（cursor，援上一轮 D1）。另加比对卫生四条（kimi） |
| **OP-2** Interaction 字段表 | **改写，五处** | ① `render` 出内核进 Delivery（cursor；所有者 R6 裁定使其不与 §8-4 冲突）；② `editable_scope`→`amend_schema`，是**入向拒收约束**且用 JSON Pointer / path glob（kimi + luna）；③ `amend.mode ∈ {patch, replace}` 机械可判（cursor 的需求 + fable 的血缘方案）；④ 加 `response_state_version`、`supersedes` 链、`options[]`、`evidence_grade`、`responder` 由运行时鉴别（kimi + fable）；⑤ 按 `interaction_class` 分层，轻量 INPUT 不背重载荷（qwen） |
| **OP-3** 必答 Q 的四问形式 | **部分采纳，两处改写** | ① 四问把开销当任务属性，实为 **(任务, orchestrator 实现)** 的属性（fable）；② **Q4 的问法预设了绕过可观测**——绕过按定义发生在账本外，问法不改会「奖励看起来有机制的回答、惩罚如实声明覆盖边界的回答」（kimi、luna、cursor 三家独立）。正确形式：先承认限度，分母取外部 sink，允许结论为 `UNKNOWN` |

**裁决方登记**：OP-1 把静态约束（权力表）塞进动态轨迹是结构错误；OP-3 的 Q4 是本轮反复出现的
「检查给出假答案」那条纪律在裁决方自己题目上的一次犯病。两处均由参与方抓出，非自查。

---

## 7. 覆盖声明、盲区与未验证项

**查了**：五份候选与五份评审全文（按 ② 通知所钉 commit）；`request-lifecycle.md @ 70a7dd50` 全文；
`refact-fable.md @ 7e8464c2` 全文；`round-protocol.md`（601 行版）；本轮 `task.md` / `round.md` / `rulings.md` /
`inbox-owner.md`；`rounds/refact-fable/` 全部产物的存在性、行数与部分 sha256；`refact/*` 标签；
`constraints.md` 的 A1 / A3；五家候选相对 `7e8464c2` 的只读输入 diff（均为 0）。

**没查**：`~/repo/codex` 的行号（由一家评审实跑复核，裁决方未复跑）；
`agent --output-format stream-json` 与 `qoder -o` 的输出**内容**是否含工具级事件（只确认参数存在）；
luna / kimi 的实际模型（`$CODEX_HOME` 配置未读）；fable 的模型（不可机械核验）。

**盲区（裁决方）**：
- 本稿的 OP-1 / OP-2 / OP-3 由裁决方提出，五家均有理由地改写。裁决方对「哪些改写该采纳」有既得利益，
  §6 请按此折算。**三项的最终裁定权在所有者。**
- 裁决方在本轮犯的六处错误逐条登记在 `runtime-disposition.md` §E，其中四处由参与方抓出。
- §2.8 的 trace 是从 commit **重建的投影**，不是完整等效性通过证明；其 `QUEUED` / `RUNNING` 细分
  在手工腿上本来就判不了。

**未验证（⚠）**：§2.3 登记表全部 ⚠ 项；「Attempt 产出 typed Artifact」是否算内核扩充；
`retroactive` Task 与 `I1` 的关系；H1 + H5 同 commit 的账本歧义在服务态如何拆（应是两个 Interaction，
手工态今天做不到）；`(harness, model_family)` 是否应取代 `harness` 作分组键——
本轮唯一的观察是**同 harness 的两家差异大于同厂不同 harness 的两家**，单轮单题不足以定论。

**故意没写**：文件树与旧→新映射、R0–R5 重排、`protocol-v2` 五条待决、`pipeline-task.md` 那一轮、
财务分析 Task Profile 的具体契约（属它自己的第一个工作单元）。

---

## 8. 自检：对照 `task.md` §8 十条

| 条 | 自检 |
| --- | --- |
| 1 | 禁用词组零命中；`profile_id = dev.change`（四个别名登记一行）；五个 Agent Profile 在 §2.3 |
| 2 | 登记表无 `kind` 标人；§2.4 权力表八行 + 每行的边；`dispatch_event` 明确不是权力行 |
| 3 | §2.7 字段定义与六条比对规则；§2.8 用 `7e8464c2` 与 `rounds/refact-fable/` 真实产物导出 23 行，逐条带 `provenance`；状态词与边 ⊆ 内核 |
| 4 | §3.2 字段表（含出向 subject/amend_schema/evidence_grade/options、入向三值 + amend.mode + 载荷进下次 Attempt 的路径）；§3.5 显式声明内核修订并给边界 / 影响 / 迁移。**render 归属按所有者 R6 裁定** |
| 5 | §4.1 三字段四档；§4.3 采信算法与四条推论；§2.3 五家逐条填 |
| 6 | §5.1–5.4 四问全答；§5.2「反例」三则 |
| 7 | §6 对 OP-1/2/3 逐项裁定，三项全部改写并给出处 |
| 8 | 断言现状处附 `file:line` 或可复跑命令；未核处标 ⚠；休眠代码未用作能力证据；§8 列出 checked / not_checked |
| 9 | 本分支相对 `7e8464c2`，两份只读输入 diff 为 0 |
| 10 | 首行身份自证行，`<名>` = 目录名 `opus` |
