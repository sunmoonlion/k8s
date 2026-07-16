# V5-P0-001 Runtime 选型验收证据

日期：2026-07-16

结论：`ACCEPTED / CANDIDATE_A_SELECTED`

## 1. 决策结果

- 选中：Research 自建 Runtime（候选 A）。
- B/C：因生产许可、采购和外部 egress/usage reporting 未获批准，触发 ADR-001 预设硬
  淘汰规则；不是因为其运行能力不足。
- 当前 Walking Skeleton 不获得生产资格；生产实现继续受 P0-002 和 M1-301~312 控制。

## 2. 代码与镜像

Research Admin Backend：

- 实现提交：`a045de8 test: accept custom runtime selection spike`
- Research 父仓指针：`8445bdd test: pin custom runtime selection evidence`

| 文件 | SHA-256 |
|---|---|
| `app/infrastructure/graph/runtime_selection_spike.py` | `2090fe8d5742798b65397628bd54e8eec935b2d620da876d81eb00f379efc801` |
| `scripts/run_runtime_selection_sigkill_spike.py` | `ee5c37b67170ab56fd8ba6b8e6a4efad6159fdd84c6fa012f2dfd598e71532f5` |
| `scripts/run_runtime_selection_browser_spike.py` | `b41fd114b377dd15c698702a13b6880af9a6652011a9c87c8629767e3bb0fb8d` |
| `scripts/runtime_selection_browser_client.js` | `2d54a63e1fa8e1921fe5749489bc99c96118dfeee7af112d70878f3649c5c474` |
| `scripts/runtime_selection_browser_harness.html` | `301695eb2de46ae106a1f2f98c594327e20c71e6e00c9a3ae0d680def8e1d28f` |
| `scripts/runtime_selection_browser_spike.cjs` | `8750f163ecc94f62a2bd1d88944431ae8157fabecb06e77240fcf74af2f3ece0` |
| `tests/test_runtime_selection_spike.py` | `c90ca1c926948c01eac58e050ac1be1869f2c44154b5c339dccf257be626a1fd` |

K8s verifier：

| 文件 | SHA-256 |
|---|---|
| `sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_001_kind.py` | `6e7d45e7795c61a626542ec3d6c40dd077ba96b235f3d9056ad178ed32103de0` |

候选镜像：

```text
harbor.sunmoonai.com:30443/app-images/research-admin-backend:p0-001-runtime-candidate-a-20260716
harbor.sunmoonai.com:30443/app-images/research-admin-backend@sha256:d32f3e79e12193f6b2abde223260499e6220250287041994fc474a76ed72a10e
```

该镜像是 P0 Spike 证据，不是正式 `1.0.1` 发布镜像，不替换当前 Deployment。

## 3. 全量回归

```text
uv run pytest -q
90 passed in 1.10s

uv run pyright
0 errors, 0 warnings, 0 informations
```

Runtime 相关单元覆盖：

- 同 Thread 非终态第二 Run 被 reject。
- cancel 在副作用前终止并释放 Thread。
- cursor 返回断线后全部 durable event。
- broker 首次失败后 dispatch intent 保持 pending；恢复后只发送一次。
- interrupt/resume、崩溃重放、Thread 隔离与 Graph version pin。

## 4. KIND 真实进程/数据库验证

命令：

```text
python -u sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_001_kind.py \
  --image harbor.sunmoonai.com:30443/app-images/research-admin-backend:p0-001-runtime-candidate-a-20260716 \
  --kubeconfig "$HOME/.kube/kind-config" \
  --namespace app-platform-dev
```

结果：

```json
{
  "candidate": "A-custom-runtime",
  "checkpoint": "postgres",
  "process_death": "SIGKILL",
  "result": "passed",
  "kill_cases": [
    {
      "kill_point": "before_commit",
      "worker_exitcode": -9,
      "replacement_completed": true,
      "durable_side_effect_count": 1
    },
    {
      "kill_point": "after_commit",
      "worker_exitcode": -9,
      "replacement_completed": true,
      "durable_side_effect_count": 1
    }
  ],
  "cancel": {
    "running_cancel_observed": true,
    "terminal_status": "cancelled",
    "durable_side_effect_count": 0
  },
  "parallel_workers": {
    "worker_processes": 2,
    "worker_exitcodes": [0, 0],
    "terminal_statuses": ["completed", "completed"],
    "durable_side_effect_counts": [1, 1]
  },
  "postgres_outage": {
    "outage_observed": true,
    "fail_closed_side_effect_count": 0,
    "replacement_completed": true,
    "recovered_side_effect_count": 1
  }
}
```

验证 Job：

- 从现有 Research worker 只复制 ConfigMap/Secret 引用，不解析或打印 Secret 值。
- `automountServiceAccountToken=false`。
- 完成后自动删除；不会留下新的 Completed Job。

## 5. 浏览器 cursor 对账

命令：

```text
uv run python scripts/run_runtime_selection_browser_spike.py
```

真实 headless Chromium 首先只收到 live `event-1`，随后服务器主动断开 SSE；浏览器使用
`after_event_id=event-1` 请求 durable snapshot，补齐 `event-2`、`event-3`。

```json
{
  "browser": "chromium",
  "result": "passed",
  "cursor_reconciliation": true,
  "duplicate_events": 0,
  "event_ids": ["event-1", "event-2", "event-3"]
}
```

该 harness 冻结框架无关的客户端协议；P0-008C 仍必须由 Research Web 与真实 Research
Web Backend/Runtime adapter 成对执行业务 E2E，不能用本 harness 代替。

## 6. K8s 横向副本

Research API 与 worker 临时扩为两个副本：

```text
research-admin-backend                 requested=2  ready=2
celeryworker-research-admin-backend    requested=2  ready=2
```

副本分布到 `kind-worker` 与 `kind-worker2`；验证后自动恢复：

```text
research-admin-backend                 requested=1  ready=1
celeryworker-research-admin-backend    requested=1  ready=1
```

未改变 `AGENT_V4_TRAFFIC_ENABLED=false`，未替换正式 Deployment 镜像。

## 7. 许可与候选淘汰

2026-07-16 重新核验官方文档：

- Standalone Server 需要 `LANGGRAPH_CLOUD_LICENSE_KEY`。
- 非 air-gapped 模式需要访问 `https://beacon.langchain.com` 做 license verification 和
  usage reporting。
- self-hosted/Deployment 的 Enterprise 与试用许可需要供应商确认。

项目当前没有相应批准，故 B/C 按硬门淘汰。未来若许可和 egress 条件变化，必须新建 ADR
并复用本次故障矩阵，不得直接恢复 M1-313/314。

## 8. 验收边界

本证据只接受 Runtime **选型与边界**。以下仍未完成：

- Session/Thread/Run/Attempt/Invocation 生产模型。
- Research transactional outbox、Attempt lease、原子 resume/cancel、reconciler。
- 真实生产 Graph、LLM、Tool、Sandbox。
- Research Web 真实 streaming/HITL/citation E2E。

因此后续游标是 V5-P0-002，不是直接把当前 Walking Skeleton 切入生产。
