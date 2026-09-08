# 开发指导：一套状态机、一个运行时、五个角色

参与方：kimi（`runtime-refact` 轮 ① 提案候选）｜worktree：/home/zym/worktrees/kimi/k8s

> 本文是 `runtime-refact` 轮五份并行候选之一，**不是现行规范**。
> 它融合两份源稿——[`refact-fable.md`](refact-fable.md)（重构方案）与
> [`runtime-architecture.md`](runtime-architecture.md)（运行时架构）——的全部有效内容，
> 并纳入 2026-09-06 对六处设计的核查结论（§1.1）。
> 引用按标题不按章节号（[`round-protocol.md`](protocol/round-protocol.md)「通用纪律」已立此规矩）。

---

## 0. 一页摘要

1. **只有一套状态机。**Task / Attempt 两层状态机及其合法转换表由
   [`working/request-lifecycle.md`](working/request-lifecycle.md)「两层状态机」定义（下称**内核**）。
   任何场景不得新增状态词、不得走内核之外的边。开发过程与产品运行时是同一状态机
   在不同 **Task Profile** 下的运行。
2. **只有一个运行时。**它是内核七个对象的唯一权威写入面，加四个确定性组件
   （router / orchestrator / interaction service / validator）与两个适配层
   （executor adapter / principal channel）。**开发是它的第一个 Task Profile
   `dev.change`（版本 1）**，五家助手是五个 Agent Profile。
3. **人不是执行者，是 principal。**哪些状态转换需要人批准，由一张权力表（H1–H8）决定，
   不由流程图手画，也不由执行者身份决定。
4. **状态从产物反推，不从声明读取。**判据一律是命令，对照 git 提交。
5. **人介入用基座库原语**（`interrupt()` 出向任意 dict、`Command(resume=...)` 入向单值、
   checkpoint 原地恢复），**不自造替代协议**。2026-09-06 核查证伪了六处建立在未核前提上的
   设计（§1.1），它们不得以任何形式复活。
6. **一条不得外推的边界**：开发的验收机械且便宜（测试、门禁、diff），财务分析的验收
   判断且昂贵。本文的验收机制只对着开发设计，**最难的一半没解决**（§10.1）。

---

## 1. 背景：两份源稿与本轮核查

### 1.1 六处被证伪的设计（本节是「被证伪」语境，以下设计不得复活）

`runtime-architecture.md` 有六处设计建立在未核过的前提上。任务书给出证伪命令，
本候选**逐条独立复核**（复核记录见各条末行；investment-app 子模块 commit `18d88c7c`）：

| # | 被证伪的设计 | 核查结论 | 本候选的复核 |
| --- | --- | --- | --- |
| 1 | Interaction 出向六字段 + 入向三值 + amend 载荷 + `amend_schema`（**已证伪**）+ `amend.mode`（**已证伪**）+ 过期校验 | 基座库里，入向就是 `Command(resume=<任意值>)` 一个参数；出向 `interrupt()` 收任意 dict。整套自定义协议没有对应物 | 已复核：`investment-backend/app/app/infrastructure/graph/pilot_graph.py:59` `interrupt({kind, action_id, prompt})` 收任意 dict；全仓 25 处 `Command(resume=...)` 调用均为单参数（值有 `"approved"`、`"continue"`、`user_input` 等） |
| 2 | 人介入 → Task 级暂停 → 恢复时开新 Attempt、把 amend 当新输入 | 检查点是**原地恢复**：同一 `thread_id` 继续跑同一次执行，不换 Attempt | 已复核：`investment-backend/app/app/application/agent/graph_runtime_service.py:40-46` 同一 config（含 thread_id）继续 `graph.stream`，遇 `__interrupt__` 返回中断标记 |
| 3 | **回执仓**（**已证伪**）：人的批准写成签名 commit，独立仓，VM 只读 | 授权本身就是批准。且它解决不了它声称要解决的问题——身份不可区分的根因是同机同用户且有免密 sudo | 部分复核：本机 `id` = `uid=1003(zym)`；`sudo -n -l` 在本候选的沙箱内被 no-new-privileges 拦截，**该条沙箱内不可复跑**，宿主取证以 [`rounds/_spike-sign/forensics.md`](rounds/_spike-sign/forensics.md) F1（`(ALL) NOPASSWD: ALL`，宿主 shell、`uid_map` 恒等映射）为准 |
| 4 | **候选仓**（**已证伪**）：agent 把产出推到隔离仓 | agent 从不 push，全部工作在本机 worktree | 已复核：`git branch -vv` 显示 luna / kimi / cursor / fable / qwen 五条分支**均无 upstream**（仅 master 有）；`git ls-remote` 因本候选沙箱断网不可复跑，如实声明 |
| 5 | VM 换三把 key、主仓对 agent 只读 | 发布是**本地 merge**，不经网络，key 管不着这条路径 | 已复核旁证：master 相对 `origin/master` ahead 93——发布动作发生在本机，甚至长期不 push；九个冻结标签（`refact/*`、`runtime/*` 等）存在于本地，远端状态沙箱内不可查，如实声明 |
| 6 | **三道边界**（**已证伪**）作为安全架构组件 | 要拦的动作不经过它们：agent 与人同 uid 且有免密 sudo 时，任何 VM 本地强制点都可被 `sudo` 改写 | 依据第 3 条同一取证；forensics.md §2 的表（本地脚本 / hook / 文件权限对 agent 全部无效）与第 3–5 条互证 |

**六处的共同成因是同一个**：在没有用命令确认「这个动作现在实际发生在哪、由谁做、
经过什么」的情况下推演。第 1 条是根——自定义 amend 协议一旦成立，就必须有载荷、
有 schema、有过期校验、有 Task 级暂停，后面五条跟着长出来。

⚠ **不要读成「那些轮次白做了」。**对象模型、粒度三字段、证据等级、权力表、
等效判据都立住了（§4–§6 完整保留）。站不住的是围绕 amend 长出来的那一支，
以及建立在未核前提上的边界设计。

### 1.2 为什么逐节对照升格为交付要求

2026-09-06 对两份源稿做过一次融合尝试，逐节核对时发现**整节内容在融合中丢失**
（设计原则、五个角色的定义、验证分层 L0–L3、文档的删除条件、状态脚本的要点、
已登记的未决项）。教训：

> 靠一次通读做融合会丢东西，而且丢了不会有人发现。唯一可靠的办法是逐节对照。

且两份源稿在本文定稿后将从主线删除——**漏了就没了**。因此本文末附逐节落点表（§12），
两份源稿全部 64 节逐节给出落点或「故意不要」+ 理由。

---

## 2. 权威文档地图与名词

新读者只需记住：**定义不出现在本文的，去下面三份找；本文不重写它们。**

| 文档 | 是什么 | 本文怎么用 |
| --- | --- | --- |
| [`working/request-lifecycle.md`](working/request-lifecycle.md) | **内核**：七个对象（Task / Attempt / Interaction / Artifact / Event / Side Effect / Delivery）、Task Profile / Agent Profile、两层状态机、合法转换表、不变量 | 权威定义，只引用不重写（B3）。「Task」「Attempt」「Interaction」「Artifact」「Task Profile」「Agent Profile」均以它为准 |
| [`round-protocol.md`](protocol/round-protocol.md) | 多助手并行评优轮次的流程规范：档位 T0/T1/T2、七环节、裁量权、超时与回退 | 「环节」「裁决方」「验收方」「观察窗」「裁定」以它为准；本文只给导读（§10.1），不复述正文 |
| [`constraints.md`](constraints.md) | 约束册。A1–A5 是本文的硬约束：A1 新增业务智能体优先是新 Profile 而非 fork；A3 四本账落 PostgreSQL；A4 执行层租用不自建、依赖边界限定在 SDK；A5 领域概念不进 Port 签名 | 违反任一条的方案不进入讨论 |
| [`development-plan.md`](development-plan.md) / [`implementation-plan.md`](implementation-plan.md) / [`handoff.md`](handoff.md) | 建什么、按什么顺序、现在到哪 | 背景；本文不含任务清单与进度 |

其余本文自创或沿用的词，在第一次出现处定义：运行时（§4.1）、工单（§4.3）、
权力表（§5.4）、principal（§5.3）、证据等级（§6.2）、等效判据（§6.5）。

**适用边界（不得省略）**：本文的验收机制只对「机械且便宜」的开发验收设计。
财务分析类 Task 的验收是「判断且昂贵」的，`dev.change` 只证明对象形状与状态转换
跑得通；验收器对那一半不能从本文外推，必须在财务 Task Profile 的第一个工作单元里
用真实验收用例重证（内核「Profile 示例」已有同义要求）。

---

## 3. 设计原则

六条，全部取自本仓已成文的判断或所有者裁定，作为设计约束一致用到底：

| # | 原则 | 出处 |
| --- | --- | --- |
| **P0** | 只有一套状态机（Task / Attempt），场景差异只体现在 Profile 的 guard、必需产物与 interrupt 策略；任何场景不得新增状态词 | 所有者裁定 2026-09-05；内核「核心对象」Task Profile 行「不另造状态机」、「Profile、Artifact 与扩展」、反模式表 |
| P1 | 同一事实只有一个权威写入面 | 内核 I13；round-protocol「本轮定义」 |
| P2 | 状态从产物反推，不从声明读取；人的动作也不例外 | round-protocol「收到『继续』时怎么办」 |
| P3 | 方向不对称：朝严谨可自裁，朝省事须人确认；默认值属于省事方向 | round-protocol「裁量权」 |
| P4 | 判据必须声明覆盖范围；覆盖不全比没有更危险 | round-protocol「判据自身的质量」 |
| P5 | 凡能落成代码、测试或门禁的纪律必须落成；文字只描述意图 | constraints「保证这些被遵守的三层」 |

两条推论：

- **一个只能靠人转述的环节等于没有环节**（P2 + P5）。
- **P0 的适用层级是 Task 与 Attempt。**Artifact、Interaction 各有自己的小生命周期
  （如候选的 `DRAFT → FROZEN`、内核的 `consumed_at`），那是对象属性，不是第二套状态机，
  同样跨场景共用、不得按场景另造。

这些原则来自对旧框架的六条诊断，诊断本身仍可复核、对新读者有解释力，扼要保留：
旧框架把开发写成「两条路径」实是假分叉（入口差异消失后只剩「谁按了回车」）；
「supervisor」同时指四件事（§5.1 解体）；权力与流程混写、不驱动流程；
存在一个命令判不了的环节（人的确认不是产物，与 P2 直接矛盾）；
产品执行层架构与开发流程混装在同一文件；T0/T1 没有可执行形态导致日常任务绕过纪律。

---

## 4. 运行时与唯一状态机

### 4.1 一个运行时：四组件 + 两适配层

| 组件 | 职责 | 内核依据 |
| --- | --- | --- |
| **router** | 从请求算出 Task Profile 版本、tier、执行者候选、工作区计划；三值 `decide / ask / refuse` | 内核「解释、边界与完成契约」；`F-ADMIT-*` |
| **orchestrator** | 推进 Task / Attempt 状态（只走合法转换表里的边）、派发、收集、观测逾期、回退 | 内核 I4「状态转换集中校验」 |
| **interaction service** | 产生 Interaction、鉴别响应者、原子消费恢复令牌 | 内核「WAITING 与 Interaction」；`F-INTERACT-01` |
| **validator** | 按 Task Profile 版本跑 acceptance 的机械部分；判不了的显式交给 acceptor 角色 | `F-ACCEPT-01`；round-protocol「判据自身的质量」 |
| *适配层* **executor adapter** | 按 Agent Profile 的粒度字段决定怎么调、怎么看、怎么拦 | §6.1 |
| *适配层* **principal channel** | 人怎么被叫到、怎么回、响应者身份如何鉴别 | §5.5 |

**orchestrator 是确定性代码，不是角色。**过渡期由人运行脚本，人是它的**触发通道**，
不是这个组件；把欠账重命名为组件，下一轮就会有人对着这个名字设计接口。

### 4.2 Task Profile `dev.change` 版本 1

```text
profile_id            dev.change
version               1
input_schema          工单：goal · paths[] · baseline_commit · read_only_inputs[]（路径 + 版本锚）
                      · tier ∈ {T0,T1,T2}（router 建议、人可改）
                      · executors{proposers[], arbiter, acceptor}（T1/T2）
                      · acceptance[]（逐条编号；T0 = 一个已签任务类包名）
output_schema         一个或多个 Artifact 落在 final_path(s)，版本 = commit；T1/T2 另有 disposition Artifact
normalization_rules   goal → 可判定 acceptance 条；歧义实质改变结果 / 权限 / 成本 / 风险时才 ask
required_context      read_only_inputs 按版本锚取；候选不得改动它们
acceptance            机械条（validator 跑）+ 判断条（acceptor 角色跑，按冻结标准逐条给结论，不得改标准）
evidence              每条断言现状的句子附 file:line 或可复跑命令；采信等级按 §6.2 计算
freshness             baseline_commit 固定；基线移动 → 新 Task
allowed_capabilities  读整仓、写自己 worktree、不 push 主线
budget                观察窗 W = 已交付各家用时中位数；max_rollbacks = 2
retry                 逾期 → 该家 Attempt FAILED(timeout)，Task 不失败（内核 I8）
approval              权力表 H1–H8（§5.4）；tier 决定开工前 APPROVAL 触点数 0/1/2
privacy               文档任务无；财务数据任务另由其 Task Profile 定
```

**别名登记**（不并存多个真源）：`DEV`、`DEV_ROUND`、`DEVELOPMENT`、`dev.change.v1`
均为 `dev.change` 的别名，正式 id 取 `dev.change`。

**tier 不是三个 Task Profile**，是 `execution_policy` 的一个字段——改 Attempt 组数与
审批触点，不改输入 / 输出 / 验收的形状。T2 的七环节是 execution_policy 定义的
Attempt 阶段图，每个 Attempt 记 `kind ∈ {proposer, reviewer, arbiter, objector, acceptor, publisher}`，
产物是 typed Artifact。⚠ 「Attempt 可产出 typed Artifact」是否算对内核 Attempt 定义的扩充，
未决（§11），若内核维护者认为是扩充则按内核「修订纪律」走规范修订工作单元。

### 4.3 工单：冻结的 Artifact，档位 = 三张表

把 round-protocol 的 `round.md` 一般化为**工单**（Work Order）。**工单是 Artifact，
不是 Task 状态。**它只有 Artifact 的两个状态词 `DRAFT → FROZEN`，Task 状态由产物推导。
任何档位都有工单，字段固定：

```toml
[order]
id, tier                    # tier 只选 guard 表，不是状态
artifact_state              # DRAFT | FROZEN
route_proposal              # 路由的输出：模型证据 + 确定性规则结果，含 policy_version（建议与决定分开）
route_effective             # T0：= proposal，由策略放行；T1/T2：H2 确认后的值
route_delta                 # 人相对 proposal 改了哪些字段；空 = 全盘沿用（观察值来源）
intent_restatement          # 执行者用自己的话复述需求 + 决策点清单 + 标出的歧义
acceptance = [...]          # 逐条编号，冻结后不改；每条尽量指向一个机械检查；T0 为一个包名
frozen_sections = [...]
[executors]
intake_author               # 起草 intent_restatement / acceptance 的执行者：同票禁任 proposer / arbiter / acceptor，
                            # 分发前机械拦；T2 的题目与验收条可由 owner 直接提供，此时 intake_author = owner
proposers, arbiter, acceptor, approver
[workspace]
source, baseline_commit, write_actors, review_needed, submodule_plan
[budget]
observation_window_rule, max_rounds, max_rollbacks
```

**每个 tier 对应一张 guard 表（哪些转换要过哪些门）、一张必需产物表（哪个 Attempt 组交什么）、
一份 interrupt 策略（H2 能否默认）。**T2 是 round-protocol 的七环节；T1 是
「出稿 → 独立评审 → 验收 → 确认」；T0 是「做 → 独立验收 → 确认」。
三者读同一个工单 schema，脚本按 `tier` 取表。

**开工前触点数按档位是 0 / 1 / 2**：T0 = 0（H1 由已签策略承担，H2 按策略放行，见 §7.2）；
T1 = 1（H1+H2 合并一次确认）；T2 = 2（H1 与 H2 分离——T2 的验收标准要在参赛者看到题目之前
冻结，而参赛者名单本身可能要人再定）。

**开工确认（H2）一次完成四件事**：确认路由、确认（或更换）arbiter 与参赛者、
确认任务 list 与是否 fan-out、确认仓库与 worktree 计划。避免多次前置确认退化成盖章。

### 4.4 `dev.change` 的产物 → 唯一状态机

| 产物 / 事件 | Task | Attempt | 说明 |
| --- | --- | --- | --- |
| 工单文件出现 | `RECEIVED` → 即刻 `VALIDATING` | — | 空转不停留 |
| 工单 `DRAFT` / `FROZEN` | `VALIDATING` | — | Artifact 状态，不是 Task 状态 |
| router `ask` | `VALIDATING → WAITING(INPUT)` → 回 `VALIDATING` | — | H8 |
| H1 冻结 | `WAITING(APPROVAL) → VALIDATING` | — | 验证期恢复边 |
| H2 开工 | `VALIDATING → QUEUED` | — | T0 按策略放行 |
| 派发 | `QUEUED → RUNNING`（首个 Attempt 获租约） | `CREATED → RUNNING` | `dispatch = manual` 的由 `dispatch_event` 承担（§5.2） |
| 某家交付并 commit | `RUNNING` | `RUNNING → COMPLETED` | 产出 typed Artifact，不等于 Task 成功 |
| 某家逾期 | `RUNNING` | `FAILED(timeout)` | Task 不因此失败 |
| 某家用尽观察窗 | `RUNNING` | `BUDGET_EXCEEDED` | Task 随后进 `WAITING(APPROVAL)`（H4）或重新 `QUEUED` |
| 执行期澄清 / 裁选项 | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | 在跑的 → `WAITING` | H8；执行期等待先回 `QUEUED` |
| ④⑤⑥ 回到 ③ | `RUNNING` | 新 Attempt；旧的终态不重开（I5） | |
| ⑥ 确认待人 | `RUNNING → WAITING(APPROVAL)` | — | H5 |
| ⑥ 确认成立 | `WAITING → QUEUED` | publisher `CREATED` | 不是 `WAITING → SUCCEEDED`——内核没有这条边 |
| ⑦ 发布 | `RUNNING → SUCCEEDED` | publisher `COMPLETED` | 本地 merge 写共享最终路径（§9.2） |
| 无获准成功路径 | `RUNNING → FAILED` | — | |
| 候选 `STALE` / `SUPERSEDED` | — | — | Artifact 状态 |

**没有一个新词，没有一条内核之外的边，内核每个状态都有落点**——这三件合起来才是
P0 的验收方式。`AUTH-EFFECT` 类（H5）不得直达成功终态：批准的是执行动作，
`SUCCEEDED` 由 publisher Attempt `COMPLETED` 之后提交。

### 4.5 git 载体的语义映射：什么是权威、什么是投影、什么验不了

先把 git 的两个角色拆开：**git 当 Artifact 载体**（代码与文档的版本就是 commit）是永久的；
**git 当账本**（用 commit 历史 + `rulings.md` 反推状态）是脚手架，见 §4.6。

| 内核要求 | git 载体的落法 |
| --- | --- |
| 权威事件 | 可从发布点 tag 到达的 commit |
| branch / tag | branch 是运输通道，不是评审对象；tag 仅在受保护模式下是权威引用 |
| 比较交换（`state_version`） | 发布校验目标 ref 仍指向记录的 commit；不一致即失败并新建整合 Attempt |
| 终态不可重开（I5） | round id 全局不复用 |
| ref 被重置后的恢复 | 发布点与各家候选打 tag（`refact` 轮已这么做） |
| 工作区文件 | 永不作判据；判据只看提交 |

**git 载体验证不了的三样，如实登记，不得宣称「已在开发层验过」：**

1. **事务性**——结果、验收、预算结算与终态事件原子提交，git 的多 ref 更新不原子；
2. **租约**——Attempt 的 `lease_owner / lease_expires_at`；开发层只有观察窗判据；
3. **fencing**（I14）——过期 worker 的写入被拒；开发层靠整合方核对候选状态，不靠机制。

「先在这一层跑通，再往下实现」的准确表述：**跑通对象形状、状态转换与交互纪律；
并发语义与证据的 attested 等级留给 PostgreSQL 载体**（constraints A3）。

### 4.6 bootstrap 与目标态：同一 Profile 的两种 orchestrator 实现

| 组件 | `orch.manual`（现状） | `orch.service`（目标态） | 拆除条件（全部机械可判） |
| --- | --- | --- | --- |
| Task 主档 | `rounds/<id>/round.md` toml | `task` 表 | 服务态对 ≥1 个 T0、T1、T2 真实 Task 的轨迹与手工态同 tier 历史轨迹按 §6.5 比对全等，且每类条目的 `attested` 计数 ≥ 手工态 |
| Event 日志 | commit 历史 + `rulings.md`（agent 可写面，是投影） | `event` 表（只追加） | 同上；另加 `round-status.py` 与服务态投影对同一历史轮次输出相同状态序列 |
| 并发语义 | 验不了 | 租约 / 取消竞争 / 重启重建三项通过 | git 载体验不了，不假装换说法就能验 |
| Interaction | `call-<环节>.md` + `inbox-owner.md` + 裁定行 + 所有者 commit | `interaction` 表 + 鉴别响应者的端点 | **前置：响应者身份可鉴别**（§9.2）；同一信任域里提供端点只是把 reported 搬了个家 |
| 派发 / 收集 | `round-dispatch.py` 生成命令 + 人粘贴 | executor adapter | 该 Agent Profile `dispatch = argv` 且 adapter 已跑通一次 Attempt；`dispatch = manual` 的永远由人承担，是登记对象不是拆除对象 |
| validator | `round-status.py --verify` | acceptance runner | 对三轮历史产物两者判定逐条一致 |
| 工作区供给 | `git worktree add` | provision 服务 | 供给判据（独占 × 干净 × 基线）进代码并有测试 |

### 4.7 状态判定与分发脚本的一般化

`protocol/round-status.py` 与 `protocol/round-dispatch.py` 的设计（从产物反推、
判据即命令、只生成不执行）是对的，要改的全部是「一般化」而非「推翻」：

| 现在 | 改为 |
| --- | --- |
| 只认 T2 七环节 | 按工单 `tier` 读对应 guard 表与必需产物表 |
| 输出「当前环节」 | 输出 Task 状态（唯一状态机的词）+ 当前环节 + 各 Attempt 状态；环节是投影，状态是判据 |
| `round.md` 的 `status` 字段是声明 | 降为人读缓存并由脚本校验：推导值 ≠ 声明值即报错 |
| `kind = human` 无处理 | 对人的条目输出收件箱通知而非 argv |
| 角色由每轮口头指定 | 分发前对照 `roles_allowed` 与角色分离禁令，冲突即拒绝并给 reason |
| 只判状态词 | 每次推导同时输出「上一状态 → 本状态」，边不在内核合法转换表内即报错 |

**每条判定声明覆盖范围**（P4）：「查了什么、没查什么」与结论并列；零命中要能区分
「真的没有」与「没查到」。`QUEUED` / `RUNNING` 在事件文件落地前合并显示为
「已分发未交付」并标 ⚠ 不可判——**归因更正**：这不是 git 载体缺事件文件，
而是 `observability ≤ process` 的执行者属性（§6.2 第 4 条），换成 PostgreSQL 一样
判不了 CLI 进程内部。

---

## 5. 角色、执行者与人

### 5.1 五个词：supervisor 解体

「supervisor」在旧文档里同时指四件事，解开后是五个各有定义的词：

| 词 | 是什么 | 开发场景实体 | 产品场景实体 |
| --- | --- | --- | --- |
| **router** | 确定性代码：产生 RouteDecision | 规则表 + `round-dispatch.py` 的选人逻辑 | TaskRouter |
| **orchestrator** | 确定性代码：推进状态、写环节通知、派发、观测逾期、收集、回退、供给与回收工作区 | `round-status.py` + `round-dispatch.py` + 运行它们的人（过渡期触发通道） | 调度组件 |
| **arbiter** | agent 角色：定基座、逐条吸收、写处置记录、处置异议 | 工单 `arbiter` 字段 | 执行监督的「选优整合」部分 |
| **acceptor** | agent 角色：按冻结标准独立验收 | 由处置表算出的一家（round-protocol「⑤ 验收 与 ⑥ 确认」） | validator |
| **approver** | principal：持有权力表某行的批准权 | `owner` | 有权用户 / 授权角色 |

两条硬约束：**router 与 orchestrator 必须是代码，不得是 agent 角色**；
**arbiter 不兼 orchestrator**（通知与截止由脚本按工单生成，arbiter 只写裁决与处置）。

### 5.2 Agent Profile 登记表

字段 `harness`（执行 harness：二进制 + 提示词 + 工具集）。登记粒度字段见 §6.1。
当前六条（取值经 `runtime` 轮核查，⚠ 项见源稿登记表）：

```toml
[ap.luna]   harness = "codex-cli"    provider = "openai"     dispatch = "argv"
[ap.kimi]   harness = "codex-cli"    provider = "moonshot"   dispatch = "argv"
[ap.cursor] harness = "cursor-agent" provider = "xai"        dispatch = "argv"
[ap.fable]  harness = "cursor-app"   provider = "anthropic"  dispatch = "manual"   # 无 argv，分发由人代行
[ap.qwen]   harness = "qoder"        provider = ""           dispatch = "argv"     # ⚠ provider/model 留空，推断不得进登记表
[ap.opus]   harness = "claude-code"  provider = "anthropic"  dispatch = "argv"     # roles_allowed = ["arbiter","publisher"]
```

每条另有 `roles_allowed`（只能取已注册角色）、`observability / enforcement / sandbox /
workspace_isolation`（§6.1）。**登记表没有任何条目以任何 kind 标人。**

**`dispatch_event`（不是权力表行）**：人代行 orchestrator 的传输动作（把固定指令送到
`dispatch = manual` 的执行者）记为 `dispatch_event{mode = manual, ...}`。它必须可数
（§8.3 的上界与 §8.4 的口径都要数它），但不是批准。无命令行入口的执行者，
要么经显式桥接（产生可审计 Delivery），要么退出自动路由候选集——
**登记集合与自动路由候选集是两个集合**。

**`dispatch = manual` 的执行者 `observability` 只能是 `fs-only`**（没有进程句柄就没有
stdio），脚本据此校验不许填高。⚠ 教训：登记表的机械非空不等于填对——`runtime` 轮
一份候选把 fable 填成 `process` 而正文又写「看不到 argv / stdio」。

### 5.3 人：principal，不是执行者

**权力挂在 principal 上，不挂在身份类别上。**现在只有一个 principal（`owner`）持有
全部权力；权力表引用 principal 名，将来多用户、多仓或产品审批时只加 principal 与
授权行，不改表结构。人的「真实差异」在本结构里的落点：

| 差异 | 落点 |
| --- | --- |
| 有批准权 | `owner` 持有权力表全部行；不是身份类别的属性 |
| 可裁量「不值得走全流程」 | H3（省事方向裁定）+ H6（推翻裁定）；裁量是权力表的行，不是表外自由 |
| 承担最终责任 | 治理条款：H5 的确认者即对外责任人 |
| 可跨会话续接 | 人的 Attempt 无 checkpoint 义务，`handoff.md` 就是它的 checkpoint；但不落盘的意图不是状态（P2） |

**principal 通道也有粒度**：所有者与 agent 同机、同 git 身份时，人的回执在账本上与
agent 提交不可区分，`channel_grade = shared-credential`，证据强度为零（§9.2 现状）。

**身份判别纪律**：执行者的身份只能来自 worktree 目录名
（`basename "$(dirname "$(git rev-parse --show-toplevel)")"`）；产品名、模型名、
界面一律不是证据。命令跑不出名字就停下问人，不靠推理猜。（真实事故：判别命令在仓外
执行，`basename` 对着报错文本输出一串 `.`，该家退回文本推理并判错身份。）

### 5.4 权力表：H1–H8

哪些转换需要人批准，写成一张表；引擎遇到这些转换就产生 Interaction 并停在
`WAITING(APPROVAL)`。**表外无未分类 APPROVAL interrupt**——内核另四类等待
（INPUT / DEPENDENCY / RESOURCE / EXTERNAL）按内核规则产生，不进表。

| 行 | 状态转换（唯一状态机的词） | 为什么需要批准 | eligible_principal | auto_policy |
| --- | --- | --- | --- | --- |
| H1 | 工单 Artifact `DRAFT → FROZEN`；Task `WAITING(APPROVAL) → VALIDATING` | 出题方＝答题方则验收非独立 | `owner` | 无；T0 由已签任务类包承担（§7.2） |
| H2 | Task `VALIDATING → QUEUED`（开工确认） | 唯一一次把「AI 复述的理解」与人的意图对齐 | `owner` | 有：T0 + `decide` 时按版本化策略放行，落 `RouteDecision{policy_version, matched_rule}` |
| H3 | 省事方向裁定生效：`WAITING(APPROVAL) → QUEUED` | 自动化默认漂移方向永远是省事 | `owner` | 无 |
| H4 | 扩权（冻结授权范围内的预算 / 资源额度）：`WAITING(APPROVAL) → QUEUED` 或 `→ FAILED` | 预算与范围是 fan-out 的唯一硬上限 | `owner` | 无 |
| H5 | 不可逆 Side Effect（写共享最终路径、合并主线）：publisher Attempt `COMPLETED` 后 `RUNNING → SUCCEEDED` | 无法回退 | `owner` | 无 |
| H6 | 推翻裁定 / 改冻结验收条：`WAITING(APPROVAL) → QUEUED` | 裁定本身是证据，只有更高权力能覆盖 | `owner` | 无 |
| H7 | 非终态 `→ CANCELLED`（先持久化取消意图、盘点副作用） | 取消不是 agent 可顺手做的 | `owner` | 无；表内唯一不锚仓外的行——伪造取消只停工不放行，失败安全方向 |
| H8 | 回答本 Task 的 `WAITING(INPUT)` Interaction：验证期 `WAITING → VALIDATING`，执行期 `WAITING → QUEUED` | 澄清只有歧义实质改变结果 / 权限 / 成本 / 风险时才发起 | `requester`（开发任务里 = `owner`） | 无 |

三条纪律：**H1 属验证阶段**，恢复边是 `WAITING → VALIDATING`；**改授权范围不属
in-Task 修订**，按内核「终态、刷新与重新处理」建带 `supersedes` 的新 Task；
**默认值是策略版本，不是代码兜底**——「忘了传 handler」与「故意选自动批准」在代码里
长得一样，必须显式化落账。

⚠ **已登记的形状缺口**：`runtime` 轮暴露 H5 只对准「⑦ 发布最终稿」，没有区分
最终稿发布与**轮内产物写主线**（后者该轮发生五次，未经 H5 门）。两者不可逆性不同
（轮内产物可 revert，最终稿进交付面）。处置方向是拆 `H5-final` / `H5-round`，
**本文不擅自改权力表行数**，登记 §11 待裁。

### 5.5 人的通道与回执：形状与现状的诚实评估

**形状**：引擎判定「当前转换命中权力表」时，写 `rounds/<id>/inbox-owner.md` 并停下；
人的回执**只认落盘**（对话里说「同意」不算，与 round-protocol「异议稿必须冻结提交」
同理）；H1、H3–H7 不设超时默认（最后一道关卡不默认通过），只有 H2 在策略明确允许的
T0 场景可按默认放行且落账。收件箱条目字段分级：**无默认的字段不得预填**
（验收条、executors 名单、tier——预填等于把盖章做成阻力最小路径，P3）；
可预填默认的（workspace 计划、预算窗）改动幅度落账为观察值。

**每次 H 回执登记三个观察值**：回执耗时、相对预填值的改动项数、按 H 行分计的签名次数；
⑦ 清理时汇总，所有者看趋势，**不由观测值自动触发 H6**。

**现状（经 §1.1 核查，必须如实说）**：上一稿为回执设计的仓外锚定方案已被证伪（§1.1
第 3 条）——它要防的「伪造批准」根因是同机同用户且有免密 sudo，而它自己解决不了
这个根因；且授权本身就是批准。**当前人的批准没有强过「所有者本人做出的动作」的
机制化锚点**：发布是所有者在本地做的 merge / push，强制点与签名点天然合一在人手里。
这不是缺陷声明，是现状登记；是否需要更强的锚、锚在哪，见 §9.2 的开放问题。

### 5.6 独立性折算

评优与裁决中，多家一致不等于独立信号强。登记 `provider` / `harness` /
`model_family` 三个事实字段，独立性由算法推导，不用单值标签（「cross-vendor」是
两个执行者之间的关系，不是成员共享的组名）。**折算首版**（允许粗糙，不允许缺席）：
分组键 = `harness`（同一 harness 的提示词与工具集相同，相关性最高）；
独立信号数 = 持相同主张的执行者所属不同组的个数；组内任一家带 `file:line` 或
可复跑命令取证，该组权重 ×2；裁决时先比独立信号数，相同则比带取证的组数。
**事实题用证据裁，不用票数裁**——一家独立带取证（1×2）胜过三家同 harness 无取证（1×1）。
评审之间有引用关系的，引用方在被引条目上视同同组。
⚠ 未验证：同 harness 不同模型的相关性到底多高；`runtime` 轮唯一观察是**同 harness
两家差异大于同厂不同 harness 两家**，单轮单题不足以定论（§11）。

---

## 6. 证据、验证与取证纪律

### 6.1 可观测粒度：三个字段，至少四档

「能看多细」「能在哪拦」「沙箱谁提供」是三件不同的事，分开取值——例证是
`codex exec --json`：逐条吐工具级 JSONL（`~/repo/codex/codex-rs/exec/src/cli.rs:60`，
经一家评审实跑复核），可见性到工具调用级，但吐的是执行者自报，强制点仍在进程外。

| 字段 | 取值（细 → 粗） | 含义 |
| --- | --- | --- |
| `observability` | `tool.enforced` ＞ `tool.reported` ＞ `process` ＞ `fs-only` | 运行时能看见的最细粒度 |
| `enforcement` | `tool-level` / `outer-only` | 运行时能拦在哪：工具网关（事中）/ 进程外层 |
| `sandbox` | `runtime` / `self` / `none` | 沙箱由谁提供、策略由谁定 |

当前五家 CLI/GUI 全为 `process`（fable 为 `fs-only`）或更低，`enforcement` 全
`outer-only`，`sandbox` 全 `self`。**没有一家是 `tool.enforced`**——那是 SDK 腿
建成之后才会出现的取值。

### 6.2 证据等级与采信算法

**采信等级 = `min(provenance, observability 可见上限, isolation 实际强度, verifier 独立性, coverage)`，
任一未知即降级，不取平均。**

| 等级 | 观察来源 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| `E0 ASSERTED` | 执行者 / principal 自述 | 仅作为待验证主张 | 行为发生、作者身份、完整性 |
| `E1 REDERIVED` | 运行时从冻结 workspace / Artifact 重算 diff、hash、测试 | 重算范围内的结果 | 未覆盖的进程内部动作 |
| `E2 PROCESS_OBSERVED` | 外层记录 argv / stdio / 退出码 + E1 | 调过哪个进程及其外部结果 | 内部逐工具调用、内部未留痕的出网 |
| `E3 TOOL_OBSERVED` | 运行时工具网关逐调用 Event + E1 | 经网关发生的调用与策略检查 | 绕过网关的系统调用，除非外层同时阻断 |
| `E4 EXTERNAL_AUTHORITY` | 执行者凭据域外的受保护日志 / 签名 / 审计 API | 指定主体或外部副作用的权威事实 | 人是否充分理解 |

与轨迹 `provenance` 的映射：`E0` = `reported` / `inferred`；`E1`–`E4` = `attested` 的子档。

四条推论：

1. **只有 `tool.enforced` 的事件是证据。**`tool.reported` 的事件流是**索引**——
   可据它决定去重新推导什么，不能据它下结论。
2. **证据由运行时从工作区重新推导，由 validator 跑，不由执行者跑。**实样：`runtime`
   轮一家拿休眠代码当能力证据，九份评审无一发现。
3. **覆盖声明必须同时列 `checked` 与 `not_checked`。**零命中只有在输入集合可枚举且
   枚举成功时才是 `E1`；否则结果是 `UNKNOWN`，不是 pass。
4. `RUNNING` 判不了是执行者属性，不是账本载体缺陷（§4.7 归因更正）。

### 6.3 验证分层：谁判什么

| 层 | 谁 | 判什么 | 判据要求 |
| --- | --- | --- | --- |
| L0 机器门 | pre-commit / CI / `--verify` | 全部机械判据：链接、表格、冻结区逐字节、提交↔处置记录对账、锚点可达、必须零命中的正则、测试、角色冲突 | 声明覆盖范围；首跑先与人工对照再当门禁 |
| L1 独立验收 | `acceptor`（既得利益最小的一家，由处置表算出） | 冻结的验收标准逐条；机器判不了的部分 | 只能按冻结标准；判「标准过期」要写理由交 arbiter |
| L2 来源核对 | 被处置到的各家（异议环节） | 「我的主张有没有被误读」 | 条目 + 为什么错 + 应当是什么 + 可复跑证据 |
| L3 人抽三样 | `approver`（H5 前） | 意图是否被正确理解、不可逆部分、抽样复算证据真实性 | 不逐行读；抽样规则写进工单 |

顺序不可换：L0 不过不进 L1，L1/L2 不过不叫人。**验收通过不构成「已验证」的背书，
只构成「经过一次外部检视」**——验收方漏了什么，没有任何机制能告诉你
（round-protocol「验收通过意味着什么」）。

### 6.4 取证纪律

1. **取证声明先于事实**：每条注明主机、执行身份、是否在沙箱 / 容器内
   （`hostname; id; cat /proc/self/uid_map`）。`uid_map` 恒等映射才是宿主真实身份；
   沙箱内的映射伪 root——同一台机器上已发生过一次据此的误判。
2. 权限测试必须以**与生产 agent 完全相同的 OS 用户与进程环境**复跑，不在任何沙箱内。
3. 边界的表述写成「agent 与人是否共享 credential domain」，不绑定「是不是 root」
   这个偶然事实。
4. 每条断言现状的句子附 `file:line` 或可复跑命令；做不成的老实标 ⚠；
   **未验证的结论标注清楚，不把推断写成事实**。
5. 本机当前事实（[`rounds/_spike-sign/forensics.md`](rounds/_spike-sign/forensics.md)，
   2026-09-05 宿主取证）：agent 与人同为 `uid=1003(zym)`，有免密 sudo 且在 docker 组，
   VM 身份对两个主仓 `push --dry-run` 均未被拒。**推论：本机一切本地强制点对 agent
   无效；只有托管方的 key 作用域与账户端点在 agent 的 credential domain 之外。**
   任何方案的安全论述以该记录为准。

### 6.5 等效判据：S 层 / R 层 / 投影 / TraceEnvelope

比较两种 orchestrator 实现是否等效，分两层：

| 层 | 比什么 | 何时可机械判 |
| --- | --- | --- |
| **S 层（schema）** | 对象集合、状态词、边、权力表行、Interaction 绑定字段、Agent Profile 字段 | 现在。候选给出字段即判 |
| **R 层（run）** | 同一 Task 的轨迹序列经投影 Π 之后逐条对应 | 两种 orchestrator 都按同一 schema 落账之后 |

「谁在哪条边上有权」属 S 层静态约束，不塞进一次 run 的轨迹里比。
R 层轨迹条目带 `provenance ∈ {attested, reported, inferred}`；
**投影 Π = 丢掉执行者私有 Event 与时间，保留 Task/Attempt 的边、权力表命中的
Interaction、Artifact 版本与作者**。
**`TraceEnvelope`**（契约 / 策略版本 / principal 身份域 / 输入摘要 / Side Effect 摘要 /
证据权威摘要）是比较上下文：没有它，两条同形轨迹可能一条获权、一条越权。

比对规则六条：① 白名单制（允许不同的只有载体、orchestrator 实现、粒度取值、
Π 丢掉的 Event、时间；白名单外差异一律判失败）；② 比对粒度取较粗一腿并显式列出
未比对项；③ 两边都声明权威源与重建规则（手工态是从 commit 重建的投影，工作区文件
永不作判据）；④ **等效只能在两条轨迹的最低来源等级上宣称**，结论附各类条目的
`attested` 计数；⑤ bootstrap 期权限归因项强度为零、单列判，服务态不得把手工态的
回执继承为可信先例；⑥ 先验证每个状态 ⊆ 内核状态集、每条相邻边 ⊆ 内核合法转换表，
然后才比序列。「轨迹」不是内核对象，不得据它另造第五个对象或新状态。

### 6.6 trace 样例读数与引用纪律

对上一轮真实产物重建的 23 条轨迹（可复跑命令与逐行表见源稿，本候选抽查复核无误）：
**`attested` 仅 2 条**（且身份都不 attested），`reported` 15 条，`inferred` 6 条；
Artifact 六个版本零 commit；H1 与 H5 由同一 commit 承担，账本分不开。
读数：**手工模式「看起来在跑」，轨迹基本不可复原**——这是「先在这一层跑通」的
账本版。对照组：`refact` 轮整合分支有 28 条逐主张提交，同一 Profile、同一
orchestrator 实现，`attested` 条目数量级不同——**差别不在载体，在纪律是否落成动作。**

引用纪律两条（各对应一种真实发生过的失败形态，防法不同、不可互相替代）：

1. **每个引用对象须先核验其属于所声明的那一轮**——对象真实存在、哈希可验但属于
   另一轮的，只查「是否存在」抓不到（张冠李戴）。
2. **无 ⚠ 声明的样例条目一律按「已核验」读，凭空构造即为假证据**——把本轮形状
   倒灌进历史、写出账本上不存在的对象而不作声明，前一条防不了它。

---

## 7. 路由、工单策略与工作区

### 7.1 路由：三值决策，模型只建议

```text
输入：原始请求 + 附件 + 请求者上下文
  ├─ 分类建议（可选；受限模型节点，无工具，固定 schema，低预算）
  │     → { tier_hint, domain_hint, complexity_hint, evidence[] }   ← 只是证据
  └─ 确定性规则表（版本化）
        → decide : 唯一命中 → RouteDecision{tier, executors, workspace_plan, policy_version, matched_rule}
        → ask    : 零命中或多命中 → 产生 H2 Interaction，列候选与各自理由
        → refuse : 命中拒绝规则 → Task REJECTED，reason code
```

三值而不是二值，让「不知道」不被压成「默认通用」。`tier` 的判据就是 round-protocol
「判据：命中任一条即 T2」那四条（不可逆 / 权威层 / 已知对立 / 判据未定）；
分类节点的产出是「四条各自命中与否 + 证据」，规则表据此判 tier，人只在 `ask` 时介入。
**模型不得决定路线**——这是已立的硬规则。

### 7.2 T0 任务类包与两道门

T0 的诚实定义：**题目能被「改动限于路径 X、通过门禁 Y」完全表达**；表达不了的升 T1。
T0 的 `acceptance` 必须是版本化策略文件里一个**命名任务类包**的名字，不得自拼门禁子集。
每个包三项：`paths`（允许触及的文件，机械判完工 diff ⊆ paths）、`gates`（必须通过的
门禁）、`covers`（人读的一句话——策略签名时所有者签的就是这句话）。
**包纪律**：任何包的 `paths` 展开集不得覆盖权威层文件、策略文件本身与门禁脚本——
否则「改门禁」与「被门禁判」落在同一可写面；宽包不许，多个窄包可以；
包的增删改按 T2（策略修改本就是 T2）。

**两道门，不是一道**：开工门（分发时）查包名 ∈ 已签策略、T0+`decide` 有
`RouteDecision` 落账、T1/T2 有人的确认，不过拒发；完工门（H5 前）查实际 diff ⊆
`paths`、`gates` 全过，不过不进 H5。分发时还没有 diff，空集 ⊆ 任何 paths 恒真——
所以 `diff ⊆ paths` 只能绑在完工门。
**T0 的承诺只是「开工前零触点」**：发布仍要 H5，不免除。

### 7.3 工作区供给：纯函数，判据是独占与干净

```text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan) →
  前置判据（任一不成立即新建，不复用）：
    现有工作区 owner == task_id 且 == 该执行者      # 独占
    git status --porcelain 为空                    # 干净；有人的未提交改动时绕开，不 stash
    HEAD == baseline_commit                        # 基线一致
  数量规则：
    write_actors = 0 → 不建可写工作区（单文件 git show，整仓只读开 detached worktree）
    write_actors = 1 → 一个独占工作区、一条命名分支
    write_actors = N → 同一 baseline_commit 上 N 个 worktree + N 条命名分支 + 一个整合 worktree
    review_needed    → 额外一个检视 worktree，用完删
    submodule_plan   → 多仓时逐仓钉 commit 并记父仓 gitlink（constraints T4）
```

三条判断：**worktree 数量看写者数，要不要新建看独占与干净，两者都不看复杂度**
（复杂度不可机械判定，独占与干净可以）；**「事先创建好的仓库」只能是 `source`，
不能是工作区**（多个 Task 塞进同一预建仓违反 workspace 唯一归属）；**来源一律钉
commit，不钉地址或分支**（只固定分支名 → 评审对象漂移）。

### 7.4 独占在 CLI / GUI 腿是约定，不是隔离

| | `agent-sdk`（`observability = tool.*`） | `agent-cli` / `agent-gui` |
| --- | --- | --- |
| 工作区怎么来 | 挂进运行时提供的沙箱 | 宿主上建目录，把路径传给进程 |
| 进程看见什么 | 沙箱根 | 整个文件系统（本机各 CLI 与 GUI 后端同用户） |
| 「独占」是什么 | 隔离 | **约定**；打破约定的动作运行时事中看不见 |

登记字段 `workspace_isolation = enforced | convention`，当前全部 `convention`。
后果：CLI 腿 Task 的授权范围声明只能依赖「事后审计可发现越权读取」；
**涉及第二租户或真实财务数据前，CLI 腿的数据源必须经运行时的数据网关，不得给裸库凭据。**
现场证据两则（`runtime` 轮）：一家在自己 worktree 起草却读了其他 worktree 与外部仓；
同一执行者同一会话内 `id` 先报伪 root 后报真实 uid——身份切换发生在助手自带沙箱里，
运行时看不见。

---

## 8. 开销盈亏线：什么时候不该走运行时

**前提**：开销是 **(任务, orchestrator 实现)** 的函数，不是任务单独的函数。

### 8.1 分类规则（机械可判，全部由工单字段直接判）

| 规则 | 字段判据 | 结论 |
| --- | --- | --- |
| M1 | proposers ≥ 2 或 write_actors ≥ 2 | 走运行时更便宜 |
| M2 | 计划中的审批触点 ≥ 1（tier ≥ T1，或 T0 但 router `ask`） | 走运行时更便宜 |
| M3 | `read_only_inputs[]` 非空且带版本锚，或依赖另一 Task，或 `needs_resume` | 走运行时更便宜 |
| M4 | `paths ∩ 权威层路径集 ≠ ∅` | **必须**走运行时（无关便宜） |
| M5 | 副作用清单非空，或 `needs_audit_trail`，或 `recurrence_key ≠ null` | 走运行时更便宜 |
| M0 | 以上皆否 | 走运行时**更贵**，除非满足 §8.3 的上界 |

规则不读题目自然语言；路由结果必须保存 `matched_features`。
⚠ **不得用 `tier` 作为「走运行时更便宜」的输入**——档位由风险判据定，
用档位反推成本是循环。新增布尔字段缺省 `false` 会 fail-open，须在工单上显式声明。

### 8.2 三类反例（走运行时反而更贵）

1. **单文件笔误 / 死链修补**，落在已签 T0 类包的 `paths` 内。**贵在供给**：
   一个不需要隔离的任务被强制隔离，任务本体十秒，手续一分钟。
2. **一次性提问 / 探索性阅读**。它没有 Artifact 落盘，而 output_schema 必须有
   final_path。**贵在 VALIDATING：为一个不需要契约的任务形成契约**；目标未定时会在
   「澄清—改目标—再澄清」间空转，而改目标要建新 Task。
3. **对 `dispatch = manual` 执行者的任何分发**（M0/T0 类）。**贵在派发与身份核对**：
   运行时看不见的执行者，每次调用都要人替它证明「是谁、在哪」。

**不接受的说法**：「都值得走，因为留痕总是好的。」留痕成本高于改动价值时，
留痕不会发生，发生的是绕过。

### 8.3 T0 开销上界（复合向量，任一维超标即不标 T0）

**人的必需动作** = 没有它 Task 就不能推进的、由 principal 做出的动作。手工模式一个
T0 任务的基线 = 2（说一句 + 一次 commit / push）。

```text
(human_required_actions, persisted_artifacts, request_to_dispatch_steps, dispatch_events)
        ≤ (        2,              4,                  2,                     0        )
且 human_required_actions ≤ 同一任务手工模式的动作数
```

两条推论：T0 工单必须**从请求自动生成**（router `decide` 选包、tier、执行者）；
H5 必须**折进人本来就要做的那次动作**（凭据在人手里，发布动作本身就是确认）。
**通知送达或敲命令不算决策，但仍计动作**——防止把传声筒成本藏掉。

### 8.4 绕过的可观测性

**先说限度：绕过发生在运行时之外，账本天然看不见。「完全可观测」不可达。**三层，
没有一层承诺全知：

1. **让绕过无利**：主线写入只经 H5；绕过的最大动机（快）保留为合法路径（§8.3）。
2. **对账，分母取外部 sink**：`bypass_rate = 未归因的合格变更数 / 全部合格变更数`，
   分母取外部权威 sink（托管方 pre-receive、git 底座对账、工作区脏状态、终端历史），
   每个 sink 显式列出覆盖与**不**覆盖。找不到对应 Event 的变更记 `UnattributedEffect`，
   **不得反向补造正常 Task**；命中记 `BYPASS_CANDIDATE` 观察 Event，不自动惩罚。
   「绕过」不是内核对象，不得据此新增状态。
3. **降低登记成本**：`register --from-commit <sha>` 一步把已发生的改动登记为
   retroactive T0 Task；retroactive 比例本身就是超上界的信号。

**如实声明看不见的**：未提交的工作区改动、纯对话问答，任何机制都看不见。
**零命中只能写成「没查到」，不能写成「没有绕过」。**当前条件下 git author 无法区分
人与 agent，principal 侧的绕过指标为 `UNKNOWN`。

---

## 9. 人介入与发布的正确形状

### 9.1 用基座库原语，不自造协议（B6）

基座库（investment-app 实际用法，§1.1 第 1–2 条已复核）提供的人介入原语：
出向 `interrupt(<任意 dict>)`——载荷形状由调用方自定；入向
`Command(resume=<任意值>)`——单个值；恢复是**同一 thread_id 检查点原地继续**，
不换 Attempt。approve / reject / 自由文本答复 / 选项选择，都能用这一对原语表达；
需要结构化修订时，出向 dict 携带被审 Artifact 与可改范围，入向值携带人的版本引用，
**形状属 Task Profile 层，不属于内核绑定，更不需要自造一套带 schema 与模式字段的
入向协议**（§1.1 第 1 条已证伪的那套）。

执行层租用不自建（constraints A4）：依赖边界限定在 SDK，不直接依赖裸协议；
中断、恢复、检查点用库的。

### 9.2 授权、批准与发布：现状与信任域事实

- **授权本身就是批准。**开发场景里，H5 的强制点与签名点天然合一：能合并主线的人
  就是所有者本人，发布动作（本地 merge / push）只能由持有凭据的人做出。
  为「证明人批准过」再建一套独立于授权的签署设施，解决的是一个不存在的问题，
  且解决不了真问题（§1.1 第 3 条）。
- **真问题是信任域**：当前 agent 与人同机同用户、有免密 sudo（§6.4 第 5 条），
  账本上 agent 提交与人的提交不可区分，`channel_grade = shared-credential`。
  在该信任域内做的任何本地验证（验签、hook、门禁脚本）都不是边界。
- **发布路径是本地 merge，不经网络**。master 长期 ahead 于 origin——托管方的
  key 作用域管不到这条路径。要把 H5 变成机制化强制点，有效方向只有两个：
  发布改经托管方（key 作用域在 agent credential domain 之外），或收紧本机信任域
  （移除免密 sudo / docker 组、agent 跑专用低权用户）。两者都是所有者动作，
  agent 无法代劳；在此之前，H5 的诚实表述是「人的显式动作」（round-protocol
  「⑤ 验收 与 ⑥ 确认」：不得由任何 agent 代行，不设逾期默认）。

### 9.3 仍开放的设计缺口

如实登记，不假装已解决：

1. **响应者身份鉴别**：`interaction` 表 + 鉴别端点是 §4.6 Interaction 行的拆除前置；
   同一信任域里提供端点只是把 reported 搬了个家。
2. **结构化修订的规范形状**：人的「部分否定 / 以自己的方案替代」在账本上如何落成
   Artifact 版本（作者 = principal）并进入下一 Attempt 输入——形状需求真实存在
   （财务场景同样命中），但答案必须用 §9.1 的原语构造，且若触及内核绑定字段须按
   内核「修订纪律」走规范修订工作单元。
3. **H5-final / H5-round 拆分**（§5.4 ⚠）。
4. **轮内产物写主线的管辖**：`runtime` 轮五次未经 H5 门，登记待裁。

---

## 10. 文档治理

### 10.1 文档分工与本稿不含什么

| 文档 | 职责 | 不含 |
| --- | --- | --- |
| 本文 | 开发怎么跑：运行时、角色、证据、路由、开销线、介入形状 | 具体业务功能、任务清单、流程规范正文 |
| 内核 | 对象与状态机的唯一定义 | 开发场景的具体落法 |
| round-protocol | 并行评优轮怎么走 | 本文只导读：新读者读完本文 §4–§5 后，按它的「收到『继续』时怎么办」即可自助定位环节 |
| constraints | 硬约束册 | — |
| development-plan / implementation-plan / handoff | 建什么 / 顺序 / 进度 | — |

**导读关系**：本文不复制 round-protocol 任何一条正文（改了会双真源漂移，P1）；
轮次参与者以 round-protocol 为流程真源，以本文理解「为什么流程长这样」。

### 10.2 迁移映射方法：枚举全部标题，脚本查零缺口

文档合并 / 删除的唯一可靠方法：**枚举源文档全部 `##` / `###` 标题，每个标题必须有且
只有一个落点**（新文档某节，或「删除：理由」），映射表由脚本生成骨架、检查零缺口，
并进 L0 机器门。粒度是「全部标题」而非「几个大节」；行数不进入任何判据——
重复段落消除才是收益，行数下降不是。本文 §12 即按此方法构造。

### 10.3 文档的删除条件

一份文档被取代后，删除前下列判据全部机械可判（以两份源稿的删除为例）：

1. 取代它的新文档通过 [`doc-gate.py`](doc-gate.py) 与 [`anchor-gate.py`](anchor-gate.py)；
2. 引用清理：对新文档之外的引用全文检索零命中（`git log` 除外）；
3. 迁移映射零缺口（§10.2 的脚本判）；
4. 源稿中仍标 ⚠ 的未验证项在新文档逐条可寻、仍标 ⚠；
5. 删除动作本身是不可逆动作，经 H5 确认。

### 10.4 内核按 commit 引用，防双向耦合

内核是持续演化的产品真源，本文若跟随其 HEAD，产品侧每次改内核都会反向冲击开发
流程文档与脚本。规则三条：① 本文注明引用的内核 commit；② 内核对象名 / 状态名的
任何修改按 T2；③ 内核修改后重跑状态词集合比对（开发侧使用的 states/edges 与内核
「两层状态机」对称差为空），通过才算合并。

---

## 11. 风险与未决登记

| # | 事项 | 状态与处置 |
| --- | --- | --- |
| 1 | 「Attempt 可产出 typed Artifact」是否算对内核 Attempt 定义的扩充 | 未决；若是，按内核「修订纪律」走修订单元（§4.2 ⚠） |
| 2 | 独立性分组键（`harness`）是否足够 | ⚠ 未验证；由「候选相似度」观测值校验，届时可能改为 `(harness, model_family)`（§5.6） |
| 3 | H5-final / H5-round 拆分与轮内产物写主线的管辖 | 未决；`runtime` 轮已登记，本文不擅自改权力表（§5.4） |
| 4 | H5 的机制化强制点 | 两个有效方向均需所有者动作（§9.2）；现状登记为「人的显式动作」 |
| 5 | 响应者身份鉴别（Interaction 服务化前置） | 未决；信任域收紧前不拆（§9.3） |
| 6 | 结构化修订（部分否定 / 替代）的规范形状 | 未决；必须用库原语构造（§9.3） |
| 7 | T0 的「可逆出口」（只落 worktree、免 H5） | 未决；属省事方向的新权力表行，有签名次数观察值后再定。弊端已知：worktree 成果无状态，堆积后批量 push 就是批量不可逆动作 |
| 8 | round-protocol「命中任一条即 T2」的「权威层」覆盖面过宽 | 判据属 round-protocol，改它是它自己的 T2 |
| 9 | 触点疲劳导致盖章化 | 观察值：回执耗时、改动项数、每票签名次数；不设自动动作（§5.5） |
| 10 | 单 principal 阶段的权力表在多用户场景是否够用 | 表结构已按 principal 设计；capability 列等出现第二个 principal 再加 |
| 11 | 三值路由初期大量 `ask` | 预期行为；每次 `ask` 的人工选择按「裁量是规则的孵化器」反哺规则表 |
| 12 | 内核演化冲击本文 | §10.4 三条：按 commit 引用、内核改动 T2、改后重跑状态词比对 |
| 13 | `QUEUED` / `RUNNING` 在事件文件落地前不可判 | 已声明；脚本合并显示并标 ⚠（§4.7） |
| 14 | retroactive Task 与内核 I1「原始输入不被后续解释覆盖」的关系 | 未决；建单时一并核（§8.4） |
| 15 | H1 与 H5 同 commit 的账本歧义在服务态如何拆 | 未决（应是两个 Interaction，手工态今天做不到） |
| 16 | `ai-dev-readiness/` 五份与 `pipeline-task.md` 轮的归档 | 历史产物；与本文无冲突，不展开 |
| 17 | 上一份融合尝试（本轮任务书 §3.1 所指文档）的去留 | 本轮 ⑥ 之后由所有者定 |

---

## 12. 逐节落点表（D2）

两份源稿全部 64 节逐节对照。「故意不要」均给出具体理由。
本稿章节号以本文标题为准。

### 12.1 `refact-fable.md`（31 节）

| 源 | 源稿的节号与标题 | 落点（本稿章节号）或「故意不要」+ 理由 |
| --- | --- | --- |
| refact-fable | §0 一页摘要 | §0（源稿摘要中的架构结论已按 `runtime` 轮推翻后重写） |
| refact-fable | §1 诊断：现状的六个结构问题 | §3 末段（六条诊断压缩保留为设计动因） |
| refact-fable | §1.1 「两条路径」是假分叉 | §3 末段（诊断 1） |
| refact-fable | §1.2 supervisor 已有三套同名物，第三套还有一个未定义的别名 | §5.1（解体为五个词的动因） |
| refact-fable | §1.3 权力与流程混写 | §5.4（权力表驱动 interrupt 的动因） |
| refact-fable | §1.4 一个环节判不了 | §5.5、§9.2（人的动作必须落盘；现状诚实评估） |
| refact-fable | §1.5 执行架构与开发流程装在同一份文件里 | §10.1（文档分工的动因） |
| refact-fable | §1.6 档位只有 T2 有正文 | §4.3（档位 = 三张表的动因） |
| refact-fable | §2 设计原则 | §3（P0–P5 全文保留） |
| refact-fable | §3 目标架构 | §4 全章（结构按 `runtime` 轮结论重排） |
| refact-fable | §3.1 一套状态机，两个 Profile（源题原名，其结论已推翻） | **故意不要**：按部署形态分立 Profile 的主张被 `runtime` 轮推翻——五格取值不同不构成分立 Profile 的理由，且内核已定义 Task/Agent Profile，再造第三义正是它自己诊断的同名物病；正解为一个运行时 + `dev.change`，见 §4.1–§4.2 |
| refact-fable | §3.2 执行者模型：三种 kind，一张登记表 | §5.2（登记表保留；以 kind 标人已被推翻，人改登记为 principal，见 §5.3；独立性两维见 §5.6） |
| refact-fable | §3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源 | §5.4（表形状保留，行按 `runtime` 轮 H1–H8 版重述） |
| refact-fable | §3.4 人的通道：收件箱 + 回执 | §5.5（收件箱形状保留；仓外锚定方案已证伪，现状如实登记） |
| refact-fable | §3.5 路由：三值决策，模型只建议 | §7.1 |
| refact-fable | §3.6 工单：一个冻结的 Artifact，一次确认 | §4.3、§7.2（T0 类包与两道门独立成节） |
| refact-fable | §3.7 工作区供给：纯函数，判据是独占与干净 | §7.3 |
| refact-fable | §3.8 状态判定与分发：一般化现有脚本 | §4.7 |
| refact-fable | §3.9 角色：supervisor 解体为五个各有定义的词 | §5.1 |
| refact-fable | §3.10 开发 Profile ↔ 内核对象对照（源题原名） | §4.4、§4.5（产物映射与载体语义分两节重述，Profile 措辞按推翻结论改正为 Task Profile `dev.change`） |
| refact-fable | §3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了 | §4.5（含验不了的三样） |
| refact-fable | §3.12 验证分层：谁判什么 | §6.3 |
| refact-fable | §3.13 签名回执的威胁模型与密钥分布 | §6.4（取证纪律保留）、§1.1 第 3–5 条（边界设计方案已证伪：授权即批准、agent 不 push、发布是本地 merge）、§9.2（信任域真问题与有效方向） |
| refact-fable | §4 对原建议的处置 | **故意不要**：这是对所有者 2026-09-05 一次思路的逐条处置记录，属轮次档案；其中「采纳/改造」的结论已分别吸收进 §4–§7 对应章节，表格本身不含额外规范内容 |
| refact-fable | §5 文档重构 | §10 全章 |
| refact-fable | §5.1 目标文件树 | §10.1（文件树中 lifecycle.md / authority.md 等规划未落地，按现状文档分工重写） |
| refact-fable | §5.2 旧 → 新映射：按旧文全部标题，脚本检查零缺口 | §10.2（方法论保留，本文 §12 即按它构造） |
| refact-fable | §5.3 删除条件 | §10.3（五条机械判据保留并适配到本轮） |
| refact-fable | §6 实施路线 | **故意不要**：R0–R5 是该轮的实施排序，R0/R0′ 已执行完毕，其余各轮取舍属任务清单与进度（`implementation-plan.md` / `handoff.md` 的职责），不属指导文档；其中仍有效的未决项已并入 §11 |
| refact-fable | §7 风险与未决 | §11（17 条逐条更新状态：已被证伪的改记 §1.1，仍成立的保留） |
| refact-fable | §8 本方案自身的验收标准（供开轮时冻结） | **故意不要**：那是开那一轮用的冻结判据，随该轮结束而失效；其中仍有规范效力的内容（触点数 0/1/2、状态词对称差、强制点在 credential domain 之外）已分别落入 §4.3、§10.4、§6.4 与 §9.2，照搬全表会把轮次判据误当长期规范 |

### 12.2 `runtime-architecture.md`（33 节）

| 源 | 源稿的节号与标题 | 落点（本稿章节号）或「故意不要」+ 理由 |
| --- | --- | --- |
| runtime-architecture | §0 一页摘要 | §0（第 4 条 amend 相关结论按 §1.1 核查结论撤除） |
| runtime-architecture | §1 本稿与上一轮的关系 | §1（含「RUNNING 判不了」归因更正，另见 §4.7） |
| runtime-architecture | §2 P1 — 一个运行时、唯一状态机、`dev.change`、五个 Agent Profile | §4、§5 两章 |
| runtime-architecture | §2.1 运行时 = 内核对象的唯一写入面 + 四个确定性组件 + 两个适配层 | §4.1 |
| runtime-architecture | §2.2 Task Profile `dev.change` 版本 1 | §4.2（含别名登记与不得外推的边界，边界另见 §2 末段） |
| runtime-architecture | §2.3 五个 Agent Profile：登记表 | §5.2 |
| runtime-architecture | §2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行 | §5.3、§5.4（介入实例清单的规范结论已进表；清单本身属轮次档案，其中暴露的 H5 缺口登记 §5.4 ⚠ 与 §11-3） |
| runtime-architecture | §2.5 `dev.change` 的产物 → 唯一状态机 | §4.4 |
| runtime-architecture | §2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现 | §4.6 |
| runtime-architecture | §2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文 | §6.5 |
| runtime-architecture | §2.8 trace 样例：`refact-fable` 轮的真实产物 | §6.6（读数与引用纪律保留；23 行逐条表为可复跑证据，源稿删除后可由所附命令从 git 历史重建） |
| runtime-architecture | §3 P2 — Interaction 双向带载荷：一个内核修订工作单元 | §1.1 第 1–2 条（整套设计已证伪）、§9.1（正确的原语）、§9.3-2（仍开放的真实缺口） |
| runtime-architecture | §3.1 缺口 | §9.3-2（「部分否定 / 替代需落成 Artifact 版本」是真实需求，保留为开放问题；原论证所依赖的「入向只有布尔」前提经复核不成立——入向是任意值） |
| runtime-architecture | §3.2 扩展后的绑定字段表 | **故意不要（已证伪）**：出向六字段、入向三值、`amend_schema`、`amend.mode` 在基座库中无对应物，库出向收任意 dict、入向单值，见 §1.1 第 1 条与 §9.1 |
| runtime-architecture | §3.3 `amend` 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task | **故意不要（已证伪）**：它假设恢复时开新 Attempt 消费 amend 输入，而库的检查点是同一 thread_id 原地恢复，见 §1.1 第 2 条；「不建新 Task」的直觉本身正确，已由 §9.1 原语覆盖 |
| runtime-architecture | §3.4 与权力表的对应 | **故意不要（已证伪）**：全表建立在 §3.2 的字段表上，字段表证伪后对应关系无承载；权力表与 Interaction 的关系按 §5.4 + 内核「WAITING 与 Interaction」表达 |
| runtime-architecture | §3.5 修订工作单元（按修订纪律） | **故意不要（已证伪）**：修订单元修订的是 §3.2 那套字段，对象不复存在；「是否真需内核修订」降级为开放问题，见 §9.3-2 |
| runtime-architecture | §4 P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果 | §5.2、§6.1、§6.2 |
| runtime-architecture | §4.1 粒度是三个字段，不是一个；至少四档 | §6.1 |
| runtime-architecture | §4.2 五家的取值 | §5.2、§6.1 末段 |
| runtime-architecture | §4.3 证据权威性：由粒度推导，不由执行者声明 | §6.2 |
| runtime-architecture | §4.4 三道边界是架构组件，不随脚手架拆 | **故意不要（已证伪）**：作为安全架构组件的边界设计要拦的动作不经过它们——发布是本地 merge、agent 不 push、同 uid 免密 sudo 使本地强制点全部无效，见 §1.1 第 3–6 条；其中仍成立的信任域事实与两个有效方向移入 §6.4 第 5 条与 §9.2 |
| runtime-architecture | §4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离 | §7.4（含工作区供给纯函数，见 §7.3） |
| runtime-architecture | §4.6 R2：principal 通道也有粒度 | §5.3 末段、§9.2（R2 前置保留为 §9.3-1；收件箱形状见 §5.5；凭据分布与多 key 方案已证伪，见 §1.1 第 5 条） |
| runtime-architecture | §4.7 取证纪律与当前事实 | §6.4（取证纪律四条保留；当前事实以 forensics.md 为准） |
| runtime-architecture | §5 必答 Q：运行时相对手工直接调用助手的开销盈亏线 | §8 全章 |
| runtime-architecture | §5.1 分类规则（机械可判，全部由工单字段直接判） | §8.1 |
| runtime-architecture | §5.2 反例（三类走运行时反而更贵的任务） | §8.2 |
| runtime-architecture | §5.3 T0 开销上界（复合向量，任一维超标即不标 T0） | §8.3 |
| runtime-architecture | §5.4 绕过的可观测性 | §8.4 |
| runtime-architecture | §6 对 OP-1 / OP-2 / OP-3 的裁定 | **故意不要**：三项裁定的结论已全部落在对应章节正文（OP-1 → §6.5，OP-2 已随 §3.2–3.5 证伪，OP-3 → §8），裁定过程与利益申报属 `runtime` 轮档案（`rounds/runtime/`），不是指导文档内容 |
| runtime-architecture | §7 覆盖声明、盲区与未验证项 | **故意不要**：那是该裁决稿的自陈，审计对象是那份稿子本身；其「未验证」清单中仍成立的四条已并入 §11（#1、#2、#14、#15），本稿的自陈在 §13 |
| runtime-architecture | §8 自检：对照 `task.md` §8 十条 | **故意不要**：那是 `runtime` 轮的轮内自检表，判据随该轮结束失效；把轮次自检搬进指导文档会让后来的读者误判它为长期标准 |

---

## 13. 覆盖声明（D3）

**本候选的身份与隔离**：

- 身份由命令取得：`git rev-parse --show-toplevel` → `/home/zym/worktrees/kimi/k8s`，
  目录名 `kimi`。
- **未读 `agent-dev-refact.md`**（裁定 R2）：未打开、未 `git show`、未 grep/rg 其内容，
  未以它为起点。本文对它的全部提及仅限于任务书与工单中已写明的事实（它存在、
  被移出只读输入、行数规模）。
- 候选提交前未读任何其他家的 worktree 或分支。⚠ 隔离靠纪律不靠机制
  （各 worktree 共享同一个 `.git`），无法事后证明独立，如实告知。

**查了**：

- 两份源稿全部 64 节全文（按 baseline `ed0b5136` 取件：`refact-fable.md` 933 行、
  `runtime-architecture.md` 1062 行）；
- 内核 `working/request-lifecycle.md@ed0b5136`（647 行）的核心对象、两层状态机、
  WAITING 与 Interaction、Attempt 字段、Profile 与扩展各节；
- [`constraints.md`](constraints.md) 的 A1–A5 与「保证这些被遵守的三层」；
- [`round-protocol.md`](protocol/round-protocol.md) 全文（环节判定、档位、验收方计算、
  引用纪律）；
- [`rounds/_spike-sign/forensics.md`](rounds/_spike-sign/forensics.md) 全文；
- `runtime-refact` 轮的 `round.md`、`call-①.md`、`runtime-refact-task.md` 全文；
- §1.1 六条证伪命令中可在本环境复跑的全部（见下）。

**独立复核记录**（§1.1，investment-app 子模块 commit `18d88c7c`）：

- 第 1 条：✅ 读 `pilot_graph.py:50-70`（`interrupt({kind, action_id, prompt})` 收任意
  dict）；`rg 'Command\(resume' app/` 得 25 处调用，全部为单参数；
- 第 2 条：✅ 读 `graph_runtime_service.py:30-50`（同一 config/thread_id 继续
  `graph.stream`，`__interrupt__` 即返回）；
- 第 3 条：⚠ 部分。`id` = `uid=1003(zym)` 已复跑；`sudo -n -l` 在本候选沙箱内被
  no-new-privileges 拦截（本沙箱 `uid_map` 非恒等），**免密 sudo 一项以
  forensics.md F1 的宿主取证为准，本候选未独立复跑**；
- 第 4 条：✅ 部分。`git branch -vv`：五家分支均无 upstream（agent 不 push 的本地
  旁证）；`git ls-remote --heads origin` 因本候选沙箱断网（DNS 解析失败）不可复跑；
- 第 5 条：✅ 旁证。master ahead `origin/master` 93（发布在本机、不经网络）；
  远端标签状态沙箱内不可查；
- 第 6 条：✅ 由第 3–5 条取证链互证，无独立命令。

**没查**：

- `~/repo/codex`、`~/repo/deepseek-harness`、`~/repo/openclaw` 三个外部参考仓的内容
  （本文仅引用 `runtime` 轮已复核的 `cli.rs:60` 锚点，未自己复跑该锚点）；
- `development-plan.md`、`implementation-plan.md`、`handoff.md` 的全文（仅作背景
  指引，未逐节核对其中是否有应进本文的内容）；
- `rounds/` 下前三轮的全部评审与处置记录（只读了 `forensics.md` 与
  `runtime-refact` 本轮文件；源稿中标注「见 disposition」的逐条理由未逐条回溯）；
- `doc-gate.py` / `anchor-gate.py` 的内部实现（只读了 doc-gate 头部说明，
  两门禁将在提交前实跑）；
- investment-backend 中除 §1.1 第 1–2 条指定两处以外的运行时代码。

**未验证 ⚠**：

- 第 3–5 条中标注「沙箱内不可复跑」的项（免密 sudo、远端分支与标签状态）——
  结论以 forensics.md 与本地旁证为据。本候选的沙箱环境本身即是一处取证边界：
  §6.4 第 1 条要求「与生产 agent 相同环境」，本候选不满足，如实声明；
- §6.6 的 23 条轨迹读数：复核了可复跑命令的形状与源稿结论的一致性，
  未逐行重放全部 23 条；
- §11-2 独立性分组键：沿用源稿的 ⚠ 标记，无新观测值。
