# `0023-fin-forecast` 专家「财务分析与预测」做成真的

> 状态：2026-10-13 Opus 在 qwen 工位写设计，未实施。依据：[任务清单 opus-001](../../../switch-test/inbox/opus/opus-001.md)、账 96、[决策](../../decisions.md) 2026-10-13 一条。
> 起点：investment-backend `e73ffa5`（`FIN_FORECAST` 版本 0，`status="preparing"`），knowledge-backend `548e84a`，k8s `451b3fae`。
> 先读：[`0009-semantic`](0009-semantic.md)（口径与 SQL 怎么走）、[`0015`](0015-files-not-dossiers.md)（成稿落文件）、[`0018`](0018-advisor-market.md)（专家 = 知识库 + skill）、[审批](../architecture/approval.md)（工具级三档）。
> 分工：Opus 设计、拆任务、审读；Qwen 在同一工位实施（任务页在 `switch-test/inbox/qwen/`）；远程 Fable 最后审读、合进 fable、发布。

## 一、做成什么

用户在请专家页选「财务分析与预测」，问一句，例如「近两年按月的收入趋势，预测下两个季度」。专家按五步做完：定范围 → 取数 → 分析 → 预测 → 成稿。项目目录里出现 `底稿/财务分析与预测-成稿.md` 和 `交回.md`；专家页上逐步看得到它查了什么、算了什么、预测用了什么方法、什么假设、多宽的区间。不给买卖建议。

| 范围 | 内容 |
| --- | --- |
| 做 | 一份数据集（Olist 巴西电商样例，九张表）进 knowledge；十道金标准题；专家包五步的方法；切成可用 |
| 不做 | 改专家包机制（`StepContract`、验收判定、顾问、审批三档）；改评测判定；A 股公司的财务预测（以后接，方法现在就写成不绑定这份数据）；估值；买卖建议 |

## 二、数据摸底（2026-10-13，直接读九个 parquet）

来源：`https://assets.getwren.ai/sample_data/brazilian-ecommerce/<表>.parquet`，九个文件共约 55 MB。WrenAI 现成的定义在它 `legacy-v1` 分支的 `wren-ui/src/apollo/server/data/sample.ts`（`ecommerce` 一段）：表与列的英文说明、表关系、三道示例问题。

| 事实 | 数 | 对设计的影响 |
| --- | --- | --- |
| 下单时间 | 2016-09-04 到 2018-10-17 | 不是整段都能用 |
| 连续可用的月份 | 2017-01 到 2018-08，共 20 个月 | 2016 年只有 9、10、12 月零星几单，11 月整月没有；2018-09 只有 16 单、2018-10 只有 4 单，是截断，不是业务下滑 |
| 2018 年第三季度 | 7、8 月完整，9 月截断 | 「按季度」的题会撞上残缺季度 |
| 成本 | **没有** | 只有售价 `price`、运费 `freight_value`、支付额 `payment_value`。毛利、利润率算不出来 |
| 支付额与「售价 + 运费」 | 98278 / 98665 单逐单相等（差 ≤ 0.01） | 收入可按明细算，也可按支付算，两者几乎相同但不是同一个口径 |
| 订单状态 | delivered 96478，shipped 1107，canceled 625，unavailable 609，invoiced 314，processing 301，created 5，approved 2 | 收入要说清剔除哪些状态 |
| 没有明细的订单 | 775 单，几乎全是 unavailable 与 canceled | 按明细算收入时它们自然不进 |
| 明细表主键 | `order_id + order_item_id`（`order_item_id` 只是单内序号，只有 21 个不同值） | WrenAI 定义里写成 `order_item_id`，**错** |
| 支付表主键 | `order_id + payment_sequential` | WrenAI 定义里写成 `order_id`，**错** |
| 评价表 | `review_id` 不唯一（99224 行，98410 个）；`review_id + order_id` 唯一 | 主键用两列 |
| 客户 | `customer_id` 一单一个（99441 个）；真正的客户是 `customer_unique_id`（96096 个） | 复购、客户数必须用 `customer_unique_id`；用 `customer_id` 复购率恰好是 0 |
| 地理表 | 1000163 行，只有 19015 个邮编前缀 | 一个前缀多行，与客户、卖家是多对多，不能做关系 |
| 品类 | 610 个商品没有品类；13 个商品的品类没有英文名 | 按品类汇总要处理空值 |
| 邮编前缀 | 文字，带前导零（`01003`） | 必须存文字 |
| 币种 | 巴西雷亚尔 | 单位写「雷亚尔」 |

按本文第三节的口径验算过（DuckDB 1.5.5 直读 parquet，脚本不进仓）：2017-01 到 2018-08 的按月 GMV 从 13.7 万升到 2018 年的约 98 万至 116 万；最近 6 个完整月（2018-03 到 2018-08）的均值约 108.5 万，最低约 99.7 万，最高约 115.6 万；用 2017-09 到 2018-02 回测 2018-03 到 2018-08，6 个月实际值全部落在区间内，绝对百分比误差 6% 到 19%。DuckDB 里 `share` 是保留字，不能作列名。

## 三、数据集 `olist-ecommerce`

### 3.1 登记

| 项 | 值 |
| --- | --- |
| `dataset_id` | `olist-ecommerce` |
| `data_version` | `olist-ecommerce-<16 位十六进制>`，取自「九个 parquet 的 sha256（按表名排序）+ 生成器版本」的 sha256 前 16 位。按输入定版本，不按 SQLite 文件的字节（同样的内容在不同机器上写出的字节可能不同） |
| `title` | `巴西电商 Olist 样例（演示与评测用，CC BY-NC-SA 4.0）` |
| `security_code` | 不填（登记接口允许为空） |
| `source_app` | `knowledge-sample` |
| `start_date` / `end_date` | `2016-09-04` / `2018-10-17` |
| 文件 | 与现有数据集同形的 SQLite：业务表加自述表（`dataset_metadata`、`field_dictionary`、`metric_dictionary`、`table_links`、`table_keys`） |

**许可证**：Olist 数据集是 CC BY-NC-SA 4.0，只作演示与评测。注明在三处：标题（`list_datasets` 会带出来，专家的出处里就有）、`dataset_metadata` 的 `license` 与 `source` 两行、生成脚本与说明文档的开头。

### 3.2 九张表

表名改短：模型名就是 SQL 里写的名字，短名少出错。原文件名记在 `dataset_metadata` 的 `source_<表名>` 行里。

| 表 | 原文件 | 行数 | 主键（`table_keys.key_columns`） | 说明字段（`label_columns`） |
| --- | --- | --- | --- | --- |
| `orders` | `olist_orders_dataset` | 99441 | `order_id` | `order_status`、`order_purchase_timestamp` |
| `order_items` | `olist_order_items_dataset` | 112650 | `order_id, order_item_id` | `product_id`、`seller_id` |
| `order_payments` | `olist_order_payments_dataset` | 103886 | `order_id, payment_sequential` | `payment_type` |
| `order_reviews` | `olist_order_reviews_dataset` | 99224 | `review_id, order_id` | `review_score` |
| `products` | `olist_products_dataset` | 32951 | `product_id` | `product_category_name` |
| `customers` | `olist_customers_dataset` | 99441 | `customer_id` | `customer_unique_id`、`customer_state` |
| `sellers` | `olist_sellers_dataset` | 3095 | `seller_id` | `seller_state` |
| `geolocation` | `olist_geolocation_dataset` | 1000163 | 无（没有唯一键，不登记 `table_keys`） | — |
| `product_category_translation` | `product_category_name_translation` | 71 | `product_category_name` | `product_category_name_english` |

列名照原样，包括原数据的拼写错误（`product_name_lenght`、`product_description_lenght`）。改了拼写，用户拿 Kaggle 上的说明对不上。

### 3.3 类型

知识服务只认整数、小数、文字三种（`domain/semantic.py`）。

| parquet | SQLite 声明 | 例 |
| --- | --- | --- |
| `BIGINT` | `INTEGER` | `order_item_id`、`review_score` |
| `DOUBLE` | `REAL` | `price`、`payment_value` |
| `VARCHAR` | `TEXT` | 各种 id、邮编前缀 |
| `TIMESTAMP` | `TEXT`，`YYYY-MM-DD HH:MM:SS` | `order_purchase_timestamp` |

空值保留为空，不填默认值。按月取 `substr(order_purchase_timestamp, 1, 7)`，在 SQLite 与 DuckDB 上写法一样。

### 3.4 表关系（`table_links`）

知识服务只支持一对一、多对一，而且两边字段同名。七条都满足：

| `link_name` | `from_table` | `to_table` | `cardinality` | `on_columns` |
| --- | --- | --- | --- | --- |
| `order_customer` | `orders` | `customers` | `many_to_one` | `customer_id` |
| `item_order` | `order_items` | `orders` | `many_to_one` | `order_id` |
| `item_product` | `order_items` | `products` | `many_to_one` | `product_id` |
| `item_seller` | `order_items` | `sellers` | `many_to_one` | `seller_id` |
| `payment_order` | `order_payments` | `orders` | `many_to_one` | `order_id` |
| `review_order` | `order_reviews` | `orders` | `many_to_one` | `order_id` |
| `product_category` | `products` | `product_category_translation` | `many_to_one` | `product_category_name` |

`geolocation` 不建关系：它和客户、卖家按邮编前缀是多对多，字段名也不同。表照样入库，说明写进 `dataset_metadata`。

### 3.5 字段字典（`field_dictionary`）

每个业务字段一行：`source_table`、`field`、`display_name`（中文）、`unit`；另加一列 `description`，放 WrenAI 定义里的英文说明原文（知识服务现在不读这一列，留作出处；以后 `describe_schema` 要带说明时直接用）。单位：金额「雷亚尔」，重量「克」，尺寸「厘米」，评分「分」，期数「期」，长度「字符」，数量「张」「件」。

### 3.6 口径表（`metric_dictionary`）

七列照旧，加第二版的六列。Olist 的口径都是**按维度汇总**的，现在的 `query_metric` 只做逐行口径（`0009` §数据集自述的约定）。所以这里全部 `queryable = 0`：只有定义，由专家按定义写 SQL。`metric_definitions` 会把每一行原样返回，知识后端不用改代码。

| 列 | 这份数据集怎么填 |
| --- | --- |
| `metric_name` | 英文小写下划线，也是**结果列的规范名**：专家算出来的列一律用它作别名（第五节「通用规则」），评测按这个名字比对 |
| `display_name`、`unit`、`description` | 中文；`description` 写全：分子、分母、剔除哪些状态、按什么时间归期 |
| `source_table` | 主表 |
| `expression_hint` | 可直接用的 SQL 片段 |
| `time_basis` | 按 `order_purchase_timestamp` 归期 |
| `kind` | `aggregate`（汇总，只有定义）或 `unavailable`（数据集里没有，写明原因） |
| `base_table`、`value_expression` | 同 `source_table`、`expression_hint`，表名写全 |
| `applicable_when` | 空 |
| `reason_if_not` | `kind = unavailable` 时写原因 |
| `queryable` | 全部 `0` |
| 另加 `row_filter` | 行过滤条件，例如 `orders.order_status NOT IN ('canceled','unavailable')` |

| `metric_name` | 中文名 | 定义要点 |
| --- | --- | --- |
| `gmv` | 成交额 | `SUM(order_items.price + order_items.freight_value)`；剔除 canceled、unavailable；按下单月 |
| `item_revenue` | 商品收入（不含运费） | `SUM(order_items.price)`；同上 |
| `freight_revenue` | 运费收入 | `SUM(order_items.freight_value)`；同上 |
| `payment_total` | 支付额 | `SUM(order_payments.payment_value)`；同上；与 `gmv` 几乎相等但不是同一口径 |
| `order_count` | 订单数 | `COUNT(DISTINCT order_items.order_id)`：有明细、剔除 canceled、unavailable，与 `gmv` 同一范围（算客单价时分子分母一致）。直接数 `orders` 会多出 8 张没有明细的单 |
| `cancel_rate` | 取消率 | 当月下单中 `order_status = 'canceled'` 的订单数 ÷ 当月全部下单数（分母含所有状态） |
| `credit_card_installment_share` | 信用卡分期占比 | 有信用卡支付的订单中，任一笔信用卡支付 `payment_installments > 1` 的订单占比 |
| `active_customers` | 下单客户数 | `COUNT(DISTINCT customers.customer_unique_id)`；不要用 `customer_id` |
| `repeat_customer_share` | 复购客户占比 | 按 `customer_unique_id` 计，下过 2 单及以上的客户 ÷ 全部下单客户（全部状态、全部时间） |
| `cost_of_goods` | 商品成本 | `kind = unavailable`，原因「数据集不含成本」 |
| `gross_margin` | 毛利率 | `kind = unavailable`，原因「数据集不含成本，毛利与利润率都算不出来」 |

比率一律存成 0 到 1 的小数，不乘 100，SQL 里不四舍五入（评测按数值容差比对；成稿里再写成百分比）。

### 3.7 数据集说明（`dataset_metadata`）

| `key` | `value` 要点 |
| --- | --- |
| `data_snapshot_id` | 同 `data_version` |
| `start_date` / `end_date` | `2016-09-04` / `2018-10-17` |
| `complete_start` / `complete_end` | `2017-01` / `2018-08`：数据集声明的连续完整月份 |
| `period_formats` | 月 `YYYY-MM`，季度 `YYYY-Qn`（例 `2018-Q2`），年 `YYYY` |
| `currency` | 巴西雷亚尔（BRL） |
| `license` / `source` | CC BY-NC-SA 4.0；Olist 在 Kaggle 发布的公开数据，经 WrenAI 样例文件取得，只作演示与评测 |
| `source_<表名>` | 原文件名与 sha256 |
| `note_truncation` | 2016 年零星、2016-11 无数据；2018-09 只有 16 单、2018-10 只有 4 单，是数据截断，不是业务下滑；2018 年第三季度不完整 |
| `note_no_cost` | 不含成本、费用、利润，毛利与利润率算不出来 |
| `note_customer_id` | `customer_id` 一单一个，客户数与复购用 `customer_unique_id` |
| `note_status` | 收入类口径剔除 canceled、unavailable；取消率的分母含全部状态 |
| `note_geolocation` | 一个邮编前缀多行，不能直接与客户、卖家关联；要用先按前缀汇总 |
| `note_category` | 610 个商品无品类，13 个商品的品类无英文名；按品类汇总时单列「未知」 |

`describe_schema` 不带这些说明；专家方法要求第一步用 `run_sql` 读 `dataset_metadata` 全部行（财报体检已是这样做）。

### 3.8 生成与登记

| 处 | 做什么 |
| --- | --- |
| knowledge-backend `app/datasets/olist/olist.yml`（新） | 声明：九个文件的地址与 sha256、表名对照、主键、关系、字段字典、口径、说明。**数据集的定义只有这一份** |
| knowledge-backend `app/scripts/build_olist_dataset.py`（新） | `--cache <目录> --out <文件>`：缺文件就下载，sha256 不对就停；用已有依赖（DuckDB）读 parquet、写 SQLite；写完用 `read_description()` 自检、生成一次语义模型；打印 `data_version`、`sha256`、`size_bytes`、起止日期，供登记 |
| 测试 | 用几行合成数据造小 parquet（测试里现造，不进仓、不联网）：生成、自述校验、语义模型、口径行原样返回且不可查、类型映射、地理表无关系、两次生成 `data_version` 相同、sha256 不对时停 |
| k8s `sunmoonai/scripts/local-integration/dataset-chain/` | 加一个样例桶 `development-knowledge-samples`（只给知识服务读）、`run.sh sample olist`（生成 → 上传样例桶 → 登记）、`driver.py verify-sample olist`（第四节的检查）。登记直接调知识服务的登记接口，用替身发的服务令牌，`source_app = knowledge-sample` |

数据文件、parquet、生成出的 SQLite 都不进 git。生产上谁来登记、桶叫什么，留到发布时定（第九节）。

## 四、知识服务这一侧怎么验

知识后端的运行代码不改：多数据集登记、语义层、四个查询工具都已有。验的是这份数据集在它们上面能用：

| 工具 | 应该看到 |
| --- | --- |
| `list_datasets` | 有 `olist-ecommerce`，标题带许可证，`security_code` 为空 |
| `describe_schema(dataset=olist-ecommerce)` | 九张业务表（加自述表），列带中文名与单位；不出现 `phys_` |
| `metric_definitions(dataset=…)` | 十一个口径，`queryable` 全为假，`row_filter`、`kind` 原样带出 |
| `run_sql(dataset=…)` | 按月 GMV（2017-01 到 2018-08，20 行）与直接读 SQLite 的结果逐行相同 |
| `run_sql` 读 `dataset_metadata` | 拿到 `complete_end = 2018-08` 等说明 |

## 五、专家包 `FIN_FORECAST` 第 1 版

照 `FIN_REVIEW` 的写法：`method_text` 英文给模型，`summary`、`why`、标签中文给用户，验收全是确定性规则，`tool_policy` 不放宽。同文件里已有的 `JSON_ONLY`、`_FIN_DATASET`、`_FIN_SQL`、`_FIN_NUMBERS` 直接用。

### 5.1 通用规则（每步方法都带）

| 规则 | 为什么 |
| --- | --- |
| 每次调知识工具都带 `dataset=<scope.dataset>` | 不查默认数据集 |
| 数只能来自本步工具结果或上游交回物，不回忆、不估 | 同 `FIN_REVIEW` |
| **计算一律在 SQL 里做**：求和、均值、最小最大、比率、同比，不心算 | 模型心算出错是这类任务最常见的失败 |
| **结果列用口径名作别名**（`AS gmv`），期间列叫 `period`，按数据集声明的期间格式写；维度列用原字段名 | 出处可追，评测可比 |
| 比率保留 0 到 1 的小数，SQL 里不四舍五入 | 同上 |
| 只用数据集声明的完整期间；声明里没有就按「首尾两端订单量低于中间各期中位数一半的期」认不完整，并写明是这样认的 | 截断的月份不能当业务下滑 |
| 数据集里没有的口径（`kind = unavailable`）照实说没有，不找替代品冒充 | 例：没有成本就不给毛利 |

### 5.2 五步

| 步 | 工具 | 要点 | 交回物关键字段 | 验收 |
| --- | --- | --- | --- | --- |
| `scope` 定范围 | `list_datasets`、`describe_schema`、`metric_definitions`、`run_sql` | 认出数据集；读 `dataset_metadata` 全部行；把问题落到口径名、期间、粒度；问到但数据集没有的口径列进 `unavailable`；问题没给期间就用完整期间并写进 `assumptions`；找不到数据集就把 `dataset` 留空 | `dataset`、`data_version`、`question`、`period`（起、止、粒度）、`complete_period`、`metrics`、`unavailable`、`notes`、`assumptions` | 格式对；有 `dataset`、`data_version`、`period`、`metrics`；`missing_data` 认 `dataset` 为空 |
| `pull` 取数 | `run_sql` | 按口径取期间序列；每列写来源（表、字段、过滤）；交回实际执行的 SQL | `columns`（名、中文、来源）、`rows`、`sql`、`data_version` | 格式对；`rows` 至少 1 行；有 `sql`、`data_version` |
| `analyze` 分析 | `run_sql` | 趋势（环比、同比）、季节性只在有两个完整周期时才说、结构（区域、品类的占比与变化）；每条发现带支撑它的 SQL 与数 | `findings`（文字、证据、SQL） | 格式对；`findings` 至少 1 条 |
| `forecast` 预测 | `run_sql` | 方法固定，见 5.3；先回测再外推；全部在 SQL 里算 | `method`、`window`、`excluded_periods`、`assumptions`、`rows`（`period`、`forecast_point`、`forecast_low`、`forecast_high`）、`backtest`、`sql` | 格式对；有这几项；`assumptions` 至少 2 条；`rows` 至少 1 行 |
| `writeup` 成稿 | 无 | 按 0015 的写法要求写 `底稿/财务分析与预测-成稿.md`：回答、数据带角标、验过什么、局限、出处；不贴 JSON；不给买卖建议；`unavailable` 与截断必须写进局限；最后一步照例写 `交回.md` | `answer`、`limitations`、`citations` | 格式对；有正文；无买卖建议（`no_positioning_advice`） |

`reserve` 与输入长度照 `FIN_REVIEW` 的量级定，Qwen 实测后回填。`field_words.py` 补齐新字段的中文词（现有测试会查）。

### 5.3 预测方法：移动平均

**取最近 6 个完整期的均值作每个预测期的点估计；区间取这 6 期的最低与最高。**不足 6 个完整期用全部完整期；不足 3 个就不预测，交人。

为什么在三种里选它（这条理由不依赖这份数据）：

| 方法 | 要什么前提 | 结论 |
| --- | --- | --- |
| 季节性朴素法（用去年同期） | 至少两个完整周期才看得出季节性是不是稳定；只有一个周期时，去年同期的偶然事件（例如一次大促）会原样复制到明年 | 不选 |
| 线性趋势 | 增长在外推期内保持同一斜率 | 不选：短序列里常见「先爬坡、后走平」，拟合一条直线会把爬坡期的斜率推到走平期 |
| 移动平均 | 只假设近期水平延续 | **选**：前提最少、最容易说清、算法一行 SQL；区间直接摆出「过去半年最低到最高」，用户一眼看懂它有多不确定 |

| 细则 | 怎么做 |
| --- | --- |
| 预测从哪期开始 | 完整期间之后的第一期。数据集里有、但被认作不完整的期（例如 2018-09），用预测值代替，并在交回物与成稿里写明 |
| 季度 | 季度点估计 = 三个月点估计之和；区间 = 三个月下限之和到上限之和。残缺季度 = 已有完整月的实际值 + 其余月的预测值，写明哪几个月是实际、哪几个月是预测 |
| 回测 | 完整期 ≥ 12 时必做：把窗口整体前移 6 期，用同一方法预测其后 6 期，与实际比，报绝对百分比误差的平均值与「落在区间内的期数 / 总期数」。完整期不足 12 就写「期数不够，没有回测」 |
| 假设至少写两条 | 近期水平延续；没有新的大促、政策或口径变化；数据截断期之后业务照常 |
| 不说的 | 「一定」「保证」；不把预测说成目标或承诺 |

## 六、评测 `fin_forecast_10`

放 `investment-backend/app/eval/cases/fin_forecast_10.json`，格式与 `fin_review_13.json` 相同；`data_snapshot_id` 为 3.1 的 `data_version`；评测按语义层开着跑（`--dialect duckdb`）。真值查询的列名与口径名、`period` 一致。

| # | `case_id` | 问题 | 真值查询的列 | 陷阱与必须提醒 |
| --- | --- | --- | --- | --- |
| 1 | `ff-gmv-monthly` | 2017 年 1 月到 2018 年 8 月，按月的成交额和订单数 | `period`、`gmv`、`order_count`（20 行） | 剔除取消与不可用 |
| 2 | `ff-gmv-quarterly-yoy` | 按季度看成交额，2018 年第二季度比上年同期增长多少 | `period`、`gmv`（2017-Q1 到 2018-Q2，6 行） | 季度格式 `YYYY-Qn` |
| 3 | `ff-state-top5` | 成交额最高的五个州，各占多少 | `customer_state`、`gmv`、`gmv_share`（5 行） | `share` 是保留字 |
| 4 | `ff-category-top10` | 商品收入（不含运费）最高的十个品类 | `product_category_name_english`、`item_revenue`（10 行） | 品类为空与无英文名 |
| 5 | `ff-category-margin` | 哪个品类毛利率最高 | 无真值查询 | 必须提醒：任一「不含成本」「没有成本」「无法计算毛利」；不得出现「毛利率为」 |
| 6 | `ff-installment-share` | 用信用卡付款的订单里，分期的占多少 | `credit_card_installment_share`（1 行） | 按订单去重 |
| 7 | `ff-cancel-monthly` | 2017 年 1 月到 2018 年 8 月每月的取消率 | `period`、`cancel_rate`（20 行） | 分母含全部状态 |
| 8 | `ff-repeat-customers` | 下过不止一单的客户占多少 | `repeat_customer_share`（1 行） | 用 `customer_id` 得 0 |
| 9 | `ff-forecast-gmv` | 预测 2018 年 9 月到 12 月每月的成交额，给区间 | `forecast_point`、`forecast_low`、`forecast_high`（2018-03 到 2018-08 的均值、最低、最高，1 行） | 必须提醒：任一「截断」「不完整」；任一「假设」；不得出现「一定」「保证」 |
| 10 | `ff-backtest-orders` | 只用 2018 年 2 月及以前的数据，预测 2018 年 3 月到 8 月的订单数，和实际比误差多大 | 真值一：`forecast_point`、`forecast_low`、`forecast_high`（2017-09 到 2018-02 的订单数，1 行）；真值二：`period`、`order_count`（2018-03 到 2018-08，6 行） | 必须提醒：任一「误差」 |

预测题的真值是「这份方法正确用在正确的数上」的结果，不是真实的未来；这在案例的 `description` 里写明。容差：金额 0.01，比率 0.0001，计数 0。

**「10 题过 ≥ 8」怎么算**：一题算过 = 质量、引用、必须提醒三栏都过（比发布门严：发布门不看必须提醒）。只考边界的第 5 题没有真值查询，质量栏按现有判法算过，它的过不过实际由必须提醒决定。

## 七、规矩对照

| 规矩 | 这里怎么守 |
| --- | --- |
| `C-A1` 新专家是新专家包 | 只改 `FIN_FORECAST` 这一份数据；不改机制 |
| `C-A8` WrenAI 只用引擎 | 只借它的样例数据与说明文字；知识后端里引擎的用法不变 |
| `C-A9` 供应商不调模型 | 不变 |
| `C-D1` 一个权威主档 | 主档是对象存储里登记的那份 SQLite；parquet 是外部来源，生成脚本按 sha256 钉住 |
| `C-D4` 对象存储按领域拥有 | 样例放知识服务自己的样例桶，不放 info 的桶 |
| `F-POS` 不给买卖建议 | 成稿步骤加 `no_positioning_advice` 验收；边界写进六问 |
| 用户字面无代号、无 JSON | 现有测试会拦；`preparing_note` 清空、标题去掉「筹备中」时一起过 |

## 八、分段与停点

| 段 | 谁做 | 做什么 | 停点怎么算过 |
| --- | --- | --- | --- |
| 1 数据 | Qwen | 第三节；联调链加样例 | 联调链里 `run.sh sample olist` 与 `driver verify-sample olist` 全过，第四节五项原文贴回执；knowledge 后端三件套（ruff、pyright、pytest）全过 |
| 2 评测题 | Qwen | 第六节十题 | 真值查询在数据集上逐条跑通、结果贴回执；`run_eval.py --cases fin_forecast_10 --profile FIN_FORECAST` 能跑（专家包还是占位时允许全不过） |
| 3 方法 | Qwen | 第五节 | 专家包规矩测试全过；用真 Codex 对本机 knowledge 跑一遍五步；十题过 ≥ 8（按第六节的算法） |
| 4 切真 | Qwen | `status="ready"`、`version="1"`、标题去「筹备中」、`preparing_note` 清空 | 后端全量测试过；回执附一次完整委托的事件摘要与成稿文件 |

每段 Qwen 写回执 `k8s/sunmoonai/scripts/results/fin-forecast-<段>-<日期>.md`，Opus 审过才进下一段。

## 九、要所有者定的、要记的

| 项 | 建议 | 状态 |
| --- | --- | --- |
| 任务清单里的「品类利润率」 | 数据里没有成本，改成第 5 题那样的边界题：考专家会不会照实说「算不出来」 | **已定**（所有者 2026-10-13：「这正是我们要的不硬算、不冒充」） |
| 「10 题过 ≥ 8」的算法 | 三栏都过才算过（第六节） | **已定**（所有者 2026-10-13：「内部门槛比发布门严没坏处」） |
| 生产上的样例桶与登记身份 | 发布时定：桶名、谁持有登记令牌、知识服务的存储账号对样例桶只读 | 发布前记进账 |
| 专家包标语「收入、成本、现金流」 | 专家包是通用的，以后接 A 股要用；对 Olist 照实说没有成本与现金流。标语不改 | 已定（本文） |
| 预测题用固定方法出真值 | 方法一旦改，真值跟着改；方法改了要重定第 9、10 题 | 已定（本文） |
