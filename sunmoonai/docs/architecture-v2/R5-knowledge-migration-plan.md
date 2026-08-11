# Architecture v2 R5 Knowledge Backend 与数据库归并方案

状态：`R5-K0 DONE / R5-K1 DONE / R5-K2 DONE / R5-K3 DONE / R5-K4 DONE / R5-K5 DONE / R5-K6 DONE / Knowledge R5 DONE`

日期：2026-08-11

适用分支：`architecture-v2`

上游基线：`architecture-v2-r3.2-20260808`、Knowledge R4、R4.1、R4.2、Info R5 DONE

本文件是 R5 第二个串行对象 Knowledge 的权威施工方案。Investment 在 Knowledge 完成源码、
数据库、RAGFlow Provider 绑定、KIND 切换、回滚、声明式部署收口和证据门禁前不得进入 R5。

## 1. 冻结结论

1. `knowledge_admin` 继续作为规范物理数据库，逻辑所有者是统一 `knowledge-backend`；
2. Knowledge 没有第二个 Web 数据库，不制造空库迁移或双库合并工作；
3. 唯一 Alembic 链固定为 `20260710_0001 -> 20260712_0002 -> 20260715_0003 ->
   20260808_0004`，其中 `0004` 只增加通用 outbox/inbox；
4. RAGFlow 是 Knowledge 管理的外部索引 Provider，不是 Knowledge 领域数据库；稳定领域 ID、
   Provider dataset/document binding 和 RAGFlow 实体必须分别对账，禁止用 Provider ID 取代领域 ID；
5. API、Worker、Scheduler、Migration 使用同一 `knowledge-backend` 镜像和不同命令、身份、
   Secret、NetworkPolicy、资源及伸缩策略；
6. Admin/Web 两个 Next.js 前端保持独立身份表面，共用统一 Backend 与 `knowledge_admin`；
7. API 接受 Info 摄取和 Investment 检索的服务身份；只有 Worker 获得 S3 Artifact 与摄取所需
   RAGFlow 写凭据，API 只获得检索所需 Provider 能力，Scheduler 不获得 S3/Provider 凭据；
8. 现有 `sunmoonai-research-knowledge-retrieve` 是旧 Research 被 Investment 取代前的过渡身份。
   Knowledge R5 为保持现有调用者可回滚而暂时兼容；Investment R5 必须迁移为显式 Investment
   身份，旧身份只能在 R7 观察窗结束后退役；
9. R5 只做可回滚切换，不删除旧 Deployment、数据库角色、Secret、PVC、RAGFlow 数据或受保护
   镜像；删除属于 R7。

## 2. 2026-08-11 事实基线

### 2.1 规范库 `knowledge_admin`

| 项目 | 实测值 |
| --- | --- |
| PostgreSQL | 17.6 |
| 数据库 owner | `knowledge_admin_user_migration` |
| Alembic head | `20260715_0003` |
| 表 owner | 5 张表均为 `knowledge_admin_user_migration` |
| 约束 | PK 5、FK 2、Unique 5、未验证约束 0 |
| 业务不变量异常 | 0 |
| 通用 outbox/inbox | 均不存在 |

精确行数：

| 表 | 行数 |
| --- | ---: |
| `auth_user` | 1 |
| `knowledge_ingestion_job` | 38 |
| `knowledge_document` | 1 |
| `knowledge_document_version` | 1 |

摄取状态：`accepted=5`、`artifact_verified=18`、`artifact_unreadable=5`、`failed=6`、
`legacy_binding_missing=3`、`succeeded=1`。唯一稳定文档为 `active`，唯一版本为 `indexed`；
Provider binding 完整，领域/版本/摄取关联异常均为 0。

### 2.2 旧运行拓扑

`app-platform-dev` 当前只有两个 Knowledge v1 写角色：

- `knowledge-admin-backend`：1 副本，旧候选镜像；
- `celeryworker-knowledge-admin-backend`：1 副本，`1.0.1` 镜像。

当前没有 Knowledge Admin/Web 前端 Deployment，也没有旧 Web Backend。RAGFlow 及其
MySQL、Elasticsearch、MinIO、Redis 是共享 Provider 运行面，必须保持原样并单独对账。

旧 API 与 Worker 使用 `knowledge_admin_user`，Migration owner 使用
`knowledge_admin_user_migration`；两者仍可登录。正式切换后应改用：

- `knowledge_backend_user`：API/Worker/Scheduler DML；
- `knowledge_backend_user_migration`：Migration/DDL 与 owner。

## 3. 数据、Provider 与身份门禁

### 3.1 数据库迁移

正式库只允许从 `20260715_0003` 前滚到 `20260808_0004`。迁移前必须生成私有 custom-format
备份并完成隔离恢复；迁移后原四张业务表计数、状态分布、Provider binding 和全部业务不变量
保持不变，新建 `outbox_message`、`inbox_message` 且初始为 0。

Migration roundtrip 只允许在恢复副本执行 `0003 -> 0004 -> 0003 -> 0004`。正式库回滚保留
additive `0004`，禁止为恢复旧运行态破坏性 downgrade。

### 3.2 RAGFlow Provider

门禁必须同时证明：

- 数据库中的 `provider_dataset_id`、`provider_document_id` 非空；
- 对应 RAGFlow dataset/document 可由真实 API 读取；
- 真实检索能返回已绑定文档及稳定领域引用；
- 回滚/前滚前后 Provider 实体数量和绑定不漂移；
- 迁移不重建 dataset、不重复摄取、不伪造成功状态。

### 3.3 运行身份与最小权限

- API：数据库 runtime role、Redis session、Admin/Web OIDC、Info ingest 与过渡 retrieval 验证、
  RAGFlow 只读检索；不持有 S3 Artifact 凭据；
- Worker：数据库 runtime role、broker、S3 Artifact、RAGFlow 摄取、必要的内部调用身份；
- Scheduler：数据库 runtime role、broker/outbox 扫描；不持有 S3、RAGFlow 或调用者凭据；
- Migration：只持有 migration role；不持有浏览器、Provider、S3 或服务调用身份。

## 4. 串行施工步骤

### R5-K0 基线冻结

- [x] 盘点源码、旧 Deployment、Service、Ingress、PVC、Secret 键名和 RAGFlow 运行面；
- [x] 精确审计 `knowledge_admin` head、表计数、owner、约束、状态和不变量；
- [x] 生成私有备份并记录摘要；
- [x] 隔离恢复、对账并清理恢复库；
- [x] 读取并冻结真实 RAGFlow dataset/document 绑定与检索基线。

### R5-K1 源码、迁移链与配对

- [x] 复核 `20260808_0004` metadata、单 head 和 downgrade 边界；
- [x] 在恢复副本完成 migration roundtrip；
- [x] Backend Ruff、Pyright、全测试与生产镜像通过；
- [x] Admin/Backend 与 Web/Backend 源码、构建和配对门禁通过；
- [x] Info ingest、Investment retrieval、RAGFlow adapter 契约测试通过。

### R5-K2 数据角色与候选声明

- [x] 幂等创建规范 runtime/migration 数据库角色和可逆 owner/grant SQL；
- [x] 生成 API/Worker/Scheduler/Migration、双前端、Service/Ingress/NetworkPolicy；
- [x] Worker/API/Scheduler/Migration 凭据严格分离；
- [x] 候选清单使用不可变 digest，且不覆盖旧 v1 资源；
- [x] 将受治理 dataset allowlist 作为显式发布输入，禁止空值与 `*`。

### R5-K3 平行候选与预切换

- [x] Migration 在正式切换前只对恢复/候选路径演练；
- [x] API 与双前端候选平行部署，候选 Worker/Scheduler 保持零写者；
- [x] 严格 TLS 完成 Admin/Web 两套真实 Casdoor 登录；
- [x] 验证四角色数据库 principal、Provider/S3 最小权限和服务身份矩阵；
- [x] 真实 RAGFlow 检索、过渡消费者契约和数据对账通过；
- [x] Calico 包级 NetworkPolicy allow/deny 通过。

### R5-K4 切读、切写与旧写入封锁

- [x] 冻结摄取写入、排空旧队列并生成第二份备份；
- [x] 停止旧 API/Worker，迁移 owner/grants 并封锁旧角色；
- [x] 正式 Migration 升到 `0004`，启用统一 API/Worker/Scheduler；
- [x] 切换 Admin/Web `/api` 与 `/` Ingress；
- [x] 单写者、双端、异步摄取、检索、数据与 Provider 对账通过。

### R5-K5 回滚、前滚与观察

- [x] 原生恢复旧 API/Worker、角色授权与旧 Ingress；
- [x] 保留 additive `0004`，验证旧镜像兼容；
- [x] 再次前滚并重复浏览器、身份、数据、Provider 与单写者门禁；
- [x] 临时资源清理，旧 v1 声明与受保护数据保留。

### R5-K6 声明式部署收口

- [x] `app-platform/knowledge-app` 默认入口只重建统一正式态；
- [x] 旧 v1 生成器移至显式入口；RAGFlow 继续作为受保护 Provider 子系统；
- [x] clean-room render、共享静态门禁、server-side dry-run、两次 apply 与 diff/reconcile 通过；
- [x] reconcile 后重复 runtime/data/provider/single-writer 与严格 TLS 浏览器门禁；
- [x] GitHub/Gitee SHA 对齐后标记 Knowledge R5 DONE，才允许开始 Investment R5。

## 5. 退出门禁

只有以下全部闭合才能标记 DONE：

- 私有备份可恢复，迁移 roundtrip 和正式单 head 通过；
- 业务表计数、状态、约束、不变量和 Provider binding 前后完全一致；
- RAGFlow 实体与真实检索通过，未发生重复摄取；
- 同 Backend digest 的四角色使用正确命令和最小身份；
- Admin/Web 严格 TLS 真实身份与独立 client/cookie/session 通过；
- Info ingest、过渡 retrieval 与 Worker Provider 能力矩阵通过；
- 新旧写者不并存，旧角色 fail-closed；
- 原生回滚/前滚及再次对账通过；
- Git 声明可重建正式态、零漂移、双远端 SHA 一致。

任一失败均不得开始 Investment R5、不得晋级 `2.0.0`、不得删除 v1 或 RAGFlow 资产。
