# Qwen 卡 qwen-015：K19 第 3 稿——照 sig-am 的补充方法改第 6 步，孵出分身 1.3、测试，第一次看成稿与各步交回物（不发版）

> 状态：**已完成**（2026-10-20 所有者贴管理端结果：三条用例全过、已交付；「集群好像正常结束了，qwen好像没有查。就算了吧」；随后 Qwen 补齐第 7–12 行（回执 `62c093a8`，全绿），见文末「结果与审读」）。原状态：可执行（Opus 2026-10-19 改写；所有者「好，改写qwen-015」）。前提都已满足：qwen-016 已上线（knowbench 后端 `44888e2` 认第 6 步新加的两种验收 `each_has`、`covers`；knowlab 取回并显示成稿），所有者已用 sig-am 在 web端点了「同意新说明」。原稿 2026-10-19 写成后暂停（所有者「暂停转贴」，先做 [0037](../../tree-build/SDD/modules/0037-idea-avatar-expert.md)）；sig-am 的补充 `e6df96db…` 由所有者把原话贴给 Opus。
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

为什么这样改、怎么核过的：样本 [`README.md`](../../tree-build/SDD/modules/0029-sample-fin-forecast/README.md) 第 5 条、预演 [`rehearsal/README.md`](../../tree-build/SDD/modules/0029-sample-fin-forecast/rehearsal/README.md)「第 3 稿」（6 步全过，第 6 步做错的写法都判不过、该过的都过）。

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

## 结果与审读（Opus 2026-10-20，依据所有者贴的管理端分身 1.3 页面与 Qwen 补齐的回执）

- **Qwen 回执第 7–12 行**：runner 三次核无 `advisor crashed`、`advance failed`、`outputs failed`、`budget exhausted`，第 6 步没有 `workbench_mcp_result_too_large`；三条 `advisor stopped … state=SUCCEEDED`，`knowbot test run finished … status=passed error=`；knowlab-api 零命中；24 步全 `accepted`、验收 48/48（第 6 步 `official` 9/9）；三条都有成稿（c2 照实说人均创收算不出来、员工人数不在数据里，c3 照实说五粮液不在数据里）；没有待回答的问题。期望条数回执写「各 2/2」，管理端页面 c2 是 1/1，以页面为准，不影响结论。Qwen 自述轮询命中结束后自停、没主动回报，所有者问了才补——下次跑完要主动报。

- **测试报告**：c1 通过 · 期望满足 2/2；c2 通过 · 1/1；c3 通过 · 2/2。花费 66.36 元，结束于 2026/10/20 00:49（北京时间；10-19 15:00:04Z 开跑，约 1 小时 49 分）。三条都写「本次测试没有隔离」——照旧，等代理 0.5.1 打开 `KNOWBOT_TEST_ISOLATE`（待办账 129）。
- **交付**：四段全勾，「已交付 knowmart，专家编号 `084acc72-f396-453f-ad70-d300695678dc`」。**不是所有者点的**（所有者 2026-10-20「不是我点的」）：knowlab 的「刷新结果」查到测试通过就接着交付（`knowbot_service.py` `refresh()` 末尾「通过的接着交付」，0027 P3 起就这样，SDD 0027「刷新结果、通过即交付」），所有者按第 8 行点「刷新结果」时自动交了；后端没有定时刷新，交付只有这一条和「重试交付」按钮两条路。0037 第三节把「通过待交付」列成要我们动手的一段，和代码不符——交付是自动还是要人点，进 `创意-分身-专家状态.md` 一起定。交到的是 knowmart 私有登记，只有作者 sig-am 能请；[qwen-012](../inbox/qwen/2026-10-19-qwen-012-k21-hire.md) 的前置「第 3 稿测试通过、已交付」由此满足。
- **成稿**（c1，取于 2026/10/19 23:59）：`底稿/对话-c7077de8/2026-10-19-230004-财务分析与预测/财务分析与预测-成稿.md`，第 8 步写的。回答、数据五张表、专家验过什么（勾稽四项 22 期全为 0；对照年报管理层讨论；指标与发现；预测先回测再外推，8 个回测点 4 个落在区间内）、局限，数字都带出处或计算编号。
- **第 6 步照 sig-am 的补充做到了**：五份年报都按目录标题找到「管理层讨论与分析」并写了页码（2021 p7–17 … 2025 p8–22）；7 条结论 2 条判支持、都引了原文，5 条判不支持、各写了理由；页面写明「引文平台核过在原件里；判断是模型做的」。
- **留给 sig-am 第 4 稿的（模型的判断，方法没说清的地方；按 C-L1 由 sig-am 定，我们不替他补）**：
  1. 发现 2「归母净利润 2021–2024 增长、2025 下降」，2025 下降管理层讨论没提，整条仍判支持——「没提到算不支持」是按整条结论判，还是按其中每一句判，方法没说；
  2. 发现 4 毛利率只出现在这一节的表格里、叙述里没有，判不支持——这一节里的表格算不算「提到」，方法没说；
  3. 发现 1 的 2025 年引的是「营业收入变动原因说明」，不是数；管理层用「营业总收入」口径，成稿写明了口径不同、方向一致；
  4. 两处引文截掉了开头（「属于上市公司股东的净利润…」「于上市公司股东的净利润…」），平台按原文核得过，读起来不完整。
  这几条和决定记录里第 4 稿已定要问的（读哪几年、去掉「为测试抄营业收入」）一起问。
- **页面问题**：成稿那一行写「第 writeup 步写的」——管理端把步骤编号直接填进了「第 {step} 步」，应写「第 8 步「成稿」」，记待办账 142，随下一次管理端改版。

