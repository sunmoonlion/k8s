# 财务分析与预测 第 3 段（远程部分）回执——专家包五步与本地跑分脚本

> Opus，远程机，qwen 工位，2026-10-13。设计：`0023-fin-forecast.md` 第五节。真 Codex 与真模型 key 的运行归本地（所有者 2026-10-13 定），任务页 `switch-test/inbox/qwen/qwen-002.md`，Qwen 的回执另写 `fin-forecast-3-local-<日期>.md`，由 Opus 审。**本段的线（十题过 ≥ 8）要等那份回执。**

## 提交

| 仓 | 提交 | 内容 |
| --- | --- | --- |
| investment-backend（子仓） | `8e80e28` | `packs.py` 的 `FIN_FORECAST` 五步、`field_words.py`、`tests/test_fin_forecast_pack.py` |
| investment-app（父仓） | `969f72b` | 子模块指针 |
| k8s | 本回执所在提交 | `workbench-finforecast.sh`、`qwen-002.md`、`0023` 失败去向的执行顺序、本回执 |

PPT 第 7 页同步改了两格失败去向（取数「重做 1 次后交你」、成稿「重做 1 次后交你」、分析「退回取数一次」），已写回 `~/财务分析与预测智能体/财务分析与预测智能体.pptx`。

## 专家包现在的样子（从代码导出）

```text
== FIN_FORECAST v0 status=preparing requires_tools=True name=财务分析与预测
   pack tool_policy: {'file_change_in_project': 'allow', 'file_change_outside': 'deny', 'command': 'ask', 'command_allow': (), 'network': 'deny', 'questions': 'allow', 'max_questions': 3}
   scope      定范围    tools=['list_datasets', 'describe_schema', 'metric_definitions', 'run_sql'] in=[] out=scope reject=human reworks=0 backs=1 rules=['json_object', 'required_keys', 'non_empty', 'non_empty', 'list_min'] missing= ask=[] policy= file= mt_len=1584
   pull       取数     tools=['describe_schema', 'run_sql'] in=['scope'] out=series reject=rework reworks=1 backs=1 rules=['json_object', 'required_keys', 'list_min', 'list_min', 'non_empty'] missing= ask=[] policy= file= mt_len=1715
   analyze    分析     tools=['run_sql'] in=['scope', 'series'] out=analysis reject=back->pull reworks=0 backs=1 rules=['json_object', 'required_keys', 'list_min'] missing= ask=[] policy= file= mt_len=1497
   forecast   预测     tools=['run_sql'] in=['scope', 'series', 'analysis'] out=forecast reject=human reworks=0 backs=1 rules=['json_object', 'required_keys', 'list_min', 'list_min', 'list_min'] missing= ask=[] policy= file= mt_len=2409
   writeup    成稿     tools=[] in=['scope', 'series', 'analysis', 'forecast'] out=note reject=human reworks=1 backs=1 rules=['json_object', 'required_keys', 'non_empty', 'list_min', 'list_min', 'no_positioning_advice', 'max_chars'] missing= ask=[] policy= file=底稿/财务分析与预测-成稿.md mt_len=1552
```

## 与设计对齐时发现的两件事

1. **失败去向的执行顺序**（`advisor.py`）：先用本步的返工额度，用完再看退回，最后交人。所以「不过直接交人」必须 `max_reworks=0`。分析一步原来默认有 1 次返工，会先重做再退回；按设计与 PPT 改成 `max_reworks=0`，不过直接退回取数。成稿保留 1 次返工（补局限、出处，没有凑数的风险，与财报体检一致），设计与 PPT 改成「重做 1 次后交你」。
2. **占位版的验收不起作用**：`non_empty`、`list_min` 只认 `path`，占位版写的是 `keys`，结果成稿的「有正文」永远判过、分析的「至少一条发现」永远判不过。正式版全部用 `path`，并有测试逐条验。

## 测试与三件套

```text
$ uv run pytest -q tests/test_fin_forecast_pack.py tests/test_workbench_pack_view.py tests/test_workbench_now_view.py tests/test_fin_review_pack.py tests/test_eval_fin_forecast.py
133 passed in 1.86s
$ uv run ruff check .
All checks passed!
$ uv run pyright
4 errors, 0 warnings, 0 informations
$ uv run pytest -q（末尾）
805 passed, 273 skipped in 48.16s
```

pyright 的 4 个错仍是 `repository.py` 与 `workbench_routes.py` 里原有的（第 2 段回执已记）。

## 本地跑分脚本，远程先验了能验的部分

`workbench-finforecast.sh` 由 `workbench-dataquery.sh` 改出：数据集换成知识服务生成的 1/20 样例（脚本里现生成，并核 `data_version` 必须是 `olist-ecommerce-dcca129e2ea0cb56`）、知识 MCP 打开语义层（DuckDB 方言，与题的真值一致）、默认只跑专家臂十题、预算 20（上次问数专家臂在预算 8 时停在 `WAITING RESOURCE`）。

远程用同样的环境变量起了一次知识服务的 MCP 最小应用（不需要模型 key）：

```text
tools: list_datasets,describe_schema,metric_definitions,run_sql,query_metric
list_datasets: False [('olist-ecommerce', 'olist-ecommerce-dcca129e2ea0cb56', '巴西电商 Olist 样例（1/20 抽样，演示与评测用，CC BY-NC-SA 4.0）')]
run_sql(quarter, duckdb //): False [{'period': '2018-Q2', 'gmv': 190824.06000000026}] olist-ecommerce-dcca129e2ea0cb56
```

只跑专家臂时 `run_eval.py` 照常出报告，发布门那一项为空（它要基线臂与专家臂都有）；本段的线按每题三栏判。

## 没做的

- 真 Codex 跑五步、十题：归本地（`qwen-002`）。
- 沙箱、会合点、本地代理那几段没在远程起：它们和问数那条链一样，脚本没改。
