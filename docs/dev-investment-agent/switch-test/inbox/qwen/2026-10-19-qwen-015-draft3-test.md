# Qwen 卡 qwen-015：K19 第 3 稿——照 sig-am 的补充方法改第 6 步，孵出分身 1.3、测试，第一次看成稿与各步交回物（不发版）

> 状态：**可执行**（Opus 2026-10-19 改写；所有者「好，改写qwen-015」）。前提都已满足：qwen-016 已上线（knowbench 后端 `44888e2` 认第 6 步新加的两种验收 `each_has`、`covers`；knowlab 取回并显示成稿），所有者已用 sig-am 在 web端点了「同意新说明」。原稿 2026-10-19 写成后暂停（所有者「暂停转贴」，先做 [0037](../../../tree-build/SDD/modules/0037-idea-avatar-expert.md)）；sig-am 的补充 `e6df96db…` 由所有者把原话贴给 Opus。
> 不发版、不改集群：只在管理端孵化、核出处、发起测试，Qwen 看日志、核截图。

```text
被测：knowlab 管理端「分身」→「财务分析与预测」的分身 1.2 → 孵化下一个分身（分身 1.3）
清单：docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast/manifest-v1-draft3.json
     sha256 1f2e56177d163d7d8f576a44ae83843e652b822dce116a33536b9725c2f71f8d，53459 字节
和分身 1.2 比只改两步：第 6 步「对照官方披露」改成拿第 5 步的结论对照年报的管理层讨论（判支持/不支持，判支持的引原文，平台回 PDF 那一页核）；
  第 8 步「成稿」跟着改写法。规则出处仍是 14 条，G6 那条换成 sig-am 的补充（出处 amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6）
第 6 步的验收比暂停前多三项结构检查：每条结论有原话、判断、引文、理由，判断只许「支持」「不支持」；第 5 步的结论逐条对照、不多不少；
  每份年报要么写明找到的那一节（年份、数据编号、页码），要么写明没找到、为什么
数据绑定、用例、其余六步一字没动；预算 300、超时 28800 照旧
```

为什么这样改、怎么核过的：样本 [`README.md`](../../../tree-build/SDD/modules/0029-sample-fin-forecast/README.md) 第 5 条、预演 [`rehearsal/README.md`](../../../tree-build/SDD/modules/0029-sample-fin-forecast/rehearsal/README.md)「第 3 稿」（6 步全过，第 6 步做错的写法都判不过、该过的都过）。

## 一、核对（只读，Qwen）

```bash
bash <<'SH'
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen; echo "pull exit=$?"
git log --oneline -1
cd docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast
sha256sum manifest-v1-draft3.json; wc -c < manifest-v1-draft3.json
python3 -c "import json;m=json.load(open('manifest-v1-draft3.json'));print(m['version'], len(m['rule_sources']), [r['ref'] for r in m['rule_sources'] if r['ref'].startswith('amendment:')], [s['step_id']+'@'+s.get('step_version','1') for s in m['pack']['workflow']])"
SH
```

要看到：`pull exit=0`；sha256 与上面逐字一致、`53459`；`1 14 ['amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6'] ['scope@1', 'inventory@1', 'reconcile@1', 'series@1', 'indicators@1', 'official@2', 'forecast@1', 'writeup@2']`。对不上就停。

## 二、孵化与测试（所有者操作，用 admin 账号，登录由所有者输入；Qwen 核截图、看日志）

| # | 谁、在哪 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | 所有者，管理端「创意」（先硬刷新）→「财务分析与预测」 | 看主栏「补充方法」 | `e6df96db…` 是「待处理」，出处写 `amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6` |
| 2 | 所有者，管理端「分身」→ 分身 1.2 | 点「孵化下一个分身」 | 出现「孵化」一块，「孵化哪个创意」已选「财务分析与预测」 |
| 3 | 同上，「手工孵化：贴专家清单」 | 把 `manifest-v1-draft3.json` **全文**贴进框里，点「孵出分身」 | 出来「分身 1.3」，没有报错（报 `amendment … is not one of this request's`、`was declined`，或说验收规则不认得，就停，截图给 Opus） |
| 4 | 同上，分身 1.3 右边栏「规则出处」 | 看一眼 | 14 条；其中一条出处写 `amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6`，内容是「对照官方披露（第 6 步）：拿分析结论对照年报的管理层讨论……找不到这一节照实说」 |
| 5 | 所有者，管理端「创意」→「财务分析与预测」→「补充方法」 | 看一眼，不点「不照做」 | `e6df96db…` 变成「已用进第 3 个分身」 |
| 6 | 所有者，回到分身 1.3 | 逐条核对出处后点「已逐条核对出处」→ 预算上限 **300**、超时 **28800** →「发起测试」 | 「测试中」，有开跑时间；不出现「先处理这几条补充……」（出现就停，截图给 Opus） |
| 7 | Qwen，集群侧（开跑后约 15 分钟、之后每小时一次） | `$K -n app-platform-dev logs deploy/knowbench-runner --since=70m \| grep -E "advisor (stopped\|crashed)\|advance failed\|knowbot test\|budget exhausted\|workbench_mcp_result_too_large\|outputs failed"`；测试跑完后再加一条 `$K -n app-platform-dev logs deploy/knowlab-api --since=70m \| grep -E "Traceback\|outputs not fetched"` | 没有 `advisor crashed`、`advance failed`、`outputs failed`；用例跑完有 `advisor stopped task=… state=…`；全部跑完有 `knowbot test run finished run=… status=…`；第 6 步读五份年报的管理层讨论，**没有** `workbench_mcp_result_too_large`；knowlab-api 那条没有命中 |
| 8 | 所有者，管理端分身 1.3（隔一阵点「刷新结果」） | 看「跑到哪了」 | 「正在跑 c?（第 n/3 条）· 第 x/8 步 …」；c1、c2 跑到第 6 步「对照官方披露」时多停一会儿正常（要读五份年报的管理层讨论，约 31 万字节） |
| 9 | 所有者，管理端 | 测试结束后截图「测试报告」 | 三条用例各自的结论、「期望满足 x/y」；没过的「第几步没过」与原因全文（第 6 步没过的，原因里写到第几条结论、第几页、`not_found`、`too_short` 之类，或哪项结构检查没过）；花费、结束时间；状态 |
| 10 | 所有者，管理端分身 1.3「成稿与各步交回物」 | 逐条用例展开看，截图 | 每条用例有「取于 …」；「成稿」不为空，写明是第几步写的、文件路径；没有成稿的，「没有成稿：…」后面的原因照抄。没取到的点「补取产出」再看一次。各步交回物：通过的标「通过」，没过的那一步展开看得到没过的验收和最后一次交回的原文 |
| 11 | 所有者，用 sig-am 登录 web端「分身」→ 分身 1.3 | 看一眼 | 先看到成稿，和管理端第 10 行同一份 |
| 12 | 测试中若冒出「待回答的问题」 | 不在管理端「改由我们答」；截图告诉所有者，由所有者用 sig-am 在 web端「待我回答」里回答 | — |

判「不支持」不是没过：第 6 步只要判支持的都引了原文、引的都在年报那一页，结构检查都过，全判不支持也过。用例记「运行出错」（不是「未通过」）的，原因里会写「the platform stopped this run: …」，那是平台的事（待办账 138），照原文抄进回执。

第 10 行成稿为空、原因里有 `-32010` 的：查测试电脑上 `/workspace` 到底稿那条路径有没有经过符号链接（代理读文件不跟链接），`$K -n app-platform-dev exec deploy/knowbench-test-computer -- sh -c 'ls -la /workspace; readlink -f /workspace'` 输出原样进回执。

## 回执

`scripts/results/qwen-015.<时间>.md`：第一节输出原文；第二节每行的截图描述（第 3 行的分身号、第 4 行那条出处原文、第 5 行的状态）；第 7 行每次的日志行；第 9 行三条用例的结论与原因原文、花费与用时；第 10 行每条用例成稿的路径、是第几步写的、开头几行，没成稿的原因原文；第 11 行看到的是不是同一份。截图不带地址栏里的 code=、token=、state=。提交推送后停下等 Opus 审。
