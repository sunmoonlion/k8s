# 实现笔记 ｜ `AgentExecutorPort` 照着协议怎么写

> **状态：累积中的实现笔记，不是结论、不是判据、不是取证记录。**
> ⚠ **不得被当作规范引用。**它的用途是：`executor-adapter` 轮开工时，
> 把已经查清的实现细节直接拿来用，不必重查。
>
> **与同目录另两份的分工**：
> `task.md` 是**判据**（冻结）；[`spike-codex.md`](spike-codex.md) 答「**接口提供什么**」；
> **本文答「照着它写代码，有哪些地方会写错」**。三者不重叠。
>
> ⚠ **本文全部结论来自读源码，未实跑。**凡「跑起来是否如此」一律未验证——
> 同一形态的教训见 `agent-dev-guide.md` §4.3 的 `NotImplementedError` 那条。
> 钉版：Codex `7d6f808b`、DeepSeek Harness `dd6322d6`。**升级钉版必须重跑本文全部锚点。**

---

## 1. 进程层：同一个二进制，**子命令决定协议**

```
CLI 交互:   shell  → codex                              → TUI 文本 on /dev/pts/N
CLI 一次性: shell  → codex exec                         → 人读文本 on pipe
可编程:     任意     codex app-server --listen stdio:// → JSON-RPC on 3 条 pipe
```

`app-server` 是 `codex --help` 里的**公开子命令**（标 `[experimental]`）。
Python SDK 起的就是它：`client.py:252` `args.extend(["app-server","--listen","stdio://"])`，
可执行文件取自 `bundled_codex_path()`（`client.py:111-121`）。

⚠⚠ **三条路径在 syscall 层完全相同**——干活的都是那个二进制。
Python 只做两件事：`fork/exec` 一次（`client.py:259` `subprocess.Popen`），
然后在管道上 `read`/`write`。

**对我们的直接后果：**

1. **SDK 不是能力，是封装。**能力上限 = 二进制的上限。
   ⚠ 这解释了 Harness 那句「server→client requests are a dead capability —
   the transport supports them, but the server never sends one」：**管道双向，二进制不发。**
   SDK 再怎么写也接不到不存在的消息。
2. **可以不用 Python SDK。**自己 `Popen` 讲协议是可行的，SDK 买的是
   编解码 + 请求响应配对 + 审批回调注册 + teardown 梯子。
   ⚠ **但见 §4：SDK 的执行模型有一处我们必须绕开，自建反而更省事。**
3. **「入口」这个词在本项目此前被用错了。**CLI 与 SDK 不是并列的两个入口——
   **SDK 包含 CLI，它是 CLI 二进制的调用者**。真正的三个维度是：
   谁起的进程 / 起的哪个子命令 / 管道另一头是谁。见 `dev-plan-refact` 轮 `findings.md` F-1。

---

## 2. 线路层：JSONL + 三类消息判别式

**分帧是换行，不是 `Content-Length` 头**（`client.py:840`）：

```python
self._proc.stdin.write(json.dumps(payload) + "\n")
```

**判别式**（`client.py:_reader_loop`）：

```python
if "method" in msg and "id" in msg:      # server→client 请求：必须回
if "method" in msg and "id" not in msg:  # 通知：不回
else:                                    # 对我方 request 的响应
```

⚠ **没有 `jsonrpc: "2.0"` 字段**——别拿标准 JSON-RPC 库直接解析。

写入加锁（`client.py:838` `with self._lock`），读只有一个线程。

---

## 3. `server→client` 请求全集：**九个，不是两个**

来源：`codex-rs/app-server-protocol/src/protocol/common.rs:1681-1752`。

| # | 请求 params 类型 | 语义 |
| --- | --- | --- |
| 1 | `CommandExecutionRequestApprovalParams` | 命令执行审批 |
| 2 | `FileChangeRequestApprovalParams` | 文件改动审批 |
| 3 | `ToolRequestUserInputParams` | ⚠ **工具调用时向人要输入**（EXPERIMENTAL）——**通用的「问人」通道** |
| 4 | `McpServerElicitationRequestParams` | MCP 服务器要信息 |
| 5 | `PermissionsRequestApprovalParams` | ⚠ **追加权限审批** |
| 6 | `DynamicToolCallParams` | ⚠⚠ **让客户端执行一个工具调用** |
| 7 | `ChatgptAuthTokensRefreshParams` | token 刷新 |
| 8 | `AttestationGenerateParams` | 生成上游 attestation |
| 9 | `CurrentTimeReadParams` | 从**客户端拥有的**时钟读时间 |
| 10–11 | `ApplyPatchApprovalParams` / `ExecCommandApprovalParams` | v1，已废弃（旧 turn API 路径） |

### ⚠ SDK 的默认 handler 只覆盖 2/9

```python
# client.py:773-779
def _default_approval_handler(self, method, params):
    if method == "item/commandExecution/requestApproval": return {"decision": "accept"}
    if method == "item/fileChange/requestApproval":       return {"decision": "accept"}
    return {}                    # ⚠ 其余七个：回空对象
```

**两个自动放行，七个行为未定义。**
`agent-dev-guide.md` §4.9 写的是「必须由 Adapter 强制显式传入 handler」——
⚠ **更精确的说法是：默认实现只覆盖了 2/9，其余七个返回 `{}`。**

### ⚠ 第 6 条是工具网关的接入点

`DynamicToolCall` 是运行时**把一次工具执行交给客户端**。
`agent-dev-guide.md` `F-3`（见 `dev-plan-refact/findings.md`）说
「`tool.enforced` 的前提是运行时拥有工具层」——**这个请求就是所有权移交的机制**。
⚠ 而 SDK 默认对它返回 `{}`。**我们要 `tool.enforced`，就必须实现它。**

---

## 4. ⚠⚠ 执行模型：handler 在 reader 线程里被**同步**调用

```python
# client.py:_reader_loop
while True:
    msg = self._read_message()
    if "method" in msg and "id" in msg:
        response = self._handle_server_request(msg)      # ← 同步
        self._write_message({"id": msg["id"], "result": response})
        continue
    ...
```

**handler 阻塞 = 整个 stdout 读循环冻结**，期间所有通知与响应都不再被路由。

而「转给人」天然阻塞。于是：

> ⚠ **审批期间，该会话收不到任何其它事件。**

### 这条决定 `principal channel` 怎么接（四个可行形状）

| 形状 | 做法 | 代价 |
| --- | --- | --- |
| 甲 | handler 内**只做策略判定**：查已签策略能自决就自决，判不了就 fail-closed | 人不在飞行中；等于回到「事前授权」 |
| 乙 | 预置人类决定（会话开始前把这一轮可能的审批点批完） | 只对可枚举的审批点成立 |
| 丙 | ⚠ **自建 adapter，拆开 reader 与 request handler**：reader 只分发到 in-flight 请求表，另一个线程/任务负责回复 | 要自己实现协议，但**这是唯一能做到「人在飞行中」的形状** |
| 丁 | 每个审批点单开一个 turn | 语义变了：不再是「同一次执行」 |

⚠ **`async_client` 救不了**：它是 `_call_sync` 把同步客户端包进 worker thread
（`async_client.py:68-74`），**reader 线程的约束原封不动**。
`agent-dev-guide.md` §2.10「不得由 `async` 关键字推断安全」，机制就在这里。

⚠ **倾向丙**，理由：guide §2.8 已立「Port 存在的第一理由是可测性」，
而丙是唯一能让 `FakeAgentWorker` 跑通「审批往返」路径的形状；甲乙都把人挪出了飞行中。
**但这意味着放弃 Python SDK，自己讲协议。**这笔账要在该轮显式裁。

---

## 5. `ReviewDecision` 不是布尔——**三个值带载荷**

来源：`codex-rs/protocol/src/protocol.rs:4001-4050`。

```
1 Approved
2 ApprovedExecpolicyAmendment { proposed_execpolicy_amendment }   ← 带载荷
3 ApprovedForSession                                              ← 改变会话状态
4 ApprovedMcpPolicyAmendment
5 NetworkPolicyAmendment
6 Denied { rejection: String }                                    ← 带理由
7 TimedOut
8 Abort
```

⚠ **第 2、4、5 是「批准 + 顺带改策略」**，按权力表那不是 H2 放行，**是 H4 扩权**；
`ApprovedForSession` 把单次批准变成**会话级默认**。

**开发含义**：adapter **不得**把 decision 折成 `bool`。
⚠ **每个带载荷的 decision 必须落账为一次策略变更事件**，否则「谁在什么时候放宽了策略」
在账本上消失。这与 guide §4.7「超时是独立 reason code，不折成 `auto-deny`」同源——
**那条管拒绝侧，这条管批准侧。**

---

## 6. 审批载荷的字段：**判定用一个，落账用另一个**

```rust
// codex-rs/app-server-protocol/src/protocol/v1.rs:160-171
pub struct ExecCommandApprovalParams {
    pub conversation_id: ThreadId,
    pub call_id: String,          // 与 ExecCommandBegin/End 事件关联
    pub approval_id: Option<String>,
    pub command: Vec<String>,     // ⚠ 数组，不经 shell
    pub cwd: PathBuf,
    pub reason: Option<String>,
    pub parsed_cmd: Vec<ParsedCommand>,
}
```

⚠ **`command` 与 `parsed_cmd` 两个都给，用途不同：**

- **判定用 `parsed_cmd`**——用裸 argv 判会漏语义（`rm -rf` 藏在 `sh -c` 里）；
- **落账存 `command`**——存 `parsed_cmd` 就丢了真实执行的东西。

⚠ **`approval_id` 是 `Option`**：拿它当幂等键前必须处理 `None`。
`call_id` 才是与执行事件关联的那个。

---

## 7. 由此得出：`AgentExecutorPort` 现在的签名**缺一个方向**

guide §2.8 现有签名只有两个方向：我方发起（`start`/`resume`/`cancel`）与读事件流（`events`）。
⚠ **没有「对端向我发起请求并等我回」。**必须补：

```python
async def serve_requests(
    self, binding: ExecutionBinding,
    handler: Callable[[ServerRequest], Awaitable[ServerResponse]],
) -> None: ...
```

**配三条硬约束：**

1. ⚠ handler **必须覆盖全部九种请求**；未覆盖的**显式 fail-closed**，
   **不得**像 SDK 那样返回 `{}`；
2. ⚠ handler **不得阻塞事件循环**——实现按 §4 的丙：in-flight 请求表 + 独立回复通道；
3. ⚠ decision **不折成 bool**，带载荷的三种各自落账为策略变更事件。

### ⚠ 这三条对 Harness 腿**全部不适用**

Harness 的 server→client「是死能力」。所以 `serve_requests` 在 Harness 腿上是
**`explicit_unsupported`，不是 `implicit_fallback`**——⚠ **不能用进程级补法凑，
因为根本收不到请求。**

`agent-dev-guide.md` §5.6 的双腿矩阵在 `F-EXEC-03` 行只写了结论，
**没写 Port 该长什么样**。该轮应补。

---

## 8. ACP 与 A2A：两个**不同层**的协议，别并列

⚠ **本节证据来源分级，逐条标注**：ACP 的报文形状来自 `~/repo/deepseek-harness/snapshots/acp/`
的**真实期望输出**（可复跑）；A2A 来自 `~/repo/openclaw/docs/channels/a2a.md`（**文档，未实跑**）。

### 8.1 ACP —— 宿主调 harness，与 app-server **同层**

**Agent Client Protocol**（`agentclientprotocol.com`）。用途见
`openclaw/docs/tools/acp-agents.md:1-18`：让宿主跑**外部 coding harness**
（Claude Code、Cursor、Copilot、Gemini CLI、Codex ACP、OpenCode……）。

**真实握手**（`snapshots/acp/handshake/stdout.expected.jsonl`）：

```json
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,
 "agentInfo":{"name":"deepseek-harness-acp","version":"0.0.1"},"agentCapabilities":{…}}}
{"jsonrpc":"2.0","id":2,"result":{"sessionId":"…","configOptions":[…]}}
```

⚠ **第一处可判差别：ACP 带 `"jsonrpc":"2.0"`，codex app-server 不带**（见 §2）。
写解析器时**两者不能共用同一个库配置**。

**审批往返是真的**（`snapshots/acp/escalation-approved/`、`escalation-rejected/`）：

```json
{"jsonrpc":"2.0","id":1,"method":"session/request_permission",
 "params":{"sessionId":"…","toolCall":{"toolCallId":"call_00_…"},
           "options":[{"optionId":"allow-once","name":"Allow once","kind":…}]}}
```

⚠ **第二处差别，而且是设计层的**：

| | codex app-server | ACP |
| --- | --- | --- |
| 审批选项 | **协议固定枚举** `ReviewDecision` 八值（§5） | ⚠ **agent 在请求里自带 `options[]`** |
| 客户端怎么答 | 从八值里挑一个 | 回一个 `optionId` |
| 后果 | 客户端可以**预先**为八值各写一条策略 | ⚠ **选项在运行时才知道**——策略不能预编译，只能按 `optionId` 字符串匹配或转人 |

**事件流**用 `session/update` 通知，靠 `sessionUpdate` 判别：
`agent_thought_chunk` / `tool_call` / `tool_call_update` / `agent_message_chunk`；
`toolCallId` 把权限请求与工具调用关联（对应 codex 的 `call_id`）。

### 8.2 ⚠⚠ 由此更正 guide 的一处结论：**「Harness 没有 HITL」的适用范围被写宽了**

`agent-dev-guide.md` §2.7「交互批准」行与 §5.6 `F-EXEC-03` 行，
依据是 `packages/sdk/protocol/README.md:116`：

> Server→client requests are a dead capability — the transport supports them,
> but the server never sends one.

**这句话本身没错，但它说的是 `packages/sdk/protocol` 这一个面。**实测同一个仓有**三个面**：

| 面 | 位置 | server→client 请求 |
| --- | --- | --- |
| Python SDK wire | `packages/sdk/protocol/` | ⚠ **死能力**（README 自述） |
| **ACP 服务端** | 握手自报 `agentInfo.name = "deepseek-harness-acp"` | ⚠ **可用**：`session/request_permission`，**有快照测试** |
| ACP 客户端 | `packages/subagent/subagent-acp/`（out-of-process ACP subagent backend） | 它是**调用方** |

⚠ **所以正确表述是**：「**Harness 的 Python SDK wire 上没有 server→client 请求**」，
**不是**「Harness 不得声称原生 HITL」。**后者把包级约束写成了产品级结论。**
——这正是 §2.7 表格里那条限定纪律（「本表结论固定在核对提交」）在**范围维度**上的同类失误。

⚠ **未核**：harness 的 ACP 服务端**怎么起**（哪条命令）没查到；
`_default_launch_args`（`python/sdk/client.py:458`）起的是 SDK runtime，**不是 ACP**。
**在查清之前，不得据本节声称「走 ACP 就能拿到 Harness 的 HITL」。**

### 8.3 A2A —— **不同层**：agent 之间，跨进程跨主机跨信任域

**Agent2Agent**（Linux Foundation，`a2a-protocol.org`）。
依据 `openclaw/docs/channels/a2a.md`（⚠ **文档，未实跑**）：

> 外部 agent 通过 **public Agent Card** 发现网关，用 **A2A 1.0 JSON-RPC binding**
> 提交**经认证的**文本任务；OpenClaw 也能向配置好的 peer 发消息。
> 配置：`advertisedUrl` + **每个 peer 一个 bearer token**。

⚠⚠ **A2A 与前三者不是同一层，把它们并列是错的**：

| | app-server / ACP | **A2A** |
| --- | --- | --- |
| 传输 | **stdio 管道** | ⚠ **HTTP(S)** |
| 进程关系 | **父子**（调用方 `spawn` 它） | ⚠ **无进程关系**——两个独立服务 |
| 谁拥有对方的生命周期 | 调用方 | ⚠ **谁也不拥有** |
| 发现 | 路径已知（二进制在哪） | ⚠ **Agent Card**（网络发现） |
| 认证 | **无**——同机同用户，共享凭据域 | ⚠ **per-peer bearer token** |
| 信任域 | **同一个** | ⚠ **不同** |

### 8.4 由此得到的分层，和它对本项目的直接后果

```
第一层  进程内：agent loop 自己
第二层  同机父子进程 + stdio：app-server / ACP        ← 我们现在全部的实测都在这层
第三层  跨主机 + HTTP + token：A2A                     ← 一次都没碰过
```

⚠ **`F-3` 说「本项目全部证据落在三维空间的一个点上」，本节把其中一维说细了**：
「执行侧：用户侧 → provider 侧」这个迁移，**协议形态上就是从第二层走到第三层**。

**三条直接后果：**

1. **凭据边界的位置变了。**第二层里凭据边界 = 进程边界，而同机同用户**根本没有边界**
   （guide §4.4：本机一切本地判定都不是边界）。第三层里边界是 **token + 网络**——
   ⚠ **A2A 是第一个天然跨信任域的形态**，也就是第一个能让 §4.4 那条
   「强制点必须落在 executor 够不着的地方」**物理上成立**的形态。
2. **`AgentExecutorPort` 的 `serve_requests`（§7）只覆盖第二层。**第三层里
   「对端向我发请求」是一个 **HTTP inbound**，不是管道上的一条 JSON——
   ⚠ **同一个 Port 抽象能不能罩住两层，本文答不了，该轮要裁。**
3. **`ExecutionBinding` 的含义也变了。**第二层里它至少要能定位一个进程；
   第三层里没有进程，只有 **peer id + task id**。
   guide §2.8 写「`ExecutionBinding` 必须可序列化并落 PostgreSQL，SDK 侧的
   thread/session id 不是 Task 的真源」——⚠ **那句话在第三层反而更成立**，
   因为压根没有本地进程可依赖。

### 8.5 ⚠ 本节没查的（不得当已知）

| # | 没查 |
| --- | --- |
| 1 | A2A 有没有 server→client 请求（即**对端能不能向我要审批**）——⚠ 这决定它能不能做 HITL |
| 2 | ACP 的方法全集（只见到 `session/request_permission`、`session/update` 与两条握手响应） |
| 3 | harness 的 ACP 服务端**启动命令** |
| 4 | ACP 的 `options[].kind` 有哪些取值 |
| 5 | A2A 的任务生命周期（提交后怎么查、怎么取消） |
| 6 | ⚠ **本节 A2A 部分全部来自文档，一次报文都没见过** |

---

## 9. 同一个 codex，**七个接入面**——选哪个决定能力，不是决定风格

⚠ **本节全部来自 `codex --help` 与仓内源码（钉版 `7d6f808b`），未实跑。**

### 9.1 面的清单

`codex --help` 的子命令里，与「被程序驱动」相关的有这些：

| 面 | 起法 | 协议 / 输出 | server→client 请求 |
| --- | --- | --- | --- |
| **交互 TUI** | `codex` | 终端文本 on pts | 有（**问的是人**） |
| **一次性** | `codex exec` | 人读文本 | ⚠ **无** |
| **一次性 + 结构化** | `codex exec --experimental-json` | JSONL 事件流 | ⚠ **无**（单向） |
| **app-server** | `codex app-server --listen stdio://` | JSON-RPC（**无 `jsonrpc` 字段**） | ⚠ **九种**（§3） |
| **MCP 服务端** | `codex mcp-server` | MCP over stdio | 按 MCP 语义 |
| **MCP 客户端** | `codex mcp add/list/…` | 它去调别人 | — |
| **插件** | `codex plugin add/list/…` | 进程内扩展（§9.3） | — |

另有 `exec-server`、`remote-control`、`agents`（共享的本地 app-server daemon）、`review`、
`sandbox`、`apply`、`resume` / `fork` / `queue` —— ⚠ **均未查**。

### 9.2 ⚠⚠ 两个官方 SDK 走的是**两个不同的面**

```
Python SDK     → codex app-server --listen stdio://    （client.py:252）
TypeScript SDK → codex exec --experimental-json        （sdk/typescript/src/exec.ts:92）
```

复核：`rg 'app-server' sdk/typescript/src/` **零命中**；`rg '"exec"' sdk/python/src/` **零命中**。
**两条路互不相交。**

| | Python SDK | TypeScript SDK |
| --- | --- | --- |
| 子命令 | `app-server` | `exec --experimental-json` |
| 线路 | JSON-RPC，**双向** | JSONL 事件流，**单向** |
| 能收审批请求吗 | ⚠ **能**（九种） | ⚠ **不能** |
| 能拦工具调用吗 | 能（`DynamicToolCall`） | 不能 |
| 体量 | 72 个 `.py` | 24 个 `.ts` |

⚠⚠ **所以「走 SDK 就能接审批」这句话对 Python 成立、对 TypeScript 不成立。**
两个都是官方 SDK，同一个产品，**能力不同**。

⚠ **这与 `findings.md` F-4 是同一个形状的第二个实例**：
F-4 是「Harness 没有 HITL」把包级约束写成产品级结论；
本条是「SDK 有审批」把**某一个 SDK** 的能力写成 **SDK 这个类别**的能力。
**通则应当是：凡「某执行者支持/不支持 X」，必须写明是在哪个接入面上。**

⚠ **对本项目的直接后果**：`agent-dev-guide.md` §2.7「交互批准」行的 Codex 侧写
「可由 approval handler 接请求」——**该行未指明是哪个 SDK / 哪个子命令**。
若将来有人按 TypeScript SDK 实施，会发现接不到，而文档看起来是支持的。

### 9.3 插件：**进程内**的第三条拦截路径

`codex plugin` 管的是**插件市场**（`add` / `list` / `marketplace` / `remove`）。
插件装的内容，从 `app-server-protocol/src/protocol/v2/plugin.rs` 看是两类：
**skills** 与 **hooks**（该文件里有 `SkillsList*`、`HooksList*`、`Marketplace*`、`Plugin*`）。

**Hook 的事件全集**（`app-server-protocol/src/protocol/v2/hook.rs:19-21`）：

```
PreToolUse, PermissionRequest, PostToolUse,
PreCompact, PostCompact,
SessionStart, SessionEnd, UserPromptSubmit,
SubagentStart, SubagentStop, Stop, Interrupt
```

**Handler 类型**（同文件 `:25-27`）：`Command` / `McpTool` / `Prompt` / `Agent`
**执行模式**（`:31-35`）：`Sync` / `Async`

⚠ **Hook 能否决**（`codex-rs/hooks/src/types.rs:15-31`）：

```rust
pub enum HookResult {
    Success,
    FailedContinue(..),   // 本 hook 失败，后续 hook 继续，操作继续
    FailedAbort(..),      // 后续 hook 不执行，⚠ 操作中止
}
impl HookResult { pub fn should_abort_operation(&self) -> bool { … } }
```

⚠⚠ **于是拦截审批有三条路，不是一条：**

| 路径 | 位置 | 能拦吗 | 谁能改配置 |
| --- | --- | --- | --- |
| `--permission-mode` / `-s` | 启动参数 | **事前授权**，不是拦截 | 调用方 |
| **hook `PreToolUse` / `PermissionRequest`** | ⚠ **进程内** | ⚠ **能**（`FailedAbort`） | ⚠ **本机配置** |
| app-server 的九种 server→client 请求 | ⚠ **进程外**，管道对端 | 能 | 调用方（在管道另一头） |

⚠ **第二条与第三条的安全性质完全不同**，这一点必须写清楚：

- **hook 在同一个进程、配置在本机**——而 guide §4.4 已立
  「**本机一切本地判定都不是边界**」（`sudo -n -l` = `NOPASSWD: ALL`）。
  ⚠ **agent 与人同用户时，agent 能改 hook 配置。**
  所以 hook 给的是**可观测与协作式拦截**，**不是对抗性强制点**；
- **app-server 的请求在管道另一头**——⚠ 若那一头是**另一个信任域的进程**（F-3 的 provider 侧），
  它才构成 guide §4.4 要求的「executor 够不着」的强制点。

⚠ **`PreToolUse` + `FailedAbort` 是 `tool.enforced` 的必要条件，不是充分条件。**
`agent-dev-guide.md` §5.1 说「只有 `tool.enforced` 的事件是证据」；
本节表明**拦截点存在**（hook），但**它在 agent 可写面上**——
按 §5.2「采信等级取 `min(…)`，任一未知即降级」，**这样的拦截只能记 `tool.reported`**。

### 9.4 选型结论（**倾向，非裁定**）

| 我们要什么 | 该走哪个面 | 为什么 |
| --- | --- | --- |
| 结构化事件流，不要审批 | `exec --experimental-json` 或 TypeScript SDK | 最简单，单向 |
| **审批往返 + 工具网关** | ⚠ **`app-server`**（Python SDK 或自建协议） | 唯一有九种 server→client 请求的面 |
| 协作式的本地拦截与观测 | **hook** | 便宜，但**不是边界**（§9.3） |
| 让别的 agent 调我们 | `mcp-server` / A2A（§8.3） | 未查 |

⚠ **§4 的结论不变**：即使选了 `app-server`，Python SDK 的 reader 线程约束仍在，
倾向仍是**自建协议**。**选面与选实现是两件事。**

---

## 10. CLI / SDK / 插件的机制差别：**拦截点在哪**

⚠ **这是本文的核心一节。**前九节都在描述「有哪些面」，本节答「**它们的机制到底哪里不同**」。

### 10.1 先否掉一个直觉答案

直觉答案是「**你的代码跑在 harness 进程外面还是里面**」。**不准确**——
codex 的 hook handler 有四型（`hook.rs:25-27`）：

```
Command | McpTool | Prompt | Agent
```

`Command` 型**是起子进程的**，`McpTool` 可能打到另一个进程，`Agent` 甚至是另一个 agent。
**所以插件的处理器完全可以在 harness 进程之外。**

### 10.2 准确的差别：**拦截点的位置**

| | **拦截点在哪** | 处理器可以在哪 | 能拦到什么 |
| --- | --- | --- | --- |
| **CLI** | ⚠ **只有进程边界的两端**：启动（argv）与退出（exit code） | 调用方进程 | ⚠ **几乎什么都拦不到**——中间发生的事一件也看不见 |
| **SDK** | ⚠ **进程边界上的消息**（管道上的 JSON） | 调用方进程 | ⚠ **只能拦协议明确暴露的点**——协议没写的，边界上就不会出现 |
| **插件 / hook** | ⚠⚠ **agent 执行流的内部** | 进程内、子进程、MCP、甚至另一个 agent | ⚠ **协议没暴露的点也能拦**——因为它不受协议边界约束 |

**一句话**：

> **CLI 和 SDK 是在边界上等；插件是在流水线上站。**
> 边界上只能等到「被设计成要穿过边界」的东西；流水线上站着，凡是流过的都能碰。

### 10.3 硬证据：两个面暴露的点**几乎不重叠**

同一个 codex，两个扩展面：

| app-server 的 server→client 请求（九种） | hook 事件（十二种） |
| --- | --- |
| `CommandExecutionRequestApproval` | `PreToolUse` |
| `FileChangeRequestApproval` | **`PermissionRequest`** |
| `ToolRequestUserInput` | `PostToolUse` |
| `McpServerElicitationRequest` | `PreCompact` / `PostCompact` |
| **`PermissionsRequestApproval`** | `SessionStart` / `SessionEnd` |
| `DynamicToolCall` | `UserPromptSubmit` |
| `ChatgptAuthTokensRefresh` | `SubagentStart` / `SubagentStop` |
| `AttestationGenerate` | `Stop` / `Interrupt` |
| `CurrentTimeRead` | |

⚠⚠ **交集只有「审批」一项**（`PermissionRequest` ↔ `*RequestApproval`），**其余全部不重叠**。

**这不是巧合，是两种拦截点位置的必然结果：**

- app-server 那九种，形式都是「**我需要你替我做一件事**」——
  决定（审批）、执行（`DynamicToolCall`）、提供（时间、attestation、token）。
  ⚠ **它们必须穿过边界，因为 harness 自己做不了。**
- hook 那十二种，形式都是「**执行流到了这个点**」——
  工具前后、压缩前后、会话起止、子 agent 起止、停止、中断。
  ⚠ **它们本来完全不需要穿过边界**，harness 自己就能继续；
  **暴露它们纯粹是为了让人插进去。**

**所以 `PostToolUse` 不可能出现在 app-server 的请求列表里**——
工具跑完了，harness 不需要任何人帮忙，它只是**允许**你在那里插一脚。
反过来 `DynamicToolCall` 不可能是 hook——那是真的需要外面的人干活。

### 10.4 由此推出三条，每条都有工程后果

**① 控制反转的方向相反**

```
CLI / SDK:   你的代码  ──调用──►  harness        （你是主，它是从）
插件:        harness  ──回调──►  你的代码        （它是主，你是从）
```

⚠ **这是「库」与「框架」的经典分野。**后果：SDK 的错误你能捕获并决定下一步；
插件里抛出的错误由 **harness 决定**怎么处理——codex 给的三值是
`Success` / `FailedContinue`（继续）/ `FailedAbort`（中止），
**你只能在这三种里选，不能自定义恢复策略。**

**② 能拦到的点决定了「能不能做某个纪律」，而不是「做得漂不漂亮」**

`agent-dev-guide.md` §5.1 要 `tool.enforced`，判据是「每一次工具调用，且调用先经运行时批准」。
- **CLI**：办不到——看不见工具调用；
- **SDK**：⚠ **只能靠 `DynamicToolCall`**，而那要求 harness **主动把工具执行交出来**；
- **插件**：`PreToolUse` + `FailedAbort` 直接就是这个语义。

⚠ **但插件那条有个致命限定**（§9.3）：hook 配置在**本机**，
而 guide §4.4 已立「本机一切本地判定都不是边界」。
**agent 与人同用户时，agent 能改 hook 配置。**

**③ 版本耦合强度递增，而这决定维护成本**

| | 耦合到什么 | 换版本时最容易断的 |
| --- | --- | --- |
| CLI | 命令行参数 + 输出格式 | 参数改名、输出格式变 |
| SDK | 协议版本 | 消息形状变（有 `protocolVersion` 可协商） |
| **插件** | ⚠ **harness 的内部扩展点** | ⚠ **事件名/时机/语义变，而这些通常不进版本协商** |

### 10.5 ⚠⚠ 对本项目最要紧的一条推论

我们有两个需求，**它们分落边界两侧，不可能用同一个机制满足**：

| 需求 | 属于 | 该用 |
| --- | --- | --- |
| **业务控制面**：Task / Attempt / 四本账 / 验收 / 授权 | ⚠ **harness 之外**——它不该知道这些 | **SDK**（从外面驱动） |
| **`tool.enforced`**：每次工具调用先经批准 | ⚠ **harness 之内**——要改它的执行行为 | **插件**（在流水线上站） |

⚠ `agent-dev-guide.md` §2.6 立的「**租用 loop，自建业务控制面**」**只覆盖了第一行**。
第二行是**改变 harness 的行为**，而**租用不改变行为**。

**由此得到一条判据**（建议入 guide）：

> ⚠ **CLI 与 SDK 都不能改变 harness 的行为，只能驱动它。要改变行为，必须进到它的执行流里。**

**再叠上 `F-3` 的执行侧轴，才是完整答案：**

| | 用户侧（agent 与我们同凭据域） | provider 侧（进程由我们拥有） |
| --- | --- | --- |
| **SDK 驱动** | ✓ 可行，这是现状 | ✓ 可行 |
| **插件拦截** | ⚠ **协作式**——agent 能改配置，只能记 `tool.reported` | ⚠⚠ **真正的 `tool.enforced`**——配置在 agent 够不着的地方 |

⚠ **所以 `tool.enforced` 需要两件事同时成立：插件（拿到拦截点）+ provider 侧（拿到配置的所有权）。**
少任何一件都不够——这比 §5.1 现在写的「那是 SDK 腿建成之后才会出现的取值」精确得多，
**也说明那句归因是错的**（已记 `findings.md` F-3 落点建议第 2 条）。

---

## 11. 未解决 / 下次接着看

| # | 问题 | 为什么现在答不了 |
| --- | --- | --- |
| 1 | 丙形状（自建协议）的实际工作量 | 没数过 app-server 协议的消息种类总数 |
| 2 | `turn/start` 之后，审批往返是否真在**同一 turn** 内闭合 | **未实跑**；`spike-codex.md` 也只到接口形状 |
| 3 | `DynamicToolCall` 的实际语义与调用约定 | 只看到 params 类型名，未读定义 |
| 4 | Harness 腿有没有等价的「客户端执行工具」通道 | 未查 |
| 5 | 三条 pipe 里 **stderr** 那条怎么用（`_start_stderr_drain_thread`） | 只知道有个 drain 线程和 40 行 tail |
| 6 | 进程 teardown 梯子在两条腿上的差异 | guide §2.10 记了 Harness 侧 `close→terminate→kill` 的锚点，Codex 侧只说「进程组 TERM/KILL」 |
| 7 | ⚠ **本文全部内容未实跑** | 见文首 |
| 8 | `exec-server` / `remote-control` / `agents`（共享 daemon）三个面是什么 | 只见到 `--help` 一行 |
| 9 | `codex mcp-server` 的 MCP 面能不能收审批 | 未查；MCP 有 elicitation，但没核 codex 侧实现 |
| 10 | 插件的清单格式（怎么写一个插件） | 只看到市场管理命令与协议侧的 `Plugin*` 类型，**没看到 manifest 定义** |
| 11 | hook 的 `Agent` handler 类型是什么语义 | ⚠ 一个 hook 的处理器可以是**另一个 agent**——这可能是个递归面，没查 |
| 12 | hook 配置放在哪、谁能写 | ⚠ 直接决定 §9.3 那条「agent 能改 hook 配置」是否成立——**目前是推断，不是取证** |
| 13 | TypeScript SDK 走 `exec` 是设计选择还是尚未跟进 | 若是后者，本文 §9.2 的结论会随版本失效 |
