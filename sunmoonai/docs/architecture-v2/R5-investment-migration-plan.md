# Architecture v2 R5 Investment 归并与 Research 回滚基线迁移方案

状态：`R5-V0..V6 DONE`

日期：2026-08-11

适用分支：`architecture-v2`

上游基线：`architecture-v2-r3.2-20260808`、Investment R4、R4.1、R4.2、Info R5 DONE、Knowledge R5 DONE

本文件是 R5 第三个、也是最后一个串行对象 Investment 的权威施工方案。跨 App 真实竖线 R6
只能在本文件 V0～V6 全部完成后开始。

## 1. 冻结结论

1. 旧 Research 产品已由 Investment 取代；`research_admin` 及旧 `research-*` 工作负载只作为
   可验证的回滚基线，不再是 Architecture v2 的规范命名；
2. 新规范物理数据库固定为 `investment_admin`。禁止把 `research_admin` 原地改名，也禁止让新
   Investment 继续长期连接旧库名；
3. 初次候选由 `research_admin` 的私有、可校验备份恢复到 `investment_admin`；正式切换前冻结旧
   写者、重新备份并重建目标库，以获得最后一致快照；源库始终保留，回滚不依赖反向同步；
4. 空的 `research_web`、`investment_web` 不承载业务数据，不拼接迁移链、不激活为第二数据库；
5. 唯一 Alembic 链固定为 `20260708_0001 -> 20260712_0002 ->
   20260729_0003_agent_pilot -> 20260809_0004_outbox_primitives`；
6. API、Worker、Scheduler、Migration 使用同一 `investment-backend` 镜像和不同命令、身份、
   Secret、NetworkPolicy、资源及伸缩策略；候选 Worker/Scheduler 固定为 0，正式切换后才启用；
7. Admin/Web 两个 Next.js 前端保持独立浏览器身份和安全表面，共用统一 Backend 与
   `investment_admin`；
8. Knowledge 检索服务身份正式改为 `sunmoonai-investment-knowledge-retrieve`。旧
   `sunmoonai-research-knowledge-retrieve` 只为旧 Research 回滚保留，不能进入 Investment 正式
   工作负载；
9. R5 只做可回滚切换：不删除 `research_admin`、旧 Research 声明、Secret、PVC、镜像或旧
   Casdoor 身份；观察窗后的退役属于 R7；
10. 领域层中表示“研究过程/研究报告”的 research 词汇可以保留；基础设施、产品、仓库、数据库、
    服务身份和部署资源必须使用 Investment 命名。

## 2. 2026-08-11 事实基线

### 2.1 旧规范数据源 `research_admin`

| 项目 | 实测值 |
| --- | --- |
| 数据库 owner | `research_admin_user_migration` |
| Alembic head | `20260712_0002` |
| public 业务表 | 11 张（不含 Alembic） |
| 约束 | 17，未验证约束 0 |
| `agent_runs` | 28 |
| `agent_sessions` | 29 |
| `session_events` | 278 |
| `tool_side_effects` | 21 |
| `checkpoints` | 160 |
| `checkpoint_blobs` | 40 |
| `checkpoint_writes` | 363 |
| `checkpoint_migrations` | 10 |
| `auth_user` | 2 |

`research_web`、`investment_admin`、`investment_web` 当前均为空库；只有 `research_admin` 含业务
数据。正式施工必须重新审计并以证据文件中的机器可读结果为准，本文数字不是替代门禁的缓存。

### 2.2 旧运行拓扑

`app-platform-dev` 仍运行六个 Research v1 Deployment：Admin Backend、Celery Worker、Admin
Frontend、Web Backend、NodeBull Worker、Web Frontend。它们在 V4 切换前保持原样；候选资源使用
`investment-r5-*` 名称，不得覆盖或读取正式队列。

### 2.3 锁定源与镜像

- Investment Backend 源码：`4204355f8c960db85730c212864d716f9754fcfa`；
- Admin 源码：`4a7053b138148fb9ce5c4295c39472e6183fdc8d`；
- Web 源码：`e463809eb4fb0cbeeb0a87ab4bb23919c64c4395`；
- Backend 候选镜像：`investment-backend@sha256:edc52084c243703a68ab9b422d8ad0e1d2ff8519e6a25190b8b52fe8c1e1ed10`；
- Admin 候选镜像：`investment-admin-frontend@sha256:15d8253d2125045f38ea8bd159df77642250214b3bd72e8733cedbd50464f41d`；
- Web 候选镜像：`investment-web-frontend@sha256:d3ac86bdea887ed3be4ab2b61a8928bdf23086e20137c02e0ec2ca520ae51a0a`。

## 3. 数据、身份与单写者模型

### 3.1 数据库角色

| 角色 | 用途 | 边界 |
| --- | --- | --- |
| `investment_backend_user` | API/Worker/Scheduler DML | 无 DDL、无 createdb/createrole/superuser |
| `investment_backend_user_migration` | Migration 与 owner | 唯一 DDL 身份，不供运行角色使用 |

旧 `research_admin_user` 与 `research_admin_user_migration` 在回滚观察窗内保留。正式态中旧角色仅
作用于旧源库，必须 NOLOGIN；新角色只连接 `investment_admin`。两个数据库不得同时存在可写
业务工作负载。

### 3.2 Knowledge 服务身份

- Investment Worker 独占 `investment-knowledge-retrieval-client`；
- Knowledge API 接受 `knowledge-investment-retrieval-service-binding`；
- application/audience：`sunmoonai-investment-knowledge-retrieve`；
- scope：`knowledge:retrieve`；
- API、Scheduler、Migration 和两个前端不得继承该 client secret；
- 旧 Research identity 只挂在旧 Research 回滚工作负载和 Knowledge 过渡兼容入口。

### 3.3 写入切换

正式切换顺序不可更改：冻结入口 -> 排空旧队列 -> 备份 `research_admin` -> 停止旧六组件 ->
重建 `investment_admin` -> 迁移到 `0004` -> 转移新 owner/grants -> 启用新 API/Worker/Scheduler ->
切双前端正式路由 -> 数据、浏览器、服务身份、异步和单写者验收。

## 4. 串行施工步骤

### R5-V0 基线冻结

- [x] 盘点旧 Research 工作负载、Service、Ingress、Secret、PVC 和 Casdoor 身份；
- [x] 审计四个相关数据库及 `research_admin` 数据、owner、约束和不变量；
- [x] 生成私有 custom-format 备份、摘要和权限证明；
- [x] 恢复到隔离库并逐表、逐 head、逐约束对账后清理；
- [x] 冻结旧 Research 拓扑哈希和现有 Knowledge 检索基线。

### R5-V1 源码、迁移链与配对

- [x] Backend Ruff、Pyright、全测试、单 head、metadata/schema 与生产镜像通过；
- [x] 在恢复副本完成 `0002 -> 0004 -> 0002 -> 0004` roundtrip；
- [x] Admin/Backend 与 Web/Backend typecheck、lint、测试、构建和契约配对通过；
- [x] Investment 产品/基础设施命名门禁通过，合法领域 research 词汇不被误删；
- [x] Knowledge retrieval adapter 与服务身份契约通过。

### R5-V2 数据角色、目标库与候选声明

- [x] 幂等创建 `investment_admin`、runtime/migration role 和分离 Secret；
- [x] 从已验证备份恢复候选数据并迁移到唯一 head；
- [x] 生成 API/Worker/Scheduler/Migration、双前端、Service/Ingress/NetworkPolicy；
- [x] 候选 API=2、Admin=2、Web=2，Worker=0、Scheduler=0；
- [x] 候选使用不可变 digest，且不覆盖旧 Research 资源；
- [x] 创建显式 Investment→Knowledge 身份，不把旧 Research 凭据挂入新 Pod。

### R5-V3 平行候选与预切换

- [x] 严格 TLS 完成 Admin/Web 两套真实 Casdoor 登录、注销和会话隔离；
- [x] 四角色数据库 principal、最小 Secret 和无额外写者通过；
- [x] 真实 Knowledge 检索与正负服务令牌矩阵通过；
- [x] 数据计数、约束、状态、不变量及 agent checkpoint 读取一致；
- [x] Calico 包级 NetworkPolicy allow/deny 通过；
- [x] 旧 Research 拓扑哈希不变。

### R5-V4 切读、切写与旧写入封锁

- [x] 冻结旧写入、排空队列并生成最终私有备份；
- [x] 停止旧六组件，重新从最终备份构建 `investment_admin`；
- [x] Migration 升至 `0004`，启用正式 API=2、Worker=1、Scheduler=1；
- [x] 正式 Admin/Web `/api` 与 `/` 路由切到 Investment；
- [x] 旧 Research role NOLOGIN、工作负载为 0；
- [x] 严格 TLS、服务身份、异步任务、数据与单写者门禁通过。

### R5-V5 回滚、前滚与观察

- [x] 停止新写者并恢复旧 Research 六组件、路由和数据库角色；
- [x] 验证旧路径、旧数据和旧服务身份仍可工作；
- [x] 再次前滚并重复全部正式门禁；
- [x] 临时候选、探针和候选 Casdoor 资产清理；
- [x] 源库、旧声明、Secret、PVC 与受保护镜像保持可回滚。

### R5-V6 声明式部署收口

- [x] `app-platform/investment-app` 默认入口只重建统一正式态；
- [x] 旧 Research 生成器/声明只能由显式 legacy 入口访问，默认禁止；
- [x] clean-room render、静态门禁、server-side dry-run、两次 apply 与零漂移通过；
- [x] reconcile 后重复 runtime/data/retrieval/single-writer/browser 门禁；
- [x] GitHub/Gitee SHA 对齐后标记 Investment R5 DONE，才允许开始 R6。

## 5. 退出门禁

只有 V0～V6 全部闭合才能标记 DONE：备份可恢复；迁移 roundtrip；目标库唯一 head；业务数据、
checkpoint、约束和不变量一致；双前端真实身份通过；Investment→Knowledge 显式身份和真实检索
通过；新旧写者不并存；原生回滚/前滚通过；声明式重建零漂移；双远端 SHA 一致。

任一失败均不得开始 R6、不得标记 `2.0.0`、不得删除 Research 回滚资产。
