# 改名工具（R1 用；k8s/docs/rename.md）

R1 之前由 Opus 在远程机草稿目录里准备，在五组仓的副本上验证，存这里备查。R1 时照此执行：

```bash
python3 rename_rules.py <五组仓的上一级目录> --apply --report r1-report.json   # 内容替换（真仓里分仓提交；目录改名见 rename.md R1）
python3 manual_patch.py <改名后的采集后端 app 目录>                            # 规则做不对、要看上下文的几处
```

| 文件 | 是什么 |
| --- | --- |
| `rename_rules.py` | 替换引擎：按「改与留的界线」逐类规则 + 保留清单（占位保护）；套到路径上得出要 `git mv` 的目录与文件（**目录下全部跟踪文件都随目录走**，含不在替换范围里的已有迁移、图片、锁文件）；`uv.lock` 只改项目自身名字那一行；冻结件（已有迁移、为 0008 冻结的 `info_identity_v1.py` 扫描）不改 |
| `manual_patch.py` | 手工补丁：放入新迁移、迁移链清单测试补上它；测历史迁移 0007 / 0008 的测试——把新迁移包在外面、旧结构时段的 SQL 用旧表名、预检挪到降级后、写入前把查找路径限定在本测试的模式 |
| `migrations/knowfeed_20261015_0014_rename.py` | 采集后端新迁移：只改结构——四张 `info_*` 表改 `knowfeed_*`，名字带它们的约束 / 索引 / 序列改名（在 `current_schema()` 里找）。不改数据（所有者定：现有数据都不要，新库从空的开始） |
| `tests/test_knowfeed.sh` | 新迁移的独立验证：旧末端 + 模拟行 → 升级 → 回退 → 再升级 |
| `scan.sh` | 盘点用的 grep |

2026-10-15 验证（最终名字 knowfeed / knowbase，采集器仍叫 collector）：新迁移独立验证通过（4 表、22 个对象改名，回退复原）；采集后端全量测试改名前后对照见 `R1-opus` 回执。

仍要在 R1 里人工处理的：gitops `config.yaml` 的 `expected_schema_revision` 改 `20261015_0014`、`migration_job_revision` 加一；改名后的 knowfeed、knowbase 组件目录里旧的 `*.sops.yaml` `git rm`。
