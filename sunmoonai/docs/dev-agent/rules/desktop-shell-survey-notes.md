# 桌面外壳与执行体调研

SunMoonAI 的桌面应用（[`0002-desktop`](../SDD/modules/0002-desktop.md)）与本地 runtime
（[`0003-runtime`](../SDD/modules/0003-runtime.md)）是否可以不自建，以及执行体是否可以不用 Codex。
2026-09-21 取证。

⚠ **编号已更正**：早期版本用 D16/D17/D18，与合同里已有的三条（研究底稿呈现、
定位的法律边界、自有数据下发上限）撞号。现改为 **D25/D26/D27**，接在合同当前最大号 D24 之后。

这是**取证记录**，不是规范：留在 `rules/` 下是为了让 D25、D26 的依据可复核，
用法同后端旧划分的四份 `*-notes.md`。结论一旦落进合同或约束，以那边为准。

---

## 一、结论摘要

| 问题 | 结论 |
|---|---|
| 用 DeepSeek Harness 替掉 Electron + local runtime？ | **不能整体替代。**它是 Codex 的替代品，不是 runtime 的。三条硬伤见 §三 |
| 桌面外壳从哪来？ | **不 fork 任何仓当基座。**抄 `stablyai/orca` 的窗口策略与套接字守护进程那几份文件，三窗 preload 与 IPC 自己写。见 §五 |
| Electron 还是 Tauri？ | **已定 Electron**（团队不做 Rust）。Tauri 那边也没有可当基座的成品 |
| 上了现成外壳，周期能省多少？ | 壳那部分能省一半，业务一分不省；真正的收益是省错误，不是省时间。见 §六 |

**取用模型：参考实现，不 fork 整仓。**2026-09-21 cursor 在本机实读 Orca 的 `src/main` 后
改定——原来的「fork 一次自己养」建立在「壳能从产品逻辑里干净摘出来」这个前提上，
而那个前提**不成立**（§五之零）。

三条待落的决定：

- **D25 执行体是谁**——Codex / dsh / 双腿经 `AgentExecutorPort`
- **D26 桌面外壳从哪来**——**不 fork 任何仓**；新建薄壳（Electron Forge / electron-vite 工具链），定点移植 Orca、goose 的小模块
- **D27 Electron 还是 Tauri**——已定 Electron，应写进 `rules/constraints.md` 而非待决表

**D26 与 D25 不耦合**：基座只负责壳与通道，执行体协议归 D25。避免以后有人拿
「Orca 用 PTY 不用 SDK」来反对选它当壳——那一层你们全要自己写（§五之三）。

---

## 二、取证成色

不同结论的证据强度不一样，用的时候要分清。

| 对象 | 做了什么 | 成色 |
|---|---|---|
| DeepSeek Harness | 读源码；钉版 `dd6322d6` 与本地 checkout **同一个提交**，协议限制逐字引 | 强 |
| goose `ui/desktop` | 克隆 + `pnpm install`（73 秒）+ `tsc --noEmit` 干净过 + Vite 编出 main/preload + **53 个主进程侧单测全过**，全程无 goosed、无 Rust 工具链 | 强 |
| AionUi | 克隆 + `bun install`（131 秒，1599 包）+ `tsc --noEmit` **全仓干净过** + `binaryResolver` 测试过，全程无 aioncore | 强 |
| **Orca** | 本机只做了静态分析（**行数统计有误，已作废，见下**）；**实机启动与 `src/main` 通读由 cursor 在本机完成**，结论以那一份为准 | 强（来自 cursor 的实读） |
| Tauri 生态 | 网搜 + 文档，未取代码 | 弱 |
| awesome 清单其余约 20 个 | 只有名字、许可、星数 | 弱 |

### ⚠ 已作废：本备忘早期版本里的全部行数

统计写法是 `find … | xargs wc -l | tail -1`。文件多且路径长时 `xargs` 会**分批**执行 `wc`，
每批各打一行 `total`，`tail -1` 只取到**最后一批的小计**。复现（6000 个文件、真值 18000 行、
路径深度贴近 Orca）：分了 7 批，该写法得 **1602**，正确求和 **18000**。

Orca 的文件名最长最深，被削得最狠：本备忘曾报 `src/` 31 万行，**实际生产 TypeScript 约 74 万行**
（cursor 实测：`runtime` 21 万、`ipc` 8 万、`browser` 4 万、`daemon` 2.7 万）。
goose 与 AionUi 的数同样不可信，只是路径短、偏差小。**凡本备忘出现的行数，一律当作未经核实。**

正确写法：`find … -print0 | xargs -0 wc -l | awk '/total/{s+=$1} END{print s}'`。

---

## 三、执行体：DeepSeek Harness（dsh）

`~/repo/deepseek-harness`，MIT，Cordis 插件架构，0.1.2-alpha.3。

### 位置错位

dsh 自己就是一个 agent harness——agent loop、LLM 适配、工具注册表、会话日志。
合同写的是「**一个执行体：执行体只有 Codex**」。所以上 dsh 不等于省掉 runtime，
等于**换掉 Codex**。它和 Codex 的唯一关系是 `hooks-codex` 包（读你现有的 `hooks.json`）。

### 三条硬伤（`packages/sdk/protocol/README.md`，逐字）

| 行 | 原文 | 撞上什么 |
|---|---|---|
| 115 | **No cancel or session-close methods** — a client abandons a turn by closing the runtime process | 取消只能杀进程。「断线即暂停、重连对账」要的是**可恢复的取消** |
| 116 | **Server→client requests are a dead capability** — the transport supports them, but the server never sends one | **收不到审批请求**。而 runtime 的核心职责就是工具级审批拦截点。结论：**不得声称原生 HITL** |
| 52 | `SessionPromptResult.messageId` … **does not identify a later assistant message, turn ending, or prompt result** | 缺完成归属，**不能伪装 `COMPLETED`** |

对称事实：Codex 的 `_default_approval_handler` 对 `commandExecution` 与 `fileChange`
**一律 accept**，必须覆盖默认 handler。区别是 Codex **能覆盖**，Harness **根本收不到**。

### 它强在哪

> preset 是一目录一 `agent.cordis.yml`，按会话组合 tools/prompt/skills/persona，一进程可跑多种 agent

这是「专业 agent 用 deepseek harness」的由来，今天依然成立。沙箱三平台齐全
（Linux landlock、macOS、Windows ACL），多厂商 LLM 适配（`llm-pi-ai`）。

### 不能当 runtime 的另一条理由

它有自己的 append-only `SessionEvent` log 与会话持久化。当 runtime 用，这份 log 和
后端事件表就是**两个真源**——正是 `I13` 反对引图执行框架的同一个毛病。当**执行体**则无此问题。

### 其它不符项

- `credentials-local` 把 key 存**文件**（`<harness home>/.credentials.yaml`）。`I16` 要求存系统钥匙串。
  文档原话：keyring / KMS 后端「**None is shipped**」
- 无外连、无设备身份、无租约与 fencing；`webhook` 是入站且明写「无投递库、无队列、无重试、无去重」
- 全仓 README 搜不到 encrypt——没有结果端到端加密
- `SAFETY.md`：未经安全审计、不可当生产、「**不要把它当作唯一的安全控制**」

**建议**：作为**专业腿的执行体**评估（D25），不作为 runtime 或桌面的替代。
上了 dsh 之后 runtime **更必要**——取消、审批、完成归属三个洞只能在 runtime 补。

---

## 四、桌面外壳：四家对比

| | **Orca** | goose `ui/desktop` | AionUi | emdash |
|---|---|---|---|---|
| 仓 | `stablyai/orca` | `aaif-goose/goose` | `iOfficeAI/AionUi` | `generalaction/emdash` |
| 许可 | **MIT** | Apache-2.0 | Apache-2.0 | Apache-2.0 |
| ★ | **73747** | 54504 | 32991 | 5790 |
| 建仓 | 2026-03 | — | 2025-08 | 2025-08 |
| 治理（**不算数**，见下） | Stably 一家公司 | Linux 基金会 AAIF | iOfficeAI 一家 | 一家 |
| **接手行数**（真正的成本） | **≈3.5 万**（main 24367 + preload 11095） | ≈5600（5199 + 375） | ≈1.4 万 | — |
| **守护进程语言** | **TypeScript（0 行 Rust）** | Rust（goosed，577 文件） | Rust（AionCore，另一个仓） | — |
| 主进程 | 24367 行 | **5199 行** | 13849 行 | — |
| preload | 11095 行 / **155 个文件** | 375 行 / 1 个文件 / 47 个 IPC 全暴露 | 165 行 / 4 个文件 | — |
| 界面（不要的） | 63481（另 shared 149603） | 53868 | 122692 | — |
| `sandbox: true` | **✅ 12 个窗口里 7 个** | ❌ | ❌ | — |
| 按窗口隔离 | **✅ `partition` + session 隔离策略** | ❌ 共用一份 preload | ✅ 四份 preload（但总线不按窗口鉴权） | — |
| 桌面↔守护进程 | **✅ stdio + ipc 管道** | ❌ `ws://127.0.0.1:port/acp?token=` | ❌ `http://127.0.0.1:port` | — |
| 守护进程常驻 | ✅ relay-daemon | ⚠ **两条路径**：桌面自管的那条每窗口一个、关窗即清；但 `createExternal()` **可连已在跑的外部后端**，退出时只释放连接、不停后端 | ✅ 单实例，带崩溃恢复 | ❌ 无 sidecar |
| 驱动 agent | PTY + spawn，**无协议** | ACP over WebSocket | ACP（`@agentclientprotocol/sdk`） | git worktree |
| 换 sidecar 的接缝 | provider 适配层 | `GOOSE_BINARY` 环境变量 | `AIONUI_BACKEND_BIN` 环境变量 | — |

> **「治理」那行不算数。**取用模型是 fork 一次自己养（§五之零），上游的治理形式与
> 迭代速度都不影响你——手里是一份快照加一张许可证。**真正的成本是「接手行数」那行。**

### 查过但排除的

| 项目 | 许可 | 排除原因 |
|---|---|---|
| AnythingLLM | MIT 66269★ | **仓里没有桌面源码**，桌面版二进制分发 |
| OpenClaw | MIT **390155★** | 不是桌面外壳（住在 WhatsApp/Telegram/Discord 里的个人 agent） |
| opencode | MIT **208912★** | 不是桌面外壳（Solid.js + TUI + server） |
| Cherry Studio | **AGPL-3.0** 52034★ | 传染性 copyleft |
| Chatbox | **GPL-3.0** 41816★ | 同上 |
| PI-Desktop | **LGPL-3.0** | 同上 |
| LobeHub / Jan / 5ire | 自定义或改过的许可 | 要逐条读 |
| openwork | 开放核心双许可 | `ee/` 目录，闭源商用有风险 |
| Void | Apache-2.0 28798★ | VSCode fork，外壳太重 |
| ClawX 7615★ / open-cowork 2160★ / Orkas 2101★ / nimbalyst 1752★ | MIT | 体量小，只拿到元数据未看架构 |

---

## 五、Orca 怎么用：抄几份文件，不 fork 整仓

### 零、结论改了：壳摘不出来

2026-09-21 由 cursor 在本机实读 `src/main` 得出，**推翻本备忘早期版本的「fork 为基座」**。
原判断建立在静态推断上（依赖方向 + 文件名 + grep），没有读代码。

**摘不干净的四条（cursor 实读）**：

| 发现 | 撞上什么 |
|---|---|
| 主窗口开了 **`webviewTag: true`** | 正是本备忘曾拿来否 AionUi 的那一条。**两家都开，批评对称成立**——早期版本只查了 AionUi，没查 Orca |
| **主窗与仪表盘共用同一份 preload**，挂着 worktree / skills / Codex / SSH / pet / mobile 几十个 API | 「155 个 preload 文件 = 按窗口分能力」是误读，155 是**模块数**不是窗口数。审查窗口不能用这套 |
| 隔离做在 **guest webview** 上，不是「一窗一份能力」 | 早期版本写的「它真做了你们那条窗口边界」**过头了** |
| `attachMainWindowServices` 一上来就注册 repo / worktree / PTY / SSH / runtime | **没有壳与产品之间的端口**，拆不出来 |
| `daemon` 是**终端 PTY 守护进程** | 不是你们要的 runtime 进程 |

加上体量的真值（约 74 万行生产 TS，不是早期版本说的 31 万），**「fork 整仓再删」不成立**。

### 零之二、仍然值得抄的（cursor 确认真趟过坑）

| 抄什么 | 内容 |
|---|---|
| **窗口策略** | 主窗口 `sandbox: true`；仪表盘另开**内存 partition**并**关掉 `webviewTag`** |
| **外来内容的收口** | 走 `<webview>`：`will-attach-webview` **默认拒绝**，清掉 guest 的 preload，强制 `sandbox` / `contextIsolation` / `nodeIntegration: false`，**partition 必须在允许名单里** |
| **特权窗纪律** | 禁止导航到远程 URL，避免继承 preload |
| **守护进程** | **Unix 套接字 + token 文件 + 崩溃节流**，实机对得上 |

第四条符合 `channels.md` ③「仅本用户可访问的本地套接字」，**不开 TCP 端口**。

**正确用法：抄这几份文件当参考实现，三窗 preload 与 IPC 自己写。**
Orca 是**壳的首选参考**，不是可拆的基座。

### 一、全 TypeScript

主干 **0 个 `.rs` 文件**；`src/relay` 是 373 个 ts 文件；`native/` 只有平台小工具
（macOS Swift、Windows PowerShell + 一个 C#、Linux 两个 Python 脚本）。

goose 的 goosed 和 AionUi 的 AionCore 都是 Rust——虽然你们本来就要换掉它们，
但它们的协议、健康检查、租约语义写在 Rust 里，读参考实现就得读 Rust。

这条和你们自己的栈也一致：runtime 是「经 **Codex Python SDK** 驱动 Codex」，也不是 Rust。

> ⚠ **已被 `D28` 取代**：runtime 改为 TypeScript，经 `codex app-server` 的 stdio JSON-RPC 驱动。
> 当时的推导「A4 禁裸协议 + 只有 Python SDK 能拦审批 = 必须 Python」**前提错了**——
> `app-server` 是带版本、带 JSON Schema、带官方生成 TS 类型的**公开接口**，不是裸协议。
> 见 [`engine-adapter.md`](../SDD/submodules/0003-runtime/PRD/engine-adapter.md)。

### 二、窗口边界：它趟过坑，但不是「一窗一份能力」

`0002-desktop.md` 写着：

> 三扇窗口各自一个 webContents，**能力按窗口授予**，所以窗口就是能力边界
> **审查窗口不挂本机能力**——它展示的内容来自后端，外来内容加本机能力就是提权路径

Orca 的做法：12 处建窗口，**7 处显式 `sandbox: true`** ＋ `nodeIntegration: false`
＋ `contextIsolation: true`，再加 **`partition` 按窗口隔离 session**，配套
`browser-session-partition-policies`、`browser-route-session-retirement`、
`browser-route-renderer-prepare-fence` ——这套东西就是为**展示外来内容**建的。

另外两家都靠 `contextIsolation` 单撑，而
[有公开研究指出 contextIsolation 不是硬边界](https://s1r1us.ninja/posts/electron-contextbridge-is-insecure/)（v8 patch gap）。

⚠ **但不要读成「Orca 实现了你们要的窗口能力边界」**。cursor 实读后确认（§五之零）：
它的隔离做在 **guest webview** 上，主窗与仪表盘**共用一份 preload**，
而且主窗口同样开了 **`webviewTag: true`**——和 AionUi 一样。
可抄的是**外来内容的收口手法**（§五之二·抄什么），不是「一窗一份能力」这个结构。
那个结构你们要自己写。

### 三、通道对得上，而且没被协议绑死

`channels.md` 要求 ③ 走「本机管道（stdio 或仅本用户可访问的本地套接字）」，**不开 TCP 端口**。

| | 桌面↔守护进程 |
|---|---|
| **Orca** | **`stdio` 管道 + Node `ipc` 通道** ✅ |
| goose | `ws://127.0.0.1:port/acp?token=` ❌ |
| AionUi | `http://127.0.0.1:port` ❌ |

Orca 唯一的 TCP 监听是 `agent-hook-server`，绑 127.0.0.1，源码注释写明
「loopback only — 给盒子里的 agent CLI 回调用，外面够不着」，不是桌面↔守护进程那条。

**关于「它用 PTY、我们用 SDK」**：这个差异落在**驱动层**，不在壳。而且反而是优点——
选基座该看谁的壳最不被协议绑死：

- goose 的 `ui/desktop` **唯一的 workspace 依赖就是 `@aaif/goose-acp-client`**，整个壳围着 ACP 建
- AionUi 的 `@agentclientprotocol/sdk` 是主依赖
- **Orca 没有协议**，驱动层是 spawn + PTY，和壳之间隔着一层 provider 适配接缝
  （`agent-session-wire.ts` 自述：「Phase 2 builds **provider adapters** … against exactly these types」）

### 四、它有你们后端的核心概念，而且在对的那条链路上

| 你们的设计 | Orca 里 |
|---|---|
| outbox | `structured-agent-session-outbox.ts`，三态 **`queued \| dispatching \| unconfirmed`**，带重试、拒绝码、投递拒绝 |
| 幂等「同键同摘要返回原 id，同键异摘要返回冲突」 | `clientMessageId` + `structuredAgentSessionPayloadFingerprint`；`idempotencyKey` 进 contract |
| 租约 | `lease` 3135 次，有 `ownerLease`、`getSshRemotePtyLeases` |
| 账 | 有个文件就叫 **`codex-reset-credit-attempt-ledger.ts`**，里面是 `idempotencyKey: z.uuid()` |
| 事件流 | `agent-session-journal`、`agent-session-wire` |

**关键**：`structured-agent-session-outbox` 被 `src/renderer`（14 处）、
`src/main/runtime/rpc/methods`（1 处）、`src/shared`（2 处）使用，
**在 `src/relay` 里 0 处**。也就是说这套东西在**「界面 ↔ 主进程 ↔ 远端」**那条链路上
——正是你们的**通道 ③ 与 ④**——跟怎么驱动 agent 无关。

⚠️ 一条纠正：Orca 里的 **`fencing` 是假朋友**，指页面导航围栏（浏览器安全），
不是你们的租约 fencing。

---

## 六、周期能省多少

⚠ **本备忘早期版本在此处给过一笔账（桌面 13–20 人周砍到 6–10，接手一万行上下）。
那笔账作废**——它建立在「fork 整仓再删」上，而 cursor 实读后确认壳摘不出来（§五之零），
且所用行数是错的（§二）。

按现在的取用模型（抄几份文件当参考实现），账要重算，而且**现在算不准**：

| | 状态 |
|---|---|
| **省下来的** | 窗口策略、外来内容收口、套接字守护进程这几份文件的**设计**——不用自己趟坑 |
| **省不掉的** | 三窗 preload 与 IPC **自己写**；壳的其余部分（打包、更新、托盘、深链、开机启动）自己写或另找参考 |
| **一行都不给的** | Task 九站、类别预填、审查窗口、交付、本地知识库、结果端到端加密、登录计费、与后端 ④ 的协议；后端七块（`0001-ledger` 到 `0007-delivery`） |

**怎么才能算准**：先把要抄的那几份文件点名列出来（窗口创建与 `will-attach-webview` 策略、
partition 允许名单、套接字守护进程与 token 文件、崩溃节流），数清它们的真实行数，
再估自己要写的三窗 preload 与 IPC。**这件事没做，所以本节不给数字。**

按 `verify-rules.md` 的三值写法，本节结论是 **`undecidable`**。

## 七、Electron 还是 Tauri（已定 Electron）

Tauri v2 的能力模型恰好就是你们文档写的那句，而且是框架默认：

| | Electron | Tauri v2 |
|---|---|---|
| 默认 | 原生能力**默认可达**，自己一层层关（`nodeIntegration: false`、`contextIsolation: true`、`sandbox: true`） | **默认全关**，用什么开什么 |
| 授予方式 | 自己写 preload，自己在主进程做 IPC 路由和鉴权 | **声明式**：`tauri.conf.json` 里按 capability 授权，**每个窗口/webview 单独给**，可带 scope 参数 |
| 边界强度 | contextIsolation 不是硬边界 | 前端只能碰显式放行的 Rust 命令 |

这也解释了为什么三家 Electron 项目里只有 Orca 做到了那条边界——
**在 Electron 里那是要自己建的工程，在 Tauri 里那是框架默认。**

Tauri 生态里的 AI agent 桌面应用很薄，没有可当基座的成品：
`EDEAI/OpenFlux`（MIT，Tauri v2）、`tempestai-dev/tempest`（Apache-2.0）。

**决定：Electron。理由——团队不做 Rust。** 这条应写进 `rules/constraints.md`
当约束，不进 Appendix A 的待决表。

---

## 八、覆盖声明

按 [`verify-rules.md` 的「覆盖声明：查了、没查、不能排除」](../../dev-human/uat/verify-rules.md) 三档写。

### 查了（有观测，有结论）

| 观测 | 谁做的 | 结论 |
|---|---|---|
| dsh 协议的三条限制 | 本机读源码，钉版 `dd6322d6` 与 checkout 同一提交 | `fail`——无取消、审批是死能力、无完成归属 |
| goose 壳脱离 goosed 能构建 | 本机 install + tsc + Vite + 53 个单测 | `pass` |
| AionUi 壳脱离 aioncore 能构建 | 本机 install + tsc + 单测 | `pass` |
| **Orca 能起来** | **cursor 本机 `pnpm dev`**，exit 0 | `pass` |
| **Orca 的壳能否从产品逻辑里摘出** | **cursor 本机通读 `src/main`** | **`fail`**——见 §五之零 |
| Orca 守护进程的通道 | cursor 实机 | `pass`——Unix 套接字 + token 文件 + 崩溃节流 |

### 没查（没有观测，明知自己不知道）

| 类别 | 条目 | 性质 |
|---|---|---|
| **环境事实**（可当场复跑） | awesome 清单剩下约 20 个的架构；Tauri 生态未取代码 | 跑了就有结论 |
| **环境事实** | Orca 的 `setAsDefaultProtocolClient`（协议登录回调）、`setLoginItemSettings`（开机启动）、`notarize`（公证）——本机 grep **没查到**，未确认是真没有还是写法不同 | 同上 |
| **远端与授权** | GitHub 检索接口两次限流，awesome 清单那一批的元数据是绕道拿的，未逐仓核对 | 部分可读 |
| **执行者内部** | 无 | —— |

### 不能排除（有观测但不足以定论）

1. **本备忘引用的一切行数**。统计写法有误（§二），Orca 的已被 cursor 实测推翻；
   goose 与 AionUi 的**没有重测**（本机克隆已删）。**不能排除这两家的数同样偏低。**
2. **goose 与 AionUi 是否也有「壳摘不出来」的同类问题**。对 Orca 的判断来自通读 `src/main`；
   另两家只做了构建与单测，**没有通读主进程**。它们的 `attachMainWindowServices` 一类入口
   有没有同样把产品服务焊死在壳上，**不能排除**。
3. **「抄那几份文件」的实际工作量**。要抄的文件还没点名列出、没数行数（§六）。

### 2026-09-21 第二轮订正（codex 读源码）

| 本备忘原写 | 实际 | 依据 |
|---|---|---|
| goose「每窗口一个后端，窗口关了就清」 | **不完整**。还有 `createExternal()` 一条：连已在跑的外部后端，退出清理**不停后端**。所以「退出桌面仍继续执行」**不能用来排除 goose** | `ui/desktop/src/main.ts`、`gooseServeLeaseRegistry.ts` |
| 决定项编号 D16/D17/D18 | **撞号**。合同里这三个已是研究底稿呈现、定位法律边界、自有数据下发上限。现改 D25/D26/D27 | `product-contract.md` 附录 A |
| 「抄 Orca 几份文件」 | 方向对，但**基座应是自己新建的薄工程**（Electron Forge 或 electron-vite 工具链），Orca/goose/AionUi 都只作定点移植来源 | codex 通读三仓的窗口启动、preload/IPC、后台进程生命周期与退出清理 |

⚠ Electron Forge 的 Vite 插件官方仍标 **experimental**，选它要锁版本并先验 Windows 打包与 Python 服务安装。

### 这一轮改了什么

早期版本判定「fork Orca 为基座」，依据是静态推断（依赖方向、文件名、grep），**没有读代码**。
cursor 读了，结论相反。**教训：文件数与目录结构推不出「能不能摘」，只有读代码能。**

## 九、复现信息

仓在 `~/repo/`（仓外，不进 git），已删 node_modules，源码留作取证：

| 目录 | 大小 | 钉的版本 |
|---|---|---|
| `~/repo/deepseek-harness` | 240M | `dd6322d6`（2026-08-31） |
| `~/repo/goose` | 651M | 浅克隆 2026-09-21 |
| `~/repo/aionui` | 935M | 浅克隆 2026-09-21 |
| `~/repo/orca` | 382M | 浅克隆 2026-09-21 |

工具链（都在用户目录内，没动系统）：nvm Node 24.21.0、corepack pnpm 10.30.0 / 12.0.0、
bun 1.4.2（`~/.bun`）。goose 要 Node `^24.10.0` + pnpm `>=10.30.0`；
AionUi 要 Node `>=22 <25`，锁文件是 `bun.lock`（npm 不认 `workspace:*`）；
Orca 要 Node 24 + pnpm 12。

本机限制：3.6G 内存（`openclaw-gateway` 常驻约 800M），无 g++。
跑不动十万行级仓的全量测试；要跑只能 `--maxWorkers=1` 加单文件，或只做 `tsc --noEmit`。

顺手发现两处与本调研无关的问题：

- AionUi 的 `binaryResolver.test.ts` **不在 vitest 的 include 里**
  （只收 `packages/web-host/src/**` 和 `tests/**`），源码旁 8 个测试默认都不跑
- AionUi 的 Electron 侧**不自己拉 CLI agent**，只拉一个内置 MCP browser server；
  agent 全在 aioncore 里
