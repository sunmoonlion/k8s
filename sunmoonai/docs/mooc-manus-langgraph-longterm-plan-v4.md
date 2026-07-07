# MoocManus 长期智能体平台架构规划

版本：**v4**
定位：在 app-platform/research-app 中**全新建设**一个以 LangGraph 为编排运行时、可长期维护、可扩展、支持多智能体与长期记忆的智能体平台。旧 `imooc-mas/mooc-manus` 已废弃，仅作领域概念启发与 golden 样本来源，不作工程底座、不迁移、不兼容。
更新时间：2026-06-27
基线：继承早期规划中的工程判断，口径统一为 greenfield 全新重建。
设计策略：以 greenfield / M1·M2 切分 / Walking Skeleton / 评估前置 / 控范围控制落地节奏；以 Event-Message-Command-Transport 边界、ADR 铁律、目标态 schema 控制类型体系。完整类型体系**一律按本文 M1/M2 节奏落地、并显式打 M2/目标态标签，不在 M1 铺满**。

> 本文的两条主轴：
>
> **主轴一（节奏）：先验证，再形式化；先打通竖线，再铺平台。**
> 不「先规划一切、再验证」，不把多租户 / CQRS / GraphRegistry / 四类事件全量上在前面。而是：先用最小代价证伪最危险的假设（Walking Skeleton），把评估骨架提前，明确切出 **M1 必须** 与 **M2 延后**，并把「过度设计吞掉产品进度」列为一等风险。
>
> **主轴二（边界，按节奏主轴落地）：**
> 建立 Event/Message 类型体系（Command、TransportMessage、拆 UIEvent）——
> - 现在采用：`DomainEvent`（事实真相源）与 `UIEvent`（投影）的区分、`Command`（请求意图）与 `Event`（已发生事实）的命名规则、事件带 `schema_version`、`session_events` 落 `category/lineage`。这些**现在就声明为命名铁律**，成本低、防止改名债。
> - 延后：`TransportMessage` envelope、完整的四类事件基类拆分、`Command` 的完整类层级——这些在系统真正长出多 broker / 多 app / 审计合规需求时才必要，列入 **M2**，现在只留命名占位，不进 M1 实现。
> - legacy 问题：**确认旧 MoocManus 项目彻底废弃，本规划是全新重建（greenfield），不做 in-place 迁移**。因此不存在"回退到旧 flow"这回事——本修订的差异仅剩节奏：旧项目只作**只读行为参考 + golden 样本来源**，新系统在 golden set 验收通过前不被信任（用 Walking Skeleton + 评估骨架兜底，而非用旧 flow 兜底）。详见 §9.4、§33.1。

> ▲ 项目定位（重要）：旧 `imooc-mas/mooc-manus` 项目以后**彻底不再使用**。本文不是"如何把旧项目迁到 LangGraph"，而是"按这套架构在 research-app 里全新重建"。旧项目仅用于：(1) 抽取真实任务作 golden 样本；(2) 行为对照参考。**不部署、不兼容、不回退。**

> 标记说明：★ = 重点章节；▲ = 本修订新增/重排；◆ = 类型边界强化。

---

## 0. 结论先行

方向判断：**这是一个全新项目。旧 MoocManus 暴露的工程问题（手写 Planner-ReAct 循环、message/memory 体系混乱、图在 HTTP 进程内执行）值得作为反面教材；它验证过的领域概念（会话/计划/步骤/沙箱/工具）值得在新项目里重新建模采纳。但代码、结构、持久化一律从零设计，不继承、不迁移。**

三句话架构原则（不变）：

```text
LangGraph 管状态流转与恢复，
LangChain Core 管消息和模型工具协议，
Research App（新项目）管产品业务、事件、会话、工具、文件、沙箱、租户和持久化。
```

不要把新项目做成一个 LangGraph demo。要把 LangGraph 嵌入新 Research App，使它成为智能体执行内核。

### 0.1 ▲ M1 / M2 范围切分（本修订最重要的新增）

> ▲ 命名约定（避免混淆）：**`M1 / M2` 指项目交付阶段**（M = Milestone；`M1` = 先打通、能演示的竖线/MVP，`M2` = 等负载或真实需求出现后再做的平台能力），与封面的**文档版本 `v4`（本规划文档的第 4 次修订）不是一回事**。早期版本曾用 `V1/V2` 表示阶段，因与文档版本 `vN` 视觉太像、易被误读为"文档已到 v4，阶段是不是也该改"，本版起阶段统一改用 `M1/M2`；文档版本仍用小写 `vN`，schema 演进版本（§24.2 的 `v1 -> v2 -> current`）也仍是小写，二者互不相关。

早期规划列了 13 个阶段、21 条 ADR。问题不在内容对错，而在**全部堆在一条路线上**——对一个仍是「手写 Planner-ReAct 能跑」的项目，这会把一个能落地的产品拖成永远发不出的平台工程。所以先把目标切成两层：

```text
M1「能用、能演示、能验证」——先打通这一条竖线（P0，必须）：
  1. Walking Skeleton：证伪最危险的三个假设（§6.5）
  2. 最小评估骨架：golden set + LLM 录制回放（§28.3 前移）
  3. 消息体系 LangChain Core 化（§11）
  4. 单 Graph（Planner-ReAct）+ State/Reducer（§14）
  5. 执行拓扑：API 入队 / Celery graph-runner / Redis / SSE（§6）
  6. checkpoint + interrupt + resume（§17）
  7. 重放安全：reducer 幂等 + 工具副作用幂等 + 并发锁（§15）
  8. EventSink + DomainEvent/UIEvent 区分（◆ 类型边界强化，最小实现，§18）

M1 明确"先不做"（不是删除，是等负载/需求真正出现再做）——M2：
  - 多租户 SecurityContext 全链路传播（§21）—— M1 留单租户占位即可
  - GraphRegistry 版本化 + run 版本锁定 + 灰度（§15.4）
  - CQRS 读模型物化（§18.2）—— M1 直接查事件流够用
  - 完整四类事件基类拆分 + TransportMessage envelope（§18，◆ 部分延后）
  - Model Gateway 多 provider fallback（§23）
  - Supervisor 多智能体（§20）
  - Integration Event / RabbitMQ 跨 app（§18.1）
  - 长期记忆 Store 深度集成（§12.4/12.5 仅在 M1 留接口）
  - RAGFlow 深度集成（§13，M1 最多 retrieve 只读）
```

判定一件事属于 M1 还是 M2 的尺子：

```text
"不做它，单 Graph 任务就跑不通 / 不可恢复 / 调不动" -> M1
"不做它，系统照样能跑，只是还没多租户/多 app/多模型/可灰度" -> M2
```

### 0.2 推荐最终形态（不变，作为北极星）

```text
采纳并重新建模（领域概念来自旧项目验证，但代码全新实现）：
      Session / Event / Plan / Step / File / Sandbox / Tool / Repository / UoW / API / UI
不照搬：手写 Planner-ReAct 循环 -> 改为 LangGraph Graph
      Dict 消息列表 -> 对齐 LangChain Core BaseMessage 的消息体系
      简单 Memory JSON -> AgentState(checkpoint) + AgentMemory(session) + LongTermMemory(跨 session)
新增：Graph Runtime / Event Sink / Message Mapper / Memory Manager /
      Tool Adapter / Agent Registry / RAGFlow Client / Observability /
      执行拓扑 / Ports & Adapters / 控制面数据面分离 / 多租户 / Model Gateway
```

平台分工（不变）：

```text
knowledge-app:  知识库、RAGFlow、知识管理后台、文档处理 worker。
research-app:   智能体研究/任务平台、LangGraph runtime、会话、任务、沙箱、前端交互。
research-app -> knowledge-app:  通过 RAGFlow API / 内部服务地址调用知识库能力。
```

---

## 1. 设计依据与官方能力校准（不变）

官方文档对 LangGraph 的定位：面向长运行、有状态 Agent 的低层编排框架和运行时，重点能力是 durable execution、streaming、human-in-the-loop、persistence，而不是替你隐藏 prompt、工具、业务模型和产品结构。

- LangGraph 适合做编排运行时。
- LangChain Core 适合做模型、消息、工具协议层。
- 新项目必须拥有自己的业务领域模型，并吸收旧项目验证过的领域概念（重新建模，不继承旧代码）。
- 不能把业务事件、审计日志、用户会话直接塞进 LangGraph state 当万能容器。

官方持久化能力区分：

```text
Checkpointer: 持久化单个 thread 的 graph state。短期会话连续性、HITL、time travel、fault tolerance。
Store:        持久化跨 thread 的应用数据。长期记忆、用户偏好、事实、共享知识。
```

核心结论：**checkpoint 不等于 memory，memory 不等于 event log。** checkpoint 持久化的是运行时 state 的快照（state 本身不独立落库，落库的就是 checkpoint = ThreadMemory）；store 才是跨 thread 的长期记忆（详见 §12.1）。

---

## 2. 项目愿景（不变，略收敛）

MoocManus 应演进为**面向复杂任务的长期智能体平台**，具备：多轮任务会话、长任务执行、计划与步骤追踪、工具调用与沙箱执行、人类介入/审批、中断后恢复、多智能体协作、长期记忆、文件产物管理、可观测可审计可测试、可按业务扩展不同 Agent/Graph。

核心难点不是"调通一次大模型"，而是：状态如何流转、上下文如何管理、工具调用如何可控、人类介入如何恢复、多 Agent 如何协作、事件如何给前端展示、失败后如何恢复、长期记忆如何不污染上下文、系统如何持续演进而不失控。

本规划以"长期工程化"为目标——**但工程化不等于一次性把所有平台能力建齐（见 §0.1）**。

---

## 3. 旧项目评价（作为反面教材与领域启发，不作底座）

旧 MoocManus 后端结构（仅作参考）：

```text
api/app
  application/services/
  domain/{models,services,repositories,external}/
  infrastructure/{repositories,models,external,storage}/
  interfaces/{endpoints,schemas}/
```

### 3.1 值得在新项目里重新建模采纳的领域概念

> 注意：是「概念值得采纳」，不是「代码值得保留」。新项目从零实现这些概念。

```text
Session: 任务会话聚合根。
Event:   时间线/审计/执行过程这一类产品能力值得有（但新项目按 DomainEvent/UIEvent 重新建模，见 §18）。
Plan/Step: 任务规划和进度表达。
Tool:    Shell、Browser、File、Search、MCP、A2A、Message 等工具能力面。
Sandbox: 隔离执行环境，是这类产品的重要差异化能力。
Repository/UoW: 领域层与存储层边界这一分层思路值得延续。
Application Service: 用例编排层这一职责划分值得延续。
```

### 3.2 主要短板（◆ Event/Message 语义边界诊断）

```text
Message:     命名像通用消息，实际只是用户输入 DTO（应为 UserInput）。
Event:       一个词同时承担了"前端时间线投影 / 审计事实 / 执行过程 / SSE payload"四件事，
             缺"事实(DomainEvent) vs 投影(UIEvent)"的分层。这是真实的概念债。
Memory:      messages 是 List[Dict]，缺强类型、版本、策略、边界。
Agent Flow:  Planner/ReAct 依赖手写 while loop，难以支持可靠中断、恢复、分支、并发、多 Agent。
Persistence: events/files/memories 都在 sessions JSONB 中，长期会膨胀。
执行拓扑:    图在 API 进程内同步执行（隐含），无法承载长任务，未用上已有 worker/队列。
```

▲ 本修订的取舍：Event/Message 的概念债**是真的**，但它**不是最危险的债**。最危险的是「执行拓扑 + 重放正确性 + 没有评估」。所以本修订承认并采纳事实/投影的拆分（§18），但**把它放在"先打通竖线"之后做最小实现**，而不是在写代码前先把类型学全量形式化。理由见 §9.4 与 §33.1 新增风险。

---

## 4. 目标架构总览（不变）

### 4.1 分层视图

```text
Frontend / API:      Next.js UI, FastAPI Routes, SSE, File Preview, VNC
Application:         AgentRunService, SessionService, FileService, ConfigService
Domain (只依赖 Ports): Session, Event, Plan, Step, UserInput, AgentProfile, Policy
Agent Runtime (ACL 内): LangGraph Graphs, Nodes, Edges, State+Reducer, Interrupt
Integration / Ports: LLMPort, ToolPort, CheckpointPort, MemoryStorePort,
                     EventSinkPort, SandboxPort, FileStoragePort, KnowledgePort
Infrastructure:      Postgres, Redis, RabbitMQ, Object Storage, Sandbox, RAGFlow
```

### 4.2 核心边界

```text
业务会话边界：Session 是产品视角的任务会话。
执行线程边界：LangGraph thread_id 与 session_id 默认一一对应。
前端展示边界：UIEvent 是 UI 投影视图（◆ 区别于 DomainEvent 事实，见 §18）。
模型上下文边界：LangChain Core BaseMessage 是 LLM 输入输出协议。
执行恢复边界：Checkpoint 是运行时 AgentState 的持久化快照（= ThreadMemory），不是"记忆"。
会话记忆边界：AgentMemory 是 session 级可压缩上下文。
长期记忆边界：Store / LongTermMemory 是跨 session 可复用知识。
租户隔离边界：tenant_id/project_id 贯穿 memory/event/file/sandbox（M1 留占位，M2 全链路）。
证据装配边界：EvidenceAssembler 是 run/session 级跨源证据的只读装配层（M2，见 §13.9），
  只读各来源结果、不持有存储；不是 LangGraph state、不是 memory、不是 RAGFlow dataset。
```

不要把这些边界合并成一个"大 JSON"。

---

## 5. App Platform 对齐设计

新项目**直接在 `app-platform/research-app` 里建设**智能体能力，从一开始就是平台内的业务应用，不存在「从旧 Docker Compose 应用迁移过去」这一步。旧 MoocManus 不搬、不迁、不归位。

### 5.1 现有平台结构

```text
app-platform: auth-app / investment-app / info-app / knowledge-app / research-app / tools-app

research-app:  research-admin-backend(Python/FastAPI:8000) / research-admin-frontend
               research-web-backend(Node:3000) / research-web-frontend
               celeryworker-research-admin-backend(Python/Celery, Redis broker)
               nodebullworker-research-web-backend(Node/BullMQ)
knowledge-app: 同构 + ragflow
```

关键事实（来自真实部署清单）：每个业务应用天然是**双语言栈**——admin 侧 Python（FastAPI + Celery worker，Redis broker），web 侧 Node.js（:3000 + BullMQ worker）。新项目的 agent runtime 是 Python，与 admin 侧 Python 栈同构。**结论：LangGraph（Python）执行运行时落在 Python 栈，由 Celery worker 承载，而不是 Node 的 nodebullworker。**

### 5.2 能力归属

```text
新 Research App 智能体能力 -> 建在 research-app 内
RAGFlow                    -> knowledge-app/ragflow（已有）
Research App 通过 RAGFlow API / 平台内部服务访问知识库能力。
```

### 5.3 部署优先级

```text
knowledge-app priority = 950 ; research-app priority = 650
=> 先部署 knowledge-app/ragflow，再部署 research-app
```

### 5.4 新项目在 research-app 内的组件落位

```text
agent API + 用户侧入口 -> research-app Python 应用栈（FastAPI:8000），SSE/入队
graph-runner            -> research-app Celery worker（Python），LangGraph 真正执行者
智能体任务前端          -> research-web-frontend
sandbox runtime         -> research-app 依赖的沙箱服务（独立 deployment 或平台工具服务）
ingress / 网关          -> app-platform ingress/traefik（不自带 nginx）
本地开发                -> 可用 compose 起最小依赖，生产一律 app-platform/k8s
```

> 这些是「新建组件的落位」，不是「旧组件的搬迁」。旧 `mooc-manus/{api,ui,sandbox,nginx,docker-compose}` 一概不复用。

> ▲ sandbox runtime 落地说明（§22 展开；代码留到 app 实施阶段，此处只定形态与边界）：
> 沙箱不是 research-app 进程内的模块，而是工具调用真正执行副作用（跑代码 / shell / 写文件 / 浏览器）的**隔离算力**。业务侧只通过 `SandboxPort`（§7）解耦，其生命周期由数据面 graph-runner worker 申请/释放（§22）。上面第 243 行"独立 deployment 或平台工具服务"具体指下列三种形态之一，按 M1/M2 节奏选：

```text
落地模型（三选一，随阶段演进）：
  A. 按需拉 Pod/容器（M1 推荐）：不新写常驻服务；graph-runner worker 内的 SandboxPort 适配器
     直接调 K8s API，每个 run 拉一个受限 Pod 当沙箱，用完删。"平台工具服务" = 复用集群
     已有的容器运行时本身，而非另写一个常驻沙箱服务。
  B. 常驻 Sandbox Manager（M2）：独立 deployment，自管预热池 / 配额 / GC / 网络隔离，
     暴露内部 gRPC/HTTP 供 research-app 调用；等池化/配额/bulkhead 真出现再从 A 抽出来。
  C. 现成沙箱（可选）：E2B / gVisor(runsc) / Firecracker microVM 等，需要强隔离跑不可信代码时。

M1 决定：不单独写沙箱微服务。由 graph-runner worker 实现 SandboxPort 的 K8s 适配器
  （本地开发用 DockerSandbox / 生产用 K8sPodSandbox，落位见 §30 external/sandbox/），
  "每 run 拉一个 Pod、用完回收"。Port 边界现在就立住，A → B → C 的演进都不动 domain 与图代码（§7）。

M1 必须做（§22）：
  - GC：run 结束/超时/失败在 finally 释放沙箱；另加兜底清理（按 label + 存活时长扫孤儿）防
    worker 崩溃泄漏；Pod 设 activeDeadlineSeconds 作第三层保险。
  - 隔离基础：非 root、drop ALL capabilities、只读根文件系统、不挂 serviceaccount token；
    NetworkPolicy 默认禁止沙箱访问集群内部服务（DB/Redis/其它 app），仅按白名单放行出网。
M2：预热池 + 每租户配额 + bulkhead + 强隔离 runtimeClass（gvisor/kata）（对应 §22 的配额/隔离条目）。

app 实施阶段落地（此处不写代码）：SandboxPort 接口、K8sPodSandbox 适配器、Pod spec 安全上下文、
  NetworkPolicy、兜底 GC CronJob。
```

### 5.5 与 Knowledge App 的接口契约

```python
class KnowledgeRetrievalPort(Protocol):
    async def list_datasets(...): ...
    async def retrieve(...): ...
    async def ask(...): ...
    async def get_document(...): ...
```

实现：`RagflowKnowledgeRetrievalAdapter`。配置（`RESEARCH_RAGFLOW_BASE_URL/API_KEY/...`）进 secret/configMap，不写死。开发阶段允许 RAGFlow disabled，不阻塞部署。

> ▲ M1 注记：阶段 -1（平台边界约定）**只定文档与边界约定**，成本极低，可与 M1 并行；但 RAGFlow 深度集成本身是 M2（§0.1）。

---

## 6. ★ 执行拓扑：图在哪里跑（M1 核心，不变）

长 Agent 任务**绝不能跑在 HTTP 请求生命周期内**，必须落到已有的 worker/队列/消息基础设施。

### 6.1 组件拓扑

```text
research-web-frontend
  │ HTTP: POST /sessions/{id}/runs  (带 idempotency_key)
  ▼
research-app Python 后端 (FastAPI / 数据面入口)
  - 鉴权、构造 SecurityContext、创建 run(created)、入队、立即返回 run_id
  │ enqueue(run_id, graph_name, graph_version, input, security_ctx)   ← Celery 任务(Redis broker)
  ▼
graph-runner Celery worker (Python / 真正执行)
  - 取任务 -> 重建 SecurityContext -> 解析有效配置 -> 编译/取缓存 Graph
  - 执行 LangGraph，节点产出事件
  │ DomainEvent -> EventSink(DB append-only) -> Projector -> UIEvent -> Redis Pub/Sub(channel=session_id)
  │ token 增量  -> 仅 Redis Pub/Sub（易失，不落库）
  ▼
research-app Python 后端 SSE 端点
  - 订阅 Redis channel -> 推前端 ; 支持 last_event_id 断线补发（仅落库的 UIEvent）
```

> ◆ 此处明确：事件链路明确为 `DomainEvent -> EventSink -> Projector -> UIEvent`，但 M1 不引入独立 TransportMessage envelope（直接用 Redis/SSE 原生载体），envelope 是 M2（§18.5）。

### 6.2 队列分工与持久化真相源（ADR-009，不变）

```text
Celery (Python, Redis broker): Research App 内部 graph run 的调度与执行（执行者必须同语言）。
BullMQ / nodebullworker (Node): 仅 research-web-backend 的非 agent 轻量异步，不承载图执行。
RabbitMQ: 跨业务应用的 Integration Event（M2）。
Redis Pub/Sub: SSE 临时通道，token 增量 + UIEvent 推送，不作持久化真相。
```

```text
决策一（语言栈）：图执行者是 Python graph-runner（Celery worker），复用 research-app Python 栈。
决策二（真相源）：执行进度与可恢复点，真相源是 LangGraph checkpointer，不是队列 job 状态。
  队列只负责调度，可重投、可多 worker 竞争；checkpoint 唯一决定图进度。
```

### 6.3 同步快路径（可选优化）

对"预计极短"的轻任务可在 API 进程内同步执行并直接 SSE，但必须与异步路径共享同一套 Graph/Port/Event 代码。默认走异步路径。

---

## 6.5 ▲ Walking Skeleton：先证伪最危险的假设（本修订核心新增，排在所有 P0 之前）

这是本修订最重要的节奏取舍。在投入任何平台级建设（多租户、版本化、四类事件、记忆体系）之前，先用**最少代码端到端跑通一条竖线**，专门用来**证伪三个"错了就要推翻全盘"的假设**。

### 6.5.1 三个必须先验证的假设

```text
假设 A（恢复链路）：LangGraph checkpoint + interrupt + resume 在你们的
  Celery + Redis + Postgres 栈里真能跑通——worker 重启后能凭 thread_id 续跑。
  风险：若 checkpointer 在 Celery 异步上下文 / 多 worker 竞争下行为异常，
        §15/§17 整套设计的地基就是空的。

假设 B（流式对账）：SSE 断线 + last_event_id 补发，前端不缺字、不重复。
  风险：这是这类系统最常见的线上 bug；若对账模型不成立，§18.4 要重做。

假设 C（重放幂等）：一次工具调用的副作用，在重放/恢复时确实不会执行第二次。
  风险：若 tool_call_id + 结果缓存的幂等机制在真实 checkpoint 重放下失效，
        §15.2 的"重放安全"就只是纸面承诺。
```

### 6.5.2 骨架范围（刻意极小）

```text
做：
  - 一个 hardcode 的两节点 graph：ask_user 节点 + 一个有副作用的工具节点（如"写一个文件到沙箱"）。
  - 真实接 Celery worker 执行、真实 checkpointer 落 Postgres、真实 SSE 推前端。
  - 一个最小验证脚本（属于 §28.3 评估骨架的第一个用例）。

不做：
  多租户、SecurityContext、记忆、RAGFlow、版本化、事件分类、Model Gateway、UI 美化。
  消息体系可先用最小 StoredMessage，不要求完整 serializer/upcaster。
```

### 6.5.3 验收（必须全绿才进 M1 正式阶段）

```text
1. 触发 graph -> 走到 ask_user -> interrupt -> session.status=waiting -> 前端渲染等待。
2. kill 掉 Celery worker 进程，重启 -> 凭 thread_id 能 resume，不从头跑。
3. 用户补充输入 -> resume(Command) -> 工具节点执行 -> 文件确实只被写了一次。
4. 在工具节点后人为制造一次重放 -> 文件不会被写第二次（幂等缓存命中）。
5. SSE 中途断开 -> 用 last_event_id 重连 -> 时间线完整、不缺字、不重复。
```

### 6.5.4 为什么是它排第一

```text
- 它用最小代价把"整套架构赖以成立的三个物理假设"先验证了；
- 若某个假设不成立，现在改方案的成本，是把 13 个阶段都建到一半再发现的 1/100；
- 它产出的不是 PPT，是一段能 demo、能跑测试的真实代码，士气与判断力都来自它；
- 它天然顺手建立了 §28.3 评估骨架的第一个 golden 用例。
```

> 本节的取舍点正在此：把类型体系（Command/TransportMessage/UIEvent）做全是**那是被真实需求逼出来后的正确答案**；在骨架跑通、真实需求显形之前，先做全量类型形式化，是在没有反馈的情况下做大决策，风险更高。

---

## 7. ★ 端口与适配器目录（Hexagonal，不变）

domain 层只依赖一组 Port，所有外部技术都是 Adapter。

```text
domain/ports/
  llm_port.py             # ModelGateway 抽象，见 §23（M1 可只接一个 provider）
  tool_execution_port.py  # 工具执行，屏蔽沙箱/本地差异
  checkpoint_port.py      # 包一层 LangGraph checkpointer
  memory_store_port.py    # 长期记忆读写（对应 LangGraph Store，M1 留接口）
  event_sink_port.py      # DomainEvent / IntegrationEvent 事实输出（◆ 类型边界强化）
  sandbox_port.py         # 沙箱生命周期
  file_storage_port.py    # 对象存储
  knowledge_port.py       # RAGFlow / 知识检索
  # transport_port.py     # ◆ M2：TransportMessage 发布，屏蔽 Redis/SSE/RabbitMQ。M1 不建。
```

收益：可测试（图单测全对 Port mock）、可替换（DockerSandbox→K8s Pod Sandbox 不动 domain）、为 §9.3 ACL 边界提供支点。

---

## 8. ★ 控制面 / 数据面分离（不变，M1 可轻量）

```text
Control Plane (research-admin-backend)：
  定义并版本化 GraphSpec / AgentProfile / ToolConfig / MemoryPolicy / RAGFlow binding，产出不可变带版本工件。
Data Plane (research-app 后端 / graph-runner worker)：
  运行时只读"某版本的有效配置"执行，绝不在数据面热改配置语义。
```

两条规则：配置是数据不是代码（存库、带 version、发布即快照）；数据面对控制面的依赖单向异步（admin 改配置→发布事件→worker 拉新版本）。

> ▲ M1 注记：M1 可以先用 YAML + 进程内读取实现"有效配置"，**不需要 admin 后台 UI 和版本化发布流程**（那是 M2 GraphRegistry 的一部分）。控制面/数据面的**边界**现在就守住，**机制**延后。

---

## 9. 核心设计原则

### 9.1 MoocManus 不是 LangGraph 的附属项目

LangGraph 是执行内核，不是产品架构全部。新 Research App 自己拥有：用户会话、任务状态、前端事件、文件系统、沙箱、工具权限、业务配置、数据库模型、API 契约、租户模型。

### 9.2 ◆ Event / Message / Memory / Checkpoint 分离（事实/投影/请求三分）

早期规划的四分离（Event/Message/Memory/Checkpoint）正确但偏粗。本修订采纳把 "Event" 与 "Message" 各自再拆的判断，作为**命名铁律现在就立**（成本只是命名约定，却能防止后期大规模改名）：

```text
DomainEvent:   已经发生的事实，append-only，审计/回放真相源。回答"发生了什么"。
               名称用过去式：RunCreated / PlanCreated / StepCompleted / ToolCallFailed。
UIEvent:       从 DomainEvent 投影出的前端时间线视图，可重建、可丢、可补发。不是真相源。
Command:       请求系统做某事，可能被拒绝/等待。回答"要做什么"。
               名称用祈使式：CreateRun / ResumeRun / CancelRun。禁止命名成 RunCreateEvent。
UserInput:     用户输入 DTO，不叫 Message。
StoredMessage / LLMMessage: 给模型看的上下文消息（对齐 LangChain Core BaseMessage）。
Memory:        给 Agent 复用（AgentMemory=session 级；LongTermMemory=跨 session）。
Checkpoint:    运行时 state 的持久化快照（= ThreadMemory），不是一种"记忆"。
```

可互相映射，不可互相替代。

```text
▲ M1 落地范围（不全量上）：
  - 现在就遵守上面的"命名铁律"（成本 = 约定，收益 = 不欠改名债）。
  - M1 真正实现：UserInput、StoredMessage、DomainEvent、UIEvent、Checkpoint、AgentMemory。
  - M1 延后实现：Command 完整类层级（M1 用一个 CreateRun/ResumeRun 的最小请求体即可）、
    TransportMessage envelope（M1 用 Redis/SSE 原生载体）、IntegrationEvent（M2 跨 app 才需要）。
```

补充两条通道边界（参考 Agently）：

```text
观测通道（Runtime/Observation Event）：记录"运行时发生了什么"，面向 trace/debug/metrics，
  不作业务事实、不进前端时间线、不驱动路由（M1 可只打日志，TraceSink 是 M2）。
控制流通道：graph 路由只由 LangGraph state/edge/Command/interrupt 决定，
  禁止用任何 Event 驱动 graph 走向（铁律见 §15.5）。
```

### 9.3 ★ ACL（Anti-Corruption Layer）边界必须被强制（M1 就上）

```text
铁律：
  domain/models/ 不允许 import langgraph / langchain_core。
  application/services/ 不直接 import langgraph。
  普通业务服务不直接暴露 LangChain/LangGraph 类型。
允许边界：
  langchain_core 只允许出现在 message serializer/mapper、tool adapter、graph runtime。
  langgraph 只允许出现在 graph definitions、graph runtime、checkpoint adapter。
对外暴露的永远是 MoocManus 自己的类型（UserInput / DomainEvent / UIEvent / StoredMessage）。
强制手段：CI 用 import-linter / ruff banned-api 检查，违反即失败。
```

> ▲ 为什么 ACL 是少数"M1 就必须上"的平台件：它是**约束**不是**功能**，成本只是一条 CI 规则；一旦放任 langgraph 类型渗进 domain，后期再拆的成本是指数级的。这类"便宜且防腐"的约束，本修订都保留在 M1（同理还有命名铁律、schema_version、lineage 占位）。

### 9.4 ▲ 全新重建：先统一消息再建 Graph；安全网是 golden set，不是旧 flow

LangGraph 接入前必须先稳住消息体系。关于 legacy，**已确认旧项目彻底废弃、本规划是全新重建**（见文首项目定位），因此结论简单直接：

```text
本修订立场（greenfield）：
  - 不存在"回退到旧 PlannerReActFlow"这回事——旧项目不部署、不兼容、不回退。
  - 也不需要 Message=UserInput 之类的 legacy alias（没有旧代码 import 它）。
  - 验证期的安全网不是"旧 flow 兜底"，而是：
      Walking Skeleton(§6.5) 先证伪物理假设 + 评估骨架(§28.3) 用 golden set 守住能力回退。
  - 旧项目只承担两件事：抽取真实任务作 golden 样本；行为对照参考。只读，不接线。
结论：不留 legacy。理由很简单：本修订是全新重建，本就无兼容对象。
  本修订的差异只剩：在 golden set 跑出"新系统 ≥ 目标能力"之前，不把它接到用户流量上。
```

### 9.5 先单 Graph 稳定，再多智能体

多智能体不是多个类，而是：权限隔离、memory 隔离、任务交接、失败处理、事件归属、结果汇总。M1 先把 Planner-ReAct 单 Graph 做扎实（多智能体是 M2）。

### 9.6 状态最小化

State 只放执行需要的最小事实：messages / session_id / user_input / plan / current_step / pending_tool_calls / artifacts / status / error。完整事件历史、文件详情、长期记忆不进 state。

### 9.7 ★ 重放安全是第一性约束（M1 就上）

凡依赖 checkpoint 恢复/重放的设计，都必须保证：reducer 幂等、工具副作用幂等、并发幂等（见 §15）。这是 demo 与长期平台的分水岭，也正是 §6.5 Walking Skeleton 要先证伪的假设 C。

---

## 10. 领域模型重构（◆ 强化命名边界，▲ 按 M1/M2 切分实现深度）

### 10.1 UserInput 替代当前 Message（M1）

```python
class UserInput(BaseModel):
    text: str = ""
    attachment_ids: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)
```

> ▲ 全新重建，无需 `Message = UserInput` legacy alias（没有旧代码 import 旧 `Message`）。直接用 `UserInput`。

### 10.2 StoredMessage 对齐 LangChain Core（M1）

```python
class StoredMessage(BaseModel):
    schema_version: int = 1           # ★ Schema 演进，见 §24
    id: str | None = None
    type: str
    content: Any
    name: str | None = None
    additional_kwargs: dict[str, Any] = Field(default_factory=dict)
    response_metadata: dict[str, Any] = Field(default_factory=dict)
    tool_calls: list[dict[str, Any]] = Field(default_factory=list)
    invalid_tool_calls: list[dict[str, Any]] = Field(default_factory=list)
```

序列化优先复用官方 `messages_to_dict / messages_from_dict`，`StoredMessage` 仅作 DB schema 薄封装。转换集中在 `domain/services/messages/serializer.py`。

### 10.3 ◆ Command：请求意图，不是事件（M1 最小实现）

Command 表达"请系统做某事"，可能成功/失败/被拒绝/进入等待；不是已发生的事实。API、队列、worker、人工介入入口优先用 Command 表达请求，而非伪造一个"将要发生的 Event"。

```python
class BaseCommand(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str
    schema_version: int = 1
    run_id: str | None = None
    session_id: str | None = None
    idempotency_key: str | None = None
    created_at: datetime = Field(default_factory=datetime.now)

class CreateRunCommand(BaseCommand):
    type: Literal["CreateRun"] = "CreateRun"
    session_id: str
    user_input: UserInput
    graph_name: str

class ResumeRunCommand(BaseCommand):
    type: Literal["ResumeRun"] = "ResumeRun"
    run_id: str
    resume_token: str
    user_input: UserInput | None = None
```

Command 的处理结果必须落成 DomainEvent（`RunCreated` / `RunRejected` / `RunResumed` / `RunCancelled`）。

```text
▲ M1/M2 切分：
  M1 只需 CreateRun / ResumeRun / CancelRun 三个最小 Command；不需要完整 Command 总线、
    不需要 correlation/causation 链路。Command 在 M1 就是"带 idempotency_key 的请求体"。
  M2 再扩：CommandHandler 注册表、RequestToolApproval 等更多命令、跨进程 Command over TransportMessage。
```

M2 目标态（完整 Command 形态，作为 M2 目标态，M1 不必全建）：

```python
class BaseCommand(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str
    schema_version: int = 1
    run_id: str | None = None
    session_id: str | None = None
    idempotency_key: str | None = None
    created_at: datetime = Field(default_factory=datetime.now)
    metadata: dict[str, Any] = Field(default_factory=dict)

class CreateRunCommand(BaseCommand):
    type: Literal["CreateRun"] = "CreateRun"
    session_id: str
    user_input: UserInput
    graph_name: str
    requested_graph_version: str | None = None     # M2：配 GraphRegistry 版本锁定

class ResumeRunCommand(BaseCommand):
    type: Literal["ResumeRun"] = "ResumeRun"
    run_id: str
    resume_token: str
    user_input: UserInput | None = None

class CancelRunCommand(BaseCommand):
    type: Literal["CancelRun"] = "CancelRun"
    run_id: str
    reason: str = ""
```

### 10.4 ◆ Event：事实模型 + 通道分类 + 调用树身份（M1 上 domain/ui 两类）

```python
class RunLineage(BaseModel):           # ★ correlation/tracing 轴，区别于 SecurityContext(authz 轴)
    run_id: str
    root_run_id: str | None = None     # 多 Agent/子图调用树根（M1 = run_id）
    parent_run_id: str | None = None   # 父 run（M1 = None）
    session_id: str
    thread_id: str | None = None
    graph_name: str | None = None
    graph_version: str | None = None
    node_name: str | None = None
    agent_name: str | None = None
    tool_call_id: str | None = None
    # tenant_id/user_id/project_id 属鉴权主体，由 SecurityContext(§21.2) 携带，lineage 只引用不重存。

class EventCategory(str, Enum):
    domain = "domain"          # 业务事实，append-only，审计/回放
    ui = "ui"                  # 前端展示投影，可补发
    integration = "integration"# 跨 app 协作，走 RabbitMQ（M2）
    runtime = "runtime"        # 运行观测，trace/debug/metrics，可丢（M2 TraceSink）

class BaseEvent(BaseModel):
    id: str
    type: str
    schema_version: int = 1            # ◆ 类型边界：事件也带版本
    category: EventCategory
    lineage: RunLineage
    sequence_no: int | None = None     # 同 session 有序（仅 domain/ui 落库事件保证）
    created_at: datetime
    metadata: dict[str, Any] = Field(default_factory=dict)
```

◆ 采用"按通道拆基类"，但 **M1 只实现 DomainEvent / UIEvent 两类**：

```python
class DomainEvent(BaseEvent):
    category: Literal[EventCategory.domain] = EventCategory.domain
class UIEvent(BaseEvent):
    category: Literal[EventCategory.ui] = EventCategory.ui
# IntegrationEvent / RuntimeEvent -> M2（跨 app / 观测平台真正需要时再加）
```

核心 DomainEvent 名称（M1 子集即可）：

```text
RunCreated / RunStarted / RunWaiting / RunCompleted / RunFailed / RunCancelled
PlanCreated / PlanUpdated / StepStarted / StepCompleted / StepFailed
ToolCallRequested / ToolCallCompleted / ToolCallFailed
HumanInputRequested / HumanInputReceived
```

核心 UIEvent 名称（前端时间线消费）：

```text
TimelineUserMessageAdded / TimelineAssistantMessageFinalized / TimelinePlanDisplayed
TimelineStepUpdated / TimelineToolCardUpdated / TimelineWaitInputDisplayed / TimelineRunFinished
```

> ▲ M1/M2 切分：完整目标态会定义 domain/ui/integration/runtime 四类基类 + 全套名称。本修订 M1 只落 domain/ui，把 integration/runtime 留到对应能力（跨 app / 观测平台）真正进场时再加——避免一开始就维护四套永远只用到两套的类型。

M2 目标态（完整四类基类 + 全套事件名，作为 M2 目标态，M1 不必全建）：

```python
class DomainEvent(BaseEvent):
    category: Literal[EventCategory.domain] = EventCategory.domain
class UIEvent(BaseEvent):
    category: Literal[EventCategory.ui] = EventCategory.ui
class IntegrationEvent(BaseEvent):       # M2：跨 app 协作，走 RabbitMQ
    category: Literal[EventCategory.integration] = EventCategory.integration
class RuntimeEvent(BaseEvent):           # M2：运行观测，走 TraceSink，不进 session_events
    category: Literal[EventCategory.runtime] = EventCategory.runtime
```

```text
完整 DomainEvent 名称：
  RunCreated / RunStarted / RunWaiting / RunCompleted / RunFailed / RunCancelled
  PlanCreated / PlanUpdated / PlanCompleted
  StepStarted / StepCompleted / StepFailed / StepSkipped
  ToolCallRequested / ToolCallCompleted / ToolCallFailed
  HumanInputRequested / HumanInputReceived
  ArtifactCreated / MemoryCandidateExtracted / MemoryWritten
完整 UIEvent 名称：
  TimelineUserMessageAdded / TimelineAssistantMessageFinalized / TimelinePlanDisplayed
  TimelineStepUpdated / TimelineToolCardUpdated / TimelineWaitInputDisplayed / TimelineRunFinished
完整 IntegrationEvent 名称（M2）：
  DocumentIngestRequested / KnowledgeIndexUpdated / RunCompleted / ConfigPublished
RuntimeEvent（M2）：节点生命周期、模型 token 计量、reasoning delta、工具 stdout、耗时、内部告警。
```

### 10.5 Plan/Step 从"展示模型"升级为"执行模型"（M1）

```python
class Step(BaseModel):
    id: str
    description: str
    status: Literal["pending","running","waiting","completed","failed","skipped"]
    assigned_agent: str | None = None
    required_tools: list[str] = Field(default_factory=list)
    dependencies: list[str] = Field(default_factory=list)
    result: str = ""
    artifacts: list[str] = Field(default_factory=list)
    error: str | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
```

---

## 11. Message / Event 命名边界（◆ 采用"几类容易被叫成消息的对象"）

### 11.1 几类对象不混淆

```text
UserInput:         API 层用户输入 DTO，不叫 Message。
StoredMessage:     LLM 上下文消息的持久化形态。
BaseMessage:       LangChain Core 运行时消息协议，只在 ACL 内出现。
UIEvent:           前端时间线投影，不叫 MessageEvent。
DomainEvent:       已发生事实，审计真相源。
# TransportMessage: 通信 envelope，只在 adapter/broker/SSE 边界（M2，§18.5）。
```

### 11.2 转换路径（M1）

```text
UserInput -> HumanMessage -> StoredMessage
UserInput -> DomainEvent(HumanInputReceived) -> UIEvent(TimelineUserMessageAdded)

AIMessage(content final) -> StoredMessage
                          -> DomainEvent(AssistantResponseCompleted) -> UIEvent(TimelineAssistantMessageFinalized)
AIMessage.tool_calls -> DomainEvent(ToolCallRequested)
ToolMessage -> StoredMessage
            -> DomainEvent(ToolCallCompleted/ToolCallFailed) -> UIEvent(TimelineToolCardUpdated)
```

### 11.3 推荐目录

```text
api/app/domain/models/
  user_input.py  commands.py  events.py  lineage.py  stored_message.py
api/app/domain/services/messages/
  serializer.py        # BaseMessage <-> StoredMessage（复用官方）
  validators.py        # LLM 消息序列合法性
  input_mapper.py      # UserInput -> HumanMessage / Command payload
  tool_call_mapper.py  # AIMessage.tool_calls / ToolMessage <-> domain facts
api/app/domain/services/events/
  projector.py         # DomainEvent -> UIEvent / read model
  command_mapper.py    # Command result -> DomainEvent
  validators.py        # event schema/version/category/lineage
```

### 11.4 消息序列合法性（必须有测试）

```text
- SystemMessage 只能由系统生成；HumanMessage 来自用户输入或人工恢复。
- AIMessage 可含 text、tool_calls、usage、reasoning metadata。
- ToolMessage 必须关联已有 tool_call_id，不能脱离对应 AIMessage.tool_calls 单独出现。
- UIEvent 不直接作为 LLM 输入，必须由 DomainEvent/StoredMessage 映射。
```

---

## 12. Memory 体系详细设计

### 12.1 ★ 两个轴：运行时对象 ↔ 持久化表（权威定义，§12.2/§30 只引用不重述）

落地存储**只有三张表**：

```text
运行时对象（Python，内存）        持久化表              Port              作用域
──────────────────────────────────────────────────────────────────────────────────
AgentState (LangGraph state)      graph_checkpoints     CheckpointPort    当前 thread（一对多快照）
AgentMemory (Pydantic)            agent_memories        MemoryRepository  当前 session（1:1）
LongTermMemory (Pydantic)         long_term_memories    MemoryStorePort   跨 session（1:1）
```

铁律：

```text
- 落地存储里没有 "state" 表。AgentState 只通过 Checkpointer 以快照形式落到 graph_checkpoints。
- 后两个运行时对象与表 1:1；只有 AgentState 是"一个活体 → 一串 step 快照"，非 1:1。
- Checkpoint 不是"记忆"，而是运行时 State 的持久化形态（checkpoint ≠ memory）。
```

### 12.2 ★ WorkingState 与 ThreadMemory：同一份 state 的两个相态

```text
WorkingState：AgentState 在内存里"正在跑"的活体（messages/plan/current_step/...）；瞬态，用完即弃。
ThreadMemory：同一份 state 被 Checkpointer 落盘后跨"轮次/重启/resume"存活的线程级连续性；
              物理上就是 graph_checkpoints 里的快照。
关系：WorkingState ──Checkpointer 快照──> ThreadMemory(graph_checkpoints)
```

落地职责（用 Port 包一层）：Checkpointer(CheckpointPort) 持久化当前 thread state 快照 = ThreadMemory；Store(MemoryStorePort) 持久化跨 thread 长期信息 = LongTermMemory；AgentMemory(MemoryRepository) 是介于两者之间的 session 级可压缩上下文。

### 12.3 AgentMemory 与 MemoryPolicy（M1）

```python
class AgentMemory(BaseModel):
    schema_version: int = 1
    session_id: str
    agent_name: str
    messages: list[StoredMessage] = Field(default_factory=list)
    summary: str = ""
    pinned_facts: list[str] = Field(default_factory=list)
    token_count: int = 0
    version: int = 1
    updated_at: datetime

class MemoryPolicy(BaseModel):
    max_messages: int = 60
    max_tokens: int = 16000
    preserve_system_messages: bool = True
    preserve_recent_human_messages: int = 5
    preserve_recent_tool_results: int = 5
    summarize_when_exceed_tokens: bool = True
    allow_long_term_write: bool = False
    allow_long_term_recall: bool = True
```

不同 Agent 用不同 policy（planner 重 plan summary、react 重最近工具结果、research 重引用来源、code 重文件/diff）。

### 12.4 ▲ 长期记忆：分类、价值判据与"不写"清单（重写——这才是 longterm 该重点着墨处）

早期规划把长期记忆写得很薄（与事件/端口的笔墨严重不成比例），而文档名就叫 *longterm*。本修订把它补成一个**有判据、可度量**的子系统。注意：**长期记忆的深度集成属于 M2**（§0.1），但其判据必须现在想清楚，否则一开始就会写脏。

分类（不变）：Semantic（事实）/ Episodic（任务经验）/ Procedural（可复用流程）/ Preference（偏好）。

必带元数据：`scope / namespace / source_session_id / confidence / created_by / last_used_at / ttl / sensitive`。

▲ 写入价值判据（决定"什么值得写进长期记忆"）：

```text
值得写：
  - 可复用的决策与其理由（"该用户的项目用 pnpm 不用 npm"）。
  - 纠错经验（"上次按 X 方案失败，原因 Y，应改用 Z"）—— Episodic，最高价值。
  - 稳定偏好（语言、风格、默认参数）—— Preference。
  - 可泛化的流程（"导出报表的标准步骤"）—— Procedural。
坚决不写：
  - 一次性事实、随时间失效的状态（"现在是周五""任务进度 60%"）。
  - 能被 RAGFlow 检索到的文档型知识（那是 Knowledge App 的职责，不是记忆）。
  - 未经确认的模型臆测、低置信度推断。
  - 含敏感信息且未脱敏的内容（sensitive=true 默认不自动注入召回）。
```

### 12.5 ▲ 写入/召回流程 + 召回归因（记忆质量闭环）

```text
写入：任务完成 -> memory_extraction_node -> 候选记忆(带 confidence)
      -> 去重合并 -> 安全/敏感检查 -> 价值判据过滤(§12.4) -> 可选人工确认 -> 写 Store
召回：graph 启动 -> 按 user/project/intent 检索 -> 过滤无关与敏感
      -> 作为 context block 注入(标注来源+置信度) -> 标记本次 recall 的 memory_ids
```

▲ 召回归因（早期规划缺失，是记忆能否"越用越准"的关键）：

```text
- 每次召回的每条记忆，记录 used / ignored：本轮模型回答是否真的采纳了它
  （可由 summarize 节点回填，或离线用 LLM 判定）。
- 离线统计：召回命中率、被采纳率、误召回率、记忆 last_used_at 衰减。
- 长期不被采纳的记忆 -> 降权 / 进入 TTL 回收候选。
- 这些指标进 §28.3 的 golden set，作为"记忆质量门禁"。
```

原则：不要每轮写长期记忆；不要无脑拼进 messages；召回必须带来源和置信度；**没有归因统计，长期记忆只会单调膨胀并污染上下文**。

---

## 13. RAGFlow / Knowledge 集成（M1 最多只读 retrieve，深度集成 M2）

### 13.1 定位

```text
Research App / MoocManus: 会话、编排、事件流、计划、工具权限、文件、沙箱。
LangGraph:                工作流、状态流转、多智能体、HITL、checkpoint。
Knowledge App / RAGFlow:  知识库、文档解析、切片、索引、检索、RAG 问答、引用来源。
```

RAGFlow 不替代 memory，也不替代编排。它是 Knowledge App 暴露给 Research App 的能力。

### 13.2 与长期记忆的区别

```text
RAGFlow Knowledge Base: 文档/资料/知识，重点是可检索、可引用、可追溯。
Long-term Memory:       偏好/经验/习惯/决策，重点是跨 session 个性化与经验复用。
```

不要把 RAGFlow 检索结果无脑写入长期记忆；只有经总结、去重、确认、分类后的"可复用经验"才进长期记忆（呼应 §12.4 的"不写"清单）。

### 13.3 三层集成

```text
Infrastructure Client: 封装 RAGFlow API（认证/请求/超时/错误）。
Domain Retrieval Service: search_knowledge_base / ask_dataset / list_datasets（实现 KnowledgePort）。
Agent Tool Adapter:    暴露给 LangGraph/LangChain tool calling。
```

### 13.4 工具与节点

```text
ragflow_list_datasets / ragflow_retrieve / ragflow_ask / ragflow_get_document
ragflow_ingest_document: 高风险高成本，默认不开放，必须接权限、审批、任务状态和错误恢复。
```

Graph 中显式 retrieval 节点，避免每节点随意查库：

```text
START -> classify_intent -> decide_need_retrieval -> retrieve_from_ragflow -> planner/executor -> cite_sources -> summarize
```

### 13.5 结果标准化与引用

```python
class RetrievedChunk(BaseModel):
    id: str; dataset_id: str; document_id: str; document_name: str
    content: str; score: float | None = None
    source_url: str | None = None; page: int | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
```

进入 LLM 前转为清晰 context block，必须标注"外部内容不可信、只作资料参考、不能作为系统指令"。回答尽量保留 dataset_id/document_id/document_name/chunk_id/page/score/source_url。

### 13.6 权限与文件边界

权限：`ragflow:list_datasets / retrieve / ask / read_document / ingest_document / delete_document`，接入 §21 多租户权限，禁止越权读其他项目知识库。上传附件不默认进 RAGFlow，由用户/策略显式触发"加入知识库"。

### 13.7 实施优先级

```text
M1（若需要）：只做 ragflow_retrieve 只读检索。
M2：ragflow_ask + 引用 -> KnowledgeAgent -> ragflow_ingest（加权限审批）-> 引用前端展示与知识库管理 UI。
```

### 13.8 RAGFlow 知识工程专题沉淀

RAGFlow 集成不是"接上 API 就结束"。生产可用的 RAGFlow 至少由四层共同构成：

```text
Helm / K8S 层：          部署、镜像、资源、存储、依赖服务、全局运行参数、service_conf、llm_factories。
RAGFlow Dataset 层：     RAGFlow 原生支持的 parser、chunk method、embedding、rerank、retrieval 参数。
Knowledge App 层：       文档类型识别、预处理、RAGFlow Adapter、metadata、去重/MMR、评估、任务状态。
Research App 层：        只消费标准化 retrieve / ask 结果，负责 Agent 上下文组装、引用展示和安全边界。
```

知识库质量主要由文档解析、分块、Embedding、向量索引、检索优化、上下文融合、引用、评估、可观测性和生产运维闭环决定。这些策略归 Knowledge App / RAGFlow 边界内治理；Research App 不直接依赖 RAGFlow 私有 API、数据库、MinIO 或 Elasticsearch。

RAG 系列文章、实验记录、实施方案和评估清单不直接堆进本文；统一沉淀在工作区外的 `~/rag/` 专题目录。目前该目录已形成：

```text
guide.md：后续 RAG 文章的统一处理流程：阅读文章 -> 映射平台实施 -> 进一步完善。
RAG-02-分块策略-平台实施方案.md
RAG-03-Embedding-平台实施方案.md
RAG-04-向量数据库-平台实施方案.md
RAG-05-检索优化-平台实施方案.md
RAG-06-生成与上下文融合-平台实施方案.md
RAG-07-评估与可观测性-平台实施方案.md
RAG-08-生产实战-平台实施方案.md
RAG-09-多模态RAG-平台实施方案.md
RAG-10-前沿变体与高阶技巧-平台实施方案.md
RAG-11-经典业务场景设计-平台实施方案.md
RAG-02-golden-set.yaml：首个分块策略检索评估集。
```

本文只保留平台级约束：

```text
- RAGFlow 的 Helm values 只承载部署级/全局运行级参数，不承载所有知识工程策略。
- RAGFlow 原生稳定支持的能力优先通过 Dataset/UI/API 配置；不稳定或不支持的能力进入 Knowledge App 预处理/后处理。
- ingestion 前必须明确 Document Profile：Markdown/HTML/PDF/表格/图片/代码/业务场景。
- chunk 必须尽量自包含：保留标题路径、来源、页码、段落/行号、版本、content_hash 等 metadata。
- Embedding、chunk、retrieval、generation profile 都必须版本化，变更后可评估、可回滚、可重建。
- overlap 默认控制在 10%-25%，避免存储膨胀、重复召回和上下文浪费。
- retrieve 后必须考虑去重 / MMR / parent-document / rerank / token budget / 引用标准化。
- RAGFlow 深度集成进入 M2 前，先建立真实 query golden set、离线评估口径、bad case 回流和可观测性指标。
- 高风险场景（医疗、法律、金融数值问答等）默认不自动开放，必须有权限、审计、人工抽检和更高评估门槛。
```

`~/rag/` 中的专题方案作为 Knowledge App 的 ingestion / retrieval / evaluation contract 候选输入；只有沉淀为可执行配置、预处理流程、RAGFlow Adapter 能力或评估门禁后，才进入平台实现。该目录不是运行时依赖，也不进入 `k8s` Git 仓库。

### 13.9 ▲ EvidenceAssembler：跨源证据装配层（吸收 Agently 4.1.3.9 Workspace 的"证据装配"思想；M2，M1 只留边界与命名）

§13.8 的"去重 / MMR / rerank / token budget / 引用标准化"主要落在 Knowledge App / RAGFlow 边界内，且只覆盖 RAG 一条源。但真正进入 Agent prompt 前，证据是**跨源**的：

```text
RAGFlow RetrievedChunk（§13.5）
Memory recall（§12.5，带 confidence / sensitive / 来源）
文件引用（FileStoragePort）
工具产物 ArtifactRef（§19.3）
人工输入附件
```

v4 当前没有任何组件负责把这些合并成统一的模型上下文块。EvidenceAssembler 补这一层——它吸收 Agently 4.1.3.9 Workspace `retrieve(...)` 的**证据装配**思想（多源 → 去重 / rerank / token budget / 引用标准化 / model-hot 打包 / raw readback），但**不把 Workspace 作为存储层引入**。

定位（收窄为"装配"而非"存储"，避免 god object，呼应 §4.2）：

```text
EvidenceAssembler 只读各来源结果，不持有存储。
不替代 KnowledgePort / MemoryStorePort / FileStoragePort（不是 ResearchWorkspace 那样的统一存储）。
分源召回、各带治理元数据（RAG 带 provenance/引用；memory 带 confidence/sensitive/TTL），
  只在装配层汇合成带来源标签的 EvidenceBlock —— 不在召回口抹平各源治理差异。
```

M2 目标态（M1 不实现，仅作命名与边界占位）：

```python
class EvidenceBlock(BaseModel):
    id: str
    source: Literal["rag", "memory", "file", "artifact", "user_attachment"]
    ref: str                       # 指向原始事实源（chunk_id / memory_id / artifact_id / file_path）
    model_hot: str                 # 进 prompt 的紧凑投影（摘要 / 短结构）
    citation: dict[str, Any]       # dataset/document/page/score/confidence/来源，标准化引用
    sensitive: bool = False
    metadata: dict[str, Any] = Field(default_factory=dict)
```

装配职责（对齐 4.1.3.9 的 retrieval packaging）：

```text
- 去重：按 content_hash / ref。
- 结构门控 rerank：默认不发起模型 rerank；仅宽查询 / 噪声 / 跨源 / 混入 distractor 时才 rerank，
  失败降级为确定性顺序 + diagnostics（成本治理，呼应 §16 预算）。
- token budget 打包：按长度预算或 top_n 选择（对齐 4.1.3.9 selection="length"|"top_n"）。
- model-hot 投影 vs raw readback：只把摘要 / 短结构放进 prompt，原文通过 ref/readback 保留为事实源
  （呼应 §9.6 状态最小化）。
- 引用标准化：统一 dataset / document / chunk / page / score / confidence / 来源。
```

铁律：

```text
- EvidenceBlock 不进 LangGraph state（§9.6），只作为 prompt 装配的输入。
- model-hot 摘要进 prompt；raw 内容通过 ref/readback 保持事实源，不整块塞进上下文。
- ★ evidence ≠ 完成证明：检索命中只是候选证据，failed/empty evidence 只能支持"缺失数据"声明；
  最终结论是否成立，必须由 verifier / readback / 引用校验 / 人工审查 / 评估门禁（§28.3）支撑。
- 装配层不替代 RAGFlow、不替代 LongTermMemory、不替代 EventSink。
```

M1/M2 切分：

```text
M1：只在 §13.5 单 RetrievedChunk 与 §12.5 记忆召回之上留命名与边界占位；
    prompt 装配先用最小拼接 + token 截断即可，不做跨源 rerank / 投影。
M2：完整 EvidenceAssembler —— 跨源合并、结构门控 rerank、model-hot 投影、raw readback、evidence≠完成证明门禁。
```

---

## 14. LangGraph 运行时设计（M1 核心）

### 14.1 概念区分

```text
Graph: 一种任务流程（planner_react_graph、research_graph）。
Agent: 一种能力角色（planner、react、browser、coder）。
Node:  Graph 执行节点，可调用某 agent 或工具。
Tool:  外部动作能力（shell、browser、file、mcp）。
```

### 14.2 第一版 Graph：Planner-ReAct

```text
START
  -> load_session -> normalize_input -> recall_memory
  -> create_or_update_plan -> select_step -> execute_step
  -> call_tools -> observe_tool_result -> update_step -> update_plan
  -> route_next -> {select_step | summarize | wait_human | fail | budget_exceeded}
  -> persist_memory -> END
```

### 14.3 ★ State 设计 + Reducer（M1 关键）

裸字段在多节点/并行/重放时会丢更新，必须为累积型字段配幂等 reducer。

```python
from typing import Annotated, TypedDict
from langchain_core.messages import BaseMessage
from langgraph.graph.message import add_messages

def merge_plan(old, new):
    if old is None: return new
    if new is None: return old
    return new if new["version"] >= old["version"] else old   # 拒绝旧版本覆盖新版本

def append_unique(old, new):                                    # 按 id 去重追加，重放幂等
    seen = {x["id"] for x in old}
    return old + [x for x in new if x["id"] not in seen]

class PlannerReactState(TypedDict, total=False):
    session_id: str
    run_id: str
    tenant_id: str            # M1 可固定占位
    user_id: str | None
    project_id: str | None
    user_input: dict
    messages: Annotated[list[BaseMessage], add_messages]
    plan: Annotated[dict | None, merge_plan]
    current_step_id: str | None
    current_step: dict | None
    pending_tool_calls: list[dict]
    tool_results: Annotated[list[dict], append_unique]
    artifacts: Annotated[list[dict], append_unique]
    recalled_memories: list[dict]
    memory_summary: str
    status: str
    error: dict | None
    budget: dict              # 见 §16
```

原则：任何会被多节点写、或会在重放中重复写的字段，禁止裸覆盖，必须配满足幂等的 reducer。

### 14.4 Node 设计原则

输入输出明确；不直接操作 FastAPI request / ORM；副作用集中走 Port/service/sink；可单测、可观测、可重试；Node 返回 state patch，不随意改全局对象。

### 14.5 GraphRuntimeService（Facade）

`application/services/agent_run_service.py` 职责：创建 run、选择 graph（M1 单图，M2 含版本）、构造 config、传 thread_id、启动 stream、处理 interrupt/resume、把 LangGraph stream 转 MoocManus DomainEvent/UIEvent、更新 Session。API route 不直接调用 graph。

---

## 15. ★ 重放安全：reducer + 工具幂等 + 并发幂等（M1 核心，Walking Skeleton 先验证）

### 15.1 Reducer 幂等

见 §14.3：同一 patch 应用两次结果不变。

### 15.2 工具副作用幂等

```text
重放 checkpoint 时，已执行过的工具不得再执行（删文件/发消息/写库尤其致命）。
机制：tool_call_id + 结果缓存。重放时若该 id 已有结果，直接取缓存，不重新执行。
长时工具：走"提交 -> 返回 handle -> 轮询/回调"，工具节点可中断可恢复，不阻塞 graph、不长占 session 锁。
```

### 15.3 Run 生命周期状态机 + 并发控制

```text
created -> running -> (waiting <-> running)* -> completed
                                    \-> failed / cancelled / budget_exceeded
```

```text
- 一个 session 同一时刻只允许一个活跃 run：Redis 锁 lock:session:{id}（TTL+续租）。
- resume 幂等：带 resume_token(=当前 interrupt id)，不匹配则拒绝。
- run 必须带 idempotency_key：API 重试/双击/SSE 重连触发的重复创建靠它去重。
```

### 15.4 图版本锁定（GraphRegistry）—— M2

```text
GraphSpec: graph_name + version（不可变）+ nodes/edges/默认模型/入口/中断点定义。
agent_runs 必须 pin: graph_name + graph_version + agent_profile_version + prompt_version。
已发布 GraphSpec 不可改，只能发新版本；活跃 run 锁定创建时版本直到结束（天然灰度）。
```

> ▲ M1/M2：版本化是 M2。M1 单图阶段，graph 就是代码里的一份定义，不需要 registry 与 run 版本锁。但 §24 落库 schema 现在就预留 `graph_version` 字段（便宜的前向兼容）。

### 15.5 ★ 控制流铁律：路由不靠事件（ADR-019，M1 就守）

```text
铁律：graph 内部控制流只由 LangGraph 的 state / 条件边(edge) / Command / interrupt 决定。
      禁止用 DomainEvent / UIEvent / RuntimeEvent 驱动 graph 走向。
三件事各归各位：
  业务事实 -> Event（产出物，旁路 sink，不回灌路由）
  执行恢复 -> Checkpoint（thread_id + state 快照）
  路由控制 -> LangGraph state/edge/Command/interrupt
理由：用"已发生"的事件回灌驱动路由，会把审计日志和运行状态机耦合，重放/恢复时极难推理。
```

---

## 16. ★ 错误模型与预算治理（M1 上）

### 16.1 统一错误分类

```python
class AgentError(BaseModel):
    code: str
    category: Literal[
        "transient",       # 网络/限流 -> 自动退避重试
        "tool_failed",     # 工具业务失败 -> 作为 ToolMessage 喂回 LLM 换策略
        "invalid_state",   # 消息序列非法 -> 终止+告警，不可重试
        "needs_human",     # 缺信息/需审批 -> interrupt
        "budget_exceeded", # 超预算 -> 终止
        "fatal",           # 不可恢复 -> 终止
    ]
    retryable: bool
    detail: str
```

关键：`tool_failed` 是正常的 ReAct 观测，应喂回模型，而不是 try/except 吞掉重试。

### 16.2 预算与熔断

```python
class RunBudget(BaseModel):
    max_total_tokens: int
    max_tool_calls: int
    max_wall_seconds: int
    max_llm_calls: int
    consumed: dict[str, int] = Field(default_factory=dict)
```

每次 LLM/工具调用前检查，超限抛 `budget_exceeded` -> 优雅终止 + "因预算中止"总结。`route_next` 增加预算分支。这也是比 `max_iterations` 更可靠的防死循环保险。

---

## 17. Human-in-the-loop 设计（M1 核心，Walking Skeleton 先验证）

### 17.1 标准流程（基于 interrupt）

```text
node/tool 需要用户输入
  -> emit DomainEvent(HumanInputRequested)
  -> projector 生成 UIEvent(TimelineWaitInputDisplayed)（◆ 采用事实/投影分层）
  -> interrupt(payload) -> checkpointer 保存 state -> session.status=waiting
  -> 用户提交补充输入 -> graph resume(ResumeRunCommand) -> session.status=running
```

### 17.2 介入类型

ask_user / approve_action / edit_plan / select_option / confirm_memory。

### 17.3 规则

interrupt payload 必须 JSON 可序列化；interrupt 前副作用必须幂等（§15.2）；resume 必须验证用户权限和 session 状态；同一 session 不能并发 resume（§15.3）；等待态通过 `HumanInputRequested -> TimelineWaitInputDisplayed` 投影给前端。

---

## 18. ★◆ 事件架构：事实流 + 投影（M1 上 DomainEvent/UIEvent + Projector；TransportMessage 延后 M2）

> ◆ 本节采用"事实流 / 投影"分层。▲ 但本修订把 TransportMessage envelope、IntegrationEvent、CQRS 物化、TraceSink 全部划入 M2，M1 只做能让单 Graph 跑通并被前端正确渲染的最小集。

### 18.1 事件分层

```text
DomainEvent（事实流，M1）：graph/command handler 产生，写 session_events（append-only，审计/回放真相）。
UIEvent（投影视图，M1）：从 DomainEvent 投影出的前端友好视图，可按 last_event_id 补发。
Integration Event（跨 app，走 RabbitMQ）—— M2：research-app ↔ knowledge-app、配置发布等。
Runtime / Observation Event（旁路观测）—— M2：节点生命周期、token 计量、stdout、耗时。
  面向 trace/debug/metrics，不作业务事实、不进前端时间线、不驱动路由；M1 可只打日志。
```

分层判定准则（litmus）：

```text
丢了它会破坏审计 / 回放 / 计费 / 法务  -> DomainEvent（严格 schema，不可丢）
它只是 DomainEvent 的前端友好视图      -> UIEvent（投影，可补发，可丢可重建）
它要跨业务应用通知别的服务              -> Integration Event（RabbitMQ，M2）
丢了它只是少了排错 / 监控信息          -> Runtime/Observation Event（可摘要采样丢弃，M2）
```

### 18.2 ◆ Projector：DomainEvent → UIEvent（M1 核心机制）

```text
DomainEvent 是真相源；UIEvent 是可重建投影。
UIEvent 可丢弃并从 DomainEvent 重建；DomainEvent 不可丢。
同一个 DomainEvent 可投影出 0..N 个 UIEvent；多个 DomainEvent 也可折叠成一个 UIEvent
  （例如工具 requested/completed 合成一个工具卡片状态）。
前端不得直接订阅原生 LangGraph event；只消费 UIEvent 或 LiveDelta。
```

> ▲ M1 简化：早期规划中的 CQRS 读模型物化（session_timeline / current_plan_snapshot 物化表）是 M2。M1 直接从 `session_events` 投影/查询即可，数据量小时完全够用。先别为还没出现的读压力建物化视图。

### 18.3 EventSink / Projector 职责切分（M1）

```python
class EventSink(Protocol):            # 业务事实出口
    async def emit_domain(self, event: DomainEvent) -> None: ...

class EventProjector(Protocol):       # 投影，不是真相源
    async def project(self, event: DomainEvent) -> list[UIEvent]: ...
```

M1 实现：`DBEventSink`（写 session_events）+ `TimelineProjector`（DomainEvent→UIEvent）+ 直接经 Redis Pub/Sub 推 SSE。

```text
职责切分：
  EventSink 只负责 DomainEvent，保证不丢、有序、可补发。
  Projector 负责 DomainEvent -> UIEvent，不承担真相源职责。
  (M2) IntegrationEventSink(RabbitMQ) / TraceSink(runtime 观测) / TransportAdapter(envelope)。
```

### 18.4 ★ 流式输出与前端 token 映射（M1，◆ 采用 LiveDelta 命名）

> ◆ 此处将 `TokenDelta` 直接改名为 `LiveDelta`：命名是零成本的前向决定，用更中性的 `LiveDelta` 能避免后续改名债。

```text
stream_mode="messages": LLM token 增量(LiveDelta) -> 仅推 SSE live channel，打字机，不落库，断线不补发。
stream_mode="updates":  节点产出 -> DomainEvent -> EventSink -> 落库 + Projector 投影 UIEvent 推 SSE。
stream_mode="values":   （可选）整图 state 快照，调试用。
对账：前端用 (run_id, node, message_id) 拼接 LiveDelta 增量；节点结束产出 final UIEvent 做一次替换对账。
没有对账，断线重连后消息会"缺字"，是这类系统最常见线上 bug（Walking Skeleton 假设 B 先验证）。
```

实时输出只有一类「live、可丢、不落库」的增量（`LiveDelta`，走 Redis Pub/Sub / SSE live channel），统一靠 final UIEvent 对账——不另立 StreamChunk 概念；进度提示作为 `LiveDelta` 的一种 `kind`（如 `kind="token"|"progress"`）即可。

### 18.5 ◆ TransportMessage 与 Broker 边界（▲ 延后 M2，此处只记录目标形态）

当系统真正长出"多 broker（Redis/RabbitMQ/SSE）+ 多 app 协作 + 跨进程 Command"时，需要一个显式传输 envelope，把"业务对象"与"传输载体"分开：

```python
# —— 以下为 M2 目标形态（完整 schema 作为 M2 目标态），M1 不实现，仅作命名占位，避免将来改名债 ——
class TransportKind(str, Enum):
    command = "command"; event = "event"; response = "response"; live_delta = "live_delta"

class TransportMessage(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    kind: TransportKind
    schema_version: int = 1
    trace_id: str
    correlation_id: str | None = None
    causation_id: str | None = None
    run_id: str | None = None
    session_id: str | None = None
    payload_type: str
    payload_schema_version: int = 1
    payload: dict[str, Any]
    created_at: datetime = Field(default_factory=datetime.now)
```

M2 还需补的两个 Protocol（M1 不建，目标态记此）：

```python
class TransportAdapter(Protocol):     # 传输 envelope 边界（Redis/SSE/RabbitMQ）
    async def publish(self, message: TransportMessage) -> None: ...

class EventSinkM2(Protocol):          # M2：事实出口扩出 integration 通道
    async def emit_domain(self, event: DomainEvent) -> None: ...
    async def emit_integration(self, event: IntegrationEvent) -> None: ...
```

```text
M2 映射：
  Command   -> TransportMessage(kind=command) -> worker -> CommandHandler
  UIEvent   -> TransportMessage(kind=event)   -> SSE adapter -> 前端
  IntegrationEvent -> TransportMessage(kind=event) -> RabbitMQ -> 其他 app
  LiveDelta -> TransportMessage(kind=live_delta) -> Redis Pub/Sub
铁律（现在就立）：TransportMessage 不进入 domain model / graph state / memory / DomainEvent payload；只存在于 adapter/broker 边界。
```

M2 broker 边界全链路示例（Broker 只认识消息，不认识业务事件；payload 才是 Command/Event）：

```text
API -> Celery:        CreateRunCommand -> TransportMessage(kind=command) -> 队列 -> worker 反序列化为 CreateRunCommand
worker -> DB/Sink:    DomainEvent(RunStarted) -> DBEventSink append -> TimelineProjector 生成 UIEvent(TimelineRunStarted)
worker/API -> 前端:   UIEvent(TimelineRunStarted) -> TransportMessage(kind=event) -> SSE adapter
research-app -> knowledge-app: IntegrationEvent(DocumentIngestRequested) -> TransportMessage(kind=event) -> RabbitMQ
```

M2 CQRS 读模型（M1 直查事件流即可，物化是 M2）：

```text
写模型：session_events（不可变事件流，审计/回放真相）
读模型（M2 物化）：session_timeline（前端时间线）/ current_plan_snapshot（当前计划）/ run_summary
审计/回放靠事件流，前端读靠物化视图，互不拖累。
```

> ▲ 关键取舍：不要把 TransportMessage 写成 M1 领域模型与目录的一部分。在只有一个 Redis+SSE 通道、还没有跨 app 协作的 M1 阶段，引入 envelope 是**为尚未出现的复杂度提前付费**。折中：**现在立命名铁律 + 留上述完整 M2 目标态**，但 M1 直接用 Redis/SSE 原生载体，等第二个 broker 或第二个 app 真正进场再落地 envelope。

### 18.6 事件可靠性（M1）

event_id 全局唯一；run_id 标识一次 run；sequence_no 保证同 session 有序；tool_call_id 合并 requested/completed/failed；前端按 UIEvent.id 去重；SSE 断线按 last_event_id 补发（仅落库并可重建的 UIEvent）。

---

## 19. 工具体系设计（M1）

### 19.1 双层工具模型

```text
Domain Tool:          MoocManus 工具，处理沙箱/权限/文件/事件/错误（实现 ToolExecutionPort）。
LangChain Tool Adapter: 暴露给模型 tool calling。基础工具不直接依赖 LangGraph。
```

目录：

```text
domain/services/tools/
  shell.py browser.py file.py search.py mcp.py a2a.py message.py
  registry.py permissions.py
  adapters/langchain_adapter.py
```

### 19.2 ToolRegistry / ToolContext

```python
class ToolRegistry:
    def get_tools_for_agent(self, agent_name: str, context: ToolContext) -> list[BaseTool]: ...
```

ToolContext：session_id / sandbox_id / security_context / permissions / environment / event_sink / file_service。

### 19.3 ◆▲ 工具结果处理策略（Strategy 注册表，替代 if/elif）

旧项目在 `AgentTaskRunner._handle_tool_event()` 里按 `browser/search/shell/file/mcp/a2a` 堆 `if/elif`，把三件本该分开的事耦合在一起。新框架用**策略注册表**取代，加新工具时只新增一个 handler、不改已有代码（开闭原则）。

> ◆ 此处明确一个关键设计：一个工具结果要分别产出**三种东西**，必须拆开，不能混在一个返回值里——这比"只生成一个前端 content"更正确。

```python
class ToolResultHandler(Protocol):
    tool_name: str
    async def normalize_for_llm(self, result, ctx) -> StoredMessage: ...   # 给 LLM 看的 ToolMessage
    async def collect_artifacts(self, result, ctx) -> list[ArtifactRef]: ...# 截图/文件等产物落存储
    async def to_domain_events(self, result, ctx) -> list[DomainEvent]: ... # 事实事件（再由 Projector 投影 UIEvent）

class ToolResultHandlerRegistry:
    def register(self, handler: ToolResultHandler) -> None: ...
    def get(self, tool_name: str) -> ToolResultHandler: ...   # 缺省回落 DefaultToolResultHandler
```

内置策略（每个对应旧 if 分支）：`Browser`(截图→artifact)、`Search`(结果→引用列表)、`Shell`(console 摘要/长输出落 artifact)、`File`(读写同步对象存储)、`MCP`/`A2A`(远程返回标准化+保留 metadata)、`Default`(保底：JSON 序列化+错误标准化+安全截断)。

工具执行链路：

```text
tool_call -> ToolExecutionPort.invoke -> ToolExecutionResult
  -> registry.get(tool_name)
  -> normalize_for_llm  -> StoredMessage/ToolMessage（喂回 LLM）
  -> collect_artifacts  -> ArtifactRef[]（落对象存储）
  -> to_domain_events   -> DomainEvent[] -> Projector -> UIEvent（前端工具卡片）
```

铁律：

```text
- graph node / runner 禁止按 tool_name 写 if/elif；新增工具 = 新增/复用 handler 并注册。
- handler 可依赖 FileStoragePort/SandboxPort/EventSinkPort，但不得依赖 FastAPI request / ORM。
- "LLM 可见内容 / artifact / UI 投影"三者分开生成，避免前端展示字段污染 ToolMessage。
- handler 必须幂等：同一 tool_call_id 重放时不得重复上传文件/重复截图/重复写库（呼应 §15.2）。
```

> ▲ M1/M2 与"现在就拆"的理由：这个重构**便宜、纯属内部结构**，且**正好就是 §18.2 Projector「DomainEvent→UIEvent」的工具特化**——所以 M1 就该按策略拆，将来这些 handler 的 `to_domain_events` 几乎能平移成 projector 的工具卡片投影器，不白做。M1 可以先只把 `normalize_for_llm` + `to_domain_events` 做齐，`collect_artifacts` 按需补。

### 19.4 工具权限与高风险审批

权限：read_file / write_file / execute_shell / browser_access / network_access / mcp_access / a2a_access / write_memory / delete_memory。默认需审批：删文件、覆盖文件、执行 shell、访问外网、调用远程 MCP、写长期记忆、导出敏感文件。

> ▲ M1：工具权限**枚举与校验点**现在就上（便宜且涉及安全），但**审批流 UI / 多 Agent 差异化工具集**是 M2。

---

## 20. 多智能体架构（M2）

### 20.1 演进顺序

```text
阶段一（M1）：单 Graph，Planner + ReAct。
阶段二（M2）：Supervisor + 专业 Agent。
阶段三（M2+）：多 Graph、多 Agent、可配置编排。
```

### 20.2 AgentProfile

```python
class AgentProfile(BaseModel):
    version: int = 1
    name: str; role: str; description: str
    system_prompt_id: str            # 引用 PromptRegistry（§23）
    model_name: str                  # 经 ModelGateway 解析
    tools: list[str]
    memory_policy: str
    permissions: list[str]
    max_iterations: int = 10
```

### 20.3 推荐内置 Agent

PlannerAgent / ExecutorAgent / ResearchAgent / BrowserAgent / CodeAgent / FileAgent / CriticAgent / SummarizerAgent / KnowledgeAgent。

### 20.4 多智能体 memory 边界

```text
Private Memory:        单 agent 私有。
Shared Task State:     当前 graph 共享（plan/current_step/artifacts）。
Shared Session Summary:当前 session 所有 agent 可读。
Long-term Store:       按 namespace、权限、召回策略读取。
```

不要让所有 agent 共享一个无限增长的 messages。

---

## 21. ★ 多租户与安全上下文传播（M1 留占位，M2 全链路）

### 21.1 租户隔离贯穿每一层

```text
namespace 约定：{tenant_id}/{project_id}/{session_id}/...
长期记忆 Store、RAGFlow dataset、沙箱实例，全部按 tenant 隔离与配额。
```

### 21.2 SecurityContext 跨异步边界传播

```python
class SecurityContext(BaseModel):
    tenant_id: str
    user_id: str
    project_id: str | None
    scopes: list[str]      # ragflow:retrieve / tool:execute_shell ...
    run_id: str
```

入队时随消息序列化，worker 取出后重建，注入每个工具调用与沙箱请求；工具/沙箱执行前再校验一次 scope（纵深防御）。

> ▲ M1/M2：这是少数"现在留接口、M2 才全链路"的设计。M1 单租户场景，SecurityContext 可以是**固定单租户值 + run_id**，但**字段结构与"每跳重建"的传播位置现在就预留**——因为补租户隔离若要回填历史调用链，成本极高（同 §28 lineage 占位的理由一致）。

---

## 22. ★ 沙箱与资源生命周期 + 故障隔离（M1 基础，配额/bulkhead M2）

```text
归属：Sandbox 作为 SandboxPort 实现，由数据面 worker 申请/释放。
策略：
  池化：预热 pool 降冷启动；按 tenant 配额限制并发（配额 M2）。
  绑定：sandbox 生命周期 ≤ session；interrupt 等待期可回收，resume 时重建。
  GC：run 结束/超时/失败统一回收，避免泄漏（M1 就要做，否则跑几次就泄漏）。
  隔离：每租户独立网络/资源限制，防 noisy neighbor 与逃逸（M2 bulkhead）。
```

---

## 23. ★ 模型与 Prompt 抽象层（M1 单 provider，多 provider M2）

### 23.1 Model Gateway（实现 LLMPort）

```text
- 多 provider（OpenAI / Anthropic / 本地 vLLM / 自建）—— M2。
- 主备 fallback —— M2。
- 按 agent/任务路由不同档位模型 —— M2。
- 统一注入 token 计量、tracing、超时、重试、预算扣减 —— M1 就要（预算在 §16）。
- 屏蔽不同 provider tool-calling 协议差异 —— M1 接一个就行。
```

> ▲ M1：LLMPort 接口现在就定义（domain 不直接耦合某 SDK），但背后**先只接一个 provider（如 DeepSeek）**。Gateway 的多 provider/fallback/路由是 M2。

### 23.2 PromptRegistry（M2，M1 用带 id 的常量即可）

```text
prompt_id + version + 模板 + 变量 schema；运行时按 (agent, version) 取，trace 记录用了哪个版本。
M1：prompt 用带 prompt_id 的代码常量，先不做版本化存储；但事件/日志现在就记录 prompt_id（便宜的可追溯）。
```

---

## 24. 持久化与 Schema 演进

### 24.1 目标 schema（从零设计，不继承旧库）

新项目从一开始就按下面的目标 schema 设计；**没有"兼容旧 sessions JSONB"这回事**（旧库不连）。实现上允许起步从简（先少建几张表、读路径先直查），按负载再演进读模型/索引/物化视图——这是增量设计，不是迁移。目标数据模型：

```text
sessions(id,user_id,project_id,tenant_id,title,status,latest_message,latest_message_at,created_at,updated_at)
agent_runs(id,session_id,graph_name,graph_version,thread_id,idempotency_key,status,started_at,completed_at,error)
session_events(id,session_id,run_id,sequence_no,category,type,payload_schema_version,lineage JSONB,payload JSONB,metadata JSONB,created_at)
session_files(id,session_id,file_path,filename,mime_type,size,storage_url,metadata JSONB,created_at)
agent_memories(id,session_id,agent_name,schema_version,messages JSONB,summary,pinned_facts JSONB,token_count,version,updated_at)
long_term_memories(id,namespace,scope,tenant_id,user_id,project_id,memory_type,content,embedding_id,confidence,source_session_id,sensitive,metadata JSONB,ttl,created_at,updated_at,last_used_at)
graph_checkpoints(由 CheckpointPort 实现管理；存运行时 AgentState 的快照 = ThreadMemory)
读模型（M2）：session_timeline / current_plan_snapshot / run_summary（由 projector 物化）
```

> ◆ 类型边界：`session_events` 现在就含 `category / payload_schema_version / lineage`（事实/投影/版本/调用树都落得下）。这是便宜且防债的字段，M1 就建。

与记忆/状态相关的持久化表只有 **graph_checkpoints / agent_memories / long_term_memories** 三张——没有 `state` 表（对齐 §12.1）。

### 24.2 ★ Schema 演进与重放兼容（M1 就上 schema_version + upcaster 骨架）

```text
- 落库的消息/记忆/state/event 一律带 schema_version。
- 反序列化走 upcaster 链：v1 -> v2 -> current，老数据读出自动升级，绝不在读路径报错。
- checkpoint 尤其危险：代码升级后必须能读旧 checkpoint，否则一次发布让所有 waiting 任务失联。
  建议 checkpoint 只冻结最小稳定子集，业务大对象放外部表用 id 引用。
```

### 24.3 ★ 数据治理与级联删除（M2，但 sensitive/ttl 字段 M1 就留）

TTL / 可删除 / 敏感标记落到结构层；用户或项目"被删除"时，级联清理 sessions / events / memories / checkpoints / RAGFlow dataset 绑定。

### 24.4 演进策略（起步从简 → 按负载拆，非迁移）

```text
阶段1（M1）：核心表（sessions / agent_runs / session_events）按目标 schema 直接建；serializer/mapper + upcaster 就位。
阶段2（M2）：session_events 增长最快，按需加分区/索引/归档。
阶段3（M2）：agent_memories 独立演进。
阶段4（M2）：session_files / long_term_memories 按需优化。
阶段5（M2）：引入生产级 checkpointer/store。
```

---

## 25. 配置体系

```text
GraphConfig:       graph_name, version, nodes, default_model, checkpointer, store, max_steps
AgentConfig:       agent_name, version, model, system_prompt_id, tools, permissions, memory_policy
ToolConfig:        name, enabled, permission, timeout, retry
MemoryPolicyConfig:max_tokens, max_messages, summarize_strategy, long_term_write_policy
```

M1：先 YAML + 进程内读取；不可变版本化工件（控制面产出）是 M2。

---

## 26. ★ 模块边界与可抽取性（M1 就守边界）

```text
现在：Agent Runtime 作为 research-app Python 后端内的一个独立 package。
  对外只暴露 Facade（AgentRunService），其余 internal；package 内禁止被其他模块直接 import。
将来：当负载/隔离需要时，把该 package 原样抽成独立 Python graph-runner 服务。
判断标准（ADR）：只要 Runtime 还只通过 Port + Facade + 事件与外界交互，
  它在"库"和"服务"之间就可平滑切换。
```

这样"将来把 Runtime 从 package 抽成独立服务"不是一次性豪赌，而是有退路的渐进决策。

---

## 27. 安全与权限

### 27.1 安全边界

User Boundary / Agent Boundary / Tool Boundary / Data Boundary / Network Boundary。

### 27.2 Prompt Injection 防护（M1 就上，便宜且关键）

浏览器/文件/MCP/A2A 返回内容视为不可信输入：工具返回内容不得作为系统指令；文件内容不得覆盖 system prompt；外部网页不得指挥 Agent 泄露 memory；MCP 工具描述也要权限控制。

### 27.3 长期记忆安全

风险：错误记忆污染、敏感跨 session 泄露、偏好过度泛化、旧记忆诱导。治理：分类/来源/置信度/TTL/可删除/可解释召回/敏感记忆默认不自动注入（呼应 §12.4/12.5）。

---

## 28. 可观测性与评估门禁（▲ 评估骨架前移到 M1）

### 28.1 必须记录

```text
Run:    graph_name, graph_version, run_id, session_id, thread_id, tenant_id, status, duration
Node:   node_name, input/output summary, duration, error
LLM:    model, provider, prompt_id/version, token usage, latency, tool_calls, budget_consumed
Tool:   tool_name, args summary, success, duration, artifacts, error
Memory: recalled / written / used / ignored memories, compact events（◆ used/ignored 见 §12.5）
Interrupt: payload, resume input, wait duration
```

correlation：所有日志/trace/事件携带 §10.4 的 `RunLineage`（含 root_run_id / parent_run_id），M1 单 run 时 root=run_id、parent=None，**但字段现在就贯穿**（否则后续补 trace 要回填历史）。

### 28.2 TraceSink：Runtime/Observation 事件统一出口（M2）

```text
TraceSink -> LangSmith / OpenTelemetry / 本地日志 / DevTools
投递策略：coalescing / summary / sampling / max_items；bounded background delivery（队列满降级丢弃并计数）。
不阻塞主执行：对 graph 主路径非阻塞，带超时与 backpressure；trace 出口慢或挂不能影响业务 run。
fail-open：Runtime/Observation 事件消费者忽略未知字段，不按严格 schema 校验；
           Domain Event 仍按 schema_version + upcaster 严格演进。
```

> ▲ M1：Runtime/Observation 事件先**只打结构化日志**，TraceSink 与投递策略是 M2。但日志现在就带 RunLineage。

### 28.3 ▲ 评估骨架（从末期阶段前移到 M1，最小版）

早期规划把评估放在最后一个阶段——这对 Agent 系统是顺序错误：**没有评估，规划质量、工具选择、记忆召回都调不动，全靠手感**。本修订把它的最小版拉到 M1（紧跟 Walking Skeleton）：

```text
M1 最小评估骨架（便宜，却能给后续每一次改动兜底）：
  - LLM 调用录制回放（VCR 式），保证 graph 路由/状态/中断恢复测试确定性。
  - 5~8 个 golden 任务：纯文本 / 一次工具 / 多次工具 / 工具失败 / ask_user 中断恢复 / 带附件。
  - 每次改 graph/prompt/tool，CI 跑 golden set，指标回退超阈值则阻断合并。
  - 第一个 golden 用例直接复用 §6.5 Walking Skeleton 的验证脚本。

M2 扩展：
  评估维度补全——计划质量 / 工具选择正确率 / 最终回答正确率 / 无效工具调用 /
  错误写长期记忆 / 记忆召回采纳率（§12.5）/ 是否按要求等待用户 / 中断恢复是否正确 /
  检索证据是否被误当作完成证明（evidence ≠ verification，§13.9）。
```

---

## 29. 测试策略

### 29.1 单元测试

```text
messages: BaseMessage<->StoredMessage、ToolCall/ToolMessage<->DomainEvent、UserInput->HumanMessage、upcaster
events:   Command->DomainEvent、DomainEvent->UIEvent、event schema/category/lineage（◆ 类型边界强化）
memory:   window / summary / compaction / long-term extraction / recall 归因
graph:    routing / node IO / interrupt-resume / checkpoint restore / reducer 幂等
tools:    permission / timeout / error mapping / 副作用幂等
```

### 29.2 集成测试

```text
创建 session -> 发消息 -> graph 执行 -> 产生 DomainEvent -> 投影 UIEvent -> 保存 memory
工具调用 -> ToolCallRequested/ToolCallCompleted DomainEvent -> ToolMessage -> 后续 LLM
ask_user -> interrupt -> waiting -> resume -> completed
断线重连 -> last_event_id 补发；重复 enqueue -> idempotency_key 去重
```

### 29.3 金样本

纯文本 / 一次工具 / 多次工具 / 工具失败 / 人类介入 / 带附件 / 长上下文压缩。

---

## 30. 推荐目录结构

```text
api/app
  application/services/
    agent_run_service.py session_service.py memory_service.py event_service.py config_service.py
  domain/
    ports/
      llm_port.py tool_execution_port.py checkpoint_port.py memory_store_port.py
      event_sink_port.py sandbox_port.py file_storage_port.py knowledge_port.py
      # transport_port.py  # M2
    models/
      user_input.py commands.py events.py lineage.py stored_message.py   # ◆ 按语义拆分
      agent_profile.py agent_state.py                                     # agent_state.py = AgentState(运行时,不落地)
      memory.py memory_policy.py session.py plan.py security_context.py run_budget.py
    services/
      graphs/        planner_react_graph.py graph_registry.py            # supervisor_graph.py M2
      graph_nodes/   load_context.py planner.py select_step.py executor.py tools.py
                     update_plan.py summarize.py memory.py human.py retrieve_from_ragflow.py
      messages/      serializer.py input_mapper.py tool_call_mapper.py validators.py upcaster.py
      events/        sink.py projector.py command_mapper.py validators.py # ◆ projector/command_mapper
      memory/        manager.py compactor.py summarizer.py extractor.py retriever.py
      tools/         registry.py permissions.py adapters/langchain_adapter.py
  infrastructure/
    graph/           checkpointer.py store.py   # checkpointer.py -> graph_checkpoints(ThreadMemory)
    model/           model_gateway.py prompt_registry.py                  # 多 provider/registry M2
    external/        ragflow/ragflow_client.py sandbox/docker_sandbox.py
    messaging/       redis_adapter.py sse_adapter.py run_consumer.py      # transport_message.py / rabbitmq_adapter.py M2
    repositories/    session_repository.py event_repository.py memory_repository.py run_repository.py
    observability/   trace_sink.py metrics.py                             # M2
```

运行时对象 ↔ 代码位置 ↔ 持久化表（对齐 §12.1）：

```text
AgentState     domain/models/agent_state.py   infrastructure/graph/checkpointer.py(CheckpointPort) -> graph_checkpoints (= ThreadMemory)
AgentMemory    domain/models/memory.py        infrastructure/repositories/memory_repository.py     -> agent_memories
LongTermMemory domain/models/memory.py        infrastructure/graph/store.py(MemoryStorePort)        -> long_term_memories
```

注意：**AgentState 没有 Repository**（不直接落表），只由 `checkpointer.py` 以快照写入 `graph_checkpoints`。

---

## 31. ▲ 分阶段实施路线（本修订：先验证竖线，再铺平台）

> 原则：先用 Walking Skeleton 证伪最危险假设；再打通"能用的单 Graph 产品"（M1）；平台能力（多租户/版本化/多 provider/多智能体/CQRS/RAGFlow 深度）一律 M2，等负载与需求真正出现再做。

### 31.1 M1 路线（先打通这条竖线）

| 优先级 | 阶段 | 内容 | 关键依赖 |
|---|---|---|---|
| P0 | 阶段 -1 | App Platform 边界约定（**只定文档与边界，无代码搬迁**）：新 Research App 智能体能力建在 research-app、RAGFlow 用 knowledge-app、admin/web/worker 职责 | — |
| **P0** | **阶段 0★ Walking Skeleton** | **两节点 graph 端到端证伪假设 A/B/C：Celery+checkpoint+interrupt+resume、SSE 断线补发不缺字、工具副作用重放幂等（§6.5）** | — |
| **P0** | **阶段 0.5★ 最小评估骨架** | **LLM 录制回放 + 5~8 golden 任务进 CI（§28.3）** | 阶段 0 |
| P0 | 阶段 1 | 语义冻结（命名铁律）+ 消息体系：UserInput、StoredMessage、serializer（复用官方）、validators、upcaster；ACL 边界 CI 检查；ADR-001~003、022 | 阶段 0 |
| P0 | 阶段 2 | EventSink + DomainEvent/UIEvent + Projector + RunLineage(占位) + LiveDelta/事件双流对账 + 控制流铁律(ADR-019)；session_events 按新 schema 建表 | 阶段 1 |
| P1 | 阶段 3 | 执行拓扑：API 入队 + Python graph-runner(Celery) + Redis Pub/Sub + SSE；Run 状态机 + idempotency_key + session 锁 | 阶段 2 |
| P1 | 阶段 4 | MemoryManager：AgentMemory、MemoryPolicy、compactor、summary | 阶段 1 |
| P1 | 阶段 5 | LangGraph Planner-ReAct：State+Reducer、GraphRuntimeService、**ToolResultHandler 策略注册表（§19.3）**、工具重放幂等、错误模型、预算 | 阶段 3,4 |
| P1 | 阶段 6 | Interrupt + Checkpoint：durable checkpointer、session_id=thread_id、ask_user→interrupt、resume API、waiting/running 切换 | 阶段 5 |
| P1 | 阶段 7 | **M1 收尾**：单 Graph 在 golden set 上达标（对照旧项目抽取的样本）→ 接到用户流量；M1 可演示可发布 | 阶段 5,6 |

### 31.2 M2 路线（M1 稳定且被真实需求驱动后再做）

| 优先级 | 阶段 | 内容 | 触发条件 |
|---|---|---|---|
| P2 | M2-A | GraphRegistry 图版本化 + run pin 版本 + 灰度 | 需要在不停机下迭代图拓扑 |
| P2 | M2-B | Model Gateway 多 provider + fallback + 路由 | 需要第二个模型/降本/容灾 |
| P2 | M2-C | 长期记忆 Store 深度：extraction/retrieval node、召回归因、安全过滤、人工确认、级联删除 | 单 Graph 任务质量已稳，要靠记忆提升 |
| P2 | M2-D | 多租户 SecurityContext 全链路 + 配额 + bulkhead | 真正多租户/多用户上线 |
| P3 | M2-E | KnowledgeAgent 与 RAGFlow 深度集成（ask/ingest/引用/权限） | 知识库问答成为核心场景 |
| P3 | M2-F | 多智能体 Supervisor：AgentProfile、AgentRegistry、handoff、agent 级隔离 | 单 Agent 明显不够用 |
| P3 | M2-G | 生产化数据模型：session_events/agent_runs/memories 分区/索引/归档 + CQRS 读模型物化 | 数据量/读压力撑不住单表 |
| P3 | M2-H | 完整观测治理：TransportMessage envelope + IntegrationEvent/RabbitMQ + TraceSink + 完整评估门禁 | 多 app 协作 / 需要专业可观测 |
| P3 | M2-I | EvidenceAssembler 跨源证据装配（§13.9）：多源 evidence 去重/结构门控 rerank/token budget/model-hot 打包/raw readback + evidence≠完成证明门禁 | 单源检索已稳，需把 RAG/memory/file/artifact 多源证据统一进 prompt |

### 31.3 阶段验收口径（M1）

```text
阶段 0（Walking Skeleton）：§6.5.3 五条验收全绿。worker 重启能 resume；副作用不重复；SSE 不缺字。
阶段 0.5：改一行 prompt 能立刻在 CI 看到 golden set 指标变化。
阶段 1：LLM 调用入口只接收 list[BaseMessage] 或其 adapter 输出；DB 存储只走 serializer/upcaster；命名铁律有 CI 守。
阶段 2：所有用户可见事件 = DomainEvent 经 Projector 投影为 UIEvent；LiveDelta 与 final UIEvent 可对账；
        所有事件自创建即带 RunLineage（run_id/session_id 必填，root=run_id、parent=None）。
阶段 3：API 创建 run 后立即返回 run_id；worker 可执行最小闭环；idempotency_key 去重生效。
阶段 4：memory 更新不再散落在 Agent 基类；compact/summary/window 可测可配。
阶段 5：LangGraph Planner-ReAct 能完成 plan/step/tool/summarize；工具结果统一走 ToolResultHandlerRegistry（runner 无 tool_name if/elif）；工具重放不重复副作用。
阶段 6：服务重启后能恢复 waiting 任务；用户输入后能从 interrupt 点继续。
阶段 7：单 Graph 在 golden set 上达标（对照旧项目样本）；可对外演示并接用户流量。
```

通用验收口径：可重放、可恢复、可计量；M2 再加可灰度、可隔离、可跨 app。

---

## 32. 架构决策记录（ADR）清单

```text
ADR-001: 新项目自建 domain model（采纳旧项目验证过的领域概念，但不塞进 LangGraph state 当万能容器）
ADR-002: 使用 LangChain Core BaseMessage 作为 LLM 消息协议
ADR-003: Event / Message / Memory / Checkpoint 的边界（Checkpoint = 持久化的运行时 State，非记忆类别）
ADR-004: GraphRuntimeService 的职责与 Facade 边界
ADR-005: 长期记忆写入和召回策略（+ 召回归因，见 §12.5）
ADR-006: 多智能体 Supervisor 模式（M2）
ADR-007: 工具权限和审批策略
ADR-008: session_id 与 thread_id 映射规则
ADR-009: 执行拓扑——图执行者为 Python graph-runner(Celery)；checkpointer 为持久化真相源，队列仅调度
ADR-010: Ports & Adapters 端口目录与 ACL 强制（CI 边界检查）
ADR-011: 控制面/数据面分离与有效配置解析
ADR-012: GraphSpec 不可变版本化与 run 版本锁定（M2）
ADR-013: 事实流 + 投影——DomainEvent / UIEvent + Projector + CQRS 读模型（物化 M2）
ADR-014: 多租户 namespace 与 SecurityContext 跨异步边界传播（M1 占位，M2 全链路）
ADR-015: 重放安全（reducer 幂等 + 工具副作用幂等 + 并发幂等）
ADR-016: Schema 演进 / upcaster / checkpoint 向后兼容
ADR-017: Sandbox 生命周期归属、池化、GC 与故障隔离域
ADR-018: Agent Runtime 模块边界与可抽取为独立服务的判据
ADR-019: 控制流铁律——graph 路由只由 state/edge/Command/interrupt 决定，禁用事件驱动路由
ADR-020: Runtime/Observation 事件层 + RunLineage + TraceSink 投递策略（M2，fail-open/不阻塞/有界 flush）
ADR-021: 记忆/状态运行时对象↔表映射——无 state 表；AgentState 仅经 Checkpointer 落 ThreadMemory
ADR-022: ◆ Event/Message/Memory/Checkpoint/Transport 统一边界铁律（命名 M1 即生效）：
         DomainEvent=已发生事实(审计真相源, append-only)；UIEvent=投影视图(可重建可丢)；
         Command=请求意图(可被拒绝)；StoredMessage/LLMMessage=LLM 上下文持久化；
         Memory=Agent 复用(AgentMemory/LongTermMemory)；Checkpoint=运行时 state 快照(非记忆)；
         TransportMessage=通信 envelope, 只在 adapter/broker/SSE 边界, 不进 domain model(完整 schema 属 M2)。
         铁律：Event 用过去式、Command 用祈使式；UIEvent 不是真相源；TransportMessage 不入 state/memory/payload。
ADR-023: ▲ 验证优先（Walking Skeleton）——平台级建设前先端到端证伪 checkpoint/SSE/重放三假设（§6.5）
ADR-024: ▲ M1/M2 范围纪律——"不做它单 Graph 就跑不通"才进 M1；平台件等负载/需求驱动（§0.1、§33.1）
ADR-025: ▲ 评估前置——最小 golden set + 录制回放在 M1 阶段 0.5 就建，而非放到最后（§28.3）
ADR-026: ◆ 工具结果处理策略——ToolExecutionResult 经 ToolResultHandler 拆成 LLM ToolMessage /
         ArtifactRef / DomainEvent 三路，runner 禁止按 tool_name 写 if/elif（§19.3）
ADR-027: ▲ 全新重建——旧 MoocManus 彻底废弃，不部署/不兼容/不回退；旧项目仅作 golden 样本与行为参考
ADR-028: ▲ 跨源证据装配（吸收 Agently 4.1.3.9 Workspace 的证据装配思想）——分源召回保各自治理元数据，
         统一到 EvidenceAssembler 做去重/结构门控 rerank/token budget/引用标准化/model-hot 打包；
         EvidenceBlock 只读装配、不持有存储、不进 state；evidence ≠ 完成证明（M2，§13.9）。
         不引入 ResearchWorkspace 统一存储层，不新增 RuntimeEventCenter（TraceSink 已收口，ADR-020）。
```

---

## 33. 风险清单

### 33.1 ▲ 过程风险（本修订新增，且列为第一类——它比任何技术故障更可能杀死项目）

```text
过度设计吞掉产品进度（最大风险）| 严格 M1/M2 切分(§0.1)；每阶段以"可演示的用户价值"验收，
                                  而非"架构完整度"；平台件默认 M2，需举证为何必须提前。
先规划后验证 -> 地基假设是错的    | Walking Skeleton(§6.5) 在投入平台建设前先证伪 checkpoint/SSE/重放。
没有评估 -> 调优全靠手感          | 评估骨架前移 M1 阶段 0.5(§28.3)。
全新系统未验证就接流量          | 旧项目已废弃无可回退；改用 Walking Skeleton + golden set 把关，达标前不接用户流量(§9.4、阶段 7)。
为未出现的复杂度提前付费          | TransportMessage/多 provider/CQRS 物化等只立命名占位，实现延后(§18.5)。
```

### 33.2 技术风险

```text
State 过大，checkpoint 成本高     | state 最小化，大对象放文件/事件/memory store
长期记忆污染上下文                | 价值判据 + 召回归因 + 置信度/来源/过滤/人工确认（§12.4/12.5）
多智能体过早引入 -> 复杂度爆炸    | 先单 Graph，后 Supervisor（M2）
重放重复执行副作用                | reducer 幂等 + tool_call_id 结果缓存 + 并发锁（Walking Skeleton 先验证）
发布后旧 checkpoint 读不了        | schema_version + upcaster + checkpoint 最小稳定子集
图拓扑变更冲突活跃 run             | GraphSpec 不可变 + run 版本锁定（M2）
成本失控                          | RunBudget 预算熔断 + Model Gateway 计量
```

### 33.3 产品风险

```text
前端时间线被底层 graph 事件污染 | 前端只消费 UIEvent（经 Projector 投影），不直接消费原生 LangGraph event
用户无法理解 Agent 在做什么     | 保留 Plan/Step/ToolCall* DomainEvent，投影为前端工具卡片/步骤时间线
流式消息缺字                    | LiveDelta/事件双流 + final UIEvent 对账
```

### 33.4 运维/平台风险（多数对应 M2）

```text
长任务恢复困难                  | checkpointer + run table + 状态机（M1）
工具执行失控                    | sandbox + permission + timeout + approval
租户互相影响 / 资源泄漏          | 多租户 namespace + 配额 + bulkhead + sandbox GC（GC 是 M1）
跨服务上下文丢失                | SecurityContext 序列化随队列传播，每跳重建+复校验
观测出口拖垮主任务              | TraceSink 非阻塞 + 超时 + backpressure + 有界投递（M2）
```

---

## 34. 最终蓝图

```text
用户输入
  -> research-web-frontend
  -> research-app Python 后端 API（鉴权 / 构造 SecurityContext / 创建 run / 入队 / 返回 run_id）
  -> Celery 队列(Redis broker)
  -> Python graph-runner（Celery worker）
       -> 解析有效配置 + 编译/取缓存 Graph
       -> 路由仅由 state/edge/Command/interrupt 决定（事件不回灌路由，ADR-019）
       -> LangGraph PlannerReact Graph（每跳携带 RunLineage）
            -> LLM via ModelGateway(LLMPort) + prompt_id
            -> Tools via ToolRegistry(ToolExecutionPort) + SecurityContext 复校验
            -> Knowledge via KnowledgePort -> RagflowAdapter（M1 只读 / M2 深度）
            -> Memory via MemoryManager(MemoryStorePort)
            -> DomainEvent via EventSink (-> DB append-only) -> Projector -> UIEvent -> Redis/SSE
            -> Runtime/Observation -> 日志(M1) / TraceSink(M2)
       -> Checkpointer(CheckpointPort) 持久化执行状态（真相源）
  -> Redis Pub/Sub -> research-app SSE（UIEvent 投影 + last_event_id 补发）
  -> research-web-frontend 时间线（LiveDelta 流 + final UIEvent 对账）
  -> (M2) Integration Event(RabbitMQ) 跨 research-app/knowledge-app 协作
  -> Repositories 持久化 Session/Event/File/Run
```

从零设计、不被旧 message/memory 体系困住；既用 LangGraph 的强项，也不把全部业务逻辑塞给 LangGraph；**既对齐 app-platform 分工，也坚持先验证、先发布 M1，再被真实需求驱动铺 M2。**

---

## 35. ▲ 第一批落地任务清单（按本修订顺序：验证在前）

```text
0.  ★ Walking Skeleton（§6.5）：两节点 graph + Celery + checkpointer(Postgres) + SSE，
    跑通 ask_user→interrupt→worker 重启→resume；验证工具副作用重放幂等；验证 SSE 断线补发不缺字。
0.5 ★ 最小评估骨架：LLM 录制回放 + 把 Walking Skeleton 验收脚本变成第一个 golden 用例进 CI。
1.  语义冻结：定义 UserInput / StoredMessage / DomainEvent / UIEvent / 最小 Command；命名铁律写入 ADR-022。
    （全新重建，不设 Message=UserInput legacy alias。）
2.  引入 langchain-core；StoredMessage(带 schema_version)，serializer 复用官方；validators + upcaster 骨架。
3.  domain/ports/ 端口目录（先空接口，按本框架边界设计）。
4.  CI 加 ACL 边界检查（domain/models 禁 import langgraph/langchain_core；application 禁直接 import langgraph）。
5.  EventSink + DomainEvent/UIEvent + TimelineProjector + RunLineage(占位) + LiveDelta/事件双流对账。
    session_events 按新 schema(category/lineage/schema_version) 建表。
6.  执行拓扑最小闭环：API 入队 -> Celery graph-runner -> Redis -> SSE；Run 状态机 + idempotency_key + session 锁。
7.  AgentMemory / MemoryPolicy。
8.  LangGraph Planner-ReAct 单图（State+Reducer）+ ToolResultHandlerRegistry（browser/search/shell/file/mcp/a2a/default handlers，runner 不再按 tool_name 分支）。
9.  为上述写单测（reducer 幂等、序列化往返、DomainEvent->UIEvent、idempotency、interrupt-resume）。
10. 单 Graph 在 golden set 达标（对照旧项目抽取样本）后，接用户流量，M1 收尾可演示。
11. 写 ADR-001~003、009、010、015、019、022、023、024、025。
```

这批完成后，**地基（已验证的恢复/对账/幂等 + 消息协议 + 事件投影 + 执行拓扑 + 评估兜底）是被真实跑通过的，而不是纸面承诺**，再扩展 M2 能力风险显著降低。

---

## 36. 参考资料

- LangGraph Overview：面向长运行、有状态 Agent 的低层编排框架与运行时（durable execution / streaming / HITL / persistence）。
- LangGraph Persistence：checkpointer 用于 thread-scoped graph state，store 用于 cross-thread long-term memory。
- LangGraph Memory：短期记忆属 thread/state，长期记忆跨 session/thread。
- LangGraph Interrupts：interrupt 依赖 checkpointer 和 thread_id，可暂停并恢复 graph。
- LangGraph Event Streaming：messages / values / updates / subgraphs / interrupts 等 typed projections。

---

## 附录 A. v4 修订摘要

```text
口径（greenfield 一致性扫描，2026-06-27 二轮）：全文已从"旧项目工程化重构"口径，统一为
  "全新项目蓝图"——定位行/§0/§3/§5/§9.1/§24/§26/§31/ADR-001/最终蓝图里的
  "底座/保留/归位/过渡/迁移/继续拥有"等渐进改造语言，已改为"全新建设 + 采纳领域概念重新建模"。
  旧 MoocManus 一律只作反例与 golden 样本来源（ADR-027）。

A. §0.1 新增 M1/M2 范围切分与"先不做"清单；新增判定尺子。
   （本版：项目阶段由 `V1/V2` 更名为 `M1/M2`，与文档版本 `v4` 明确区分，见 §0.1 命名约定。）
B. §6.5 新增 Walking Skeleton，排在所有 P0 之前，先证伪 checkpoint/SSE/重放三假设。
C. §28.3 评估骨架从末期阶段前移到 M1 阶段 0.5。
D. §12.4/12.5 重写长期记忆：价值判据 + "不写"清单 + 召回归因质量闭环。
E. §33.1 新增"过程风险"类，把"过度设计吞掉进度"列为第一风险。
F. 全文按 M1/M2 标注实现深度；§12.1 记忆↔表映射定为唯一权威，§30 只引用。
G. §31 路线图重排为 M1 竖线 + M2 触发式两张表。

H. ▲ 全新重建定位：旧项目彻底废弃，不部署/不兼容/不回退；据此移除 legacy alias 与 legacy fallback，
   安全网改为 Walking Skeleton + golden set（文首项目定位、§9.4、§33.1、ADR-027）。

类型边界强化（◆，按本修订节奏落地）：
+ §9.2/§10.4/§11 明确 DomainEvent(事实) vs UIEvent(投影) 的分层与命名铁律（M1 落 domain/ui 两类）。
+ §10.3 明确 Command(请求意图) 概念（M1 只做 CreateRun/ResumeRun/CancelRun 最小集）。
+ §18 明确"事实流 + 投影 + Projector"；§18.4 采纳 TokenDelta→LiveDelta 改名。
+ §19.3 引入 ToolResultHandler 策略：工具结果拆成 normalize_for_llm / collect_artifacts /
  to_domain_events 三路（比"只生成一个前端 content"更正确），替代旧项目的 tool_name if/elif；ADR-026。
+ §24.1 明确 session_events 带 category/schema_version/lineage。
+ ADR-022 明确 Event/Message 语义边界。

吸收 Agently 4.1.3.9（▲，收窄吸收，不破坏既有边界）：
+ §13.9 新增 EvidenceAssembler：跨源证据（RAG/memory/file/artifact/附件）→ 去重 / 结构门控 rerank /
  token budget / 引用标准化 / model-hot 打包 / raw readback，只读装配、不持有存储（不是 ResearchWorkspace 统一存储层）。
+ 关键治理 evidence ≠ 完成证明进 §13.9 铁律与 §28.3 评估项；§4.2 加证据装配边界；ADR-028。
+ EventCenter 不再新增概念/改名：其精神已在 §9.2 / §10.4 RuntimeEvent / §28.2 TraceSink / ADR-020 收口。

延后到 M2 的目标态（▲）：
- EvidenceAssembler 是 M2：M1 只在 §13.5/§12.5 之上留命名与边界占位，prompt 装配先用最小拼接 + token 截断。
- 不在 M1 上 TransportMessage envelope / IntegrationEvent / 四类基类全量：只立命名占位，实现归 M2（§18.5）。
  理由：在只有单 Redis+SSE 通道、无跨 app 协作时引入传输 envelope，是为未出现的复杂度提前付费。
- legacy：本修订是 greenfield，本就无兼容对象；旧项目只作为 golden 样本来源，golden set 达标前不接用户流量（§9.4）。
```
