# Architecture v2 R5 Info Backend 与数据库归并方案

状态：`R5 RUNTIME CUTOVER PASSED / DECLARATIVE CLOSEOUT IN PROGRESS`

日期：2026-08-09

适用分支：`architecture-v2`

上游基线：`architecture-v2-r3.2-20260808`、Info R4、R4.1、R4.2

本文件是 R5 第一个串行对象 Info 的权威施工方案。Knowledge 和 Investment 在 Info 完成源码、
数据库、KIND 切换、回滚、`app-platform/info-app` 声明式部署收口和证据门禁前不得进入 R5。

## 1. 结论

Info 采用以下不可变决策：

1. `info_admin` 继续作为规范物理数据库，不为名称美观搬库或改名；逻辑所有者是统一
   `info-backend`，名称中的 `admin` 仅是历史遗留；
2. `info_web` 经 2026-08-09 再次实测仍为零表、零 Alembic head，不存在业务数据迁移；
3. 现有 Info Alembic 链 `20260706_0001 -> 20260707_0002 -> 20260712_0003 ->
   20260714_0004` 是唯一合法主线；旧 Web migration root 不得拼入；
4. 在 `20260714_0004` 后新增实例 migration，创建模板通用的 `outbox_message` 和
   `inbox_message`；现有 `delivery_outbox_message` 是 Info->Knowledge 交付日志，语义不同，
   必须保留，禁止相互改名、合表或伪造回填；
5. API、Worker、Scheduler、Migration 使用同一 `info-backend` 镜像，以不同命令和独立
   Kubernetes ServiceAccount 运行；前三者共用一个应用数据库角色，Migration 独占 DDL 角色；
6. Admin/Web 两个 Next.js 前端继续是两个独立安全表面，但都通过同一个 `info-backend`；
7. R5 只做可回滚切换，不删除旧 Backend Deployment、数据库、角色、Secret、PVC 或受保护镜像；
   删除属于 R7 观察窗后的退役动作。

## 2. 2026-08-09 事实基线

### 2.1 规范库 `info_admin`

| 项目 | 实测值 |
| --- | --- |
| PostgreSQL | 17.6 |
| 数据库 owner | `info_admin_user_migration` |
| Alembic head | `20260714_0004` |
| 表 owner | 11 张表均为 `info_admin_user_migration` |
| 约束 | PK 11、FK 14、Unique 5、未验证约束 0 |
| 业务不变量异常 | 0 |
| `delivery_outbox_message` | 16 行，全部 `completed` |
| 模板通用 outbox/inbox | 均不存在 |

精确行数：

| 表 | 行数 |
| --- | ---: |
| `auth_user` | 1 |
| `crawl_job` | 25 |
| `delivery_outbox_message` | 16 |
| `distribution_record` | 22 |
| `extracted_content` | 30 |
| `info_collector` | 1 |
| `info_document` | 8 |
| `info_document_version` | 16 |
| `info_source` | 7 |
| `raw_artifact` | 56 |

### 2.2 旧 Web 库 `info_web`

- owner：`postgres`；
- Alembic head：无；
- public 表：0；
- 约束：0；
- 当前角色 `info_web_user` 仍可连接并创建 schema 对象，这是 R5 切换时必须封锁的旧写入口。

### 2.3 R5 切换前的 v1 运行拓扑基线

R5 切换前，`app-platform-dev` 运行六个旧 Deployment：

- `info-admin-backend`、`celeryworker-info-admin-backend`；
- `info-web-backend`、`nodebullworker-info-web-backend`；
- `info-admin-frontend`、`info-web-frontend`。

另有已暂停的 `info-delivery-outbox-scanner` CronJob。旧 Admin/Web Backend 当时分别引用
`info-admin-backend-postgresql-conn` 和 `info-web-backend-postgresql-conn`；这证明切换前仍是双
Backend、双数据库接线，不能把 R4 隔离门禁误当成生产 namespace 已迁移。

### 2.4 备份与恢复门禁

- 私有 custom-format 备份：71,412 bytes；
- SHA-256：`ce553f688de4310d266d040538b9ab3bbaa8a21793945e96cef1edfe0e5c411e`；
- 存储：`$HOME/.local/state/sunmoonai/architecture-v2/r5-info/`，权限 0700/0600；
- 备份包含业务数据，不进入 Git、镜像、ConfigMap、Secret 或日志；
- 已恢复到隔离数据库 `info_r5_restore_baseline_20260809`；
- 恢复后的 head、表计数、owner、约束和业务不变量与源库一致；
- 演练结束后隔离数据库已删除，存在性复核为 `false`。

证据见 `evidence/R5-info-baseline/`。

## 3. 目标数据与身份模型

### 3.1 数据库角色

R5 创建并使用：

| 角色 | 用途 | 权限 |
| --- | --- | --- |
| `info_backend_user` | API/Worker/Scheduler 数据访问 | CONNECT、schema USAGE、表 DML、sequence 使用；无 DDL、无角色/数据库创建 |
| `info_backend_user_migration` | 唯一 Migration Job | `info_admin`/public schema 与表 owner、DDL/default privileges；不供 API 使用 |

历史 `info_admin_user`、`info_admin_user_migration`、`info_web_user` 及其 Secret 在 R7 前保留。
切写后撤销旧运行角色连接/写权限；回滚脚本必须先恢复授权，再恢复旧 Deployment。

数据库角色与工作负载身份不是同一概念。Kubernetes 运行身份分别为：

- `info-backend-api`；
- `info-backend-worker`；
- `info-backend-scheduler`；
- `info-backend-migration`。

四者使用同一镜像但具有不同命令、Secret、NetworkPolicy、扩缩容和故障语义。只有 Worker 获得
Info->Knowledge 的调用身份；API 和 Scheduler 不得继承该凭据。

### 3.2 单一迁移链

新增 migration 必须满足：

```text
20260714_0004
  -> 20260809_0005_outbox_primitives
```

`0005` 只创建 `outbox_message`、`inbox_message`、唯一/检查约束和 claim 索引，不改写现有业务
行。迁移后：

- 原 10 张业务表和 1 张 Alembic 表保持行数；
- 两张新表初始均为 0；
- `delivery_outbox_message` 16 条完成记录原样保留；
- 所有既有业务不变量仍为 0；
- 模型 metadata 与数据库结构一致。

### 3.3 双前端与统一 Backend

Admin/Web 前端分别使用独立 Casdoor application、redirect、cookie、session namespace、scope 和
CSRF/Origin 策略。浏览器同源 `/api` 由 Traefik 的高优先级路由直达统一 Backend；`/` 进入各自
Next.js 前端。两个 Next.js 在 SSR session introspection 时使用同一个 server-only
`BACKEND_INTERNAL_URL=info-r5-backend:8000`。前端不连接 PostgreSQL、不保存 Provider access token，
也不成为领域授权点。

## 4. 串行施工步骤

### R5-I0 基线冻结

- [x] 盘点 v1 Deployment/Service/Ingress/CronJob/PVC/Secret 键名；
- [x] 精确盘点 `info_admin` 与 `info_web`；
- [x] 校验业务不变量；
- [x] 生成私有备份并记录摘要；
- [x] 隔离恢复、对账并清理恢复库。

### R5-I1 源码与迁移链

- [x] 新增 `20260809_0005_outbox_primitives`；
- [x] 增加 migration 单 head、metadata/schema 一致性测试；
- [x] 在恢复副本上验证 `0004 -> 0005 -> 0004 -> 0005`；
- [x] 证明 downgrade 演练只删除两张空通用表，不触碰业务数据；
- [x] 增加新旧 Web/Admin 契约兼容和双前端配对测试。

迁移 roundtrip 使用不可变镜像
`info-backend@sha256:ee962dff40dd0ebee6969f084dceac10a9283814df7af45d1da6e114047bea0d`，
业务计数、约束和不变量在三次状态转换后均一致。正式库回滚保留 additive `0005`：旧 v1 镜像
并不知道该 revision，回滚时必须跳过旧 Migration gate，只恢复已验证与 additive schema 兼容的旧运行
工作负载；不得让旧镜像尝试解释或 downgrade `0005`。

Admin/Web 两个 Next.js 源码分别通过 typecheck、lint、i18n、单元/组件测试和生产构建；统一
FastAPI 同时保留 `/api/auth/admin`、`/api/admin`、`/api/auth/web`、`/api/web/v1` 契约，双端
仍只使用同源 `/api` 和 server-only `BACKEND_INTERNAL_URL`。证据见
`evidence/R5-info-baseline/source-pair-gates.json`。

### R5-I2 数据角色与部署资产

- [x] 幂等创建两个规范数据库角色和 default privileges；
- [x] 以显式 SQL 迁移 owner/grants，生成可逆授权脚本；
- [x] 生成 `info-backend` API/Worker/Scheduler/Migration 四角色候选资源；
- [x] Worker 独占下游服务身份；Migration 独占 DDL Secret；
- [x] HPA/PDB/NetworkPolicy/探针和资源按角色设置；
- [x] 以不可变 digest 构建并验证同一 Backend 镜像。

角色准备态已经证明：`info_backend_user` 能以真实凭据连接并访问 11 张既有表但不能 DDL，
`info_backend_user_migration` 能 DDL 但不是 superuser/createdb/createrole/replication；两个新 Secret
均标记为 `prepared-not-active`。既有 11 张表 owner、旧角色授权和线上 Deployment 均未改变。
证据见 `evidence/R5-info-baseline/database-roles-prepared.json`。

候选资源由规范 `k8s-scaffold-v2` 派生，再叠加最小 Info R5 overlay；资源名固定为
`info-r5-*`，业务身份仍为 `APP_SLUG=info`。静态门禁证明其不会覆盖六个 v1 Deployment，四个
Backend 角色使用同一不可变 digest，API/Worker/Scheduler 只读取 runtime DB Secret，Migration
只读取 DDL Secret，且只有 Worker 可见 Info→Knowledge 身份与对应 egress。候选部署脚本默认
只输出计划，`apply` 前还会复核全部外部 Secret 键和 v1 Deployment 仍存在。

I3 候选态的 Worker/Scheduler 副本固定为 0，Worker HPA 不创建，队列固定为
`info.r5.candidate`；因此平行部署只能验证 API、双前端、Migration 和声明式身份拓扑，不会形成
第二组异步写者。Worker/Scheduler 的真实 principal 由受控一次性探针验证，只有进入 I4、冻结
旧写入并再次对账后，才允许切换到正式队列并启用副本。

### R5-I3 平行部署与预切换

- [x] 在 `app-platform-dev` 平行部署新 Backend 四角色，不接正式前端流量；
- [x] Migration Job 以规范 migration role 升到唯一 head；
- [x] 新 Admin/Web 前端以候选 Service/路由部署；
- [x] 严格 TLS 完成两套真实 Casdoor 登录和各自 Backend 配对；
- [x] 验证 API/Worker/Scheduler/Migration 数据库 principal 与 Worker 独占服务身份；
- [x] 对账 head、行数、约束、状态分布、业务不变量和关键读取结果；
- [x] 在支持 NetworkPolicy 的 CNI 上实测 API/Scheduler 到 Knowledge 的 egress 拒绝。

候选 API、Admin、Web 分别以 2 副本就绪；Worker/Scheduler 保持 0 副本，旧六个 v1
Deployment 的副本和镜像均未变化。四角色一次性只读探针证明 API/Worker/Scheduler 使用
`info_backend_user`，Migration 使用 `info_backend_user_migration`。Worker 以真实 client credentials
到达 Knowledge 请求校验（422），负向令牌矩阵全部按预期拒绝。严格 TLS 双表面真实登录、注销、
会话撤销及 client/cookie 隔离全部通过。

当前 KIND 使用 `kindnet`，该 CNI 不执行 Kubernetes NetworkPolicy。因此策略结构已通过静态门禁，
但 API/Scheduler egress 拒绝不得在该环境伪报为运行态通过；此项是支持 NetworkPolicy 的
预生产/生产集群硬门禁。一次性 Calico v3.28.2 KIND 已对同一候选策略执行包级矩阵：Worker 到
Knowledge 允许，API/Scheduler 到 Knowledge 拒绝，内部/前端到 Backend 允许，无标签调用者到
Backend 拒绝；验证后隔离集群自动删除。长期 KIND 的运行态快照仍诚实保留
`production_network_policy_gate_satisfied=false`，Calico 证据单独闭合生产策略门禁。完整证据见
`candidate-runtime-gate.json`、`candidate-browser-gate.json` 和
`service-token-negative-matrix.json`、`network-policy-calico-gate.json`。

### R5-I4 切读、切写与旧写入封锁

已验证切换顺序固定为：

1. 冻结新业务写入并等待旧 outbox/queue 可接受地排空；
2. 再次生成备份和摘要；
3. 将旧 Admin API/Worker、旧 Web Backend/Node Worker 缩容为 0；
4. 转移 `info_admin` owner/grants，封锁旧 Admin 角色，并撤销空 `info_web` 的旧角色和
   `PUBLIC CONNECT`；
5. 应用正式配置，启用统一 API/Worker/Scheduler；
6. 将 Admin/Web 正式 Ingress 切成 `/api -> info-r5-backend`、`/ -> 对应 Next.js` 双路由；
7. 将旧双前端缩容为 0；
8. 验证旧写请求 fail-closed、单写者、双端、异步交付和数据对账。

- [x] 正式切换前旧 outbox 已排空，生成第二份私有备份；
- [x] 统一 API/Worker/Scheduler 启用，旧六个工作负载均缩容为 0；
- [x] `info_admin` 旧角色 NOLOGIN/无连接，owner 全量转给规范 migration role；
- [x] 空 `info_web` 保持零表，旧角色 NOLOGIN/无连接/无 schema create；
- [x] 正式双 Ingress 使用高优先级 `/api` 和低优先级 `/`，Admin/Web 严格 TLS 真登录通过；
- [x] 单写者、principal、服务身份、数据计数、约束和业务不变量门禁通过。

禁止通过同时运行新旧写者来换取“无停机”表象。Info 当前数据量极小，应优先选择短写冻结、
单写者、可证明回滚，而不是引入双写或 CDC。

### R5-I5 回滚、前滚与观察

回滚顺序固定为：

1. 冻结新写入并停止新 Worker/Scheduler/API；
2. 恢复旧数据库角色授权；
3. 旧 Admin Backend/Worker 与旧 Web Backend/Node Worker 按锁定副本恢复；
4. Ingress 切回旧双前端；
5. 运行旧路径读写与数据对账；
6. 保留 additive `0005`，不在正式库执行破坏性 downgrade；
7. 再按锁定清单前滚并重复全部门禁。

- [x] 原生回滚恢复旧六组件、四条旧 Ingress 和旧 `info_admin` 角色/owner；
- [x] 回滚态旧 Admin API 返回预期 401，旧 runtime principal 完成零行 UPDATE 并回滚；
- [x] `info_web` 权限完成独立 rollback -> forward 往返，前后均保持零表；
- [x] 再次前滚后严格 TLS 双端真实 Casdoor 门禁重复通过；
- [x] 再次前滚后单写者、角色封锁、数据对账和服务身份门禁重复通过；
- [x] 候选域名 Ingress 和一次性探针已清理，v1 资产全部保留；
- [x] 最终 Pod 均 0 重启，API/Worker/Scheduler 启动及连接日志正常；
- [x] 长期 KIND 无 metrics-server，HPA `ScalingActive=false` 作为环境限制记录，不伪报指标门禁通过。

R5 完成后仍保留旧数据库、角色、Secret、PVC、Deployment 声明和镜像。R7 观察窗结束前不得删除。

最终私有备份位于 `$HOME/.local/state/sunmoonai/architecture-v2/r5-info/`，capture 为
`r5-info-final-20260809T0704Z`，SHA-256 为
`50b897c7b009d58431b019acc75489c8a471bb3e2e4bdbe0d6b3d446abd0ad93`。备份包含业务数据，
不得提交。正式验收证据见 `formal-browser-gate.json`、`formal-runtime-gate.json` 和
`rollback-forward-gate.json`。

### R5-I6 声明式部署收口

- [x] 将 `app-platform/info-app` 的默认部署入口切换为已验收的统一 Backend 正式态；
- [x] 正式清单声明 API=2、Worker=1、Scheduler=1、Admin=2、Web=2 及不可变镜像 digest；
- [x] 正式清单声明双前端 `/api` 与 `/` 优先级路由、正式配置、角色隔离和 NetworkPolicy；
- [x] 将旧六组件部署生成器移出默认扫描面，保留于显式 `legacy-v1` 回滚边界；
- [x] 提供 render、静态验证、server-side dry-run、apply、status 和 drift reconciliation；
- [ ] 从干净生成目录重建正式态并重复浏览器、运行、数据和单写者门禁；
- [ ] 提交并双远端对齐后，才允许将 Info R5 标记 DONE、开始 Knowledge R5。

该步骤是 Info 暂时重新打开 R5 的原因。私有候选 bundle 和已经成功的集群切换不能替代 Git 中
的声明式部署真相。

2026-08-09 声明式收口已完成以下子门禁：空目录重复生成与 Git bundle 逐字一致、跨实例通用
静态门禁通过、Kubernetes server-side dry-run 通过、默认入口正式 reconcile 通过、Migration Job
成功后清理、旧六组件保持 0 副本、`kubectl diff` 零漂移。深层 runtime/data/single-writer 与
严格 TLS 浏览器门禁须在本次 reconcile 后再重复一次，之后才能勾选最后两项。

通用门禁为 `app-platform/scripts/verify-architecture-v2-instance.py`。Knowledge 与 Investment
必须提交同一 schema 的 formal `release.json` 并通过该脚本，禁止另写弱化版实例检查器。

## 5. 退出门禁

只有以下全部通过，Info R5 才可标记 DONE：

- 源码 clean、单 Alembic head、模型/迁移一致；
- 私有备份可恢复，摘要可复核；
- migration roundtrip 与业务数据对账通过；
- API/Worker/Scheduler/Migration 同 digest、不同身份/命令；
- Admin/Web 严格 TLS 真实登录、会话隔离、CSRF/Origin、scope/ownership 通过；
- Worker 下游身份 allow，API/Scheduler/无标签调用者 deny；
- 新旧写者不会并存，旧写入口 fail-closed；
- 统一 Backend 的 Admin/Web 契约与异步交付通过；
- 原生回滚和再次前滚均通过，前后数据不变量一致；
- 临时 namespace、恢复数据库、临时凭据和测试任务已清理；
- `app-platform/info-app` 默认部署可从 Git 重建当前正式态，且旧 v1 不在默认扫描面；
- GitHub/Gitee、源码 commit、镜像 digest 和证据闭合。

任何一项失败均不得开始 Knowledge R5，不得晋级 `2.0.0`，不得删除 v1 资产。

## 6. 明确禁止

- 禁止把 `info_web` 的空库迁移脚本拼进 Alembic；
- 禁止把 `delivery_outbox_message` 重命名成通用 `outbox_message`；
- 禁止在正式库试验 downgrade；
- 禁止让 API 使用 migration role；
- 禁止把 Worker 服务身份注入 API/Scheduler；
- 禁止把两个前端身份表面合并；
- 禁止只看 Pod Ready 就宣布数据迁移完成；
- 禁止在 R5 删除旧数据库、Secret、PVC、仓库历史或受保护镜像。
