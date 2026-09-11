# 开发指导：一套运行时、一个 Task Profile、一张权力表

> 轮次 `runtime-refact` ① 候选 ｜ 2026-09-06 ｜ 参与方 **cursor**
>
> 工作目录 `/home/zym/worktrees/cursor/k8s`。身份由目录名判定，不由产品名或模型名判定。
>
> **本稿是面向今后开发的指导，不是现行规范。**规范效力要等本轮 ⑥ 确认。
> 内核对象与状态机的权威定义在 [`working/request-lifecycle.md`](working/request-lifecycle.md)；
> 多助手协作流程的权威定义在 [`protocol/round-protocol.md`](protocol/round-protocol.md)。
> 本稿只引用二者，不重写。
>
> 基线 commit：`ed0b5136`（工单 `round.md` 的 `baseline`）。
> 两份源稿按该 commit 取件：`refact-fable.md`、`runtime-architecture.md`。
>
> **本稿不承担**：具体业务功能（[`development-plan.md`](development-plan.md)）、
> 任务清单与进度（[`implementation-plan.md`](implementation-plan.md) / [`handoff.md`](handoff.md)）、
> 流程规范正文、财务分析 Task Profile 的契约。

---

## 0. 怎么读这份文件

新读者不需要先读过本仓之前的讨论。读的顺序：

1. **先读本节和第 1 节**，知道硬约束和本稿不做什么。
2. **内核对象与状态词**一律跟 [`working/request-lifecycle.md`](working/request-lifecycle.md) 走。
   本稿出现 Task / Attempt / Interaction / Artifact / Event / Side Effect / Delivery /
   Task Profile / Agent Profile 时，定义就是内核「核心对象」表，不在这里另给一套。
3. **一轮怎么走**跟 [`protocol/round-protocol.md`](protocol/round-protocol.md) 走。
   本稿不把七环节重写一遍；只说明开发任务如何投影到那套流程上（第 3 节、第 9 节）。
4. **第 12 节**是已被证伪的设计清单。那一节存在的理由是防止再犯，不是给新设计当菜单。
5. **第 14 节**是两份源稿 64 节的落点索引。抽查落点时以正文为准，不以表格自称的覆盖为准。

**身份**只认 worktree 目录名：

```bash
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")"
```

产品名、模型名、界面长什么样，一律不是身份证据。这条来自一次真实事故：判别命令在仓外一层执行，管道吞掉 `git` 的 128，`basename` 对着报错吐出一串 `.`，该家据产品名自判为另一家。

---

## 1. 硬约束与设计原则

### 1.1 不可违反

| # | 约束 | 权威出处 |
| --- | --- | --- |
| B1 | **只有一套状态机**（Task / Attempt）。不新增状态词，不走内核合法转换表之外的边 | 内核「两层状态机」；不变量 I4 / I5 |
| B2 | **执行层租用不自建**，依赖边界限定在 SDK，不直接依赖裸协议 | [`constraints.md`](constraints.md) A4 |
| B3 | **同一事实只有一个权威写入面**。内核已定义的对象，本稿不重新定义 | 内核 I13 |
| B4 | **人不是执行者**。人的位置是 requester 与 principal | 本轮任务书 B4；内核提交信封的 `requester` |
| B5 | **不得把「判不了」写成「通过」**。判据声明覆盖范围；判不了的显式标出 | 协议「判据自身的质量」 |
| B6 | **不自造已有基座原语的替代协议**。中断、恢复、检查点用库的 | A4 的推论；第 7 节 |

合法转换全集只在内核（`request-lifecycle.md`「两层状态机」）。本稿出现的每条边 ⊆ 该表：

```text
RECEIVED    → VALIDATING | CANCELLED
VALIDATING  → QUEUED | WAITING | REJECTED | CANCELLED
QUEUED      → RUNNING | WAITING | FAILED | CANCELLED
RUNNING     → QUEUED | WAITING | SUCCEEDED | FAILED | CANCELLED
WAITING     → VALIDATING | QUEUED | FAILED | CANCELLED
```

内核没有 `WAITING → SUCCEEDED`。H5 批准的是执行动作，Task 的 `SUCCEEDED` 由 publisher Attempt `COMPLETED` 之后提交。

### 1.2 设计原则

六条全部取自本仓已成文的判断，本稿只是把它们用到底：

| # | 原则 | 出处 |
| --- | --- | --- |
| P0 | 场景差异只体现在 Task Profile 的 guard、必需产物与 interrupt 策略；任何场景不得新增状态词 | 内核「Profile、Artifact 与扩展」：不另造状态机 |
| P1 | 同一事实只有一个权威写入面；两份同构文档即两个真源 | I13 |
| P2 | 状态从产物反推，不从声明读取；人的动作也不例外 | 协议「收到『继续』时怎么办」 |
| P3 | 方向不对称：朝严谨可自裁，朝省事须人确认；默认值属于省事方向 | 协议「裁量权」 |
| P4 | 判据必须声明覆盖范围；覆盖不全比没有更危险 | 协议「判据自身的质量」 |
| P5 | 凡能落成代码、测试或门禁的纪律必须落成；文字只描述意图 | [`constraints.md`](constraints.md)「保证这些被遵守的三层」 |

两条推论：

- **一个只能靠人转述的环节等于没有环节**（P2 + P5）。对话里说「同意」不算回执。
- **强制点必须落在动作实际经过的路径上。**先用命令确认「这个动作现在发生在哪、由谁做、经过什么」，再设计拦截。第 12 节六条被证伪的设计，共同成因就是跳过了这一步。本条是源稿没有、本稿新增的（J8）；取证见第 12 节各条复跑命令。

P0 的适用层级是 Task 与 Attempt。Artifact、Interaction 各有自己的小生命周期（`DRAFT → FROZEN`、`consumed_at`），那些是对象属性，不是第二套状态机，同样跨场景共用。

### 1.3 一条不得淡化的边界

**开发的验收机械且便宜**（测试、门禁、diff）。**财务分析的验收判断且昂贵。**

本稿的验收机制——L0 机器门、T0 任务类包、`round-status.py --verify`——只对着开发设计。`dev.change` 只证明对象形状与状态转换能在 git 载体上跑通；验收器对「判断且昂贵」那一半不能从它外推，必须在财务 Task Profile 的第一个工作单元里用真实验收用例重证。内核「Profile 示例」已有同义要求：每个 Profile 的第一项开发工作单元必须用真实输入、输出、前端 renderer 和验收用例确认字段。

这条写在这里，是因为漏写或淡写都会让人以为「开发轮次跑通了 = 运行时对财务也够用」。不够用。

---

## 2. 唯一运行时

### 2.1 运行时是什么

只有一个产品运行时。它是内核七个对象的**唯一权威写入面**，加上四个确定性组件与两个适配层：

| 组件 | 职责 | 内核依据 |
| --- | --- | --- |
| **router** | 从请求算出 Task Profile 版本、tier、执行者候选、工作区计划；三值 `decide / ask / refuse` | 「解释、边界与完成契约」 |
| **orchestrator** | 推进 Task / Attempt 状态（只走合法转换表）、派发、收集、观测逾期、回退 | I4 |
| **interaction service** | 产生 Interaction、鉴别响应者、原子消费令牌 | 「WAITING 与 Interaction」 |
| **validator** | 按 Task Profile 版本跑 acceptance 的机械部分；判不了的显式交给 acceptor | 协议「判据自身的质量」 |
| *适配层* **executor adapter** | 按 Agent Profile 的粒度字段决定怎么调、怎么看、怎么拦 | 第 4 节 |
| *适配层* **principal channel** | 人怎么被叫到、怎么回，响应者身份如何鉴别 | 第 5 节 |

**orchestrator 是确定性代码，不是角色。**过渡期由人运行 [`protocol/round-status.py`](protocol/round-status.py) 与 [`protocol/round-dispatch.py`](protocol/round-dispatch.py)，人是它的触发通道，不是这个组件。把「今天由人跑脚本」重命名成组件，下一轮就会有人对着这个名字设计接口。

**router 与 orchestrator 不得由 agent 实现。**登记表里没有任何条目的 `roles_allowed` 含这两个词。

### 2.2 开发是它的第一个 Task Profile

内核已经定义了 Task Profile 与 Agent Profile（「核心对象」表）。场景差异落在 **Task Profile 的取值**上，不落在第二套状态机上，也不落在「按部署形态再切一层」上。

本稿的第一个 Task Profile 是 `dev.change` 版本 1。别名 `DEV` / `DEV_ROUND` / `DEVELOPMENT` / `dev.change.v1` 均指向它，不并存多个真源。

产品运行时上的其他 Task Profile（财务分析等）尚未开工，见 [`handoff.md`](handoff.md)。它们将是**另一份 Task Profile**，共用这一套状态机与运行时组件，不另起炉灶。

源稿曾把「git 载体的开发流程」和「PostgreSQL 载体的产品运行」画成并列的两层架构。不沿用。理由：内核已经用 Task Profile / Agent Profile 两个词覆盖了场景差异与执行者差异；再按持久层切一层，就是源稿自己诊断过的「同名物」病换了个名字。持久层差异是载体取值，不是架构分层。

**内核按 commit 引用**，防双向耦合：本稿引用的是 `request-lifecycle.md` 当前主线文本；内核对象名 / 状态名的任何修改按 T2；改后必须重跑第 3.4 节映射表与合法边的集合比较。

---

## 3. Task Profile `dev.change` 版本 1

### 3.1 契约字段

```text
profile_id            dev.change
version               1
input_schema          工单：goal · paths[] · baseline_commit
                      · read_only_inputs[]（路径 + 版本锚）· tier ∈ {T0,T1,T2}
                      · executors{proposers[], arbiter, acceptor}（T1/T2）
                      · acceptance[]（逐条编号；T0 = 一个已签任务类包名）
output_schema         一个或多个 Artifact 落在 final_path(s)，版本 = commit
normalization_rules   goal → 可判定 acceptance 条；歧义实质改变结果 / 权限 / 成本 / 风险时才 ask
required_context      read_only_inputs 按版本锚取；候选不得改动它们
acceptance            机械条（validator 跑）+ 判断条（acceptor 跑，按冻结标准逐条给结论，不得改标准）
evidence              每条断言现状的句子附 file:line 或可复跑命令；采信等级按第 4.3 节计算
freshness             baseline_commit 固定；基线移动 → 新 Task
allowed_capabilities  读整仓、写自己 worktree、不 push 主线
budget                观察窗 W = 已交付各家用时中位数；max_rollbacks = 2
retry                 逾期 → 该家 Attempt FAILED(timeout)，Task 不失败（I8）
approval              权力表 H1–H8（第 5.2 节）；tier 决定开工前 APPROVAL 触点数 0/1/2
privacy               文档任务无；财务数据任务另由其 Task Profile 定
```

**tier 不是三个 Task Profile**，是 `execution_policy` 的一个字段——改的是 Attempt 组数与审批触点，不改输入 / 输出 / 验收的形状。T2 的七环节是 execution_policy 定义的 Attempt 阶段图，每个 Attempt 记 `kind ∈ {proposer, reviewer, arbiter, objector, acceptor, publisher}`，产物是 typed Artifact。

⚠ 「Attempt 可产出 typed Artifact」是否算对 Attempt 定义的扩充，要走内核修订纪律另裁，本稿不擅自扩。选择「Attempt 可产出 typed Artifact」而非「每环节一个 child Task」，理由是后者会让 T2 一轮生成七个 Task。这是产物类型的细化，不改 Attempt 状态与边。

### 3.2 工单：一个冻结的 Artifact，一次确认

把协议的 `round.md` 一般化为**工单**。**工单是 Artifact，不是 Task 状态。**
它只有 Artifact 的两个状态词 `DRAFT → FROZEN`。Task 自身的状态由产物推导。任何档位都有工单：

```toml
[order]
id, tier                    # tier 只选 guard 表，不是状态
artifact_state              # DRAFT | FROZEN
route_proposal              # 模型证据 + 确定性规则结果，含 policy_version
route_effective             # T0：= proposal，由策略放行；T1/T2：H2 回执确认后的值
route_delta                 # 人相对 proposal 改了哪些字段；空 = 全盘沿用
intent_restatement          # 执行者用自己的话复述需求 + 决策点 + 标出的歧义
acceptance = [...]          # 逐条编号，冻结后不改；T0 为一个包名
frozen_sections = [...]
[executors]
intake_author               # 起草 intent_restatement / acceptance 的执行者
                            # 同票禁任 proposer / arbiter / acceptor，分发前机械拦
proposers, arbiter, acceptor, approver
[workspace]
source, baseline_commit, write_actors, review_needed, submodule_plan
[budget]
observation_window_rule, max_rounds, max_rollbacks
```

`round.md` 的 `status` 字段是声明，不是状态。推导值 ≠ 声明值即报错，不许靠改声明让它消失。

### 3.3 档位 = 三张表，不是三套状态

每个 tier 对应：一张 **guard 表**、一张**必需产物表**、一份 **interrupt 策略**。三者读同一个工单 schema，脚本按 `tier` 取表。档位判据在协议「流程档位」，本稿不重写。

| 档 | 形态 | 开工前 APPROVAL 触点 |
| --- | --- | --- |
| T0 | 做 → 独立验收 → 确认 | 0（H1 由已签任务类包承担，H2 按策略放行） |
| T1 | 出稿 → 独立评审 → 验收 → 确认 | 1（H1+H2 合并为一份回执） |
| T2 | 协议七环节 | 2（H1 与 H2 分离：验收标准须在参赛者看到题目之前冻结） |

**T0 的验收条只能来自已签策略里的命名任务类包**，不得自拼门禁子集。每个包三项：`paths` / `gates` / `covers`。

包纪律：任何 T0 包的 `paths` 展开集不得覆盖权威层文件、`policies/**`、门禁脚本及其依赖——否则「改门禁」与「被门禁判」落在同一可写面。**宽包不许，多个窄包可以。**跨包的题目升 T1，不塞进宽包。

两道门，不是一道：

| 何时 | 查什么 | 失败则 |
| --- | --- | --- |
| **开工门**（H2 / 分发） | 包名 ∈ 已签策略；T0 + `decide` 有 `RouteDecision` 落账；T1/T2 有落盘回执 | 拒发 |
| **完工门**（L0 / L1 / H5 前） | 实际 diff 文件集 ⊆ `paths`；`gates` 全过；H5 内容门 | 不进 H5 |

T0 的诚实定义：「题目能被『改动限于路径 X、通过门禁 Y』完全表达」。表达不了的就不是 T0。T0 的承诺只是「开工前零触点」；发布仍要 H5。「可逆、不写共享最终路径、免 H5」的出口属省事方向，本稿不加，见第 13 节。

**升档不需要理由，降档必须写明理由并经人确认。中途只能升，不能降。**

### 3.4 产物 → 唯一状态机

| 产物 / 事件 | Task | Attempt | 说明 |
| --- | --- | --- | --- |
| 工单文件出现 | `RECEIVED` → 即刻 `VALIDATING` | — | 空转不停留 |
| 工单 `DRAFT` / `FROZEN` | `VALIDATING` | — | **Artifact 状态**，不是 Task 状态 |
| router `ask` | `VALIDATING → WAITING(INPUT)` → 回 `VALIDATING` | — | H8 |
| H1 冻结 | `WAITING(APPROVAL) → VALIDATING` | — | 验证期恢复边 |
| H2 开工 | `VALIDATING → QUEUED` | — | T0 按策略放行 |
| 派发 | `QUEUED → RUNNING` | `CREATED → RUNNING` | `dispatch = manual` 的由 `dispatch_event` 承担 |
| 某家交付并 commit | `RUNNING` | `RUNNING → COMPLETED` | 产出 typed Artifact，**不等于 Task 成功** |
| 某家逾期 | `RUNNING` | `FAILED(timeout)` | Task 不因此失败（I8） |
| 某家用尽观察窗 | `RUNNING` | `BUDGET_EXCEEDED` | Task 按内核进 `WAITING(APPROVAL)`（H4）或重新 `QUEUED` |
| 执行期澄清 | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | 在跑的 → `WAITING` | H8；执行期等待先回 `QUEUED` |
| ④⑤⑥ 回到 ③ | `RUNNING` | 新 Attempt；旧的终态不重开（I5） | |
| ⑥ 确认待人 | `RUNNING → WAITING(APPROVAL)` | — | H5 |
| ⑥ 回执成立 | `WAITING → QUEUED` | publisher `CREATED` | **不是** `WAITING → SUCCEEDED` |
| ⑦ 发布 | `RUNNING → SUCCEEDED` | publisher `COMPLETED` | Side Effect 由人执行本地合并 |
| 无获准成功路径 | `RUNNING → FAILED` | — | |
| 候选 `STALE` / `SUPERSEDED` | — | — | **Artifact 状态** |

**没有一个新词，没有一条内核之外的边，内核每个 Task / Attempt 状态都有落点。**这三件合起来才是 P0 的验收方式。

中途 H3/H4/H6 改的是所有 Attempt 共用的预算、环节或验收条，所以命中权力表时让 Task 进 `WAITING(APPROVAL)`。这是 `dev.change` 的 guard 选择，不改内核「有一路可推进则保持 RUNNING」的语义——它选择在这些行上让全 Task 暂停。

**`RUNNING` 目前判不了，如实声明。**git 产物只能证明「已分发」与「已交付」。缺交付可能是未调用、在跑、崩了没产物、机器失联、观察窗超时五种之一。归因：这是 `observability ≤ process` 的**执行者属性**，不是 git 载体缺陷——换成 PostgreSQL 一样判不了 CLI 进程内部。处置：orchestrator 单写 `events.jsonl`（投影，不是权威；权威仍是 commit）；落地前脚本把 `QUEUED` / `RUNNING` 合并显示为「已分发未交付」并标 ⚠。

### 3.5 路由：三值，模型只建议

```text
输入：原始请求 + 附件 + 请求者上下文
  ├─ 分类建议（可选；受限模型节点，无工具，固定 schema，低预算）
  │      → { tier_hint, domain_hint, evidence[] }     ← 只是证据
  └─ 确定性规则表（版本化）
         → decide  : 唯一命中 → RouteDecision{... policy_version, matched_rule}
         → ask     : 零命中或多命中 → 产生 H2 Interaction
         → refuse  : 命中拒绝规则 → Task REJECTED
```

三值而不是二值，是为了让「不知道」不被压成「默认通用」。`tier` 的判据就是协议「命中任一条即 T2」那四条；分类节点的产出是「四条各自命中与否 + 证据」，人只在 `ask` 时介入。

默认值是策略版本，不是代码兜底。H2 的默认必须来自版本化配置，每次按默认跳过都落一条 `RouteDecision{policy_version, matched_rule}`。

OpenClaw 的 gateway 按 channel binding 确定性映射，不读用户语义。可借的是「确定性 binding + 落账 + fail-closed」；不借它的名字来指语义路由。

---

## 4. 执行者、粒度、证据

### 4.1 登记表

执行者登记在 [`protocol/agents.toml`](protocol/agents.toml)。字段用 `harness`，不用 `runtime`——后者在本仓同时指过产品运行时、内核 Agent runtime 与分组键，一词三义。

```toml
# 形状示意，取值以 agents.toml 为准
[ap.luna]
harness = "codex-cli"   provider = "openai"    model = "gpt-5.6"   model_pinned = false
dispatch = "argv"       observability = "process"
enforcement = "outer-only"   sandbox = "self"   workspace_isolation = "convention"
roles_allowed = ["proposer","reviewer","objector","acceptor"]   supports = ["dev.change/1"]

[ap.kimi]
harness = "codex-cli"   provider = "moonshot"  model = "kimi-k3"   model_pinned = false
dispatch = "argv"       observability = "process"   enforcement = "outer-only"

[ap.cursor]
harness = "cursor-agent"  provider = "xai"     model = "cursor-grok-4.6-high"   model_pinned = true
dispatch = "argv"       observability = "process"   enforcement = "outer-only"

[ap.fable]
harness = "cursor-app"  provider = "anthropic"  model = "claude-fable-5.1"   model_pinned = false
dispatch = "manual"     observability = "fs-only"   enforcement = "outer-only"
roles_allowed = ["proposer","reviewer","objector"]

[ap.qwen]
harness = "qoder"       dispatch = "argv"       observability = "process"
enforcement = "outer-only"

[ap.opus]
harness = "claude-code" provider = "anthropic"  dispatch = "argv"
roles_allowed = ["arbiter","publisher"]

[principal.owner]
channel = "inbox+commit"          channel_grade = "shared-credential"
```

纪律：

- **没有任何条目把人标成执行者。**`[principal.owner]` 没有 harness / dispatch / observability。
- `dispatch = manual` 的执行者，`observability` 只能是 `fs-only`。脚本据此校验不许填高。登记表机械非空不等于填对。
- **`roles_allowed` 由登记表约束**，不由每轮口头指定。分发前对照协议「角色分离」禁令，冲突即拒绝。
- **「登记集合」与「自动路由候选集」是两个集合。**前者记「存在」，后者记「可被 router 选中」。`dispatch = manual` 的执行者：要么经显式桥接（`dispatch_event{mode = manual}`，产生可审计 Delivery），要么不得进入自动路由候选集——不得靠不可见的手工粘贴冒充自动分发。两条都不满足时它退出自动路由候选集，但仍留在登记表。
- `dispatch_event` **不是权力表行**。它必须可数（第 8.2 节的上界要数它），但它不是批准。

⚠ 未验证：luna / kimi 的 argv 未钉 `--model`；fable 的模型在 GUI 内选择，不可机械核验；qwen 的 provider / model 在任务书该栏为「—」，推断不得进登记表取值。

### 4.2 粒度是三个字段，至少四档

能看多细、能在哪拦、沙箱谁提供，是三件事，可以分开取值。例证：`codex exec --json` 可见性到工具调用级，但吐的是执行者自报，运行时拦不住也验不了——强制点仍在进程外。

| 字段 | 取值 | 含义 |
| --- | --- | --- |
| `observability` | `tool.enforced` ＞ `tool.reported` ＞ `process` ＞ `fs-only` | 运行时能看见的最细粒度 |
| `enforcement` | `tool-level` / `outer-only` | 运行时能拦在哪：工具网关（事中）/ 只有进程外层 |
| `sandbox` | `runtime` / `self` / `none` | 沙箱由谁提供、策略由谁定 |

当前取值：luna / kimi / cursor / qwen 为 `process`（可升 `tool.reported`）；fable 为 `fs-only`。全部 `enforcement = outer-only`，全部 `sandbox = self`。**目前没有一家是 `tool.enforced`。**那是 SDK 腿建成之后才会出现的取值。

`enforcement = outer-only` 时，内核 `F-EXEC-01` 只能靠外层实现。外层控制（文件可见范围、进程环境里没有写凭据、出网默认拒绝）是 **executor adapter 的环境策略**，不是「换三把钥匙就能得到的安全架构」。无法外层阻断时必须标 `audit_after`，**不得声称事中拦截**。今天这些外层控制**并未就位**——见第 12 节。

### 4.3 证据权威性：由粒度推导，不由执行者声明

**采信等级 = `min(provenance, observability 可见上限, isolation 实际强度, verifier 独立性, coverage)`，任一未知即降级，不取平均。**

| 等级 | 观察来源 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| `E0 ASSERTED` | executor / principal 自述 | 仅作为待验证主张 | 行为发生、作者身份、完整性 |
| `E1 REDERIVED` | 运行时从冻结 workspace / Artifact 重算 | 重算范围内的结果 | 未覆盖的进程内部动作 |
| `E2 PROCESS_OBSERVED` | 外层记录 argv / stdio / 退出码 + E1 | 调过哪个进程及其外部结果 | 内部逐工具调用 |
| `E3 TOOL_OBSERVED` | 运行时工具网关逐调用 Event + E1 | 经网关发生的调用 | 绕过网关的系统调用 |
| `E4 EXTERNAL_AUTHORITY` | executor 凭据域**外**的受保护日志 / 签名 / 审计 API | 指定主体或外部副作用的权威事实 | 人是否充分理解 |

轨迹 `provenance` 三值：**attested** = 运行时从它控制的底座直接取得；**reported** = 执行者或人的自报；**inferred** = 事后读产物推出来的。映射：`E0` = `reported` / `inferred`；`E1`–`E4` = `attested` 的子档。

四条推论：

1. **只有 `tool.enforced` 的事件是证据。**`tool.reported` 的事件流是索引，可据它决定去重新推导什么，不能据它下结论。`process` / `fs-only` 的自报一律是主张。
2. **证据由运行时从工作区重新推导**，由 validator 跑，不由执行者跑。反例：一家拿休眠代码当能力证据，九份评审无一发现。
3. **覆盖声明必须同时列查了什么与没查什么。**零命中只有在输入集合可枚举且枚举成功时才是 `E1`；否则是 `UNKNOWN`，不是 pass。
4. Artifact 作者拆 `author_claimed` 与 `author_attested`。当前通道下身份侧全部是 `reported`。

### 4.4 独立性按字段推导，不用单值

登记 `provider` / `harness` / `model_family` 三个事实字段。分组键首版 = `harness`（同一 harness 的提示词与工具集相同，相关性最高）。独立信号数 = 持相同主张的执行者所属不同组的个数（同组 N 家只计 1）；组内任一家带 `file:line` 或可复跑命令，该组权重 ×2。裁决时先比独立信号数，相同则比带取证的组数。

评审之间若有引用关系，引用方在被引条目上视同同组——这是本票 evidence graph 上的关系，不改静态登记。

⚠ 未验证：同 harness 不同模型的相关性到底多高。`runtime` 轮唯一的观察是同 harness 的两家差异大于同厂不同 harness 的两家，单轮单题不足以把分组键改成 `(harness, model_family)`。

---

## 5. 人：principal 与权力表

### 5.1 人的位置

人不是执行者，不是一条平行路径。人同时是：

| 词 | 是什么 | 内核落点 |
| --- | --- | --- |
| **requester** | 提交 Task 的人 | 提交信封；后端从认证上下文确定，不信前端自报 |
| **principal / approver** | 持有权力表某行的批准权 | Interaction 的受众；`eligible_principal` |

本稿不引入第三个词。B4 只约束「人不是执行者」，不禁止人同时是 requester 与 principal——今天只有一个 `owner`，两顶帽子戴在同一个人头上。权力挂在 principal 上，不挂在执行者条目上。将来多用户只加 principal 与授权行，不改表结构。本轮不引入 capability 体系——只有一个 principal 时那是空列。

人与 agent 的真实差异在本结构里各有落点，不另立一条路径：

| 差异 | 落点 |
| --- | --- |
| 有批准权 | `principal = owner` 持有权力表全部行 |
| 可裁量「不值得走全流程」 | H3（省事方向）+ H6（推翻）；裁量是表内的行 |
| 承担最终责任 | 治理条款：H5 的确认者即对外责任人。脚本判不了，不进权力表 |
| 可跨会话续接 | 人的 Attempt 无 checkpoint 义务，[`handoff.md`](handoff.md) 是它的 checkpoint；**不落盘的意图不是状态** |

### 5.2 权力表

权力表是驱动 `WAITING(APPROVAL)` 的唯一来源。没有强制点的行不许进表。表外无未分类的 APPROVAL interrupt。内核另外四类等待（`INPUT` / `DEPENDENCY` / `RESOURCE` / `EXTERNAL`）按内核规则产生，不进表；但 `INPUT` 类问人受「只有歧义会实质改变结果、权限、成本或风险时才请求澄清」约束。

| 行 | 状态转换 | eligible_principal | auto_policy | enforcement_point |
| --- | --- | --- | --- | --- |
| H1 | 工单 Artifact `DRAFT → FROZEN`；Task `WAITING(APPROVAL) → VALIDATING` | `owner` | 无；T0 由已签任务类包承担 | validator 查落盘回执 |
| H2 | Task `VALIDATING → QUEUED`（开工确认） | `owner` | 有：T0 + `decide` | orchestrator 不分发 |
| H3 | 省事方向裁定生效：`WAITING(APPROVAL) → QUEUED` | `owner` | 无 | 落盘回执；无回执的裁定行视同不存在 |
| H4 | 扩权（冻结授权范围内的预算 / 资源额度） | `owner` | 无 | 同 H3 |
| H5 | 不可逆 Side Effect（写共享最终路径 / 合并主线 / 删除或迁移已有资产） | `owner` | 无 | **人执行该动作**；VM 上的脚本与 hook 不是强制点 |
| H6 | 推翻裁定 / 改冻结验收条：`WAITING(APPROVAL) → QUEUED` | `owner` | 无 | 冻结区逐字节 + 落盘回执 |
| H7 | 非终态 `→ CANCELLED`（先持久化取消意图） | `owner` | 无 | 裁定行（表内唯一不要求仓外锚的行，失败安全方向） |
| H8 | 回答本 Task 的 `WAITING(INPUT)` | `requester`（开发任务里 = `owner`） | 无 | 库的恢复原语消费令牌；响应者由通道鉴别 |

纪律：

- **`AUTH-EFFECT` 类不得直达成功终态。**H5 之后走 `WAITING → QUEUED` → publisher `COMPLETED` → `RUNNING → SUCCEEDED`。
- **H1 属验证阶段**，恢复边是 `WAITING → VALIDATING`，不是 `WAITING → QUEUED`。
- **改授权范围不属 in-Task 修订**：按内核应建带 `supersedes` 的新 Task。H4 收窄为「冻结授权范围内的预算 / 资源额度」。
- H7 是表内唯一例外：伪造取消只停工、不放行任何东西。取消裁定必须附已产生副作用清单；误取消的重开是新 Task（I5）。
- 回执**只认落盘**。当前载体是 `rounds/<id>/rulings.md` 的「人确认」列 + 所有者 commit。对话里说「同意」不算。人不回执时：H1、H3–H7 等待，**不设超时默认**；只有 H2 在策略明确允许的 T0 场景可以按默认放行，且要落账。

**今天 H5 的强制点是「人的手」，不是凭据隔离。**发布路径是本地 merge，不经网络——`git ls-remote --tags origin` 只有 `2.0.0` 与 `pre-architecture-v2-final-20260813`，本机 `runtime/*`、`refact/*` 冻结标签一个都不在远端。把强制点设计成「远端 key 管主仓」管不着这条路径。目标态若要把强制点移到人够得着、agent 够不着的操作面，先决条件是这个操作面真的存在（[`rounds/_spike-sign/forensics.md`](rounds/_spike-sign/forensics.md) 登记该前置未满足）。在此之前，诚实的写法是：H5 = 人做合并 + 落盘确认；VM 脚本报状态，不充边界。

`check-no-owner-creds.sh` 是配置卫生检查，防人为疏漏；**不是边界**——agent 能改它。

### 5.3 人的通道

```text
sunmoonai/docs/dev-plan/rounds/<id>/inbox-owner.md     ← 引擎写，人读
                                                          必备：interaction_id、transition、待决内容、截止判据
                                                          H1–H6 另加 target_commit、diff_stat
                                                          H1/H5 再加冻结验收条编号表
落盘回执（rulings.md「人确认」列 + 所有者 commit）       ← 人写，引擎读
```

字段分级：无默认的字段不得预填（预填等于把盖章做成阻力最小路径）。

| 分级 | 字段 | 规则 |
| --- | --- | --- |
| 无默认，必须显式填 | 验收条、executors 名单、`tier` | 收件箱留空；这三项为空即判无回执 |
| 可预填默认 | workspace 计划、预算窗、观察窗规则 | 预填值与人改后的值都落账 |

通知丢了不要紧，收件箱文件是真源。每次 H 回执登记三个观察值（耗时、相对预填的改动项数、按行分计的确认次数），不由观测值自动触发 H6。

**principal 通道也有粒度。**今天 `[principal.owner]` 的 `channel_grade = shared-credential`：所有者与 agent 同机、同用户、同免密 sudo（第 12 节第 3 条）。后果：轨迹里所有 `power_row ≠ —` 的条目，响应者身份都是 `reported`；服务态若在同一信任域里提供响应端点，只是把 `reported` 搬了个家。**先有 agent 够不着的操作面，再谈把通道升级为 attested。**

---

## 6. 工作区、状态判定、git 载体

### 6.1 工作区供给：纯函数

```text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan) →

  前置判据（任一不成立即新建，不复用）：
    现有工作区 owner == task_id 且 == 该执行者      # 独占
    git status --porcelain 为空                    # 干净；脏改动绕开，不 stash
    HEAD == baseline_commit                        # 基线一致

  数量规则：
    |write_actors| = 0   → 不建可写工作区
    |write_actors| = 1   → 一个独占工作区、一条命名分支
    |write_actors| = N   → 同一 baseline 上 N 个 worktree + 一个整合 worktree
    review_needed        → 额外一个检视 worktree，用完删
    submodule_plan       → 多仓时逐仓钉 commit 并记父仓 gitlink
```

- 数量看写者数，要不要新建看独占与干净，**都不看复杂度**。三者可机械判定，复杂度不可。
- 「事先创建好的仓库」只能是 `source`，不能是工作区。多个 Task 塞进同一个预建仓违反「workspace 唯一归属本 Task」。
- 来源一律钉 commit，不钉地址或分支。

### 6.2 独占在 CLI / GUI 腿是约定，不是隔离

| | SDK 腿（目标态，`observability = tool.*`） | CLI / GUI 腿（现状） |
| --- | --- | --- |
| 工作区怎么来 | 挂进运行时提供的沙箱 | 宿主上建目录，把路径传给进程 |
| 进程看见什么 | 沙箱根 | **整个文件系统**（本 VM 上各 CLI 与 GUI 后端都以同一用户跑） |
| 「独占」是什么 | 隔离 | **约定**。打破约定的动作，运行时事中看不见 |

登记字段 `workspace_isolation = enforced | convention`，当前全部 `convention`。后果：CLI 腿的授权范围声明只能依赖「事后审计可发现越权读取」；**涉及第二租户或真实财务数据前，CLI 腿的数据源必须经运行时的数据网关，不得给裸库凭据。**

现场证据：同一执行者同一会话内 `id` 先报 `uid=0(root)`（`uid_map: 0 1003 1`，助手自带沙箱）后报 `uid=1003`。取证必须附 `hostname; id; cat /proc/self/uid_map`，只看 `id` 会误判。本次取证（宿主 shell，2026-09-06）：

```text
hostname          VM-0-13-ubuntu
id                uid=1003(zym)  groups=...,27(sudo),...,988(docker)
uid_map           0 0 4294967295      # 恒等映射，是真实 uid
```

### 6.3 状态判定与分发

[`protocol/round-status.py`](protocol/round-status.py) 与 [`protocol/round-dispatch.py`](protocol/round-dispatch.py) 的设计（从产物反推、判据即命令、只生成不执行）保留，要改的是一般化：

| 现在 | 改为 |
| --- | --- |
| 只认 T2 七环节 | 按工单 `tier` 读对应 guard 表与必需产物表 |
| 输出「当前环节」 | 输出 Task 状态（唯一状态机的词）+ 当前环节 + 各 Attempt 状态 |
| `status` 是声明 | 降为人读缓存；推导值 ≠ 声明值即报错 |
| 角色由每轮口头指定 | 分发前对照 `roles_allowed` 与角色分离禁令 |
| 只看工作仓产物 | 加读 `events.jsonl` 区分已分发 / 在跑 / 超时；落地前合并显示并标 ⚠ |
| 只判状态词 | 同时输出「上一状态 → 本状态」，边不在合法转换表内即报错 |

每条判定声明覆盖范围。空集合不是「全部完成」——要跳过某环节，必须在 `round.md` 明写 `skip_stages`。

**隔离目前靠纪律，不靠机制。**各 worktree 共享同一个 `.git`，任何人都能 `git show <别家分支>:<路径>`。这是协议最大的已知缺口，如实告知。

### 6.4 git 载体：什么是权威、什么验不了

先把 git 的两个角色拆开：

- **git 当 Artifact 载体**——代码与文档 Artifact 的版本就是 commit。**这是永久的。**
- **git 当账本**——用 commit 历史 + `rulings.md` + `events.jsonl` 反推状态。**这是脚手架，要拆。**拆除条件见第 8.1 节：服务态与手工态按等效判据比对全等，且每类条目的 `attested` 计数 ≥ 手工态。

| 内核要求 | git 载体的落法 |
| --- | --- |
| 权威事件 | 可从发布点 tag 到达的 commit；人的决定：`rulings.md` 落盘回执 + 所有者 commit |
| branch / tag | branch 是运输通道，不是评审对象；tag 仅在受保护模式下是权威引用 |
| 比较交换 | 发布校验目标 ref 仍指向开始时记录的 commit；不一致即失败并新建整合 Attempt |
| 终态不可重开（I5） | round id 全局不复用；纠错用 `supersedes` 新回执，不改旧记录 |
| 工作区文件 | 永不作判据；判据只看提交 |

**git 载体验证不了、不得宣称「已在开发层验过」的三样：**

1. **事务性**——结果、验收、预算结算与终态事件的原子提交；git 的多 ref 更新不原子。
2. **租约**——Attempt 的 `lease_owner / lease_expires_at`；开发侧只有观察窗判据。
3. **fencing**（I14）——过期 worker 的写入被拒；开发侧靠整合方核对，不靠机制。

「先在这一层跑通，再往下实现」的准确表述：手工态跑通的是对象形状、边、Interaction 形状与权力行；它跑不通的是并发语义与证据的 `attested` 等级。

---

## 7. 中断与恢复：用库的原语

内核 Interaction 的绑定字段（「WAITING 与 Interaction」）出向是 `question_or_action` 一段自由文本，入向是 `resume_token_hash + consumed_at`。缺口是真的：上一轮所有者裁决以 `rulings.md` 的行存在，账本上没有一条是 Interaction 对象。财务分析里「人改计划两条再继续」的形状也需要入向能带内容。

**解法不是自造一套入向三值 + 载荷 + 过期校验。**基座库已经有中断与恢复。独立复核（`investment-backend` 子模块 `18d88c7c`）：

出向：`interrupt()` 收任意 dict。

```text
# investment-backend/app/app/infrastructure/graph/pilot_graph.py 约第 59–68 行
value = interrupt({
    "kind": "confirmation",
    "action_id": action_id,
    "prompt": "确认使用这些检索证据生成最终回答？",
})
return {"approval": str(value)}
```

入向：`Command(resume=<任意值>)` 一个参数。本仓全部实际调用都是这一个参数（`rg "Command\(resume=" investment-backend`：测试、脚本、`agent_graph.py`、`pilot_agent_graph.py`、`langgraph_runtime.py`，没有第二套入向协议）。

恢复：同一个 `thread_id`，检查点原地继续。内核自己已经写了「Attempt 若从 checkpoint 原地恢复，可在自己的状态机内 `WAITING → RUNNING`」。

```text
# graph_runtime_service.py:14-15  配置就是 thread_id = session_id
return {"configurable": {"thread_id": session_id}}

# graph_runtime_service.py:40-42  同一 config 上 stream；碰到 __interrupt__ 返回
for chunk in graph.stream(graph_input, config=config):
    if "__interrupt__" in chunk:
        return GraphRuntimeResult(state=chunk, interrupted=True)

# langgraph_runtime.py:17-20  恢复 = Command(resume=user_input) + 同一 session_id 的 config
return self.stream_with_config(
    graph, Command(resume=user_input), self.build_config(session_id=session_id),
)
```

`GraphRuntimeService.resume` 本身是 `NotImplementedError`（`:26-31`），适配器必须把恢复输入翻译成库的命令类型——这是 A4「依赖边界限定在 SDK」的代码形状，不是缺口。

因此 `dev.change` 的 H8 这样接：

1. 需要人时，adapter 调库的 `interrupt(payload)`；payload 的形状由 **Task Profile 的入向约定**声明，不写进内核绑定字段表。
2. 人的答复经 principal channel 到达后，adapter 调 `Command(resume=答复)`，**同一 `thread_id` 原地续跑**。
3. 这不是新 Attempt，也不建新 Task。内核 Attempt 状态机走 `WAITING → RUNNING`。
4. 若人的答复实质改变了目标、口径、授权范围或 Profile 版本，那才按内核建带 `supersedes` 的新 Task——四个条件一个都不命中时，就是同一次执行的恢复。
5. 过期、异键、跨 Task 的恢复由库与内核 `AT-07` 拒绝，不在 Profile 层再造一套校验。

**需要载荷这个需求，是被「恢复必须开新 Attempt」自己造出来的。**库的恢复不换 Attempt，载荷就是 `resume` 的那个值。render 属 Delivery，不进内核绑定——把渲染放进内核会让每次 UI 改动都变成规范修订。

若将来要扩展内核 Interaction 绑定字段，按内核「修订纪律」开一个规范修订工作单元：只改字段、不改状态词与合法转换表；历史 v1 响应只能标「已消费，无载荷」，严禁回填成「批准」。**本稿不是那个工作单元，也不预写字段表。**

---

## 8. 等效、开销、绕过

### 8.1 等效判据

两层：

| 层 | 比什么 | 何时可机械判 |
| --- | --- | --- |
| **S 层（schema）** | 对象集合、状态词、**边**、权力表行、Interaction 绑定字段、Agent Profile 字段 | **现在** |
| **R 层（run）** | 同一 Task 的四条序列，经投影 Π 之后逐条对应 | 两种 orchestrator 都按同一 schema 落账之后 |

「谁在哪条边上有权」属 S 层，是静态约束，不塞进一次 run 的轨迹里比。

```text
trace_entry = { seq, layer, subject_id, from→to, actor, power_row,
                payload_ref, provenance, evidence_ref }
Π = 丢掉执行者私有 Event 与 at
    保留 Task/Attempt 的边、权力表命中的 Interaction、Artifact 版本与作者

TraceEnvelope = { task_profile_id/version, acceptance_contract_digest, policy_version,
                  principal 身份域, 输入摘要, Side Effect 摘要, Evidence authority 摘要 }
```

没有 `TraceEnvelope`，两次运行可以状态、Attempt、Interaction、版本全同，而其中一次用未获权凭据发布——算法会误报等效。

比对规则：

1. **白名单制。**允许不同：载体、orchestrator 实现、执行者可观测粒度的取值、Π 丢掉的 Event、`at`。不允许不同：状态、边、对象、Interaction 形状（投影后）、`power_row`。白名单之外一律失败。
2. **比对粒度取较粗一腿，并显式列出未比对项。**
3. **两边都要声明权威源与重建规则。**手工态轨迹是从 commit 重建的投影。
4. **等效只能在两条轨迹的最低来源等级上宣称。**比对结论必须附各类条目的 `attested` 计数。
5. **权限归因项在 bootstrap 期强度为零，单列判。**服务态不得把手工态的回执继承为可信先例。
6. **先验证每个状态 ⊆ 内核状态集、每条相邻边 ⊆ 合法转换表，再比序列。**

「轨迹」不是内核对象，是 Event 序列的投影；不得据它另造第五个对象或新状态。

`refact-fable` 轮按真实产物重建的 23 条轨迹里，`attested` 仅 2 条（且身份都不 attested）。手工模式「看起来在跑」，轨迹基本不可复原——这是「先在这一层跑通」的账本版读数。对照组：`refact` 轮整合分支有 28 条逐主张提交，同一 Task Profile、同一 orchestrator 实现，`attested` 数量级不同。**差别不在载体，在纪律是否落成动作。**

样例引用纪律两条，防法不同，不可互相替代：

1. 每个引用对象须先核验其属于所声明的那一轮（防张冠李戴：对象真实存在但属于另一轮）。
2. 无 ⚠ 声明的样例条目一律按「已核验」读，凭空构造即为假证据（防把本轮形状倒灌进历史）。

### 8.2 运行时相对手工调用的开销

开销是 **(任务, orchestrator 实现)** 的函数，不是任务单独的函数。对 `orch.manual`，凡 `dispatch = manual` 的执行者每个 Attempt 至少多一次人代行的传输动作。

分类规则机械可判，全部由工单字段直接判，**不读题目自然语言**，**不得用 `tier` 反推成本**（档位由风险判据定，用档位反推成本是循环）：

| 规则 | 字段判据 | 结论 |
| --- | --- | --- |
| M1 | `proposers ≥ 2` 或 `write_actors ≥ 2` | 走运行时更便宜 |
| M2 | 计划中权力表触点数 ≥ 1 | 走运行时更便宜 |
| M3 | `read_only_inputs[]` 非空且带版本锚，或依赖另一 Task，或需要恢复 | 走运行时更便宜 |
| M4 | `paths` 与权威层路径集相交 | **必须**走运行时 |
| M5 | 副作用清单非空，或需要审计轨迹，或有复发键 | 走运行时更便宜 |
| M0 | 以上皆否 | 走运行时**更贵**，除非满足 T0 上界 |

三类走运行时反而更贵的任务：

1. **单文件笔误 / 死链修补**，且落在已签 T0 包的 `paths` 内。贵在供给：一个不需要隔离的任务被强制隔离。
2. **一次性提问 / 探索性阅读。**贵在 `VALIDATING`：为一个不需要契约的任务形成契约。目标未定时更糟，改目标还要建新 Task。
3. **对 `dispatch = manual` 执行者的任何分发。**贵在派发与身份核对。该反例的成立范围是 M0 / T0 类。

不接受「都值得走，因为留痕总是好的。」留痕成本高于这笔改动的价值时，发生的是绕过。

T0 开销上界是复合向量，任一维超标即不标 T0：

```text
(human_required_actions, persisted_artifacts, request_to_dispatch_steps, dispatch_events)
        ≤ (        2,              4,                  2,                     0        )
且 human_required_actions ≤ 同一任务手工模式的动作数
```

推论：T0 的工单必须从请求自动生成；H5 必须折进人本来就要做的那次发布动作。通知送达或敲命令不算决策，但仍计动作。

### 8.3 绕过的可观测性

绕过发生在运行时之外，账本天然看不见。「完全可观测」不可达；宣称可达就违反 P4。

1. **让绕过无利。**主线写入只经 H5；绕过的最大动机（快）被保留为合法路径（T0 上界）。
2. **对账，分母取外部 sink**，不取运行时自己看见的事件。sink 清单与各自的覆盖边界必须显式列出（主仓托管方审计、git 底座对账、工作区脏状态、终端历史）。找不到运行时 Event 的变更写成 `UnattributedEffect`，**不得反向补造一个正常 Task**。「绕过」不是内核对象。
3. **降低登记成本**：`register --from-commit` 把已发生的改动登记为带标记的合法对象；`retroactive` 的比例本身就是超上界的信号。⚠ 与 I1「原始输入不被后续解释覆盖」的关系需在内核修订单元核，本稿不裁。
4. **如实声明看不见的。**零命中只能写成「没查到」，不能写成「没有绕过」。在当前 `channel_grade = shared-credential` 下，principal 侧的绕过指标为 `UNKNOWN`。

---

## 9. 验证分层与五个词

### 9.1 L0–L3

| 层 | 谁 | 判什么 |
| --- | --- | --- |
| L0 机器门 | pre-commit / CI / `--verify` | 全部机械判据。声明覆盖范围；首跑先与人工对照再当门禁 |
| L1 独立验收 | `acceptor`（由处置表算出，既得利益最小的一家） | 冻结标准逐条；机器判不了的部分。只能按冻结标准 |
| L2 来源核对 | 被处置到的各家（异议环节） | 「我的主张有没有被误读」。条目 + 为什么错 + 应当是什么 + 可复跑证据 |
| L3 人抽三样 | `approver`（H5 前） | ① 意图是否被正确理解 ② 不可逆部分 ③ 抽样复算证据真实性。不逐行读 |

顺序不可换：L0 不过不进 L1，L1/L2 不过不叫人。L3 就是「机器全审 + 人抽检三样」；L2 是协议「异议：对整合权的唯一制衡」。

产出方 ≠ 验收方。出题方与答题方是同一个，验收就不是独立信号。

### 9.2 supervisor 解体为五个各有定义的词

| 词 | 是什么 | 今天的实体 |
| --- | --- | --- |
| **router** | 确定性代码：产生 RouteDecision | 规则表 + `round-dispatch.py` 的选人逻辑 |
| **orchestrator** | 确定性代码：推进状态、写环节通知、派发、观测逾期、回退 | `round-status.py` + `round-dispatch.py` + 运行它们的人（过渡期，是欠账不是角色） |
| **arbiter** | agent 角色：定基座、逐条吸收、写处置记录、处置异议 | 工单 `arbiter` 字段 |
| **acceptor** | agent 角色：按冻结标准独立验收 | 由处置表算出的一家 |
| **approver** | principal：持有权力表某行的批准权 | `owner` |

**arbiter 不兼 orchestrator。**通知与截止由脚本按工单生成，arbiter 只写裁决与处置。不需要给「轮次组织者」定名——用上面五个词替换掉全部 supervisor 及其别名。

---

## 10. 文档职责与删除条件

### 10.1 权威写入面

| 文件 | 写什么 | 不写什么 |
| --- | --- | --- |
| [`working/request-lifecycle.md`](working/request-lifecycle.md) | 内核对象、状态机、不变量 | 开发流程、档位、权力表取值 |
| [`protocol/round-protocol.md`](protocol/round-protocol.md) | 七环节、档位判据、裁量、产物落点、环节判定 | 运行时组件、Task Profile 字段 |
| **本稿** `agent-dev-guide.md` | 运行时如何承接内核；`dev.change`；权力表；粒度与证据；中断如何接库 | 内核定义、流程规范正文、业务功能、进度 |
| [`constraints.md`](constraints.md) | 跨仓硬约束 | 某一轮的设计 |
| [`development-plan.md`](development-plan.md) | 要建什么 | 怎么走一轮 |
| [`implementation-plan.md`](implementation-plan.md) / [`handoff.md`](handoff.md) | 顺序与进度 | 架构结论 |

执行层架构（Codex / Harness SDK 能力矩阵、双 runtime 部署）的读者是实现 investment-app 的人，不是「接一个开发任务」的执行者。它应迁到独立文件（源稿建议的 `executor-architecture.md`），不和开发指导装在一起。本稿不迁那一块——那是另一次搬家，方向无争议，走 T1。

目标文件树不在本稿冻结。需要的新文件（`policies/tier-defaults.toml`、`policies/state-machine.toml`、`scripts/gates/`）在实施时按 T2 开轮添加；`state-machine.toml` 头部钉 `request-lifecycle.md @ <commit>`，被「按 commit 引用」纪律罩住，不是第二真源。

协议演化不是第三个 Task Profile，是 `dev.change` 上 `tier = T2` 钉死的工单（改协议命中不可逆与权威层）。

### 10.2 两份源稿的删除条件

本轮 ⑥ 确认后，`refact-fable.md` 与 `runtime-architecture.md` 将从主线删除。删除前须机械可判：

1. 本稿通过 `doc-gate.py` 与 `anchor-gate.py`；
2. 第 14 节落点表 64 行，抽查落点属实；
3. `rg -l 'refact-fable.md|runtime-architecture.md'` 在指导文档中的引用改为指向本稿或内核 / 协议；
4. 两份 lifecycle 旧文（`working/development-lifecycle-*.md`）的删除仍按其自身条件，不在本轮范围。

旧文全部标题 → 新落点的枚举，由第 14 节承担。映射表是覆盖的索引，不是覆盖的证明。

---

## 11. 诊断与对原建议的处置

### 11.1 六个结构问题（仍然成立）

| # | 问题 | 本稿处置 |
| --- | --- | --- |
| 1.1 | 「两条路径」是假分叉：入口差异只剩「谁按了回车」 | 一条运行时，人不是路径 |
| 1.2 | supervisor 已有三套同名物，还有未定义别名 | 拆成第 9.2 节五个词 |
| 1.3 | 权力与流程混写 | 权力表驱动 APPROVAL，流程在协议 |
| 1.4 | 一个环节判不了（人的确认不是产物） | 回执只认落盘；⑥ 有没有落盘由命令判，内容由人判 |
| 1.5 | 执行架构与开发流程装在同一份文件里 | 第 10.1 节拆开职责；搬家另走 T1 |
| 1.6 | 档位只有 T2 有正文 | 第 3.3 节三张表；T0/T1 可执行 |

「两条路径」的差异不足以支撑两份文档。`automation-roadmap.md` 已指出四家助手 CLI 化之后入口差异也消失。

### 11.2 对所有者 2026-09-05 思路的处置

| 原建议 | 处置 | 说明 |
| --- | --- | --- |
| 人不再是 supervisor，改为 HITL | **改造** | 人是 principal，不是执行者。interrupt 点由表导出，不手画 |
| 路由先意图识别再选通用/专业 | **改造** | 路由三值化。意图识别只建议，不得决策 |
| 「openclaw 的 gateway 模式」 | **不采纳此命名** | 借 fail-closed 与落账，不借名字指语义路由 |
| 路由后选 supervisor，可 interrupt，可默认 | **采纳并合并** | 并入 H2。工单里是 `arbiter` 字段 |
| 规划 list → 是否 subagent → interrupt | **采纳并合并** | 同上，避免三次前置 interrupt 退化成盖章 |
| 有 subagent 必须建 git 仓库 | **采纳** | `write_actors ≥ 1 → 必有独占工作区` |
| 用户本轮就是仓库→引用地址；否则用预建仓 | **改造** | 预建仓只能是 `source`；一律钉 commit |
| 拉取 master | **改造** | 落 `baseline_commit` |
| worktree：agent 用看复杂度；人用为审核 | **一半采纳** | 人的检视 worktree 采纳；agent 侧按独占 / 干净 / 写者数 |

---

## 12. 已被证伪、不得复活的设计

> **本节是「被证伪」语境。**下列专名只在本节出现，且每一条都附独立复跑结果。
> 它们不得以任何形式进入第 2–11 节的现行设计。保留本节的理由是防止再犯（Q4：保留）。

六条的共同成因：在没有用命令确认「这个动作现在实际发生在哪、由谁做、经过什么」的情况下推演。第 1 条是根——自定义入向协议一旦成立，就必须有载荷、有 schema、有过期校验、有 Task 级暂停，后面几条跟着长出来。

**不要读成「`runtime` 轮白做了」。**对象模型、粒度三字段、证据等级、权力表、等效判据立得住，本稿第 2–9 节保留。站不住的是围绕自定义入向协议长出来的那一支，以及建立在未核前提上的边界设计。

| # | 被证伪的设计 | 独立复核（2026-09-06，cursor，宿主 shell） | 本稿怎么处置 |
| --- | --- | --- | --- |
| 1 | Interaction 出向六字段 + 入向三值 + 修订载荷 + `amend_schema` + `amend.mode` + 过期校验 | 基座库入向就是 `Command(resume=<任意值>)` 一个参数；出向 `interrupt()` 收任意 dict。见第 7 节引用的 `pilot_graph.py` / `langgraph_runtime.py:19` | **不采纳。**H8 接库的原语。内核字段扩展另走修订工作单元，不在本稿预写 |
| 2 | 人介入 → Task 级暂停 → 恢复时开**新 Attempt**、把修订当新输入 | `graph_runtime_service.py:14-15,40-42`：同一个 `thread_id` 继续跑。内核已写「checkpoint 原地恢复」。`resume()` 在基类是 `NotImplementedError`，适配器翻译成库命令 | **不采纳。**恢复不是新 Attempt。「需要载荷」是被本条自己造出来的 |
| 3 | **回执仓**：人的批准写成签名 commit，独立仓，VM 只读 | `sudo -n -l` → `(ALL) NOPASSWD: ALL`；`id` → 同用户、sudo + docker 组。授权本身就是批准。身份不可区分的根因是同机同用户且有免密 sudo，独立仓解决不了。取证与 [`rounds/_spike-sign/forensics.md`](rounds/_spike-sign/forensics.md) 一致 | **不采纳独立仓。**回执只认落盘（`rulings.md` + 所有者 commit）。通道升级的前置是 agent 够不着的操作面，该前置未满足 |
| 4 | **候选仓**：agent 把产出推到隔离仓 | `git branch -vv`：各家分支无 `origin` upstream。`git ls-remote --heads origin` 远端分支停在旧 commit，本地 master 领先 origin 93 个 commit。agent **从不 push**，全部工作在本机 worktree | **不采纳。**候选的冻结单位是本机分支上的 commit |
| 5 | VM 换三把 key、主仓对 agent 只读 | `git ls-remote --tags origin` 没有 `runtime/*`、`refact/*`；这些冻结标签只在本地。发布是**本地 merge**，不经网络，key 管不着这条路径 | **不采纳「用远端 key 拦截发布」。**H5 = 人做本地合并 + 落盘确认 |
| 6 | **三道边界**作为安全架构组件 | 要拦的动作不经过它们（第 3–5 条同一组命令）。本机免密 sudo 使一切本地强制点对 agent 无效（`forensics.md` F1/F2） | **不采纳「三道边界已就位」。**外层控制作为 adapter 环境策略的**目标**保留在第 4.2 节，并标明今天未就位 |

对任务书 §1.1 六条：**全部采纳该核查结论**，本表是独立复跑后的处置，不是照抄。

源稿 §3.13 / §4.4 里仍然成立、已迁入正文的部分：取证必须附 `uid_map`（防沙箱伪 root）；本地脚本与 hook 不是边界；`check-no-owner-creds.sh` 是卫生检查不是边界；Windows Remote 终端等于在 VM 上操作。被证伪的是「建两个仓 + 换三把 key 就能得到强制点」这一跳。

---

## 13. 未决与实施纪律

### 13.1 实施纪律（不是任务清单）

每轮一个工单，前置不可跳。档位按协议判据自判，**本路线不含任何降档**。任务编号与进度在 [`implementation-plan.md`](implementation-plan.md) / [`handoff.md`](handoff.md)，本稿不重写 R0–R5 表——那张表把已被证伪的基础设施当作后续轮次的前置，必须重排。

`bootstrap` 只用于「策略尚未存在、因而无法引用 T0 包」的可逆工作（修脚本、宿主取证）。效力来自被冻结的工单验收条，不来自尚不存在的 `policy/1`。之后全部按 T0/T1/T2 自判。

### 13.2 未决

| # | 未决 | 处置 |
| --- | --- | --- |
| 1 | 人的确认如何升级到 attested（agent 够不着的操作面） | 前置未满足，见 `forensics.md`。在此之前 H5 的强制点就是人的手 |
| 2 | T0 的「可逆出口」（不写共享最终路径、免 H5） | 省事方向的新权力表行，本稿不加。有确认次数数据后再定 |
| 3 | 协议「权威层」几乎覆盖 `dev-plan/` 全部文件，日常任务大量落 T2 | 判据属协议，改它是协议自己的 T2；本稿不改、不绕 |
| 4 | `RUNNING` 在 `events.jsonl` 落地前不可判 | 第 3.4 节已声明；合并显示并标 ⚠ |
| 5 | 独立性分组键是否改为 `(harness, model_family)` | 等候选相似度观测值 |
| 6 | 「Attempt 产出 typed Artifact」是否算内核扩充 | 走内核修订纪律 |
| 7 | `retroactive` Task 与 I1 的关系 | 走内核修订纪律 |
| 8 | **轮内产物发布 vs 最终稿发布**：`runtime` 轮所有者五次执行发布脚本写主线，按权力表属 H5，实际未经 H5 门。权力表的 H5 只对准 ⑦，没区分两者 | 两者不可逆性不同（后者可 revert，前者进交付面），但都写主线。是否拆行属省事方向的新行，本稿不擅自改权力表行数，待所有者裁 |
| 9 | 过渡期 orchestrator 由人运行脚本 | 登记为「可自动」欠账，不是角色 |
| 10 | 单 principal 阶段的权力表在多用户场景是否够用 | 表结构已按 principal 设计；capability 列等到第二个 principal 再加 |

观察值，不是判据：每次 H 回执的耗时与改动项数；T0/T1 比例；`retroactive` 比例。⑦ 清理时登记，不进验收。

源稿「本方案自身的验收标准」九条，凡依赖第 12 节被证伪设计的（独立仓锚定、远端 key、VM 对主仓 push 被拒）一律作废，不迁入。仍成立的：五词唯一定义且 router / orchestrator 无 agent 实现；权力表每行有强制点且 VM 脚本不算强制点；只有一套状态机；开工前触点 0/1/2；新判据首跑与人工对照；取证栏附 `uid_map`。

---

## 14. 逐节落点表

> D2。源稿节号与标题以 `ed0b5136` 上的实际标题为准。
> 「故意不要」的理由均超过 15 字，并指出被什么取代。
> 本表是索引。声称落在某节而该节没有对应内容的，比不写本表更差。

| 源 | 源稿的节号与标题 | 落点（本稿章节号）或「故意不要」+ 理由 |
| --- | --- | --- |
| F | 0. 一页摘要 | §0、§2 |
| F | 1. 诊断：现状的六个结构问题 | §11.1 |
| F | 1.1 「两条路径」是假分叉 | §11.1 第 1 行 |
| F | 1.2 supervisor 已有三套同名物，第三套还有一个未定义的别名 | §9.2、§11.1 第 2 行 |
| F | 1.3 权力与流程混写 | §5.2、§11.1 第 3 行 |
| F | 1.4 一个环节判不了 | §5.2 回执只认落盘、§11.1 第 4 行 |
| F | 1.5 执行架构与开发流程装在同一份文件里 | §10.1、§11.1 第 5 行 |
| F | 1.6 档位只有 T2 有正文 | §3.3、§11.1 第 6 行 |
| F | 2. 设计原则 | §1.2 |
| F | 3. 目标架构 | §2 |
| F | 3.1 一套状态机，两个 Profile | §2.2（状态机与 Task Profile 取值保留；按持久层再切一层的架构不沿用，理由见该节） |
| F | 3.2 执行者模型：三种 kind，一张登记表 | §4.1、§4.4（登记表与独立性保留；把人写成执行者 kind 不沿用，见 §5.1） |
| F | 3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源 | §5.2 |
| F | 3.4 人的通道：收件箱 + 回执 | §5.3 |
| F | 3.5 路由：三值决策，模型只建议 | §3.5 |
| F | 3.6 工单：一个冻结的 Artifact，一次确认 | §3.2、§3.3 |
| F | 3.7 工作区供给：纯函数，判据是独占与干净 | §6.1 |
| F | 3.8 状态判定与分发：一般化现有脚本 | §6.3 |
| F | 3.9 角色：supervisor 解体为五个各有定义的词 | §9.2 |
| F | 3.10 开发 Profile ↔ 内核对象对照 | §3.4（对照关系保留；源标题里的分层用词不沿用，场景差异只在 Task Profile 取值） |
| F | 3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了 | §6.4 |
| F | 3.12 验证分层：谁判什么 | §9.1 |
| F | 3.13 签名回执的威胁模型与密钥分布 | §5.2 末段、§5.3、§6.2、§12 第 3–6 条（取证纪律与「本地脚本不是边界」保留；独立仓与换钥匙方案见 §12，不进入现行设计） |
| F | 4. 对原建议的处置 | §11.2 |
| F | 5. 文档重构 | §10 |
| F | 5.1 目标文件树 | §10.1（职责表保留；具体文件名不在本稿冻结） |
| F | 5.2 旧 → 新映射：按旧文全部标题，脚本检查零缺口 | §10.2、§14（本表即其执行；旧 lifecycle 两文的细表不在本轮范围） |
| F | 5.3 删除条件 | §10.2 |
| F | 6. 实施路线 | §13.1（一轮一工单、不降档、bootstrap 纪律保留；R0–R5 编号表因把已证伪基础设施当前置而作废，进度以 implementation-plan 为准） |
| F | 7. 风险与未决 | §13.2 |
| F | 8. 本方案自身的验收标准（供开轮时冻结） | §13.2 末段（依赖已证伪设计的条款作废；五词、单状态机、触点数、取证纪律仍成立） |
| R | 0. 一页摘要 | §0、§2、§3、§4、§8 |
| R | 1. 本稿与上一轮的关系 | §2.2、§3.4（`RUNNING` 归因更正）、§12 开篇 |
| R | 2. P1 — 一个运行时、唯一状态机、`dev.change`、五个 Agent Profile | §2、§3、§4 |
| R | 2.1 运行时 = 内核对象的唯一写入面 + 四个确定性组件 + 两个适配层 | §2.1 |
| R | 2.2 Task Profile `dev.change` 版本 1 | §3.1、§1.3 |
| R | 2.3 五个 Agent Profile：登记表 | §4.1 |
| R | 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行 | §5.1、§5.2 |
| R | 2.5 `dev.change` 的产物 → 唯一状态机 | §3.4 |
| R | 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现 | §6.4、§8.1 |
| R | 2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文 | §8.1 |
| R | 2.8 trace 样例：`refact-fable` 轮的真实产物 | §8.1 末两段 |
| R | 3. P2 — Interaction 双向带载荷：一个内核修订工作单元 | §7（缺口承认；自造字段表见下一行起故意不要） |
| R | 3.1 缺口 | §7 首段 |
| R | 3.2 扩展后的绑定字段表 | 故意不要：自造出向六字段与入向三值加修订载荷，基座库入向只有 Command(resume=任意值) 一个参数，见第 7 节与第 12 节第 1 条 |
| R | 3.3 `amend` 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task | 故意不要：恢复被写成新 Attempt，与库的同一 thread_id 原地续跑矛盾，见第 7 节与第 12 节第 2 条 |
| R | 3.4 与权力表的对应 | §5.2 H8（只保留「回答 WAITING(INPUT)」；按字段表绑修订载荷的对应关系不沿用） |
| R | 3.5 修订工作单元（按 `request-lifecycle.md:627` 修订纪律） | §7 末段（修订纪律本身保留为指针；本稿不预写字段表，也不开这个工作单元） |
| R | 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果 | §4.2、§4.3 |
| R | 4.1 粒度是三个字段，不是一个；至少四档 | §4.2 |
| R | 4.2 五家的取值 | §4.1、§4.2 |
| R | 4.3 证据权威性：由粒度推导，不由执行者声明 | §4.3 |
| R | 4.4 三道边界是架构组件，不随脚手架拆 | 故意不要：把未就位的外层控制写成已有安全架构组件，要拦的动作不经过它们，见第 12 节第 6 条；外层控制作为目标策略留在 §4.2 并标明未就位 |
| R | 4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离 | §6.1、§6.2 |
| R | 4.6 R2：principal 通道也有粒度 | §5.3 末段 |
| R | 4.7 取证纪律与当前事实 | §6.2、§12 第 3 条、§15 |
| R | 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线 | §8.2 |
| R | 5.1 分类规则（机械可判，全部由工单字段直接判） | §8.2 规则表 |
| R | 5.2 反例（三类走运行时反而更贵的任务） | §8.2 三类反例 |
| R | 5.3 T0 开销上界（复合向量，任一维超标即不标 T0） | §8.2 上界 |
| R | 5.4 绕过的可观测性 | §8.3 |
| R | 6. 对 OP-1 / OP-2 / OP-3 的裁定 | §8.1（OP-1）、§7（OP-2 改为接库，不沿用字段表）、§8.2–§8.3（OP-3） |
| R | 7. 覆盖声明、盲区与未验证项 | §15（形状沿用；内容换成本轮独立取证） |
| R | 8. 自检：对照 `task.md` §8 十条 | 故意不要：那是 `runtime` 轮对照其任务书的自检清单，本轮验收标准在任务书 §8，不把上一轮自检表当现行条款 |

---

## 15. 覆盖声明

**查了**：

- 身份命令：输出 `cursor`；工作目录 `/home/zym/worktrees/cursor/k8s`。
- 两份源稿在 `ed0b5136` 上的全部 64 个 `##` / `###` 标题（`refact-fable.md` 31 节、`runtime-architecture.md` 33 节），并按标题通读正文。
- 内核 [`working/request-lifecycle.md`](working/request-lifecycle.md) 的「核心对象」「两层状态机」「WAITING 与 Interaction」「全程不变量」I4/I5/I8/I13、「Profile、Artifact 与扩展」。
- 协议 [`protocol/round-protocol.md`](protocol/round-protocol.md) 的档位、裁量、环节判定、8b、提案隔离。
- [`constraints.md`](constraints.md) A1–A5；[`development-plan.md`](development-plan.md) 通用/专用与租用边界；[`handoff.md`](handoff.md) 当前阶段；[`protocol/agents.toml`](protocol/agents.toml)。
- [`rounds/_spike-sign/forensics.md`](rounds/_spike-sign/forensics.md) 全文。
- §1.1 六条证伪命令，全部在宿主 shell 独立复跑（`uid_map` 为恒等映射 `0 0 4294967295`，不是沙箱伪 root）：
  - `Command(resume=` 在 `investment-backend` 的全部命中；`pilot_graph.py` 的 `interrupt({...})`；`graph_runtime_service.py:14-46`；`langgraph_runtime.py:14-20`；
  - `id`；`sudo -n -l` → `(ALL) NOPASSWD: ALL`；
  - `git ls-remote --heads origin`；`git branch -vv`（只看分支名与 upstream，见下）；
  - `git ls-remote --tags origin` 与本地 `git tag -l`。
- 兄弟仓 `~/worktrees/cursor/investment-app`，子模块 `investment-backend` = `18d88c7c`。

**没查**：

- `~/repo/codex`、`~/repo/deepseek-harness`、`~/repo/openclaw` 的源码行号（源稿有一处 `codex exec --json` 锚点，本稿未复跑，粒度三字段的例证标 ⚠）。
- luna / kimi 的 `$CODEX_HOME` 实际模型配置；fable GUI 内当前选中的模型。
- `agent --output-format stream-json` 与 `qoder -o` 的输出内容是否含工具级事件。
- 托管方侧的 key 列表与作用域（凭据在所有者手里）。
- Windows 侧是否已装 git / gpg，以及 Remote 会话与本地 shell 的当前分离状态。
- `rounds/` 下历史轮次评审正文的逐句核对（取证用了 `refact-fable` 轨迹的已发表结论与 `runtime` 轮处置记录的存在性，未重读五家候选全文）。
- [`implementation-plan.md`](implementation-plan.md) 是否已按第 12 节重排 R0–R5——本稿故意不写任务清单。

**未读 `agent-dev-refact.md`（裁定 R2）**：遵守。未打开该文件，未对其做 `git show` / `grep` / `rg`，未以其为起点。本覆盖声明写明这一点，供验收核对。

**隔离**：候选完成前未打开任何其他家的 worktree 目录，未 `git show` 其他家分支上的文件。跑 `git branch -vv` 时看见了各家分支名、worktree 路径与 HEAD 短哈希（为复核「agent 是否 push」所必需），**没有据此读取任何候选正文**。隔离靠纪律不靠机制，无法事后证明「真的没读」，此处如实记录做了什么、没做什么。

**未验证 ⚠**：

- M4 正则能否可靠区分「复活该设计」与「在第 12 节被证伪语境里提到它」——首跑须与人工对照。
- 「Attempt 可产出 typed Artifact」是否算内核扩充。
- `retroactive` 登记与 I1 的关系。
- 同 harness 不同模型的相关性；分组键是否应改为 `(harness, model_family)`。
- `dispatch = manual` 的执行者在服务态 orchestrator 下除 `dispatch_event` 之外还有没有更干净的形状。
- 第 8.2 节 T0 上界的四个数字未经实测，是从源稿迁入的设计值。

**故意没写**：

- 财务分析 Task Profile 的字段与验收用例（第 1.3 节已声明那是它自己的第一个工作单元）。
- 协议七环节的逐步操作说明（权威在 `round-protocol.md`；本稿第 0 节只指路）。
- 把人登记为执行者、自定义入向三值协议、独立仓与换钥匙方案（第 12 节）。
- 具体业务功能与当前进度。

**新增条款（源稿没有、本稿有，J8）**：

1. **强制点必须落在动作实际经过的路径上**（§1.2 推论）。取证：第 12 节六条复跑。
2. **恢复接库的 `Command(resume=)`，同一 `thread_id` 原地续跑，不是新 Attempt**（§7）。取证：`langgraph_runtime.py:17-20`、`graph_runtime_service.py:14-15`、内核「WAITING 与 Interaction」原地恢复句。
3. **登记集合 ≠ 自动路由候选集**（§4.1）。取证：`agents.toml` 的 `[fable]` 无 argv。
4. **身份只认 worktree 目录名**（§0）。取证：本轮任务书 §6 记录的事故。
5. **轮内产物发布与最终稿发布尚未在权力表区分**（§13.2 第 8 条）。取证：`runtime` 轮处置记录已登记该缺口；本稿不擅自加行。