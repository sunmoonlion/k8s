# 总体架构设计（草案）

> 性质：设计草案，供之后正式派发开发任务时作参考输入。**不是定稿（composition），不是任务书，也不是现状说明。**
> 整合自两份讨论纪要（`~/BS_Agent_Local_Runtime_架构讨论纪要.md`、`~/Agent_许可与Supervisor_MCP架构讨论纪要.md`）及 2026-09-17 的讨论，
> 并对照了 [`composition/request-lifecycle.md`](composition/request-lifecycle.md)、[`composition/constraints.md`](composition/constraints.md)（A1–A5）、
> `investment-app` 的现有代码。
>
> 标 ⚠ 的是未验证或待实测的前提；第 5 节集中列出。第 4 节是需要人拍板的决策点，正文里的"建议"在拍板前不生效。

## 0. 结论一览

1. **大模型调用只在用户电脑上发生。**本地 runtime 内置原版 Codex，用用户自己的 key 直连模型厂商；后端不替用户调用模型，也不中转模型请求。
2. **后端是确定性的控制面。**Task、Attempt、Interaction、四本账都在后端的 PostgreSQL；router、orchestrator、validator 等角色不调用模型，需要推理的环节作为 Attempt 派给本地 Codex。
3. **知识服务（knowledge-app）以 MCP 对 Codex 提供检索与领域工具。**它的 embedding、rerank 用后端自有模型，与用户的模型调用无关。
4. **界面用 Electron 桌面应用，不用浏览器页面。**界面与 runtime 同机，runtime 本来就必须安装；改成 Electron 后，本机通道的整套安全问题消失，审批和 key 输入天然留在本地。
5. **执行层租用、不自建（A4）。**本地 runtime 建议做成 Python 后台进程，经 Codex Python SDK 驱动 Codex，并替换 SDK 默认的"自动同意"审批处理。
6. **审批分两层。**工具级审批（单条命令、单个文件修改）由本地 runtime 执行并上报；Task 级审批（`WAITING(APPROVAL)`、不可逆动作）按合同在后端落 Interaction、原子消费。
7. **断线即暂停。**本地执行器离线时不产生新的副作用；重连后按 fencing 校验再决定继续还是开新 Attempt。
8. **卖点只在知识服务与控制面。**用户拿原版 Codex 自己就能做到的，不算卖点；每项功能都要过这道检验，并用"原版 Codex 对比本产品"的领域评测给出证据（1.15）。

## 1. 总体设计

### 1.1 目标与前提

**目标**：用户在自己电脑上，通过桌面应用提交 Task；后端受理、编排并验收；Agent 在用户电脑上执行，读写本地工作区、调用模型、调用知识服务；结果可靠持久化并可重新取得。完整语义以 `request-lifecycle.md` 为准。

**前提**：

- 界面与本地 runtime 总在同一台电脑上；后端一般在另一台机器（私有化部署时也可以同机）。
- 大模型调用只由本地 runtime 负责，用户自带 key；模型选择与配置在 runtime 里做（runtime 由我们分发）。
- 界面、本地 runtime、后端三方各自直连，互不代劳。

**必须满足的现行规则**：

| 规则 | 在本设计中的落点 |
| --- | --- |
| A1 通用/专用分离，新增业务 Agent 优先新增 Profile | 通用执行编排在后端控制面 + 本地 runtime；领域差异在 Task Profile / Agent Profile、skills、MCP 工具 |
| A2 两边都要有纪律 | 多方竞争协议照旧适用；本地 runtime 的策略层是执行侧纪律的强制点 |
| A3 四本账必须落 PostgreSQL | 四本账只在后端；本地 runtime 只执行与上报，不持有任何账的权威副本（1.12） |
| A4 执行层租用，只依赖 SDK | 本地 runtime 经 Codex Python SDK 驱动 Codex，不直接依赖 app-server 裸协议（1.6） |
| A5 领域概念不进 Port 签名 | `AgentExecutorPort` 保持中性；派往本地的 DTO 只含引用与通用字段 |
| `request-lifecycle` 全文 | 状态机、七阶段、I1–I15、AT-01–AT-22 不变；本设计只决定它们落在哪个部分（1.4） |

### 1.2 组成部分

```text
用户电脑
┌──────────────────────────────────────────────────────────────────┐
│ Electron 桌面应用                                                 │
│   界面（渲染进程，随应用打包）  ⇄ ③ 进程内通信 ⇄  主进程             │
│                                                   │ 拉起/监管     │
│                                                   ▼               │
│   本地 runtime（Python 后台进程）                                  │
│     连接层 · 策略层 · 模型配置 · 工具级审批 · 执行 Adapter          │
│                    │ ② Codex Python SDK（底层 stdio）              │
│                    ▼                                              │
│   原版 Codex（唯一真正干活的 agent）── 沙箱 ── 本地工作区            │
└──────────────┬──────────────────┬───────────────┬────────────────┘
               │ ④ HTTPS/事件流    │ ① WSS         │ ⑤ HTTPS(MCP)    │ ⑥ HTTPS
               ▼                  ▼               ▼                 ▼
          ┌─────────── 后端（investment-backend）──────┐   knowledge-app   模型厂商
          │ 会话与设备 · 派发网关 · 控制面角色          │   RAG + MCP       OpenAI / 国产 /
          │ Task/Attempt/Interaction/四本账（PG）       │   自有 embedding  企业网关
          │ skills 库 · 审计 · 网页端（账号/报告）      │
          └──────────────────────────────────────────┘
```

| 部分 | 职责 | 不做什么 |
| --- | --- | --- |
| **Electron 桌面应用** | 提交 Task、展示状态与结果、Task 级审批的用户操作、工具级审批页、模型与 key 配置页、工作区授权 | 不持有领域事实；不自己调用模型 |
| **本地 runtime** | 主动连后端；接收 Attempt 并驱动 Codex；工具级审批的强制点；模型配置与 key 保管；工作区与沙箱策略；上报事件、用量、副作用意图与结果 | 不持有四本账权威副本；不自行决定 Task 状态 |
| **Codex** | agent loop：规划、调用工具、读写文件、执行命令、调用模型与 MCP | 不直接连后端；不开网络端口 |
| **后端** | 身份、会话、设备注册；Task/Attempt/Interaction/Event/Delivery；四本账；router、orchestrator、validator；skills 库；派发网关；审计；网页端 | 不调用用户的模型；不中转模型请求；不接触用户 key |
| **knowledge-app** | 知识库、检索、领域工具，经 MCP 暴露；用自有模型做 embedding/rerank | 不接触用户 key；尽量不整段返回原文（1.9） |
| **模型厂商** | 推理 | — |

### 1.3 通道

| # | 两端 | 协议 | 内容 | 安全要点 |
| --- | --- | --- | --- | --- |
| ① | runtime ⇄ 后端 | WSS，runtime 主动向外连 | 派发 Attempt、取消、事件与进度回传、副作用意图与回执、审批结论上报、用量上报、厂商预设下发 | 设备私钥认证；协议里不设 key 字段 |
| ② | runtime ⇄ Codex | Codex Python SDK（底层是子进程 stdio） | 启动/恢复 thread、下发 turn、事件、审批请求、中断 | 仅本机；Codex 不开端口 |
| ③ | 界面 ⇄ runtime | Electron 进程内通信（渲染进程 → preload → 主进程 → runtime 本地管道） | 工具级审批、模型配置、工作区授权、本地 diff 预览、runtime 状态 | 不开 localhost 端口；preload 只暴露少数具体函数 |
| ④ | 界面 ⇄ 后端 | HTTPS + 事件流（cursor 续传） | 提交 Task、查询、Task 级审批、取消、结果 | 桌面端 token；每次读取重新授权（F-DELIVERY-09） |
| ⑤ | Codex ⇄ knowledge-app | HTTPS（MCP） | 检索、领域工具、按需取 skill | 按设备发 token、可吊销、限流 |
| ⑥ | Codex ⇄ 模型厂商 | HTTPS | 推理 | 用户自己的 key，只在本机 |

另有网页端 ⇄ 后端（HTTPS）：账号、计费、报告、任务历史，不涉及本地操作。

### 1.4 生命周期七阶段的落位

| 阶段（`request-lifecycle` §5） | 在哪里执行 | 说明 |
| --- | --- | --- |
| 5.1 提交 | Electron 界面 | 幂等键生成与复用、`task_id` 与 event cursor 持久化在应用本地存储 |
| 5.2 受理与校验 | 后端 | 身份来自桌面端 token 会话；网页端与桌面端共享同一 application use case（F-ADMIT-04 措辞需修订，见 3.2） |
| 5.3 排队与可靠投递 | 后端 → ① → runtime | outbox 投递到派发网关；设备离线时 Task 保持 `QUEUED`（或 `WAITING(RESOURCE)`），不丢 |
| 5.4 Agent 执行 | 本地 runtime + Codex | Attempt 的租约与 fencing 由后端签发，runtime 持有；工具、证据、副作用经 ① 关联到 Attempt |
| 5.5 中断、批准与恢复 | 两层（1.7） | Task 级 Interaction 在后端；工具级审批在本地 |
| 5.6 验收与完成提交 | 后端 validator（确定性）+ 本地验收 Attempt（需要语义判断时） | 结果、验收、预算结算与终态在后端原子提交 |
| 5.7 返回前端 | 后端 → ④ → 界面 | 先持久化后通知；应用重启、断线后按 cursor 回放 |

### 1.5 后端控制面

控制面不调用模型，只做确定性的事。角色沿用 `agent-dev-guide` 的词：

| 角色 | 做什么 |
| --- | --- |
| router | 形成 RouteDecision：选 Task Profile、Agent Profile、执行设备；确定性映射，命中规则与拒绝原因入账 |
| orchestrator | 创建并推进 Attempt；按流程模板拆步骤；需要临时规划时，先派一个"出计划"的 Attempt，计划作为 Artifact 经批准后再执行 |
| validator | 按固定 Task Profile 版本做确定性验收：schema、规则、测试结果、MCP 领域校验 |
| acceptor | 需要语义判断的验收，作为独立的验收 Attempt 派给本地（不同 Agent Profile、不同 Codex thread），结论回到后端 |
| publisher | 不可逆副作用经 Task 级批准后执行，Delivery 可重取 |

**控制面承担的领域方法**：

- **流程模板**：按领域流程把需求拆成步骤，逐步派发；
- **结果校验**：规则、测试、MCP 工具优先；Codex 对自身产出的自评可靠性低，不能单独作为验收依据；
- **上下文管理**：跨 Task 记住项目背景、偏好、历史决定（长期记忆的 embedding 在后端，用自有模型）；
- **审计**：全部 Task、Attempt、审批结论、副作用摘要。

**skills 收在后端，不落地到用户电脑**：

- 好处：方法库不分发；改一个 skill 所有用户立即生效；可按客户、行业定制并做灰度和 A/B；由 router/orchestrator 按任务类型和检索结果挑选，比让 Codex 按描述自行匹配更可控。
- 下发方式，可并用：
  - **随 Attempt 注入**：派发时把选定 skill 拼进指令，适合开工时就能确定方法的场景；
  - **经 MCP 按需取**：提供 `get_skill(name)` 一类工具，适合长任务中途才需要某套方法的情况。
- 边界：
  - 注入的文本会进入本地 Codex 会话记录，也会发给模型厂商，不是完全保密。skill 只写"怎么做"的指引，核心规则、算法、数据留在 MCP 工具内部执行，只返回结果；
  - 一次别注入太多，否则挤占 Codex 的工作上下文；
  - skill 是提示词资产，要版本化并配评测，改动后做回归。

下发给 Codex 的指令质量直接决定结果，领域评测集要尽早建：用来调流程模板、skills、验收规则，也用来对比用户所选模型的效果（1.15）。

### 1.6 本地 runtime 与 Codex

**Codex 的 agent loop 本来就在本地**：Codex CLI、IDE 插件、桌面 app 都是规划、工具、读写文件、执行命令在用户电脑上完成，只有推理请求发往模型厂商。（Codex Web 是另一种形态：agent 在 OpenAI 云端沙箱里跑，与本设计无关。）所以本地 runtime 不是干活的主体，而是一层壳。

**完整打包，不做部分打包**：

| | 部分打包：本地只放 Codex 的执行层 | 完整打包：整个 Codex 放进 runtime |
| --- | --- | --- |
| agent loop | 在后端，要自建或 fork Codex 改工具层，跟进频繁的上游更新 | 不改代码 |
| 模型调用 | 必须从后端发出，违背前提 | 从本地发出 |
| 延迟 | 每次工具调用都要后端⇄本地往返，一个任务几十上百次 | 工具调用本地完成 |
| 工具格式 | 必须与 Codex 的 shell、apply_patch 一致，效果才不打折 | 原样 |
| 沙箱、审批 | 要自建（Codex 很依赖执行 shell 命令，只做文件读写不够） | 用 Codex 自带的 |
| 升级 | 跟上游改代码 | 换钉版二进制 |
| 代价 | — | agent 行为由 Codex 决定，只能经配置、AGENTS.md、MCP 工具、派发的指令影响 |

**runtime 要补 Codex 缺的**：

- 主动连后端（Codex 的 app-server 只等别人连进来）；
- 随安装包带上 Codex、锁定版本、负责升级；
- 设备身份与配对（1.10）；
- 模型配置与 key 保管（1.8）；
- 工具级审批的强制点（1.7）；
- 策略：限定工作区、禁止关闭沙箱、危险操作必须审批、并发上限。

**用哪个 SDK（A4）**：

| 选项 | 审批 | 与 A4 | 代价 |
| --- | --- | --- | --- |
| **Codex Python SDK（`openai-codex`）** | 有审批回调；⚠ 默认对命令执行与文件修改一律返回 accept，必须替换 | 符合 | 应用里要带 Python 运行环境 |
| Codex TypeScript SDK（`@openai/codex-sdk`） | 包装的是 `codex exec`，只有 `approvalPolicy`（`never`/`on-request`/`on-failure`/`untrusted`），没有审批回调，做不了逐条交人审批 | 符合 | 可直接在 Electron 主进程里用 |
| 直接用 app-server 协议 | 可以 | **违反** | 裸协议变化快（`04-agent-execution` §2.7 实测） |

**建议**：runtime 做成独立的 Python 后台进程，经 Python SDK 驱动 Codex；Electron 只当界面壳。理由：满足 A4；审批回调可用；DeepSeek Harness 那条腿也是 Python；后端已有的 `AgentExecutorPort`、Adapter 与 Fake 执行器代码可以复用。

**驱动 Codex 的要求**：

- 不解析终端输出；
- 钉住 Codex 与 SDK 版本，升级钉版必须重跑锚点；
- 连接时带 `clientInfo.name` 标识本产品（OpenAI 合规日志用它区分客户端；面向企业客户时，官方建议联系 OpenAI 加入已知客户端列表）；
- SDK 侧的 thread/session id 不是 Task 的真源：`ExecutionBinding` 经 ① 写回后端（I13）。

**这是官方支持的嵌入方式**：OpenAI 的 VS Code 插件和桌面 app 在发布包里带对应平台的 Codex 二进制、锁定版本，作为长驻子进程经 stdio 走 JSON-RPC；JetBrains、Xcode 也嵌入同一套 harness；官方文档把 app-server 定位为产品深度集成接口，自动化与 CI 用 SDK。社区已有 20 多个基于或包装 Codex 的项目。"打包进自家产品、用户完全无感"有多普遍，没有可靠数据。

### 1.7 审批：两层

| 层 | 例子 | 发起 | 通道 | 决定与记录 |
| --- | --- | --- | --- | --- |
| **工具级** | 执行某条命令、修改某个文件、联网 | Codex → SDK 审批回调 → runtime | ③ | runtime 按策略自动放行、拒绝或交用户在本地审批页决定；结论经 ① 上报后端存档 |
| **Task 级** | `WAITING(INPUT/APPROVAL)`、计划批准、不可逆副作用（发布、推送、对外动作）、预算追加 | 后端 | ④ | 后端落 Interaction，按 `request-lifecycle` §4.2 原子消费（F-INTERACT-*） |

- **强制点在执行者够不着的地方**：runtime 与 Codex 是两个进程，Codex 改不了 runtime 的策略；审批页随应用打包、已签名，后端也改不了。
- **后端不能替用户批准工具级动作**：runtime 只接受本机界面给出的答复，后端被攻破也无法把 ① 变成远程控制通道。
- **审批内容尽量不上传**：命令原文、diff、文件路径在本机展示；上报只带摘要与结论。
- **两层的具体划分**是待定决策（第 4 节 D3）。建议：所有不可逆、对外可见的动作归 Task 级；工作区内可回退的读写和命令归工具级。

### 1.8 模型调用与 key

**配置在 runtime 里做**：

- key 只在本地配置页输入，存进系统钥匙串（macOS Keychain、Windows 凭据管理器、Linux libsecret），不写进配置文件；
- runtime 启动 Codex 时用环境变量把 key 只传给 Codex 子进程，`config.toml` 里只写环境变量名（`env_key`）；
- runtime 内置厂商预设（OpenAI、各家国产模型、企业自建网关），只含接口地址、模型名等不涉密字段；后端可经 ① 推送更新这份列表；
- 企业客户把 `base_url` 指向自己的网关，可自行审计每次调用；
- 只用 API key，不提供"用 ChatGPT 账号登录"（第三方产品能否这样用，OpenAI 未明确答复）；
- ① 的协议里没有 key 字段；上报的日志、报错过滤请求头与环境变量。

**计费**：模型费用由用户直接付给厂商；我们收控制面、知识服务与领域数据的服务费。runtime 上报的用量只用于展示，不作计费依据。建议用户为本产品单独建 key、按项目隔离、在厂商控制台设用量上限和预算提醒。

**接国产模型**（不需要 cc-switch，runtime 自己生成配置）：

- Codex 只支持 Responses API（`wire_api="chat"` 明确报错）。只支持 Chat Completions 的厂商，需要 runtime 内置一个本机转换层（类似 LiteLLM）；
- ⚠ 会话自动压缩后，记录里会带 OpenAI 私有的 compaction 条目，第三方"兼容 Responses"的接口可能不认，导致该会话无法继续；转换层要处理，续接长任务会受影响；
- ⚠ 有报告称经第三方 Responses 接口时，配置的 reasoning effort 可能没有真正发出；
- 第三方模式下官方插件、图片生成、远程功能等不保证可用；
- "能接上"不等于"效果好"：Codex 的提示词与工具格式按 OpenAI 模型调优，换模型要用领域评测集实测。起步阶段可只支持原生提供 Responses API 的厂商，暂不做转换层。

### 1.9 知识服务与 MCP

**RAG 接给 Codex 的两种方式**，可并用：派发时由 orchestrator 预先检索并注入（简单可控，但执行中途拿不到新资料）；做成 MCP 工具由 Codex 按需调用（更灵活，Codex 原生支持）。

**核心逻辑留在工具内部**：检索、行业数据查询、业务系统对接都做成 MCP 工具；需要严格步骤的领域流程封装成一个工具，内部用固定逻辑执行，而不是让 Codex 逐步执行。

**防批量抓取**：MCP 调用凭据存在用户本地，拿到它就能绕过 Codex 直接调用。"数据留在后端"只在一定程度上成立，所以要：

- 按设备单独发 token，可吊销，随设备配对签发；
- 限流，监控异常调用模式；
- 尽量返回处理后的结论，少返回原文；
- 必要时给返回内容加水印，便于追查。

### 1.10 连接、设备身份与首次安装

**runtime 主动向外建立 WSS**：

- 用户电脑不需要开放入站端口，易穿越 NAT 和家庭/企业防火墙；
- 后端能维护设备在线状态，直接经已有连接派发；
- 断线自动重连，重连后先对账（1.12）。

**常驻**：runtime 注册为用户级后台服务（Windows 用户态后台程序、macOS LaunchAgent、Linux systemd user service），登录后启动并连后端；关闭窗口后是否继续运行由设置决定（托盘）。

**首次安装**：WSS 解决不了"机器上还没有 runtime"，首次仍要引导：下载安装包（Windows `.exe`/`.msi`，macOS `.pkg`/`.dmg`，Linux `.deb`/`.rpm`/AppImage）→ 用户确认安装 → 注册后台服务 → 启动并连接。安装包必须签名：Windows 代码签名（否则会被 SmartScreen 拦截），macOS 公证。

**绑定账号：一次性配对**。不把浏览器 Cookie、密码或长期 token 塞进 runtime：

- 配对记录含 `enrollment_id`、一次性 secret、5 分钟有效期、所属用户；
- 后端校验 secret 是否正确、是否过期、是否已用、属于谁；
- 成功后立即标记已用，secret 失效。

**配对方式建议用 Device Code 流程**（RFC 8628 那一类）：runtime 向后端申请配对码 → 打开系统浏览器（链接带码）→ 用户在已登录的页面确认 → 后端把设备公钥绑定到账号。secret 不需要在浏览器与 runtime 之间传递，三个平台做法一致。不建议把 token 写进安装包参数：会与代码签名冲突。

**长期身份：设备密钥**。runtime 首次启动生成密钥对，私钥只留本机（存系统钥匙串），公钥在配对时上传；之后建立 WSS 时用私钥证明身份，后端用公钥验证。设备可在网页端或应用里吊销。

**一个用户多台设备**：router 选设备时只考虑在线且已授权该工作区的设备；Task 与设备的绑定写入 RouteDecision。

### 1.11 执行隔离与权限

**权限的来源**：本地进程的权限继承其运行用户（UID）。Agent 是逻辑执行主体，不是操作系统用户；Codex 调 shell 时 `whoami` 看到的是运行它的用户。能否做管理员操作取决于 sudo、ACL、SELinux/AppArmor 等系统策略。

**沙箱与非 root 各管一件事**：沙箱限制 Agent 能看到和接触哪些资源（外层边界）；非 root 限制它在边界内的权限（内层最小权限）。两者同时需要，非 root 也是纵深防御的一部分。

**桌面场景的取舍**：

- 默认以用户本人身份运行，依靠 Codex 自带的操作系统级沙箱（⚠ macOS Seatbelt、Linux Landlock/seccomp 等，以钉版实测为准）；
- runtime 只把用户授权的工作区暴露给 Codex，禁止关闭沙箱，网络访问按策略开关；
- 不默认使用 Docker 容器或专用 UID：Windows/macOS 需要 Docker Desktop（较大企业要付费），创建专用用户需要管理员权限，写出的文件属主不是用户本人会造成权限混乱；
- 企业或服务器部署可选加固：容器内以非 root UID 运行（镜像里 `USER`，或运行时 `--user`，由容器运行时直接以该 UID 启动进程，不需要先以 root 启动再切换），挂载 `/workspace` 可写、参考资料只读、生产数据不可见。

**权限链**：

```text
后端控制面：RouteDecision、Task 级批准（逻辑控制）
    ↓ ①
本地 runtime：工作区白名单、工具级审批、并发与预算上限（执行侧强制点）
    ↓ ②
Codex 沙箱
    ↓
运行用户的 UID（企业部署可为非 root 专用 UID）
    ↓
本地工作区
    ↓
操作系统内核（最终边界）
```

### 1.12 与合同、四本账的衔接

- **Port 不变**：后端的 `AgentExecutorPort`（start/resume/cancel/events/inspect/close/submit_result）增加一个"经 ① 派往本地 runtime"的 Adapter；纪律层继续用 Fake 执行器测试。runtime 内部再用 Codex Python SDK 实现执行。
- **租约与 fencing**：Attempt 的租约由后端签发，runtime 持有并续约；续约失败（断线、休眠）即视为失去租约，runtime 停止提交结果与副作用；迟到写入被拒（I14）。
- **断线即暂停**：离线时不产生新的副作用。重连后先对账：租约仍有效且 fencing 一致则继续，否则按合同开新 Attempt，从持久 Artifact 恢复。不允许"离线先在本地记账、之后同步"（违反 A3）。
- **副作用账**：本地写动作的意图先经 ① 记入后端副作用账，拿到幂等键后执行，回执再上报（I9）。工作区内可回退的普通文件修改可以按 Profile 声明为批量记账，粒度待定。
- **预算账**：步骤数、耗时、派发次数由后端控制；token 与费用由 runtime 上报，证据等级标"自报"。花的是用户自己的钱，这不构成信任问题，但要写明。
- **证据账**：citation、来源、时点经 ① 上报后端落表，不只留在事件流里。
- **可恢复现场**：Codex 本地会话目录不是真源；需要跨 Attempt 恢复时，以后端持久的 Artifact 与快照引用为准。
- **多方竞争**：N 路并行 Attempt 都在用户电脑上跑，按机器资源限制并发数；各路工作区隔离。dev.change 类 Task 天然适合本地：仓库本来就在用户电脑上。
- **后端不可用时**：进行中的 Attempt 按"断线即暂停"处理；已在本地展示的审批不因断线自动通过。

### 1.13 信任与数据流

| 数据 | 流向 |
| --- | --- |
| 用户 key | 只在用户电脑，只发给用户选的模型厂商 |
| 代码与文件 | 由 Codex 发给用户选的模型厂商；发往后端的只有 MCP 检索与工具调用需要的内容、结果、审批摘要 |
| 审批细节 | 只在本机展示 |

**让用户能验证，而不只靠承诺**（key 就在 runtime 里，用户会担心它被偷偷发走）：

- 开源本地 runtime（Codex 本身是 Apache-2.0）；开源 runtime + 闭源后端是这类产品常见的平衡点；
- 签名二进制，最好可复现构建；
- 公开 runtime 与 Codex 会连接的全部域名，用户可用防火墙或抓包工具（Little Snitch、mitmproxy 等）核对；
- 公开 ① 与 ⑤ 的协议文档，证明没有上传 key 的途径。

**后端不滥用的约束**（后端仍会看到 MCP 检索内容和结果）：服务条款、隐私政策、数据处理协议（DPA）；GDPR、《个人信息保护法》等法规；企业单独合同；SOC 2、ISO 27001 等第三方审计；必要时机密计算（Intel TDX、AMD SEV、NVIDIA 机密 GPU）加远程证明，思路同 Apple Private Cloud Compute。上游同理：提示词最终发给模型厂商，依赖其条款与零数据保留（ZDR）协议。通行做法是缩小需要信任的范围，而不是消灭信任。

### 1.14 许可（2026-09-17 核对）

| 项目 | 许可 | 对本设计 |
| --- | --- | --- |
| Codex（仓库、`@openai/codex` 发布包、Python/TS SDK） | Apache-2.0 | 可以打包进 runtime、修改、再分发；须附 LICENSE 与 NOTICE（含 Ratatui 的 MIT 声明），修改须标注；不得用 Codex、OpenAI 商标作产品名或 logo |
| Anthropic API SDK（Python/TypeScript） | MIT | 自由使用 |
| Claude Agent SDK | TypeScript 版专有；Python 版包装层 MIT，但内置专有 Claude Code 二进制 | 受 Anthropic 商业条款约束 |
| Claude Code | 专有 | 可预装在产品里，条件：二进制不改、不移除其登录方式、每个用户用自己的凭据、不替用户付费或中转用量、不用其名称与 logo 作品牌。本设计本来就是用户自带凭据、不中转，条件上走得通 |

模型调用受厂商服务条款约束，与代码许可无关。网上流传的 Claude Code 泄露源码没有使用授权，不能用。以上不构成法律意见，上线前由法务复核。

### 1.15 价值、风险与应对

**价值在哪里**：agent loop 正在变成通用基础设施，差异化在"给它什么能力"（知识服务）和"让它干什么、怎么验收"（控制面）。真正的价值是它们装的东西：

- 独家或精心整理的领域数据，以及打通客户内部系统的能力（RAG 的价值在数据：专业性、持续更新、针对行业的切分与标注、检索准确率评测）；
- 流程模板与验收标准里的领域经验；
- 能证明"比直接用 Codex 强多少"的评测体系；
- 私有化部署、国产模型适配、代码与 key 不经过后端、审计与权限；
- 开箱即用（不用自己装 Codex、拼流程），这是体验价值，容易被追上，不宜作主卖点。

**价值检验：去掉知识服务与控制面，用户还能不能得到同样的结果？**用户随时可以直接试原版 Codex，所以每项功能在设计与验收时都要过这道检验；答案是"能"的，不作为卖点投入。原版 Codex 给不了、本产品要给的：

| 类别 | 内容 | 由谁提供 |
| --- | --- | --- |
| 领域数据与工具 | 独家或整理过的知识库、持续更新、客户内部系统对接、封装成工具的领域规则与计算 | 知识服务（MCP） |
| 领域流程与验收 | 按行业规矩拆步骤、按标准验收并打回重做、规定何时必须停下问人与哪些动作要批准、跨 Task 记住项目背景 | 控制面 |
| 可靠性与可追溯 | Task/Attempt 断点恢复、审批记录、证据与引用可追溯、多方竞争择优、全程审计 | 控制面 + 四本账 |
| 团队与企业能力 | 共享知识库、权限、私有化部署、国产模型适配、代码不经过后端 | 后端 + 本地 runtime |

**对比评测是价值的证据**：同一批领域任务，原版 Codex（同一模型、同一用户配置）做一遍，本产品做一遍，比较准确率、验收通过率、返工次数、引用完整度与耗时。要求：

- 任务集、金标准、指标与预算在跑之前冻结，两边用同一模型与 key；
- 结果按 Task Profile 分别报告，不合并成一个总分；
- 控制面、skills、MCP 工具的改动都要重跑回归，确认优势没有退化；
- 同一套数据用于推荐模型清单（见下表）。

它既是调优依据，也是销售时的核心材料；评测集要在第一个 Task Profile 开发时一并建立。

**两处容易被绕开的地方**：

- **知识服务可以被单独接走**：用户可以在自己装的 Codex 里直接配置 MCP 地址（1.16），绕过控制面。因此控制面的价值要让用户直接看到（验收结论、返工记录、可追溯的证据），知识服务是否单独售卖、如何定价要单独决定（D9）。
- **下发的指令会被看到**：skills 与派发的提示词会进入用户本地的 Codex 会话记录。方法里真正的核心（规则、算法、数据）留在 MCP 工具内部执行，只返回结果（1.5、1.9）。

**风险与应对**：

| 风险 | 应对 |
| --- | --- |
| 强依赖 Codex：协议变化快；OpenAI 在往上做 skills、插件、编排，可能覆盖通用部分 | 控制面与知识服务不绑定 Codex，换执行引擎只改 runtime 里的 Adapter；控制面越贴近行业流程越稳 |
| 用户自选模型，质量不受控，售后压力落到我们身上 | 维护经评测的推荐模型清单，清单外标"未验证"；公布各模型在领域任务上的评测数据 |
| 用户自带 key 对非技术用户是门槛（国内申请 OpenAI key 尤其难） | 目标客户以开发团队和企业为主，企业网关作为主要场景设计 |
| 维护面：runtime、Codex、转换层、三个平台、签名、更新 | 起步只支持原生 Responses API 的厂商；Electron 统一界面层 |
| 控制面没有模型，自评式验收可靠性低 | 优先确定性验收（测试、规则、MCP 校验）；语义验收用独立 Agent Profile |
| 多方竞争的并行压在用户电脑上 | runtime 按机器资源设并发上限，派发前由 router 查询设备容量 |

### 1.16 备选：只做远程 MCP

接受用户自己安装 Codex 时，可以不要本地 runtime：用户在 Codex 里配置我们的 MCP 地址，skills 经 MCP 下发。代价是控制面无法主动派发 Attempt，只能由用户在 Codex 里发起；流程与验收要改成 MCP 工具由 Codex 调用，对流程的掌控弱很多，Task/Attempt 合同也难以完整落实。适合面向开发者、先快速验证领域价值；完整产品仍走本设计。两者可以先后做。

## 2. 为什么用 Electron，以及对详细架构的影响

### 2.1 前提决定了选择

界面与 runtime 总在同一台电脑，runtime 又必须安装。于是浏览器方案相对 Electron 的唯一结构性优势——"界面与执行不在同一台机器"——用不上；而它的全部额外复杂度都来自"界面在浏览器里、要去访问本机"。

### 2.2 两种方案对比

| 维度 | 浏览器方案（界面由后端提供，runtime 另开本地页面） | Electron 方案（界面随应用打包） |
| --- | --- | --- |
| 界面数量 | 两处：后端网页 + 本地审批/配置页，来回跳 | 一个 |
| 本机通道 | 本地端口、Origin 校验、浏览器与 runtime 配对、防恶意网页 | 进程内通信，不开端口 |
| 浏览器限制 | ⚠ 各家在收紧公网页面访问 localhost（Chrome 推本地网络访问权限弹窗，Safari 另有限制），企业浏览器策略可能禁用 | 不受影响 |
| 后端被攻破时 | 后端下发的网页代码可被篡改，替用户点"同意"、读 key，所以审批与 key 输入必须另做本地页面 | 界面代码在本地且已签名，后端改不了 |
| key 输入 | 必须跳到本地页面 | 应用内，直接进钥匙串 |
| 系统集成 | 弱：选目录、通知、托盘、开机启动都要 runtime 另做 | 原生支持 |
| 多标签页 | 多个标签页同时连 runtime，要处理并发与状态同步 | 窗口由应用管理 |
| 界面更新 | 后端发布即生效 | 随应用升级（可混合，见 2.4） |
| 跨平台一致性 | 各浏览器行为不同 | Electron 自带 Chromium，一致 |
| 安装包大小 | runtime + Codex | 再加约 100MB（Electron） |
| 远程场景 | 天然可扩展 | 要另外设计 |
| 试用传播 | 可先注册看演示 | 须先下载 |

### 2.3 关键理由

1. **安全模型**：浏览器方案的核心难点是"后端下发的网页代码不可信"，于是 key 输入与工具级审批必须挪到本地页面，一个产品两个界面不可避免。Electron 里界面代码在本地并签名，这个问题不存在。
2. **复杂度花在哪**：本地端口、Origin 校验、浏览器配对、localhost 访问限制、多标签页，全是为"界面在浏览器里"付的代价，对产品本身没有价值；先做浏览器版等于花力气做一套注定被丢掉的机制。
3. **切换成本低**：界面代码（组件、契约、数据获取）基本原样复用，差别只在页面从哪里加载、怎么与本地通信。

**框架**：优先 Electron（行为一致、生态成熟，VS Code、Cursor 同路线；包里已有数十 MB 的 Codex，Electron 的体积相对不突出）。在意包大小或团队熟悉 Rust 时可选 Tauri，但它用系统自带网页引擎，三平台差异要多测，Linux 上尤其明显。

**何时改回浏览器**：近期要支持"执行在远程机器、界面在本地浏览器"时。为此保留 2.5.3 的 `runtimeClient` 抽象。

### 2.4 套壳陷阱与混合做法

只把后端网址塞进 Electron（`loadURL`），得到的仍是浏览器方案，安全问题一个没少；若再给远程页面挂上能调用本地能力的 preload，比浏览器更危险。

需要保留"后端发布即生效"时可以混合：主界面从后端加载但**不挂任何 preload**（或只给只读能力）；工具级审批、key 输入、工作区授权放在随应用打包的独立窗口，由主进程弹出。

### 2.5 对详细架构的影响

#### 2.5.1 前端（`investment-app/investment-web-frontend`，Next.js 16 + React 19）

**可以复用**：`components/`、`contracts/`（zod 校验）、`lib/interaction/`（创建 Task、查询、操作）、React Query 数据获取、next-intl 文案、界面组件。

**必须改**（现状取证于该仓代码）：

| 现状 | 为什么在 Electron 里不行 | 改为 |
| --- | --- | --- |
| `next.config.ts` 为 `output: 'standalone'`，依赖 Next 服务器 | Electron 里没有 Next 服务器 | `output: 'export'` 静态导出，经自定义协议（如 `app://`）加载；不用 `file://`（绝对路径与路由会出问题） |
| 工作台页面在服务端用 cookie 调 `/api/auth/web/me` 检查登录（`lib/server/auth-session.ts`），页面 `force-dynamic` | 静态导出不支持服务端读 cookie、动态渲染 | 登录检查挪到客户端；未登录跳登录页 |
| `proxy.ts` 在服务端生成 CSP nonce 并做多语言路由 | 静态导出没有中间件 | CSP 由 Electron 会话设置响应头；多语言改为不依赖中间件的路由 |
| `lib/common/api-client.ts` 强制同源 `/api/...`、`credentials: 'same-origin'`，cookie + CSRF | 应用来源不是后端域名，跨站 cookie 基本不可用 | 后端绝对地址 + `Bearer` token；token 认证不需要 CSRF；后端 CORS 放行应用来源 |
| 登录跳转后端 `/auth/web/login`（Casdoor），用 `return_to` 回到网页 | 桌面应用不能靠网页回跳 | 见 2.5.2 |

另外（在不改 Next 运行方式的前提下）也可以在 Electron 里跑 Next standalone 服务器，改动最少，但重新引入本地端口、应用更重，不建议。

**Electron 安全配置**：开启 `contextIsolation`、`sandbox`，关闭 `nodeIntegration`；禁止窗口导航到外部网址（`will-navigate`、`setWindowOpenHandler`）；preload 只经 `contextBridge` 暴露具体函数（如 `approve(id, ok)`、`saveKey(provider, key)`），不暴露"执行任意命令"类通用接口；设置 CSP。这几项没配好，Electron 比浏览器更危险。

**应用本身**：代码签名、公证、自动更新（如 electron-updater）；更新包校验完整性。

#### 2.5.2 登录与会话

- 桌面端用系统浏览器打开 Casdoor 登录页，走 OAuth PKCE；通过自定义协议链接（或本地回调端口）回到应用；
- token 存系统钥匙串，刷新由应用负责；
- 后端新增桌面端 token 发放与刷新；网页端的 cookie 会话保留；
- 设备配对（1.10）复用同一登录态：应用登录后，由应用引导 runtime 完成 Device Code 配对。

#### 2.5.3 本地通信

- 前端所有与 runtime 的交互集中在一个 `runtimeClient` 模块：Electron 实现走 preload → 主进程 → runtime 本地管道；将来若做远程场景，再补一个 HTTP/WS 实现，页面代码不动；
- 工具级审批、key 输入、工作区授权做成独立页面，不依赖后端数据即可渲染；
- 浏览器方案里的几种本机连接方式不再需要：localhost HTTP（健康检查）、localhost WebSocket（事件流）、浏览器扩展 + Native Messaging。自定义协议只用于登录回调与"唤起应用"。

#### 2.5.4 runtime 的进程形态

- runtime 是独立的 Python 后台进程，由 Electron 主进程拉起并监管；主进程与 runtime 之间用本机管道（stdio 或仅本用户可访问的本地套接字），不开 TCP 端口；
- runtime 同时注册为用户级后台服务，窗口关闭后仍可接收派发（由设置决定）；应用启动时连接已在运行的 runtime，而不是再起一个；
- runtime 打包：带 Python 运行环境与 Codex 钉版二进制，随应用一起签名、一起更新。

#### 2.5.5 后端

- **U1（web 面生产适配器的形状）随之确定**：没有 Next BFF，会话与投影由后端持有；
- `request-lifecycle` F-ADMIT-04 写的是"浏览器入口…身份来自登录会话"，要改为"客户端入口…身份来自登录会话或桌面端 token 会话"。这是合同改动，按 SDD 规则提修订工作单元；
- F-DELIVERY 的 cursor 回放、先持久化后通知照旧；AT-16/AT-17 的"前端断线/页面刷新"在桌面端对应"断线/应用重启"；
- 事件流（SSE 或 WebSocket）对桌面端同样适用，token 认证。

#### 2.5.6 网页端

保留一个轻量网页端：账号、计费、报告、任务历史；不做任何本地操作，不输入 key，不做工具级审批。

## 3. 对现有文档与代码的重构影响

`mooc-manus-langgraph-longterm-plan-v5.md` 已降为历史输入；`dev-agent-task` 里仍沿用"执行器在后端 worker"前提的内容，按本设计重构：

### 3.1 文档

| 文档 | 要改什么 |
| --- | --- |
| `README.md` | "第一层分前端与后端，Agent / runtime 与验收器归后端"：第一层是否改为三部分，见 D1 |
| `composition/development-plan.md` | 阶段一"前后端对接"的对象换成 Electron 客户端 + 后端 + 本地 runtime；U1 结论 |
| `components/0001-backend/components/0002-agent-execution` | §2.6–2.10：执行位置改到本地 runtime；§2.10 的四条部署阻断（worker 无模型出口、根文件系统只读、768Mi 内存、模型凭据未进部署包）对执行器不再适用；Celery 进程纪律只约束派发网关与后端角色 |
| U5（外部 harness 的部署形态） | 有了答案：在用户电脑上，用用户凭据，由本地 runtime 管理 |
| U2（执行层 Port） | Port 不变，新增"派往本地 runtime"的 Adapter；① 的消息契约要定 |
| U3（预算账、证据账落表） | 仍是前置；预算账增加"自报"来源字段 |
| `components/0002-frontend` | 目标改为 Electron 客户端（2.5.1–2.5.3） |
| `composition/request-lifecycle.md` | F-ADMIT-04 措辞（修订工作单元） |
| 新增组成部分 | 本地 runtime（连接、策略、审批、模型配置、执行 Adapter）；知识服务的 MCP 接口 |

### 3.2 代码

| 仓 | 改动方向 |
| --- | --- |
| `investment-web-frontend` | 静态导出、客户端登录检查、`api-client` 改 token、Electron 壳、`runtimeClient` |
| `investment-backend` | LangGraph 作为确定性编排使用，不在后端接模型调用；`RunBudget` 从内存换到 PG；`AgentProfile` 从审计字段变为执行约束；新增设备注册与配对、WSS 派发网关、桌面端 token、工具级审批结论与副作用意图的接收 |
| `knowledge-app` | 在现有检索接口外包 MCP；按设备 token、限流 |
| 新仓：本地 runtime | Python；Codex Python SDK；钥匙串；本地转换层（可后做） |

## 4. 待定决策

| # | 问题 | 建议 | 影响 |
| --- | --- | --- | --- |
| D1 | 第一层分两部分（前端、后端）还是三部分（客户端、本地 runtime、后端） | 三部分：本地 runtime 与后端运行位置、信任域、发布方式都不同 | 子任务划分与责任投影（合同 §9） |
| D2 | 本地 runtime 的语言与 SDK | Python 后台进程 + Codex Python SDK | A4 合规、审批回调、打包体积 |
| D3 | 两层审批各管哪些动作 | 不可逆、对外可见的归 Task 级；工作区内可回退的归工具级 | F-EXEC-03、F-INTERACT-* 的落点 |
| D4 | 断线规则 | 断线即暂停，重连后按 fencing 对账 | I9、I14、AT-09、AT-12 |
| D5 | U1 | 后端持有会话与投影 | 前端与后端接口 |
| D6 | 本地文件修改的副作用记账粒度 | 按 Profile 声明，可回退修改批量记账，不可逆动作逐条 | 副作用账表结构 |
| D7 | 界面是否全部打包在本地，还是混合加载 | 起步全部打包 | 更新节奏与安全边界 |
| D8 | 是否先做"只做远程 MCP"的轻方案验证领域价值 | 视市场节奏决定 | 排期 |
| D9 | 知识服务（MCP）是否脱离控制面单独提供，如何定价 | 先不单独提供；若提供，按设备或用量计费并限流 | 用户能否绕开控制面；收入结构 |

## 5. 未验证事项 ⚠

- Codex 自带沙箱在三平台上的实际机制与边界（以钉版实测为准）；
- Codex Python SDK 默认自动同意审批的行为在当前钉版是否仍成立，替换后的审批回调能否覆盖全部高风险动作；
- 第三方 Responses 接口的 compaction 条目兼容性、reasoning effort 是否发出；
- 各浏览器对公网页面访问 localhost 的限制细节（只影响浏览器方案，是否保留远程场景时再测）；
- Python 运行环境 + Codex + Electron 的安装包体积与三平台签名流程；
- 用户电脑上多路并行 Attempt 的资源占用；
- 断线即暂停对长任务体验的影响；
- 对比评测与推荐模型清单所需的领域评测集尚不存在，"本产品优于原版 Codex"目前只是目标，没有数据；
- `investment-app` 目前没有业务数据表，问数类 Profile 的前置仍未解决。
