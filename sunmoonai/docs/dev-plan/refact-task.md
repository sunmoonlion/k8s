# Refact 任务：重写 `working/development-lifecycle-agent.md`

> 建立：2026-09-03 ｜ 发起：项目所有者 ｜ 起草：opus
>
> **opus 本轮不参赛**，任评审与整合方：裁决选基座、逐条整合、处理异议。不参与独立验收。
> 角色划分见 §13。
>
> **本文是发给各助手的任务书。**读它的人可能没有此前任何上下文，所以第一部分把背景
> 讲全；第二部分是要交付的东西。
>
> **产物位置**：任务书与输入材料看 `master`（本仓 `~/master/k8s`）；
> **你的产物放你自己的 worktree 目录**（`~/worktrees/<你的名字>/k8s/...`），不要写 master。

---

# 第一部分 · 背景

## 1. 这个项目在建什么

investment-app 是一个多租户投资研究平台。用户在浏览器提出请求，后端受理成 Task，
交给 Agent 执行，结果持久化后返回前端。项目规矩分三层：

| 文档 | 管什么 | 本轮是否可动 |
| --- | --- | --- |
| [`constraints.md`](constraints.md) | **代码必须符合的规则**（A/C/D/I/T/R 系列） | 不动 |
| [`development-plan.md`](development-plan.md) | 要建什么、为什么这么建 | 不动 |
| [`working/request-lifecycle.md`](working/request-lifecycle.md) | **产品契约**：Task/Attempt 对象、两层状态机、十五条不变量 I1–I15、四本账、Profile、验收矩阵 AT-01…AT-22 | **不动，是原则层** |
| [`working/development-lifecycle-agent.md`](working/development-lifecycle-agent.md) | **上一份的开发指南**：agent 怎么把那份契约建出来——工作区物化、写入前门禁、supervisor 派工、产出物与 commit、权限预算副作用、证据验收交付 | **本轮要重写的就是它** |
| [`working/development-lifecycle-human.md`](working/development-lifecycle-human.md) | 人的路径，与上一份同构。**长期保存** | 不动 |

**关键关系，先读懂再动手**：`request-lifecycle.md` 定义**要建成什么**；
`development-lifecycle-agent.md` 定义**怎么把它建出来**。后者是前者的开发指南，
不是它的投影，也不重新定义它的对象。

## 2. 2026-09-02 发生了两件互不知情的事

### 2.1 五家并行提案：agent 架构可行性 + OpenClaw

用户当天提出两问，发给五家助手，按 [`agent-discipline.md`](agent-discipline.md) 模式 A
**互不可见**地各自作答：

1. investment-app 建统一 Supervisor 接前端 Task 并路由——通用任务经官方 SDK 交 Codex，
   专业任务（如财务分析）经官方 SDK 交基于 DeepSeek Harness 构建的专业 Agent。
   这条架构可行吗？从自研执行体系改成租用，合理吗？比原来更好吗？
2. `~/repo/openclaw` 的 Gateway 做法，路由与 Supervisor 该借鉴、完全转向，还是另有更好建议？

产出五份，共 3687 行，全部在 `dev-plan/` 下：

| 助手 | 文件 | 行 |
| --- | --- | --- |
| luna | [`investment-agent-architecture-luna.md`](investment-agent-architecture-luna.md) | 988 |
| kimi | [`investment-agent-architecture-kimi.md`](investment-agent-architecture-kimi.md) | 686 |
| opus | [`investment-agent-architecture-opus.md`](investment-agent-architecture-opus.md) | 804 |
| qwen3.8 | [`investment-agent-architecture-qwen3.8.md`](investment-agent-architecture-qwen3.8.md) | 635 |
| cursor | [`investment-agent-architecture-cursor.md`](investment-agent-architecture-cursor.md) | 574 |

kimi、cursor、opus 三家原本一人多份，2026-09-03 已各自合并成一份，内容未改判。

### 2.2 同一天，另一轮：lifecycle 文档重写

同日另有一轮完整流程（四候选评优 → 逐条整合 → 异议轮 → 独立验收 → 发布），
产出就是现在的 `development-lifecycle-agent.md`（518 → 1132 行）与
`development-lifecycle-human.md`（169 → 821 行）。

**两轮互不知情，且有 3.5 小时时间差**：

```text
08-31 17:19  working/ 三份起稿                     ← 此时 dsh 还不存在，执行器只有 Codex
09-02 10:46  deepseek-harness 第一次出现在 dev-plan
09-02 10:46–14:31  五家五份原稿全部写完
09-02 17:52  development-lifecycle-agent.md 整合稿替换正文
09-02 18:01  development-lifecycle-human.md 自足化
09-02 18:05  lifecycle 定稿合入 master             ← 比五家原稿最晚一份晚 3 小时 34 分
```

**后果**：五家写稿时，lifecycle 定稿还不在 master 上。它们要论证「加一条 dsh 腿可不可行」，
只能把 Task 内核、四本账、supervisor 各自重推一遍当论证背景。**这些重复不是质量问题，
是隔离协议 + 时间差的必然产物。**

反过来看它也是交叉验证：五份稿在互不可见、也没读过定稿的情况下推导出的 Task/Attempt 分层、
四本账、supervisor 不是第三个 agent、终态不可转出，与 `request-lifecycle.md` §6.1 的
I1–I15 高度同构。

## 3. 2026-09-03：一次失败的整合，和它暴露的问题

opus 在 09-03 把五家五份整合成一份 1100 行的稿子。**该稿与它的处置记录已删除**
（内容在 git 历史里可取），不作本轮输入——以免锚定。作废原因如下，请引以为戒：

| 问题 | 具体 |
| --- | --- |
| **整合方即参赛方** | opus 自己有三份在场上，却由它裁决。上一轮 lifecycle 那次 opus 未参赛才当裁决方，条件不同 |
| **无异议轮、无独立验收** | 上一轮有，这一轮没有。下面几条本该在验收时被逮住 |
| **与 `request-lifecycle.md` 大量重复** | 自编了一套 8 条不变量与 I1–I15 并存，还漏了 I12/I13/I15；自列 11 条验收与 AT-01…AT-22 并存 |
| **弄丢了基座的长处** | luna 原稿用 `F-EXEC-03` / `F-EXEC-05` / `F-INTERACT-*` 锚定 dsh 的缺口，整合时被抹成散文。全稿此类 ID 出现 **0 次** |
| **措辞不准** | 把 Harness SDK 门禁写成「专业路线进入实施前」，会被读成「专业 agent 建不了」 |

**因此本轮要求**：见第二部分的验收标准，尤其是锚定要求。

## 4. 已经查实、不必重新论证的事实

以下由多家互不可见地各自取证，或由裁决方复核过，直接采信：

**① dsh 能构建专业 agent —— 这是选 dsh 的最硬理由。**
preset 是一等公民：一 preset = 一目录一份 `agent.cordis.yml`，按会话组合
tools/prompt/skills/persona，**一个进程可同时跑多个不同组合的 agent**
（`packages/preset/README.md`）。Profile + Bundle + patch 组合，不必 fork runtime。
一切皆插件（`docs/cookbook/adding-a-tool.md`）。Codex 无 preset 概念，只有进程级配置。

**② 但 dsh 当前 SDK 的 wire 控制面不足，接生产控制面要过门禁。**
公开 wire 只有 `initialize` / `session/prompt` / `shutdown`；无 cancel、无 session
close/resume/read、无逐 Turn 结果归属、无 per-session preset 选择、无模型不可篡改的
tenant/actor/policy 绑定、无 `output_schema` 对等参数、服务端→客户端请求是死能力
（协议 README 原文：server never sends one）。
**注意：这卡的是「我们的状态机怎么管它」，不卡「它能不能干专业活」。两个轴别混。**

**③ dsh 不需要系统 Node.js —— 一条曾被误判的阻断，已推翻。**
opus 原稿断言「runtime 镜像里没有 Node，所以 dsh 装不进去」。镜像事实为真，推论不成立：
`~/repo/deepseek-harness/python/sdk-runtime/README.md` 原文 *"SDK use requires no system
Node.js"*；`platforms.json` 已发布 `linux-x64 → manylinux_2_28_x86_64`。qwen 与 kimi
互不可见地各自核到同一句，裁决方 09-03 第三次复核确认。
仓库另有需系统 Node 22.19+ 的 `runtime/node/` carrier，但 README 明写
*never selected automatically and excluded from wheels and sdists*——**别再被它误导**。
仍未验证的只有「该 wheel 能否从内网 PyPI 镜像装到」，属供应链问题。

**④ Codex 被钉死在 Responses API。**本仓 Codex 已移除 `wire_api = "chat"`
（`codex-rs/model-provider-info/src/lib.rs:57` 有报错原文）。通用腿走 OpenAI 系模型零障碍；
要跑 DeepSeek 等 Chat Completions 模型必须自建翻译代理，有真实阻抗风险。

**⑤ Codex 默认 `approval_handler` 自动 accept 命令执行与文件改动**
（`sdk/python/src/openai_codex/client.py:773-779`）。headless 生产必须覆盖它。
**这是「没有人在场」下最危险的一处。**

**⑥ 生产环境里现在没有 agent。**`ToolExecutionPort` 生产层引用数为 0——不存在
「模型调工具、看结果、再决定」的循环；`RunBudget`、`SandboxPort`、`CancelRunCommand`
引用数同为 0；`AGENT_V4_TRAFFIC_ENABLED: 'false'`。

**⑦ 部署侧四条硬阻断**（只有 opus 稿核过部署清单，每条带可复跑 `grep`）：
worker 无任何 `ipBlock`（两个模型 API 都连不出去）、`readOnlyRootFilesystem: true`、
内存上限 768Mi、`AGENT_PILOT_LLM_*` 在 bundle 里根本没配。

**⑧ 财务数据是死穴。**投资仓 13 张表全是运行时基础设施，业务数据为 0。
kimi、qwen、luna 三家各自独立提出。**没有数据，专业 agent 的选型再对也无米下锅。**

## 5. 一处曾经的归档失误

kimi 的两份提案 09-02 被 `fa88dc72` 按文件名后缀当作「历史调研材料」一并移出仓外，
09-03 已捞回 `dev-plan/`。`~/codex-reference-archive/kimi/` 下仍有同名副本，
**以 `dev-plan/` 下的为准**。

---

# 第二部分 · 任务

## 6. 交付物

每家交**两份**，都写在**你自己的 worktree**，master 只读：

| # | 文件（相对仓根） | 内容 |
| --- | --- | --- |
| 1 | `sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | **候选**：直接改写基座那个文件，一份可直接发布的完整成品 |
| 2 | `sunmoonai/docs/dev-plan/working/refact-review-<你的名字>.md` | **自述 + 评优**，见 §13.3 |

第 1 份**不是补丁、不是增量说明、不是另起一份新文档**——就是那个文件的完整新版本。
路径与 master 完全一致，所以「你改了什么」= 你 worktree 里的 `git diff master`，
裁决时会直接这么看。

四家写同一个路径**不会冲突**：候选只活在各自分支，裁决方到各家 worktree 按 commit 取，
**不合并任何候选分支**；全流程只有最后一步由裁决方把最终稿写进 master。

## 7. 基座与不许动的部分

**基座是 master 上现有的 `working/development-lifecycle-agent.md`（1161 行）。**
它经过完整流程（四候选评优 + 异议轮 + 独立验收），是本仓最贵的资产之一。
五份提案稿在「agent 怎么干活」这一块**全都不如它**，具体差在：

| 它有 | 五份稿 |
| --- | --- |
| §5.1 写入前门禁五条（`cwd == workspace_path`、分支、解析软链后仍在 writable root、目标路径无他人产物、不得宽泛写入） | 零 |
| §5.5 checkpoint 字段清单 + 判据「把当前会话杀掉，另一个执行者只读持久载体能否接着做」 | 只说「持久化 checkpoint」 |
| §7 产出物与 commit 全生命周期，220 行九个子节 | 零 |
| §9 权限公式（**租约是条件项，不是无条件交集**）+「只有有权主体能做」六行表 | 散在各处的规则 |
| §6.4–6.8 候选隔离、角色分离、评审裁决选优、改进整合回归、停止规则 | 一句论断 |
| §5.2 上下文路由表 + 四级能力词典 `defined / wired / deployable / runtime-verified` | 零 |

**以下小节一字不许改写**（只可在其后追加增量小节）：
§5 执行内核、§7 产出物与 commit 全生命周期、§12 完成判据、§13 反模式、
§14 常见失败方式与项目实例、附录 A 词汇对照、附录 B 持久记录模板。

**撞车一律以基座为准。**五份提案稿里凡是重述 Task/Attempt/四本账/状态机/验收矩阵的
部分，**一律以 `request-lifecycle.md` 为准，不采信、也不重写**——那些重复是 09-02 的
时间差造成的，不是有效内容。这一条能替你砍掉大量无效阅读。

## 8. 要加进去的七块

基座通篇**执行器无关**：`harness` 0 次、`deepseek` 0 次、`openclaw` 0 次，
唯一一处 `codex` 是顺带提 `CODEX_HOME`。它 08-31 起稿时 dsh 还不存在。要补：

| # | 内容 | 主要来源 |
| --- | --- | --- |
| 1 | **路线转向**：执行层为什么租不自建；「自研 vs 租用」是假二分，真问题是在哪一层自研；比原体系更好吗（分方向 / 当前成熟度 / 满足门禁后三层判断）；「更好」成立的硬条件 | luna §19、opus 第二部分、kimi、cursor、qwen §10 |
| 2 | **两个执行 SDK 的核实事实与能力不对称**：逐条带 `file:line` 锚点；能力不对称必须写进 Port，不许假装对称 | kimi §1、opus §5.3、luna §5、qwen §2 |
| 3 | **统一执行 Port**：签名、通用 DTO、Adapter 职责边界、**能力探针是三态不是布尔**（available / explicit_unsupported / implicit_fallback） | luna §8、opus §15.1⑤、cursor |
| 4 | **Harness SDK 前置门禁**：要补哪些 wire 方法与 trusted context 字段；必须由 Harness 上游正式实现，不许私自复制协议类型；**门禁未过期间的补法**（杀进程取消 + `submit_result` + 分层审批）及其代价 | luna §9、kimi §4 R1–R3 |
| 5 | **双 runtime 的部署与进程模型**：运行角色拆分、四条硬阻断、SDK 进程纪律（prefork 后创建、不跨 fork 共享、teardown ladder）、**执行现场快照到对象存储与 restore 续跑**、恢复有界（`max_attempts` + Profile 版本熔断） | opus §4/§6.3、kimi R5/B5、luna §13、qwen §6 |
| 6 | **门禁、凭据与审批**：三道门正交（Tool Policy / Execution Scope / Approval Policy），deny 优先、allow 非空即默认拒、工具门是硬停；**被拒绝的工具应当不存在而不是存在但被禁**（会话组装层 + 网关层双层）；审批分级四档（`llm-review` 必须落账否则等于自我批准）；审批绑定产物哈希、漂移即作废、超时 fail-closed；**推理经代理，真 key 不下发到 harness 进程**；Attempt 级短 TTL 网关令牌 | kimi B2–B4、opus §15.1③④、cursor §3.3、qwen §11.4 |
| 7 | **OpenClaw Gateway：借鉴，不转向**：它到底是什么（两层路由都不是语义分类）；该借的机制逐条映射到我们的落点；**为什么不转向**（租户模型、存储、技术栈、`sandboxing off by default` 的危险默认、它自己 `VISION.md` 反对重编排层）；明确不借的清单（含 `elevated` / `full` 逃生门） | kimi 第 2 节 B1–B5、luna §20–21、opus 第三部分、qwen §11、cursor §3.3–3.4 |

## 9. 三件必须解掉的结构问题

### 9.1 supervisor 同名不同物 —— 硬要求

```text
基座 §6「Agent 作为 supervisor」
  → supervisor 是一个 Agent，在 Attempt 内部拆 Work Unit、派工、收候选、选优整合

五份提案稿「Supervisor 不是第三个自由 Agent」
  → Supervisor 是应用层确定性代码，在 Attempt 之上建单、路由、管预算
```

**两个不同层的东西共用一个名字。**不消歧就直接合并，新加的内容会和 §6 读成互相打脸。

要求：给两层各自定名并写清关系。至少讲清内层 supervisor 是**在上层已经路由完、权限已经
收窄之后**才存在的——它不能改路由、不能换执行器、不能扩权。这与基座 §9
「supervisor 不因协调职责获得任何有权主体的动作」是同一条纪律的延伸。

顺带：**「Supervisor 必须是确定性代码，不能是模型」是五份稿里唯一比基座多出来的论断**，
五家一致，理由三条（路由错的代价不对称、不可解释、分类调用自己也要预算而预算账引用数
为 0）。它正好是消歧的落点：上层是代码所以确定，内层是 agent 所以要被门禁箍住。

### 9.2 `F-EXEC-*` / `F-INTERACT-*` 逐条映射到两条腿 —— 必交

`request-lifecycle.md` §9 责任投影里写着「Agent / runtime 负责 `F-EXEC-*`」。
现在的答案是「租来的 Codex 或 dsh」——而 luna 已指出 dsh 缺 `F-EXEC-03`（每次高风险动作
重新授权）和 `F-EXEC-05`（进程死亡后 checkpoint 恢复）。

**产品契约里已登记的功能项，在其中一条执行腿上落不了地。**必须交一张表：
逐条列 `F-EXEC-*` / `F-INTERACT-*`，标出在 Codex 腿、dsh 腿各是「已支持 / 当前缺失 /
需补法」。有了它，「dsh 门禁过不过」才是可判定的，而不是一句定性。

### 9.3 基座的存续声明要重估

基座 §11.1 写着「本文是开发期文档，开发结束后可能删除；human 那份长期保存」，
§11.2 给了三个删除条件与删除时的引用清理表。

新版装进执行器架构判断后，这两节必须重写：要么给删除条件加一条（这两块先移出或已被
`development-plan.md` 吸收才可删），要么改判它的存续性质。**你选哪条都行，但必须显式
处理，不能沉默地留着一份自相矛盾的存续声明。**连带 `development-lifecycle-human.md`
头部两处、`request-lifecycle.md` 三处引用、`AGENTS.md` 第 22 行的措辞是否要跟着改，
在文末列出清单即可，本轮不要求你去改那些文件。

## 10. 明确不要写进去的

**任何具体 Profile 的字段表。**指南写**怎么建**，不写**建成什么样**。

- **该写**（对任何专用 Profile 都成立的方法）：专用 Agent = Profile/patch + 插件，
  不 fork runtime、不改 agent loop；工具必须逐条声明安全边界；规划与执行分离
  （dry-plan 只出可审计计划，query 才执行）；结果必须经一个显式工具提交，未提交不算
  Attempt 完成，且提交成功只产生候选、validator 说了才算；两条腿凭据互斥。
- **不该写**（某一个 Profile 的实例）：`investment-finance-analysis-v1` 的六个工具表、
  `financial_query` 的行数上限、`knowledge_retrieve` 怎么绑 dataset、20–50 道金标准。

理由不止「越界」：`request-lifecycle.md` §7.2 明写**每个 Profile 的第一项开发工作单元
必须用真实输入确认字段，之后才发布首个版本**；而业务数据现在是 0 张表（见 §4 ⑧）。
那些工具表从没跑过一次真实输入，**写进开发指南等于把未验证的设计固化成纪律**。

「用 dsh 具体构建几个专业 agent、每个装什么、角色怎么分」是下游另一条线的题
（提案稿里已有对立主张：luna 主张首版只建一个窄 Profile，qwen 主张用 preset 白捡
analyst/checker/awaiter 三角色）。**本轮只留判据，不做决定**，并在文末写明那条线的前置是
财务数据源与 Gate 0 spike 结果。

## 11. 输入材料

**必读**

```text
working/request-lifecycle.md                 产品契约，原则层，不动
working/development-lifecycle-agent.md       基座
constraints.md                               A/C/D/I/T/R 规则
development-plan.md                          方向
五份提案稿（§2.1 表格里的全部）
```

**参考**：`~/repo/codex`、`~/repo/deepseek-harness`、`~/repo/openclaw` 源码；
`~/codex-reference-archive/`（各家历史调研，已归档可直接读，引用时注明是谁的稿）。

## 12. 验收标准

1. **基座 §7 保留的部分逐字未改**；不许动的清单（§7）全部成立。
2. **§8 的七块内容全部到位**，每块的核心断言带 `file:line` 或可复跑命令锚点。
3. **新增内容必须用 `F-*` / `I*` / `AT-*` / `constraints.md` 的 A/C/D/I/T/R 编号锚定，
   不许写成散文。**（上一次整合栽在这里。）
4. **交出 §9.2 的两条腿映射表。**
5. **supervisor 消歧完成**，新版内不存在两处「supervisor」指代不同层而未说明的情况。
6. **§9.3 的存续声明已显式处理**，并附引用清理清单。
7. **没有任何具体 Profile 的字段表**（§10）。
8. **不重新定义 `request-lifecycle.md` 已定义的对象**：Task、Attempt、Interaction、
   Artifact、Event、Side Effect、Delivery、四本账、I1–I15、AT-01…AT-22 一律引用，不重写。
   参照 `development-lifecycle-human.md` 头部的写法。
9. **`dsh 需要系统 Node` 这个已推翻的说法不得出现**（§4 ③）。
10. **「能不能构建专业 agent」与「能不能接进生产控制面」两个轴分开表述**，不得混成一句。
11. 未验证的结论标注清楚。做不成的老实标 ⚠，不假装已门禁化——这是基座 §11.1 立的规矩。

## 13. 本轮的角色

**流程本身见 [`round-protocol.md`](round-protocol.md)**——六个环节、产物落点、冻结与
枚举方式、评审四块、裁决与验收规则、清理顺序，全在那份里，本节不重复。
**动手前先读完它。**

本节只写本轮特有的：

| 角色 | 谁 |
| --- | --- |
| 提案方 | **luna / kimi / cursor / qwen3.8 四家** |
| 评优方 | 同上四家 |
| 裁决与整合方 | **opus**（本轮不出候选、不写评审，不参与验收） |
| 验收方 | 裁决稿完成后由 opus 指定，规则见 `round-protocol.md` §6 |
| 确认方 | 项目所有者 |

**本轮的共享最终路径**是 `sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`，
所以候选的枚举形状固定为：

```text
~/worktrees/*/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
```

评审文件为 `working/refact-review-<你的名字>.md`。

### 13.1 opus 的利益声明

opus 的 2026-09-02 旧稿
（[`investment-agent-architecture-opus.md`](investment-agent-architecture-opus.md)）
是本轮五份输入材料之一。**opus 本轮不出候选、不写评审，但在裁决时会读到自己的旧稿。**

因此额外约束：

1. 凡采纳 opus 旧稿的主张，处置记录必须写明**它比另外四家好在哪**，不得只写「作者判断」；
2. opus 旧稿与其他家冲突时，**默认采纳对方**，除非有可复跑的取证支持 opus 那一侧；
3. opus 旧稿里已知有一条被推翻（§4 ③ 的 Node 阻断），整合时不得以任何形式复活。

§3 列的那次失败整合，五条毛病全部源于角色不分，反例记在
[`round-protocol.md`](round-protocol.md) §8。
