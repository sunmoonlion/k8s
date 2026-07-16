# ADR-002：Session/Thread/Run/Attempt/Invocation 身份模型

状态：ACCEPTED

日期：2026-07-16

任务：V5-P0-002

依赖：ADR-001（Custom Runtime）

## 1. 决策

Research 执行域必须使用以下互不复用的稳定实体：

| 实体 | 含义 | 生命周期 |
|---|---|---|
| Session | 用户拥有的产品会话/工作空间容器 | 可跨多个 Thread 和 Run |
| Thread | 一张 Graph 的持久 checkpoint 状态链 | 绑定 Graph 名称和版本 |
| Run | 一次逻辑用户意图/执行 | 跨 resume/retry 保持不变 |
| RunAttempt | 一个 worker 对 Run 的一次物理领取/执行 | initial、resume、retry 都创建新 Attempt |
| AgentInvocation | 主 Agent/Subagent 的逻辑调用节点 | 在一个 Run 内形成调用树 |
| CheckpointBinding | Thread 的 checkpoint namespace/id/version 映射 | 不属于 Session、Run 或 Attempt |

任何一个 ID 不得兼任另一实体的 ID。尤其禁止：

- `session_id = thread_id`。
- worker retry 创建新 Run。
- Human-in-the-loop resume 创建新 Run。
- Subagent 默认创建新 Run。
- 用 Attempt ID 作为 checkpoint `thread_id`。

## 2. 关系与基数

```text
Session 1 ── N Thread
Session 1 ── N Run
Thread  1 ── N Run（默认串行；非终态并发由 ADR-001 reject）
Run     1 ── N RunAttempt
Run     1 ── N AgentInvocation
AgentInvocation 1 ── N child AgentInvocation
Thread  1 ── 1 latest CheckpointBinding per namespace
```

Run 必须同时保存 `session_id` 和 `thread_id`，并通过组合外键保证 Thread 属于同一
Session。不能仅靠应用代码约定归属。

## 3. Run 与 Attempt 语义

### 3.1 initial

新 Run 从 `created` 通过条件更新被一个 worker claim，创建 ordinal=1、
reason=`initial` 的 Attempt。

### 3.2 interrupt/waiting

Attempt 到达 interrupt 后：

- Attempt 变为 `waiting`。
- Run 变为 `waiting`。
- checkpoint 绑定在 Thread，记录 namespace、checkpoint ID 和 Graph version。
- 不保留活跃 worker lease。

### 3.3 resume

resume 不创建新 Run；它：

- 原子消费 resume command/token。
- 定位原 Run、Thread 和 checkpoint。
- 创建下一个 ordinal、reason=`resume` 的 Attempt。
- 使用同一 Run 和 root Invocation。

### 3.4 retry

worker/Provider 瞬时失败后，若策略允许重试：

- 失败 Attempt 保留为 `failed`。
- Run 进入 `retry_pending`。
- 新 worker 通过条件更新创建下一个 ordinal、reason=`retry` 的 Attempt。
- Run ID、Thread ID、root Invocation ID 不变。

## 4. 并发与 lease

- Run 带单调 `version`；claim、resume、retry、cancel 和 terminal update 必须使用
  `WHERE id=? AND version=? AND status IN (...)` 的条件更新。
- 同一 Run 同时最多一个 `running` Attempt，由数据库 partial unique/条件约束保证。
- 同一 Thread 默认最多一个非终态 Run；第二个 Run 的执行请求返回确定的 conflict，
  不能依赖 Redis 锁竞态后把其中一个标成 failed。
- Attempt 在生产表中必须保存 worker、lease owner/token、lease expiry、heartbeat、
  start/end checkpoint 和错误；P0 隔离 schema 只冻结身份与状态边界。
- Redis signal/lock 只能加速，不能替代 PostgreSQL claim/lease 真相。

## 5. Invocation 语义

- 每个 Run 创建一个稳定 root Invocation。
- Subagent 默认创建 child Invocation，携带：
  `run_id/root_invocation_id/parent_invocation_id/created_attempt_id/profile`。
- retry/resume 不重新创建 root Invocation。
- Invocation 的 parent/root 必须属于同一 Run，由组合外键保证。
- 只有 Subagent 需要独立排队、独立取消、独立预算或跨 Run 生命周期时，才创建 child
  Run；该扩展必须显式记录 `parent_run_id`，不能把普通调用树全部升级成 Run。

## 6. Checkpoint 映射

Checkpoint identity：

```text
(thread_id, checkpoint_ns, checkpoint_id, graph_version)
```

- Run/Attempt 只引用 start/end checkpoint ID，不拥有 checkpoint。
- waiting Run 的 resume 必须先解析 Thread 的 durable checkpoint。
- Graph 升级后，旧 waiting Run 使用 Thread 上被 pin 的旧 Graph version。
- 分支、回放或切图产生新 Thread/namespace 映射，不覆盖原 Thread 身份。

## 7. Lineage 最小字段

领域事件、日志、ToolExecution、citation 和审计记录按需要携带：

```text
session_id
thread_id
run_id
run_attempt_id
root_invocation_id
parent_invocation_id
agent_invocation_id
correlation_id
causation_id
```

不是每张表都复制全部字段，但查询必须能沿外键/稳定映射还原整条 lineage。

## 8. Spike 结果

隔离 Python 语义模型和 SQLite 关系 schema 已验证：

- 五类 ID 类型和前缀互不复用。
- 一个 Session 创建两个不同 Run；同 Thread 非终态第二 Run 被拒绝，前一个 terminal
  后可执行。
- initial → waiting → resume → retry 共三个不同 Attempt，Run/Thread/root Invocation
  不变。
- waiting Run 可解析被 pin 的 Thread/checkpoint。
- 两个 worker 使用同一个 observed version claim 时只有一个成功。
- 同一 Run 只允许一个 running Attempt。
- Subagent 创建 child Invocation，不能跨 Run 连接 parent/root。
- Session–Thread–Run 归属由组合外键约束。

证据：`sunmoonai/docs/evidence/v5/V5-P0-002/result.md`。

## 9. 生产实施边界

本 ADR 不修改生产表。M1-301 必须把该模型转换为 PostgreSQL migration，并补齐：

- Attempt lease/heartbeat/deadline/error。
- Run command/outbox 与原子状态/event。
- resume/cancel command 和 idempotency。
- Invocation/ToolExecution/Approval/Artifact lineage。
- 旧 Phase 0 `session_id=thread_id` 数据的迁移或 legacy 标记。

当前 `agent_runs.thread_id = session_id` 和 Redis session lock 仍是 Phase 0 骨架，不能
解释为符合本 ADR。
