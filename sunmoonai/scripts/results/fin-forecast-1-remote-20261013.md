# 财务分析与预测 第 1 段（远程部分）回执——Olist 1/20 样例进 knowledge

> Opus，远程机，qwen 工位，2026-10-13。设计：`sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md` 第二之二、三、四节。Opus 主导；本机 KIND 联调链那一截在 `switch-test/inbox/qwen/qwen-001.md`，Qwen 的回执另写 `fin-forecast-1-local-<日期>.md`，由 Opus 审。
> 本回执取代同名文件的上一版（那一版是全量数据：文件 109 MB、`data_version` `olist-ecommerce-5f4af057bf031216`，在 git 历史里）。所有者同日定「只要一个完整的示例数据集」、按 1/20 抽样，数据集改为样例后本段重做了一遍。

## 提交

| 仓 | 提交 | 内容 |
| --- | --- | --- |
| knowledge-backend（子仓） | `94a3a72` | 第一版：定义、生成脚本、测试、文档（全量） |
| knowledge-backend（子仓） | `e30525f` | 改为按真实客户 1/20 抽样；地理表按前缀汇总；生成器版本 2 |
| knowledge-app（父仓） | `f7e5aba`、`d049070` | 子模块指针跟上两次 |
| k8s | 本回执所在提交 | 回执、`0023` 第二之二节与第三节、`qwen-001` 的对照数 |

知识服务的运行代码（`app/app/` 下）一行没改。

## 停点逐项

| 停点 | 结果 |
| --- | --- |
| 知识后端三件套 | ruff：只有 1 条，是**原有的** `tests/test_kernel_invariants.py:90` 行宽（基线 `548e84a` 与 fable 上同样，本次没动这个文件）；新加的文件 ruff 干净。pyright 0 错误。pytest 全量 808 过、174 跳过、0 失败；新测试 9 过 |
| 生成脚本对真实数据跑两次 | 两次 `data_version` 都是 `olist-ecommerce-dcca129e2ea0cb56`，文件 sha256 也逐字节相同；每次约 4 秒，文件 3858432 字节 |
| 经知识服务的 MCP 处理链列到、查到、跑通按月成交额 | 11 项全过，原文见下 |

**样例长什么样**：4917 单、4747 个真实客户、5587 条明细、地理表 4147 行（每个邮编前缀一行）；没有悬空引用（明细→订单、订单→客户、明细→商品各查过一遍，都是 0）。连续完整月份 2017-01 到 2018-08，2018-09 只有 1 单（已取消）。

**MCP 核对怎么做的**：没有起 HTTP 服务（那是本机联调链的事），用的是知识服务自己的 `KnowledgeMcp.handle`（与 `tests/test_semantic_mcp.py` 同一种起法）：语义层开着，默认数据集用仓里的 600009 夹具，样例按真实登记的形状放进登记表（登记表与取文件两处用测试里现成的替身 `MemoryRegistry`、`LocalFiles`），工具经 JSON-RPC `tools/call` 调。驱动脚本在远程机 scratchpad，不进仓。

## 三件套原文

```text
$ uv sync --frozen
Checked 89 packages in 58ms
$ uv run ruff check .
tests/test_kernel_invariants.py:90:78: E501 Line too long (89 > 88)
Found 1 error.
$ uv run pyright
0 errors, 0 warnings, 0 informations
$ uv run pytest -q（末尾）
........ss...................................s                           [100%]
808 passed, 174 skipped in 85.85s (0:01:25)
```

## 生成脚本原文（提交 `e30525f` 的代码；九个全量 parquet 已在缓存）

```text
$ uv run python -m scripts.build_olist_dataset --cache <全量 parquet 目录> --out <文件>（第 1 次）
built in 3.7s
{"dataset_id": "olist-ecommerce", "data_version": "olist-ecommerce-dcca129e2ea0cb56", "title": "巴西电商 Olist 样例（1/20 抽样，演示与评测用，CC BY-NC-SA 4.0）", "source_app": "knowledge-sample", "sha256": "1e5f9284b60ae2e9a87e40d80b171d356a997fdb8ccc0afb13fd35f4de274abe", "size_bytes": 3858432, "start_date": "2016-10-04", "end_date": "2018-09-06"}
exit=0
$ uv run python -m scripts.build_olist_dataset --cache <全量 parquet 目录> --out <文件>（第 2 次）
built in 3.6s
{"dataset_id": "olist-ecommerce", "data_version": "olist-ecommerce-dcca129e2ea0cb56", "title": "巴西电商 Olist 样例（1/20 抽样，演示与评测用，CC BY-NC-SA 4.0）", "source_app": "knowledge-sample", "sha256": "1e5f9284b60ae2e9a87e40d80b171d356a997fdb8ccc0afb13fd35f4de274abe", "size_bytes": 3858432, "start_date": "2016-10-04", "end_date": "2018-09-06"}
exit=0
$ sha256sum
1e5f9284b60ae2e9a87e40d80b171d356a997fdb8ccc0afb13fd35f4de274abe  1.sqlite
1e5f9284b60ae2e9a87e40d80b171d356a997fdb8ccc0afb13fd35f4de274abe  2.sqlite
```

## MCP 核对原文（对上面第 1 次生成的文件）

```text
list_datasets 原文（olist 一行）: {"dataset": "olist-ecommerce", "title": "巴西电商 Olist 样例（1/20 抽样，演示与评测用，CC BY-NC-SA 4.0）", "security_code": null, "data_version": "olist-ecommerce-dcca129e2ea0cb56", "start_date": "2016-10-04", "end_date": "2018-09-06", "default": false}
通过 | list_datasets 有 olist-ecommerce
通过 | 标题带许可证
通过 | security_code 为空
通过 | data_version 与生成结果一致
describe_schema 表: ['customers', 'dataset_metadata', 'field_dictionary', 'geolocation', 'metric_dictionary', 'order_items', 'order_payments', 'order_reviews', 'orders', 'product_category_translation', 'products', 'sellers', 'table_keys', 'table_links'] | 方言: duckdb
通过 | 九张业务表都在 | []
通过 | 不出现 phys_
order_items 列: [('order_id', 'VARCHAR', '订单号', None), ('order_item_id', 'BIGINT', '单内序号', None), ('product_id', 'VARCHAR', '商品编号', None), ('seller_id', 'VARCHAR', '卖家编号', None), ('shipping_limit_date', 'VARCHAR', '卖家发货截止时间', None), ('price', 'DOUBLE', '售价', '雷亚尔'), ('freight_value', 'DOUBLE', '运费', '雷亚尔')]
metric_definitions: [('active_customers', 'aggregate', False), ('cancel_rate', 'aggregate', False), ('cost_of_goods', 'unavailable', False), ('credit_card_installment_share', 'aggregate', False), ('freight_revenue', 'aggregate', False), ('gmv', 'aggregate', False), ('gross_margin', 'unavailable', False), ('item_revenue', 'aggregate', False), ('order_count', 'aggregate', False), ('payment_total', 'aggregate', False), ('repeat_customer_share', 'aggregate', False)]
通过 | 十一个口径
通过 | queryable 全为假
通过 | row_filter、kind 原样带出
dataset_metadata: {'complete_start': '2017-01', 'complete_end': '2018-08', 'license': 'CC BY-NC-SA 4.0；只作演示与评测，不得商用'}
通过 | complete_end = 2018-08
run_sql 按月 GMV（MCP，语义层）: 20 行
   {'period': '2017-01', 'gmv': 5811.130000000001, 'order_count': 33}
   {'period': '2017-02', 'gmv': 11570.479999999996, 'order_count': 82}
   {'period': '2017-03', 'gmv': 21857.659999999993, 'order_count': 130}
   {'period': '2017-04', 'gmv': 18304.579999999998, 'order_count': 110}
   {'period': '2017-05', 'gmv': 30441.17999999998, 'order_count': 196}
   {'period': '2017-06', 'gmv': 26072.06, 'order_count': 152}
   {'period': '2017-07', 'gmv': 24550.170000000006, 'order_count': 173}
   {'period': '2017-08', 'gmv': 39521.29999999995, 'order_count': 220}
   {'period': '2017-09', 'gmv': 32100.439999999984, 'order_count': 186}
   {'period': '2017-10', 'gmv': 31702.729999999985, 'order_count': 206}
   {'period': '2017-11', 'gmv': 61369.26999999994, 'order_count': 391}
   {'period': '2017-12', 'gmv': 45768.219999999994, 'order_count': 285}
   {'period': '2018-01', 'gmv': 48113.979999999996, 'order_count': 352}
   {'period': '2018-02', 'gmv': 44406.42000000001, 'order_count': 299}
   {'period': '2018-03', 'gmv': 58930.49, 'order_count': 328}
   {'period': '2018-04', 'gmv': 60736.950000000026, 'order_count': 339}
   {'period': '2018-05', 'gmv': 69707.02000000006, 'order_count': 368}
   {'period': '2018-06', 'gmv': 60380.09000000004, 'order_count': 354}
   {'period': '2018-07', 'gmv': 49461.570000000094, 'order_count': 310}
   {'period': '2018-08', 'gmv': 44372.02000000004, 'order_count': 332}
引用: {"dataset_id": "olist-ecommerce", "data_version": "olist-ecommerce-dcca129e2ea0cb56", "source": "olist-ecommerce@olist-ecommerce-dcca129e2ea0cb56", "as_of": "2018-09-06", "retrieved_at": "2026-10-13T03:44:54+00:00", "engine": "wrenai-0.15.0", "query_digest": "669d111897e4caa2"}
通过 | 与直接读 SQLite 逐行相同（20 行，金额容差 0.01）
未过 0 项
```

## 没做的、要说的

- **本机 KIND 联调链没跑**：样例桶、`run.sh sample olist`、`driver verify-sample olist` 归 Qwen（`qwen-001`）。
- **174 个跳过**：我没有核它们跳过的原因，也没在基线上对比跳过数；能确定的只有新加的 9 个用例一个都没跳。
- **生产上的样例桶与登记身份**：没定，发布前定（`0023` 第九节）。
- **与原设计的出入**（`0023` 已同步）：数据集改为 1/20 样例（第二之二节）；`data_version` 加进了定义文件的 sha256；YAML 里关系的键用 `columns` 不用 `on`（YAML 1.1 把 `on` 读成布尔值）。
- **顺带发现、留给第 2 段**：评测的 `TruthStore` 在 DuckDB 模式下逐行 `executemany` 装载，即使 3.86 MB 的样例也要 83 秒（全量超过 10 分钟没装完，被我停了）。第 2 段在 investment 后端改成按批装载，只改装载方式。
