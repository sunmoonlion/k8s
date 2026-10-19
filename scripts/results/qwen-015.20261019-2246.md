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

### 第 1–6 行（所有者操作）——已完成；截图免（所有者令），三样要项改用只读库真源原文

所有者 2026-10-19 本地 22:51–22:53 完成第 1–6 行，并令「截图免」。第 3 行分身号、第 4 行出处原文、第 5 行状态均从 knowlab 库只读取证（data-platform-dev/postgresql-0，库 knowlab，表 knowbot_draft / knowbot_amendment）：

```text
-- 该补充所属请求下的分身（草稿）序列：
                  id                  | revision | version | status  |                     run_id                     | run_attempts |       rules_reviewed_at       |          created_at
 433a5349-5301-41da-ad59-3c5db794c4c2 |        1 | 1       | failed  | knowlab-433a5349-5301-41da-ad59-3c5db794c4c2-1 |            1 | 2026-10-18 14:53:19.312359+00 | 2026-10-18 14:53:11.105089+00
 94b2d093-8098-4f0a-b3af-0ee6c827cae5 |        2 | 1       | failed  | knowlab-94b2d093-8098-4f0a-b3af-0ee6c827cae5-1 |            1 | 2026-10-19 00:29:55.966158+00 | 2026-10-19 00:29:44.227647+00
 1d4122f0-6e13-4ac4-9473-5f79f079e992 |        3 | 1       | testing | knowlab-1d4122f0-6e13-4ac4-9473-5f79f079e992-1 |            1 | 2026-10-19 14:52:31.472546+00 | 2026-10-19 14:51:41.76412+00

-- 补充方法本体（第 1/5 行）：
                  id                  |                                                       text_head                                                       | declined_at | declined_by
 e6df96db-a92c-43ce-8039-84d7ebcd65b6 | 第 6 步改成拿分析结论对照管理层讨论：只读管理层讨论那一节，按标题在目录里找；每条结论判支持或不支持，没提到算不支持， |             |

-- 分身 1.3 清单里那条 amendment 出处（第 4 行，jsonb 整条）：
{"ref": "amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6", "rule": "对照官方披露（第 6 步）：拿分析结论对照年报的管理层讨论，只读这一节、按标题在目录里找；每条判支持或不支持，没提到算不支持，判支持的引原文；找不到这一节照实说", "source": "user_text"}

-- 分身 1.3 清单结构：
 rule_count |                                            steps                                             | amendment_count
         14 | scope@1, inventory@1, reconcile@1, series@1, indicators@1, official@2, forecast@1, writeup@2 |               1
```

逐行对卡：
- 第 1 行：`e6df96db…` 存在且 `declined_at/declined_by` 皆空（未被拒）；出处写 `amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6`——与卡一致。
- 第 2–3 行：分身 1.3 = `knowbot_draft` revision **3**、id `1d4122f0-6e13-4ac4-9473-5f79f079e992`，创建 14:51:41Z，无报错；`status=testing`、`run_id` 已绑 `knowlab-1d4122f0-…-1`、`run_attempts=1`。
- 第 4 行：出处原文逐字如上（`rule` 字段），与卡面「对照官方披露（第 6 步）：拿分析结论对照年报的管理层讨论……找不到这一节照实说」相符；清单共 **14** 条、恰 **1** 条 amendment。
- 第 5 行：「已用进第 3 个分身」成立——该补充未 declined，且 revision=3 草稿的 `manifest.rule_sources` 恰含该 `amendment:e6df96db…` 引用。
- 第 6 行：`rules_reviewed_at=2026-10-19 14:52:31Z`（「已逐条核对出处」的库内凭据），随后 14:53:02Z 受理 run，`budget_limit=300.00`、`timeout_seconds=28800` 与卡一致；未出现「先处理这几条补充……」阻断（否则不会有 run_id）。

截图免后口径：第 9–11 行要入回执的用例结论、原因原文、花费与用时、成稿与各步交回物，同样改由只读库（knowbench 测试状态表族、knowlab `knowbot_test_output`、`knowbot_draft.report/delivery`）取原文入库；库取不到的项再请所有者口述。

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
