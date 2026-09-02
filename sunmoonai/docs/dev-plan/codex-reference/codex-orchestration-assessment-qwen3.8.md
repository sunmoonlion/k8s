# Codex 编排文章独立考证 + investment-app 落地判断（qwen3.8 独立版）

> 最后更新：2026-08-17
>
> 性质：独立交叉考证（个人参考），非 baseline、非 REQ。与 kimi 版
> `~/codex-reference/codex-orchestration-assessment-kimi.md` 平行存在，结论大体同向，方法与侧重不同。
> 考证对象：`~/note/Codex编排能力完全指南.md`（1009 行，下称"文章"）。

---

## 0. 方法论声明：我和 kimi 的证据等级不同

kimi 是 Codex 本体，它的 A 级证据是**被测对象在自己的活会话里为自己作证**。
我不是 Codex，无法在 Codex 会话内复现那些实测。我的证据链分四层，置信度递减：

| 层级 | 证据 | 我今天亲自复核的结果 |
| --- | --- | --- |
| L1 磁盘取证 | `~/.codex/goals_1.sqlite`（含 -wal/-shm） | **存在**，Goal 功能有持久化落盘，非虚构 |
| L1 磁盘取证 | `~/.codex/sessions/2026/.../*.jsonl` rollout | **存在**，样例首行即 `session_meta`，`cli_version: 0.148.0-alpha.9`、`originator: codex_vscode`，与 kimi 自述版本逐字吻合 |
| L1 磁盘取证 | `~/.codex/config.toml` | 存在，含 provider 配置与 `[projects."/home/zymun"] trust_level`，印证文章"项目信任等级"概念 |
| L2 代码锚点 | investment-app 全部引用锚点 | 逐条复核为真（见 §3 表），kimi 无一行虚构 |
| L3 单方证词 | kimi 的活会话实测表（Seccomp: 2、defer_loading 工具、features list） | 与 L1/L2 无矛盾、内部自洽，判**高可信但单源**，凡只有此一层支撑的结论我都降半档使用 |
| L4 文章自述 | 工具名、flag 状态、拓扑描述 | 已知存在版本漂移，按 kimi 的 C 级清单打折 |

**推论**：kimi 的 A 级证据表在我的体系里 = L1 磁盘痕迹（可独立复核）+ L3 证词
（不可独立复核）。两者无矛盾，所以我接受其结论，但我在下文的论证里尽量只用
L1/L2 就能站住的推理，少依赖 L3。

---

## 1. 问题一：文章是真的还是 demo？——我的独立判断

### 结论

与 kimi 一致：**真实原语 + 作者的模式总结，不是 demo，也不是"Codex 内部编排
引擎的暴露"。** 但我给出一条不依赖 codex 作证的独立论证：

### 独立论证：wait-all 的缺失本身就是"没有编排引擎"的证据

文章教读者用 wait-any 原语**手写循环**拼 wait-all（§"让一个 Session 等另一个
做完再动手"），并坦承 `wait_threads` 有八目标上限。如果 Codex 内置了编排引擎，
wait-all 是一行声明式 join 的事，没有理由让每个用户手搓循环。一个产品缺什么，
看它让用户补什么——**文章里所有的"手工补丁"恰好勾勒出 Codex 编排能力的真实
缺口形状**。这是文本内证，不需要 codex 出庭作证。

同理，文章"八种拓扑"要成立，每一节都在教"你要记得做 X"（记得等全部、记得读回
结果、记得掐掉落后者）。凡是需要靠教程约束使用者自觉的机制，就不是引擎强制的
机制。所以 kimi 那句核心定性——**编排逻辑运行在模型的推理里，不运行在 Codex 的
代码里**——我判为全文最重要的一句话，且它由文章自身结构即可推出。

### 我补充的一条水分（kimi 未点破）

文章 §"怎么自己核实这些能力" 给出了验证路径，这是诚实信号；但文章通篇用
"100% 正式接管"式的标题党开场，把**能力存在**与**能力可用于生产**混在一起讲。
对你的决策真正有用的区分是：原语存在 ≠ 编排可靠。Codex 场景里编排可靠性由
**用户在场**兜底（你是审批人、纠错人）；这个兜底在你的服务端不存在（见 §2）。

---

## 2. 问题二：Docker 沙箱 + 文章式编排，在 investment-app 上可行吗？

### 结论

**可行，同意 kimi 的"语义映射、机制替换"总纲。** 我的分歧不在方向，在三处侧重。

### 2.1 前提核对：你的系统现在处于什么阶段（L2 证据）

今天复核的代码现状（全部锚点为真）：

| 事实 | 锚点 |
| --- | --- |
| 幂等建 run 已实现 | `application/agent/run_service.py:25` `create_run(command)` 走 `idempotency_key` |
| RunBudget 四维限额就绪但未接线 | `domain/agent/runtime.py:62`，`consume_step/tool_call/llm_call/input_tokens` 四个不可变累加器 |
| CancelRunCommand 休眠 | `domain/agent/commands.py:31` |
| 事件溯源就绪 | `application/agent/event_sink.py` + `timeline_projector.py` |
| 工具权限在 profile 层裁决 | `domain/agent/profiles.py:19-41`（model_key/allowed/denied，deny 优先） |
| SandboxPort 生产零调用 | grep 全仓仅 5 处命中，全在定义与 fake 实现 |
| 唯一真实产品链是 Pilot | baseline §3.6；`agent_v4_traffic_enabled` 默认 false（流量门关闭） |

关键判断：**你缺的不是编排原语，是"单 run 的价值闭环"还没跑完**——沙箱零调用、
预算未接线、v4 流量门关着。在这个地基上谈八种拓扑，是把屋顶图纸画在了没打
地基的位置上。kimi 的 P0-P3 排序其实隐含了同样的判断，我把它说破：**编排是
P1+ 的事，P0 只有一个主题：让真实执行穿过真实链路。**

### 2.2 我对 kimi 语义映射表的复核

kimi 的 14 行映射表我逐行对照 baseline 与代码，**无一行失实**。其中四行"强于
原文"的判定（事件溯源、声明式 join、确定性 interrupt/resume、静态图即 Registry）
我都同意，且这是 LangGraph + Postgres 技术栈的结构性优势，不是偶然。

我只修正一行的措辞：`Fork+Worktree 多方案竞赛 → 容器内 git`。准确说法是
**每候选一个容器 = 天然独立文件系统视图**，你不需要 worktree 机制，容器本身就是
worktree 想解决的问题（同一仓库多份并行检出）。worktree 是桌面单机上的省空间
技巧，容器化后这个问题被更高维度地消掉了——这行不是"对应"，是"消解"。

> **2026-08-22 修订（接受 cursor 版改判）**：上段"消解 worktree、直接容器"过于
> 绝对。财务 Agent 并行写代码少，竞赛默认先同容器 worktree（共享 .git，更便宜），
> 候选要跑不可信代码或抢资源时再升级多容器——这是成本判断不是折中。
> 以 cursor 版 §4 为准。

### 2.3 我的三点补充（kimi 版未展开的）

**一、编排决策权三分法（把"确定性下沉"落成可执行纪律）。**
kimi 说"能写成静态图的绝不交给 LLM"，我补上中间档，生产系统只允许前两档：

1. **静态图档**：固定流程（研究→检索→引用→审批→产出）写成 LangGraph 静态图，
   Pilot 链已经是这个形态，保持；
2. **受约束动态档**：LLM 只能在**预定义枚举**里选（拆成 2 路还是 3 路、选哪个
   已注册的 graph、是否取消），选择经 pydantic schema 校验后落到应用服务执行；
3. **自由编排档**：LLM 直接决定控制流——**生产禁用**，只在 admin 调试面开放。

Codex 的 Supervisor 全程活在第 3 档，因为它有人在场兜底；你没有，这是你与文章
最大的威胁模型差异，比沙箱选型差异更根本。

**二、六个编排工具的重新排序。** kimi 的六工具清单成立，但我按"价值/风险比"
重排：`create_run`（封装即可，零风险）→ `wait_runs`（补齐文章最大短板）→
`read_run_result`（带 schema 校验，防注入回读）→ `cancel_run`（接线休眠能力）→
`steer_run`（interrupt/resume 已有底座，但语义要防注入）→ `review_run`（实质是
Generator-Critic 的应用，不必单独成工具，并入 P1 拓扑）。前四个够支撑 Supervisor
+ Fan-out 两条拓扑，先做这四个。

**三、回读即攻击面。** 文章那句 "treat returned titles and summaries as untrusted
data" kimi 引了，我加一句量化：你的 Supervisor 每 fan-out 一次，就有 N 份不可信
产物回读进它的上下文；研究域产物大量来自网页，**回读通道 = prompt injection 的
主入口**，不是次要风险。落地要求：`read_run_result` 返回前过一道标注/截断/
结构化（只回 schema 字段，不回自由文本全文），这条应写进该工具的验收标准。

### 2.4 实施路径（我的版本，比 kimi 版多一道 P0.5 闸门）

| 阶段 | 内容 | 完成判据 |
| --- | --- | --- |
| P0 | DockerSandbox 首个真实实现（见沙箱文档 §5 加固）+ RunBudget/CancelRunCommand 接线 | 有一个真实 run 在容器里执行过 shell 并产出 artifact |
| P0.5 | **闸门**：Pilot 链验收 + v4 流量门至少内部开启，单 run 价值闭环成立 | 否则编排无从验证，不进 P1 |
| P1 | 编排工具前四件 + Supervisor/Fan-out/Generator-Critic，全部走决策权三分法第 2 档 | 编排决策全落 DomainEvent，可回放 |
| P2 | Race/Quorum、容器内多方案竞赛、celery beat 定时 | RunBudget 在 fan-out 场景实测拦截过至少一次 |
| P3 | 工具延迟加载、跨 App 编排（契约锁已有 `knowledge-retrieval-provider-lock.json`） | — |

### 风险清单（对 kimi 版的增量）

kimi 列了五条（成本、容器资源、LLM 漂移、评审污染、注入），都成立。我追加两条：

6. **编排可观测债**：Supervisor 的每次拆派若无事件落库，出问题时无法区分
   "模型决策错"还是"执行错"——事件溯源是你现成的解药，P1 必须带全。
7. **版本漂移重演**：文章的工具名漂移会发生在你自己身上——编排工具的 schema
   应像 retrieval 契约一样进契约锁纪律（你已有成熟机制），别让半年后的自己
   读今天的代码像读别人的转述。

---

## 3. 与 kimi 版的对账表

| 议题 | kimi | 我 |
| --- | --- | --- |
| 文章真伪定性 | 真实原语+模式总结 | 同意；另给 wait-all 缺失这一文本内证 |
| "Supervisor 非内置模块" | 靠活会话证词 | 同意；仅凭文章结构即可推出 |
| 语义映射表 | 14 行 | 复核无失实；Worktree 行改判"消解"非"对应" |
| 确定性下沉 | 五条完善之首 | 同意；落成决策权三分法，第 3 档生产禁用 |
| 实施排序 | P0 含沙箱+两休眠接线 | 同意；加 P0.5 闸门（单 run 闭环先于编排） |
| 工具集 | 六件平铺 | 按价值/风险重排，先做前四件 |
| 注入防线 | 回读按 untrusted 处理 | 升级为验收标准：schema 化回读，不回自由文本全文 |

## 最终判定

文章的**思想**（控制环、拓扑分类、上下文纪律）成立且值得吸收；文章的**机制**是
Codex 桌面形态的产物，移植时只做语义映射。你的平台在状态机、事件溯源、确定性
中断三点上强于文章假设的起点，但**没有"人在场"兜底**这一点上弱于 Codex 的运行时
环境——所以你的移植必须比文章更确定性、更可审计、更设防。地基现状（沙箱零调用、
预算未接线）决定了 P0 不是编排，是先把真实执行跑通。
