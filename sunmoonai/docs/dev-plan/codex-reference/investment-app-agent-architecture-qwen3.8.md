# investment-app Agent 总体架构设计（qwen3.8 独立收敛版）

> 最后更新：2026-08-22（三版互评后修订）
>
> 性质：总体设计（个人决策底稿），非 baseline、非 REQ；立项时按治理规则走 REQ。
> 与 kimi 版 `investment-app-agent-architecture-kimi.md` 平行：骨架共识、细节不同。
> 本文收敛的是**我的四份独立文档**（均为我亲自复核锚点后写就）：
> - `codex-orchestration-assessment-qwen3.8.md`（编排考证：证据分层、决策权三分法、P0.5 闸门）
> - `sandbox-extension-advice-qwen3.8.md`（沙箱：零 port 改动首实现、加固 +4 条）
> - `wrenai-financial-analysis-integration-qwen3.8.md`（WrenAI：依赖兼容、制品治理、敏感数据面）
> - `codex-deepdive-v2-qwen3.8.md`（源码增量：trigger_turn、预算三件套、压缩、角色、code-mode）
>
> 所有引用锚点此前均已逐条验证（REQ-002 纪律）；与代码冲突时以代码为准。

---

## 1. 共识基础：两条祛魅结论（两版一致，不再展开）

1. **Codex 没有编排引擎**——动态图是模型循环推理在 AgentPath 树上的投影，运行时
   只做约束（findings §4，源码已证）。所以不用建 DAG 引擎。
2. **源码公开 ≠ 可复制**——智能在权重里、微决策的失效史不在 repo 里、机制与
   模型 co-design。垂直 agent 的目标不是成为 Codex，是借机制祛魅省钱。

在此之上，我的版本强调一条 kimi 版未展开的判断：**你与 Codex 最大的环境差异
不是技术栈，是"没有人在场"**。Codex 的编排可靠性由用户当场兜底；你的生产系统
没有这个兜底。下文所有"比 Codex 更严格"的设计都从这一条推出。

**本版本第二总纲（2026-08-22 用户确认为最重要建设纪律）：一套地基，两种形态，
不建两套系统。** 熟路（静态图）与生路（通用循环）是**同一个运行时上的两种执行
形态**，不是两个系统：同一套 LangGraph + PostgresSaver，同一套预算三件套、
事件审计、结果契约（schema + artifact）、HITL、角色配置、压缩，同一个 Run
实体——生路 run 与熟路 run 必须能在同一条 timeline 上一起回放。建两套 =
治理断、审计断、"没有人在场"的兜底断。要分的是**执行形态与建设顺序**（熟路
先行、生路随后，P0.5 闸门），不能分的是地基与契约；两者靠 artifact schema +
事件流相通（这是固化雷达的数据源，第一天就要埋好，见 §3.5.2 第 3-4 条）。
对应验收：§2 第 9 条。

另需一次澄清（两版一致，防再读岔）：**"Codex 无 DAG 引擎"否定的是"运行时动态
拼 DAG 的引擎"这个中间形态，不是静态图**。静态图是主体（问数主链 100% 走
LangGraph 编译图）；判据是"这条边写代码时画得出来吗"；LangGraph Send API 原生
支持"静态拓扑 + 运行时动态 fan-out"，不存在静态 vs 动态的选型冲突。

## 2. "完美"的操作定义（kimi 版七条全收，我加第 8 条）

1-7 与 kimi 版一致（边可解释、返回可校验、编排可审计、预算闸门、数字可溯源、
错误可恢复、有评估集），我追加：

8. **长 run 不怕上下文**——有阈值触发的压缩策略，领域化摘要保留数字/SQL/
   evidence_id；且 Supervisor 懂"能拆小 run 就不硬扛长上下文"。依据：Codex 有
   完整 compaction 机制（deepdive §4），你目前为零；财务分析 run 必然长。
9. **熟路生路不建两套系统**（§1 第二总纲的验收件）——生路（通用循环）run 与
   熟路（静态图）run 共用同一套预算/事件/契约/HITL 基建，同一条 timeline 统一
   回放；禁止为生路另建独立执行栈。判据：任意一个 run，都能指回同一套 L0/L5
   组件；生路产物 schema 与路由未命中都在事件流里查得到。

## 3. 分层架构（沿用 L0-L5，补两处缺件）

```text
L5 治理层   RunBudget 三件套 │ DomainEvent 审计 │ timeline 回放 │ 身份权限
L4 质量层   Generator-Critic(dry_plan) │ 独立评审 │ HITL interrupt │ 金标准评估
L3 能力层   Wren 六工具(受管SQL) │ SandboxPort(任意代码) │ 知识检索 │ 资讯
L2 动态层   Supervisor meta-agent + 编排工具集 │ Send fan-out │ 双通道回注(trigger_turn 语义)
L1 领域骨架  静态图：取数→校验→分析→评审→产出（财务工作流知识在此）
L0 运行时   LangGraph + PostgresSaver + celery + outbox + event_sink（已有）
             └ 补：run 内压缩策略（跨层能力，挂 L0，服务所有层）
```

两处缺件说明：

- **L5 的 RunBudget 从"接线"升级为"三件套"**（deepdive §3 源码依据）：入口预留
  （SpawnReservation 式，建 run 时检查）+ 全树共享账本（fan-out 的 N 个子 run
  共摊根预算，防 N 份 120k 失控）+ 提醒阶梯（跌穿 80%/50%/20% 阈值注入余额提醒，
  软降级先于硬停止）。kimi 版只有第一件。
- **L0 补压缩**：阈值触发 + 领域摘要模板 + 从旧到新裁剪保最近 + 压缩落
  DomainEvent（kimi 版 §5"必须自建"我相应扩为六样，见 §5）。

## 3.5 任务类型扩展模型（"以后不止问数"怎么接）

与 kimi 版 §4 共识：**入口通用、执行分档、成长靠固化**——Supervisor 什么任务
都接；执行侧三档频谱（静态固化图 / 骨架+Send 动态点 / 通用循环）；新任务从通用
循环端进入，跑量后由编排事件流雷达选出热路径，数据驱动地固化为静态图。我全收，
补三点让它可执行：

1. **三档各有源码背书**：静态固化档 = 你的 L1（Codex 没有是因为 coding 无固定
   流程，你有）；骨架+动态点档 = LangGraph Send（对应 Codex 的 fan-out）；
   通用循环档 = findings §4 的 spawn 循环 + 双通道回注 + 状态枚举——**源码追踪
   证明这档不需要 DAG 引擎，所以第三档的建造成本比想象低**，"第一天就能跑"
   成立。
2. **通用循环档必须有治理壳验收标准**（没有人在场 → 比 Codex 更严）：RunBudget
   三件套生效、每次 spawn/结果回注落编排事件、沙箱工具走 D8 分离、**产出无
   schema 时默认触发 HITL 确认**（对应 D1 第三档生产禁用的边界：通用循环不是
   自由编排，它的每个副作用动作仍在受约束档内）。判据一句话：通用循环档跑出的
   每个 run，都能在 timeline 上完整回放。
3. **固化流水线补上回归一环**：热路径固化成静态图时，该任务类型累积的 run
   样本自动转成它的金标准评估集（喂 §2 第 7 条）——固化前后跑回归，防止固化
   本身引入行为漂移。否则"固化"只有成本收益没有正确性保障。

示例沿用 kimi 版的"研报解读"生命周期（第 1 天通用循环 → 第 50 次 run 热路径
浮现 → 固化为静态图），我加一步：**固化验收 = 新旧两档在同一评估集上准确率
不降**。

### 3.5.1 中间态的两个漂移方向与护栏（2026-08-22 补）

专业域 Agent 的通行做法（熟路预定图，生路和分叉才让 LLM 选）与我的三分法同形；
两种常见偏法也诊断明确：①"小号 Codex"（只挂 system prompt + 工具整段 ReAct）在
财务域必然违约四项：不可回放、不可回归、成本方差失控、决策无红线——正好是
§2 八条的反面清单；②"图画得太死"的病根是生路无落脚点。

但**中间态不是稳定均衡**，有两个漂移方向，各需一个护栏：

- 不维护通用循环档 → 退化成"图太死"（护栏：通用循环档永远是新任务类型的
  落脚点，第一天就能跑）；
- 不跑固化流水线 → 通用循环永远是主力 → 退化成"小号 Codex"（护栏：事件流
  驱动的热路径固化持续运转，能力从"通用但贵"向"专用且稳"迁移）。

只画三档频谱不装这两个护栏，半年后必然滑向某一端。

另：光谱两端其实都是"受约束"——连 Codex 的模型规划也被工具 schema/预算/沙箱
权限圈着，差别只在约束粒度（选择级 vs 规划级）；你们因"没有人在场"取更细
一档，同一条逻辑。

### 3.5.2 生路与熟路各自怎么编排（2026-08-22 回应 cursor 版 §2/§5/§11）

cursor 版的公式"熟路走预定图、生路走控制环（建、派、等、读、再派）、跑热了
再收成图"我同意，与 §3.5 同形。它没展开的四个执行细节，我钉死：

1. **熟路编排 = 确定性三条**：边是代码，LLM 只做节点内推理（填槽、取证、写
   结论）；每个节点带出口 schema；每张静态图配 eval 集，改图 = 跑回归（§3.5
   固化验收）。熟路 run 的退出不问模型"你完成了吗"，查 schema 过没过——
   与 cursor"下游认 Artifact"同一条。
2. **生路编排 = 控制环 + 治理壳三必须（§3.5 第 2 条）再加预算反置**：生路
   run 的根预算应比熟路低、提醒阶梯更早触发——用预算把生路"推向固化"，
   不让它舒服地待在贵区。生路里 LLM 的决策权仍全是受约束枚举（拆几路、
   取消谁、留谁，D1 第二档），不是自由规划。
3. **生路↔熟路的接口 = Artifact 契约（我认为最关键、cursor 未展开的一条）**：
   生路 run 的产出反复出现同一种 schema 时，这个 schema 就是未来静态图节点的
   雏形——**生路的出口产物 = 熟路的入口设计稿**。所以固化不是重写逻辑，是把
   已涌现的路径钉死：事件流给节点序列、run 样本给 eval 集、产物 schema 给节点
   契约，三样缺一不可。反向通道也要有：**熟路降级**——静态图 eval 准确率持续
   下降（schema 漂移/业务变口径，wrenai-qwen3.8 §3-⑧）时，退回通用循环重新探索，
   不在旧图上打补丁。
4. **生/熟路由由谁判**：Supervisor 路由表（意图 → 执行档），命中静态图直接走，
   未命中落通用循环；**未命中本身落事件流**——未命中也是雷达信号（新任务类型
   出现了，或路由写错了），喂给 §3.5 的固化候选雷达。

## 3.6 投资管理主战场（问数只是感官）

与 kimi 版 §5 共识：投资主循环六环节（研究→观点→决策→持仓→监控→复盘）
各自落三档频谱；问数是感官，投资管理是主战场；六环节映射表与四数据域划分
（财务库/行情时序/持仓交易账本/公告事件流）我全收。补四点修正与增强：

1. **数据域扩张的治理代价要说破**：四域都进 Wren 受管路径 = **四套 MDL**，
   wrenai-qwen3.8 §3-⑧ 的"schema 演进带动 MDL 演进"问题×4；其中行情时序是
   高基数列式形态，与财务库的关系型建模不同，MDL 建模策略要分域评估（P0
   spike 只验财务库，其余三域的建模可行性各自单独 spike，不默认 Wren 全能）。
   另：持仓交易账本是**自产敏感数据**，与外部数据不同级——它的访问控制、
   备份与脱敏纪律要单列，不与四域混谈。
2. **"时间一等公民"落到语义层**：不止是数据模型要 as-of——thesis 的时点、
   复盘的对时点、行情的复权口径，都要求 Wren MDL 里把"数据时点 vs 查询时点"
   建进语义模型（否则 SQL 生成会系统性出错），这条应写进 MDL 建模规范。
3. **监控环节 = awaiter 角色的主场**：beat/事件触发的盯梢型 run（等公告、等
   价格穿越阈值）正是 D7 awaiter 的用武之地——便宜模型 + 指数退避轮询，
   贵模型只在触发后介入分析。没有 awaiter，监控环节的成本会失控。
4. **决策环节的红线要落成机制不是口号**："人工拍板"在代码里的形态 =
   决策类 run 的终态必须由 HITL 事件触发（对应你已有的 pilot 链
   interrupt/resume + action token 原子消费机制，baseline §3.6 已验证可行）；
   且决策 artifact 必须携带证据快照 id——复盘环节要用**当初看到的证据**对比
   事后数据，而不是用今天的重新检索（否则复盘失真）。

六环节中"复盘喂回学习闭环"一条，与 §2 第 7 条（评估集）合流：thesis 事后验证
的样本是天然的金标准题源——投资域的评估集不靠人造，靠复盘长出来。

## 4. 关键机制决策表（我的版本：九条，与 kimi 版逐条对账见 §7）

| # | 决策 | 依据 | 落点 |
| --- | --- | --- | --- |
| D1 | **决策权三分法**：静态图档（固定流程）/ 受约束动态档（LLM 只在预定义枚举里选，schema 校验后落应用服务；**通用循环档的每个动作也归这档**）/ 自由编排档（生产禁用，仅 admin 调试面）。判断标准同 kimi 版："这条边写代码时画得出来吗" | assessment-qwen3.8 §2.3；Codex 有"人在场"兜底可活在第三档，你没有 | 设计纪律，写进 REQ 评审；编排工具 schema 进契约锁纪律 |
| D2 | 不建 DAG 引擎；动态性 = 静态骨架内受控 spawn（Send API） | findings §4（源码证）；code-mode 佐证（deepdive §6：连 Codex 都给模型"把编排写成代码"的出口） | 同 kimi 版 |
| D3 | 双通道回注：pull（wait_runs）+ push 取 **`trigger_turn=true` 语义**——完成事件即结构化消息（author/recipient/RunLineage/四类 Kind），直接驱动下一节点，不做"躺着等顺便看到" | deepdive §2：V2 协议 `InterAgentCommunication.trigger_turn` 原生支持确定性推进；**修正 kimi 版"另用事件驱动边/interrupt-resume"的表述——协议照抄即可，不必另发明** | DomainEvent 新增四类编排子类型（Spawn/Message/Followup/Result），`event_sink` 承载 |
| D4 | 结果契约：结构化 outputSchema + artifact 引用为数据，文本仅人读摘要；**回读即攻击面**——Supervisor 读回的产物默认不可信，schema 化回读写进工具验收标准 | findings §3 + assessment-qwen3.8 §2.3 之三（研究域产物大量来自网页，回读通道是注入主入口） | `read_run_result` 工具验收标准 |
| D5 | RunBudget 三件套（见 §3）；提醒投递纪律照抄源码：写入事件流成功后才标记已投递，resume 时重新武装 | deepdive §3（rollout_budget.rs） | RunBudget 接线方案（P1） |
| D6 | Run 状态机 = 枚举 + 单一 is_final()，结果挂终态上，不为结果另建管道 | findings §5（watch::channel<AgentStatus>） | Run/RunAttempt 状态定义 |
| D7 | **角色 = 配置不是代码**：profiles.py 扩为完整角色配置（instructions + model_key + reasoning 档位 + 工具集）；财务域三角色 analyst/checker/**awaiter**（最便宜模型盯长 job，纪律照抄 awaiter.toml："只等待与报告、不修改任务、指数退避、禁止幻觉完成"） | deepdive §5（agent/builtins/awaiter.toml、role.rs:38-42） | `domain/agent/profiles.py` 扩展 |
| D8 | Wren 受管 SQL 与 DockerSandbox 任意代码两路分离，各管各的威胁模型；首个沙箱实现**零 port 改动**，artifact 落对象存储列 P0 验收 | sandbox-qwen3.8 §2；wrenai-qwen3.8 §3.2 | adapter 双实现 |
| D9 | **编排计划确定性编译**（code-mode 启示的中间路）：批量编排意图一次性结构化成执行计划，交确定性执行器跑，不逐轮问 LLM | deepdive §6；省 token + 可审计，适配"多表联查分析"类固定套路 | Supervisor 工具集之上的编译层（P2 之后评估） |

## 5. 必须自建的六样（kimi 版五样 + 我加第六样）

1. **L1 领域骨架**（财务工作流知识，你的壁垒）
2. **评估集**（20 金标准题起步，eval 门禁先于架构投入——wrenai-qwen3.8 §2 之三）
3. **MDL 语义建模**（窄而精；制品进镜像按 digest 钉死、memory 索引挂 PVC——
   wrenai-qwen3.8 §3-⑥ 的决策框架；**L3 数据供给是两段**：上游入库 + 下游
   schema 演进带动 MDL 演进，wrenai-qwen3.8 §3-⑧）
4. **反馈采集**（对错按钮 + 纠错通道；Wren memory 只存去标识化查询模式，
   带数值/主体的一律走 AgentMemory sensitive 纪律——wrenai-qwen3.8 §3-⑦）
5. **HITL UX**（SQL 审批、结论确认）
6. **run 内压缩策略**（阈值 + 领域摘要保数字/citation + 压缩落事件——
   deepdive §4；Codex 有完整机制，你目前为零）

## 6. 建设顺序（我的版本：P0.5 闸门；2026-08-22 修订为双轨并行）

```text
P0-A  问数 spike（L3 上限轨）：选定财务数据源 → DuckDB 样例库 + Wren（langgraph
      原语路线，先不引 langchain 主包——wrenai-qwen3.8 §1.4 依赖实测）→ 20 金标准题
      准确率基线
P0-B  执行闭环（Agent 地基轨，与 P0-A 并行，不依赖数据源选定）：一个真容器跑通
      （DockerSandbox 接 SandboxPort.run，零 port 改动，artifact 进对象存储）+
      预算/取消接线（cursor 版 §10 第 1-2 步）
P0.5  闸门：单 run 价值闭环成立才进编排——两轨各自退出后合流：沙箱有首个真实
      调用方、RunBudget 接线、Pilot 链验收/v4 流量门内部开启（assessment-qwen3.8
      §2.4；风险是"地基没打好就盖编排楼"）
P1    静态主链（L1）+ Wren adapter + FakeWren 测试 + RunBudget 三件套之入口预留与账本；
      退出条件 = 20 金标准题准确率达标（P0-A 基线在此验收，不是全项目第 4 步才验数）
P2    Supervisor 工具前四件（create_run/wait_runs/read_run_result/cancel_run，
      按价值/风险排序——assessment-qwen3.8 §2.3 之二）+ fan-out + dry_plan critic + HITL
P3    双通道回注（D3）+ 编排事件审计 + memory 存取 + 提醒阶梯（D5）
P4    DockerSandbox 加固（加固清单 6+4 条）；SSE/ChartSpec 上 Web；压缩策略上线
P5    压测（25 课 v5 方法学）+ 生产加固 REQ
```

**双轨修订说明（接受 cursor 版改判）**：我此前把"先准确率再碰沙箱"读成单一总闸，
错了。P0-A 管的是问数上限（数据源未定不该画问数主链——这条仍成立）；P0-B 管的
是 Agent 执行闭环（真容器、预算、取消），不依赖财务库选完。两轨并行，各自退出后
在 P0.5 合流，不排成一条队。

每阶段退出标准对应 §2 打勾项；八条全勾 = "完美"达成。

## 7. 与 kimi 版的对账表

| 议题 | kimi 版 | 我的版本 |
| --- | --- | --- |
| 分层 L0-L5 | 提出 | 接受；补 L0 压缩、L5 预算三件套 |
| 完美定义 | 七条 | 全收 + 第 8 条（长 run 上下文） |
| push 通道 | "注入消息等顺便看到"→ 需另建事件驱动边 | **修正**：V2 协议 trigger_turn=true 原生确定性推进，协议照抄 |
| 预算 | 建 run 预留检查（一件） | 三件套（预留 + 全树账本 + 提醒阶梯） |
| 决策权 | "边画得出来吗"单一判据 | 三分法三档，第三档生产禁用（"没有人在场"推出） |
| 工具集 | 六件平铺 | 前四件先行，review_run 并入拓扑 |
| 角色 | 未展开 | 角色=配置，analyst/checker/awaiter 三角色 |
| 压缩 | 未覆盖 | 第六样必自建 |
| 建设顺序 | P0-P5 | 同 + P0.5 闸门（单 run 闭环先于编排） |
| 回读安全 | 隐含 | 显式：schema 化回读进验收标准 |
| 任务扩展模型 | §4：入口通用/执行三档/动态→静态固化（采纳） | 全收 + 三点加固：三档源码背书、通用循环档治理壳验收标准（无 schema 默认 HITL）、固化时评估集回归 |
| 投资管理主战场 | §5：六环节映射 + 四数据域 + 两条原则升级（采纳） | 全收 + 四点：四套 MDL 的治理代价与分域 spike、as-of 进语义层规范、监控环节用 awaiter 角色控成本、决策红线落成 HITL 终态机制 + 证据快照 |

**两版关系建议**：kimi 版胜在简洁完整（尤其 §1 七条"为什么抄不到"、§4 第一行
的"边画得出来吗"判据、§4 任务扩展模型，我都采纳了）；我的版本胜在源码增量
（deepdive 五项）与闸门/治理纪律。**§7 对账表的裁决范围仅限本文与 kimi 版
之间**；涉及第三版时见 §7.5。

## 7.5 与 cursor 版（B-S 形态篇）的对账（2026-08-22 三版互评后补）

cursor 版 `investment-app-agent-architecture-cursor.md` 的贡献（我认账并采纳）：
开篇钉死 B-S 形态（浏览器唯一入口、服务端唯一控制面、Docker 是 Host，无 Codex
桌面"App Server 侧门"之缝）；编排对象→仓内实体映射表；worktree 默认/多容器升级
（修正我 assessment-qwen3.8 §2.2"消解 worktree 直接容器"的过激判断，已在原文补修订
注；这是成本判断不是折中）；
角色按沙箱权限分（watcher ≈ 我的 awaiter，独立收敛）；"下游认 Artifact，不认
上游一句'好了'"；后台审批失败抛回父 Run 不挂死。

我的版本仍独有的：Wren 集成深度（见 wrenai-qwen3.8）、四数据域治理代价（§3.6）、
源码级机制锚（trigger_turn/四 Kind/code-mode）、证据分层纪律。cursor 版对这四条
的回应是"按形态篇收口，缺锚不等于反对；立项底稿需补或明确指针"——同意，
统一进 investment-app 时按此办。

三版定位（只当"文档怎么用"，不当三套真理）：形态与操作规程以 cursor 版为准；
叙述与全景以 kimi 版为准；决策底稿与治理纪律用本文。**最终拍板归用户**：
形态以 B-S 篇为准，治理把 Wren/数据域/证据纪律补进来，源码名以现活代码为准
（文章用名如 fork_turns 可能漂移，不得写进契约）。

## 7.6 设计成色分层：哪些能称"最佳实践"（2026-08-22 补）

立项 REQ 评审时，本文的设计条款分三类成色，不得混装：

**A 类：行业最佳实践（可引用、可答辩，参照已核验）**

| 做法 | 参照 |
| --- | --- |
| 熟路预定图，动态只在必要时 | Anthropic《Building Effective Agents》："find the simplest solution possible, only increasing complexity when needed"；workflows/agents 二分与本文三档频谱同形 |
| 问数走语义层受管 SQL | 裸 text-to-SQL 会"silently and confidently fail"（Omni 分析）；dbt 2026 基准：语义层对覆盖内查询接近满分；企业部署标配 guardrails（只 SELECT、只读凭据、强制行级过滤）——与 Wren + dry_plan 路线一致 |
| 决策必过人、审计回放、eval 先行 | 高风险域 agent 标准配置，无争议 |

**B 类：Codex 源码移植（OpenAI 生产规模验证过，但行业未普及）**：预算三件套、
取消、checkpoint 恢复、trigger_turn 确定性推进、awaiter 角色纪律。来源可靠，
引用时指向 deepdive 锚点。

**C 类：本文自创假设（无公开先例，是"没有人在场"的演绎，需跑出来验证）**：
① 固化流水线（事件流雷达 + 评估集回归）；② 预算反置（生路根预算低于熟路，
逼它固化）；③ 熟路降级通道（eval 持续下降退回通用循环）；④ P0.5 闸门具体形态。
评审时 C 类条款必须标注"待验证假设"，不得包装成最佳实践。

两个边界条件：

1. 这是"正确性敏感的垂直域 agent"的最佳实践，不是通用答案——通用 coding
   agent 恰恰该偏动态端；换领域，静态/动态最优配比会平移。
2. 最佳实践本身是移动靶（模型能力每涨一截，"哪些边必须写死"的答案变一次）。
   真正可持续的不是某张架构图，而是**保住重新划线的工具：eval 集 + 编排事件流**——
   有这两样配比随时可调，没有则任何"最佳"都会过期。

## 8. 速查

```text
我的四份输入：~/codex-reference/{codex-orchestration-assessment-qwen3.8,
  sandbox-extension-advice-qwen3.8,wrenai-financial-analysis-integration-qwen3.8,
  codex-deepdive-v2-qwen3.8}.md
源码锚点（本轮已验证）：
  codex-rs/protocol/src/protocol.rs:738        InterAgentCommunication/trigger_turn
  codex-rs/core/src/rollout_budget.rs          全树账本/提醒阶梯
  codex-rs/core/src/compact.rs                 压缩机制
  codex-rs/core/src/agent/builtins/awaiter.toml 等待者角色（explorer.toml 为空文件勿引用）
  codex-rs/code-mode-protocol/src/description.rs:15+ exec/V8 编排
代码锚点：~/master/investment-app/investment-backend/app/app/{domain,application,infrastructure}/agent/
  （RunBudget runtime.py:62 │ CancelRunCommand commands.py:31 │ profiles.py:19-41 │
   SandboxPort domain/agent/sandbox.py:39 生产零调用 │ memory.py:29 AgentMemory）
```
