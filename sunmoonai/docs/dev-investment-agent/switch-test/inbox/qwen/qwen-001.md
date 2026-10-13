# 给 Qwen：财务分析与预测 第 1 段——Olist 数据集进 knowledge（账 96）

> Opus 2026-10-13 在远程机写；你在本地机做，两边只经 git 来往（所有者同步）。设计全文：[`tree-build/SDD/modules/0023-fin-forecast.md`](../../../tree-build/SDD/modules/0023-fin-forecast.md)，**表名、主键、关系、类型、口径、说明以它第三节为准**；设计走不通先停下，在回执里写清楚交 Opus，不自己改设计。
> 工位 `~/worktrees/qwen/*`，分支 `qwen`。基线：knowledge-backend `548e84a`，k8s `451b3fae`（或之后本工位上的提交）。本地提交，**子仓先、父仓后**，不 push、不合并别的分支。只做本页；第 2 段（评测题）等 Opus 审过本段再发。

## 一、要做的

### A. knowledge-backend（`knowledge-app/knowledge-backend/app`）

| 处 | 做什么 |
| --- | --- |
| `app/datasets/olist/olist.yml`（新） | 数据集的唯一定义：九个文件的地址与 sha256（见下表）、表名对照、主键与说明字段、七条关系、字段字典（中文名、单位、WrenAI 英文说明原文）、十一个口径、`dataset_metadata` 各行。WrenAI 的英文说明在上游 `Canner/WrenAI` 的 `legacy/v1` 分支 `wren-ui/src/apollo/server/data/sample.ts` 的 `ecommerce` 一段（`https://raw.githubusercontent.com/Canner/WrenAI/legacy/v1/wren-ui/src/apollo/server/data/sample.ts`）；本地机取不到就在回执里说，由所有者从远程机转 |
| `app/scripts/build_olist_dataset.py`（新） | `--cache <目录> --out <文件>`。缺 parquet 就下载到 `--cache`，sha256 对不上就停（非零退出）；只用已有依赖（DuckDB、标准库 `sqlite3`），**不加依赖**；按 0023 §3.3 映射类型，时间写成 `YYYY-MM-DD HH:MM:SS` 文字；写自述五张表；写完用 `app.infrastructure.semantic.sqlite_source.read_description()` 自检，再生成一次语义模型；最后打印一行 JSON：`dataset_id`、`data_version`、`sha256`、`size_bytes`、`start_date`、`end_date`、`title`。`data_version` 按 0023 §3.1 从输入算，不从输出文件算。文件开头写明许可证 CC BY-NC-SA 4.0、只作演示与评测 |
| `tests/test_olist_dataset.py`（新） | 测试里用 DuckDB 现造几行的小 parquet（不进仓、不联网），sha256 用测试自己算的值覆盖声明里的值。断言：生成成功；`read_description()` 通过；九张业务表与自述表都在；时间列是文字且格式对；邮编前缀保留前导零；`table_links` 七条、无 `geolocation`；`table_keys` 中明细表是两列主键；`metric_dictionary` 十一行、全部 `queryable = 0`、`row_filter` 与 `kind` 列在；经 `SemanticQueryService`（或现有测试里起语义层的同一种办法）调 `metric_definitions` 能拿到这些行且 `queryable` 为假；两次生成 `data_version` 相同；改一个 sha256 后生成失败 |
| `docs/` | 在 `docs/dataset-registry.md` 末尾加一小节「样例数据集」：怎么生成、怎么登记、许可证。不另起文件 |

九个文件（`https://assets.getwren.ai/sample_data/brazilian-ecommerce/<文件>.parquet`，Opus 2026-10-13 下载核过）：

| 文件 | sha256 |
| --- | --- |
| `olist_customers_dataset` | `2a52521a4d1d53451e4cfebbd7369fa589af09fc8758ef43df1c2de699eaee01` |
| `olist_geolocation_dataset` | `5cd727ebf0d600e8c3101558dfdaf4337029e3de08cea0cdfb4c7e01bbb3d286` |
| `olist_order_items_dataset` | `d3f75a00d0820e8da7205ae6fcebf4bcc7d50c4357f8641edd58f2f2392c264c` |
| `olist_order_payments_dataset` | `330adbbdb0dce4baac65dca09e655b71523aad3cb72c545ef362732b6a44cd6f` |
| `olist_order_reviews_dataset` | `16b04987266b5a0a881be83a5687191525e8408b71abe2c0f7669e9bf5c36e88` |
| `olist_orders_dataset` | `6aec6d54909f1b0895a654202abebb17dc35b52d0c6062562bad7b75166fe8b0` |
| `olist_products_dataset` | `38dd21f3deecc50a4d29b82c1a70b640c8f52315fb7bd81c0af7b5db4c7ed832` |
| `olist_sellers_dataset` | `cb26cab9c47e610dc170696f49781298257d1fa5e333a512d44bdf05db70a670` |
| `product_category_name_translation` | `9a982199b2f58b105e54bfeb231047b7d91b413f9f9c31e646cc333f4063e244` |

### B. k8s 联调链（`k8s/sunmoonai/scripts/local-integration/dataset-chain/`）

| 处 | 做什么 |
| --- | --- |
| `run.sh` | `up` 时多建一个桶 `development-knowledge-samples`（知识服务的存储账号只读；写入用联调链自己的管理账号）；知识服务的 `KNOWLEDGE_DATASET_ALLOWED_BUCKETS` 默认值加上它（逗号分隔，info 的桶照旧在）。新子命令 `sample olist`：调 A 的生成脚本（`--cache` 放 `$STATE/olist-cache`，`--out` 放 `$STATE/`）→ 上传到样例桶 → 登记。现有子命令的行为不变 |
| `register_sample.py`（新） | 读生成脚本打印的那行 JSON，`POST /api/internal/v1/knowledge/datasets`，令牌用替身发的服务令牌（与现有登记同一种取法），`source_app = knowledge-sample`；打印稳定的结果码，不打印令牌 |
| `driver.py` | 新命令 `verify-sample olist`，逐条 `record`：`list_datasets` 有它、标题带许可证、`security_code` 为空；`describe_schema` 九张业务表、不含 `phys_`；`metric_definitions` 十一行、`queryable` 全假；`run_sql` 读 `dataset_metadata` 拿到 `complete_end = 2018-08`；`run_sql` 按月成交额（下面的 SQL）与直接读生成出的 SQLite 逐行相同（20 行，金额容差 0.01） |
| `README.md` | 用法表加两行 |

按月成交额（DuckDB 方言，语义层开着；直接读 SQLite 时同一条也能跑）：

```sql
SELECT substr(o.order_purchase_timestamp, 1, 7) AS period,
       SUM(i.price + i.freight_value) AS gmv,
       COUNT(DISTINCT i.order_id) AS order_count
FROM order_items i JOIN orders o ON o.order_id = i.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND substr(o.order_purchase_timestamp, 1, 7) BETWEEN '2017-01' AND '2018-08'
GROUP BY 1 ORDER BY 1
```

Opus 直读 parquet 算出的首尾几行，供你对照（不是判据，判据是两条路相同）：`2017-01` 136943.46 / 787，`2017-11` 1172191.68 / 7421，`2018-08` 996973.51 / 6421。

## 二、停点（回执要有的）

1. knowledge 后端三件套原文：`uv sync --frozen`、`uv run ruff check .`、`uv run pyright`、`uv run pytest -q`（末尾几行即可，失败要全文）。
2. 生成脚本对真实数据跑一次的完整输出（那行 JSON）、用时、SQLite 文件大小；再跑一次，`data_version` 相同。
3. 联调链：`WORKSPACE=~/worktrees/qwen ./run.sh up`、`./run.sh sample olist`、`./run.sh driver verify-sample olist` 的原文输出，每条「通过 / 未过」都在。现有的 `driver verify 600009` 若你本机有采集结果也跑一次，证明没被改坏；没有就写「没跑，原因」。
4. 两仓的提交号：knowledge-backend 子仓、knowledge-app 父仓、k8s。

回执写 `k8s/sunmoonai/scripts/results/fin-forecast-1-<日期>.md`，原文输出，没做到的明说，不写「应该可以」。

## 三、规矩

- 不改知识后端的运行代码（`app/app/` 下除测试外不动）；真要改，先停下写清楚为什么，交 Opus。
- parquet、生成出的 SQLite、缓存目录不进 git；`.gitignore` 若漏了就补。
- 令牌、口令、存储凭据不进日志、不进回执。
- 不碰 `investment-app`（第 3 段才动专家包）；不改别的专家包、不改评测判定。
- 联调链的 `down` 会清掉状态目录，跑完再 `down`。
