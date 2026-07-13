# V5-P0-001 候选 A 部分证据

日期：2026-07-11  
结论：`PARTIAL_PASS`，不是 ADR 验收。

## 范围

本证据只覆盖自建 Runtime 候选 A 的隔离 Spike。代码不接 API、Celery 注册、Kubernetes 流量或生产数据。

同构图：

```text
START -> persist_input -> ask_user(interrupt)
      -> side_effect_tool(execute_once) -> final -> END
```

## 代码与 SHA-256

| 文件 | SHA-256 |
|---|---|
| `app/infrastructure/graph/runtime_selection_spike.py` | `b31968d3475f4462cb5e1aabeb9feb67a8fee9b509d015a3ac1812a0e9d785d3` |
| `scripts/run_runtime_selection_spike.py` | `00ec95d480a7a2cf1bd3f4abbc4453ce4daf3e082c6a867710c6df348fa5898b` |
| `scripts/run_runtime_selection_postgres_spike.py` | `1472bb3b957d39394c43e414fb312b0b20e7611cb4176ddc6536e76978f50e56` |
| `tests/test_runtime_selection_spike.py` | `83a848df8a603b4fc200e7966e3ddcc09f98e507f9d3dba0bb269ee7918a79cf` |

仓库：`/home/zymun/research-app/research-admin-backend/app`，分支 `codex-1`。

## 执行结果

相关回归：

```text
uv run pytest -q tests/test_runtime_selection_spike.py tests/test_agent_phase0.py tests/test_graph_runtime_service.py tests/test_side_effect_service.py
..........                                                               [100%]
10 passed in 0.51s
```

本地崩溃注入：

```json
{"candidate":"A-custom-runtime","graph_version":"runtime-spike-v1","injected_crash_observed":true,"interrupt":true,"physical_side_effect_executions":1,"resume_completed":true}
```

PostgreSQL checkpointer 跨连接/替代 worker 恢复：

```json
{"candidate":"A-custom-runtime","checkpoint":"postgres","interrupt":true,"physical_side_effect_executions":1,"replacement_worker_resume_completed":true,"thread_id":"6d6a7599-6ad9-4f33-a685-e24b170568de"}
```

类型检查：

```text
0 errors, 0 warnings, 0 informations
```

## 失败与环境发现

完整旧版 `validate_agent_phase0.py` 没有通过：本地 Redis 配置返回 `invalid username-password pair or user is disabled`。这不是本次 Spike 的成功项，也不能被忽略。PostgreSQL 专项脚本成功，是因为它不依赖 Redis。

## 已证明与未证明

已证明：基础 interrupt/resume、checkpoint 跨连接恢复、崩溃重放下的 operation 幂等测试语义、Thread 隔离、Graph 版本 pin 的调用纪律。

未证明：真实 `SIGKILL`、durable side-effect journal、同 Thread 并发、cancel、cursor streaming、双副本、Redis/queue/DB 故障注入以及候选 B/C 对照。未证明项完成前 ADR-001 不得 Accepted。

## 候选 B/C 准备结果

`langgraph-api`、`langgraph-cli` 不在当前项目环境。使用隔离的 `uvx --from 'langgraph-cli[inmem]'` 获取官方本地 CLI 时，当前软件源没有成功解析/下载该 extra；离线重试确认缓存中也不存在。故本轮没有候选 B/C 运行证据，且没有修改 `pyproject.toml` 或 `uv.lock`。需要先解决可审计软件源和版本锁定，再运行同一测试矩阵。

## 2026-07-13 续作复验

四个隔离 Spike 文件已在 Research Admin Backend 提交：

- commit：`33fd6de test: add runtime selection spike`
- 分支：`codex-1`
- 文件仍不被 API、Celery 注册或生产路由导入。

本次复验：

```text
.venv/bin/pytest -q tests/test_runtime_selection_spike.py
4 passed in 0.19s

.venv/bin/python scripts/run_runtime_selection_spike.py
{"candidate":"A-custom-runtime","graph_version":"runtime-spike-v1","injected_crash_observed":true,"interrupt":true,"physical_side_effect_executions":1,"resume_completed":true}

.venv/bin/pytest -q
76 passed in 1.22s
```

该复验只确认 Spike 可重复运行且不破坏 Research Admin 现有测试；不增加真实 `SIGKILL`、同 Thread 并发、cancel、cursor streaming、双副本或候选 B/C 的证据。因此结论仍为 `PARTIAL_PASS`，ADR-001 仍不得 Accepted。
