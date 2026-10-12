# 给 Opus：把专家「财务分析与预测」做成真的（账 96）——你设计、带 Qwen 实施、审读；远程 Fable 最后合并与发布

> 所有者 2026-10-13 定：这位专家先在 fable 上开了头（专家包 `FIN_FORECAST`，`status: preparing`，五步照样子写了），接下来由你在 **qwen 工位**（`~/worktrees/qwen/*`，分支 `qwen`）把它做成真的。分工照远程 Fable 与 astra 的关系：**你**写设计、拆任务、审读、写回执；**Qwen** 在同一工位实施、跑测试、写回执；**远程 Fable** 不参与过程，做完后审一遍、合进 fable、发布。所有者负责同步、传话、真机演示。

## 一、起点（工位上已经有的）

| 东西 | 在哪 | 现状 |
| --- | --- | --- |
| 专家包 | `investment-app/investment-backend/app/app/domain/workbench/packs.py` 的 `FIN_FORECAST` | `status="preparing"`、版本 `0`；五步：定范围 → 取数 → 分析 → 预测 → 成稿（`output_file="底稿/财务分析与预测-成稿.md"`）；六问、底稿块、交回物字段词（`field_words.py`）都齐，能过专家包全部规矩测试 |
| 清单与页面 | 首页 / 专家首页 / 请专家页 | 都显示它，带「筹备中」标与一句说明；请不了（后端 `expert_on_offer` 对 `preparing` 回 409） |
| 已有的同类专家 | 同文件 `DATA_QUERY`（问数五阶段）、`FIN_REVIEW`（财报体检七步） | **照它们的写法**：`method_text` 英文给模型、`summary`/`why`/标签中文给用户、`acceptance` 用确定性规则、`tool_policy` 只能更严 |
| 数据与工具 | knowledge-app（摄入、口径、MCP）；MCP 工具现有 `list_datasets`、`describe_schema`、`metric_definitions`、`query_metric`、`run_sql` | 现有数据是 A 股财报（lesson23 那套）；**这位专家要的数据还没有** |
| 评测 | `investment-backend/app/eval/`（`cases/`、`truth.py`、`judge.py`、`run_eval.py`） | 问数与财报体检各有金标准题；这位专家还没有 |
| 设计稿 | `tree-build/SDD/modules/0009-semantic.md`（口径与 SQL 执行怎么走）、`0018-advisor-market.md`（专家市场、专家 = 知识库 + skill 的方向）、`0015-files-not-dossiers.md`（成稿落文件）、`approval.md`（工具级审批三档） | 读这四篇再动手 |

## 二、要做成什么

**用户视角**：在请专家页选「财务分析与预测」，问一句（例如「近两年按月的收入与毛利趋势，预测下两个季度」），专家按五步做完，项目目录里出现 `底稿/财务分析与预测-成稿.md` 和 `交回.md`，专家页能逐步看到它查了什么、算了什么、预测的假设与区间；不给买卖建议。

**数据底座**（所有者与 Qwen 已选定）：WrenAI legacy-v1 的巴西电商 Olist 样例，九张表（订单、明细、支付、商品、客户、卖家、评价、地理），远程文件在 `https://assets.getwren.ai/sample_data/brazilian-ecommerce/`；WrenAI 现成的 MDL（表关系、列说明）直接复用，不从零标注。先做这一套；A 股公司的财务预测以后再接，专家包的方法要写成**不绑定这一套数据**（口径、来源都从 `describe_schema` / `metric_definitions` 取）。

## 三、分段与停点（每段 Qwen 做完写回执、你审过才进下一段）

| 段 | 做什么 | 停点怎么算过 |
| --- | --- | --- |
| 1 数据 | Olist 九张表进 knowledge-app（摄入脚本、数据集登记、版本号、口径表、表关系）；MCP 的 `list_datasets` / `describe_schema` / `run_sql` 对它能用；写清许可证（Olist 是 CC BY-NC-SA 4.0，只作演示与评测，页面上注明） | 在本机起 knowledge 后端，用现有 MCP 测试脚本列到数据集、查到表结构、跑通一条按月收入 SQL；回执带原文输出 |
| 2 评测题 | 10 道金标准（营收趋势、区域对比、品类利润率、分期比例、取消率、两道预测题）：问题、期望的数或区间、判定方法，进 `eval/cases/` | `run_eval.py` 能跑这组题（专家包还是占位时允许全不过，但题要能跑） |
| 3 方法 | 填 `FIN_FORECAST` 五步的 `method_text`、`tools`、`output_schema`、`acceptance`、`missing_data`、`reserve`；预测那一步的方法要**简单、能说清**（移动平均 / 季节性朴素法 / 线性趋势，三选一并写明为什么），区间与假设必须在交回物里；成稿那一步按 0015 的写法要求（回答、数据带角标、验过什么、局限、出处；不贴 JSON） | 专家包规矩测试全过（`tests/test_workbench_pack_view.py`、`test_workbench_now_view.py`、`test_fin_review_pack.py` 那类）；用真 Codex 对本机 knowledge 跑一遍五步，10 题过 ≥ 8 |
| 4 切真 | `status` 改 `ready`、版本改 `1`、`title` 去掉「筹备中」、`preparing_note` 清空；前端不用改 | 后端全量测试过；回执里附一次完整委托的事件摘要与成稿文件 |

## 四、规矩

- 只在 qwen 工位、qwen 分支做；涉及的仓：`investment-app/investment-backend`（专家包、评测）、`knowledge-app/knowledge-backend`（摄入、MCP）。**子仓先提交、父仓后提交**；不 push 到别的分支；不合并 fable；所有者用 `-all` 同步。
- 不改别的专家包、不改专家包的机制（`StepContract`、`judge`、`Advisor`、审批三档）；真要改机制，先停下写清楚，由所有者转给远程。
- 用户看得到的字里没有代号、没有 JSON 字样、没有买卖建议（现有测试会拦）。
- 每段一个回执：`k8s/sunmoonai/scripts/results/fin-forecast-<段>-<日期>.md`，原文输出、没做到的明说、不写「应该可以」。你的设计写 `tree-build/SDD/modules/0023-fin-forecast.md`，给 Qwen 的任务页放 `switch-test/inbox/qwen/`。
- 数据文件、下载的 parquet、模型 key 不进 git；评测用的 key 由所有者给、放 0600 文件。
- 做完对所有者说一句「财务分析与预测做好了」；远程审读合并，发布走 Cursor 的发布卡（只从 fable 发）。

## 五、远程合并时会看什么

专家包规矩测试与后端全量过；评测 ≥ 8/10 的原文；MCP 工具对新数据集的测试原文；用户字面没有代号；`field_words` 补齐；许可证注明；`0023` 与回执齐。看过就合进 fable，不再改你们的实现。
