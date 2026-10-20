# knowfeed-app：采集

> 最后更新：2026-10-16 ｜ 按代码现状重写 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

**层与线**：第 6 层应用层；第 7 层产品线里的**数据线**（knowfeed → knowbase）。

从公开来源取原件、建证券数据集、做质量检查，然后向 knowbase 登记「有一个新版本」。属于**数据线**：是我们自己的内部工具，不作为用户专家的数据源（`C-L2`）。2026-10-15 由 `info-app` 改名而来，数据从空库开始。

## 领域

| 块 | 代码 | 表（节选） |
| --- | --- | --- |
| 采集 | `application/services/info_crawl_service.py`、`infrastructure/{external,search,storage}` | `knowfeed_source`、`knowfeed_collector`、`crawl_job`、`raw_artifact`、`knowfeed_document`、`knowfeed_document_version`、`extracted_content` |
| 证券数据集 | `domain/securities/`（数据集、财务口径、登记、报表、申请）、`infrastructure/securities/` | `security_dataset`、`security_ingestion`、`security_ingestion_item` |
| 采集申请与关注清单 | `domain/securities/requests.py` | `security_request`、`security_request_requester`、`security_watchlist`、`security_watchlist_log` |
| 投递 | `application/services/delivery_outbox.py`、`infrastructure/messaging/` | `outbox_message`、`inbox_message`、`distribution_record` |

设计：[0008](../../dev-investment-agent/tree-build/SDD/modules/0008-info.md)；后端自己的说明在 `knowfeed-backend/docs/`（证券入库 `SECURITY_INGESTION.md`、报表抽取 `REPORT_EXTRACTION.md`、投递与调度的几份）。

## 和别的应用

- **向 knowbase 登记**：服务身份 `knowbase:ingest`（`infrastructure/external/knowbase_app.py`），契约 `knowfeed-knowbase-artifact` v1，schema 真源在 knowbase，本仓只持锁 `contracts/knowbase-provider-lock.json`。没过质量检查的数据不登记。
- **原件与数据集文件**放在自己的对象存储桶 `knowfeed-originals`，键前缀 `knowfeed/`（原文 `knowfeed/original/…`、数据集 `knowfeed/securities/…/datasets/…`）；knowbase 只按登记的位置**只读**取文件。
- 记录来源的 `source_app` 值：采集服务写 `knowfeed-app`，数据集登记器写 `knowfeed`（两种，不合并）。
- knowbench 管理端的「缺数据的需求」链到本应用管理端发起采集。

## 界面

- **管理端**（`knowfeed-admin.sunmoonai.com`）：采集、证券、需求、关注清单（`/zh-CN/knowfeed/…`）；按应用角色显示，现行部署没配角色白名单，暂时看不到（总览「已知缺口」）。
- **网页端**：没有功能页，只有一句说明。只在所有者机器上可访问。

## 部署

`k8s/gitops/components/app-platform/knowfeed-app/`：`database`、`migration`、`redis`、`rabbitmq`、`identity`、`service-identity`、`storage`、`runtime`。Worker 有出站到公网站点的网络策略（`config.yaml` 的 `domain_egress`）。表名在 2026-10-15 的迁移里从 `info_*` 改为 `knowfeed_*`。
