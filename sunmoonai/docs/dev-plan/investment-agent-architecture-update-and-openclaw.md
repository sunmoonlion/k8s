# 架构更新是否合理，以及要不要转向 OpenClaw Gateway

> 最后更新：2026-09-02
>
> **性质：决策底稿，不是 baseline。**不要求人拍板清单；把两个问题写清楚。
> 承接 [`investment-agent-architecture-feasibility.md`](investment-agent-architecture-feasibility.md)。
>
> 问题：
>
> 1. 我们从自研执行体系改到「租用 Codex / DeepSeek Harness」，合理吗？比原来更好吗？
> 2. `~/repo/openclaw` 的 Gateway 做法，路由和 Supervisor 该借鉴、完全转向，还是另有更好建议？
>
> 取证：OpenClaw 文档与源码（`docs/start/why-openclaw.md`、
> `docs/specs/codex-supervision.md`、`docs/gateway/sandbox-vs-tool-policy-vs-elevated.md`、
> `docs/tools/acp-agents.md`）；本仓
> [`development-plan.md`](development-plan.md)、
> `~/codex-reference-archive/cursor/investment-app-agent-architecture-cursor.md`、
> 当前 Pilot / Agent v4 两条链。

## 0. 先说结论

| 问题 | 判断 |
| --- | --- |
| 更新合理吗 | **合理。**改的是执行循环的所有权，不是产品控制面。 |
| 比原来更好吗 | **执行层更好；控制面必须把原来最强的部分留下。**丢掉统一 Task / 预算 / 事件，就会比原来差。 |
| 转向 OpenClaw 吗 | **不要整机替换。** Gateway 的信任切分值得抄，产品形态抄过来会把投资 App 变成 IM 助手。 |
| 更好的建议 | Investment 自己当 Gateway（FastAPI + Postgres 已经是）；Codex/Harness 当 untrusted execution；政策三闸（在哪跑 / 能调什么 / 破例）用代码执行，不靠提示词。 |

一句话：

> 原来自研的是「控制面 + 执行循环」捆在 LangGraph 里。现在只把**执行循环**租出去，
> **控制面留下并加强**。OpenClaw 证明这个切分是对的；它自己不当我们的控制面。

## 1. 「原来的架构」到底是哪一套

仓里其实叠了三层，不能混着比。

### 1.1 代码现状（自研执行）

两条重叠链，都是自研 LangGraph 循环：

```text
Agent v4     AgentRunService → celery agent_graph → walking skeleton
Web/Internal PilotService    → celery pilot_agent_graph → 检索 + LLM + HITL
```

共用一部分 Session/Run/事件/副作用表，但恢复、取消、投影并不统一。
`agent_profile_key` 已写入 Run，**生产图不消费**。`RunBudget` 是内存对象。

这是「自研架构体系」在运行的部分：我们自己转轮次、自己调工具、自己当 runtime。

### 1.2 2026-08-22 总稿（自研引擎、借 Codex 思想）

`~/codex-reference-archive/cursor/investment-app-agent-architecture-cursor.md`：

- 一个 Agent；浏览器入口；服务端控制面；Docker 是 Host
- 熟路静态图、生路通用循环，**同一套 LangGraph + 同一套 Run**
- 借 Codex 控制环，**不借桌面、不借工具名、不把 Codex 当整机**

这条的强处是地基：一种 Task 模型、一条 timeline、预算/事件/HITL 不分家。
弱处是把生路循环也自研——等于再做一遍 Codex core。

### 1.3 2026-08-29 开发计划（已经决定租用执行层）

[`development-plan.md`](development-plan.md) 已经写了：

- 通用执行层采用 `openai-codex`，不自建轮次、隔离、中断、审批协议
- 只依赖 SDK，不打 app-server 裸协议
- harness 只给执行原语，运作纪律自建
- 四本账必须落 PostgreSQL；harness 本地存储不算数
- 问数是专用 Profile 的一个实例，不是另一套架构

所以 9 月「Codex + Harness SDK worker」**不是突然推翻 8 月方向**，而是把
8-29 的租用决定落到两个具体 runtime，并承认 8-22「两边都用同一个
LangGraph 引擎」这一句不再成立。

要比较的是：

| | 自研执行（现状 / 8-22 引擎句） | 租用执行（8-29 / 9-02） |
| --- | --- | --- |
| 控制面 | 自建（应对） | 自建（应对，且必须更硬） |
| 通用循环 | 自建 LangGraph | 租 Codex |
| 专用循环 | 自建图 + 工具 | 租 Harness Profile（问数工具仍可自研挂上） |
| 熟路静态图 | 自建（应对） | **仍应自建或后置固化**，不要交给聊天循环 |

## 2. 问题一：更新合理吗？比原来更好吗？

### 2.1 合理：改的是不该自研的那一层

轮次、工具调用、沙箱内循环、模型会话恢复，Codex / Harness 已经是完整产品。
我们继续用 LangGraph 复刻，会长期落后于他们的协议（Codex 近三个月裸协议
破坏性变更远高于 Python SDK 门面——见 development-plan 实测表）。

投资产品真正的壁垒不在「再做一个 agent loop」，而在：

- Task / Attempt / Delivery 合同
- 权限与委托身份
- 预算、证据、citation、as-of
- 问数口径（MDL）与人的终审
- 和持仓 / 研究工件写回同一条业务账

把 loop 租出去、把上述留下，是正确的分工。8-22 总稿「不要再做一个 Codex」
与现在「不要自研 Codex core」是同一句话。

### 2.2 比原来更好的部分

1. **生路 / 通用编码**明显更好。自研 walking skeleton 没有 interrupt / steer /
   output_schema / 原生 thread 恢复；Codex SDK 有。再自研要几年。
2. **专用 Agent 的扩展方式更好。**新增财务能力优先加 Profile + 工具，而不是
   fork 一套图。Harness 的 preset/skill/MCP 正好是这个载体；自研就要为每个
   领域复制一份 LangGraph。
3. **与 8-29 纪律一致。**四本账、Port 可 Fake、不把不变量放执行进程——租用
   之后这些纪律更有必要，不是更弱。
4. **能停掉双链膨胀。**现状 Pilot 与 v4 已经两套循环。若再自研第三套
   「财务图」，会比租用更乱。租用的前提是先收成**一条** Task 内核。

### 2.3 会比原来更差的部分（必须守住）

1. **丢掉统一 Run。**8-22 最硬的一条是熟路生路同一 `Run`、同一 timeline。
   若 Codex 一条状态、Harness 一条 jsonl、Pilot 再留一条，治理比现在更糟。
   租用成立的前提是 Supervisor 仍拥有 Task/Run。
2. **熟路被聊天化。**问数主链若也丢进通用 Codex 循环，口径、dry_plan、金标准
   都会糊掉。原来静态图在这里是对的。更新后熟路仍应是**我们的图或固定工具
   链**，只是执行可以发生在专用 worker 的工具里，而不是「模型现场规划 SQL」。
3. **控制面变薄。**租用容易滑向「Celery 里直接 `Codex().run()`」。没有 Port、
   预算落库、事件桥，比现在的 Pilot 还不可测、不可取消。Harness 尤其如此
   （SDK 无逐 prompt 取消）。
4. **Preview 风险。**Harness 是 Developer Preview。用它替换已经能跑的 Pilot
   问数，短期可能更差。所以专用路径必须后置、钉版本，不能和通用路径同日
   承诺。

### 2.4 比较句（可直接引用）

**比原来更好，当且仅当我们：**

- 留下并做强控制面（唯一 Task 内核、PG 四本账、SSE、HITL）
- 只把通用 / 生路循环租给 Codex
- 专用循环租给 Harness，但问数契约（dry_plan、Artifact、证据）仍是我们的
- 先 Fake Port 收口双链，再接真实 SDK

**比原来更差，如果我们：**

- 把 OpenClaw / Codex / Harness 任一者当成业务真源
- 为每个 SDK 再开一条 Celery 状态机
- 用杀进程冒充产品取消，用聊天冒充问数结果

所以：更新方向对；**不是「抛弃自研」**，是自研从 loop 退到 gateway。

## 3. 问题二：OpenClaw Gateway 是什么，借不借、转不转

用户说的「gate」在仓库里对应的是 **Gateway**：本地控制面，管 session、工具、
事件、channel 接入。架构口号是 **trusted gateway / untrusted execution /
deterministic policy**（`docs/start/why-openclaw.md`）。

### 3.1 它实际在做什么

```text
Channels / Control UI / CLI
        │  admission（配对、角色、scope）
        ▼
Gateway（受信控制面）
  连接、凭据、策略、版本化状态、审计
        │  工具请求 / worker turn
        ▼
隔离执行（默认关；需显式开）
  sandbox / node / cloud worker
```

与 Codex 的关系（`docs/specs/codex-supervision.md`）写得很干净：

> Codex App Server remains the thread and model-loop owner. OpenClaw supplies
> the fleet catalog, authenticated operator UI, session binding, and channel
> delivery.

ACP 路径同样（`docs/tools/acp-agents.md`）：

> OpenClaw owns routing, background-task state, delivery, bindings, and policy;
> the harness owns its provider login, model catalog, filesystem behavior, and
> native tools.

还有三道**分开的闸**（`sandbox-vs-tool-policy-vs-elevated`）：

| 闸 | 决定什么 |
| --- | --- |
| Sandbox | 工具**在哪跑**（host / 容器 / node） |
| Tool policy | 哪些工具**存在**；deny 必胜；read-only 直接拿掉写工具 |
| Elevated | 仅 exec 的破例，**不能**推翻 deny |

政策在代码里执行，不是写在系统提示词里请模型遵守。审批绑定 canonical
command + cwd + env hash，漂移则拒绝；没有审批 UI 则默认 deny。

`chat.send` 先 **admission 应答** `{ runId, status: "started" }`，再流式事件。
这就是「先入闸、后执行」。

### 3.2 不要完全转向 OpenClaw

原因不是它写得差，是**产品不是同一个**：

| | OpenClaw | investment-app |
| --- | --- | --- |
| 用户 | 个人或互信小团队的助手 | 投资产品的前端用户 |
| 入口 | WhatsApp / Slack / Discord / WebChat | 我们的 Web / Admin / Internal 三面 |
| 控制面实现 | Node 长驻 Gateway，WebSocket `:18789` | FastAPI + Postgres + Redis SSE |
| 默认安全 | 沙箱默认关，exec 在 gateway 主机跑 | 必须默认隔离、默认拒绝出网 |
| 业务合同 | 会话与 channel 投递 | Task / Attempt / Delivery、citation、as-of、MDL |
| 多租户 | 角色与 pairing；省略 `gateway.roles` 则角色边界关掉 | 委托身份、数据域、服务令牌，不能关 |
| 与 Codex | 插件监督别人的 loop，自己仍是 IM 网关 | 我们是投资控制面，不是聊天网关 |

整机换上 OpenClaw 等于：丢掉 request-lifecycle、三面身份、四本账、问数证据；
再在 Gateway 上重做一遍投资产品。Channel、配对码、Control UI、龙虾动画，
都不是阶段二该买的东西。

它的威胁模型也写明：单进程 harness 把 loop、channel、凭据、shell 放在同一
OS 用户下。我们若把 OpenClaw 当外层，只是换了一个更大的单信封，并没有自动
得到投资级隔离。

### 3.3 应该借鉴的（建议清单）

这些可以直接映射到我们的 Supervisor，不必引入 OpenClaw 进程：

1. **信任切分。** 控制面持有凭据与策略；执行器拿短时效、窄 scope 的委托，
   没有站立的 DB/LLM 密钥。对应我们：API 进程 ≠ worker 容器。
2. **Codex 仍是 loop owner。** 我们不实现第二套 app-server。只经
   `openai-codex`；句柄映射到 `run_id`。这与 OpenClaw 的 Codex 插件边界同构。
3. **Admission 先于执行。** `create_run` 成功只表示入闸（幂等、权限、槽位、
   预算预扣），执行在 worker 里异步开始。不要把「HTTP 200」当成「模型已跑完」。
4. **三闸分开，deny 必胜。**  
   - 在哪跑 = SandboxPort / 一 Run 一容器  
   - 能调什么 = Profile `allowed_tools` / `denied_tools`（今天已建模未接线）  
   - 破例 = 人的批准，不能用 elevated 绕过 deny  
   不要合成一个「权限提示词」。
5. **政策是代码。** read-only 就不要注册 write 工具，而不是靠模型自律。
6. **审批绑定现场。** dry_plan 通过的 SQL、要 exec 的命令，批准后哈希绑定；
   漂移作废。OpenClaw exec-approvals 就是这个。
7. **无审批 UI 则拒绝。** 与人稿终审一致；超时单独成态，不折成拒绝。

### 3.4 明确不要借的

- Gateway WebSocket 作为产品主协议（我们已有 HTTP + SSE）
- Channel / pairing 当用户体系
- 默认 host 执行
- 用 OpenClaw Chat 当投资前端
- 让 OpenClaw 再包一层 Codex，我们再包 OpenClaw（三层 loop）
- ACP 大总线（Harness 有 ACP，Codex 主路径是 app-server；我们按 SDK 走，
  不先上 ACP 联邦）

## 4. 更好的建议（目标拓扑）

把 OpenClaw 的词换成本产品的词：

```text
前端 / Admin / Internal
        │  身份在各自 interface 验完
        ▼
Investment Gateway = FastAPI 应用层 + Postgres
  Task/Attempt 内核、四本账、profile 路由、admission、审计
        │  AgentWorkerPort
        ├─ Codex worker      （通用 / 生路循环）   不受信执行
        ├─ Harness worker    （专用 Profile 循环） 不受信执行
        └─ 熟路工具链        （Wren dry_plan/query 等）可先不经大循环
```

路由仍是 **profile 表**，不是 OpenClaw 式 channel routing，也不是模型现场选
worker。Supervisor 是应用服务，不是第三个 agent runtime。

和「完全自研 LangGraph」比：少造一个 Codex。  
和「完全转向 OpenClaw」比：少买一个 IM 操作系统，保住投资合同。

## 5. 对可行性文的修正（不改方向，收窄一处）

[`investment-agent-architecture-feasibility.md`](investment-agent-architecture-feasibility.md)
里「熟路也进专用 worker」容易读成「问数也去聊天」。这里收窄：

- **通用 / 生路**：Codex SDK。
- **专用开放循环**（研报、尚无静态图的财务任务）：Harness Profile。
- **已能画边的问数主链**：我们的节点 + Wren 工具；可以跑在专用 worker 进程里，
  但编排权在我们的图/固定链，不在模型。

这与 8-22「熟路先行、生路随后、热了固化」一致，也与 8-29「问数是专用实例
不是另一套架构」一致。

## 6. 边界

- 未把 OpenClaw 跑起来对接 investment-app；判断来自文档与代码结构，不是联调。
- 未比较 OpenClaw 与我们在成本、多租户配额上的数字。
- 本文不吸收进 constraints；方向被批准后，再改 development-plan 的「执行层
  租用」段落，写明两个 SDK 与三闸。
