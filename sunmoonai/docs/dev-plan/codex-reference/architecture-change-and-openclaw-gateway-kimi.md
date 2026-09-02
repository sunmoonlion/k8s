# 换架构合理吗 + OpenClaw Gateway 借鉴分析（kimi 版）

> 最后更新：2026-09-02
>
> 性质：决策分析（个人决策底稿），非 baseline、非 REQ。
> 姊妹文档：`supervisor-dual-harness-feasibility-kimi.md`（双腿架构可行性，下称"可行性文档"）。
> 本文回答用户 2026-09-02 提出的两个问题：
> 1. 从自研架构换成双腿 SDK 架构，合理吗？比原来的更好吗？
> 2. `~/repo/openclaw` 的 gate（Gateway）做法，我们的路由和 Supervisor 该借鉴还是完全转向？
>
> 取证：`~/repo/openclaw` 的 docs/start/why-openclaw.md、docs/concepts/architecture.md、
> docs/agent-runtime-architecture.md、docs/channels/channel-routing.md、VISION.md（2026-09-02 亲核）；
> 本仓 development-plan.md、constraints.md、旧架构文档（investment-app-agent-architecture-kimi.md）。

---

## 1. 问题一：换架构合理吗？比原来更好吗？

### 1.1 先纠正一个事实：被"换掉"的到底是什么

"推翻自研架构"这个印象需要精确化，因为涉及两份地位不同的文档：

| 文档 | 地位 | 对执行层的主张 |
| --- | --- | --- |
| `investment-app-agent-architecture-kimi.md`（2026-08-22） | **个人决策底稿**，明示"非 baseline、非 REQ" | L2 动态层自研（Supervisor meta-agent 写成 LangGraph 图），L1 静态图自研，L0 复用已有 |
| `development-plan.md`（2026-08-29，治理文件） | **正式计划** | "通用部分的执行层采用 Codex 的 Python SDK……不自建轮次生命周期、隔离进程、中断恢复、审批协议、工具与沙箱"（原文） |

即：**正式治理在 2026-08-29 已经判定执行层租用不自建**——比这次提问早四天。
用户的双腿提案不是推翻正式架构，而是：(a) 追认已定的租用方向；(b) 把它具体化
（Supervisor、ExecutionPort、工具网关、部署形态）；(c) 新增唯一一个真决策——
专用腿用 dsh 而非同跑 Codex。我 8-22 那份自研 L2 的旧文档才是被治理否掉的偏离项，
这一点如实记录，不粉饰。

### 1.2 为什么"租用执行层"是对的——用旧文档自己的论证回收

旧架构文档 §1 论证了"为什么源码公开，多数人还是做不出 Codex 水平的 coding agent"，其
七条理由恰恰是今天换架构的依据，逐条回收：

| 旧 §1 论点 | 对今天的含义 |
| --- | --- |
| "机制在源码里，智能不在" | 我们不需要抄机制——直接**调用**机制（SDK）。自研循环既没有模型的判断力，又要自己扛机制的复杂度，两头不占 |
| "可靠性的复利在长尾……重试、断点恢复、预算、沙箱、会话重建、compaction、背压，无聊的 80%" | 这 80% 正是租用买到的东西。小团队的机会成本账：花在重建 turn 生命周期上的每一周，都是没花在 MDL 质量与金标准题集上的一周——而后者才决定答数对不对，答数对不对才是产品 |
| "机制与模型是 co-design" | Codex 与 OpenAI 模型、dsh 与 DeepSeek 模型各自 co-design 过；自研循环套外来模型，prompt/工具粒度/上下文预算全部要自己重新调——租用把 co-design 一起租来了 |
| "移动靶" | 靶还在动（我们亲见 codex 移除 wire_api chat），但 SDK 门面层 3 个月 0 破坏（development-plan 实测），租用的是稳定门面不是移动的内部 |
| "评估缺位" | 不变：金标准题集仍是必须自建的七样之一，与执行引擎无关 |
| "知道什么不用建比知道建什么更省钱" | 这句话的直接推论就是：agent loop 本身不用建。旧文档写了这句话却没有把它贯彻到 L2，新架构贯彻了 |

**结论：换架构合理，因为它是旧分析的逻辑终点，不是新冲动。**

### 1.3 诚实的代价清单（我们放弃了什么）

说"更好"之前先把代价摆全，每条都是真实损失：

1. **单一状态机让位给两个黑盒**。自研 LangGraph 路线下，checkpoint = 完整状态机，
   time-travel、确定性恢复、图内任意节点重放都是原生能力。租用后恢复粒度退化为
   "home 快照 + thread_resume/同 session 续聊"（可行性文档 R5）——能恢复，但不能
   在 harness 对话中间做任意点分叉重放。**缓解而非消除**：我们把确定性拓扑留在
   自己手里（熟路静态图的骨架仍是我们的 LangGraph 图，harness 会话只是节点执行体），
   图级 checkpoint 照旧在 PostgresSaver——分叉重放的粒度从"对话内任意点"变成
   "图节点边界"，对熟路场景恰好够用。
2. **事件保真度依赖上游词汇表**。我们的 timeline 从"原生事件流"变成"对两个 harness
   事件词汇表的投影"，映射必有取舍（Codex 的 item 体系 vs dsh 的 SessionEvent 体系
   形状不同）。这是 S1 spike 的验证项，不是嘴上说能映射就算数。
3. **两个上游的路线图进入我们的风险面**。破坏性变更（dsh 明示）、功能移除（codex
   移除 chat wire_api，我们亲见）都会砸进来。靠钉版 + 协议契约测试 + 季度复测管理
   （可行性文档 R7），不能归零。
4. **运维面从一个 Python 运行时变成三个运行时**（Python worker + Rust 二进制 +
   Node 运行时）。镜像、排障、资源模型都变复杂。
5. **跨进程边界无处不在**。工具调用从进程内函数调用变成 JSON-RPC + HTTP 网关往返；
   延迟、失败模式、序列化成本都新增。换来的恰好是隔离与审计点（网关），这笔账是
   赚的，但账要记着。

### 1.4 判定与反证条件

**判定：更好，且好得有结构，不是好得有情绪。**好在三个层面：

- **战略层**：执行层是商品（commodity），领域不是。我们的壁垒清单（旧 §7 七样自建物：
  领域骨架、评估集、MDL、反馈采集、HITL UX、压缩策略、口径资产）里**没有一样是
  agent loop**。把预算从非壁垒项移到壁垒项，是资源配置的修正。
- **风险层**：自研失败的模式是"loop 永远差一口气且拖住全部进度"（系统性、不可恢复）；
  租用失败的模式是"某个 harness 不达标，经 Port 换掉"（局部、可恢复）。**失败的
  不对称性站在租用这边。**
- **治理层**：新架构反而强化了旧纪律——工具网关让"每次能力调用带 run lineage 落账"
  成为结构性事实（自研路线下这只是约定）；harness 进程天然是最小权限执行体
  （凭据白名单下发）。

**但"更好"是有反证条件的**（falsifiable，写死以防自我说服）：

1. S1 spike 中，任一腿的事件流无法忠实喂给 timeline（词汇表映射损失过大）→ 该腿
   退回自研 LangGraph 循环重估；
2. dsh 腿 `submit_result` 契约 + preset 在金标准任务上打不过"Codex 单 harness +
   output_schema"的对照组 → 专用腿改回 Codex，dsh 出局；
3. dsh 进程模型在 worker 里不稳定（启动失败率/内存/僵尸进程超阈）→ 同上。

三条都触发不了，结论站住；触发任何一条，按条款回退，不嘴硬。

---

## 2. 问题二：OpenClaw 的 gate 做法——借鉴还是转向？

### 2.1 核实：OpenClaw 的 Gateway 到底是什么

一句话：**一个长驻的可信控制面守护进程，拥有全部通道连接、凭据、策略与持久状态；
执行被推到不可信的、可移动的沙箱/节点/云 worker；策略以代码强制而非 prompt 请求；
路由由宿主配置决定，模型不参与。**（docs/start/why-openclaw.md 标题句："trusted
gateway, untrusted execution, deterministic policy"）

关键机制（全部亲核）：

| 机制 | 事实 | 锚点 |
| --- | --- | --- |
| 信任边界 | Gateway 持通道/配置/凭据/控制面 API/持久 transcript；sandbox（Docker 默认无网+只读 root+drop all caps+非 root）、node（密封工件、三处哈希校验）、cloud worker（**按次派发铸造凭据、10 分钟 TTL、RPC 方法白名单、推理经 Gateway 代理、worker 不留 transcript、只见有界单轮上下文**） | why-openclaw.md "The trust boundary" |
| 策略即代码 | 权限模式直接决定**哪些工具存在**（read-only 会话里 edit/write 根本不出现）；tool policy deny 永远赢；exec 审批**绑定规范化命令+cwd+环境哈希+内容哈希文件操作数，任何漂移即拒**；无审批 UI 时默认拒；严格情形（inline eval、heredoc）任何 fallback 都不可软化 | why-openclaw.md "Policy as code" |
| 确定性路由 | "**The model does not choose a channel**; routing is deterministic and controlled by the host configuration"；session key 形状决定上下文桶；bindings 覆盖有序 | channel-routing.md |
| 运行时选择也是配置策略 | harness 注册表 + 按 model/provider 的 `agentRuntime.id` 配置；`auto` 确定性解析；模型/provider 前缀本身永不选择 harness | agent-runtime-architecture.md "Runtime Selection" |
| 身份与作用域 | operator scope 按请求实际参数在 dispatch 前导出；**无分类的方法默认拒**；role 是天花板，只取交集永不叠加 | why-openclaw.md "Identity and roles" |
| 凭据不出模型上下文 | SecretRef（env/file/exec/store）+ 出口边界 sentinel 替换（只给绑定目的主机替换真值，未识别 sentinel 拒发）；agent 只见句柄 | why-openclaw.md "Secrets" |
| 状态与升级 | DB-first（SQLite）、schema 双段版本契约（库比自身新即拒开）、升级预检、迁移单一 owner（doctor）、备份哈希校验、**重启恢复在有限尝试预算内恢复中断 turn + 崩溃循环熔断器** | why-openclaw.md "Versioned state" |
| 协议 | WebSocket，首帧必须 connect，幂等键用于副作用方法，设备配对 | concepts/architecture.md |

### 2.2 为什么不能"完全转向"

OpenClaw 不是我们的 Supervisor 位置的组件，而是这个位置上的**竞品**——转向它意味着
把我们的 Supervisor、路由、Profile、账本全部重平台化到一个聊天助手产品的扩展点里。
五个具体理由：

1. **问题不同**。它解的是"个人/团队助手在不可信设备与聊天通道边界上的治理"
   （WhatsApp/Telegram/Slack 通道、设备配对、operator 角色）；我们解的是"多租户
   服务端投资平台的 run 治理"（领域契约：citation、MDL 口径、as-of、决策必过人）。
   它的策略粒度是 tool/exec，我们的粒度是领域语义——它的框架里没有放这些的地方。
2. **租户模型冲突**。原文："one gateway is one trust domain"，多租户 = 每租户一个
   gateway（fleet 实验特性）。我们是 Casdoor 身份下的多用户单平台，模型不匹配。
3. **存储冲突**。它的状态是 per-gateway SQLite；D1/D2 要求 PG、每 App 一个逻辑库
   一条迁移链。转过去等于数据层再开一个异构真源。
4. **叠加运行时**。A4 已租 Codex/dsh 两个执行层；OpenClaw 自带 agent runtime
   （还能把 codex 挂成它的 plugin harness）——转向它不是替代我们的 Supervisor 而是
   在我们与 harness 之间再塞进一个完整产品，三层变四层。
5. **我们已有它通道层要做的事**。Web/Internal 接口分面、SSE、Casdoor 身份、Outbox
   都在或在建；它的 WS 协议/通道抽象对我们是重复建设。

**结论：不转向。但它的七条机制里有五条恰好打在我们设计的薄弱处，定向借鉴。**

### 2.3 该借鉴的五条（每条：机制 → 我们的现状 → 改动）

**B1 · "模型不路由" + 运行时选择是配置策略。**
OpenClaw 双重确认：通道路由确定性（模型不参与），harness 选择也是
model/provider 作用域的配置（`auto` 是确定性解析函数，不是模型决策）。
我们的现状：可行性文档 §3.1 已定 Supervisor v1 = 确定性代码路由 + 闭集分类器兜底。
**改动（加固而非转向）**：路由表与 Profile→harness 映射写成**版本化配置文件**
（不是代码里的字面量），变更走评审 + 落事件；分类器永不创作标签；未命中 → 通用档
+ 雷达事件（原设计保留）。这条借鉴的实质是：把我们已定的方向用"配置即策略"的
形式固化，并获得一个外部独立佐证。

**B2 · 被拒绝的工具应当不存在，而不是存在但被禁止。**
OpenClaw：权限模式直接从会话里**移除**工具定义（模型连 schema 都看不见），deny 永远
赢，无分类方法默认拒。
我们的现状：profiles.py 有 allowed/denied_tools；可行性文档 §3.3 已定网关白名单
fail-closed。
**改动（双层）**：第一层在会话组装时——dsh 侧用 preset 只挂该 Profile 的工具、
Codex 侧按 Profile 裁剪 MCP 暴露面，**被拒绝的工具不进入模型上下文**；第二层在
网关——未注册/未授权工具调用结构性强拒。两层都不可单独失效：harness 配置写错，
网关不放行；网关被绕过，模型手里本来就没有那把工具。

**B3 · 审批绑定 + 漂移即拒 + 触达不到人时 fail-closed。**
OpenClaw：exec 审批绑定规范化命令/cwd/环境哈希/文件操作数内容哈希，批准后任何
漂移即拒；无审批 UI 默认拒；严格情形不可软化。
我们的现状：可行性文档 §3.5 的 HITL 是"人在决策点批准"，没有定义批准的**对象粒度**。
**改动（直接升级 SQL 审批与决策 HITL 的语义）**：批准对象 = **绑定产物**——SQL 审批
绑定（SQL 文本 + 参数 + 数据源 + as-of）的哈希，决策审批绑定（备忘录 artifact 内容
哈希 + 证据快照 id）；批准后内容有任何变化 = 原批准作废、重新过人。HITL 超时策略
定为 **fail-closed**（决策类 run 等不到人就停在终态之外，绝不超时自动放行）。

**B4 · 凭据按次铸造 + 推理经网关代理。**
OpenClaw cloud worker：按次派发铸造凭据（10 分钟 TTL、哈希落盘、RPC 白名单），
推理经 Gateway 代理，worker 不持任何常驻模型/GitHub/云凭据。
我们的现状：可行性文档 §3.7 是"worker 环境持 API key、spawn 时白名单清洗下发"——
harness 进程仍持有真 key（能调通 OpenAI/DeepSeek 的就是真 key）。
**改动（v1 就值得做，两侧配置成本都极低）**：
- **推理代理**：模型调用经我们网关/代理出口，真 key 只在代理侧——Codex 的 provider
  `base_url`、dsh 的 `DEEPSEEK_BASE_URL`/`base_url` 参数都原生支持指向自建端点
  （可行性文档 §1 已核）。harness 进程拿到的 base_url 指向内网代理，进程里**一把
  真 key 都没有**。附带收益：token 计量在代理处天然落账（R8 的预算记账更准）、
  出口白名单收拢有了物理载体（R6）。
- **run 级令牌**：工具网关令牌按 attempt 铸造，subject 绑 run_id+profile+attempt_no，
  短 TTL，run 结束即吊销——把 I7 的"精确键 + allowlist"再收紧到时间维度。

**B5 · 有界恢复预算 + 崩溃循环熔断。**
OpenClaw：重启恢复在有限尝试预算内恢复中断 turn；崩溃循环熔断器保住控制面可达。
我们的现状：可行性文档 R5 有快照/恢复，没有定义"恢复尝试的上限"与"连续崩溃怎么办"。
**改动**：RunBudget 增加 `max_attempts` 档（第四维之外的第五维）；同一 Profile 版本
连续 N 个 attempt 启动即崩 → 熔断该 Profile 版本并落事件 + 告警，新 run 不再分发到
它（防"dsh 某钉版在我们环境里坏了，所有财务 run 排队送死"）；快照格式带 harness
版本号，restore 校验兼容性（学它"库比自身新即拒开"）。

### 2.4 明确不借的清单

WS Gateway 协议与通道抽象（我们有 HTTP 分面 + SSE）、设备配对（我们有 Casdoor）、
SQLite 状态（D1/D2 要 PG）、它的插件 API 作为我们的扩展机制（我们的扩展 = Profile
+ 网关工具）、它的 agent runtime 本体（我们租 Codex/dsh）、fleet 多租户形态
（我们是单平台多用户）。

### 2.5 对可行性文档的具体修订点

以上五条落实为可行性文档的增量，不推翻其任何一节：

| 位置 | 增量 |
| --- | --- |
| §3.1 Supervisor | 路由表 = 版本化配置，变更落事件（B1） |
| §3.3 工具网关 | 双层门禁：会话组装层裁剪工具面 + 网关结构性强拒（B2） |
| §3.5 HITL | 审批绑定产物哈希、漂移作废、超时 fail-closed（B3） |
| §3.7 部署形态 | 推理经出口代理、真 key 不下发；run 级短 TTL 令牌（B4，R6 同步升级为"已收拢"） |
| §4 R5 | 恢复有界：max_attempts + Profile 版本熔断 + 快照版本校验（B5） |
| §6 落地顺序 | B4 推理代理进 S1 spike（两侧都是 base_url 配置，顺便验计量落账） |

---

## 3. 两问合一的一句话

换架构是旧分析的逻辑终点，好得有结构、且留有反证条款（§1.4）；OpenClaw 证明了
我们 Supervisor 的形态选择（确定性路由 + 代码强制策略 + 不可信执行）是对的方向，
它的价值是**机制教师**而不是**平台候选**——借五条机制（B1–B5），一行它的代码
和架构都不进我们的仓。

## 4. 速查

```text
OpenClaw 机制锚点：~/repo/openclaw/docs/start/why-openclaw.md（信任边界/策略即代码/凭据/版本化状态）
                ~/repo/openclaw/docs/channels/channel-routing.md（模型不路由原文）
                ~/repo/openclaw/docs/agent-runtime-architecture.md（Runtime Selection 配置策略）
                ~/repo/openclaw/docs/concepts/architecture.md（WS 协议/配对）
换架构事实锚点：development-plan.md（执行层租用原定）、constraints.md A4、
               investment-app-agent-architecture-kimi.md §1/§7（论证回收与壁垒清单）
修订落点：supervisor-dual-harness-feasibility-kimi.md §3.1/§3.3/§3.5/§3.7/§4 R5/§6
```
