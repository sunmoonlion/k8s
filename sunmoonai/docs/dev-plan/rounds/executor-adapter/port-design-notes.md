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

## 8. 未解决 / 下次接着看

| # | 问题 | 为什么现在答不了 |
| --- | --- | --- |
| 1 | 丙形状（自建协议）的实际工作量 | 没数过 app-server 协议的消息种类总数 |
| 2 | `turn/start` 之后，审批往返是否真在**同一 turn** 内闭合 | **未实跑**；`spike-codex.md` 也只到接口形状 |
| 3 | `DynamicToolCall` 的实际语义与调用约定 | 只看到 params 类型名，未读定义 |
| 4 | Harness 腿有没有等价的「客户端执行工具」通道 | 未查 |
| 5 | 三条 pipe 里 **stderr** 那条怎么用（`_start_stderr_drain_thread`） | 只知道有个 drain 线程和 40 行 tail |
| 6 | 进程 teardown 梯子在两条腿上的差异 | guide §2.10 记了 Harness 侧 `close→terminate→kill` 的锚点，Codex 侧只说「进程组 TERM/KILL」 |
| 7 | ⚠ **本文全部内容未实跑** | 见文首 |
