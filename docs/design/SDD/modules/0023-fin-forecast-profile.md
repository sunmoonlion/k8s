# 专家包 `FIN_FORECAST` 第 2 版：逐步说明

> 这一份把**现在上架的**「财务分析与预测」专家包（profile）原样摊开：每一步给用户看什么、喂给模型什么方法、用什么工具、交回什么、怎么验收、不过去哪。真源是代码 `knowbench-backend/app/app/domain/workbench/packs.py` 里的 `FIN_FORECAST`（2026-10-15 按投资后端 `a6e6ceb` 整理）；两边不一致时以代码为准。为什么这样设计见 [`0023-fin-forecast.md`](0023-fin-forecast.md)，评测真值见 [`0023-fin-forecast-answer-key.md`](0023-fin-forecast-answer-key.md)。
>
> **第 3 版已定方向**（[决策](../../decisions.md)「专家收成一位」）：改名「中国A股上市公司财务分析与预测」，吸收财报体检，只做 A 股上市公司，Olist 下掉，演示贵州茅台，预测改为带季节性的方法。第 3 版做出来后本文随之重写；第 8 节先列出要改的地方。

## 1. 概况

| 项 | 值 |
| --- | --- |
| 代号 / 版本 | `FIN_FORECAST` / `2`（新委托绑定委托时上架的版本） |
| 给用户看的名字 | 财务分析与预测 |
| 标题 | 财务分析与预测（先定口径，再看走势，带区间预测） |
| 一句话 | 看清收入、成本、现金流的走势，给出可核对的预测 |
| 状态 | 上架（`ready`）；要调知识工具（`requires_tools`） |
| 步骤 | 定范围 → 取数 → 分析 → 预测 → 成稿（五步，顺序定死，不能跳步） |
| 第 2 版支持的数据 | 只支持「按期汇总」的经营数据（口径 `kind=aggregate`，例如 Olist 电商样例）；财报类（`kind=row`）不支持 |

请专家页上的「六问」：

| 问 | 答 |
| --- | --- |
| 解决什么 | 对一份已入库的经营或财务数据，按定死的口径看清过去的走势与结构，并用说得清的方法给出带区间、带假设、先回测的预测 |
| 不解决什么 | 估值、评级、买卖建议；数据里没有的口径（例如没有成本就不算毛利）；复杂的统计模型 |
| 输入 | 一个问题，例如：近两年按月收入怎么走，预测下两个季度 |
| 输出 | 成稿：回答、取数表（每列带出处）、分析发现、预测表（方法、区间、假设、回测）、局限、出处 |
| 谁做判断 | 用户。专家只摆数、说走势、给带假设的预测 |
| 失败怎么办 | 找不到能回答的数据集或范围认不出时停下问你；分析不过退回取数一次；预测不合格不返工，直接交你看 |

## 2. 每步都带的共同规则

方法原文是英文（给模型）；页面上给用户看的是每步的 `summary`、`why` 与验收项的中文标签。下面几段规则拼进各步的方法里：

| 规则段 | 意思 | 用在 |
| --- | --- | --- |
| `_FC_DATASET` | 每次调知识工具都必须带 `dataset=<scope.dataset>`，绝不查默认数据集 | 取数、分析、预测 |
| `_FC_SQL` | **所有计算都在 SQL 里做**（求和、均值、最小最大、比率、增速），不心算；计算列用口径表里的 `metric_name` 作别名（例如 `AS gmv`），期间列叫 `period`，期间按 `dataset_metadata.period_formats` 写（月 `YYYY-MM`、季 `YYYY-Qn`）；比率保留 0 到 1 的小数、SQL 里不四舍五入；维度列用原字段名 | 取数、分析、预测 |
| `_FC_PERIODS` | 只用完整期间：数据集声明了 `complete_start`、`complete_end` 就严格用这一段；没声明就把首尾两端量低于其余各期中位数一半的期认作不完整，并写明是这样认的；不完整的期绝不读成下滑 | 取数 |
| `_FIN_NUMBERS` | 数只能来自本步工具结果或上游交回物，不回忆、不估 | 取数、分析、预测 |
| `JSON_ONLY` | 只回一个 JSON 对象，前后不加说明、不加代码块围栏；本步没说要写文件就不改任何文件 | 全部五步 |
| `DELIVERABLE_RULES` | 成稿写成给用户看的 Markdown，按「回答、数据（每个数带出处、期间、口径与角标）、专家验过什么、局限、出处」的顺序；不给评级、目标价、买卖建议；不贴原始 JSON | 成稿 |

## 3. 工具与审批

**知识工具**（经 MCP，由 knowbase 提供，服务端按沙箱令牌鉴权）：`list_datasets`（有哪些数据集）、`describe_schema`（表与列）、`metric_definitions`（口径表：名字、类型、计算式、过滤条件、为什么没有）、`run_sql`（只读 SQL）。每步只列它用得到的。

**工具级审批**（专家包的三档表，用的是默认值，各步没有另行收紧）：

| 动作 | 怎么处理 |
| --- | --- |
| 改项目目录里的文件 | 放行 |
| 改项目目录外的文件 | 拒绝 |
| 跑命令 | 每条问你 |
| 联网 | 拒绝 |
| 模型反过来问你（`request_user_input`） | 允许，每步最多 3 问；问不到就写明假设继续 |

**每步的额度**：上游交回物放进本步输入的字符上限 24000（超出会注明）；本步预留预算 0.05（币种随委托）。

## 4. 五步一览

| 步 | 给用户看的一句话 | 输入 | 工具 | 交回物 | 不过去哪 |
| --- | --- | --- | --- | --- | --- |
| 1 定范围 `scope` | 认出数据集，把问题落到口径、期间和粒度上；说不清是哪家就先问你，数据里没有的口径照实列出 | 用户的问题 | 四个都用 | `scope` | 交人，不返工 |
| 2 取数 `pull` | 按口径把每期的数取出来，每列写明出自哪张表、什么口径；不完整的期排除并说明 | `scope` | `describe_schema`、`run_sql` | `series` | 本步重做 1 次，再不过交人 |
| 3 分析 `analyze` | 看走势、结构和季节性，每条发现都带它依据的数和查询 | `scope`、`series` | `run_sql` | `analysis` | 不在本步重做，退回取数 1 次，回来仍不过交人 |
| 4 预测 `forecast` | 按固定的方法外推：先回测看误差，再给每期的预测值、区间和假设；残缺的季度用实际加预测 | `scope`、`series`、`analysis` | `run_sql` | `forecast` | 交人，不返工 |
| 5 成稿 `writeup` | 把范围、取数、发现、预测写成一篇可核对的稿子，落到项目文件里 | 前四步全部 | 不调数据工具，只写文件 | `note` + 成稿文件 | 本步重做 1 次，再不过交人 |

验收全是确定性规则（不调模型判）；一步通过才进下一步。

## 5. 逐步

### 5.1 定范围 `scope`

**为什么**（页面上一直摆着）：口径先定，后面的数和预测才有意义；同一个问题，口径不同，答案可以差一倍。说不清是哪家、或找不到能回答的数据，就停下问你。

**方法**：
1. 调 `list_datasets`，对列出的每个数据集调 `metric_definitions`。本版只支持按期汇总的口径（`kind=aggregate`，例如销售、订单数据），不支持财报类（`kind=row`）。只留下对问题有 `aggregate` 口径的数据集。
2. 在留下的里面选：问题点了公司或数据集的名，就用那个；没点名（例如「这个公司」「它」）且恰好一个合适，就用它，并在 `assumptions` 写明；多个合适就问你选哪个（选项是数据集标题）；一个都不合适，或者问的东西只在财报类数据集里，就把 `dataset` 置空、写明原因、停下——绝不用不合适的数据集。
3. 选定后每次调用都带 `dataset=<它>`：读 `dataset_metadata` 全部行，把关于期间、截断、缺数据、主键、状态规则的说明**原文**抄进 `notes`；调 `describe_schema`。
4. 把问题落到 `metric_definitions` 返回的口径上，逐个列进 `metrics`（名字与 `kind` 照抄，缺 `kind` 写 `unknown`），只用那里存在的名字。问题要的量，凡是口径表里标 `kind=unavailable` 或根本没有定义的，进 `unavailable` 并写原因，绝不拿别的字段顶替。
5. `period` 定成问题要的范围和粒度，不比数据存的粒度更细。问题没给范围或给得含糊（例如「近两年」），就用 `complete_start` 到 `complete_end` 并写明；数据集没声明完整期，最多用最近 36 期并写明。把 `complete_start`、`complete_end` 抄进 `complete_period`。
6. 问题要预测，就把要预测的期放进 `forecast.horizon`（「下一个 / 下两个季度」= 最后一个完整季度之后的季度，只完整了一部分的季度算第一个）；不要预测就置空。口径表已经说清的定义不问你，把自己的理解写进 `assumptions`。

<details><summary>方法原文（英文，给模型）</summary>

```text
Turn the user's question into a fixed scope before any number is used. 1) Call list_datasets, and metric_definitions for each dataset listed. This version supports only datasets whose metrics are aggregated per period (kind=aggregate), such as sales or order data; it does not support financial statement datasets whose metrics are computed per report row (kind=row). Keep only the datasets that have kind=aggregate metrics for what the question asks. 2) Choose among the kept datasets. If the question names the company or the dataset, take that one. If it does not (for example 这个公司 or 它) and exactly one kept dataset fits, take it and say so in `assumptions`. If more than one fits, ask the user which one, with the dataset titles as the options, and use the answer. If none fits, or what the question asks is only in a financial statement dataset, set `dataset` to null, say why in `assumptions` and stop; never use a dataset that does not fit. 3) With dataset=<that dataset> on every call: read dataset_metadata (all rows) and copy into `notes`, verbatim, every note about periods, truncation, missing data, keys and status rules; call describe_schema. 4) Map the question onto metrics returned by metric_definitions and list each in `metrics` with its name and its kind copied exactly as returned (a missing kind is written as unknown); use only names that exist there. Every quantity the question asks for whose definition has kind=unavailable, or that has no definition at all, goes into `unavailable` with the reason; never substitute another field for it. 5) Set `period` to the range and grain the question asks for, never finer than the data is stored in. If the question names no range, or a vague one such as 近两年, use complete_start to complete_end and say so in `assumptions`; if the dataset declares no complete period, use at most the latest 36 periods and say so. Copy complete_start and complete_end into `complete_period`. 6) If the question asks for a forecast, put the periods to forecast in `forecast.horizon` (for the next quarter or quarters: the quarters after the last complete quarter, counting a quarter that is only partly complete as the first); otherwise set `forecast` to null. Do not ask the user about definitions that metric_definitions settles; state your reading in `assumptions`. + JSON_ONLY
```

</details>

**交回物 `scope`**：

| 字段 | 内容 |
| --- | --- |
| `question` | 问题 |
| `dataset` | 选定的数据集，或空 |
| `data_version` | 工具报的数据版本 |
| `period` | `{start, end, grain}`，例如 `2017-01` 到 `2018-08`，按月 |
| `complete_period` | 数据集声明的完整期 `{start, end}` |
| `metrics` | `[{name, kind}]`，名字取自口径表 |
| `unavailable` | `[{name, reason}]`，问了但数据里没有的口径 |
| `forecast` | `{horizon: ["YYYY-Qn", …]}` 或空 |
| `notes` | `dataset_metadata` 里的说明原文 |
| `assumptions` | 自己的理解与假设 |

**验收**：交回的格式对；有数据集、数据版本、期间、口径；认出了能回答的数据集（`dataset` 非空）；有数据版本；问题落到了口径上（`metrics` 至少一项）；口径都是按期汇总的（全部 `kind=aggregate`，否则报「这份数据不是按期汇总的经营数据：本版只支持这一类，财报类请用财报体检」）。

**不过**：直接交你（`on_reject=human`，不返工）。没有数据集或数据不对路，重做也不会变好。

### 5.2 取数 `pull`

**为什么**：后面的分析和预测都建立在这张表上：每列从哪来、怎么算，先摆出来给你核对。

**方法**：对 `scope.metrics` 里的每个口径，按 `scope.period` 和粒度逐期取，严格照口径的定义（计算式与行过滤）写；每期一行、每个口径一列；`scope.period` 里不完整的期列进 `excluded_periods` 并写原因，不放进 `rows`；`columns` 给出每列的名字、中文名、来源（表、字段、过滤）；执行过的每条 SQL 都放进 `sql`。另带 `_FC_DATASET`、`_FC_SQL`、`_FC_PERIODS`、`_FIN_NUMBERS`、`JSON_ONLY`。

<details><summary>方法原文</summary>

```text
Pull the series the scope needs. + _FC_DATASET + For each metric in scope.metrics (by its name), query it per period over scope.period at scope.period.grain, never splitting data into a finer grain than it is stored in, following its definition (expression and row_filter) exactly. Return one row per period with one column per metric. List every period inside scope.period that is not complete in `excluded_periods` with the reason, and leave it out of `rows`. In `columns` give, for each column, its name, its display name and its source (table, field and filter). Put every SQL statement you ran in `sql`. + _FC_SQL + _FC_PERIODS + _FIN_NUMBERS + JSON_ONLY
```

</details>

**交回物 `series`**：`columns`（`[{name, display_name, source}]`）、`rows`（`[{period, <口径名>: 数}]`）、`excluded_periods`（`[{period, reason}]`）、`sql`（执行过的全部语句）、`data_version`。

**验收**：格式对；有列说明、取数结果、排除的期、查询语句、数据版本；取到了数（`rows` 至少一行）；交回了执行过的查询语句；有数据版本。

**不过**：本步重做 1 次（`on_reject=rework`、`max_reworks=1`），再不过交你。

### 5.3 分析 `analyze`

**为什么**：先把过去说清楚，预测才有依据；每条发现都能回到数据上核对。

**方法**：用取数结果，需要时再补查：① 走势：逐期环比；去年同期在范围内的再算同比；② 结构：只在问题需要时做，按地区、品类的占比及其变化；③ 季节性：序列覆盖至少两个完整年度才谈，不够就写一条发现说明「这份数据判断不了」。每条发现写明事实、依据的数、算出这些数的 SQL；至少两条；**只描述，不评价好坏**。另带 `_FC_DATASET`、`_FC_SQL`、`_FIN_NUMBERS`、`JSON_ONLY`。

<details><summary>方法原文</summary>

```text
Describe the past before anyone forecasts it. + _FC_DATASET + Using the series, and further queries where needed: 1) trend: change from period to period and, where the same period a year earlier is in range, year on year; 2) structure, only where the question needs it: shares by region or category and how they changed; 3) seasonality only if the series covers at least two complete years; otherwise say in a finding that it cannot be judged from this data. Each finding states the fact, the numbers it rests on, and the SQL that produced those numbers. At least two findings. Describe only; do not say whether something is good or bad. + _FC_SQL + _FIN_NUMBERS + JSON_ONLY
```

</details>

**交回物 `analysis`**：`findings`（`[{text, numbers, sql}]`）、`data_version`。

**验收**：格式对；有分析发现；至少两条发现。只查格式与条数，查不了发现里的数是否真由那条 SQL 算出——这是五步里最松的一处（第 3 版收紧，见第 8 节）。

**不过**：不在本步重做，直接退回取数（`on_reject=back`、`back_to=pull`、`max_reworks=0`）；最多退回 1 次（`max_backs=1`），回来仍不过交你。分析不过多半是取的数有问题，所以退回取数而不是原地重写。

### 5.4 预测 `forecast`

**为什么**：预测一定带区间和假设，只给一个数等于没说；方法写死、不合格不返工，不让模型改方法凑结果。

**方法：移动平均**（只许用这一种）：
1. 完整期取自 `scope.complete_period` 与 `series.excluded_periods`。窗口 = 最近 6 个完整期；不足 6 用全部完整期；**不足 3 不预测**（`rows` 留空，在 `method`、`assumptions` 写明原因）。
2. **先回测**（完整期 ≥ 12 才做）：把窗口整体前移 6 期，用同一规则预测其后 6 期，与实际比，报平均绝对百分比误差与「落在区间内的期数」；不够 12 期则 `backtest` 置空并写明原因。
3. **外推**：每个预测期的点估计 = 窗口均值；区间 = 窗口最低到最高。从最后一个完整期之后的第一期开始；数据里有但不完整的期按预测处理，不读它。
4. **季度**：季度点估计 = 三个月点估计之和，区间 = 三个月下限之和到上限之和；季度里已有完整月份的，用实际值代替那几个月的预测，并列进 `actual_months`。
5. 全部在 SQL 里算，列名 `forecast_point`、`forecast_low`、`forecast_high`，期间列 `period`。至少两条假设（例如「近期水平延续」「没有新的大促、政策或口径变化」）；不许把预测说成确定、承诺或目标。

另带 `_FC_DATASET`、`_FC_SQL`、`_FIN_NUMBERS`、`JSON_ONLY`。为什么选移动平均而不是「去年同期」或「线性趋势」，见 [`0023-fin-forecast.md`](0023-fin-forecast.md) 第 5.3 节。

<details><summary>方法原文</summary>

```text
Forecast with the fixed method below; do not choose another method. + _FC_DATASET + Method: moving average. 1) Complete periods come from scope.complete_period and series.excluded_periods. The window is the 6 latest complete periods; if fewer than 6 exist use all of them; if fewer than 3 exist, do not forecast: leave `rows` empty and say why in `method` and `assumptions`. 2) Backtest first when there are at least 12 complete periods: move the window back by 6 periods, forecast the 6 periods after it with the same rule, compare with the actual values, and report the mean absolute percentage error and how many actual values fall inside the range. Otherwise set `backtest` to null and say why in `assumptions`. 3) For each period in the horizon, the point forecast is the average of the window and the range is the minimum and the maximum of the window. The forecast starts at the first period after the last complete period; a period that exists in the data but is incomplete is forecast, not read. 4) Quarters: a quarter's point is the sum of its monthly points and its range is the sum of the monthly lows and highs; a quarter with complete months adds their actual values instead of forecasts for those months, and lists them in `actual_months`. Compute everything in SQL; name the columns forecast_point, forecast_low and forecast_high, and the period column period. Give at least two assumptions (for example: the recent level persists; no new promotion, policy or definition change). Never call a forecast certain, a promise or a target. + _FC_SQL + _FIN_NUMBERS + JSON_ONLY
```

</details>

**交回物 `forecast`**：`method`；`window`（`{start, end, count}`）；`excluded_periods`；`assumptions`；`rows`（`[{period, forecast_point, forecast_low, forecast_high}]`）；`quarters`（`[{period, forecast_point, forecast_low, forecast_high, actual_months}]`）；`backtest`（`{window, mape, inside, total}` 或空）；`sql`；`data_version`。

**验收**：格式对；有方法、窗口、假设、预测值、回测、查询语句；至少两条假设；有预测值；交回了执行过的查询语句。

**不过**：直接交你（`on_reject=human`、`max_reworks=0`），不让模型换方法凑出一个能过的结果。

### 5.5 成稿 `writeup`

**为什么**：给你的是一篇能逐条核对的稿子：数都有出处，预测带区间和假设，缺的数据和截断照实写进局限。

**方法**：只用上游交回物写中文成稿，不调任何数据工具（唯一的工具动作是写文件）。`answer` 先用大白话回答：走势；要了预测的，给每个预测期的点估计与区间，加一句方法。`limitations` **必须**有：`scope.unavailable` 的每一项及原因；每个被排除或不完整的期及原因；预测假设近期水平延续，以及回测误差（或为什么没有回测）；`scope.notes` 里限制解读的说明。`citations` 写数据集、标题、数据版本。不给估值、评级、目标价、买入卖出持有的建议；预测是外推，不是承诺或目标。成稿文件里写全：回答、带出处的取数表、发现、预测表（方法、窗口、假设、回测）、局限、出处。另带 `DELIVERABLE_RULES`、`JSON_ONLY`。

<details><summary>方法原文</summary>

```text
Write the deliverable in Chinese from the input artifacts only; do not call any data tool (writing the files is the only tool use). `answer` answers the question in plain words first: the trend and, when a forecast was asked, the point and the range for each forecast period with the method in one sentence. `limitations` MUST contain: every item of scope.unavailable with its reason; every excluded or incomplete period with its reason; that the forecast assumes the recent level persists, with the backtest error (or why there was no backtest); any note in scope.notes that limits the reading. `citations` name the dataset, its title and the data version. No valuation, rating, target price, or advice to buy, sell or hold; a forecast is an extrapolation, never a promise or a target. The deliverable file holds the full write-up: answer, the series with sources, the findings, the forecast table with method, window, assumptions and backtest, limitations and sources. + DELIVERABLE_RULES + JSON_ONLY
```

</details>

**交回物 `note`**：`answer`、`limitations`、`citations`、`data_version`（结构化的这份回在正文里做机器验收）；**给你看的是写到项目目录里的成稿文件**（见第 6 节）。

**验收**：格式对；有回答、局限、出处、数据版本；回答不是空的；写了局限；有出处；**没有评级、目标价、买卖建议的措辞**（`no_positioning_advice`）；成稿不超过 30000 字。

**不过**：本步重做 1 次，再不过交你。

## 6. 底稿与文件

**专家页上的底稿**（从各步交回物里取，按区块摆）：

| 区块 | 取自 | 放在 |
| --- | --- | --- |
| 回答 | 成稿 `answer` | 回答 |
| 取数表 | 取数 `rows`，带列说明与数据版本 | 数据 |
| 预测表 | 预测 `rows`，带方法、假设、窗口 | 数据 |
| 按季度合计 | 预测 `quarters` | 数据 |
| 分析发现 | 分析 `findings` | 专家验过什么 |
| 局限 | 成稿 `limitations` | 局限 |
| 出处 | 成稿 `citations` | 出处 |

**项目目录里的文件**（2026-10-14 起按对话、按次分开存，不覆盖）：`底稿/对话-<对话号前 8 位>/<北京时间 年-月-日-时分秒>-财务分析与预测/` 下，一份 `财务分析与预测-成稿.md`，最后一份 `交回.md`（做了什么、什么已核实、什么未知、工作区怎么恢复）。文件在用户电脑上，是真源；网页「工作底稿」栏经本机代理的回环口读。

## 7. 什么时候停下来问你

| 时机 | 怎么停 |
| --- | --- |
| 有多个数据集都合适 | 定范围时问你选哪个（选项是数据集标题） |
| 找不到能回答的数据集、范围认不出、数据不是按期汇总的 | 定范围不过，交人 |
| 取数两次都不过 | 交人 |
| 分析不过、退回取数一次仍不过 | 交人 |
| 预测不合格 | 不返工，交人 |
| 成稿两次都不过 | 交人 |
| 要跑命令 | 每条问你；改项目外文件一律拒绝；不联网 |
| 模型自己有疑问 | 弹出提问，每步最多 3 问；问不到就写明假设继续 |

## 8. 第 3 版要改的（已定方向，设计另写）

| 处 | 第 2 版 | 第 3 版 |
| --- | --- | --- |
| 名字 | 财务分析与预测 | 中国A股上市公司财务分析与预测 |
| 数据 | 只支持按期汇总（Olist） | 只支持 A 股上市公司财报（三张表 + 官方关键数据），演示贵州茅台；Olist 下掉 |
| 定范围 | 按问题挑数据集 | 按证券代码找；没入库走「申请入库」 |
| 步骤 | 五步 | 吸收财报体检：定范围 → 数据摸底 → 勾稽 → 取数 → 算指标与分析 → 对照官方披露 → 预测 → 成稿 |
| 取数 | 按月汇总 | 季报是年初至报告期末的累计数，换算成单季（二季度 = 中报 − 一季报，四季度 = 年报 − 三季报）；说清用调整前还是调整后 |
| 分析 | 只分析问题点到的口径：走势、结构、季节性（Olist 不够两年，季节性基本判断不了） | 问题点到的科目 + 固定核心指标：营业收入、归母净利润、扣非净利润、经营现金流；毛利率、净利率、净资产收益率、经营现金流与净利润之比、收入与利润增速。十年季度数据可以真的看季节性 |
| 分析的验收 | 只查格式与条数 | 收紧：例如每条发现里的数必须出现在本步工具返回的结果里 |
| 预测 | 移动平均；一次委托实际只预测一个量 | 只预测少数流量主项：营业收入、归母净利润（问题点名的再加别的流量科目），各自回测、各给区间与假设；比率由预测出的收入与利润推算，不单独外推；不逐科目预测整套报表（三表配不平）。方法带季节性，拿茅台数据回测几种后定；不变的是方法写死、全在 SQL、先回测再外推、给区间和假设、不合格交人 |
| 评测 | `fin_forecast_10`（Olist） | 按茅台重建；问数题里检验 SQL 的部分挑几道并进来 |
| 问数、财报体检 | 各自上架 | 下架（不能新建委托，历史可看），代码先不删 |
