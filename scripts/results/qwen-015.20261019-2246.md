# qwen-015 回执（本地机 Qwen）

卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-015-draft3-test.md`（K19 第 3 稿：孵分身 1.3、测试、第一次看成稿与各步交回物；不发版）。qwen-012 等前置不做（所有者令）。

## 一、核对（只读）——输出原文，全对卡

```text
$ bash <<'SH'
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen; echo "pull exit=$?"
git log --oneline -1
cd docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast
sha256sum manifest-v1-draft3.json; wc -c < manifest-v1-draft3.json
python3 -c "import json;m=json.load(open('manifest-v1-draft3.json'));print(m['version'], len(m['rule_sources']), [r['ref'] for r in m['rule_sources'] if r['ref'].startswith('amendment:')], [s['step_id']+'@'+s.get('step_version','1') for s in m['pack']['workflow']])"
SH
From https://github.com/sunmoonlion/k8s
 * branch              qwen       -> FETCH_HEAD
Already up to date.
pull exit=0
c37afb6c (HEAD -> qwen, origin/qwen) qwen-015 改写：0037 上线后按创意/分身新导航孵出分身 1.3；清单换审读后重出的那份（sha 1f2e5617…，第 6 步加三项结构检查）；新加成稿与各步交回物、web端看成稿、-32010 时查符号链接
1f2e56177d163d7d8f576a44ae83843e652b822dce116a33536b9725c2f71f8d  manifest-v1-draft3.json
53459
1 14 ['amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6'] ['scope@1', 'inventory@1', 'reconcile@1', 'series@1', 'indicators@1', 'official@2', 'forecast@1', 'writeup@2']
```

逐项对卡：sha256 逐字一致、`53459` 字节、`1 14 ['amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6']`、八步 `official@2` 与 `writeup@2`（其余 @1）——全对，放行第二节。

## 二、孵化与测试

### 第 1–6 行（所有者操作）——已操作，截图描述待补

所有者 2026-10-19 本地约 22:53 完成第 1–6 行（孵出分身、核出处、发起测试）；集群侧佐证：run `knowlab-1d4122f0-6e13-4ac4-9473-5f79f079e992-1` 于 14:53:02Z 受理，`budget_limit=300.00`、`timeout_seconds=28800` 与卡面第 6 行一致。第 3 行分身号、第 4 行那条出处原文、第 5 行状态的截图描述待所有者截图后补。

### 加步（所有者同意）：测试停「已受理」→ 取证 → 换测试电脑 Pod

背景：受理后 runner 零日志、run 停 `accepted`；疑测试电脑代理在今晚边缘重启后卡在半开连接（待办账 136）。

**1. 取证（只读，输出原样）：**

```text
$ $K -n app-platform-dev get pod -l app.kubernetes.io/name=knowbench-test-computer -o wide
NAME                                       READY   STATUS    RESTARTS   AGE   IP               NODE                  NOMINATED NODE   READINESS GATES
knowbench-test-computer-58bdd469cf-ckl47   1/1     Running   0          14h   10.247.162.212   sunmoon-kind-worker   <none>           <none>
$ $K -n app-platform-dev logs deploy/knowbench-test-computer --since=4h --timestamps | tail -15
Defaulted container "agent" out of: agent, fetch (init)
（此外无任何日志行：agent 容器近 4 小时零输出，与半开连接卡死吻合）
```

**2. 换 Pod（只删这一个，不用 rollout restart）：**

```text
pod "knowbench-test-computer-58bdd469cf-ckl47" deleted from app-platform-dev namespace
pod/knowbench-test-computer-58bdd469cf-8dbbp condition met
wait exit=0
NAME                                       READY   STATUS    RESTARTS   AGE   IP               NODE                  NOMINATED NODE   READINESS GATES
knowbench-test-computer-58bdd469cf-8dbbp   1/1     Running   0          2s    10.247.162.214   sunmoon-kind-worker   <none>           <none>
```

**3. 新 Pod Ready 后 1–2 分钟：**

```text
select run_id, status, started_at, finished_at, spent from workbench_test_runs where run_id='knowlab-1d4122f0-…-1';
                     run_id                     | status  |          started_at           | finished_at |  spent
 knowlab-1d4122f0-6e13-4ac4-9473-5f79f079e992-1 | running | 2026-10-19 15:00:04.565271+00 |             | 0.000000
```

`started_at` 有值（15:00:04Z，新 Pod Ready 后 4 秒）→ run 转 `running`。runner 同期出现执行类行：`took over sandbox=5df3a519-6a48-43f0-9182-3e4ec074191c expired_approvals=0`、`sandbox link up sandbox=5df3a519… url=ws://sandbox-u-9c4bf023b0f8…:47800`、随后多条 `mcp elicitation … "list_my_data" / "read_my_table"` 审批行。新测试电脑日志：`sunmoon-link starting version=0.5.0`、`exec-server ready`、`relay connected`、`stream bridged conn=eb5c8d46` → 通道健康。

### 第 7 行（Qwen 日志核）

- 首核（15:01 UTC，`--since=70m`）：`grep -E "advisor (stopped|crashed)|advance failed|knowbot test|budget exhausted|workbench_mcp_result_too_large|outputs failed"` **零命中**——无崩溃/推进失败/结果过大/预算耗尽；`knowbot test … finished` 与 `advisor stopped` 待用例跑完才出现。后续每小时一核，逐次补记。

### 第 8–12 行——待回报
