# 样例数据集

给专家「财务分析与预测」演示与评测用的公共样例，设计见 `docs/design/SDD/modules/0023-fin-forecast.md` 第三节。

| 样例 | 定义与生成 | 许可证 |
| --- | --- | --- |
| `olist-ecommerce`（巴西电商 Olist，按真实客户 1/20 抽样，约 4900 单） | knowbase-backend `app/datasets/olist/olist.yml`、`app/scripts/build_olist_dataset.py` | CC BY-NC-SA 4.0，只作演示与评测，不得商用 |

## 怎么进集群

知识服务的运行代码不用改，镜像不用重建：多数据集登记与语义层在本组件 `config.yaml` 里早已打开（`KNOWBASE_DATASET_REGISTRY_ENABLED`、`KNOWBASE_SEMANTIC_ENGINE_ENABLED`）。

1. 在有 knowbase-backend 源码的机器上生成（要联网下载约 55 MB 的 parquet，按 sha256 核对）：
   `uv run python -m scripts.build_olist_dataset --cache <缓存目录> --out <文件>`，最后一行是登记要用的 JSON。
2. 在 knowfeed 后端 API 容器里运行 `register-olist.py`：用 knowfeed 的对象存储写权限把文件放进 `knowfeed-originals` 的 `knowfeed/samples/olist-ecommerce/<版本>/`，再用 knowfeed 的服务身份调登记接口。用法见脚本开头。同一版本已登记就只报告、不再上传。

为什么放在 `knowfeed-originals`：知识服务能登记、能读取的桶与前缀只有 `knowfeed-originals/knowfeed/`（本组件 `config.yaml` 的 `KNOWBASE_DATASET_ALLOWED_BUCKETS` 与 `knowledge_provider.source_prefix`）。给样例单开一个知识服务自己的桶要改对象存储的策略与 provider Job，留到样例不止一份时再做。

## 怎么验

- 知识服务的登记表（knowfeed 服务身份 `GET /api/internal/v1/knowledge/datasets`）里有 `olist-ecommerce`，`data_version` 与生成结果一致，`security_code` 为空。
- 新登记最迟 30 秒后对 MCP 工具可见。
- 投资网页：请专家页「财务分析与预测」能点；在一个项目里问「近两年按月收入怎么走？预测下两个季度。」，专家第一步「定范围」认出这份数据集。
