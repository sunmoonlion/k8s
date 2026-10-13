# 财务分析与预测 第 1 段（远程部分）回执——Olist 样例数据集进 knowledge

> Opus，远程机，qwen 工位，2026-10-13。设计：`sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md` 第三、四节。分工按 opus-001 2026-10-13 的纠正：远程能做的这里做完；本机 KIND 联调链那一截写给 Qwen（`switch-test/inbox/qwen/qwen-001.md`），它的回执另写 `fin-forecast-1-local-<日期>.md`。

## 提交

| 仓 | 提交 | 内容 |
| --- | --- | --- |
| knowledge-backend（子仓） | `94a3a72` | `app/datasets/olist/olist.yml`、`app/scripts/build_olist_dataset.py`、`app/tests/test_olist_dataset.py`、`docs/dataset-registry.md` 一节 |
| knowledge-app（父仓） | `f7e5aba` | 子模块指针前移到 `94a3a72` |
| k8s | 本回执所在提交 | 回执、`0023` 跟上新分工、`qwen-001` 只剩本机一截 |

知识服务的运行代码（`app/app/` 下）一行没改。

## 停点逐项

| 停点 | 结果 |
| --- | --- |
| 知识后端三件套 | ruff：只有 1 条，是**原有的** `tests/test_kernel_invariants.py:90` 行宽（基线 `548e84a` 与 fable 上同样，本次没动这个文件，没顺手改）；我新加的文件 ruff 干净。pyright 0 错误。pytest 全量 807 过、174 跳过、0 失败；新测试 8 过 |
| 生成脚本对真实数据跑两次 | 两次 `data_version` 都是 `olist-ecommerce-5f4af057bf031216`；文件 sha256 也逐字节相同（同一台机器）；每次 10 到 12 秒，峰值内存约 200 MB，文件 114667520 字节 |
| 经知识服务的 MCP 处理链列到、查到、跑通按月成交额 | 11 项全过，原文见下 |

**MCP 核对怎么做的**：没有起 HTTP 服务（那是本机联调链的事），用的是知识服务自己的 `KnowledgeMcp.handle`（与 `tests/test_semantic_mcp.py` 同一种起法）：语义层开着，默认数据集用仓里的 600009 夹具，Olist 按真实登记的形状放进登记表（登记表与取文件两处用测试里现成的替身 `MemoryRegistry`、`LocalFiles`），工具经 JSON-RPC `tools/call` 调。驱动脚本在远程机 scratchpad，不进仓。

## 三件套原文

```text
$ uv sync --frozen
Checked 89 packages in 57ms
$ uv run ruff check .
E501 Line too long (89 > 88)
  --> tests/test_kernel_invariants.py:90:78
   |
88 |     2026-08-13 的 Architecture v2 正式发布采用 exact-digest-alias 晋升：
89 |     不重建镜像，给已通过 R7 门禁的 digest 打 `2.0.0` 别名
90 |     （历史 R7 发布清单按 k8s:sunmoonai/docs/legacy-backlog/verification-index.md 查询）。
   |                                                                                          ^
91 |     本测试钉住源码侧的版本字符串，使 `/api/version` 与该别名一致。
   |

Found 1 error.
$ uv run pyright
0 errors, 0 warnings, 0 informations

$ uv run pytest -q（末尾）
.......ss...................................s                            [100%]
807 passed, 174 skipped in 104.13s (0:01:44)
$ uv run pytest -q tests/test_olist_dataset.py
........                                                                 [100%]
8 passed in 7.51s
```

## 生成脚本原文（提交 `94a3a72` 的代码，九个 parquet 已在缓存）

```text
$ uv run python -m scripts.build_olist_dataset --cache <parquet 目录> --out <文件>（第一次）
built in 11.9s
{"dataset_id": "olist-ecommerce", "data_version": "olist-ecommerce-5f4af057bf031216", "title": "巴西电商 Olist 样例（演示与评测用，CC BY-NC-SA 4.0）", "source_app": "knowledge-sample", "sha256": "5366e6a616de67f7f1beaef8f1ca40316209958e7f05155ef94c8ec8a8113fba", "size_bytes": 114667520, "start_date": "2016-09-04", "end_date": "2018-10-17"}
exit=0
$ 同一条（第二次，另一个输出文件）
built in 10.0s
{"dataset_id": "olist-ecommerce", "data_version": "olist-ecommerce-5f4af057bf031216", "title": "巴西电商 Olist 样例（演示与评测用，CC BY-NC-SA 4.0）", "source_app": "knowledge-sample", "sha256": "5366e6a616de67f7f1beaef8f1ca40316209958e7f05155ef94c8ec8a8113fba", "size_bytes": 114667520, "start_date": "2016-09-04", "end_date": "2018-10-17"}
exit=0
```

## MCP 核对原文（对上面第一次生成的文件）

```text
list_datasets 原文（olist 一行）: {"dataset": "olist-ecommerce", "title": "巴西电商 Olist 样例（演示与评测用，CC BY-NC-SA 4.0）", "security_code": null, "data_version": "olist-ecommerce-5f4af057bf031216", "start_date": "2016-09-04", "end_date": "2018-10-17", "default": false}
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
   {'period': '2017-01', 'gmv': 136943.4599999997, 'order_count': 787}
   {'period': '2017-02', 'gmv': 283561.68999999954, 'order_count': 1718}
   {'period': '2017-03', 'gmv': 425617.95999999985, 'order_count': 2617}
   {'period': '2017-04', 'gmv': 405848.6100000007, 'order_count': 2377}
   {'period': '2017-05', 'gmv': 582710.8300000018, 'order_count': 3640}
   {'period': '2017-06', 'gmv': 499652.24000000383, 'order_count': 3205}
   {'period': '2017-07', 'gmv': 578753.7300000049, 'order_count': 3946}
   {'period': '2017-08', 'gmv': 661903.5200000007, 'order_count': 4272}
   {'period': '2017-09', 'gmv': 717102.7200000003, 'order_count': 4227}
   {'period': '2017-10', 'gmv': 764756.0299999982, 'order_count': 4547}
   {'period': '2017-11', 'gmv': 1172191.6800000013, 'order_count': 7421}
   {'period': '2017-12', 'gmv': 861526.7699999994, 'order_count': 5618}
   {'period': '2018-01', 'gmv': 1101920.0100000051, 'order_count': 7187}
   {'period': '2018-02', 'gmv': 979486.1600000004, 'order_count': 6624}
   {'period': '2018-03', 'gmv': 1152656.989999998, 'order_count': 7168}
   {'period': '2018-04', 'gmv': 1156248.889999999, 'order_count': 6919}
   {'period': '2018-05', 'gmv': 1145686.4599999944, 'order_count': 6833}
   {'period': '2018-06', 'gmv': 1020381.8999999949, 'order_count': 6145}
   {'period': '2018-07', 'gmv': 1039783.5799999986, 'order_count': 6233}
   {'period': '2018-08', 'gmv': 996973.5099999931, 'order_count': 6421}
引用: {"dataset_id": "olist-ecommerce", "data_version": "olist-ecommerce-5f4af057bf031216", "source": "olist-ecommerce@olist-ecommerce-5f4af057bf031216", "as_of": "2018-10-17", "retrieved_at": "2026-10-13T03:04:44+00:00", "engine": "wrenai-0.15.0", "query_digest": "669d111897e4caa2"}
通过 | 与直接读 SQLite 逐行相同（20 行，金额容差 0.01）
未过 0 项
```

## 没做的、要说的

- **本机 KIND 联调链没跑**：样例桶、`run.sh sample olist`、`driver verify-sample olist` 归 Qwen（`qwen-001`）。
- **174 个跳过**：我没有核它们跳过的原因，也没在基线上对比跳过数；能确定的只有新加的 8 个用例一个都没跳。
- **生产上的样例桶与登记身份**：没定，发布前定（`0023` 第九节）。
- 设计与原稿的出入：`data_version` 的算法里加进了定义文件的 sha256（不然改了定义、内容变了版本不变，重新登记会撞 409）；YAML 里关系的键用 `columns` 不用 `on`（YAML 1.1 把 `on` 读成布尔值，第一次生成时撞上了）。`0023` 已同步改。
