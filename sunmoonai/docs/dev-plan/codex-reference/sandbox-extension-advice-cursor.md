# 沙箱：investment-app 该做到哪（Cursor 版）

> 最后更新：2026-09-02
>
> 性质：个人决策底稿，非 baseline、非 REQ。
> 总稿已经写过：任意代码走 Docker，问数走受管 SQL，两条威胁模型分开。
> 本文只补「Port 现状、从 Codex 借哪一档、第一版做成什么样」。
>
> 取证：`worktrees/cursor/investment-app` 的 sandbox 三件套；
> Codex `/home/zym/repo/codex` @ `7d6f808b97` 的 `SandboxPolicy`。

## 结论

**该做。第一版就是总稿里的 Host：一 Run（或一用户）一个 Docker，跑完销毁。**
不要为了「像 Codex」去上 Landlock / seccomp / 三套平台实现。

`SandboxAction` 已经包含 `shell` 和 `python`。这不是「研究 agent 不执行代码」，
而是「执行代码的口子已经设计了，只是没接上」。假实现继续留给测试；生产
调用方今天仍是零。

排在 `RunBudget` 接线之后。没有闸门先开耗资源出口，是倒着建。

## 1. 现状（今日复核）

| 项 | 位置 | 状态 |
| --- | --- | --- |
| `SandboxAction`：shell / python / file_read / file_write | `domain/agent/sandbox.py:9` | 已定义 |
| `SandboxRequest`：timeout 1–300，默认 30 | 同上 `:16` | **没有网络维度** |
| `SandboxResult`：exit_code / stdout / stderr / artifact_ids | 同上 `:26` | 只有引用，没有字节 |
| `SandboxPort.run` | 同上 `:39` | 一次性执行 |
| 唯一实现 | `infrastructure/agent/fake_sandbox.py` | `DeterministicFakeSandbox`，返回 `fake-shell:…` |
| 测试 | `tests/test_agent_sandbox_port.py` | `rm -rf /` 不真跑 |
| 生产调用方 | `tasks/`、`application/` | **零** |

```bash
cd worktrees/cursor/investment-app/investment-backend/app
rg -ln "SandboxPort|SandboxRequest" app tests
# 应只有 domain 定义、fake 实现、测试
```

方向对：Port 在 domain，实现在 infra，权限在 `AgentProfile` 的工具黑白名单。
接口瘦，从未被真流量顶过。第一版不要先扩 Port。

## 2. Codex 只借一档、一个正交轴

`codex-rs/protocol/src/protocol.rs` 的 `SandboxPolicy`：

| 档 | 含义 | 我们用不用 |
| --- | --- | --- |
| `DangerFullAccess` | 不隔离 | 不用 |
| `ReadOnly { network_access }` | 只读，网络另开 | 对照用 |
| `WorkspaceWrite { writable_roots, network_access, … }` | 列出可写根 | 桌面进程才需要；容器里没「用户全家目录」要保护 |
| `ExternalSandbox { network_access }` | **隔离已由外部承担** | **对上我们** |

Codex 是桌面进程，必须自己划内核边界。investment-app 跑在 k8s / compose，
**Pod / 容器就是隔离单元**。再套一层 Landlock 是重复建设。对应档位就是
`ExternalSandbox`：承认「隔离不由自己做」。

真正该抄的是：**网络与写盘正交**。三档都单独带 `network_access`。最常见的
研究场景是「能跑 Python，不许出网」——今天的 `SandboxRequest` 表达不了，
容器只会全通或全断。

接线前给 Request 加网络策略字段（默认拒绝出网）。比事后改 Port 便宜。
第一份实现 REQ 仍可以不改 `run()` 签名，先把策略放进 `metadata`，正式字段
留给第二份 REQ。

## 3. 第一版做成什么样

总稿 §4 已经定了 Host 只有 Docker。沙箱不是另一套执行栈，就是那个 Host
上的 `run()`。

| 层 | 做什么 | 不做什么 |
| --- | --- | --- |
| 测试 | 继续 Fake | 不要让 CI 真执行 |
| 本机开发 | 允许 `LocalSandbox`（subprocess），feature flag，**禁入生产** | worker 里有 DB/Redis 凭据，LLM 代码能读到就泄露 |
| 第一真实实现 | Docker：非 root、cap-drop ALL、只读 rootfs + `/workspace` tmpfs、CPU/内存/pids 限额、随 Run 销毁 | 不把 `docker.sock` 挂进业务 worker |
| 生产形态 | 一次性 Job / 短生命周期 Pod，镜像 digest 钉死，无凭据，跑完删 | 不为「通用工具框架」合并 `ToolExecutionPort` |

产物只回 `artifact_ids`。字节进对象存储——`FORBIDDEN_ARTIFACT_KEYS` 已经
禁止 body 进 graph state。没有存储后端，第一个真实现会卡在「文件没地方放」。

每次 exec 记副作用账：命令、退出码、预算、网络策略。沙箱是不可回滚的外部
动作，和问数执行同一条证据纪律。

`ToolExecutionPort` 是「能调什么」，`SandboxPort` 是「在哪儿跑」。现有分离
是对的，不要为了「好实现」并成一个大接口。

## 4. 以后才要的（现在不写进第一份 REQ）

长进程会话、stdin、浏览器 CDP、流式输出、gVisor `runtimeClassName`——等
Docker 适配器被真调用顶出来再开第二份 REQ。预留字段可以有，预承诺接口不行。

kind 上可以提前演练「同镜像切 RuntimeClass」，成本半天；不演练也不阻塞
第一版。

## 5. 边界

- 未读 Codex Landlock / seccomp 实现细节，只读了 `SandboxPolicy` 类型
- 未连集群验证 Job 配额与 NetworkPolicy
- `SandboxAction` 含 python/shell 是从动作集反推设计意图，仓里没有单独 ADR
