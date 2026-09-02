# investment-app Agent 总体架构设计（kimi 版 · 四份研究的收敛）

> 最后更新：2026-08-22（独立修订：预算三件套、run 内压缩、push 通道语义修正、
> watcher 角色、竞赛题干固化、建设顺序双轨化。依据均为本轮自行复核的源码锚点
> 与逻辑推演，见 §9；仓库路径已随迁移更新为 ~/master/）
> 同日二修：§4 末补"生路与熟路的编排纪律"（含固化触发与降级通道）。
> 同日三修：收敛第四份研究（SQLBot 评估）——术语库、示例 few-shot、图表 SSR、
> MCP 外放四机制吸收进 §3/§4/§6/§7/§8；路线不切换（Wren 语义层受管 SQL 不动）。
> 同日四修：立 §0 总纲"一套地基、两种形态、不建两套系统"（用户确认为最重要
> 建设纪律），§2 验收加第 9 条，§4/§8 同步交叉钩住。
>
> 性质：总体设计（个人决策底稿），非 baseline、非 REQ；立项时按治理规则走 REQ。
> 本文是四份研究的收敛点，引用而不复述：
> - `~/codex-reference/codex-orchestration-assessment-kimi.md`（编排框架：语义映射、Supervisor 工具集、八拓扑）
> - `~/codex-reference/codex-dynamic-graph-findings-kimi.md`（源码追踪：动态图三问的源码答案）
> - `~/codex-reference/wrenai-financial-analysis-integration-kimi.md`（WrenAI 问数能力与集成边界）
> - `~/codex-reference/sqlbot-kimi.md`（SQLBot 评估：prompt 链 + RAG 校准路线，
>   四样机制借、两样不借，自研设计在此收敛）

---

## 0. 总纲：一套地基，两种形态，不建两套系统

> 2026-08-22 用户确认为最重要建设纪律。立项第一天就要守，不是某个阶段的
> 实施细节——等读到 §4 的人可能已经在画第二套系统了，原则必须在开头拦住人。

**要分的：执行形态和建设顺序。**

- 图的形态分开建：熟路每种任务类型一张静态图（问数主链第一张，持仓体检、
  复盘随后）；生路是 Supervisor 通用循环 + 编排工具集。两者代码形态完全不同，
  不该互相迁就。
- 建设顺序分开排：先让熟路单 run 闭环成立（真容器、预算、取消接线），再放
  生路进来。顺序反了的代价：生路在没有预算/事件/HITL 的地基上自由生长，
  事后补治理要拆骨头。

**不能分的：地基只有一套。**

- 同一个 LangGraph + PostgresSaver：熟路是编译图，生路是图里的循环节点，
  不是两个引擎。
- 同一套 RunBudget 三件套、DomainEvent 审计、结果契约（schema + artifact）、
  HITL、角色配置、run 内压缩。
- 同一个 Run 实体：生路 run 和熟路 run 必须能在同一条 timeline 上一起回放——
  审计一断成两截，"决策必过人"（§5）的红线就失去回放依据。

**传送带第一天就埋**：产物 schema 落事件流（固化候选的数据源）+ 路由未命中
落事件流（新任务类型雷达）。这两样不埋，将来固化只能靠翻聊天记录考古
（机制见 §4 固化传送带与路由雷达）。

一句话：不是"分别构建两个 agent"，而是一套地基上先后长出两种执行形态——
**熟路先行、生路随后、契约相通、热了固化**。落到 §8：双轨（问数 spike +
执行闭环）→ P1 第一张熟路图 → P2 才开生路（Supervisor 工具集）。

## 1. 先回答：为什么源码公开，多数人还是做不出 Codex 水平的 coding agent？

源码能抄的和抄不到的，分得很清楚：

1. **机制在源码里，智能不在**。"何时该拆任务、子任务指令怎么写、跑偏了怎么收"——
   这些行为是模型权重里的，由 agentic RL 训练塑造。repo 里没有模型、训练数据、
   奖励模型。抄到骨架，抄不到判断力。
2. **源码告诉你"是什么"，不告诉你"为什么是这个"**。`session_prefix.rs` 里错误截断
   的 token 策略、`ERROR_NEXT_ACTION` 的措辞、wait-any 收割已完成项的写法——上千个
   微决策各自有一段失效史。抄骨架抄不到决策上下文，踩坑一个都少不了。
3. **机制与模型是 co-design**。工具粒度、prompt 结构、上下文预算都围着自家模型的
   强弱设计。换 DeepSeek/Kimi/Qwen，最优解平移——照抄的工具 schema 在别的模型上
   不一定是最优形状。
4. **可靠性的复利在长尾**。demo 到产品的距离是：重试、断点恢复、预算、沙箱、会话
   重建、compaction、背压……这些"无聊的 80%"恰恰公开源码里最不性感的部分。
5. **评估缺位**。没有 eval 集，改了什么、好没好，自己都不知道。OpenAI 有内部 eval
   和真实使用遥测，照抄者两者都没有。
6. **移动靶**。本 repo 的 feature flags 与三个月前的文章描述已多处漂移
   （`enable_fanout` 已 removed）。照抄者永远在追一个移动目标。
7. **但对你的好消息**：垂直领域 agent 不需要成为通用 Codex。源码的最大价值是
   **机制祛魅**——知道什么不用建（DAG 引擎）比知道建什么更省钱。这就是 §2 的起点。

---

## 2. "完美"的操作定义（验收式，可逐条打勾）

agent 建得好不好，不看感觉，看这九条：

1. **每条依赖边能说出为什么是静态/动态**——固定业务流程全在静态图，动态只发生在
   骨架内的受控 spawn 循环；没有"说不清为什么交给 LLM"的边。
2. **每个子任务隔离上下文、返回格式可校验**——子任务的产出要么是结构化
   outputSchema，要么带 artifact 引用；不接受自由文本直接进入下游。
3. **每次编排决策可审计**——fan-out、取消、重派、审批全部落 DomainEvent，
   timeline 可回放。
4. **每次 LLM 调用有预算闸门**——RunBudget 接线，超限是事件不是惊喜。
5. **每个数字可溯源**——分析结论挂 citation/evidence 到 artifact；财务数字能指回
   具体 SQL 与数据源。
6. **每个错误能恢复**——checkpoint 恢复 + 幂等重跑，不让用户重头来。
7. **有评估集**——金标准问题集先行，任何编排/prompt/模型改动可回归对比。
8. **长 run 不怕上下文**——有阈值触发的 run 内压缩：摘要必须保住数字、SQL、
   evidence_id，推理过程可丢；压缩本身落 DomainEvent。财务 run 必然长，这条不是
   优化是生存条件。
9. **熟路生路不建两套系统**——任意 run（不论静态图还是通用循环）都能指回同一套
   L0/L5 组件；生路产物 schema 与路由未命中都能在事件流里查到
   （§0 总纲的可验形态）。

## 3. 分层架构

```text
L5 治理层   RunBudget 三件套 │ DomainEvent 审计 │ timeline 回放 │ 身份权限
L4 质量层   Generator-Critic(dry_plan) │ 独立评审 │ HITL interrupt │ 金标准评估
L3 能力层   Wren 六工具(受管SQL) │ SandboxPort(任意代码) │ 知识检索 │ 资讯 │ 术语检索(口径映射)
L2 动态层   Supervisor meta-agent + 编排工具集 │ Send fan-out │ 双通道结果回注
L1 领域骨架  静态图：取数→校验→分析→评审→产出（财务工作流知识在此）
L0 运行时   LangGraph + PostgresSaver + celery + outbox + event_sink（已有）
            └ 补：run 内压缩（阈值触发、领域摘要模板、压缩落事件；跨层服务所有长 run）
```

每层职责与机制来源：

| 层 | 职责 | 机制来源 | 落点 |
| --- | --- | --- | --- |
| L0 | 持久化执行、事件、恢复 | LangGraph 原生 + 已有基建 | `infrastructure/graph/`、`application/agent/` |
| L1 | 财务分析的确定性主链 | **自建**（领域知识，Codex/WrenAI 都没有） | `infrastructure/graph/` 新增 analytics 图 |
| L2 | 动态任务拆解与并行 | Codex 源码机制（spawn/wait/状态通道）语义映射到 LangGraph | Supervisor 图 + 编排工具集（六工具，见 assessment） |
| L3 | 受管能力调用 | WrenAI SDK（SQL）+ DockerSandbox（任意代码）+ 术语服务（口径映射资产，SQLBot 机制自研版）+ 现有契约 | `infrastructure/analytics/`、`infrastructure/agent/` |
| L4 | 正确性与独立性 | `wren_dry_plan` + detached review + interrupt HITL | 图内 critic/approval 节点 |
| L5 | 成本、审计、权限 | RunBudget 三件套（入口预留+全树账本+提醒阶梯）+ DomainEvent/timeline | `domain/agent/runtime.py` → 生产链 |

## 4. 任务类型扩展模型（"以后不止问数"怎么接）

**一句话：入口通用，执行分档，成长靠固化。**

先破除一个误会：Codex"什么任务都能接"的通用性，来自通用工具基座（shell/文件/
浏览器）+ coding 域内训练，**且只在 coding 域成立**——它没有财务语义层和受管数据
通道，接不了财务活。财务域的正确性要求通用性必须经受管能力导流，这是领域属性，
不是静态图的限制。

investment-app 的对应结构：

1. **通用入口（Supervisor）**：任何任务都能接。没有匹配的执行档时，Supervisor 用
   通用循环（模型推理 + L3 工具 + 沙箱）自己处理——但永远套着治理壳
   （RunBudget / 审计事件 / HITL）。治理壳的验收标准一句话：**通用循环档跑出的
   每个 run 都能在 timeline 上完整回放，且全树共享一本预算账**。
2. **执行三档（频谱）**：

   | 档 | 适用任务 | 形态 |
   | --- | --- | --- |
   | 静态固化图 | 高频、高风险、已稳定（问数主链） | LangGraph 编译图：确定性最强、成本最低、可审计 |
   | 骨架 + 动态点 | 半结构化（公司分析） | 骨架固定，fan-out 几路运行时定（Send API） |
   | 通用循环 | 开放任务（新任务类型的第一天） | Codex 式 spawn 循环 + 治理壳 |

3. **成长路径：动态 → 静态的固化**。新任务类型从右端（通用循环）进入；跑量之后，
   L5 的编排事件流就是"固化候选雷达"——热路径浮现即固化为静态图。固化决策数据
   驱动，不靠拍脑袋。
4. **四个扩展点**：新工具（L3，所有档受益）/ 新静态图（新 run 类型，模板化、
   成本递减）/ 新动态点（现有图加 Send 位）/ Supervisor 路由表（意图 → 执行档）。

示例——"研报解读"任务类型的生命周期：

```text
第 1 天：无专门图 → Supervisor 通用循环 + 知识检索工具处理（能跑，但贵且不稳）
第 50 次 run 后：事件流显示热路径（拆章节 → 提要点 → 对比库内观点 → 生成摘要）
固化：写成静态图，移入"静态固化"档（成本降、可靠性升、可审计、可回归）
```

所以"静态图怎么扩展"的答案是：**静态图从来不是系统的天花板，而是成熟任务的
固化形态**；系统的通用性由 Supervisor 入口和通用循环档保留，与 Codex 同源。

### 生路与熟路的编排纪律（2026-08-22 二修补；§0 总纲的展开——以下全部建立在"一套地基"上）

**熟路三条（目标 = 确定性）**：

1. **边是代码不是提示词**：依赖关系全部显式写在图定义里，LLM 只做节点内推理，
   不参与路由。
2. **退出看契约不看自述**：每个节点带出口 schema；一条 run 算完成，是因为各节点
   schema 校验通过，不是因为模型说"我做完了"。
3. **每图配 eval 集，改图必回归**（§2 第 7 条落到图粒度）；口径资产（MDL/术语库/
   示例库）变更同走回归——口径资产改了不回归，等于图改了不回归。

**生路三条（目标 = 可控的探索）**：

1. **治理壳**（§4 已立）：timeline 可回放 + 全树一本账。
2. **预算梯度**：生路 run 的根预算刻意收紧（低于熟路折算成本的某个系数），提醒
   阶梯更早触发——让"待在生路"保持不舒服。雷达（事件流）告诉你**该固化什么**，
   预算梯度告诉你**什么时候必须固化**；只有雷达没有压力，固化永远排在"有空再说"。
3. **HITL 的性质两档不同**：熟路的 HITL 是设计时钉死的 checkpoint（决策点必过人）；
   生路的 HITL 是运行时兜底——产出无 schema 就停下来问人。

**固化传送带（生 → 熟）**：

- 三种材料缺一不可：**拓扑**来自事件流里反复出现的节点序列；**契约**来自产物里
  稳定下来的 schema；**验收**来自该任务类型累积的 run 样本转 eval 集。固化不是
  重写逻辑，是把已涌现的路径钉死。
- 量化触发（防拍脑袋）：同型任务频次过阈 + 生路单次成本 ≥ 静态预估的 N 倍 +
  产物 schema 连续 M 次无漂移，三者同时满足才立项固化。
- **反向降级通道**：静态图 eval 准确率持续下降（上游 schema 漂移、业务口径变更）
  → 退回通用循环重新探索，不在旧图上打补丁。固化是维护不是加冕。

**路由与雷达**：Supervisor 路由表判档，未命中落通用循环；**未命中本身也落事件
流**——它是"新任务类型出现"的最早信号，也是路由表写错的报警器。

## 5. 投资管理主战场（问数之外的全景）

定位：问数是**感官**（数据获取能力），投资管理才是**主战场**。投资主循环：

```text
研究 → 观点(thesis) → 决策 → 持仓 → 监控 → 复盘 →（修正）回到研究
```

六环节在架构中的落点：

| 环节 | 任务示例 | 执行档（§4 三档） | 关键依赖 |
| --- | --- | --- | --- |
| 研究 | 公司/行业/宏观分析 | 骨架+动态点 / 通用循环 | 三源证据：Wren 取数、knowledge 检索、info 资讯 |
| 观点 | thesis 形成与记录 | Generator-Critic + HITL | 独立评审；thesis 落 artifact（带时点） |
| 决策 | 投决备忘录、买卖建议 | 静态骨架 + Critic + **人工拍板（硬性）** | 人机分工红线：系统建议、人决策 |
| 持仓 | 组合体检、敞口/归因 | 静态固化图（可周期跑） | 持仓/交易数据域（新增） |
| 监控 | 公告事件、基本面变化、异动预警 | L5 主动服务：beat/事件触发 run | info-app 采集类型扩展、行情数据域（新增）；**watcher 角色盯梢**（便宜模型只等待与报告，贵模型触发后才介入，否则监控成本失控） |
| 复盘 | thesis 事后验证、绩效归因 | 周期静态图 | 决策 artifact + 时点数据对比 → 学习闭环 |

新增数据域——L3 数据供给从"财务库"一域扩为四域：

1. 财务/基本面库（问数，Wren MDL 建模）
2. 行情时间序列（价格、量、估值水位）
3. 持仓与交易账本（自己的记录，复盘与归因的源头）
4. 公告/事件流（info-app 扩采集类型）

研究资产（thesis/memo）本身入库，knowledge-app 契约可能随之扩展。

两条原则因投资管理升级：

- **决策必过人**：投决点的 HITL 从"可选增强"变为"硬性红线"——系统建议、人拍板，
  这是责任边界，不是体验设计。落成机制而非口号：**决策类 run 的终态必须由 HITL
  事件触发**（LangGraph interrupt/resume 已有底座）；决策 artifact 必须携带
  **证据快照 id**——复盘用当初看到的证据对比事后数据，不用今天的重新检索，
  否则复盘失真。
- **审计从好功能变必需品**：谁在何时基于什么证据做了什么决定，全程可回放——
  DomainEvent/timeline 的权重显著上升。
- **时间成为一等公民**：thesis 有时效、复盘要对时点，数据模型需要 as-of 语义。

与 v5 的呼应：research-app → investment-app 的改名正是这次扩张的先声；v5 已写的
HITL / 审计 / 恢复要求，全部指向这里。

## 6. 关键机制决策表（每条：借鉴谁、为什么、落在哪）

| 决策 | 借鉴 | 理由（源码/研究依据） | 落点 |
| --- | --- | --- | --- |
| 静态图为主体（L1 骨架一字不动）；不建"运行时动态拼 DAG 的引擎"；动态性 = 静态骨架内模型循环 spawn（LangGraph Send API 即"静态拓扑+运行时动态 fan-out"）。判断标准："这条边写代码时画得出来吗？"画得出来→静态节点；画不出→动态 spawn | Codex 源码 | Codex 自己无 DAG 引擎，动态图是模型行动序列的投影（findings §4）；它否定的是"动态建图引擎"，不是静态图 | 设计纪律，写进 REQ 评审 |
| 子任务返回值 = 最后一条消息（摘要）+ artifact/outputSchema（数据） | Codex 源码改造 | 源码中 `AgentStatus::Completed(last_message)` 是唯一管道；财务场景升级为结构化 | 子图返回约定 + `SandboxResult.artifact_ids` 已有雏形 |
| 双通道结果回注：pull（wait_runs 工具）+ push（**完成即推进**） | Codex 源码 | 修订：V2 协议原生支持 `trigger_turn=true` 的确定性推进（protocol.rs:753、4387），照抄语义即可，不必另发明机制；LangGraph 落地 = interrupt/resume，二者等价 | `event_sink` + LangGraph resume |
| Run 状态机收敛为枚举 + 单一 is_final() 判定 | Codex 源码 | `watch::channel<AgentStatus>` 七值枚举走天下（status.rs:24） | Run/RunAttempt 状态定义 |
| 预算三件套：入口预留检查（模型不知限额存在）+ **全树共享账本**（fan-out N 路共摊根预算，防 N 份上限失控）+ **提醒阶梯**（80%/50%/20% 先软提醒收敛再硬停；提醒先落事件流再标记已投递） | Codex 源码 | `SpawnReservation` 预留制（control.rs）+ `rollout_budget.rs:8-22`（提醒投递顺序，本轮已核） | RunBudget 在 `run_service.py` 建 run 路径接线 |
| 子任务上下文份额显式指定（给多少背景） | Codex `fork_context` | 继承全部上下文 = 污染；给零 = 背景不足 | Supervisor 派单时五段式任务书 |
| 问数走 Wren 受管路径，任意代码走沙箱，两条威胁模型分开 | WrenAI 集成文档 §3.2 | Wren 语义层即 SQL 治理层 | adapter + SandboxPort 各自实现 |
| 编排决策全部落事件流 | 自建（强于 Codex） | Codex 的 Supervisor 决策散落会话记录；你有 timeline_projector | DomainEvent 新增编排事件类型 |
| 竞赛/Quorum 的候选从**固化题干 artifact** 出发，不继承对话上下文 | 指南文章 Quorum 节 + findings §3 | 候选共享被污染的上下文，结果一致也不可信；先 solidify 题干成 artifact，再各自隔离执行 | Supervisor 竞赛拓扑派单纪律 |
| 角色 = 配置不是代码：profiles 扩为完整角色（instructions + model_key + 推理档 + 工具集）；三角色 analyst/checker/**watcher**（只等待与报告、指数退避、禁止假装完成） | Codex 源码 | `agent/builtins/awaiter.toml`（1213 字节角色文件，本轮已核）；profiles.py 已有 model_key 与工具名单 | `domain/agent/profiles.py` 扩展 |
| 问数图首节点做术语解析：业务叫法 → MDL 指标 id 的映射资产；未命中/歧义 interrupt 问人，默认不猜；人工解析结果审核后反哺术语库 | SQLBot 术语库机制 | 口径三层模型（定义/映射/校准）中 MDL 只管定义层；"ROE 用摊薄还是加权"是映射层问题，SQLBot 验证了三路注入中这一路的价值（llm.py:367）；落成受治理资产而非 prompt 填料 | 问数静态图首节点 + terminology 表（版本化、变更落事件、改必回归） |
| 示例 few-shot 轻量学习闭环：人确认 + dry_plan 通过 + 数字对过才入库；召回按指标 id + 向量，MDL 版本不符即弃；B1 基线分"裸 MDL / +校准"两组度量 lift | SQLBot data_training + Wren memory 三件套 | P0 准确率第一杠杆，不等 AgentMemoryService 全套；与 wren_store_query 同构但可手塞起步；没有 lift 的示例库是负债不是资产 | 轨 B1；入库/失效落事件，负例只进 eval |
| 图表渲染分层：查询 artifact → ChartSpec（唯一契约）→ 可选图片；SSR 独立部署件只吃 ChartSpec，失败降级不阻塞 run | SQLBot g2-ssr | IM/监控推送"就要一张图"是交付形态问题不是口径问题；不钉 @antv/g2，渲染器可换；没有 ChartSpec 不许从行数据直接渲图（§2 第 5 条口径回溯） | ChartRendererPort（Web 渲染默认 / SSR 可选 / Fake 测试），P4 随 IM 通道 |
| 能力外放 = 一个控制面三扇门：Web SSE / IM / MCP 都适配同一套 application services；MCP 只暴露 schema 化工具，同权限、同账本 | SQLBot fastapi-mcp | 第一个反向契约面；MCP 调用方是别的 agent，更要契约更不能认聊天；"外面 agent 问一次打穿限额"是设计缺陷；没有调用方的门是纯攻击面，不提前开 | interfaces 层 MCP adapter；主链过 20 题 + 首个真实调用方齐备才立项 |

## 7. 源码和框架都给不了、必须自建的七样

1. **L1 领域骨架**：财务分析工作流的业务知识（取什么数、怎么校验、分析口径）——
   这是你的壁垒，没有任何开源件。
2. **评估集**：金标准问题集（P0 spike 的 20 题是起点，持续扩充）——没有它，§2 的
   八条无法回归。
3. **MDL 语义建模**：窄而精起步（营收/成本/利润核心表），质量决定答数上限。
4. **反馈采集**：Web 端对错按钮 + 纠错通道，接通 `wren_store_query` 学习闭环。
   确认样本即示例库的唯一来源（与第 7 条纪律在此交汇）。
5. **HITL UX**：SQL 审批、结论确认的前端交互（v5 §2.1 的要求，25 课给模式参考）。
6. **run 内压缩策略**：阈值触发 + 领域摘要模板（保数字/SQL/evidence_id）+ 压缩落
   DomainEvent。Codex 有完整 compaction 机制（`compact.rs`），你目前为零；财务 run
   必然长——能拆小 run 就不硬扛长上下文，压不掉才压缩。
7. **口径映射资产（术语库）与示例库纪律**：MDL 之外第二、三份受治理资产，SQLBot
   验证了其价值、我们目前为零。术语库管"人话 → MDL 指标"的映射（版本化、人工
   确认、变更落事件、改必回归）；示例库管"问法 → 取数模式"的校准（确认才入库、
   带 MDL 版本、失效批量落事件）。两者都不许定义口径——公式只活在 MDL。

## 8. 建设顺序（2026-08-22 修订：线性改双轨）

```text
修订理由（我自己的推演）：原线性顺序把"问数 spike"排在最前，但执行闭环地基
（真容器、预算/取消、控制面工具）与财务数据源零依赖，不该被 spike 阻塞；
问数准确率是"问数链"的退出条件，不是全项目的总闸。

轨 A（执行闭环，不等数据源）：
  A1  DockerSandbox 接 SandboxPort.run 首个真实调用方，artifact 进对象存储
  A2  RunBudget 三件套 + CancelRunCommand 接线（超限/取消都是事件，不是挂死）
  A3  控制面四件：create_run（已有）+ wait_runs + read_run_result + cancel_run
轨 B（问数上限）：
  B1  选定数据源 + DuckDB 样例库 + Wren ReAct，20 金标准题准确率基线
      （同步手录术语表 + 手塞示例 few-shot；基线分"裸 MDL"与"+校准"两组跑，
      lift 量化——没有 lift 的校准资产不带上生产）
合流后：
  P1  静态主链（L1）+ Wren adapter + FakeWren 测试；退出 = 金标准题达标
  P2  Supervisor 工具集 + fan-out；dry_plan critic + HITL
  P3  双通道回注 + 编排事件审计 + memory 存取 + 提醒阶梯生效
  P4  DockerSandbox 加固；SSE/ChartSpec 上 Web；压缩策略上线；
      IM 通道若开，ChartRendererPort 挂 SSR 渲染件（可选部署，失败降级不阻塞 run）
  P5  压测（25 课方法学）+ 生产加固 REQ
```

MCP 外放不在轨上：主链过 20 题且第一个真实调用方出现时单独立项——复用控制面
application services（三扇门同一层），同权限、同账本，不为外放另做一套问数链。

每个阶段的退出标准对应 §2 的打勾项；§2 九条全勾 = "完美"达成。

## 9. 速查

```text
研究文档：~/codex-reference/codex-orchestration-assessment-kimi.md ~/codex-reference/codex-dynamic-graph-findings-kimi.md
          ~/codex-reference/wrenai-financial-analysis-integration-kimi.md ~/codex-reference/sandbox-extension-advice-kimi.md
          ~/codex-reference/sqlbot-kimi.md（SQLBot 四机制自研设计）
源码锚点：~/repo/codex/codex-rs/core/src/agent/{control,status,registry}.rs
          ~/repo/codex/codex-rs/core/src/tools/handlers/multi_agents/{spawn,wait}.rs
          ~/repo/codex/codex-rs/core/src/session/rollout_budget.rs（预算提醒阶梯）
          ~/repo/codex/codex-rs/core/src/compact.rs（run 内压缩）
          ~/repo/codex/codex-rs/core/src/agent/builtins/awaiter.toml（watcher 角色原型）
          ~/repo/codex/codex-rs/protocol/src/protocol.rs:753,4387（trigger_turn 语义）
SQLBot 锚点：~/repo/SQLBot/backend/apps/chat/task/llm.py:791,1006（generate_sql/check_sql 与 prompt 链形态）
           ~/repo/SQLBot/g2-ssr/package.json（图表 SSR 形态） ~/repo/SQLBot/backend/main.py:216（fastapi-mcp 接线）
代码锚点：~/master/investment-app/investment-backend/app/app/{domain,application,infrastructure}/agent/
```
