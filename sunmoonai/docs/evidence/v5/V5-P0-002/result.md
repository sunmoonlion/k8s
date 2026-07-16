# V5-P0-002 执行身份模型验收证据

日期：2026-07-16

结论：`ACCEPTED`

## 1. 范围

本次只增加隔离语义模型、隔离 SQLite 关系 schema、测试和可执行脚本；不导入 API、
Celery worker，不修改 Alembic 或生产数据库。

## 2. 代码与 SHA-256

Research 子仓提交：`research-admin-backend@9d72a13`

Research 父仓指针提交：`research-app@8121595`

| 文件 | SHA-256 |
|---|---|
| `app/infrastructure/graph/execution_identity_spike.py` | `20ea2fb411da38b0b66a23a848d5d01d14d4ce8255574ed9333d0ed67e1dc60e` |
| `app/infrastructure/graph/execution_identity_spike.sql` | `0fbd352b591c798be1ca27ea41660fb53ab023263bd63a4fed704c0b6d4671f6` |
| `tests/test_execution_identity_spike.py` | `88d1d09daa74d6cc481f90befc719cc09215a1f0cc17a03c910610dcbd3eef7c` |
| `scripts/run_execution_identity_spike.py` | `480635c90a674be620809d1284ed7ecadf30b59b2f97e7158b1a24bd1956d2d4` |

## 3. 验证结果

专项测试：

```text
uv run pytest -q tests/test_execution_identity_spike.py
8 passed in 0.03s
```

全量回归：

```text
uv run pytest -q
98 passed in 1.27s

uv run pyright
0 errors, 0 warnings, 0 informations
```

可执行场景：

```text
uv run python scripts/run_execution_identity_spike.py
```

结构化结果：

```json
{
  "task": "V5-P0-002",
  "result": "passed",
  "attempt_ordinals": [1, 2, 3],
  "attempt_reasons": ["initial", "resume", "retry"],
  "checkpoint_id": "checkpoint-1",
  "run_status": "completed",
  "child_lineage_depth": 2,
  "relational_foreign_keys": true,
  "relational_attempt_count": 3,
  "relational_invocation_count": 2
}
```

ID 值每次随机生成，证据只固定类型、关系和状态语义，不固定具体 UUID。

## 4. 已验证约束

- `SessionId/ThreadId/RunId/AttemptId/InvocationId` 是不同运行时类型和不同前缀。
- Session 与 Thread 的 ID 不相等。
- Run 通过 Session+Thread 组合归属，跨 Session Thread 被拒绝。
- 一个 Session 可拥有两个 Run；同 Thread 非终态并发采用 ADR-001 的 reject。
- Run resume/retry 保持同一 Run 和 Thread，创建新 Attempt。
- Attempt ordinal 在 Run 内唯一，同一 Run 只允许一个 running Attempt。
- 乐观 version 条件更新只允许一个 worker claim。
- Checkpoint 绑定 Thread/namespace/id/Graph version。
- child Invocation 的 root、parent、Run 必须一致，跨 Run lineage 被外键/模型拒绝。

## 5. 未完成项

- 尚未创建生产 PostgreSQL migration。
- 尚未实现 Attempt lease/heartbeat/reconciler。
- 尚未迁移 Phase 0 `session_id=thread_id` 数据。
- 尚未把扩展 lineage 写入生产 DomainEvent/日志/API DTO。

以上属于 M1-301~304；P0-002 Accepted 不代表生产执行 schema 已完成。
