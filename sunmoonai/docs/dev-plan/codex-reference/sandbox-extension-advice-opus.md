# 沙箱：investment-app 该不该做、做到什么程度

> 取证时点：2026-08-28 ｜ 作者：opus
> 源码：`/home/zym/repo/codex` @ `7d6f808b97`（main，最新）与
> `/home/zym/worktrees/opus/investment-app`

## 0. 先更正我自己的一个判断

我在 [`codex-mechanisms-for-investment-agent-opus.md`](codex-mechanisms-for-investment-agent-opus.md)
§5 写过：

> 沙箱**不迁**——Codex 是编码 agent（执行任意代码），investment-app 是研究 agent
> （不执行代码），风险面根本不同。

**这个判断基于不完整的信息，现更正。**investment-app 里有一个已定义的
`SandboxPort`，它的动作集**明确包含执行代码**：

```python
class SandboxAction(StrEnum):
    shell = "shell"          # ← 执行 shell
    python = "python"        # ← 执行 Python
    file_read = "file_read"
    file_write = "file_write"
```

`app/domain/agent/sandbox.py`。所以"investment-app 不执行代码"是**现状**，
不是**设计意图**——设计意图恰恰相反。

正确的说法是：**沙箱这件事在 investment-app 里已经被设计过，但只落到了 Port 层。**

## 1. 现状：一个 Port，一个假实现，零调用

| 项 | 状态 | 位置 |
| --- | --- | --- |
| `SandboxPort` 协议 | 已定义（`async def run(request) -> SandboxResult`） | `domain/agent/sandbox.py` |
| `SandboxRequest` | 已定义，含 `timeout_seconds`（1–300，默认 30） | 同上 |
| `SandboxResult` | 已定义，含 `exit_code` / `stdout` / `stderr` / `artifact_ids` | 同上 |
| **唯一实现** | `DeterministicFakeSandbox`——返回 `fake-shell:{cmd}` 一类固定字符串 | `infrastructure/agent/fake_sandbox.py` |
| **生产调用方** | **零**。`tasks/` 与 `application/` 下没有任何 sandbox 引用 | — |

这与本项目已登记的其他休眠项同构（`RunBudget`、`AgentMemoryService`、`CancelRunCommand`），
**但它没有被登记**——`architecture/repos/investment-app.md` §7 的清单里没有它。
本文视为一条新发现，应补入。

```bash
cd investment-app/investment-backend/app
cat app/domain/agent/sandbox.py
grep -rln "SandboxPort\|SandboxRequest" app/          # 应只有 2 个文件
grep -rn "sandbox" app/tasks/ app/application/        # 应为空
```

## 2. Codex 的沙箱：四档策略，三套实现

`SandboxPolicy`（`protocol/src/protocol.rs`）：

| 档位 | 含义 |
| --- | --- |
| `DangerFullAccess` | 不隔离 |
| `ReadOnly { network_access }` | 只读，网络单独开关 |
| `WorkspaceWrite { writable_roots, network_access, exclude_tmpdir_env_var, exclude_slash_tmp }` | 只有列出的根可写 |
| `ExternalSandbox { network_access }` | 隔离交给外部承担 |

实现三套：`linux-sandbox`（Landlock + seccomp，内核级）、
`windows-sandbox-rs`（token / AppContainer）、`sandboxing`（公共层）。
另有 `network-proxy` crate（1.7 万行）单独管网络策略。

**两个设计决定值得注意**：

1. **网络是独立维度**，不是"沙箱等级"的附属。三档里每一档都单带 `network_access`——
   因为"能不能写文件"和"能不能出网"是正交的风险。
2. **`ExternalSandbox` 是一等档位**——承认"隔离可以不由自己做"。
   这一档对 investment-app 直接有用：**在 k8s 上，隔离本来就该由 Pod / 容器承担。**

## 3. 判断：该做，但不该照 Codex 的做法做

### 3.1 为什么该做

`SandboxAction` 里有 `shell` 与 `python`。只要这两个动作最终会被接上，
就必然需要隔离——研究 agent 跑 Python 做数据分析是很自然的需求
（这大概率就是当初设计它的动机）。

而且 investment-app 的**输入面比 Codex 更脏**：它的证据来自
knowledge 检索（上游是 info 采集的**外部网页**）。
Codex 的输入主要是用户自己的代码库。**读不可信内容 + 执行代码**是最需要隔离的组合。

### 3.2 为什么不该照抄

| Codex 的做法 | 为什么不适用 |
| --- | --- |
| Landlock + seccomp 内核级隔离 | Codex 是**桌面进程**，必须在用户机器上自己划边界。investment-app 跑在 **k8s**，Pod 本身就是隔离单元——再套一层内核沙箱是重复建设 |
| 三套平台实现（Linux/Windows/公共层） | 只需要 Linux 容器一种 |
| `WorkspaceWrite` 的可写根列表 | Codex 要保护用户的整个文件系统；investment-app 的容器里本来就没有需要保护的东西 |

**对应的正确档位是 `ExternalSandbox`**——Codex 自己也承认这一档存在。
investment-app 的实现应该是：**一次性 Job / 短生命周期 Pod，跑完即销毁**。
这与本项目已有的迁移 Job 模式（`10-migration.yaml`，跑完即删）是同一形态，
运维上没有新东西。

### 3.3 该抄的那一条

**网络作为独立维度**。这条与平台无关，纯粹是风险建模上的对错：

```python
class SandboxRequest(BaseModel):
    action: SandboxAction
    # 现状：没有网络维度
```

现有 `SandboxRequest` 没有网络字段。若照现状实现，容器要么全通、要么全断，
而实际需求是"能跑 Python 分析，但不许出网"——**这正是最常见的一档**。
建议在接线前先给 `SandboxRequest` 补一个网络策略字段，
比事后改 Port 契约便宜得多。

## 4. 建议的落地形态

| 层 | 做什么 | 依据 |
| --- | --- | --- |
| Port | 保持 `SandboxPort` 不变，**补网络维度** | §3.3 |
| 实现 | 一次性 Pod / Job，镜像固定、无凭据、跑完销毁 | 与 `10-migration.yaml` 同形态 |
| 网络 | 默认断网；需要出网时走已有的 allowlist 机制（investment-app 的出站只有 knowledge 与 LLM 两个已知端点） | `topics/identity.md` §4.3 |
| 资源 | 必须有超时（Port 已有 `timeout_seconds` 1–300）+ CPU/内存限额 | 现有字段够用 |
| 账 | **每次沙箱执行须记副作用账**——它是不可回滚的外部动作 | `request-lifecycle.md` §7 |

**顺序上它排在预算之后**：沙箱执行是有成本的动作，
在 `RunBudget` 接线之前上沙箱，等于给一个没有闸门的系统再加一个耗资源的出口。

## 5. 一条不该做的

**不要为了"支持沙箱"去做通用的工具执行框架。**
`ToolExecutionPort` 与 `SandboxPort` 是两个东西：前者是"agent 能调什么"，
后者是"调用在哪儿跑"。现有代码已经把它们分开了（`domain/agent/tools.py`
与 `domain/agent/sandbox.py`），这个分离是对的，别合并。

## 6. 本文的边界

| 边界 | 说明 |
| --- | --- |
| 未读 Codex 沙箱的实现细节 | 只读了 `SandboxPolicy` 的类型定义与三个 crate 的目录，没读 Landlock/seccomp 的具体规则 |
| 未验证 k8s 侧的可行性 | "一次性 Job 跑沙箱"是形态建议，未验证现有集群配额、镜像拉取、网络策略是否支持 |
| 未连集群 | 同本项目其他文档的通病 |
| `SandboxAction` 的设计意图是推断的 | 我从动作集反推"当初打算执行代码"，没有找到写明意图的文档或 ADR |
