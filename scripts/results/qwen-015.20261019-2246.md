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

### 第 7 行（Qwen 日志核）——三次核 + 跑完补证，全绿

后台每小时轮询（`/tmp/q015-line7-poll.sh`，命中 `knowbot test run finished` 自停）共三轮，命令与判据原文：

```text
$ $K -n app-platform-dev logs deploy/knowbench-runner --since=70m | grep -E "advisor (stopped|crashed)|advance failed|knowbot test|budget exhausted|workbench_mcp_result_too_large|outputs failed"
$ $K -n app-platform-dev logs deploy/knowlab-api --since=70m | grep -E "Traceback|outputs not fetched"

=== #1 2026-10-19 15:13:29 UTC ===
runner 判据行：零命中；knowlab-api：零命中
run 账面：status=running, spent=0.000000, started_at=2026-10-19 15:00:04.565271+00, finished_at 空, err 空

=== #2 2026-10-19 16:13:29 UTC ===
2026-10-19 15:52:23 - app.application.workbench.runner - INFO - advisor stopped task=24eb4050-4b93-4018-b8e0-c1321b23e3f3 state=SUCCEEDED
knowlab-api：零命中
run 账面：status=running, spent=33.061280

=== #3 2026-10-19 17:13:30 UTC ===
2026-10-19 16:46:11 - app.application.workbench.runner - INFO - advisor stopped task=b0299cab-698b-497c-8d1b-f7fdd795850d state=SUCCEEDED
2026-10-19 16:49:52 - app.application.workbench.runner - INFO - advisor stopped task=12487aa9-298e-48e6-b69e-2220c2b09d48 state=SUCCEEDED
2026-10-19 16:49:58 - app.application.workbench.test_runs - INFO - knowbot test run finished run=knowlab-1d4122f0-6e13-4ac4-9473-5f79f079e992-1 status=passed error=
knowlab-api：零命中
run 账面：status=passed, spent=66.357968, finished_at=2026-10-19 16:49:58.45035+00, err 空
=== finished 命中，停止轮询 17:13 UTC ===
```

对卡逐条：无 `advisor crashed`、无 `advance failed`、无 `outputs failed`、无 `budget exhausted`；三条用例各有 `advisor stopped task=… state=SUCCEEDED`；全部跑完有 `knowbot test run finished … status=passed error=`（error 为空）；第 6 步读五份年报管理层讨论**没有** `workbench_mcp_result_too_large`；knowlab-api 那条（`Traceback|outputs not fetched`）零命中。

坦白项：轮询在 17:13 UTC 命中 finished 后按设计自停，我未主动回报终态；所有者 2026-10-20 询问后补写本节。

### 第 8 行（「跑到哪了」）——截图免，取库内真源

`knowbot_draft.report`：`progress=null`（已终态）、`questions=[]`（全程未冒出待回答的问题）、`waited_seconds=0`、`contract=knowbot-test-run/v1`；开始 15:00:04Z、结束 16:49:58Z，历时 1h49m54s。用例时序依 `advisor stopped` 时刻：c1 15:00→15:52、c2 →16:46、c3 →16:49:52；c1、c2 在第 6 步多停与卡面预期一致（要读五份年报的管理层讨论）。

### 第 9 行（测试报告原文）——三条全过

- 总体：run `status=passed`；三条用例 `status` 各 `passed`，`expectations=[true,true]` → 每条「期望满足 **2/2**」；每用例 8 步全 `accepted=true`、`failed_checks` 皆空。无未过用例，故无「第几步没过」与原因可抄；无「运行出错」用例（未出现 `the platform stopped this run:`）。
- 每条用例 `note` 原文（三条相同）：「本次测试没有隔离：测试电脑的本地代理还不支持建、删目录，在共用的工作区里跑」。
- 花费：`cost.spent=66.357968`（`currency=CNY`，上限 300）；结束时间 `finished_at=2026-10-19T16:49:58.450350+00:00`；状态 `passed`。

### 第 10 行（成稿与各步交回物）——三条都有成稿，24 步全过

成稿均为第 8 步 `writeup`（标题「成稿」）所写，`deliverable_note` 与 `error` 三条皆空，无「没有成稿：…」项；未出现 `-32010`，故卡面那条符号链接排查不适用、未执行。

| 用例 | 成稿路径（「取于 …」） | 正文长度 | 开头几行 |
| --- | --- | --- | --- |
| c1 | `底稿/对话-c7077de8/2026-10-19-230004-财务分析与预测/财务分析与预测-成稿.md` | 7944 | 「# 贵州茅台（600519）：营业收入与归母净利润近三年走势及 2026Q3–2026Q4 预测」/「分析日期：2026-10-19。全部数字来自用户上传的工作簿（合并报表口径）与 2021–2025 五份年报，金额单位为元。本稿只描述，不作评价。」/「## 回答」/「**近三年走势（2023、2024、2025 年报期，全年口径）**」 |
| c2 | `底稿/对话-31099bd7/2026-10-19-235233-财务分析与预测/财务分析与预测-成稿.md` | 7796 | 「# 贵州茅台近三年的人均创收——财务分析与预测成稿」/「## 回答」/「**人均创收算不出来。** 人均创收＝营业收入÷员工人数。分子营业收入在你的工作簿里有（合并口径全年数）：2023 年 147693604994.14 元、2024 年 170899152276.34 元、2025 年 168838102514.79 元；但分母员工人数（在职员工数量）没有收录在工作簿任何一张表里，它只在各年报「公司治理」一节披露，而你绑定的五份年报 PDF 各只含前 10 页（2021、2022 年报）或前 11 页（2023、2…」 |
| c3 | `底稿/对话-7cce4fd7/2026-10-20-004617-财务分析与预测/财务分析与预测-成稿.md` | 1135 | 「# 财务分析与预测 · 成稿」/「**问题**：五粮液近三年的营业收入走势如何？」/「## 回答」/「你的数据里没有这家公司。你绑定给本专家的数据全部是贵州茅台：一个三张表与主要会计数据的工作簿，以及 2021—2025 年五份年度报告，其中没有任何五粮液的报表或年报。因此五粮液近三年的营业收入数值与走势算不出来——本专家只用你上传的数据，不去外部取数，也不凭记忆填数。」/「## 数据」/「无。问题所问的五粮液不在你的数据中，没有可…」 |

各步交回物（`knowbot_test_output.outputs.steps`，主键 draft_id+run_id+case_id）：**24 步（3 用例 × 8 步）outcome 全 `accepted`**，验收全过且无失败项（`failed_msgs` 全空）：每用例依次 `scope` 2/2、`inventory` 2/2、`reconcile` 6/6、`series` 4/4、`indicators` 10/10、`official` **9/9**（第 6 步，含本轮新增的三项结构检查）、`forecast` 8/8、`writeup` 7/7，合计 **48/48**。因无未过步，无「没过的验收与最后一次交回原文」可抄；`returned_raw` 三条用例各步长度均为 0（本轮该字段为空，交回内容在 `artifact` 里）；`artifact_omitted_bytes` 均空。无需「补取产出」。

### 第 11 行（web端 sig-am 看成稿）——同一份，库内凭据

草稿 `1d4122f0…` `status=delivered`，`delivery` 全文：`{"digest":"sha256:068ea80e27ff262732ff2f8eded55fbe7e5c5d8801ce08b74677a9b2269f1f32","version":"1","knowbot_id":"084acc72-f396-453f-ad70-d300695678dc","delivered_at":"2026-10-19T17:02:45.875401+00:00"}`。web端与管理端读的是同一份交付物（同 `knowbot_id` 与同 delivery digest，成稿取自主键 `draft_id+run_id+case_id` 的同一行 `knowbot_test_output`），故为同一份；若需目视确认可用 sig-am 开 web端「分身」→分身 1.3，对比上表路径与开头几行。

### 第 12 行（待回答的问题）——未出现

`report.questions=[]`、`waited_seconds=0`，全程未冒出「待回答的问题」；未在管理端「改由我们答」，也无需所有者用 sig-am 在 web端作答。

## 三、纪律与清理

- 未写库（全程只读 SELECT）、未替所有者在管理端/web端点击、未用 `rollout restart`（只按加步单独 `delete pod` 测试电脑）；qwen-012 未碰。
- 一次性产物：`/tmp/q015-runs.sql`、`/tmp/q015-345.sql` 用完已删；本节固化后删 `/tmp/q015-line7-poll.sh`、`/tmp/q015-line7.log`、`/tmp/q015-910.log`、`/tmp/q015-910b.log`、`/tmp/q015-out.log`、`/tmp/q015-out2.log`；仓内 `scripts/` 未留任何 `tmp-q015-*`。轮询进程已自行退出（`pgrep` 无匹配）。

## 四、结论

K19 第 3 稿（分身 1.3，清单 `manifest-v1-draft3.json` sha `1f2e5617…`）测试 **全过**：三条用例 `passed`、期望各 2/2、24 步全 `accepted` 且验收 48/48（第 6 步 `official` 9/9 含新增三项结构检查），花费 66.357968 CNY / 上限 300，历时 1h49m54s（15:00:04Z→16:49:58Z），草稿已 `delivered`（knowbot `084acc72…`，delivery digest `sha256:068ea80e…`，17:02:45Z）。三条成稿均非空且内容合理（c1 给出近三年走势与 2026Q3–Q4 预测；c2 如实说人均创收算不出来、分母不在数据里；c3 如实说五粮液不在绑定数据里），符合「找不到就照实说」的补充方法要求。未发版、未改集群配置；唯一写动作是加步里单独删除测试电脑 Pod。

