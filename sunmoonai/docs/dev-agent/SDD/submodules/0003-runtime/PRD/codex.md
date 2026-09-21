# 驱动 Codex

> 由产品合同搬入（合同「去向」表登记）。本模块要满足什么见 [requirement.md](requirement.md)。

**完整打包**：Codex 整体随应用打包在用户电脑上运行；不在后端运行 agent loop，不自建或改写 Codex 的工具层。agent 行为只经本节「控制面」列出的入口影响。

**驱动方式**：runtime 是独立的 **Node 后台进程**，经 **`codex app-server`** 的 stdio JSON-RPC 驱动 Codex，
用官方生成的 TypeScript 类型与 JSON Schema，不自行逆向报文，不解析终端输出，不为它新增本地 TCP 端口。
边界见 [`engine-adapter.md`](engine-adapter.md)（`D28`）。

runtime 必须：

- 让所有命令执行与文件修改都经过审批判定，哪怕随后自动放行（⚠ 性能与可行性）。协议层的审批是显式的 `ExecCommandApproval` / `ApplyPatchApproval` 请求与响应，**没有「默认同意」这回事**——那是 Python SDK 的行为。⚠ **待验**：不应答时协议怎么表现（阻塞？超时？），须实机确认；
- 钉住 Codex 与 **app-server 协议**版本，升级钉版必须重跑锚点；
- 连接时带 `clientInfo.name` 标识本产品；
- 把运行时 thread 标识作为执行绑定经 ① 写回后端，不作为 Task 的真源；
- 与用户自己安装的 Codex 完全隔开：使用自己的二进制路径与独立的 `CODEX_HOME`，不读取、不改写用户自己的 Codex 配置与记录；
- 主动外连后端，维护设备身份（§2.10）；
- 保管 key（§2.9）；
- 为每个 Attempt 建立独立工作区，并在批准后把改动合进用户工作区（§8.3）；
- 把需要云端决定的工具级请求升级为 Task 级审批（§6.2）；
- 执行策略：限定工作区、禁止关闭沙箱、危险操作必须审批、并发上限、只接受签名的派发内容。

**控制面**：runtime 只能经 **app-server 协议**影响 Codex 的行为，**不得另辟通路**。协议的客户端方法
约一百个，下面按职能列出产品要用的那些；完整清单以钉版的 `ClientRequest` 为准。

| 职能 | 方法 | 管得到什么 |
| --- | --- | --- |
| 会话与轮次 | `thread/start`、`thread/resume`、`thread/fork`、`turn/start` | 模型与 provider、推理档与摘要档、工作目录、沙箱模式与细则、审批策略、约束最终回答的 JSON Schema |
| 基础与开发者指令 | `thread/start` 的指令参数与 `Personality` | 整段替换基础系统提示词、追加开发者指令、语气 |
| 工程侧指令文件 | 工作区内的 `AGENTS.md` | 工作区一级的约定（**与协议无关**，走文件系统） |
| 配置 | `config/read`、`config/value/write`、`config/batchWrite`、`config/mcpServer/reload` | MCP server 登记、执行策略、生命周期 hooks、模型 provider 等全部配置项。**是一组运行中可读写的方法，不是启动参数** |
| 轮次干预 | `turn/interrupt`、`turn/steer` | 终止本轮、中途改方向 |
| 进程干预 | `command/exec/terminate`、`command/exec/write`、`command/exec/resize` | 终止已启动的命令进程；向其写入 |
| 沙箱（Windows） | `windowsSandbox/readiness`、`windowsSandbox/setupStart` | 沙箱就绪检查与安装流程 |
| 审批应答 | 对 `ServerRequest` 的响应，见下 | 每一次请求批不批 |

**审批是服务端发起的请求，共五种**——`ServerRequest` 里的 `item/commandExecution/requestApproval`、
`item/fileChange/requestApproval`、`item/permissions/requestApproval`、`item/tool/requestUserInput`、
`mcpServer/elicitation/request`。runtime 必须**全部接住**，它们同时是副作用台账的采集点（§8.3）。
协议层没有「默认同意」这回事——那是 Python SDK 的行为。

**方法工具不走 `DynamicTool`。**协议有客户端注册、服务端回调的动态工具（`DynamicToolSpec` →
`item/tool/call`），但它**只能在 `thread/start` 下发、没有 turn 级覆盖、没有注册与注销方法**，
且标着 `#[experimental]`；满足不了「清单随派发下发、**随换步失效**」。方法工具按
[`0003-orchestrator`](../../0001-backend/SDD/modules/0003-orchestrator.md) 的设计走 MCP 代理，
换步时用 `config/mcpServer/reload` 重载。

生命周期 hooks 是外部命令，可用事件与其阻断能力以钉版实测为准（⚠）；协议侧有
`hooks/list` 与 `hook/started`、`hook/completed` 两个通知。并行 Attempt 可以用 `thread/fork`
建立，也可以各起一个 thread；选哪种由 §2.6 的工作区隔离要求决定。

**可观察面**：`ServerNotification` 约八十条，覆盖推理摘要与正文（`item/reasoning/*`）、
计划更新（`turn/plan/updated`）、命令输出（`item/commandExecution/outputDelta`）、
文件补丁（`item/fileChange/patchUpdated`）、MCP 工具调用进度、token 用量
（`thread/tokenUsage/updated`）、上下文压缩（`thread/compacted`）、错误与警告。runtime 据此
产出进度投影与执行证据（§8.3）。**通知是只读的，一切拦截走审批请求的应答。**

两条对本产品特别要紧：

| 通知 | 为什么要紧 |
| --- | --- |
| `turn/started` / `turn/completed` | **逐 turn 的完成归属**——Attempt 的终态判定据此，不靠猜 |
| `process/exited` | **子进程退出的直接观测点**——「取消是否真的停止副作用」那条待验项（附录 B）靠它验，不能只看 `turn/interrupt` 返回了 |

**不可介入**：agent loop 的决策、提示词组装与上下文裁剪、上下文压缩的内部逻辑、内置命令执行与补丁工具的实现、模型线路格式、沙箱实现本身。产品不得设计依赖这些内部行为的机制。钉版升级时，锚点必须覆盖本节列出的方法、五种审批请求与可观察面。

