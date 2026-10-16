# 财务分析与预测 第 2 段（远程）回执——十道金标准题

> Opus，远程机，qwen 工位，2026-10-13。设计：`docs/dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md` 第六节、第五之二节。本段全在远程做，没有给 Qwen 的部分。

## 提交

| 仓 | 提交 | 内容 |
| --- | --- | --- |
| investment-backend（子仓） | `03fa39b` | `eval/cases/fin_forecast_10.json`、`eval/fixtures/olist-ecommerce.dataset.bin`、`eval/truth.py`（装载）、`tests/test_eval_fin_forecast.py` |
| investment-app（父仓） | `64eb994` | 子模块指针 |
| k8s | 本回执所在提交 | 回执、`0023` 第六节对上实际的题 |

## 停点逐项

| 停点 | 结果 |
| --- | --- |
| 十题进 `eval/cases/` | 十题、11 条真值查询，全在 1/20 样例上跑通，原文见下；演示题（第 9 题）与 PPT 上的数相同：三季度 151098.28（138205.61～163540.61），四季度 171794.07（133116.06～209121.06） |
| `run_eval.py` 能跑这组题 | **端到端没跑**：它要 PostgreSQL、Codex app-server，app-server 里还要接好知识服务的 MCP，这套第 3 段搭（远程机上 `pgtest` 与 Codex 0.155.1 都在，差模型 key）。本段核过它用到的每一块：`load_cases("fin_forecast_10")`、`find_pack("FIN_FORECAST")` 有、专家臂走 `ledger.handover` 不经网页的「筹备中」拦截、`TruthStore` 的 DuckDB 模式能装、`judge` 对这组题的判法（测试里逐条试过） |
| 投资后端三件套 | ruff 全过；pyright 4 个错，全在 `repository.py` 与 `workbench_routes.py`（本次没动，基线 `e73ffa5` 原有）；pytest 全量 775 过、273 跳过、0 失败 |

## 顺带改的：评测真值库的装载

`TruthStore` 在 DuckDB 模式下原来逐行 `executemany`：样例要 83 秒，全量 Olist 超过 10 分钟没装完。原因不在执行次数，是 DuckDB 把 Python 值逐个转进去慢（改成每批 500 行也要 28 秒，整列作列表参数也要 26 秒）。现在每张表先写临时 CSV，再由 DuckDB 的 `read_csv` 按建好的列类型读进来：字符串一律加引号、空值是不加引号的空字段、读时 `allow_quoted_nulls = false`，所以空串与空值不混；小数按 Python 最短精确写法写出。装完删临时文件，照旧关掉对外访问并锁配置。只改装载方式，判定一行没动；财报体检十三题的 44 个评测测试照过（6.5 秒 → 1.8 秒）。

## 真值原文（固定数据上，DuckDB 方言）

```text
version olist-ecommerce-dcca129e2ea0cb56
ff-gmv-monthly q-gmv-monthly 20 rows; first: {'period': '2017-01', 'gmv': 5811.130000000001, 'order_count': 33} last: {'period': '2018-08', 'gmv': 44372.02000000004, 'order_count': 332}
ff-gmv-quarterly-yoy q-gmv-quarterly 6 rows; first: {'period': '2017-Q1', 'gmv': 39239.26999999997} last: {'period': '2018-Q2', 'gmv': 190824.06000000026}
ff-state-top5 q-state-top5 5 rows; first: {'customer_state': 'SP', 'gmv': 281420.59000000014} last: {'customer_state': 'PR', 'gmv': 39673.28000000001}
ff-category-top10 q-category-top10 10 rows; first: {'product_category_name_english': 'health_beauty', 'item_revenue': 70402.21000000004} last: {'product_category_name_english': 'auto', 'item_revenue': 26236.00000000003}
ff-installment-share q-installment-share 1 rows; first: {'credit_card_installment_share': 0.6685894074462506} last: 
ff-cancel-monthly q-cancel-monthly 20 rows; first: {'period': '2017-01', 'cancel_rate': 0.0} last: {'period': '2018-08', 'cancel_rate': 0.005988023952095809}
ff-repeat-customers q-repeat-share 1 rows; first: {'repeat_customer_share': 0.0326522013903518} last: 
ff-demo-forecast q-demo-monthly 20 rows; first: {'period': '2017-01', 'gmv': 5811.130000000001} last: {'period': '2018-08', 'gmv': 44372.02000000004}
ff-demo-forecast q-demo-quarters 2 rows; first: {'period': '2018-Q3', 'forecast_point': 151098.28000000017, 'forecast_low': 138205.6100000002, 'forecast_high': 163540.61000000022} last: {'period': '2018-Q4', 'forecast_point': 171794.07000000012, 'forecast_low': 133116.0600000001, 'forecast_high': 209121.06000000017}
ff-backtest-orders q-backtest-forecast 1 rows; first: {'forecast_point': 286.5, 'forecast_low': 186, 'forecast_high': 391} last: 
ff-backtest-orders q-backtest-actual 6 rows; first: {'period': '2018-03', 'order_count': 328} last: {'period': '2018-08', 'order_count': 332}
```

## 装载核对原文（每张表与 SQLite 逐行比）

```text
1.sqlite: load 0.84s, tables 14, mismatched 0 []
sh600009-financials-v2.dataset.bin: load 0.10s, tables 11, mismatched 0 []
```

## 评测测试与三件套原文

```text
$ uv run pytest -q tests/test_eval_fin_forecast.py tests/test_eval_fin_review.py tests/test_eval_gates.py
...........................................................              [100%]
59 passed in 3.88s
$ uv sync --frozen
Checked 70 packages in 37ms
$ uv run ruff check .
All checks passed!
$ uv run pyright
  /home/zym/worktrees/qwen/investment-app/investment-backend/app/app/infrastructure/workbench/repository.py:1306:13 - error: Argument of type "bool" cannot be assigned to parameter "value" of type "str" in function "__setitem__"
  /home/zym/worktrees/qwen/investment-app/investment-backend/app/app/infrastructure/workbench/repository.py:1324:19 - error: Cannot access attribute "rowcount" for class "Result[Any]"
  /home/zym/worktrees/qwen/investment-app/investment-backend/app/app/infrastructure/workbench/repository.py:1331:22 - error: Cannot access attribute "rowcount" for class "Result[Any]"
  /home/zym/worktrees/qwen/investment-app/investment-backend/app/app/interfaces/endpoints/workbench_routes.py:866:9 - error: Argument of type "str | None" cannot be assigned to parameter "key" of type "str" in function "__init__"
4 errors, 0 warnings, 0 informations
$ uv run pytest -q（末尾）
sss....................................s                                 [100%]
775 passed, 273 skipped in 78.36s (0:01:18)
```

## 与原设计的出入（`0023` 已同步）

- 第 3 题去掉了占比列（`gmv_share` 不是口径名，候选起什么名字都可能，判不了），只比州与成交额。
- 第 9 题换成演示题：真值两条，走势与两个季度的预测；原来「9 到 12 月每月预测」的问法并入其中（每月点估计与区间是季度合计的输入）。
- 季度同比只在「必须提醒」里查有没有写出 155%，不进质量栏。

## 没做的

- `run_eval.py` 端到端（见上）。
- 273 个跳过我没核原因。
