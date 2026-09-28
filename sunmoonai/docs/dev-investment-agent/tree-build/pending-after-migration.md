# 迁移完成后要做的事（账本）

> 规则（所有者 2026-09-28）：本地助手做集群迁移期间，凡是会影响迁移的部分，远程**不动，只记账**。
> 迁移完成、所有者说「luna 做完了」之后，按这张表逐项处理，处理完的划掉并写上提交。
> 远程在此期间只改三个应用仓库的代码与本文档目录。

## 怎么记

一行一件事：要做什么、为什么、是哪次改动带来的。只记会落到部署、集群、镜像、网络、存储上的事；应用代码自己的待办不记在这里。

## 账

| # | 要做的 | 为什么 | 来自 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | info 后端：数据库迁移到 `20260927_0012` | 采集批次、数据集、向知识服务登记的三张表与两列 | info-backend `1516f9f`、`f66a36f`、`688ebc7` | 待办 |
| 2 | knowledge 后端：数据库迁移到 `20260927_0007` | 数据集登记表 | knowledge-backend `a41299f` | 待办 |
| 3 | info 的配置：`KNOWLEDGE_APP_DATASET_URL` | 向知识服务登记数据集 | info-backend `688ebc7` | 待办 |
| 4 | knowledge 的配置：打开 `knowledge_dataset_registry_enabled`；`knowledge_dataset_allowed_buckets` 写 info 的桶 | 多数据集 | knowledge-backend `a41299f` | 待办 |
| 5 | knowledge 的存储账号对 info 的桶只读 | 知识服务按登记的位置自己取数据集文件 | 同上 | 待办 |
| 6 | knowledge 的配置：打开 `knowledge_semantic_engine_enabled`；`knowledge_semantic_cache_dir` 指到可写的目录 | 语义层 | knowledge-backend `98e83a0` | 待办 |
| 7 | knowledge 后端镜像增大约 600 MB；镜像仓库留出空间 | 语义层的依赖 | 同上 | 待办 |
| 8 | info 的出站网络策略：放行巨潮（`www.cninfo.com.cn`、`static.cninfo.com.cn`）与东方财富（`emweb.securities.eastmoney.com`） | 采集。新集群的网络策略真正生效，不放行就采不了 | info-backend `1516f9f` | 待办 |
| 9 | 三个后端与网页重新构建、发版 | 2026-09-27 以来的全部改动 | 各仓库 `fable` | 待办 |
| 10 | 数据盘上限是否从 100 GB 调高 | 全市场的财务数据；所有者未定，远程建议 200 GB | 决策文档 2026-09-28 | 等所有者定 |
| 11 | 外存储：内网另一台机器上装什么服务；从集群到它的出站放行 | 年报原件的转存与备份；所有者已定方向，做法未定 | 决策文档 2026-09-28 | 等所有者定 |
| 12 | 在新集群上跑通最小闭环（`0008-info` 段五） | 验收 `MVP-09` | — | 等集群 |
| 13 | info 的配置（可不配，有默认值）：`SECURITY_REPORT_MAX_BYTES`（默认 128 MiB）、`SECURITY_REPORT_TIMEOUT_SECONDS`（默认 180）、`SECURITY_QUALITY_HARD_YEARS`（默认 10，等所有者定） | 年报单份的大小与时限；质量检查硬性拦截的年数 | info-backend `e6032c1`、`cd0af51` | 待办 |
| 14 | info 后端容器的内存上限核一下：单份年报最大按 128 MiB 读进内存，再加 PDF 抽取 | 以前单份上限是 40 MB；建库实测峰值约 220 MB，是在小年报上测的 | 同上 | 待办 |
| 15 | 年报抽取接进流程时：抽一份年报约 20 到 75 秒、占一个核；要不要单独的工作进程 | 远程机上实测（小机器，内存紧张时更慢）。现在还没接进任何流程，**暂时不用做任何事** | info-backend `1529b15` | 等段八 |
