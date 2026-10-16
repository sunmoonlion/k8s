# Cursor 回执：卡 44 财务分析与预测上线（投资后端 + Olist 样例）

时间：2026-10-13 13:48（UTC+8）。两部分都做完。没有 push，没有移动本待办。真人网页演示由所有者做，不记为本卡通过。

完成到：第一部分 `application-check APP=investment` 退出 0；第二部分登记 `registered` / HTTP 201。回退材料在 `~/sunmoon-probe-runs/fin-forecast-044/`，未使用。

## 前提

`~/worktrees/fable/k8s` 分支 `fable`；`samples/` 有 `README.md`、`register-olist.py`。改钉前：父仓 `102054b4…`、后端 `e73ffa5e…`、网页 `309e73d5…`。config 仍 `v7` / `'20261012_0018'`。knowledge-backend `e30525f`。`platform-status` 0。

## 第一部分：投资后端

| 步骤 | exit | 结果 |
| --- | --- | --- |
| 改钉（父仓 + 后端两行） | — | 网页仍 `309e73d5…`；admin 未动 |
| `platform-build OBJECT=app-platform/investment-app` | 0 | 仅后端锁变：`sha256:8c2b10c6…` / `15769d59…`；网页「已是这一份」`sha256:a5bfbb79…` |
| `platform-stage` / `application-deployment-plan` | 0 / 0 | 迁移 `investment-migrate-8c2b10c698c2-v7`；schema `20261012_0018` |
| stage 提交 | `bfab854f` | `deploy(investment): 财务分析与预测切成可用、五步方法（待办 44）` |
| `flux-release` | 0 | 候选 digest `sha256:172dd635…`，revision `bfab854f…` |
| 晋级提交 | `1b08693c` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0 |

## 第二部分：Olist 样例

WSL 代理 `192.168.32.1:7890` 当时不可达（Windows 侧只监听 `::`），改由 Windows `Invoke-WebRequest` 下载九个 parquet 到 `C:\Users\zymun\sunmoon-probe-runs\olist-parquet`，再拷入 `~/.cache/sunmoon-olist/parquet` 本地组库。

| 项 | 值 |
| --- | --- |
| knowledge-backend | `e30525f` |
| `uv sync --frozen` | 0 |
| `build_olist_dataset` | 0（从缓存组，约 1.9s） |
| data_version | `olist-ecommerce-dcca129e2ea0cb56` |
| sha256 / size_bytes | `1e5f9284b60ae2e9a87e40d80b171d356a997fdb8ccc0afb13fd35f4de274abe` / 3858432 |
| 登记 | `registered`，HTTP 201；`security_code: null`；`status: active`；`registered_by: admin/sunmoonai-info-knowledge-ingest` |
| object | `s3://info-originals/info/samples/olist-ecommerce/olist-ecommerce-dcca129e2ea0cb56/olist-ecommerce.sqlite` |
| knowledge-api 日志（5 分钟内） | 有登记相关 `audit_mutation … /knowledge/datasets status=201`；未见 olist 取文件失败 / sha 不符 / 语义建失败 |

parquet 与 sqlite 留在 `~/.cache/sunmoon-olist`，不进仓。

## 本地提交

`bfab854f` stage，`1b08693c` 晋级；本回执另提。不 push。

exit=0
