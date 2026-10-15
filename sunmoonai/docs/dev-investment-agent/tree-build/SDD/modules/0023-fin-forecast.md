# `0023-fin-forecast` 专家「财务分析与预测」做成真的

> **第 3 版方向（2026-10-15 所有者定，见 [决策](../../decisions.md)「专家收成一位」）**：问数与财报体检下架，本专家吸收财报体检，改名「中国A股上市公司财务分析与预测」，只做 A 股上市公司，Olist 下掉；演示公司贵州茅台（数据能否过 knowfeed 的 `Q-BASIS` 待改名后实采确认；被拦就先做「口径标到科目」再发布）。流程拟为：定范围（按证券代码）→ 数据摸底 → 勾稽 → 取数（季报累计数换算单季）→ 算指标与分析 → 对照官方披露 → 预测（带季节性、先回测、给区间）→ 成稿。分析 = 问题点到的科目 + 固定核心指标；预测只做营业收入、归母净利润等少数流量主项，比率由预测值推算，不逐科目预测整套报表。演示分两段：先问一家没采过、不在关注清单里的公司，演示「申请入库」到「待批准」为止（不采集）；再用事先采好的茅台走完全程。第 3 版设计另写，改名完成后实施；下文仍是第 1、2 版。

> 2026-10-14：现网事故（定范围误选 600009 财报、取数超时）已修成第 2 版（investment-backend `c0f99e4`）；同日成稿步在 Windows 上耗满时限，工作台修在 `f89de88`、`ee5ee62`；底稿按次分开存与工作底稿栏在 `61f0266`、`a4f5396`；一起走发布卡 45，10-14 12:26 上线（晋级 `0c220052`）；会合点 `/service` 走卡 46，12:35 上线（晋级 `e9fd5285`）。真人验收待所有者；见第 5.2 节末的事故记录。
> 状态（2026-10-13 收尾）：**已实施并上线**——数据集、专家包五步、十题与固定数据都在 fable；发布卡 44 上线（投资后端 `15769d5`、集群登记样例）；集群真跑演示题过（判定见 [`0023-fin-forecast-answer-key.md`](0023-fin-forecast-answer-key.md)）。**没做的**：其余 9 题没有真跑（所有者定不再单独跑），所以「十题过 ≥ 8」这条线没有量过；失败去向（交人、退回）只有单元测试，没有在真跑里触发过。依据：任务清单 opus-001（已撤，原文在 git 历史 `c8eecd22`）、账 96、[决策](../../decisions.md) 2026-10-13 一条。
> 起点：investment-backend `e73ffa5`（`FIN_FORECAST` 版本 0，`status="preparing"`），knowbase-backend `548e84a`，k8s `451b3fae`。
> 先读：[`0009-semantic`](0009-semantic.md)（口径与 SQL 怎么走）、[`0015`](0015-files-not-dossiers.md)（成稿落文件）、[`0018`](0018-advisor-market.md)（专家 = 知识库 + skill）、[审批](../architecture/approval.md)（工具级三档）。
> 分工（所有者 2026-10-13 定，以这一条为准）：**Opus 主导**这位专家，从设计到切真；自己做的部分不经 fable 审读，每段自己写回执。远程机上能做的 Opus 自己做（设计、数据集、脚本、测试、专家包、评测题与跑分）；只有所有者本地才能做的（KIND 本地联调链、浏览器里的页面、真机演示）写任务页给 Qwen（`switch-test/inbox/qwen/`），**Qwen 的回执由 Opus 审**。fable 不再给 Opus 派任务；全部调好后由 fable **只做合并**（不审、不改），**发布也由 Opus 来做**。

## 一、做成什么

用户在请专家页选「财务分析与预测」，问一句，例如「近两年按月的收入趋势，预测下两个季度」。专家按五步做完：定范围 → 取数 → 分析 → 预测 → 成稿。项目目录里出现 `底稿/财务分析与预测-成稿.md` 和 `交回.md`；专家页上逐步看得到它查了什么、算了什么、预测用了什么方法、什么假设、多宽的区间。不给买卖建议。

| 范围 | 内容 |
| --- | --- |
| 做 | 一份数据集（Olist 巴西电商样例，九张表）进 knowbase；十道金标准题；专家包五步的方法；切成可用 |
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

以上是**全量**的摸底。按本文第三节的口径在全量上验算过（DuckDB 1.5.5 直读 parquet，脚本不进仓）：2017-01 到 2018-08 的按月 GMV 从 13.7 万升到 2018 年的约 98 万至 116 万；最近 6 个完整月（2018-03 到 2018-08）的均值约 108.5 万，最低约 99.7 万，最高约 115.6 万；用 2017-09 到 2018-02 回测 2018-03 到 2018-08，6 个月实际值全部落在区间内，绝对百分比误差 6% 到 19%。DuckDB 里 `share` 是保留字，不能作列名。

## 二之二、只用一个 1/20 的样例（所有者 2026-10-13 定）

所有者问「有必要下载全部数据集吗，一个完整的示例数据集就够了」，定 1/20。全量生成出的文件 109 MB、地理表 100 万行，评测装载真值库超过 10 分钟，也不能像 600009 那样把原件提交进仓做测试。

| 规则 | 做法 |
| --- | --- |
| 按什么抽 | 按真实客户：`md5_number(customer_unique_id) % 20 = 0` 的客户入样（md5 固定，不随 DuckDB 版本变）。按订单抽会拆散同一客户的几单，复购失真 |
| 跟着走的 | 入样客户的全部订单，订单的全部明细、支付、评价 |
| 只留用到的 | 商品、卖家（被明细用到的） |
| 全留 | 品类译名（71 行） |
| 地理表 | 每个邮编前缀汇总成一行：经纬度取平均（6 位小数），城市与州取最常见的写法（同票取字母序在前的）；只留客户与卖家用到的前缀 |
| 可复现 | 生成时 DuckDB 单线程、每张表按主键排序；同一台机器上两次生成逐字节相同 |

裁出来（2026-10-13 实测）：4917 单、4747 个真实客户、5587 条明细，文件 3858432 字节，生成约 5 秒。原数据的特征都在：连续完整月份仍是 2017-01 到 2018-08；2016 年只有 10 月 18 单；2018-09 只有 1 单（已取消），之后没有数据；复购率 3.27%（全量 3.12%）；信用卡分期占比 66.9%（全量 66.9%）；取消单 30 张；仍然没有成本。按月成交额的形状一致（2017 年爬坡、2017-11 大促尖峰、2018 年走平、7 到 8 月回落），绝对数约为全量的 1/20。所有真值都在这份样例上算，不对照 Kaggle 上公开的全量统计。

## 三、数据集 `olist-ecommerce`

### 3.1 登记

| 项 | 值 |
| --- | --- |
| `dataset_id` | `olist-ecommerce` |
| `data_version` | `olist-ecommerce-<16 位十六进制>`，取自「生成器版本 + 定义文件 `olist.yml` 的 sha256 + 九个 parquet 的 sha256（按文件名排序）」的 sha256 前 16 位。按输入定版本，不按 SQLite 文件的字节（同一台机器上两次生成字节相同，换机器、换 SQLite 版本不保证）；定义文件参与计算，改一个字版本就变，免得「同版本、内容不同」撞上登记的 409 |
| `title` | `巴西电商 Olist 样例（1/20 抽样，演示与评测用，CC BY-NC-SA 4.0）` |
| `security_code` | 不填（登记接口允许为空） |
| `source_app` | `knowledge-sample` |
| `start_date` / `end_date` | 样例里最早与最晚的下单日期：`2016-10-04` / `2018-09-06` |
| 文件 | 与现有数据集同形的 SQLite：业务表加自述表（`dataset_metadata`、`field_dictionary`、`metric_dictionary`、`table_links`、`table_keys`） |

**许可证**：Olist 数据集是 CC BY-NC-SA 4.0，只作演示与评测。注明在三处：标题（`list_datasets` 会带出来，专家的出处里就有）、`dataset_metadata` 的 `license` 与 `source` 两行、生成脚本与说明文档的开头。

### 3.2 九张表

表名改短：模型名就是 SQL 里写的名字，短名少出错。原文件名记在 `dataset_metadata` 的 `source_<表名>` 行里。

| 表 | 原文件 | 样例行数（全量） | 主键（`table_keys.key_columns`） | 说明字段（`label_columns`） |
| --- | --- | --- | --- | --- |
| `orders` | `olist_orders_dataset` | 4917（99441） | `order_id` | `order_status`、`order_purchase_timestamp` |
| `order_items` | `olist_order_items_dataset` | 5587（112650） | `order_id, order_item_id` | `product_id`、`seller_id` |
| `order_payments` | `olist_order_payments_dataset` | 5124（103886） | `order_id, payment_sequential` | `payment_type` |
| `order_reviews` | `olist_order_reviews_dataset` | 4903（99224） | `review_id, order_id` | `review_score` |
| `products` | `olist_products_dataset` | 3773（32951） | `product_id` | `product_category_name` |
| `customers` | `olist_customers_dataset` | 4917（99441） | `customer_id` | `customer_unique_id`、`customer_state` |
| `sellers` | `olist_sellers_dataset` | 1219（3095） | `seller_id` | `seller_state` |
| `geolocation` | `olist_geolocation_dataset` | 4147（1000163，汇总后每个前缀一行） | `geolocation_zip_code_prefix` | `geolocation_state` |
| `product_category_translation` | `product_category_name_translation` | 71（71） | `product_category_name` | `product_category_name_english` |

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

`geolocation` 不建关系：汇总后虽然每个前缀一行，但它的前缀字段名与客户、卖家的不同，知识服务的关系要求两边同名。说明写进 `dataset_metadata`，要用自己写关联条件。

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
| `start_date` / `end_date` | `2016-10-04` / `2018-09-06`（由生成脚本按样例算） |
| `complete_start` / `complete_end` | `2017-01` / `2018-08`：数据集声明的连续完整月份 |
| `period_formats` | 月 `YYYY-MM`，季度 `YYYY-Qn`（例 `2018-Q2`），年 `YYYY` |
| `currency` | 巴西雷亚尔（BRL） |
| `license` / `source` | CC BY-NC-SA 4.0；Olist 在 Kaggle 发布的公开数据，经 WrenAI 样例文件取得，只作演示与评测 |
| `source_<表名>` | 原文件名与 sha256 |
| `note_sample` | 这是全量按真实客户 1/20 抽出的样例，内部完整；绝对数约为全量的 1/20 |
| `note_truncation` | 2016 年只有 10 月的 18 单；2018-09 只有 1 单（已取消），之后没有数据，是数据截断，不是业务下滑；2018 年第三季度不完整 |
| `note_no_cost` | 不含成本、费用、利润，毛利与利润率算不出来 |
| `note_customer_id` | `customer_id` 一单一个，客户数与复购用 `customer_unique_id` |
| `note_status` | 收入类口径剔除 canceled、unavailable；取消率的分母含全部状态 |
| `note_geolocation` | 每个邮编前缀一行（经纬度平均、城市与州取最常见的写法），只含客户与卖家用到的前缀；字段名不同，要自己写关联条件 |
| `note_category` | 610 个商品无品类，13 个商品的品类无英文名；按品类汇总时单列「未知」 |

`describe_schema` 不带这些说明；专家方法要求第一步用 `run_sql` 读 `dataset_metadata` 全部行（财报体检已是这样做）。

### 3.8 生成与登记

| 处 | 做什么 |
| --- | --- |
| knowbase-backend `app/datasets/olist/olist.yml`（新） | 声明：九个文件的地址与 sha256、表名对照、主键、关系、字段字典、口径、说明。**数据集的定义只有这一份** |
| knowbase-backend `app/scripts/build_olist_dataset.py`（新） | `--cache <目录> --out <文件>`：缺文件就下载，sha256 不对就停；用已有依赖（DuckDB）读 parquet、写 SQLite；写完用 `read_description()` 自检、生成一次语义模型；打印 `data_version`、`sha256`、`size_bytes`、起止日期，供登记 |
| 测试 | 用几行合成数据造小 parquet（测试里现造，不进仓、不联网）：生成、自述校验、语义模型、口径行原样返回且不可查、类型映射、地理表无关系、两次生成 `data_version` 相同、sha256 不对时停 |
| k8s `sunmoonai/scripts/local-integration/dataset-chain/`（Qwen 在本地做） | 加一个样例桶 `development-knowbase-samples`（只给知识服务读）、`run.sh sample olist`（生成 → 上传样例桶 → 登记）、`driver.py verify-sample olist`（第四节的检查）。登记直接调知识服务的登记接口，用替身发的服务令牌，`source_app = knowledge-sample` |

数据文件、parquet、生成出的 SQLite 都不进 git。生产上谁来登记、桶叫什么，留到发布时定（第九节）。

**集群里怎么登记（2026-10-13 发布卡 44 定）**：知识服务能登记、能读的桶与前缀只有 `knowfeed-originals/knowfeed/`，所以样例放 `knowfeed-originals/knowfeed/samples/olist-ecommerce/<版本>/`，由 knowfeed 后端 API 容器里的 `gitops/components/app-platform/knowbase-app/knowbase-backend/samples/register-olist.py` 用 knowfeed 的对象存储写权限上传、用 knowfeed 的服务身份登记（`source_app = knowledge-sample`）。不重建知识服务镜像、不动它的 config。单开知识服务自己的样例桶要改对象存储策略与 provider Job，样例不止一份时再做。

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

### 5.2 五步（2026-10-13 定稿：编排逐步定死，PPT 按此讲）

| 步 | 工具 | 做什么 | 交回物关键字段 | 当场验什么 | 不过去哪 |
| --- | --- | --- | --- | --- | --- |
| `scope` 定范围 | `list_datasets`、`describe_schema`、`metric_definitions`、`run_sql` | 先按口径种类筛数据集：本版只支持按期汇总的（`kind=aggregate`），财报类（`kind=row`）不支持；问题点了名就用点名的，没点名（「这个公司」「它」）而只剩一份符合就用它并写进 `assumptions`，不止一份符合就问你是哪一份；都不符合就把 `dataset` 留空；读 `dataset_metadata` 全部行；把问题落到口径（名字与种类照抄）、期间、粒度（不细于数据存的粒度；没给期间用完整期间，没有声明就最多最近 36 期）；数据集里没有的口径列进 `unavailable` | `dataset`、`data_version`、`question`、`period`、`complete_period`、`metrics`（名字、种类）、`unavailable`、`notes`、`assumptions` | 格式对；必备字段齐；`dataset` 不为空；`metrics` 至少 1 个；**`metrics` 的种类全是 `aggregate`**（不过的说明：本版只支持按期汇总的经营数据，财报类请用「财报体检」） | **交人** |
| `pull` 取数 | `describe_schema`、`run_sql` | 按口径取期间序列；每列写来源（表、字段、过滤）；被认作不完整的期列进 `excluded_periods`；交回实际执行的 SQL | `columns`（名、中文、来源）、`rows`、`excluded_periods`、`sql`、`data_version` | 格式对；`rows` 至少 1 行；`sql` 不为空 | **重做 1 次**，仍不过交人：多半是 SQL 或格式写错 |
| `analyze` 分析 | `run_sql` | 趋势（环比、同比）；结构（区域、品类的占比与变化，按问题需要）；季节性只在有两个完整周期时才说；每条发现带支撑它的 SQL 与数 | `findings`（文字、数、SQL） | 格式对；`findings` 至少 2 条 | **退回取数 1 次**（`max_reworks=0`，不先重做本步），回来仍不过交人：分析不过多半是取的数不对 |
| `forecast` 预测 | `run_sql` | 方法固定（5.3）：认完整期 → 回测 → 外推 → 季度合计；全部在 SQL 里算 | `method`、`window`、`excluded_periods`、`assumptions`、`rows`（`period`、`forecast_point`、`forecast_low`、`forecast_high`）、`quarters`、`backtest`、`sql` | 格式对；必备字段齐；`assumptions` 至少 2 条；`rows` 至少 1 行 | **不返工，交人**（`max_reworks=0`）：方法固定，返工提示会催模型改方法、凑结果，等于把不平的数做平（与财报体检的勾稽、对照官方同理） |
| `writeup` 成稿 | 无 | 按 0015 写 `底稿/财务分析与预测-成稿.md`：回答、数据（带角标）、专家验过什么、局限、出处；`unavailable` 与截断必须进局限；不贴 JSON；最后照例写 `交回.md` | `answer`、`limitations`、`citations` | 格式对；有正文；`limitations`、`citations` 各至少 1 条；无买卖建议（`no_positioning_advice`）；成稿文件存在（`deliverable_check`） | **重做 1 次，仍不过交人**：补局限、出处这类内容，没有凑数的风险（与财报体检的成稿相同） |

`reserve` 与输入长度照 `FIN_REVIEW` 的量级定，跑分后回填。`field_words.py` 补齐新字段的中文词（现有测试会查）。

**2026-10-14 现网事故与第 2 版**：所有者问「预测这个公司下个季度的表现」，知识服务里有 Olist 与 600009 两份数据，第 1 版的定范围只写了「按标题和表挑一个能回答的」，模型自己挑了 600009（财报，季报中报年报是累计数）；取数一步要求「按月」，模型把 1994 到 2026 年按月铺开，两次撞上 15 分钟的单步超时，交回不完整，验收不过。第 1 版的方法没有拦住设计里写明「以后再接」的 A 股财报。第 2 版（`version="2"`）：定范围先按口径种类筛、指代不清就问、确定性验收要求口径种类全是 `aggregate`；取数不许拆得比数据存的粒度更细。

**同日第二处：成稿步耗满时限**：那一单第 1 版的任务走到成稿，在所有者的 Windows 电脑上两次耗满 15 分钟。模型想改项目里昨天那份成稿，补丁对不上原文连错两次，又把 bash 写文件的写法交给 PowerShell；到点被停下后，工作台把最后一句进度说明（「准备写文件」）当交回物去验，报成「交回物不是 JSON 对象」，真正的原因被盖住了。修在工作台（`f89de88`，所有专家共用）：到点停下的步骤记一条「在时限内交回」不过，其余各条「没有验」，照常走返工、退回、交人，返工额度照算；写文件的说明改成一个 `*** Add File` 整份写（覆盖旧文件），不用 Update File，先写文件、最后一句只回 JSON。根子在 Codex：它不认识的模型（kimi-k3）拿不到 apply_patch 工具，只能经命令行调，而命令行里只有整条命令恰好是 `apply_patch <<'EOF' … EOF` 时 Codex 自己接住（PowerShell 也按 bash 语法解析，见 Codex `apply-patch/src/invocation.rs`），别的写法原样交给 PowerShell、报找不到 apply_patch；所以说明里把补丁格式和命令样子写死（`ee5ee62`）。第二次成稿过了，是模型自己翻到 `codex.exe --codex-run-as-apply-patch` 写进去的，不算稳定能力。成稿硬检查这一单没有生效（`seen=false`、`checked=events`）：现网会合点镜像没有 `/service` 路由（回 1008 unknown path），卡 42 写了「会合点另开卡」，没人开；Opus 补了卡 46（会合点源码锁 `4d0ff04` → `4028d32d`，只重建会合点）。现网那个 `4d0ff04` 是 10-08 luna 上后来被改写的提交，内容按时间应是 `1d01771f`，卡 46 第一步用现网 `relay.py` 的 sha256 核对。本地核查还指出两处留待以后：上游交回物按 24000 字截断（第 2 版只认按期汇总的数据，取数小得多，暂不动）；财报口径（比率、存量、累计数不能相加）在第 2 版里直接不接。成稿步方法里「不调任何工具」改成「不调数据工具」，和要写文件不再矛盾。

**同日第三处：底稿覆盖、对话页看不懂**（所有者提）：两次委托都写同一份 `底稿/财务分析与预测-成稿.md` 与项目根的 `交回.md`，后一次盖掉前一次；对话页在专家那一段只有「交给了专家 / 这一部分还在做 / 专家交回了」，重新打开会话看不出发生了什么。改法见 0015 §3.3 末两行（后端 `61f0266`、网页 `a4f5396`）：每次委托一格存底稿，对话页照常摆过程、交回时指向右边栏「工作底稿」。与第 2 版、成稿步修复一起走卡 45。

**卡 45 上线后第一单就被打回**（2026-10-14 13:52，任务 `3dc4e13d`，所有者本地核查）：建单记 `profile_version` "1"，受理时找不到第 1 版专家包，REJECTED / `no_expert_pack`，一步没做、没写底稿；对话页交回那一行却照「没做完」说「底稿在右边栏」。根子：入口（网页、委托）都不传版本，账房 `handover` 默认写死 "1"，第 2 版升版时没跟着改，测试的委托又都走版本 1 的专家包。修法（后端 `e937bba`、网页 `6321e7c`，卡 47）：没点名版本就绑现在上架的那一版；专家还在、只是绑的那一版已换下，打回原因记 `pack_version_gone`（「按旧版建的，请重新请一次专家」）；交回事件带一句为什么，打回那一行说「一步也没做，没有写底稿：…」，不摆「打开工作底稿」。以后升版：其余各处（runner、专家台、底稿清单）都按委托记的版本找专家包，升版前建的、还没做完的委托会被打回，发布前照旧要求页面上没有在跑的这位专家的委托。卡 47 于 2026-10-14 16:10 上线（stage `b368c6cf`、晋级 `8de81580`，后端 `e937bba`、网页 `6321e7c`；qwen 那时已到卡 48 那一版，发卡期间临时检出卡 47 三钉、发完切回），回执 `scripts/results/fin-forecast-pack-version-cursor.20261014-1610.md` 远程核过；真人验收待所有者：新开对话再请一次财务分析与预测，应真开工。

**失败去向的执行顺序**（`advisor.py`）：先看本步还有没有返工额度（`max_reworks`），有就重做本步；用完了，`on_reject="back"` 的退回 `back_to`（次数受 `max_backs` 限）；再不行交人。所以「不过直接交人」要写成 `on_reject="human"` 加 `max_reworks=0`。

**「缺数据」怎么停**：现有的 `missing_data` 只认六位证券代码，Olist 这类非证券数据集触发不了它；这里不改机制，改由定范围的验收「`dataset` 不为空」加「不过交人」做到同样的效果——找不到数据集就停下问你，不硬算。以后接 A 股公司时，定范围再配上 `missing_data`（证券代码写在交回物里），没入库的公司照财报体检那样记需求。

### 5.2.1 什么时候停下来问你

| 时机 | 怎么停 | 机制 |
| --- | --- | --- |
| 找不到能回答的数据集、范围认不出 | 定范围不过，交人 | `on_reject="human"` |
| 预测不合格 | 不返工，交人 | `max_reworks=0`、`on_reject="human"` |
| 分析再退回一次取数仍不过 | 交人 | `max_backs=1` 用完 |
| 要跑命令 | 每条问你；改项目外的文件一律拒绝；不联网 | 专家包 `tool_policy`（命令问人、项目外拒绝、网络拒绝） |
| 它自己有疑问 | 弹出提问，每步最多 3 问；问不到就写明假设继续 | `questions: allow`、`max_questions: 3` |

### 5.2.2 和另外两位专家的编排有什么不同

| | 问数 | 财报体检 | 财务分析与预测 |
| --- | --- | --- | --- |
| 步数 | 5：改写 → 生成 SQL → 执行 → 整理 → 成稿 | 7：定范围 → 数据摸底 → 勾稽 → 取数 → 算指标 → 对照官方 → 成稿 | 5：定范围 → 取数 → 分析 → 预测 → 成稿 |
| 主线 | 把一句话变成一条对的 SQL | 先验数据能不能用，再算指标、对照公司披露 | 把口径定死，看清过去，按说得清的方法外推 |
| 关键把关 | 执行不过退回重写 SQL | 勾稽、对照官方不给返工，不平就交人 | 预测不给返工；先回测再外推；截断与缺的口径照实写 |
| 数据从哪来 | 默认数据集 | 按证券代码找；没入库就记需求、问你 | 按问题找；找不到就问你 |
| 计算 | SQL | SQL 加按口径名查询 | 全部 SQL，结果列用口径名作别名 |
| 交回 | 一张结果表与成稿 | 指标表、勾稽与对照结论与成稿 | 取数表、分析发现、预测表（方法、区间、假设、回测）与成稿 |

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

## 五之二、演示案例（PPT 已用，做出来必须一致）

所有者 2026-10-13 要现在就演示，PPT（`~/财务分析与预测智能体/财务分析与预测智能体.pptx` 第 6 到 13 页）按本节与 5.2、5.2.1、5.2.2、5.3 画：第 6 页五步，第 7 页编排总表（5.2 的工具、交回物、验收、失败去向，与 5.2.1 的停点），第 8 页定范围，第 9 页走势，第 10 页预测方法（5.3），第 11 页预测，第 12 页成稿，第 13 页三位专家对比（5.2.2）。专家包与评测**以本节为准**，改了方法或口径要同步改 PPT。

| 项 | PPT 上的样子 | 来自 |
| --- | --- | --- |
| 问题 | 近两年按月收入怎么走，预测下两个季度 | — |
| 五步 | 定范围 → 取数 → 分析 → 预测 → 成稿 | 5.2 |
| 两条特点 | 数都有出处（计算都用查询，每列写明出自哪张表、什么口径）；预测带区间和假设（先回测，截断月份与缺的成本照实写） | 5.1、5.3 |
| 走势 | 按月成交额柱状图 2017-01 至 2018-08；2017 年爬坡（1 月 0.58 万到 10 月 3.17 万）、2017-11 大促尖峰 6.1 万、2018 年每月 4.4～7.0 万、二季度同比 +155%；2018-09 只有 1 单（已取消）是截断 | 样例 + 3.6 口径 |
| 预测 | 每月点估计 5.73 万（区间 4.44～6.97 万）；2018 年三季度 15.1 万（13.8～16.4 万，7、8 月实际 9.38 万 + 9 月预测）；四季度 17.2 万（13.3～20.9 万） | 5.3 |
| 回测 | 窗口 2017-09 至 2018-02，预测其后 6 个月：5 个落在区间内，平均绝对百分比误差约 22%；2018-05 高出区间（增长期会低估） | 5.3 |
| 成稿 | `底稿/财务分析与预测-成稿.md`：回答、数据、专家验过什么、局限、出处；另有 `交回.md`；不给评级、目标价、买卖建议 | 0015、`deliverables.py` |

数是按本文口径在 1/20 样例（`olist-ecommerce-dcca129e2ea0cb56`）上用 SQL 算出的；评测里加一道与这个问题同形的题（第三季度、第四季度的点估计与区间作真值，列名 `period`、`forecast_point`、`forecast_low`、`forecast_high`）。

## 六、评测 `fin_forecast_10`

放 `investment-backend/app/eval/cases/fin_forecast_10.json`，格式与 `fin_review_13.json` 相同；`data_snapshot_id` 为 3.1 的 `data_version`；评测按语义层开着跑（`--dialect duckdb`）。真值查询的列名与口径名、`period` 一致。

| # | `case_id` | 问题 | 真值查询的列 | 陷阱与必须提醒 |
| --- | --- | --- | --- | --- |
| 1 | `ff-gmv-monthly` | 2017 年 1 月到 2018 年 8 月，按月的成交额和订单数 | `period`、`gmv`、`order_count`（20 行） | 剔除取消与不可用 |
| 2 | `ff-gmv-quarterly-yoy` | 按季度看成交额，2018 年第二季度比上年同期增长多少 | `period`、`gmv`（2017-Q1 到 2018-Q2，6 行） | 季度格式 `YYYY-Qn` |
| 3 | `ff-state-top5` | 全部数据里，成交额最高的五个州是哪些，各是多少 | `customer_state`、`gmv`（5 行） | 用卖家所在州 |
| 4 | `ff-category-top10` | 商品收入（不含运费）最高的十个品类 | `product_category_name_english`、`item_revenue`（10 行） | 品类为空与无英文名 |
| 5 | `ff-category-margin` | 哪个品类毛利率最高 | 无真值查询 | 必须提醒：任一「不含成本」「没有成本」「无法计算毛利」；不得出现「毛利率为」 |
| 6 | `ff-installment-share` | 用信用卡付款的订单里，分期的占多少 | `credit_card_installment_share`（1 行） | 按订单去重 |
| 7 | `ff-cancel-monthly` | 2017 年 1 月到 2018 年 8 月每月的取消率 | `period`、`cancel_rate`（20 行） | 分母含全部状态 |
| 8 | `ff-repeat-customers` | 下过不止一单的客户占多少 | `repeat_customer_share`（1 行） | 用 `customer_id` 得 0 |
| 9 | `ff-demo-forecast` | 近两年按月收入怎么走？预测下两个季度（演示题，五之二） | 真值一：`period`、`gmv`（2017-01 至 2018-08，20 行）；真值二：`period`、`forecast_point`、`forecast_low`、`forecast_high`（2018-Q3、2018-Q4，2 行；三季度 = 7、8 月实际 + 9 月预测） | 必须提醒：任一「截断」「不完整」；任一「假设」；不得出现「一定会」「保证」 |
| 10 | `ff-backtest-orders` | 只用 2018 年 2 月及以前的数据，预测 2018 年 3 月到 8 月的订单数，和实际比误差多大 | 真值一：`forecast_point`、`forecast_low`、`forecast_high`（2017-09 到 2018-02 的订单数，1 行）；真值二：`period`、`order_count`（2018-03 到 2018-08，6 行） | 必须提醒：任一「误差」 |

预测题的真值是「这份方法正确用在正确的数上」的结果，不是真实的未来；这在案例的 `description` 里写明。容差：金额 0.01，比率 0.0001，计数 0。

做出来的样子（2026-10-13，第 2 段）：题在 `investment-backend/app/eval/cases/fin_forecast_10.json`，固定数据 `eval/fixtures/olist-ecommerce.dataset.bin`（即 1/20 样例，3858432 字节，`data_version` `olist-ecommerce-dcca129e2ea0cb56`），十题共 11 条真值查询，全部写 DuckDB 方言。测试在 `tests/test_eval_fin_forecast.py`。顺带改了评测的装载：`TruthStore` 在 DuckDB 模式下原来逐行 `executemany`，样例要 83 秒；改为每张表先写临时 CSV 再由 DuckDB 读入，0.74 秒，逐表逐行与 SQLite 相同（只改装载方式，判定不变）。

**「10 题过 ≥ 8」怎么算**：一题算过 = 质量、引用、必须提醒三栏都过（比发布门严：发布门不看必须提醒）。只考边界的第 5 题没有真值查询，质量栏按现有判法算过，它的过不过实际由必须提醒决定。

## 七、规矩对照

| 规矩 | 这里怎么守 |
| --- | --- |
| `C-A1` 新专家是新专家包 | 只改 `FIN_FORECAST` 这一份数据；不改机制 |
| `C-A8` WrenAI 只用引擎 | 只借它的样例数据与说明文字；知识后端里引擎的用法不变 |
| `C-A9` 供应商不调模型 | 不变 |
| `C-D1` 一个权威主档 | 主档是对象存储里登记的那份 SQLite；parquet 是外部来源，生成脚本按 sha256 钉住 |
| `C-D4` 对象存储按领域拥有 | 样例放知识服务自己的样例桶，不放 knowfeed 的桶 |
| `F-POS` 不给买卖建议 | 成稿步骤加 `no_positioning_advice` 验收；边界写进六问 |
| 用户字面无代号、无 JSON | 现有测试会拦；`preparing_note` 清空、标题去掉「筹备中」时一起过 |

## 八、分段与停点

| 段 | 谁做 | 做什么 | 停点怎么算过 |
| --- | --- | --- | --- |
| 1 数据 | Opus（远程）；Qwen（本地联调链） | 第三节；联调链加样例 | 远程：knowbase 后端三件套过；生成脚本对真实数据跑两次 `data_version` 相同；经知识服务的 MCP 处理链（语义层开着）第四节五项全过。本地：联调链 `run.sh sample olist` 与 `driver verify-sample olist` 原文 |
| 2 评测题 | Opus | 第六节十题 | 真值查询在数据集上逐条跑通、结果贴回执；`run_eval.py --cases fin_forecast_10 --profile FIN_FORECAST` 能跑（专家包还是占位时允许全不过） |
| 3 方法 | Opus | 第五节 | 专家包规矩测试全过；用真 Codex 对本地 knowbase 跑一遍五步；十题过 ≥ 8（按第六节的算法） |
| 4 切真 | Opus；Qwen（本地 KIND 完整委托与浏览器） | `status="ready"`、`version="1"`、标题去「筹备中」、`preparing_note` 清空 | 后端全量测试过；回执附一次完整委托的事件摘要与成稿文件；本地浏览器里专家页与成稿 |

**第 4 段提前切了代码**（所有者 2026-10-13：「现在好像要把筹备中改了吧，否则点击不了啊」）：investment-backend `FIN_FORECAST` 已是 `ready`、版本 `1`、标题去掉「筹备中」、`preparing_note` 清空。本地十题的线（第 3 段）照样要过；没过线就改方法、升版本。要在站点上点得到，还要合并与发布。

每段写回执 `k8s/sunmoonai/scripts/results/fin-forecast-<段>-<日期>.md`（Opus 的远程部分与 Qwen 的本地部分各一份，文件名里带 `-remote` / `-local`）；本地部分 Opus 审过才算这一段过。

## 九、要所有者定的、要记的

| 项 | 建议 | 状态 |
| --- | --- | --- |
| 任务清单里的「品类利润率」 | 数据里没有成本，改成第 5 题那样的边界题：考专家会不会照实说「算不出来」 | **已定**（所有者 2026-10-13：「这正是我们要的不硬算、不冒充」） |
| 「10 题过 ≥ 8」的算法 | 三栏都过才算过（第六节） | **已定**（所有者 2026-10-13：「内部门槛比发布门严没坏处」） |
| 生产上的样例桶与登记身份 | 先用 `knowfeed-originals/knowfeed/samples/` 与 knowfeed 的服务身份（见 3.8 末段）；单开样例桶留到样例不止一份时 | 已定（发布卡 44） |
| 专家包标语「收入、成本、现金流」 | 专家包是通用的，以后接 A 股要用；对 Olist 照实说没有成本与现金流。标语不改 | 已定（本文） |
| 预测题用固定方法出真值 | 方法一旦改，真值跟着改；方法改了要重定第 9、10 题 | 已定（本文） |
