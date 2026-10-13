# 给 Qwen：财务分析与预测 第 3 段的本地一截——用真 Codex 跑十题（账 96）

> Opus 2026-10-13 在远程机写；你在所有者本地机做，两边只经 git 来往（所有者同步）。Opus 主导，你的回执由 Opus 审。
> 远程能做的 Opus 已经做了：专家包五步的方法（investment-backend `packs.py` 的 `FIN_FORECAST`）、十道题与固定数据（`eval/cases/fin_forecast_10.json`）、跑分脚本 `sunmoonai/scripts/local-integration/workbench-finforecast.sh`；远程起过知识服务的 MCP（语义层开着、装样例），工具与查询都通。**真 Codex、真模型 key 只在本地跑**（所有者 2026-10-13 定），所以这一截归你。
> 设计：[`tree-build/SDD/modules/0023-fin-forecast.md`](../../../tree-build/SDD/modules/0023-fin-forecast.md) 第五节（五步与失败去向）、第六节（十题与「三栏都过才算过」）。
> 先做完 `qwen-001`（联调链接样例），再做本页。

## 一、前提（缺一项先问所有者，不猜）

| 项 | 怎么核 |
| --- | --- |
| 代码是最新的 | `git -C ~/worktrees/qwen/investment-app/investment-backend log --oneline -3` 能看到「feat(packs): 财务分析与预测五步」；`git -C ~/worktrees/qwen/knowledge-app/knowledge-backend log --oneline -3` 能看到「样例改为按真实客户 1/20 抽样」 |
| 两个后端的依赖 | 各自 `cd …/app && uv sync --frozen` |
| `workbench-chain.sh` 的前提 | 沙箱镜像 `sunmoon/sandbox:dev` 在、runtime 已构建（`runtime/agent/dist/cli.js` 在）、`pgtest` 容器在 55432 |
| 模型 key | 脚本默认读 `~/.codex-probe-kimi/auth.json`（所有者说本地有）；放在别处就设 `KEYFILE=<路径>`。**key 不进日志、不进回执、不进 git**（脚本已过滤 `sk-`） |
| 网络 | 第一次要下载 Olist 的九个 parquet（约 55 MB）到 `~/.cache/sunmoon-olist`，之后用缓存 |

## 二、跑

在 `~/worktrees/qwen/k8s` 下：

```bash
# 1) 冒烟：只跑演示那一题
bash sunmoonai/scripts/local-integration/workbench-finforecast.sh --case-ids ff-demo-forecast --limit 1
# 2) 十题
bash sunmoonai/scripts/local-integration/workbench-finforecast.sh
```

脚本默认参数：`--cases fin_forecast_10 --profile FIN_FORECAST --dataset-id olist-ecommerce --dialect duckdb --arms pack --limit 10 --budget 20`；你在命令后面加的参数覆盖默认值。整份输出各存一个文件：`k8s/sunmoonai/scripts/results/fin-forecast-3-local-smoke.<时间>.txt`、`…-full.<时间>.txt`。

## 三、看什么

1. 开头三行 VERDICT：样例的数据版本与评测题一致、MCP 列出工具（含 `list_datasets`）、MCP 列到样例数据集，都应是 `pass`。不是就停，贴原文。
2. 每题一行：`quality=… citation=… caveats=…`。**三栏都是 `pass` 才算这一题过**；十题过 ≥ 8 是这一段的线。
3. 演示题（`ff-demo-forecast`）跑完后，项目目录（脚本打印的 `ROOT`）里应有 `底稿/财务分析与预测-成稿.md` 和 `交回.md`。

## 四、回执（`k8s/sunmoonai/scripts/results/fin-forecast-3-local-<日期>.md`）

- 前提逐项核的结果；
- 冒烟与十题两次的原文（上面两个 txt 的路径，加上每题那一行的原文摘出来列成表）；
- 过了几题（三栏都过）、没过的每一题原因原文（报告里 `reasons` 那一列）；
- 演示题的 `底稿/财务分析与预测-成稿.md` 与 `交回.md` 全文；
- 报告文件 `investment-app/investment-backend/app/eval/reports/<时间>-fin_forecast_10.{md,json}`：在 investment-backend 子仓提交（以前的报告也是这么留的）；
- 各仓提交号。

原文输出，没做到的明说，不写「应该可以」。

## 五、规矩

- 不改专家包、方法、题、判定、脚本。脚本命令本身写错了（路径、拼写）可以改对了接着跑，在回执里写明原命令、改后的命令与原因；判据不能改。
- 没过线就照实交回，不要为了过线重跑挑结果；两次都跑了就两次都贴。Opus 看了原因再改方法。
- 预算到顶（`WAITING RESOURCE`）照实记，不要自己调大预算重跑；回执里写出是哪一题、花了多少。
