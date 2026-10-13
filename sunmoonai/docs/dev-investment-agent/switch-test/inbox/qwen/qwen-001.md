# 给 Qwen：财务分析与预测 第 1 段的本机一截——KIND 联调链接 Olist 样例（账 96）

> Opus 2026-10-13 在远程机写；你在所有者本地机做，两边只经 git 来往（所有者同步）。分工按 [opus-001](../opus/opus-001.md) 2026-10-13 的纠正：**远程能做的 Opus 已经做了**——数据集定义、生成脚本、测试、文档都在 knowledge-backend（提交号见 Opus 的回执 `k8s/sunmoonai/scripts/results/fin-forecast-1-remote-20261013.md`），远程三件套过、真实数据生成过、经知识服务的 MCP 处理链核过。**你只做本机才能做的这一截**：把样例接进本机联调链，跑通、贴原文。
> 设计：[`tree-build/SDD/modules/0023-fin-forecast.md`](../../../tree-build/SDD/modules/0023-fin-forecast.md) 第三、四节。设计或脚本走不通先停下，在回执里写清楚交 Opus，不自己改知识后端的代码与数据集定义。
> 工位 `~/worktrees/qwen/*`，分支 `qwen`；开工前 `git -C ~/worktrees/qwen/knowledge-app/knowledge-backend log --oneline -3` 核一下能看到 Opus 的提交「feat(datasets): 样例数据集 olist-ecommerce」，看不到就停，请所有者先同步。本地提交（只提交 k8s 仓），不 push、不合并别的分支。

## 一、要做的（k8s `sunmoonai/scripts/local-integration/dataset-chain/`）

| 处 | 做什么 |
| --- | --- |
| `run.sh` | `up` 时多建一个桶 `development-knowledge-samples`（知识服务的存储账号只读；写入用联调链自己的管理账号）；知识服务的 `KNOWLEDGE_DATASET_ALLOWED_BUCKETS` 默认值加上它（逗号分隔，info 的桶照旧在）。新子命令 `sample olist`：在 `$KNOW` 下跑 `uv run python -m scripts.build_olist_dataset --cache $STATE/olist-cache --out $STATE/olist-ecommerce.sqlite`（第一次会下载九个 parquet，约 55 MB）→ 把生成的文件上传到样例桶，键 `samples/olist/<data_version>/olist-ecommerce.sqlite` → 调 `register_sample.py` 登记。现有子命令的行为不变 |
| `register_sample.py`（新） | 读生成脚本最后打印的那行 JSON（`dataset_id`、`data_version`、`title`、`source_app`、`sha256`、`size_bytes`、`start_date`、`end_date`），加上桶与键，`POST /api/internal/v1/knowledge/datasets`；令牌用替身发的服务令牌，取法与现有 `register_once.py` 相同；`security_code` 不传；打印稳定的结果码，不打印令牌 |
| `driver.py` | 新命令 `verify-sample olist`，逐条 `record`：`list_datasets` 有 `olist-ecommerce`、标题带 `CC BY-NC-SA 4.0`、`security_code` 为空；`describe_schema` 九张业务表都在、不含 `phys_`；`metric_definitions` 十一行、`queryable` 全假；`run_sql` 读 `dataset_metadata` 拿到 `complete_end = 2018-08`；`run_sql` 按月成交额（下面的 SQL）与直接读 `$STATE/olist-ecommerce.sqlite` 逐行相同（20 行，金额容差 0.01） |
| `README.md` | 用法表加 `sample olist`、`driver verify-sample olist` 两行 |

按月成交额（DuckDB 方言，联调链的语义层是开着的；直接读 SQLite 时同一条也能跑）：

```sql
SELECT substr(o.order_purchase_timestamp, 1, 7) AS period,
       SUM(i.price + i.freight_value) AS gmv,
       COUNT(DISTINCT i.order_id) AS order_count
FROM order_items i JOIN orders o ON o.order_id = i.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND substr(o.order_purchase_timestamp, 1, 7) BETWEEN '2017-01' AND '2018-08'
GROUP BY 1 ORDER BY 1
```

远程机上同一份定义生成的结果，供你对照（不是判据，判据是 MCP 与直接读文件两条路相同）：`data_version` = `olist-ecommerce-5f4af057bf031216`，文件 sha256 `5366e6a6…`、114667520 字节；按月成交额首尾 `2017-01` 136943.46 / 787，`2018-08` 996973.51 / 6421。你那边的 `data_version` 应该相同（它只取决于定义文件与 parquet）；文件 sha256 若不同（SQLite 版本不同可能导致），照实写下即可，不算失败。

## 二、停点（回执要有的）

1. `WORKSPACE=~/worktrees/qwen ./run.sh up`、`./run.sh sample olist`、`./run.sh driver verify-sample olist` 三条的原文输出，每条「通过 / 未过」都在；`sample olist` 打印的那行 JSON 原样贴上。
2. 证明现有的没被改坏：本机若有 600009 的采集结果，跑一次 `./run.sh driver verify 600009`；没有就跑 `./run.sh negative 600009` 里不依赖采集的那几条，或写「没跑，原因」。
3. k8s 仓的提交号。

回执写 `k8s/sunmoonai/scripts/results/fin-forecast-1-local-<日期>.md`，原文输出，没做到的明说，不写「应该可以」。

## 三、规矩

- 只改 `dataset-chain/` 下的文件；不改 knowledge-backend、investment-app、数据集定义。生成脚本或知识服务报错就停下贴原文，交 Opus。
- parquet、生成出的 SQLite 都在 `$STATE` 下，不进 git。
- 令牌、口令、存储凭据不进日志、不进回执。
- 联调链的 `down` 会清掉状态目录，回执写完再 `down`。
