# 改名工具（R1 用；k8s/docs/rename.md）

R1 之前由 Opus 在远程机草稿目录里准备、验证，存这里备查。R1 时照此执行，执行结果进 `docs/rename-receipts/R1-opus.*.md`。

| 文件 | 是什么 | 2026-10-14 验证 |
| --- | --- | --- |
| `rename_rules.py` | 替换引擎：按「改与留的界线」逐类规则 + 保留清单（占位保护），套到路径上即得要 `git mv` 的目录与文件；`--apply` 才写盘，`--report` 出每类每文件的处数 | 在五组仓的副本上：518 个文件；路径改名 13 处（6 个子仓目录、gitops 两个应用目录、3 个契约文件、2 份仓说明）；抽查无误伤（提示框类型 `'info'`、代理接口 `/local/v1/info`、需求编号 `F-INFO-*`、`cninfo` 都未动） |
| `scan.sh` | 盘点用的 grep（排除依赖、历史、样例） | — |
| `migrations/knowcollector_20261015_0014_rename.py` | 采集后端新迁移：四张 `info_*` 表改名，名字带它们的约束 / 索引 / 序列改名；桶与对象键前缀；`source_app` | 临时 PostgreSQL 上：旧末端 + 模拟行 → 升级（4 表、22 个对象改名，三表桶与键、source_app 换新）→ 回退（全部复原）→ 再升级，均通过 |
| `migrations/knowbase_20261015_0008_rename.py` | 知识后端新迁移：表名不动，只换两种 `source_app`、数据集桶与键前缀、`source_uri`、`canonical_url` 里的旧桶 / 前缀 / 域名 | 同上：升级、回退均通过 |
| `tests/test_knowcollector.sh`、`tests/test_knowbase.sh` | 上面两条验证的脚本（参数：装好依赖的后端目录；需本机 55440 口的临时 PostgreSQL） | — |

还要在 R1 里人工处理的：页面上英文文案里的应用名（Info crawl、Knowledge Admin 等，自动规则分不清领域词与应用名）；gitops `config.yaml` 的 `expected_schema_revision` 改为 `20261015_0014` / `20261015_0008`、`migration_job_revision` 加一。
