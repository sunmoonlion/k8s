# 开发生命周期 · Agent

> 最后更新：2026-09-03
>
> **本文定义开发类请求的 Agent 路径：前端用户提出请求，FastAPI 受理并整理成
> Task；应用层调度监督器以确定性代码选择执行路线；复杂 Task 先在 sandbox 中获得按任务
> 物化的 Git 仓库，再经统一执行 Port 交给 Codex 或 DeepSeek Harness；执行 Agent 可单路
> 实施，也可在 Attempt 内成为执行监督 Agent，按需建立 worktree、派工、选优、整合和验收；
> 最终结果经后端持久化后返回前端。**
>
> Human 路径与之同构，但工作环境起点不同：Git 仓库和初始 worktree 由人建立。
> 从“冻结的开发工作单元已经拥有可写工作区”开始，Human supervisor 与执行监督 Agent
> 地位等同，适用同一套拆分、隔离、证据、选优、整合和关闭规则。
>
> 本文是目标流程，不是当前实现清单。文件存在不等于 FastAPI、sandbox provisioner、
> Agent runtime 或验收链已经实现；能力现状只由代码、迁移、测试和运行证据证明。

## 0. 边界和共同模型

### 0.1 本文负责什么

本文覆盖开发类请求的完整 Agent 路径：

```text
Submission
  → FastAPI 受理与 Task 化
  → 简单/复杂路由
  → sandbox 与 Git 工作区物化（复杂 Task）
  → Agent Attempt
  → 执行监督 Agent 按需展开 Work Unit / worktree
  → 实施、评审、选优、整合
  → 最终验收与 Task 终态
  → Delivery 返回前端
  → sandbox 清理或保留
```

| 文档 | 权威范围 |
| --- | --- |
| [`request-lifecycle.md`](request-lifecycle.md) | 通用产品对象、状态、幂等、租约、预算、Interaction、Artifact、Event、Delivery |
| 本文 | 开发 Profile 下的 Task 化、工作区物化和开发执行生命周期 |
| `development-lifecycle-human.md` | Human 路径。**只放在人的主 checkout**（`~/master/<仓>`），各助手分支不保留——那份是给人看的，助手用不到 |
| [`../constraints.md`](../constraints.md) | 开发结果不可违反的硬约束 |
| [`../handoff.md`](../handoff.md) | 当前阻塞和下一动作的交接投影 |

Git、远端与子模块的纪律以本文 §7 为准。**跨机同步五仓用
`~/five-repos-sync/sync-five-repos.sh`**：它推送五个父仓，拉取侧自动
`submodule sync/update` 对齐 gitlink；⚠ 它不推子仓，子仓的提交仍须自己推
（见 [`../constraints.md`](../constraints.md) T4）。

### 0.2 事实、目标和执行记录分开

- 代码、迁移、测试和可重跑运行结果决定**当前事实**；
- `request-lifecycle.md`、`constraints.md` 和冻结 Task 决定**目标与边界**；
- Task/Event/Attempt、Git commit、manifest、门禁输出和 checkpoint 记录**本次执行**；
- `request-baseline/` 与其他历史稿只能解释来源，不覆盖现行合同，也不证明当前能力。

目标合同与代码不一致时，登记实现缺口或按程序修订目标；不得把目标静默降级为现状，
也不得把未接线能力写成已经实现。

### 0.3 两层监督职责与等位原则

本文禁止用一个未限定的 “supervisor” 同时指两种东西：

| 定名 | 所在层 | 性质 | 能做什么 |
| --- | --- | --- | --- |
| **调度监督器**（dispatch supervisor） | Task / Attempt 之上 | Investment application 层确定性代码 | 消费已持久化 Task，解析 Profile，按政策路由，预留预算，创建/取消/恢复 Attempt，触发验收 |
| **执行监督 Agent**（execution supervisor） | 单个 Attempt 之内 | 受门禁约束的 Agent 开发角色 | 拆 Work Unit、派工、收候选、选优、整合 |

**还有第三套同名物，不在本文管辖内**：`request-lifecycle.md` 里产品侧把一个 Task 拆成
子 Task 的编排。它既不是调度监督器也不是执行监督 Agent，本文只引用、不定义。
**三套名字并列写在这里，是为了下一轮整合时不必再撞一次。**

代码符号用 `TaskRouter`（短、可进标识符），中文全称保留“调度监督器”。
**不采 `Dispatcher` 作为唯一名**——会与产品契约的 `F-DISPATCH-*` 绑死，
将来那组编号变动会连带改代码。

调度监督器的**不做清单**与它能做什么同样重要，否则它会长成第三个 agent：
不拆 Work Unit、不收候选、不做选优整合（那三件是执行监督 Agent 在 Attempt 内的事）；
v1 不做模型驱动的动态编排，路由表是版本化配置，命中规则、配置版本与 reason
随 `RouteDecision` 落账，供 `I1`/`I4`/`I15` 审计。

调度监督器必须是可重放、可解释的确定性代码，不能是第三个自由模型 Agent：错路由可能扩张
数据面、成本和副作用，代价不对称；自由模型决定不可稳定回放；分类调用自身也消耗必须先
预留的预算。模型至多作为无工具、固定 schema、低预算的受限分类节点，只能在调度监督器给出的
合法候选中选择，不能拥有队列、权限或终态。

执行监督 Agent 只在调度监督器已经完成路由、固定执行器、冻结 Profile、收窄权限并预留预算后
存在；它不能改路由、换执行器、扩大权限或把自己的候选验收为 Task 成功。这是
`F-DISPATCH-03`、`F-EXEC-01`、`F-EXEC-04`、`I3`、`I10`、`I15` 以及
[`../constraints.md`](../constraints.md) A2/A3/A4 的开发投影。

为保持既有开发内核逐字稳定，下文冻结小节里未加前缀的 `supervisor` 一律专指**执行监督
Agent / Human supervisor 这一开发协调角色**；只有写全“调度监督器”时才指上层确定性代码。

下表只比较 **执行监督 Agent** 与 Human supervisor；“等位”是开发协调职责等同，不涉及上层
调度监督器。

| 职责 | 执行监督 Agent | Human supervisor |
| --- | --- | --- |
| 冻结顶层工作单元 | 必须 | 必须 |
| 选择单路或 fan-out | 可以，在 Task 策略内 | 可以，在人的授权和裁量内 |
| 建立后续 worktree | 可以，在 sandbox 根仓内 | 可以，在人建立的根仓内 |
| 拆 Work Unit、派工 | 必须给完整派工契约 | 必须给完整派工契约 |
| 核对证据、选择主线 | 负责 | 负责 |
| 整合、最终回归、停止其他执行 | 负责 | 负责 |
| 扩大权限、追加预算、生产发布 | 无权自行批准 | 仅有权主体可以批准并留痕 |

地位等同是协调职责等同，不表示系统授权相同。执行监督 Agent 不因角色升级获得人的
批准权；Human supervisor 也不因是人就能省略边界、证据或验收。

### 0.4 产出物的根本原则：私有地产生，单写者发布

会话隔离、模型隔离和任务名称不同，都不等于文件系统隔离。**任何可能并行的执行者都不得
把共享路径当作自己的草稿纸。**所有产出先在执行者独占的分支/worktree 或 owner namespace
内产生；只有预先指定的 integrator 才能把选定结果写入共享发布面。

```text
private draft
  → owner candidate
  → frozen commit / immutable Artifact
  → supervisor selection
  → integrator workspace
  → final commit
  → shared branch / release / Delivery
```

共享发布面包括 `master/main`、公共工作树、约定的最终文件路径、共享对象存储键、正式 PR、
release、部署环境和用户可见结果。**用户要求的最终文件名是发布目标，不是所有候选都可同时
写的路径。**多个候选若各自在独立 worktree 中修改同一个相对路径，这是安全的；若共用一个
物理工作树，就必须使用 owner namespace，不能靠“最后再改名”避免覆盖。

## 1. 两条同构路径

### 1.1 Agent 路径

```text
前端用户
  │ ① 提交原始请求、材料和幂等键
  ▼
FastAPI
  │ ② 认证 / 授权 / 校验 / 规范化 / 建立 Task
  │
  ├── 简单 Task
  │     └── ③a 创建 Agent Attempt，在获准工具面内直接执行
  │
  └── 复杂 Task
        └── ③b provision sandbox
              ├── 建立 Task 根目录
              ├── 初始化或检出 Git 仓库
              ├── 按 Task 放入源码、附件、规则和输入 Artifact
              ├── 固定 initial commit
              └── 生成 materialization manifest
                         │
                         ▼
                 ④ Agent 接单并核对基线
                         │
                         ├── 单路实施
                         └── Agent supervisor
                               ├── 建立 worktree
                               ├── 拆 Work Unit
                               ├── 派给 Agent 或 Human
                               ├── 评审 / 选优
                               └── 整合
                         │
                         ▼
                 ⑤ final commit / Artifact
                         │
                         ▼
                 ⑥ 独立验收、证据和终态提交
                         │
                         ▼
                 ⑦ Delivery 返回前端并可重取
                         │
                         ▼
                 ⑧ 按策略保留或清理 sandbox
```

FastAPI 是受理边界和工作仓供给入口，不因此成为 supervisor。它负责把用户请求可靠地
变成可执行 Task，并直接完成或调度 workspace provision；派工、选优和整合属于接单后的
supervisor。

### 1.2 Human 路径

```text
人提出或接收请求
  → 人冻结请求、范围和验收
  → 人建立或选择 Git 仓库
  → 人建立初始 worktree
  → 人单路实施，或成为 Human supervisor
  → 按需建立更多 worktree、向人或 Agent 派工
  → 评审、选优、整合、验收、交付
```

Human 路径没有 FastAPI 替它建仓。入口差异到“可写工作区已经准备好”为止；后面的
supervisor 内核同构。未来重写 Human 文档时，应把共同内核完整写入，而不是保留“其余见
Agent 文档”的依赖，因为 Agent 文档可能在开发结束后删除。

## 2. Submission 与 FastAPI 受理

### 2.1 前端提交

开发类 Submission 至少提供或允许表达：

```text
original_request
target repositories / systems（已知时）
attachments / source refs / reference material
expected output
acceptance expectations
time / cost constraints
allowed side-effect boundary
idempotency_key
```

前端可以做格式提示和安全的客户端校验，但不得改写后只提交“整理后的意图”，不得用默认值
静默扩大范围、权限或成本，也不得自报后端必须从认证上下文取得的身份和租户。网络重试复用
同一幂等键；附件与引用先成为可校验 Artifact，不能依赖临时浏览器状态。

### 2.2 FastAPI 建立开发 Task

FastAPI 在可信边界内至少完成：

1. 绑定认证身份、租户、角色和数据作用域；
2. 幂等受理并保存未经改写的原始请求；
3. 校验正文、附件、资源引用、类型、大小和恶意内容；
4. 选择并冻结开发 Task Profile 版本；
5. 将输入规范化为范围、验收、权限、预算、批准点和期望输出；
6. 选择 Agent Profile、执行策略和 sandbox 策略；
7. 判断简单直接执行或复杂工作区执行；
8. 可靠持久化 Task 和首 Event 后才允许调度。

“整理”不是替用户做产品决策。歧义若会改变结果、范围、成本、权限、不可逆风险或验收
含义，必须建立 Interaction。局部、可撤销且由 Profile 明确定义的默认值可以规范化，但原值、
规则版本和转换结果都要保留。

### 2.3 Task 契约

开发 Task 至少冻结：

```text
task_id, requester, tenant
task_profile_id + version
agent_profile_id + version / selection policy
original_request_ref, normalized_request
included_scope, excluded_scope, excluded_owner
acceptance[], hard_gates[], quality_preferences[]
permissions, approval_points
budget, deadline, stop_condition
input_artifact_refs[], expected_outputs[]
source_refs[], baseline_commits[]
workspace_mode, sandbox_policy
run_id, owner_id, work_unit_id
writable_roots[], output_namespace
publication_target, integrator_id
```

硬门禁、质量偏好和待定项必须分开。原始请求只追加、不覆写；规范化结果与原话有张力时，
两者同时保留并记录裁决。实质变更目标或完成标准，应建立新 Task、superseding Task 或明确
新版本，不得在执行中无痕改口径。

## 3. 简单与复杂任务

### 3.1 简单 Task

同时满足下列条件时可以不建 Git 工作区：

- 不修改、生成或比较持久文件；
- 单 Attempt、单会话可完成；
- 不需要 worktree、回滚、diff 或固定源码版本；
- 外部副作用为零，或已有独立可靠的副作用账；
- 验收可直接针对结构化结果和证据完成。

“简单”只决定载体，不降低授权、证据、预算或验收。执行中发现条件不满足时，停止当前
Attempt 并保存 checkpoint，由后端升级为复杂 workspace；Agent 不得私自在 sandbox 外建仓。

### 3.2 复杂 Task

满足任一条件时默认使用 sandbox Git 仓库：

- 多文件修改、生成、迁移或代码审查；
- 跨步骤、跨会话、跨执行者或跨仓；
- 需要 checkpoint、回滚、diff、固定候选或 final commit；
- 需要 supervisor fan-out 或多个 worktree；
- 结果以代码、补丁、构建产物或可复现实验交付；
- 错误代价要求独立评审、选优或最终回归。

复杂度判定必须可审计。不能为省 provisioning 成本把复杂 Task 塞进无状态 Attempt，也不能
为形式统一给一次只读问数建立空仓库。

## 4. sandbox 与 Git 物化

### 4.1 谁建立什么

| 对象 | Agent 路径 | Human 路径 |
| --- | --- | --- |
| Task 根目录 | FastAPI 后端直接或通过 provisioner 建立 | 人选择位置并建立 |
| 顶层 Git 仓库 | 后端在 sandbox 初始化，或从获准来源检出 | 人初始化或检出 |
| initial commit | provisioner 固定 | 人固定 |
| 初始 worktree | sandbox 根工作区提供 | 人建立 |
| 后续 worktree | 当前 supervisor 按 Work Unit 建立 | Human supervisor 按 Work Unit 建立 |

FastAPI 可以把耗时物化委托给 provisioning service，但产品语义不变：**工作区门禁通过前，
Task 不得进入可执行 Agent Attempt。**

### 4.2 物化步骤

provisioner 应：

1. 建立独占 Task 根目录、资源限额和访问边界；
2. 初始化仓库，或从 Task 允许来源 clone/fetch 并检出固定 commit；
3. 多仓任务逐仓固定 commit，并记录父仓 gitlink；
4. 按 Task 放入源码、附件、模板、规则和输入 Artifact；
5. 放入适用的 `AGENTS.md`、Task 包或等价入口；
6. 对生成文件和输入材料记录来源与摘要；
7. 形成可复现 initial commit；
8. 生成 materialization manifest；
9. 确认凭据只有引用或受控挂载，明文不进入 Git；
10. 通过物化门禁后才发布 workspace 给 Agent。

### 4.3 按 Task 塞入材料

不能把调用者能看到的一切都复制进仓库。Task 决定 Agent 获得什么，manifest 证明实际给了
什么：

```text
task_id, workspace_id, created_at
run_id, owner_id, work_unit_id, attempt_id
source repository + commit / gitlink
artifact source + digest + destination + access mode
generated task package + profile version
effective instruction files and scope
excluded material + reason
secret references (never values)
initial commit
writable roots + output namespace
publication target + integrator
```

材料在 sandbox 内可见不自动构成使用授权；有效权限仍由 Task、Profile、工具策略和批准共同
决定。上一 Task 的仓库不得在未重新受理、授权和物化的情况下复用给下一 Task。

### 4.4 物化门禁

首个 Agent Attempt 启动前必须证明：

- Task 契约已可靠持久化；
- workspace 唯一归属本 Task，路径、配额和回收策略明确；
- source ref、Artifact 摘要、commit 和 gitlink 可取得；
- 初始 `git status` 符合 Profile，预置脏文件均有解释；
- 指令范围可由目录层级确定；
- 凭据、越权数据和无关材料未进入版本库；
- manifest 与实际文件一致；
- Agent 的工具、权限和预算不超过 Task 授权。
- owner、独占可写根、候选产出位置和唯一 integrator 已明确；
- 共享发布面为只读，除非当前 Attempt 正是获准的整合 Attempt。

失败时不得把半成品仓库交给 Agent“尽量执行”。重试复用 Task 身份但建立新 Attempt，并隔离
或安全清理残留 workspace。

### 4.5 执行层路线：租用 loop，自建业务控制面

**先钉住现状：生产环境里现在没有任何 agent 在跑。**本节全部结论按 §5.2 的四级能力词典
一律处于 `defined`，不是 `wired`，更不是 `runtime-verified`。可复核的登记表在
`investment-backend/app/tests/test_dormant_capabilities.py`——它按「锚点还在吗 +
还休眠着吗」两个方向立判据，比 grep 计数稳：`:154` `RunBudget` 生产未接线、
`:182` Attempt/Invocation 未落库、`:208` `CancelRunCommand` 无 HTTP 端点、
`:240` `AgentProfile` 只被记录不被执行。开关侧
`AGENT_V4_TRAFFIC_ENABLED` 与 `AGENT_PILOT_ENABLED` 在 bundle 里都是 `'false'`
（`00-prerequisites.yaml:111-112`）。**读本节任何一条时都要带着这个前提**，
不得把目标态写成现状。

“自研还是租用”是假二分。真正的边界是：Investment 自研 Task/Attempt、路由、授权、预算、
四本账、验收、Delivery 与恢复控制面；通过官方 SDK 租用模型 loop、工具循环和执行 runtime。
执行器的 Thread/Session 只是 opaque binding，不是业务主档。该边界落实
[`../constraints.md`](../constraints.md) A1–A5、D1、T2/T3，并锚定 `F-DISPATCH-*`、
`F-EXEC-*`、`F-ACCEPT-*`、`I3`、`I9`–`I15`。

判断“新体系更好”必须分三层：

| 层 | 判定 |
| --- | --- |
| 架构方向 | 更合理：停止重复建设通用 loop，把投入移回业务控制与专业证据；专业能力以 Profile/插件组合，不 fork runtime |
| 当前生产成熟度 | ⚠ 尚未更好：唯一 Task/Attempt 内核、两条执行腿的部署门禁和 Harness wire 门禁尚无运行证据 |
| 门禁后的目标态 | 有条件更好：只有唯一业务主档、能力不对称显式化、故障注入通过、结果经独立 validator、旧链可回滚时才成立 |

任何“SDK 返回完成即 Task 成功”、新增第三条状态链、把执行器本地状态当恢复真源，都会使新体系
反而更差。验收至少映射 `AT-09`–`AT-15`、`AT-20`、`AT-21`；未有这些证据前只能称目标态。

**“更好”必须写成可证伪的条款，否则它只是偏好。**下面三条是 Gate 0 spike 的退出标准，
**⚠ 三条都未经实证，是待验条件、不是既成事实**：

| # | 硬条件 | 不成立时 |
| --- | --- | --- |
| 1 | 两条腿的事件流能忠实投影进我们的 Event/timeline（`I4`、`F-EXEC-02`），词汇表映射不丢关键归属 | 该腿不得接入产品链路，先补上游或换腿 |
| 2 | 专业腿（Harness `submit_result` + preset）在金标准上不劣于对照组（Codex 单腿 + `output_schema`） | 专业路线改回 Codex 腿，保留 Port 不变 |
| 3 | Harness 进程模型在 Celery worker 内稳定：启动失败率、常驻内存、僵尸进程三项达阈值 | 该腿只在独立运行角色内使用，不进 worker |

**失败时的退路是换公开 SDK 路线或走约束变更流程，不是退回自研 loop。**
自建通用 loop 与 `development-plan.md` 的执行层租用方向冲突，且本仓 `ToolExecutionPort`
生产引用为 0——从未存在过可退回的自研执行体系。

**并非所有执行都该进租来的循环。**已经能画出边界的“熟路”（问数主链一类，输入输出与
失败形态都已知）编排权留在我们的控制面，由确定性代码走；租用的是“生路”——
需要模型在工具之间自己找路的那部分。把熟路也塞进聊天循环，等于为已知流程付一次
不可解释的代价，且与 §9.1「上层必须确定性代码」冲突。

### 4.6 两个官方 SDK：两个轴、非对称能力

以下事实固定在核对提交 Codex `7d6f808b97e424da80271be8cc539e8c5437a229`、
DeepSeek Harness `dd6322d604e00eec1ba5e0c8541159906a21094a`。升级钉版时必须重跑锚点，
不能沿用本表结论。

| 轴/能力 | Codex Python SDK | DeepSeek Harness Python SDK | 开发结论 |
| --- | --- | --- | --- |
| 专业 Agent 组装 | 进程级配置为主，无 preset 一等概念 | preset 是一目录一 `agent.cordis.yml`，按会话组合 tools/prompt/skills/persona；一进程可跑多种 agent（`~/repo/deepseek-harness/packages/preset/README.md:10-12`） | Harness 适合专用 Agent；这不表示其生产控制面已合格，锚定 A1 |
| 生命周期 | thread start/resume/list/read/fork/archive（`~/repo/codex/sdk/python/src/openai_codex/client.py:430-469`），turn interrupt（同文件 `:641-646`） | wire 只有 initialize、session/prompt、shutdown；事件对 runtime 全量且未过滤（`~/repo/deepseek-harness/packages/sdk/protocol/README.md:34-52`） | Port 必须表达缺失，锚定 `F-EXEC-02/05`、`F-INTERACT-*` |
| 逐 Turn 结果 | run/turn 有 turn id、流与 `output_schema`（`~/repo/codex/sdk/python/src/openai_codex/api.py:544-609`） | prompt receipt 的 messageId 不标识 assistant result/turn end（protocol README `:50-52`） | Harness 当前缺完成归属，不能伪装 `COMPLETED` |
| 取消/关闭 | 有 turn interrupt；thread 可 archive | 无 cancel、无 session-close，客户端只能关闭 runtime 进程（protocol README `:107-116`） | Harness 当前只能用进程级补法，代价写入 Attempt |
| 交互批准 | 可由 approval handler 接请求，但默认自动接受命令与文件修改（`client.py:773-779`） | server→client request 是死能力（protocol README `:114-116`） | Codex headless 必须覆盖默认 handler；Harness 不得声称原生 HITL |
| provider 协议 | Codex 已钉死 Responses API，`wire_api="chat"` 明确报错（`~/repo/codex/codex-rs/model-provider-info/src/lib.rs:57-88`） | 面向 DeepSeek 等自身 adapter 路线 | DeepSeek Chat Completions 经 Codex 需另建翻译代理，是真实阻抗，不能当无成本替代 |
| 系统 Node | 不适用 | wheel 携闭包，SDK 不需系统 Node；repo-only carrier 才需 Node 且不会自动选（`~/repo/deepseek-harness/python/sdk-runtime/README.md:5-15`） | ⚠ 只剩内网 PyPI 能否取得 wheel 未验证；不得复活“缺 Node 阻断” |

专业构建能力与生产控制能力是两个独立轴：前者为“已核实可用”，后者在 Harness 腿仍为门禁。
工具可通过插件注册，参数/输出校验与 policy hook 见
`~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:7-59`；这支持“不 fork agent loop”，
不证明多租户授权、取消和恢复已接线。

### 4.7 统一执行 Port 与三态能力探针

application 层只依赖中性 Port；签名不得出现 ticker、portfolio、财报等领域词（A4/A5）：

```python
class AgentExecutorPort(Protocol):
    async def capabilities(self) -> ExecutorCapabilities: ...
    async def start(self, request: ExecutionRequest) -> ExecutionBinding: ...
    async def resume(self, binding: ExecutionBinding, value: ExecutionInput) -> None: ...
    async def cancel(self, binding: ExecutionBinding, reason: CancelReason) -> CancelReceipt: ...
    async def events(
        self, binding: ExecutionBinding, cursor: ExecutionCursor | None
    ) -> AsyncIterator[ExecutionEvent]: ...
    async def inspect(self, binding: ExecutionBinding) -> ExecutionSnapshot: ...
    async def close(self, binding: ExecutionBinding) -> None: ...
    async def submit_result(
        self, binding: ExecutionBinding, payload: ResultEnvelope
    ) -> SubmissionReceipt: ...
```

**`submit_result` 在签名里，不是 Adapter 私货。**结果必须经一个显式提交动作进入平台，
未提交不算 Attempt 完成，且提交成功只产生**候选**——validator 说了才算。它同时是
Harness 腿门禁未过期间的过渡补法所依赖的原语（§4.8），放进 Adapter 内部会让两条腿
在“什么算完成”上出现两套语义。**注意：Harness SDK 当前并不存在这个方法**，
它是我们自建的约定，不是租来的能力。

`capabilities()` 的三态结果同样是签名的一部分——调度要在 dispatch 前读它做硬过滤，
不能等 Adapter 内部临场降级。

**Port 存在的第一理由是可测性，不是“将来可能换执行器”。**有了它，纪律层可以用
`FakeAgentWorker` 跑完整状态机、超时、取消与恢复路径，不必每次都真起 runtime、
真发凭据、真花模型钱；`CodexAgentWorker` 与 `HarnessAgentWorker` 只在集成层出现。
“将来可能换”是收益，可测性是**现在就成立**的理由——本仓 `ToolExecutionPort` 生产
引用为 0，正说明没有可测载体时，Port 会停在 `defined`。

`ExecutionBinding` 必须可序列化并落 PostgreSQL：**SDK 侧的 thread/session id 不是
Task 的真源**（`I13`），进程重启后要能只读持久载体接着做。具体字段在实施时由契约测试
钉死，本文不列字段表（§4.10）。

通用 DTO 只承载 `attempt_id`、版本化 `profile_ref`、workspace/input Artifact 引用、完成合同引用、
预算预留引用、trusted security context 引用、deadline，以及 opaque provider session/turn identity；
不复制 `request-lifecycle.md` 的对象定义。Adapter 只做公开 SDK 映射、binding 持久化、事件归一、
错误码归一与 teardown；它不路由、不授权、不验收、不拥有四本账或 Task 终态。

每项能力不是布尔值，而是：

| 状态 | 含义 | 调度规则 |
| --- | --- | --- |
| `available` | 钉版 SDK 与 runtime 已证明原生保真支持 | 仍须经过 Attempt 准入 |
| `explicit_unsupported` | SDK 明确不支持且不得降级 | fail-closed；换路线必须新建 RouteDecision/Attempt |
| `implicit_fallback` | 可用替代语义但会损失能力或改变边界 | 只有冻结政策明确允许且代价落账才可用；不得静默 |

探针必须带 runtime/SDK 版本、证据与探测时间；dispatch 以所需能力集合做硬过滤，满足
`F-EXEC-01`、`I3`、`I15`。布尔 `true/false` 会把“明确不支持”和“悄悄降级”压成同一种事实，
无法证明 `AT-09`、`AT-14` 与 `AT-20`。

### 4.8 Harness SDK 前置门禁与过渡补法

门禁卡的是“Investment 状态机能否管住 Harness”，不是“能否用 Harness 建专业 Agent”。专业腿
进入自动路由前，必须由 Harness 上游在正式 SDK 同步实现并测试以下公开合同；Investment 不得
复制协议类型、deep import 内部包或维护私有 wire fork（A4）：

- session start/resume/read/close、按 cursor 读取 session events；
- turn start/read/steer/cancel、stable turn id、逐 Turn completion correlation；
- per-session preset 选择与逐 Turn 结构化输出合同；
- 模型不可见、不可改的 trusted context：Task/Attempt、tenant/actor、authorization policy
  version、allowed capabilities、dataset bindings、evidence policy、deadline；
- async/已证明不阻塞的 Python 面、cancel durable end、crash/restart/malformed-wire 测试及版本化
  capability query。

现 wire 的缺口可由 protocol README `:34-52,107-124` 复核。门禁验收映射
`F-EXEC-02/03/05`、`F-INTERACT-01/02`、`I3`、`I5`、`I12`、`I14`、
`AT-05`、`AT-07`、`AT-09`、`AT-14`、`AT-15`。

门禁未过时只允许显式、受限的过渡路线：

1. 取消时先持久化意图并 revoke Attempt 网关令牌，再按 teardown ladder 杀 runtime 进程；
2. 每个专业 Profile 必须提供显式 `submit_result` 工具；未调用不算 Attempt `COMPLETED`，调用成功
   只产生候选，仍由独立 validator 判定 `F-ACCEPT-*`；
3. 高风险工具不交给 runtime 自批，全部经平台工具网关按审批分层决定；
4. 等待/恢复创建新 Attempt，从持久 Artifact 和现场快照恢复，不伪造原 Session 续跑。

代价必须落账：进程级取消粒度粗、上下文重建耗时、可能丢失未提交中间推理、重复计算增加预算，
且不能原地 resume。能力探针对相关项标 `implicit_fallback`，不得标 `available`。若完成合同需要
保真的原 Attempt 恢复或逐 Turn HITL，则专业路线保持 `explicit_unsupported`。

### 4.9 双 runtime 的部署、进程与恢复

先按运行角色分 API、通用执行 worker、专业执行 worker；是否拆 Deployment 仍服从 T3 的证据门槛，
不是新建领域 Backend。两类 worker 使用互斥服务身份、队列、网络与凭据，不能在同一进程内把
两套 key 都做成环境变量。

当前部署有四条硬阻断，均是 `defined` 以下的现状，不是建议：

| 阻断 | 可复跑锚点 | 必须补的门禁 |
| --- | --- | --- |
| worker 无模型 API egress | `sunmoonai/app-platform/investment-app/deployment/bundle/30-network-policies.yaml:221-268` 只放 PostgreSQL/Redis/RabbitMQ、Casdoor、Knowledge；`rg -n 'ipBlock' sunmoonai/app-platform/investment-app/deployment/bundle/30-network-policies.yaml` 零命中 | 精确目的地/代理 egress；Calico 环境实际验证，锚定 `I3/I12`、AT-05 |
| root filesystem 只读 | `sunmoonai/app-platform/investment-app/deployment/bundle/20-runtime.yaml:361-373` | `CODEX_HOME`、`DSH_HOME`、workspace、snapshot staging 分离到有配额的可写卷，锚定 §4.4、`F-EXEC-05` |
| worker 内存上限 768Mi | `sunmoonai/app-platform/investment-app/deployment/bundle/20-runtime.yaml:354-373` | 双 runtime 峰值与 prefork 并发实测后定 requests/limits，锚定 `F-DISPATCH-03`、`F-EXEC-04` |
| 模型配置/凭据未进 bundle | `sunmoonai/app-platform/investment-app/deployment/bundle/00-prerequisites.yaml:106-119` 且 `rg -n 'AGENT_PILOT_LLM_' sunmoonai/app-platform/investment-app/deployment/bundle` 零命中 | 代理 endpoint、短 TTL token issuer、Secret/ServiceAccount 与启动 fail-closed，锚定 constraints I8、产品 I12 |

⚠ **KIND 默认不执行 NetworkPolicy。**上表第一条阻断的“包级验证”只在生产 Calico 下成立；
在开发用的 KIND 集群里策略写了也不生效，必须另起 Calico 才能验，否则会误以为出口已经封死。

**这条进程纪律有死者，不是设计洁癖。**Celery worker 默认 prefork 数继承节点 CPU，
本仓曾因此起了 12 个子进程直接打爆 768Mi 上限；模板已把并发钉成
`CELERY_WORKER_CONCURRENCY: '2'`（`00-prerequisites.yaml:109`，进程池锚点
`20-runtime.yaml:283-284`）。在这个内存上限下再往每个子进程里塞一个 SDK runtime，
是同一个坑的第二次。

SDK 进程纪律：Celery prefork **之后**按 Attempt 或受控槽创建 SDK client/runtime；不得在 parent
初始化后跨 fork 共享 fd、锁、event loop 或子进程句柄；owner 记录 PID/进程组与 binding。关闭按
`stop intake → revoke token → SDK cancel/close → 限时 TERM 进程组 → 限时 KILL → reap →
核对副作用账`，每步写证据。Codex async 客户端内部把同步调用包装到 worker thread
（`~/repo/codex/sdk/python/src/openai_codex/async_client.py:161-183,293-295`），并发与 teardown
必须做负载/故障注入，不能由 `async` 关键字推断安全。两条腿的关闭梯子分别锚到各自 SDK：
Harness 侧 `close → terminate → kill` 见 `~/repo/deepseek-harness/python/sdk/…/client.py:94/117/124`；
Codex 侧无 per-turn cancel 之外的进程级梯子，只能落到进程组 TERM/KILL。

可恢复执行现场按 `attempt_id + runtime_version + profile_version + digest` 内容寻址写对象存储，
至少包含工作区差异/未提交文件、固定 commit、输入输出 Artifact 引用、opaque binding、事件 cursor、
checkpoint 与副作用/证据引用；对象存储遵守 D4，PostgreSQL 只存引用与摘要。restore 在新可写面
校验摘要、授权、fencing、runtime/Profile 兼容性后继续；不把 executor 本地目录当真源。

恢复必须有界：Profile 固定 `max_attempts`；同一 `failure_fingerprint + profile_version +
runtime_version` 连续失败达到阈值就熔断该版本路线，停止自动恢复并进入 Interaction/人工处置。
Profile 升级不得替历史 Task 静默解锁；恢复验证映射 `F-EXEC-05`、`I5`、`I9`、`I10`、`I14`、
`AT-09`、`AT-12`、`AT-15`、`AT-20`。

### 4.10 专用 Agent 的构建方法，不冻结具体 Profile

对任一专用 Profile，只固定方法：Profile/patch + 插件组合，不 fork runtime、不改 agent loop；每个
工具逐条声明输入/输出 schema、数据与副作用安全边界；dry-plan 只产生可审计 Plan Artifact，query
才执行；结果经显式 `submit_result` 提交，未提交不算 Attempt 完成，提交只产生候选；validator
通过 `F-ACCEPT-*` 后 Task 才可成功；两条 worker 凭据互斥。dsh 插件工具的 canonical JSON、
取消 signal 与 policy hook 锚点见 `adding-a-tool.md:40-59`。

本文不冻结某个财务 Profile 的字段、工具清单、数据集或金标准：`request-lifecycle.md` §7.2 要求
首项工作以真实输入确认契约，而当前业务数据源仍为空
（`sunmoonai/docs/dev-plan/development-plan.md:110-122`）；先做财务数据源与 Gate 0 spike，再在下游
决定建一个窄 Profile 还是多个角色。未有真实数据和评测前，任何具体表都是 ⚠ 假设而非纪律。

### 4.11 OpenClaw Gateway：借机制，不转向

核对提交为 OpenClaw `173f41d682b0d4a05674820a3d390d934da8b066`。它的 Gateway 是渠道接入、
会话与控制面，不是 Investment 的财务/通用语义分类器。两层所谓“路由”分别是：

1. channel/account/peer/guild/team binding 确定性映射 agent，并返回 `matchedBy` 与 `sessionKey`
   （`~/repo/openclaw/src/routing/resolve-route.ts:57-80,745-793`）；
2. 已准备的 provider/model route 选择 agent runtime，显式 plugin runtime 默认 fail-closed，除非
   plugin 声明无损 fallback（`~/repo/openclaw/src/agents/harness/selection.ts:102-124,221-260`）。

两层都不读取用户语义来决定专业领域。可借机制及本项目落点：

| 借鉴机制 | Investment 落点 | 合同锚点 |
| --- | --- | --- |
| 确定性 binding、优先级、`matchedBy` | RouteDecision 保存命中规则、候选和拒绝 reason code | `F-DISPATCH-03`、I15 |
| agent/session/runtime/model 正交 | Task Profile、Agent Profile、executor binding 分开 | I1、I13、AT-20 |
| capability support + 显式路线 fail-closed | §4.7 三态探针；换 runtime 建新 Attempt | `F-EXEC-01`、I5、I14 |
| host 先准备上下文，runtime 只跑 loop | Attempt Admission 固定权限、预算、workspace、fencing | `F-EXEC-01/03/04`、I3/I10 |
| 来源路由与回复交付分离 | requester/Delivery 不随 executor 改变 | I7、`F-DELIVERY-*` |

不整体转向的理由：OpenClaw 明确“一 Gateway 一信任域”、多租户靠每租户一个仍属实验性的 cell
（`~/repo/openclaw/docs/start/why-openclaw.md:121-149`），其主档是全局及 per-agent SQLite，
不是本项目共享 PostgreSQL 业务主档；项目本身是 TypeScript/Node CLI
（`~/repo/openclaw/package.json:1-23`）。它不提供本项目的多租户 Task/Attempt、四本账与验收合同；
引入会重复现有 Next.js/FastAPI/Celery/Delivery 控制面，技术栈与运维面也扩大。其危险默认不能继承：sandbox 默认关闭
（`~/repo/openclaw/docs/gateway/sandboxing.md:9-23`），`tools.profile: full` 等于无限制
（`docs/gateway/config-tools.md:15-30`），`/elevated full` 可跳过 exec approval
（`docs/gateway/sandbox-vs-tool-policy-vs-elevated.md:121-137`）。OpenClaw 自身也拒绝重复既有 agent/
tool 基础设施的重编排层（`~/repo/openclaw/VISION.md:129-142`）。

因此明确不借：Gateway 作为业务主档、channel binding 冒充语义路由、本地会话存储取代
PostgreSQL、默认 host 执行、`tools.profile: full`、`elevated`/`full` 逃生门、运行中静默跨 runtime
重放，以及把 Gateway 放在 BFF 与 FastAPI 之间。若未来只接新聊天渠道，可把它作为受限 adapter
提交标准 Task；仍需走 C1/C2、I3/I5、A3/A4 与统一 Port。

## 5. Agent 执行内核

### 5.1 冷启动核对

每次 Attempt 先核对：

1. Task/Attempt ID、租约、fencing、预算和停止条件；
2. 原始请求、范围、验收、批准点和预期 Artifact；
3. 当前目录、仓库根、分支、HEAD、子模块和工作树状态；
4. manifest 的输入、摘要、基线和实际文件；
5. 生效的 `AGENTS.md` 和目标代码附近测试；
6. 依赖、权限和外部系统是否仍有效；
7. 哪些判断是事实、推断、假设、缺失或尚未验证。

不匹配会改变结果时停止并发起 Interaction；不得在错误仓库、错误分支、过期 commit 或失效
租约上继续。

**写入前门禁（一票否决）。**动手写任何文件之前，逐条核对，任一不成立则**停，不写任何文件**，
报 supervisor：

1. `cwd == workspace_path`；
2. 当前分支 `== exclusive_branch`；
3. 目标路径不在 `forbidden_write_paths` 内，且解析软链、`..` 和挂载别名后的规范路径仍落在
   获准的 writable root 内；
4. 目标路径上没有他人产物；若有，不覆盖——先让对方的内容形成可达 commit 或备份；
5. 本次不是宽泛写入（批量生成、`>` 重定向、脚本 sweep、先 `rm -rf` 后重建）；确需宽泛写入
   时收窄到明确路径逐个执行。

这五条不是建议。**宽泛写入和「路径归属不明仍继续写」是覆盖事故的两个主因**，两者都发生在
写入前，事后恢复（§7.8）代价远高于停一次。

### 5.2 上下文路由

| 改动面 | 必须追加核对 |
| --- | --- |
| 项目总体边界 | overall architecture、`constraints.md` |
| Task/Attempt/Interaction/Delivery | `request-lifecycle.md`、生产代码与对应测试 |
| Agent runtime、恢复、预算、事件、副作用 | 当前事实文档、生产链代码和测试 |
| 跨 App 契约 | provider schema、consumer lock 和双端契约测试 |
| Admin/Web/API | 目标目录 `AGENTS.md`、认证边界和端到端测试 |
| 数据模型或迁移 | 迁移链、数据库约束、前滚/回滚和数据不变量 |
| K8s 或发布 | bundle、release、部署引用与运行门禁 |
| Git、远端或子模块 | 现行协作规范、各仓 HEAD 和 gitlink |

历史 baseline、候选和聊天记录只作线索；当前实现断言必须回到代码、测试或运行结果取证。

**本项目（Investment App）的范围门禁。**上表是通用路由，已覆盖跨 App 契约、Admin/Web/API、
数据模型与迁移、K8s 与发布、跨仓与子模块各面。本文**不复制项目实现，也不铺项目清单**——
易变的当前事实只放
[`project-guide/repos/investment-app.md`](../../project-guide/repos/investment-app.md)，那里改了
本文不必跟着改。本文只固定三条不随实现变动的路由：

1. **改动涉及 Investment App 时**，除上表外追加读取该仓的项目指南、生产链代码和相关测试；
   不得由历史设计稿或旧快照推断现状。
2. **陈述任何能力状态时只用四级词典**——`defined / wired / deployable / runtime-verified`
   （见 [`project-guide/overall-architecture.md`](../../project-guide/overall-architecture.md)
   §8.2）。类、DTO、迁移或测试夹具存在，都不等于生产链已经接线；执行者不得自行发明
   「已实现」的判断口径。
3. **涉及已知休眠能力时回跑 dormant 测试**——
   [`project-guide/repos/investment-app.md`](../../project-guide/repos/investment-app.md) §7
   指向的 `tests/test_dormant_capabilities.py`，同时确认锚点仍在且能力仍未接线。

第 1 条给入口，第 2 条给词汇，第 3 条给可运行的验证动作；三者都不随某一次实现变动而失效。

### 5.3 共同纪律

单路 Agent 和 Agent supervisor 都必须：

1. 不用计划覆盖原始请求；
2. 只在范围、工具、数据、预算和副作用边界内行动；
3. 区分事实、推断、假设、缺失和未运行验证的结论；
4. 对可中断工作持久化 checkpoint；
5. 无法满足完成契约时请求输入或明确失败；
6. 在最终固定版本上运行与风险相称的验证；
7. 报告盲区、副作用和残余风险；
8. 未经授权不推送、合并、发布、删除远端资产或扩大外部影响。

### 5.4 单路实施

```text
固定 initial commit
  → 实施
  → 作者自检
  → 固定 candidate commit
  → 独立验收
  → 处置问题
  → final commit 回归
```

作者自检不能代替独立验收。没有第二 Agent 时，由独立验收器或人验收；验收方只能按冻结
标准判定，不能为了通过而静默修改标准。

### 5.5 Checkpoint 与恢复

跨会话、可能取消或产生副作用的工作必须写：

```text
task_id, attempt_id, workspace_id, current_commit
run_id, work_unit_id, owner_id
completed_scope, remaining_scope
decisions + evidence refs
commands/tests + raw output refs
budget consumed / remaining
side effects + idempotency refs
output namespace + publication target + integrator
blocker, next action
facts to revalidate
```

Git 不承担 Task 状态、预算、授权、Interaction 或副作用账。恢复必须重验 Task、租约/fencing、
权限、基线、依赖和副作用；不得根据旧会话无条件续跑或重复已记账动作。

**checkpoint 写哪、谁写共享交接面。**执行者的 checkpoint 写进**自己的 worktree**；
共享的单写者面——[`../handoff.md`](../handoff.md)、实现矩阵的权威行——**只有 supervisor
或主驾驶写**，由它把各执行者的 checkpoint 投影上去。共享单写者面的判据不是「内容重要」，
而是「同一事实只能有一个权威写入者」（§7.1）：多个执行者各自向同一份 handoff 追加进度，
就是在共享路径上并发写，会互相覆盖并让交接游标失真。

判据一句话：**把当前会话杀掉，另一个执行者只读持久载体能否接着做？**不能，就是没落盘。
checkpoint 是恢复输入，不是第二份代码真源，也不保存凭据。

### 5.6 失败、澄清与改判

- 完成契约不可满足时明确失败，不伪造完整结果；
- 改变结果、权限、成本或不可逆风险的缺失必须发起 Interaction；
- 改判追加触发、原判断错处和新判断，旧判断不删除；
- 验收标准腐坏时保留原标准、失败输出和批准记录；
- 目标态进入事实文档前重新从代码或实物取证。

## 6. Attempt 内的执行监督 Agent

### 6.1 展开条件

当前 Agent 需要拆 Work Unit、向其他执行者派活、收集候选、选主线或整合时，就成为
**执行监督 Agent**。fan-out 是已路由 Attempt 内完成同一 Task 的开发方式，不是 §0.3 的
调度监督器，不是额外上级，也不是用户结果。

| 形态 | 适用条件 |
| --- | --- |
| 单路实施 | 解法明确、局部、可被测试充分判定 |
| 定向审核 | 已有唯一产物，只需独立判断 |
| 最小选优 | 需要独立候选，但无需完整评审团 |
| 完整选优 | 解法不明确、跨层/跨仓、错误代价高 |
| 胜者改进 | 主线已选，只吸收独立局部优点 |

执行监督 Agent 可选执行形态，不能改动上层 RouteDecision、降低硬门禁、换执行器、扩大权限
或增加总预算。

### 6.2 Work Unit 契约

```text
work_unit_id, parent_task_id, owner
objective, included_scope, excluded_scope
input_refs, baseline_commits, allowed_context
expected_output, acceptance, evidence
permissions, budget, deadline, stop_condition
dependencies
workspace_path, exclusive_branch, forbidden_write_paths
checkpoint_location
output_namespace, publication_target, integrator
result_status
```

`workspace_path` 和 `exclusive_branch` 必须在派工时写死，且对每个执行者唯一。
`forbidden_write_paths` 至少包括：人的主 checkout、其他执行者的 worktree、共享发布面，
以及非 supervisor 不得写的单写者文件（如 `handoff.md`）。这三个字段不是描述性说明，
是 §5.1 写入前门禁的判定输入——派工时缺任一字段，执行者不得开始写。

派工只能收窄父 Task。父预算覆盖所有 Work Unit、Attempt、工具、评审和改进。多个 Work Unit
不得同时权威写同一可变事实；先划分所有权，无法划分则串行。

### 6.3 建立 worktree

Agent 路径的根仓由后端物化，后续 worktree 由 Agent supervisor 建立；Human 路径由人建立
根仓、初始及后续 worktree。进入并行执行后规则相同：

- 每个并行单元独立分支、独立可写 worktree；
- 候选从同一冻结 commit 开始；
- 同一分支不能被两个 worktree 同时检出；
- worktree 只隔离写入，不阻止读取共享 Git 对象，隔离强度要说明；
- 多仓单元固定每仓 commit 和父仓 gitlink；
- 租约、凭据和产品状态不得提交进分支；
- 建立、归属、基线和清理状态进入 manifest；
- 删除 worktree 不等于删除证据，commit 必须可达。
- `master/main` 和其他共享分支默认不是候选写入面；
- 即使候选修改同一相对文件，也各自在自己的分支/worktree 修改；
- 只有 integrator 在独占整合 worktree 中写最终路径并形成 final commit。

### 6.4 候选隔离

候选冻结前只读同一 Task 包、基线和各自获准上下文，不得读其他候选、发起方偏好或预设
解法。看到已有答案后的内容属于评审或改进，不再是独立候选。

候选绑定不可变 commit，并声明覆盖/未覆盖范围、各仓 commit/gitlink、验证原始输出、假设、
盲区、缺陷、副作用和关键主张证据。

需要脚本化产生候选时使用 [`../parallel-proposals.py`](../parallel-proposals.py)。
**它的验证边界要如实标注**：已验证的是独立进程、独立 `CODEX_HOME`、失败隔离与 manifest
写入；真实模型调用尚未在本项目端到端验证。脚本存在不等于流程已经可用，不得据此声称
隔离由机制保证。

### 6.5 角色分离

| 角色 | 职责 | 禁止事项 |
| --- | --- | --- |
| supervisor | 冻结、分配工作区、收集结果、停止其他执行 | 泄露候选、临时改规则 |
| 候选方 | 独立调查、实施、自检、固定 commit | 偷看候选、决定自己胜出 |
| 验收方 | 统一环境运行硬门禁 | 因身份或文案放宽标准 |
| 评审方 | 审查主张、证据、风险和偏好 | 独立审前读取其他评审 |
| 决策方 | 在合格候选中选主线 | 参加本轮候选 |
| 整合方 | 从选定 commit 处置改进 | 默认接受优胜作者自评 |

角色可跨轮次更换，也可兼任无利益冲突职责；候选作者不得成为自己候选的最终决策方。角色
不足时缩小流程或请有权人裁决，不用候选互投制造独立性。

### 6.6 评审、裁决和选优

评审分两阶段：先只读原始请求、匿名 commit 和统一标准独立审；冻结后再读候选自评、盲区
和验证记录对照审。评审必须写明 commit、覆盖范围、阻断问题、证据，以及哪些结论运行过。

先裁决事实：

| 主张 ID | 候选 commit | 证据/命令 | 结论 | 理由 |
| --- | --- | --- | --- | --- |
| `<ID>` | `<commit>` | `<位置/输出>` | 证实 / 证伪 / 未决 | `<说明>` |

测试失败、违反硬约束/范围、存在阻断风险、commit/证据不可取得或隔离不可恢复的候选，不进入
偏好评分。全体一致不是免检理由。只有合格候选间才比较维护成本、结构和命名；维度和权重
在候选前冻结，结果称“本轮选定”，不称“已证明正确”。

### 6.7 改进、整合和回归

选定 commit 冻结为只读基线。局部改进从它建新 worktree，一条独立主张一个提交；整体重写
或耦合改动作为新候选重开。

整合方逐项记录接受、部分接受或拒绝及证据。冲突按原始请求、约束和证据解决，不按票数、
作者或提交时间覆盖。所有有效门禁必须在 **final commit** 重跑，候选的绿色结果不能证明
整合结果正确。

### 6.8 停止规则

- 使用足以产生独立信号的最少候选；
- 顶层验收满足后，其余在途单元停止、取消或降为无副作用只读参考；
- 连续一轮没有关闭阻断问题或新增可验证价值时停止；
- 达到轮次上限仍有结构分歧时，请有权人裁决或重开 Task；
- 单元耗尽预算不得静默借用；
- supervisor 退出前留下可恢复 checkpoint。

“已派工”“全部返回”或“多数一致”都不等于 Task 完成。

### 6.9 内层的三条硬禁令

执行监督 Agent 在上层已经路由完、权限已收窄之后才存在（§0.3）。抽象声明容易被绕过，
下面三条是它在 Attempt 内的可执行边界，任一条被突破即为越权，按 `I3`、`I10`、`I15`
与 [`../constraints.md`](../constraints.md) A2/A4 处理：

| # | 禁令 | 具体形态 |
| --- | --- | --- |
| 1 | **不得改路由** | 执行器种类在 Attempt 创建时钉死并落账；不得因为“这个 Work Unit 更像财务”而在 Attempt 内改投另一条腿 |
| 2 | **不得换执行器** | 不得在 Attempt 内自行构造新的 runtime 客户端实例绕开已固定的 Adapter；换腿只能由上层新建 Attempt |
| 3 | **不得扩权** | 不得重新注册已被 deny 的工具，不得把 `human-approval` 降级为执行器默认的自动批准，不得追加预算 |

第 3 条的现实动因见 §4.6：Codex Python SDK 的默认审批处理器对命令执行与文件改动一律
返回 accept，且该兜底发生在构造函数里——**“忘了传 handler”与“故意选自动批准”
在代码里长得一样**，所以这条必须由 Adapter 强制显式传入，不能靠纪律。

## 7. 产出物与 commit 的全生命周期

### 7.1 先确定身份、所有权和发布权

任何可写动作开始前，supervisor 必须为执行面分配稳定身份：

```text
task_id
run_id
attempt_id
work_unit_id
owner_id
workspace_id / worktree_id
baseline_commit
output_namespace
publication_target
integrator_id
```

`owner_id` 表示谁可以写候选空间；`integrator_id` 表示谁可以写发布目标。两者可以在单路任务
中是同一个执行者，但必须显式指定，不能因为某人先打开文件就获得所有权。一个发布目标在
同一集成轮次只能有一个 writer；多个候选可以拥有相同**相对路径**，前提是它们位于不同的
branch/worktree，而不是同一物理文件。

### 7.2 命名空间

推荐的逻辑命名如下；实际路径可由平台实现调整，但隔离维度不能丢：

```text
branch:    task/<task-id>/<owner-id>/<work-unit-id>
worktree:  <sandbox>/worktrees/<owner-id>/<work-unit-id>/
artifact:  <artifact-store>/<task-id>/<work-unit-id>/<attempt-id>/<name>
evidence:  <artifact-store>/<task-id>/<attempt-id>/evidence/<name>
integrate: task/<task-id>/integrate/<run-id>
```

若工具限制导致多个执行者只能共享一个工作树，所有草稿必须写入明确的 owner namespace，
例如 `.work/<task-id>/<owner-id>/...`；共享最终路径保持只读。共享工作树只是降级方案，不能
声称具备 worktree 级隔离。平台若连 owner namespace 都无法保证，任务必须串行。

**本仓当前的具体落点**（Human 路径，多助手并行时同样适用）：

| | 路径 | 权限 |
| --- | --- | --- |
| 人的主 checkout | `~/master/<仓>` | **只读**。可以读、可以对照，**不是投稿箱**，也不因为「文档原件在这里」就该写这里 |
| 执行者工作区 | `~/worktrees/<助手>/<仓>` | 该助手唯一的可写面；提交到自己的命名分支 |
| 整合面 | 整合方自己的 worktree 上的 `integrate/<run-id>` 分支 | 只有 integrator 写；源是选定 commit，不是任何人的工作区文件 |

「一仓一个默认工作区」不够多执行者用。同一 Task 出现第二名可写执行者时，supervisor
必须先建好各自的 worktree 和命名分支再派活，不往默认工作区加写者。

### 7.3 产出物分类与载体

不同产出物不能统一用“都 commit”或“都放聊天里”处理：

| 类型 | 例子 | 权威载体 | 处置 |
| --- | --- | --- | --- |
| 源码和受控文档 | `.py`、迁移、Markdown | owner branch 的 Git commit | 候选冻结后由 integrator 选择性整合 |
| 未跟踪草稿 | 临时提案、尚未纳入版本的文档 | owner namespace，尽快形成 commit/Artifact | 不得放共享最终路径；未冻结不参与选优 |
| 可再生生成物 | build、cache、coverage 临时文件 | 构建系统，不作为真源 | 用独占输出目录；通常不 commit；按策略清理 |
| 需交付生成物 | bundle、报告、模型、安装包 | 内容寻址 Artifact + 摘要 + provenance | Git 只记录 manifest/摘要，不强塞大文件 |
| 验证证据 | 日志、截图、测试报告、benchmark | 不可变 Artifact/CI 记录 | 关联环境、命令、commit 和摘要 |
| 结构化结果 | JSON、表格、分析结果 | Task Artifact | schema/version 固定；必要时另投影为文件 |
| 敏感临时物 | token、私钥、含隐私原始数据 | 受控 secret/data store | 禁止 commit；最小暴露；到期销毁 |
| 外部副作用 | 数据库写入、发布、消息、交易 | 副作用账和外部回执 | 幂等、可审计、必要时补偿；Git 不是账本 |
| commit/branch/worktree | 候选、整合和运输引用 | Git 对象 + supervisor manifest | commit 是对象；branch 是可变引用；worktree 是临时执行面 |

### 7.4 候选状态机

```text
DRAFT
  → FROZEN(commit/digest)
  → SUBMITTED
  → {SELECTED | REJECTED | STALE | SUPERSEDED}
  → INTEGRATED（仅被采用部分）
  → VERIFIED(final commit)
  → PUBLISHED
  → RETAINED / GARBAGE_COLLECTED
```

- `DRAFT` 可以修改，但只存在于 owner 可写面，不能被称为候选完成；
- `FROZEN` 后不得原地替换，修订产生新 commit/digest，并用 `supersedes` 关联；
- `SELECTED` 只表示进入整合，不表示已经发布；
- `INTEGRATED` 必须记录实际吸收的 commit/patch/Artifact，不能只写“已吸收”；
- `VERIFIED` 只针对 final commit；
- `PUBLISHED` 必须记录发布目标、发布者、版本和时间；
- 清理前必须证明所需对象仍有可达 ref 或已进入持久 Artifact。

### 7.5 未提交文件、commit、分支与 worktree 的不同语义

隔离靠 **worktree + 命名分支**，不靠文件名。`-new`、时间戳、助手名写进文件名，都不能
阻止「同一工作区、同一相对路径」被后写覆盖。不同载体的覆盖语义完全不同：

| 对象 | 覆盖会怎样 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| **未提交工作区文件** | **后写直接覆盖先写：无冲突、无历史、无警告、无作者归属** | 磁盘此刻的内容 | 谁写的、谁先写完、被覆盖前是什么。隔离单位是工作区，不是路径字符串 |
| commit | 新 commit 不摧毁旧对象；旧对象需有 ref 才找得到 | 一组文件内容及父历史不可变 | 谁批准、测试是否通过、外部副作用状态 |
| branch | 指针可被快进、重置、强推；像标签在移动 | 当前指向哪个 commit，便于运输和续接 | 稳定评审对象；分支头会移动 |
| worktree | 一分支只能被一棵 worktree 检出，Git 会拒绝第二处 | 某执行者当前可写目录和所检出分支 | 长期证据；目录可以删除 |
| tag/ref | 可被移动或删除，但所指对象仍在对象库 | 使对象可达并表达冻结点 | 自动构成验收或发布 |
| patch | 应用到不同基线上结果不同 | 可传输的差异 | 完整父基线、未跟踪文件或外部状态 |
| 共享发布面 | 未授权写入等于闯入他人工作区或发布面 | 只有整合后的 final commit 算交付 | 任何未经整合的内容 |

**未提交工作区文件不能作为候选，也不能作为交卷物**：它没有 commit、没有 digest、没有作者
归属，被覆盖后既难恢复也难归因。交卷 = 自己分支上的可达 commit。

候选和评审一律引用完整 commit ID 与基线；不能只给分支名。冻结候选后禁止 force-push
改写其可追溯历史。需要 rebase 时形成新的候选 commit，并保留旧→新的映射。删除 branch、
worktree 或 sandbox 前，supervisor 必须确认仍需保留的 commit 已由持久 ref、获准远端或
Artifact bundle 保持可达；“对象暂时还在 reflog”不是保留策略。

### 7.6 各种并发场景的处置

每行四件事：场景、正确落点、禁止做法、**已发生时怎么收**。恢复列给的是该场景的入口动作，
统一规程见 §7.8；轻量场景走 §7.8 的四步前门，复杂或涉及发布竞争的走完整八步。

| 场景 | 必须怎样做 | 禁止做法 | 已发生时 |
| --- | --- | --- | --- |
| 多 Agent 生成同名文档 | 各自在自己的 branch/worktree 修改相同相对路径；分别 commit | 一起写共享目录的同一个 `.md` | 以 commit 认主，不以磁盘最后一版为准；共享路径上的未提交文件视为污染，移到各自 owner namespace 后比对 digest，声明哪些候选已不独立 |
| 只能共享物理目录 | 用 `owner_id/work_unit_id` 命名空间，最终路径只读；由 integrator 发布 | 用时间先后或“谁最后保存”决定结果 | 停写；把可识别的各版本分流进各自 owner namespace；由 integrator 裁决，不由最后写入者胜出 |
| 单 Agent 单路任务 | 仍固定 owner、baseline 和 candidate commit；获授权后可由同一人整合 | 在脏的共享 `master` 上直接写未跟踪结果 | 把脏工作区里属于本任务的内容迁到自己的分支并 commit；共享工作区恢复为只读 |
| Human 与 Agent 混合 | 人和 Agent 各有独占 worktree；supervisor manifest 统一登记 | 默认人的目录可被 Agent 写，或默认 Agent 分支可被人覆盖 | 助手改动撤出人的工作区；**人的未提交改动优先保留**，助手那份只有存在自己 worktree 才算数 |
| 两个 Work Unit 修改同一文件 | 若目标不同，可在各分支独立改并由 integrator 解冲突；若共同写同一事实，先重划所有权或串行 | 同时共享写，事后仅凭 mtime 猜作者 | 停写，重划所有权或改串行；已产生的双写内容各自成 commit，交 integrator 判定重复/互补/无关 |
| 多仓/子模块 | 每仓独立 owner branch/commit；manifest 保存整组映射；子仓对象先可达，再更新父仓 gitlink | 只交父仓 gitlink，不保证子仓 commit 可取得 | 补齐每仓 commit 映射；子仓对象不可达的 gitlink 不进入整合 |
| 同一 Task 多 Attempt 重试 | 每次新 attempt/worktree/branch；旧结果标失败或 superseded | 在旧 Attempt 的目录原地续写，抹掉失败现场 | 旧 Attempt 目录冻结为失败现场，不原地续写；新 Attempt 从固定 commit 重开 |
| 候选修订 | 新 commit + `supersedes`；评审明确采用哪个版本 | 冻结后改 branch 再沿用旧评审 | 新哈希标为冻结后修订并记 `supersedes`；不进入本轮比较，除非任务包重开 |
| 重复且内容相同的候选 | 按 digest 去重，可共享内容对象，但保留各自 provenance | 删除一方记录后声称只有一个来源 | 按 digest 合并内容对象，但两份 provenance 都保留；不得删除一方记录后声称只有一个来源 |
| 合并冲突 | integrator 在独占整合 worktree 解析，记录冲突双方和裁决依据 | 让候选作者互相覆盖，或按提交时间自动取新 | 由 integrator 在独占整合 worktree 重解，记录冲突双方与裁决依据；不按时间自动取新 |
| 一方删除、另一方修改同一文件 | 作为语义冲突交 integrator 依据 Task 裁决，并补回归 | 机械采用 delete/modify 任一侧 | 作为语义冲突升给 integrator，依 Task 裁决后补回归；不机械取任一侧 |
| 用户工作树已有脏改动 | 视为用户所有；建立新 worktree/分支或避开，先记录 baseline | stash、reset、checkout 或覆盖用户文件来“清理” | 不 stash、不 reset、不 checkout；先记录 baseline，另建 worktree/分支绕开 |
| 执行中发现共享路径又被修改 | 立即停写并进入 §7.8；从最新可确认版本建立新整合 Attempt | 继续保存，期待自己的内容最后覆盖回去 | 立即停写，转 §7.8；从最新可确认版本建立新的整合 Attempt |
| formatter/codegen 同时运行 | 只在 owner worktree 执行，生成物归该 owner commit；固定工具版本 | 对共享目录启用后台自动写入 | 关掉共享目录上的自动写入；受影响文件重新从 owner commit 生成 |
| 无 Git 的简单 Task | 每个 Attempt 使用独立 Artifact key；以 digest/version 冻结 | 多 Attempt 写同一临时文件或对象存储键 | 已写下的内容迁到产品载体（Artifact + digest）；同键的多次写入按 provenance 拆开 |
| CI/并行测试 | 每个 job 使用独立输出目录和 Artifact 名；聚合器只读汇总 | 并行 job 写同一 coverage、报告或缓存真源 | 单槽输出作废，重跑到绑 commit 的独立位置；不采信被覆盖过的报告 |
| 跨 Task 共享缓存 | 缓存按输入摘要寻址、内容不可变、命中可校验；失败可丢弃重建 | 把可变缓存当结果真源或允许任务互相覆盖缓存条目 | 疑似被互相覆盖的缓存条目一律丢弃重建，不尝试修复 |
| 大文件/二进制 | 内容寻址存储，Git 记录摘要、schema、来源和位置 | 多人向同一路径覆盖上传，或把巨大生成物塞入普通 Git | 以 digest 认主；同路径多次覆盖上传的，取有 provenance 的那份，其余降级为未验证参考 |
| 敏感产出 | 加密/受控存储，最短保留期，日志脱敏 | commit、PR、普通 Artifact 或聊天中保存凭据 | 按泄露处理：轮换凭据、清理副本与日志、记录暴露窗口；**不能靠删文件了事** |
| symlink/路径别名 | 写前解析规范路径并确认仍在获准 writable root 内 | 利用软链、`..` 或挂载别名写出 owner 空间 | 核对实际写出的规范路径；越出 writable root 的写入按覆盖事故处理 |
| 外部发布/数据库写入 | 唯一 side-effect owner + 幂等键 + fencing + 回执 | 因代码分支隔离就允许多候选同时写生产系统 | 查副作用账，按幂等键判定是否重复执行；需要时补偿，不靠重跑覆盖 |
| 多执行者推远端 | 每个 owner 推自己的远端 ref；integrator 独占发布 ref | 共推同名远端分支，遇 non-fast-forward 后 force-push | **不要强推回滚**。报告有权主体，由其决定 revert 或冻结该 ref |
| PR 在评审后新增 commit | 原评审绑定旧 commit；新 HEAD 重新触发受影响门禁和评审 | 沿用旧批准声明新 commit 已通过 | 原批准作废，新 HEAD 重新触发受影响门禁与评审；不沿用旧批准 |
| 候选迟到 | 标 `STALE`，只读保留；需要时建立新改进单元 | 写入 final path、覆盖已选 commit 或再次执行副作用 | 标 `STALE` 只读保留；需要采用则新开改进单元，源仍是 commit |
| 失败/取消 | 冻结失败现场和已产出对象，盘点副作用，再按策略回收 | 先删 worktree 导致无法复盘 | 先冻结现场再回收；已删除的现场按证据缺口登记，不补造 |
| Agent 崩溃 | 新执行者从 manifest/checkpoint 和固定 commit 恢复到新 worktree | 盲接旧进程的半写目录 | 不接管半写目录；从 manifest/checkpoint 和固定 commit 在新 worktree 重建 |
| 已交卷 commit 需要修改 | 新 commit；旧哈希仍报给评审并记 `supersedes` | `commit --amend` 改写已被他人读过或已交卷的提交 | 原 commit 仍可达则继续作为评审对象；新哈希标为冻结后修订，不静默替换 |
| 两执行者提交到同一分支 | 不应发生——派工时 `exclusive_branch` 互斥 | 共用 `tmp` / `new` 这类分支名却不拆所有者 | 停写；按 commit 作者和时间拆成两条分支，原分支冻结不再接受提交 |
| 从共享目录拷走他人未提交稿 | 不拷。交卷只经 supervisor 收集的 commit | 把别人的草稿当自己的起点 | 该路不再计作独立候选；记录污染来源与时间窗口 |
| 整合时误拷工作区文件进共享主仓 | integrator 从**选定 commit** 取内容，写进自己的整合 worktree | 把任何人的未提交文件复制进共享主仓 | 从共享主仓撤出该文件，改从 commit cherry-pick / merge；撤出前先确认没有覆盖他人内容 |
| 只读探索 | 不写；或只写一次性抛弃分支且不推送 | 探索性改动混进实施分支或共享主仓 | 探索提交不进选优，除非任务包事先允许 |
| 跨机 / 新会话接手 | 只凭分支 + commit 恢复；cwd 必须是自己的 worktree | 凭「上次写在共享目录里」接着写 | 先看 `worktree list` 和 `status`；共享工作区里出现的未跟踪文件先按覆盖事故处理 |
| master/main 发布 | 仅 integrator 在最终验收后、获授权时更新 | 每个候选直接向 master/main 写文件或 commit | 未经整合的写入撤出发布面，从选定 commit 重走整合与 final gate；不在发布面上就地修补 |

### 7.7 最终路径的发布协议

当用户要求 `path/to/result.md` 时，Task 必须区分：

```text
candidate path:   每个 owner worktree 内的 path/to/result.md
publication path: integrator worktree 内的 path/to/result.md
published ref:    final commit / PR / release
```

候选作者只提交自己的相对路径，不直接把文件复制到共享 `master`。supervisor 选定候选或逐项
整合后，由唯一 integrator 从冻结 commit 取内容，在独占整合 worktree 写 publication path，
运行 final gate，再形成 final commit。是否推到 `master/main`、开 PR 或发布仍受用户授权约束。

发布动作必须带预期版本：Git 更新校验目标 ref 仍指向 integrator 开始时记录的 commit；文件或
对象存储使用版本号、ETag、generation 或等价 compare-and-swap。目标已经变化时，发布失败并
创建新的整合 Attempt：读取新基线、重新解决冲突、重跑受影响门禁，再尝试发布。不得以
force-push、无条件覆盖上传或先删后写绕过竞争。发布重试使用稳定幂等键；“内容相同”也要保留
本次发布回执和 provenance。

若用户明确只要多个可比较草案，则 publication target 是**候选集合及 manifest**，而不是某个
候选抢占正式路径。只有用户或 supervisor 作出选择后，才产生单一 final 文件。

### 7.8 覆盖或来源不明时的事故处理

**后到者赢在任何场景都不成立。**磁盘上的最后一版、时间戳最新的一份、最后推上去的那个
ref，都不因为「在后面」而获得正确性或所有权。覆盖发生后唯一有效的认主依据是 commit、
digest 和 provenance。

本节是唯一一套事故规程，分两档入口：

**四步前门（轻量场景）。**单个文件被覆盖、来源基本可判、无外部副作用、无发布竞争时：

1. **保全现场**：停止对该路径的一切写入，先记录，不删除、不 reset、不 checkout；
2. **恢复归属**：从 Git 对象、reflog、Artifact 或备份取回可识别的各版本，各自恢复为归属者
   的独立分支或 owner namespace，交还归属者；
3. **判定关系**：由非当事方判定两份是重复、互补还是无关，据此决定取一、合并或都保留；
4. **留痕**：把覆盖窗口、受影响对象和恢复依据记入证据账。

任一条不成立——来源不明、涉及发布面或远端、已产生外部副作用、或同一路径反复被改——
立即升级为下面的八步，不要在四步里硬撑。

**八步完整规程。**发现文件内容、大小、hash、mtime、branch/HEAD 或作者特征与预期不符时，
立即执行：

1. **停写**：暂停所有可能触及该路径的执行者和自动格式化/生成任务；
2. **保全**：不删除、不 reset、不 checkout；记录路径、stat、hash、`git status`、HEAD 和进程；
3. **分流**：把仍能识别的不同版本保存到各自 owner namespace 或不可变 Artifact；
4. **溯源**：依据 commit、checkpoint、manifest、工具事件和内容特征判断来源；mtime 只作线索；
5. **恢复**：优先从 owner commit、Git object、Artifact、备份或工具补丁记录恢复；
6. **裁决**：由 integrator 比较并决定选用、合并或全部拒绝，不由最后写入者自动获胜；
7. **回归**：在新 final commit 重跑门禁；
8. **记录**：写清覆盖窗口、受影响对象、恢复依据和防复发控制。

来源无法确认时，文件不得进入 final；能恢复内容但不能恢复 provenance 时，只能作为未验证
参考。事故处理中不得为了“恢复干净”破坏用户或其他执行者的未提交内容。

### 7.9 保留与垃圾回收

| 状态 | 默认保留 |
| --- | --- |
| SELECTED/INTEGRATED/PUBLISHED | final commit、来源映射、验收、证据、必要 Artifact |
| REJECTED | 候选 commit/digest、拒绝理由和必要证据；可按期限清理工作目录 |
| STALE/SUPERSEDED | 血缘和摘要；是否保留全文按审计/复用价值决定 |
| FAILED | 最小复盘证据、副作用状态和可恢复 checkpoint |
| CANCELLED | 取消依据、已产生副作用、需补偿项和保留对象 |
| 敏感临时物 | 达到最短业务/审计要求后尽快安全销毁 |

垃圾回收是显式阶段，不是执行者退出的副作用。删除前验证：发布结果可重取；所需 commit 可达；
Artifact 摘要可校验；副作用已收敛；没有活跃 Attempt 引用；保留期限已满足。清理记录至少包含
操作者、时间、对象、依据和失败项。

## 8. 冻结、迟到结果与取消

候选、评审、改进、最终结果和验收绑定不可变 commit。冻结后替换必须产生新 commit 并登记。

主线采纳后的在途结果标为 stale，不得覆盖主线、执行副作用或推翻已交付结果。确需采用时
建立新 Work Unit 或 Task。

迟到判定分两层，机制不同，不要混用：

| 层 | 判定依据 | 机制在哪 |
| --- | --- | --- |
| **产品侧**（Attempt 写回、副作用、终态提交） | Task/Attempt 状态、租约与 fencing token | [`request-lifecycle.md`](request-lifecycle.md) 的**目标合同**。本文只引用，不重新定义，也不复制其状态名；该机制是否已接线由代码和运行证据决定，本文不作既成事实的断言 |
| **开发侧**（候选、评审、改进、整合） | 冻结 commit、候选状态（§7.4）、冻结时间戳 | 本文。**开发侧没有租约机制**：整合方在吸收前必须显式核对四项——候选状态仍有效（非 `STALE`/`SUPERSEDED`/`REJECTED`）、commit 仍可达、提出方未撤回、基线未失效 |

两层都不依据分支头或“看起来更新”。**核对的对象是 commit 与候选状态，不是分支**——分支是
可移动的运输通道（§7.5），“commit 还在某分支上”既不必要（可达即可核对）也不充分（分支可被
重置或强推）。开发侧的迟到靠 Git 冻结语义加整合方核对，靠的是可验证凭据而不是执行者自律；
把它写成租约会让人误以为有一个会自动拒绝迟到写入的运行时。

取消先持久化意图，再停止调度、撤销租约、终止执行、盘点副作用、固定需保留的 commit 和
Artifact，最后回收 worktree/sandbox。取消与完成只能一个终态胜出。按 `request-lifecycle.md` 的目标合同，过期执行者对产品面的
写入应由 fencing 拒绝（该机制是否已接线由代码证明，不在本文断言）；对开发面（分支、worktree、发布路径）的写入
没有等价运行时机制，只能靠 §7.7 的条件式发布和整合方核对挡住，因此**开发侧的取消必须
显式停止执行者，不能只靠标状态**。

### 8.1 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵

状态按 §4.7 的三态能力探针标注。探针词与「已支持 / 当前缺失 / 需补法」三档的对应固定如下，
**读表一律按右列判定**，不得只看探针词：

| 探针状态 | 三档判定 | 含义 |
| --- | --- | --- |
| `available` | **已支持** | SDK 原语直接满足该条义务；平台仍需归一并记账 |
| `implicit_fallback` | **需补法** | SDK 有近似原语但不满足义务，平台/Adapter 必须补齐 |
| `explicit_unsupported` | **当前缺失** | 协议显式否定该能力，须走上游门禁或过渡补法 |

**不得把 SDK 原语冒充产品能力**：`implicit_fallback` 被读成「已支持」正是 09-03 那次
整合的措辞坑。矩阵只投影 `request-lifecycle.md` 的稳定 ID，不重新定义其义务；
证据锚点一律注明出自哪个仓——**不得拿本仓自己的代码当租用 SDK 的能力证据**
（本轮实例：某候选以本仓休眠的 `AgentProfile.permits_tool` 佐证 Harness 腿工具门）。

| 功能 ID | Codex 腿 | Harness 腿 | 需补法与验收 |
| --- | --- | --- | --- |
| `F-EXEC-01` | `available`：sandbox/approval/tool 面可配置；但 headless 默认 approval handler 会自动 accept | `implicit_fallback`：**进程内**工具门是真的——`tools/pre-execute` 的 allow/deny/ask 与 `ctx.tools.guard()` 的单调 deny（`docs/cookbook/adding-a-tool.md:59`），preset 按会话组合 tools/prompt/skills（`packages/preset/README.md:12`）；但 wire 无可信逐 Task context，也无 per-session preset 选择 | Attempt Admission 取 Task/Profile/当前批准的交集；Codex 覆盖默认 handler；Harness 工具网关逐次验权。`AT-05` |
| `F-EXEC-02` | `available`：thread/turn/event 可关联，仍需归一并写平台账 | **当前缺失（turn 级）**：`sessionId` 挂在每个事件上，Attempt↔session 一对一时 Attempt 级关联成立；但 `SessionPromptResult` 只有 `messageId`，协议明写它不标识 turn 结束或结果（`packages/sdk/protocol/README.md:52`），且事件对 runtime 全量未过滤（`protocol/src/types.ts:66`） | 上游补 turn correlation 与 filtered cursor；未补前只宣称 Attempt 级归属，不宣称逐 Turn 归属。I11/I15 |
| `F-EXEC-03` | `available`：approval callback 可逐动作接平台复核，默认实现不可用 | `explicit_unsupported`：server→client request 不发生 | 高风险动作只经工具网关；审批绑定动作/产物哈希并落账。`AT-05/07/12` |
| `F-EXEC-04` | `implicit_fallback`：有 usage，但无 Task 跨 Attempt 总账 | `implicit_fallback`：有进程级 maxTokens，但无 Task 总账 | PostgreSQL 预算预留/扣减/释放；超限先 revoke token/cancel。I10、`AT-13/21` |
| `F-EXEC-05` | `implicit_fallback`：thread read/resume 存在，但本地 rollout 不是业务 checkpoint | `explicit_unsupported`：wire 无 read/resume | §4.9 对象存储现场快照 + PostgreSQL checkpoint；Harness 未补前新 Attempt 恢复。`AT-09/12/15/20` |
| `F-EXEC-06` | `implicit_fallback`：`output_schema` 可承载，仍需 Profile/validator | `implicit_fallback`：可用 schema 化 `submit_result` 工具 | 固定输出合同显式区分事实/推断/假设/缺失/不确定，validator 拒绝混淆结果。I11、`AT-11` |
| `F-EXEC-07` | `implicit_fallback`：可输出澄清/失败，Task Interaction 仍属平台 | `implicit_fallback`：用显式结果/问题工具，不能原生等待恢复 | Adapter 归一 ask/fail；不满足时不得提交完成。`AT-07/11` |
| `F-EXEC-08` | `available`：可生成 Artifact；是否要求由 Profile 决定 | `available`：可通过显式工具提交 Plan Artifact | 简单 Task 不造空 Plan；复杂任务可先验 Plan。I15、`AT-06` |
| `F-INTERACT-01` | `implicit_fallback`：interrupt/steer/resume 可作为执行原语 | `explicit_unsupported`：无 turn cancel/resume 与 server request | 平台创建/投影 Interaction；Codex 恢复前重验；Harness 过渡期杀进程并新建 Attempt。`AT-07/14` |
| `F-INTERACT-02` | `implicit_fallback`：SDK 不拥有恢复令牌和可靠投递 | `implicit_fallback`：同样由平台承担，且无原 Session 恢复 | 后端在原子消费后写 outbox/可恢复记录；SDK 不得消费 token。`AT-07/08/15` |

本表的证据锚点是 §4.6 与 §4.8 所列 SDK 源码。每次升级 adapter/runtime，必须把矩阵登记为
`ID → owner → code → automated test → current state`，对应 I15；任何 `explicit_unsupported`
被路由命中都应在 dispatch 前 fail-closed，而不是运行时才发现。

## 9. 权限、预算与副作用

权限公式分两条，因为两条路径的约束项不同：

```text
Agent 路径（产品 Attempt 内）
  有效权限 = 请求方授权
           ∩ Task Profile
           ∩ Agent Profile
           ∩ sandbox / tool policy
           ∩ 当前批准
           ∩ 有效租约      ← 仅当执行发生在持有租约的 Attempt 内；
                              租约是 request-lifecycle.md 的目标合同项

Human 路径 / 不在 Attempt 内的开发操作
  有效权限 = 有权主体授权
           ∩ 仓库与环境策略
           ∩ 当前批准
```

租约是**条件项**，不是无条件交集：Human 路径和不隶属于任何产品 Attempt 的开发操作没有
租约，不能因此在公式上算作无权限。两条路径的差别只在约束来源，不在约束强度——§0.3 的
supervisor 等位原则同样适用于此。

推送、合并、发布、删除远端资产，访问新增敏感数据，执行不可逆迁移，追加预算，提高并行度，
修改规范或验收门禁，都需要明确批准或预先冻结的策略授权。批准绑定 Task、动作、目标、版本
和有效期，不跨场景延续。**授权不跨场景延续**：在 A 分支批准过推送，不等于 B 分支也可以；
Task A 的授权不延续到 Task B；一次批准的破坏性动作不构成下次的默许。

下列动作**只有有权主体**能做。Agent 路径上是前端用户或授权角色，经 Interaction 行使；
Human 路径上是有权的人。supervisor 不因协调职责获得其中任何一项：

| 动作 | 必须留下什么 |
| --- | --- |
| 批准高风险或不可逆动作（推送、合并、发布、迁移、删远端资产） | 批准人、动作、目标、版本、有效期 |
| 取消 Task 或中止在途执行 | 取消依据、已产生副作用、需补偿项、需保留对象 |
| 追加预算或提高并行度 | 原上限、新上限、依据 |
| 最终验收终审 | 所验 final commit、逐条判定、门禁原始输出位置 |
| 降级流程（把完整选优改成最小选优或单路） | 降级依据、被省略的环节、承担的风险 |
| 推翻已有判定或改判验收标准 | 原判断、错在哪、新判断、原标准与原始失败输出 |

**是否简化流程的裁量权在有权主体，不在执行者。**Agent 不得自行把完整选优降为单路，也
不得通过询问自己派出的 subagent 或取得多数同意来制造批准——§6.5 的自我批准禁令在任何
轮次都成立。

父预算覆盖全部 Attempt、Work Unit、工具、评审和子任务。外部副作用使用稳定幂等键并进入
持久账，记录意图、目标、状态、回执和补偿。恢复、重试和取消前先查账，不能从 Git 推断。

### 9.1 三道正交门与工具不可见原则

运行时有效能力必须同时通过三道独立门；三者不能互相代替：

| 门 | 决定 | 硬规则 | 合同锚点 |
| --- | --- | --- | --- |
| Tool Policy | 哪些工具存在 | deny 优先；allow 非空时未列工具默认拒绝 | `F-EXEC-01/03`、I3、A2 |
| Execution Scope | 在哪里、对什么资源执行 | workspace/data/network/tenant/actor 逐次收窄，不能由模型自报 | `F-EXEC-01/03/05`、I3/I12/I14、D4/I5 |
| Approval Policy | 此次具体动作谁可批准 | 批准不能扩出前两门；缺失、过期或漂移一律 fail-closed | `F-EXEC-03`、I3/I9/I12、`AT-05/12/14` |

Tool Policy 是硬停，不是 prompt 建议。被拒绝的工具应当**不存在**：会话组装层在发给模型前从
schema/catalog 移除；工具网关层即使收到伪造名称也再次 deny。前者减少诱导和误调用，后者防止
绕过；任何“工具仍在但描述为禁止”的方案不满足 `F-EXEC-01`。dsh 的 policy hook 与最终
monotonic deny 可复核 `~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:57-59`；OpenClaw
deny-wins 的参考语义见 `~/repo/openclaw/docs/gateway/config-tools.md:127-146`，这里只借机制。

### 9.2 四档审批、哈希绑定与凭据边界

审批策略固定四档，具体动作由 Task/Profile 风险分类映射，不把某个 Profile 的字段写进本文：

| 档 | 适用 | 决策者 | 纪律 |
| --- | --- | --- | --- |
| `auto-deny` | 未声明、越权、不可满足门禁 | 确定性 policy | 直接拒绝并留 reason code |
| `auto-allow` | 冻结政策明确的低风险、可逆、范围内动作 | 确定性 policy | 仍逐次验权、记预算/副作用 |
| `llm-review` | 只需语义检查且政策明确允许委托的中风险动作 | 独立受限 reviewer | **必须落账**模型/版本/输入摘要/判定/理由；否则等于产出者自我批准 |
| `human-approval` | 高风险、不可逆、发布、扩权、追加预算 | 有权主体经 Interaction | 一次性、短时、精确绑定，不可转授 |

每份批准绑定 `task/attempt/action/target/policy_version` 与待执行 canonical payload、计划/diff/
Artifact 的内容哈希；执行前重算，任一字节、目标、权限或版本漂移即作废，重新批准。批准有短 TTL，
超时 fail-closed；不得把 Codex 默认 accept（`client.py:773-779`）当任何一档批准，也不得让生成
候选的同一 Agent 充当 `llm-review`。这落实 `F-EXEC-03`、I3/I9/I12、`AT-07/12/14`。

所有模型推理经平台 egress proxy；真实 provider key 只在代理/Secret 边界，绝不下发 Codex 或
Harness 进程。Attempt 只拿绑定 `attempt_id + executor + model allowlist + tenant/actor + budget +
deadline` 的短 TTL、可撤销网关令牌；取消、失租、预算耗尽或终态立即 revoke。通用 worker 不持有
专业数据凭据，专业 worker 不持有 Codex provider 凭据；工具凭据由 host-side gateway 按调用解析，
不进 prompt、普通环境回显、checkpoint、日志或 Artifact。这是 I3/I12、A3/A4 与 `AT-05/12/13`
的实现门禁。

## 10. 证据、验收、交付和清理

### 10.1 最小证据账

```text
原始请求 + 冻结 Task 契约
workspace materialization manifest
Attempt / Work Unit / executor 映射
initial / candidate / selected / final commits
owner namespace / publication target / integrator
candidate status + supersedes / provenance chain
决策、改判和 Interaction
验证命令、环境和原始输出引用
预算消耗与副作用引用
未覆盖范围、盲区和残余风险
```

聊天不是唯一账本；另一个执行者不能恢复和复核的内容视为未持久化。

### 10.2 最终验收

只验收固定 final commit 和持久 Artifact：

1. 原始请求和每条 acceptance 已判定；
2. 硬门禁、组件测试和最终回归通过；
3. 多仓 commit、gitlink、生成物和部署引用一致；
4. 未验证项、部分结果、盲区、副作用和风险已披露；
5. 未超权限、预算和数据范围；
6. checkpoint、决策和证据足够第三方复核；
7. 结果和验收先持久化，才提交成功终态。

Agent 声称完成、subagent 全返回、已有 commit/PR 或候选测试通过，均不能单独使 Task 成功。

### 10.3 Delivery

后端持久化 final commit/patch、摘要、Artifact、验收判定、证据和风险，再返回前端。流连接只
作通知；断线、刷新或换设备后仍可按 `task_id` 重取。通知失败独立重试，不修改业务终态。

### 10.4 sandbox 清理

- 先持久化需交付/审计的 commit、patch、日志和 Artifact；
- 安全销毁凭据、临时令牌和敏感缓存；
- 按 manifest 处理 worktree、临时分支和构建缓存；
- 失败现场如需保留，设置期限、权限和清理责任；
- 删除前确认候选/final commit 可达，Artifact 摘要可重验且无活跃引用；
- 清理失败独立告警，不把成功 Task 改成失败。

## 11. Human 与 Agent 对照

| 生命周期位置 | Agent 路径 | Human 路径 | 共同不变量 |
| --- | --- | --- | --- |
| 请求入口 | 前端 Submission | 人直接提出/接收 | 原始请求不覆写 |
| 受理整理 | FastAPI 建 Task | 人写持久请求记录 | 边界、验收、权限、成本明确 |
| 根 Git 仓库 | 后端在 sandbox 初始化/检出 | 人初始化/检出 | 来源和 initial commit 可追溯 |
| 任务材料 | 后端按 Task 物化、写 manifest | 人放入并记录 | 不混入越权或无关材料 |
| 初始 worktree | sandbox 根工作区 | 人建立 | 目录、分支、HEAD 明确 |
| Attempt 内执行监督 | 执行监督 Agent 可担任 | Human supervisor 可担任 | 地位和开发协调职责等同；均不能改上层路由或扩权 |
| 后续 worktree | 执行监督 Agent 按 Work Unit 建 | Human supervisor 按 Work Unit 建 | 一单元一可写面、同基线 |
| 候选产出 | owner branch/worktree 或 Artifact namespace | owner branch/worktree 或持久草稿空间 | 私有地产生，不写共享发布面 |
| 发布最终路径 | 唯一 integrator | 唯一 integrator | 单写者发布，final commit 验收 |
| subexecutor | Agent 或 Human | Human 或 Agent | 派工只能收窄 |
| 选优整合 | 执行监督 Agent 组织 | Human supervisor 组织 | 先事实门禁，后偏好 |
| 验收 | 独立 Agent/验收器，批准问人 | 未参与者验收，有权人终审 | 自检不替代验收 |
| 恢复 | 后端账 + Git + checkpoint | 请求记录 + Git + handoff | 会话和人脑都非唯一账本 |
| 交付 | 后端持久化并返回前端 | 人按协作/发布流程 | final commit、证据、风险固定 |
| 清理 | 系统按 sandbox 策略 | 人按仓库规则 | 先留证，再清临时面 |

两份生命周期文档必须分别写全上下文、Git/worktree、supervisor、证据、验收、失败、交付和
清理；可以互引差异，不能用“其余见另一份”省略共同内核。

### 11.1 本文的生效边界

**本文现在是长期开发指南，不再以“Agent 路径开发结束”作为删除理由。**它既承载开发协作
内核，也承载执行器边界、双 SDK 能力矩阵、Harness 门禁、部署/恢复与安全审批架构；这些内容
在产品 Agent 持续演进期间仍是 A1–A5、`F-EXEC-*`、`F-INTERACT-*`、I3/I10/I12/I15 的
开发依据。`development-lifecycle-human.md` 同样长期保存，两份文档继续各自自足。

由此有两条硬要求：

1. **人那份必须自足。****已完成（2026-09-02）**：
   `development-lifecycle-human.md` 已把共同内核按人的
   语境写全（执行内核、协调者 fan-out、产出物与 commit 落地纪律、证据账、成本与停止、
   完成判据、反模式、项目实例、词汇对照），对本文的引用只剩「指出差异」两处，不再取用
   内容。两份文档仍可独立使用。
2. **凡能落实为代码、测试或门禁的纪律，必须落实为代码、测试或门禁。**需要长期有约束力的
   规则不能只以文字存在于本文或提示词里。§5.1 的
   写入前门禁、§4.4 的物化门禁、§5.2 的范围门禁和 §10.2 的验收判据都属于此类：文档描述
   意图，门禁产生效力。**部分完成（2026-09-02）**：文档的机械不变量（仓内链接、章节
   引用、表格列数）已由 [`../doc-gate.py`](../doc-gate.py) 经 `.githooks/pre-commit`
   自动执行，见 [`../constraints.md`](../constraints.md)「保证这些被遵守的三层」。
   **仍未完成**：§5.1 写入前门禁、§4.4 物化门禁、§4.7–§4.9 执行器/部署门禁、§9.1–§9.2
   安全门禁、§10.2 验收判据——这些要么依赖尚不存在的运行时，要么其失败形态本身不经过
   commit，机械载体抓不到。按本项目规则，**做不成的老实标 ⚠**，不假装已门禁化。

### 11.2 本文的删除条件与清理清单

本文不随一次实施结束而删除。未来只有在规范重构时，**四个条件同时满足**才可删除：

1. Agent 路径不再使用本文描述的开发执行方式，且有获批的替代指南；
2. 人那份自足——**已满足**，见上；
3. §11.1 第 2 条完成：本文中仍需生效的纪律已落成代码、测试或门禁，而不只是文字。
4. **执行器架构内容已先迁入长期真源**：路线边界、Port/能力三态、双腿矩阵、Harness 门禁、
   双 runtime 部署/恢复、OpenClaw 取舍与审批/凭据纪律，已由 `development-plan.md`、实现矩阵、
   部署合同或其获批后继文档完整吸收，并有 `旧章节 → 新落点` 映射；不得随开发流程正文一起丢失。

删除时必须同步清理下列引用，否则会留下悬空链接：

| 位置 | 处置 |
| --- | --- |
| `AGENTS.md` 第 22 行「开发 Agent 接任务前必须读取」 | 改指获批的替代 Agent 指南；不能改指只覆盖 Human 路径的文档 |
| `development-lifecycle-human.md` 头部与末节「边界」表（2 处） | 删除或改指替代 Agent 指南；人那份正文不取用本文内容 |
| [`request-lifecycle.md`](request-lifecycle.md) 3 处引用 | 改指替代 Agent 指南，或在不再存在 Agent 开发流程时删除引用 |
| `development-plan.md` 的“执行层租用”与 A1–A5 相关指针 | 确认已吸收 §4.5–§4.11、§8.1、§9.1–§9.2 的稳定结论，不留下双真源 |
| 实现矩阵、部署文档与测试 | 保留每个 `F-EXEC-*` / `F-INTERACT-*` 的 owner/code/test/state 与 runtime 门禁证据 |

删除前确认：上表全部处置完毕；本文中不打算保留的结论已确认无人依赖；需要保留的已有
不会消失的落点，尤其逐条核对 §4.5–§4.11、§8.1、§9.1–§9.2 的迁移映射。这正是
「带退出条件的记录不会变成孤儿」的用意。

## 12. 完成判据

开发类 Agent Task 只有同时满足以下条件才闭环：

- Submission 幂等受理，原始请求和规范化 Task 可追溯；
- 简单/复杂路由有依据；复杂 Task 的 sandbox、Git 和 manifest 可复现；
- 范围、验收、权限、预算、批准点和基线已冻结；
- Agent 接单核对工作区、指令、租约和输入；
- 单路或 supervisor 流程按风险执行，角色冲突已处理；
- 每个产出有 owner、namespace、状态、provenance 和唯一 publication target/integrator；
- 候选没有直接写共享路径或 `master/main`，发布只从独占整合面发生；
- publication target 通过预期 HEAD/version 的原子条件更新，发布竞争没有变成静默覆盖；
- 并行结果绑定 commit，迟到、失败和取消已处置；
- final commit 上全部门禁和验收逐条通过；
- 结果、证据、副作用、盲区和风险已持久化；
- 后端提交唯一终态，前端可重取结果；
- Git 对象和 Artifact 可达、血缘可追溯且无活跃引用后，sandbox 才清理。

缺项时只能称“已受理”“已物化”“候选完成”“本轮选定”“待验收”“交付待重试”或
“清理待处理”，不能笼统宣称完成。

## 13. 反模式

| 反模式 | 失败方式 |
| --- | --- |
| FastAPI 只保存整理稿 | 原始意图不可追溯 |
| Task 未落库就建仓或调度 | 无主 sandbox、不可恢复执行 |
| 把所有资料塞进仓库 | 越权、泄密、上下文污染 |
| 复杂 Task 无 initial commit/manifest | 实际基线不可证明 |
| Agent 猜仓库、分支或目录 | 修改落错可写面 |
| Agent 在 sandbox 外另建仓 | 绕过物化、授权和回收 |
| Agent supervisor 被视为 Human 的低配 | 双重指挥、整合责任悬空 |
| Human supervisor 被视为无限授权 | 权限、预算和改判失控 |
| 并行单元共用工作树 | 相互覆盖、无法归因 |
| 会话隔离当作文件隔离 | 多个助手仍写同一个物理文件，最后保存者覆盖前者 |
| **用 `-new` / 时间戳 / 助手名当隔离** | 文件名不是工作区。共享路径上照样后写覆盖先写，且制造虚假安全感：以为改了名就安全，于是继续都写同一个目录 |
| 把人的主 checkout 当文档原件投放点 | 既覆盖人的未提交改动，也覆盖其他执行者的草稿；被覆盖方无痕消失 |
| 未提交就让别人到「同一路径」接盘 | 拷走的是没有归属的污染源，接盘者不再是独立候选 |
| 交卷报路径不报 commit | 路径会漂移、会被覆盖，评审对象丢失 |
| 每个执行者都写共享 `handoff.md` | 单写者面被互相覆盖，交接游标失真 |
| 所有候选直接写用户指定最终路径 | 路径成为竞态，选优在写入时被偷偷决定 |
| 多个执行者直接改 master/main | 未经整合的草稿互相覆盖并污染发布面 |
| 发布时不校验目标 HEAD/version | 新结果静默覆盖别人的更新，或旧结果覆盖新结果 |
| non-fast-forward 后 force-push | 用运输命令抹掉并发历史和已评审对象 |
| 用 mtime 判断作者或采用版本 | 时钟和后续复制会误导溯源，provenance 丢失 |
| 未跟踪文件作为唯一交付 | 无 commit/digest，覆盖后难以恢复和归因 |
| 候选读取其他候选 | 独立信号退化成改写 |
| 作者自评自收 | 同一判断链为缺陷背书 |
| 多数票覆盖失败测试 | 偏好压过事实 |
| 只固定分支名 | 评审对象漂移 |
| final commit 不回归 | 整合缺陷未发现 |
| Git 充当授权/预算/副作用账 | 恢复后越权或重复动作 |
| 删除 branch/worktree 前不建立持久 ref | commit 变成不可达对象，后续可能被回收 |
| 复制文件代替整合记录 | 内容存在但来源、取舍和验证对象不明 |
| 已派工/全返回当完成 | 内部动作冒充用户结果 |
| 成功后立即删 sandbox | commit 和证据丢失 |
| 通知失败改写终态 | Delivery 故障污染结果 |

## 14. 常见失败方式与项目实例

上一节的反模式是机制描述。本节记录本项目实际遇到过的失败，并按**证据强度**分三级标注。
三级不是修辞差别，是能不能独立复核的差别：

- **已核对事实**：证据当前仍可独立取得并复核（commit、blob、文件存在性、可重跑命令）；
- **事故报告**：确实发生过，但现场已灭失，只能按当事方陈述记录，不能独立复核；
- **设计风险**：机制上成立，但本项目尚未实际踩到，或原始证据出处已不可取得。

三级不可互相升格。尤其**不得**把「机制上必然如此」当成「此处已核对」——这正是 §7.8 第 4 步
要求的态度：能证明的和推断出来的分开写。

| 失败 | 证据性质 | 控制 |
| --- | --- | --- |
| **隔离来自 worktree + 命名分支，不来自文件名** | **已核对事实（2026-09-02）**：luna / cursor / kimi 三方在各自 worktree 与命名分支上持有**同名且不带后缀**的 `development-lifecycle-agent-new.md`，内容互不相同且**全部得以保留**；各自的 commit 与 blob 可独立复核。故后缀**非必要**；又因同一工作树内两方写同一带后缀的路径照样互相覆盖，后缀亦**非充分** | §0.4、§7.5、§13 |
| **未提交同路径写入没有任何保护** | **已核对事实**：Git 对未跟踪/未提交文件的同路径写入不提供冲突检测、不留历史、不留作者归属。这是 Git 的语义，可随时复现，与本轮事故是否可复核无关 | §5.1 写入前门禁、§7.5、§7.6 |
| **多执行者写进共享 checkout 造成覆盖** | **事故报告（2026-09-02），现场已灭失**：当事方陈述有产出在共享 checkout 上被后写覆盖。共享路径上的文件事后已被清走，**具体发生过哪一次覆盖、写入顺序和责任人均不可独立复核**，本表不作此断言。可复核的部分见上两行 | §0.4、§5.1、§7.8 |
| 以工作区最后一版代替 commit 做交卷或比选 | **已核对事实**：磁盘上的「当前文件」不携带作者归属，也不能证明谁先写完；认主只能靠 commit、digest 和 provenance | §7.5、§7.6 |
| 只写分支名，不固定 commit | **事故报告（2026-08-27）**：当事方记录评审曾引用旧提交而主方已前进。`merge-review/` 原始记录可从 commit `eb38868b^` 取回，但其中**未找到**对应条目，故不升为已核对 | §7.5、§8 |
| 评审意见的处置边界由被审方单方划定 | **已核对事实（2026-08-27）**：`merge-review/disposition.md`（可从 `eb38868b^` 取回）逐条由被审方判定采纳或拒绝，其中一条门禁因「三台机器分别报 0 / 4 / 95 条失败」被判为误报并删除。**「优胜作者拒绝改进」这一更强的说法未获记录支持，不采用** | §6.5、§6.7 |
| 评审给出的验收标准无人回跑 | **已核对事实（2026-08-27）**：`merge-review/disposition.md` 末节自记 cursor 那份验收标准「**未回跑**」、kimi 那份「**待评审方执行**」、luna 那份仅第 3 条通过。可从 `eb38868b^` 取回复核 | §6.7、§10.2 |
| 只测一端就宣布跨仓契约完成 | **现行硬规则**：[`constraints.md`](../constraints.md) C4——单仓 CI 只跑自己那半，provider 改了、consumer 锁没跟，两边各自都绿 | §5.2 范围门禁 |
| 候选提前读取其他方案 | 设计风险。机理清楚，但本项目的原始记录出处已不可取得，不作为项目实例引用 | §6.4 |
| 把历史设计或目标态当成代码现状 | 设计风险（同上）。四级词典与 dormant 回跑是现行控制 | §0.2、§5.2 |
| 多数票覆盖失败测试 / 全体一致的共同盲区 | 设计风险（同上）。多个相似模型可能共享盲区 | §6.6 |
| 候选人互投决定胜负 | 设计风险：结构上「被审方兼任判定方」已在本项目出现过，但候选互投这一具体流程尚未实跑 | §6.5 |
| 大补丁混合多条主张 | 设计风险，尚未在本项目实跑 | §6.7 |
| 整合时拷贝未提交文件进共享主仓 | 设计风险：绕过选定哈希，主仓变成公共投稿箱 | §7.7 |
| sandbox 回收后证据不可达 | 设计风险：工作仓是临时供给，不是档案 | §7.9、§10.4 |
| 完整选优流程本身 | **本项目尚未完整实跑**：独立裁判、匿名随机评审和停止规则目前是制度设计，不得写成既成能力 | §6 全节 |

本表的分级本身就是纪律的示范。2026-09-02 一例被拆成三行：两行是任何人现在都能复核的
事实（三棵 worktree 的同名文件共存、Git 对未提交同路径写入无保护），一行是现场已灭失的
事故报告。**不写「谁覆盖了谁」，也不写「确实发生了后写覆盖先写」**——后者虽然是当事方
陈述且机制上成立，但共享路径现场已被清走，按 §7.8 第 4 步，mtime 与「最后一版」只是线索，
不足以单独证明写入顺序或责任人。

纪律的效力不依赖那次覆盖是否可复核：上面两行已核对事实足以支撑 §0.4、§5.1 和 §7.5 的
全部要求。**用不可复核的叙述去加强一条本来就成立的规则，只会削弱整份文档的证据标准。**

## 附录 A：词汇对照

产品对象名只在这里对照，**不把产品状态机搬进本文**。Human 路径上没有这些产品对象时，
用右列的开发侧对应物即可。

| 产品合同用语 | 本文对应物 |
| --- | --- |
| 前端 Submission | Agent 路径的原始请求来源；Human 路径由人直接提出或接收（§1） |
| FastAPI 受理 / Task 化 | 工作仓供给前的任务化；Human 路径由人冻结请求与验收（§2） |
| Task | 一件有边界的开发工作及其冻结契约（§2.3） |
| Attempt | 一次实施、候选或修复轮次（§5.4） |
| Work Unit | supervisor 派出的子工作单元；不是产品子 Task（§6.2） |
| Artifact | 代码、补丁、报告、测试输出、证据（§7.3） |
| Interaction | 向有权主体的澄清或批准请求（§9） |
| Event | 追加式改判与证据记录（§10.1） |
| Delivery | 最终回复与可重取产物（§10.3） |
| Handoff | [`../handoff.md`](../handoff.md)；单写者面，只由 supervisor / 主驾驶写（§5.5） |
| sandbox git | 复杂 Task 由后端物化的工作仓；Human 路径由人建立（§4.1） |
| worktree | supervisor 为每个可写执行者建立的并行隔离工作区（§6.3） |
| 命名分支 | 一执行者一分支；commit 的运输通道，**不是评审对象**（§7.5） |
| 未提交工作区文件 | 仅本地草稿；同一工作区同一路径后写覆盖先写（§7.5） |
| 人的主 checkout | 如 `~/master/<仓>`；只读参照，**不是投稿箱**（§7.2） |
| Attempt 租约 / fencing | **产品侧机制**，语义见 [`request-lifecycle.md`](request-lifecycle.md)；开发侧无等价运行时，迟到判定靠冻结 commit 与整合方核对（§8） |
| 产品 supervisor 拆子 Task | [`request-lifecycle.md`](request-lifecycle.md)，不在本文（§0.1） |

## 附录 B：开发 Task 持久记录模板

```markdown
# DEV-<ID>：<短名>

## ① 原始请求
<用户原话，不改写>

## ② 受理、边界和授权
- 规范化目标：
- 包含：
- 不包含：
- 不包含部分归属：
- 权限与批准点：
- 预算、期限和停止条件：
- run / owner / work unit：
- 可写根与 output namespace：
- publication target / integrator：

## ③ 基线与工作区
- Task / Attempt：
- sandbox / workspace：
- source refs：
- initial commit / gitlinks：
- materialization manifest：
- 适用指令：

## ④ 决策点
| ID | 问题 | 结论与理由 | 证据 |
| --- | --- | --- | --- |

## ⑤ Work Units 与落地去向
| Work Unit | owner | branch/worktree/namespace | output commit/digest | publication target | status |
| --- | --- | --- | --- | --- | --- |

## ⑥ 验收标准与证据
| ID | 标准 | 判定 | 证据 |
| --- | --- | --- | --- |

## ⑦ 依赖、Interaction 与副作用
- 依赖：
- 澄清/批准：
- 副作用账：

## ⑧ 状态流转与改判
| 时间 | 状态/改判 | 触发 | 原判断错处 | 新判断 |
| --- | --- | --- | --- | --- |

## ⑨ 交付与清理
- final commit / Artifact：
- provenance / supersedes：
- published ref / publisher：
- 未覆盖与残余风险：
- Delivery：
- sandbox/worktree 清理：
```

空栏必须写“不适用”及理由。载体可以是数据库、Issue、PR、事件流或仓库文件，但不能丢失
原始请求、边界、验收、基线、证据和改判历史。
