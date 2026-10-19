# Qwen 卡 qwen-015：K19 第 3 稿——照 sig-am 的补充方法改第 6 步，建稿、测试（不发版）

> 状态：**暂停**（所有者 2026-10-19「暂停转贴」：先做 [0037](../../../tree-build/SDD/modules/0037-idea-novice-expert.md)，让测试人员和用户看得到成稿与交回物；0037 上线后本卡改写再发）。原前提：qwen-014 第四节第 4 行已写进回执并推送（Opus 2026-10-19 写；sig-am 在 web端写的补充 `e6df96db…`，所有者把原话贴给 Opus）。
> 不发版、不改集群：只在管理端建稿、核出处、发起测试，Qwen 看日志、核截图。

```text
被测：knowlab 管理端「专家草稿」→「财务分析与预测」，第 1 版第 3 稿
清单：docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast/manifest-v1-draft3.json
     sha256 1cbda8e6a26547c335a150f72521e6ece90201902f6568677325dc7ac401c192，51364 字节
和第 2 稿比只改两步：第 6 步「对照官方披露」改成拿第 5 步的结论对照年报的管理层讨论（判支持/不支持，判支持的引原文，平台回 PDF 那一页核）；
  第 8 步「成稿」跟着改写法。规则出处仍是 14 条，G6 那条换成 sig-am 的补充（出处 amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6）
数据绑定、用例、其余六步一字没动；预算 300、超时 28800 照旧
```

为什么这样改、怎么核过的：样本 [`README.md`](../../../tree-build/SDD/modules/0029-sample-fin-forecast/README.md) 第 5 条、预演 [`rehearsal/README.md`](../../../tree-build/SDD/modules/0029-sample-fin-forecast/rehearsal/README.md)「第 3 稿」。

## 一、核对（只读，Qwen）

```bash
bash <<'SH'
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen; echo "pull exit=$?"
git log --oneline -1
cd docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast
sha256sum manifest-v1-draft3.json
python3 -c "import json;m=json.load(open('manifest-v1-draft3.json'));print(m['version'], len(m['rule_sources']), [r['ref'] for r in m['rule_sources'] if r['ref'].startswith('amendment:')], [s['step_id']+'@'+s.get('step_version','1') for s in m['pack']['workflow']])"
SH
```

要看到：`pull exit=0`；sha256 与上面逐字一致；`1 14 ['amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6']`，八步里只有 `official@2`、`writeup@2`，其余 `@1`。对不上就停。

## 二、建稿与测试（所有者操作，登录由所有者输入；Qwen 核截图、看日志）

| # | 谁、在哪 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | 所有者，管理端「专家草稿」（先硬刷新）→ 左边「财务分析与预测」 | 看「下一步」卡片和页签「补充方法」 | 第 2 稿「测试未通过」，下面有「建下一稿」的框；「补充方法」里 `e6df96db…` 是「待处理」 |
| 2 | 同上，「建下一稿」 | 把 `manifest-v1-draft3.json` **全文**贴进去，点「建草稿」 | 「第 1 版 · 第 3 稿」；没有报错（报 `amendment … is not one of this request's` 或 `was declined` 就停，截图给 Opus） |
| 3 | 同上，页签「规则出处」 | 看一眼 | 14 条；其中一条出处写 `amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6`，内容是「对照官方披露（第 6 步）：拿分析结论对照年报的管理层讨论……找不到这一节照实说」 |
| 4 | 同上，页签「补充方法」 | 看一眼，不点「不照做」 | `e6df96db…` 变成「已用进第 3 稿」 |
| 5 | 同上，「下一步」卡片 | 逐条核对出处后点「已逐条核对出处」→ 预算上限 **300**、超时 **28800** →「发起测试」 | 「测试中」，有开跑时间；不出现「先处理这几条补充……」（出现就停，截图给 Opus） |
| 6 | Qwen，集群侧（开跑后约 15 分钟、之后每小时一次） | `$K -n app-platform-dev logs deploy/knowbench-runner --since=70m \| grep -E "advisor (stopped\|crashed)\|advance failed\|knowbot test\|budget exhausted\|workbench_mcp_result_too_large"` | 没有 `advisor crashed`、`advance failed`；用例跑完有 `advisor stopped task=… state=…`；全部跑完有 `knowbot test run finished run=… status=…`；第 6 步读五份年报的管理层讨论，**没有** `workbench_mcp_result_too_large` |
| 7 | 所有者，管理端（隔一阵点「刷新结果」） | 看进度行 | 「正在跑 c?（第 n/3 条）· 第 x/8 步 …」；c1、c2 跑到第 6 步「对照官方披露」时多停一会儿正常（要读五份年报的管理层讨论，约 31 万字节） |
| 8 | 所有者，管理端 | 测试结束后截图 | 三条用例各自的结论、「期望满足 x/y」；没过的「第几步没过」与原因全文（第 6 步没过的，原因里写到第几条结论、第几页、`not_found` 之类）；花费、结束时间；状态 |
| 9 | 测试中若冒出「待回答的问题」 | 不在管理端「改由我们答」；截图告诉所有者，由所有者用 sig-am 在 web端回答 | — |

判「不支持」不是没过：第 6 步只要判支持的都引了原文、引的都在年报那一页，全判不支持也过。用例记「运行出错」（不是「未通过」）的，原因里会写「the platform stopped this run: …」，那是平台的事（待办账 138），照原文抄进回执。

## 回执

`scripts/results/qwen-015.<时间>.md`：第一节输出原文；第二节每行的截图描述（第 2 行的稿号、第 3 行那条出处原文、第 4 行的状态）；第 6 行每次的日志行；第 8 行三条用例的结论与原因原文、花费与用时。截图不带地址栏里的 code=、token=、state=。提交推送后停下等 Opus 审。
