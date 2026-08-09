# App Platform Architecture v2 重构执行基线

状态：`ACTIVE / R0-R4 COMPLETE / R4.2 RUNTIME CLEANUP IN PROGRESS`

日期：2026-08-01

最近重新冻结：2026-08-08

工作分支：`architecture-v2`

重构前标签：`pre-architecture-v2-20260801`

旧架构发布：`1.0.0`

目标正式发布：`2.0.0`

## 1. 文档权威与目的

本文是 Architecture v2 重构期间的唯一施工控制文档。它负责冻结架构决策、任务顺序、
进入/退出门禁、证据、回滚点和当前状态。

现有 v5 长期规划、实施计划、Task 和 Handoff 在本次重构期间冻结为历史基线，不再继续
扩写。Architecture v2 完整验收后，才根据已经实现的真实架构编写新的长期规划、实施计划、
Task 和 Handoff；在此之前不得用未来文档宣称尚未完成的能力。

## 2. 已冻结的全局决策

### 2.1 保留三个领域 App

Info、Knowledge、Investment 保持三个独立有界上下文，不合并成一个业务 App：

- Info 拥有来源、文档版本、Artifact、分发与可靠投递；
- Knowledge 拥有摄取、索引、RAGFlow 绑定与检索；
- Investment 拥有投资研究、Agent Runtime、研究会话、证据组装与长期记忆；
- 三者继续使用显式 Artifact、Ingestion、Retrieval、Identity 与 Outbox 契约协作；
- 不共享数据库，不跨 App 直接读表。

除非出现新的领域事实，本决策不再因实现便利而反复调整。

### 2.2 每个 App 只有一个规范 Backend

每个 App 的 Admin Backend 与 Web Backend 合并为一个 FastAPI Backend 代码库和一个数据
所有者：

```text
Info       -> info-backend       -> info database
Knowledge  -> knowledge-backend  -> knowledge database
Investment -> investment-backend -> investment database
```

Admin 与 Web 两个 Next.js 前端继续独立部署，但调用同一个领域 Backend。数据库属于 Backend，
不属于任何前端。

### 2.3 一个 Backend 不等于一个进程或一个 Pod

同一代码库和同一候选镜像可以按不同命令运行多个角色：

- API：短请求、认证、命令受理、查询和 SSE；
- Worker：异步任务和可靠投递；
- Agent Worker：仅 Investment 的长时 LangGraph 执行；
- Scheduler/Scanner：定时扫描和补偿；
- Migration Job：Alembic 迁移；
- CLI/Reconciler：运维修复和对账。

这些是运行角色，不是独立 Backend、独立领域或独立数据所有者。

### 2.4 分层和接口边界

Backend 采用以下目标分层：

```text
backend/
├── domain/
├── application/
│   ├── commands/
│   ├── queries/
│   ├── services/
│   ├── ports/
│   ├── policies/
│   └── dto/
├── interfaces/
│   ├── http/
│   │   ├── admin/
│   │   ├── web/
│   │   ├── internal/
│   │   ├── auth/
│   │   └── middleware/
│   ├── tasks/
│   └── cli/
├── infrastructure/
│   ├── persistence/
│   ├── messaging/
│   ├── security/
│   ├── external/
│   ├── storage/
│   └── observability/
└── bootstrap/
    ├── api.py
    ├── worker.py
    ├── scheduler.py
    └── migration.py
```

强制规则：

- Admin/Web/Internal 只在接口层分面，不机械复制 application 用例；
- 同一用例默认被不同入口复用，只有业务语义不同才拆为不同用例；
- Internal API 按提供方能力命名，不按调用方 App 命名；
- 调用方差异由服务身份、scope、授权矩阵和 consumer contract test 表达；
- 不新增顶层 `platform/` 杂物目录；跨切面能力放入其所属 application、interfaces 或
  infrastructure 层；
- 可选 `shared/` 只容纳极小的稳定值对象、ID、时钟和无领域含义类型。

### 2.5 Worker 与容量策略

第一阶段每个 App 只建立一个通用 Worker Deployment；不因任务名称预先拆出大量队列。
只有出现下列可量化触发条件时才拆 Worker/Queue：

- 资源类型显著不同（浏览器、CPU、GPU、沙箱）；
- 任务时长或重试语义显著不同；
- 故障需要隔离；
- 独立扩缩容有持续指标支持；
- 权限或网络边界要求独立工作负载身份。

Investment Agent Worker 因长时执行、取消、checkpoint 和沙箱边界可从 API Worker 独立；是否
进一步拆分仍必须由门禁证据决定。

### 2.6 模板优先和立即同步

任何共同底座能力必须先在 tpl-app 完成并通过配对门禁，然后立即同步到 Info、Knowledge、
Investment。三个实例完成共同底座同步前，禁止继续在旧实例底座上扩展业务功能。

“同步模板”表示继承全部规范共同能力，不只是安全中间件；实例只允许以显式扩展点增加领域
代码，不得复制后形成不可解释漂移。

## 3. 目标仓库拓扑

### 3.1 模板

目标默认模板只有三个规范组件：

```text
tpl-app/
├── tpl-backend
├── tpl-admin-frontend
└── tpl-web-frontend
```

迁移策略：

- `tpl-admin-backend` 作为领域/管理能力较完整的历史主线，重命名为 `tpl-backend`；
- 将 `tpl-web-backend` 中仍有价值的 Web/BFF/interaction 能力按目标分层移入 `tpl-backend`；
- `tpl-web-backend` 在配对、数据和回滚门禁完成前保留，之后归档；
- `tpl-admin-frontend` 与 `tpl-web-frontend` 均为 Next.js，但保留不同产品表面和组件能力；
- `tpl-admin-frontend-react`、`tpl-admin-frontend-vue`、`tpl-web-backend-nest` 作为参考实现，
  不进入默认实例化链。

任何远端仓库重命名都必须先验证 Gitee redirect、父仓 `.gitmodules`、本地 submodule URL、
CI、镜像仓名和 K8s 生成器；禁止只改本地目录名。

### 3.2 实例 App

每个实例最终保留：

```text
<app>-app/
├── <app>-backend
├── <app>-admin-frontend
└── <app>-web-frontend
```

以现有 `<app>-admin-backend` 为领域代码历史主线并重命名为 `<app>-backend`；现有
`<app>-web-backend` 的 BFF/interaction/auth 能力经审计后迁入，旧仓在回滚窗内保留并最终
归档。不得用空模板覆盖实例领域代码。

## 4. API、身份与数据所有权

### 4.1 HTTP 分面

默认路由约定：

```text
/api/admin/v1/...      浏览器管理面
/api/web/v1/...        用户产品面
/api/internal/v1/...   服务到服务能力
/api/auth/...          浏览器登录、回调、会话
/health/live
/health/ready
```

Internal 示例应是 `/api/internal/v1/ingestions`、`/retrievals`、`/citations`，而不是
`/internal/info-app/...` 这类调用方耦合路径。

### 4.2 身份

- 浏览器继续使用 Casdoor OIDC Authorization Code + PKCE；
- Next.js 可承担同源 BFF/session 边界，但不得成为业务数据所有者；
- Backend 是最终授权点，必须验证主体、scope、资源所有权和 CSRF/Origin；
- 服务调用使用独立 workload identity/client credential；
- 浏览器 token、服务 token 和数据库凭据不得相互复用。

### 4.3 数据库归并

每个 App 最终只有一个 PostgreSQL 逻辑数据库和一条 Alembic migration head。数据库归并
必须先完成表/约束/索引/数据量/凭据/备份清单，之后按扩展迁移执行：

1. 建立新表或兼容列；
2. 回填并对账；
3. 切换读路径；
4. 切换写路径并停止旧写入；
5. 完成观察窗；
6. 最后删除旧表、旧角色和旧 Secret。

禁止直接把两个 migration 目录拼接、禁止双写无 outbox/幂等、禁止在回滚窗结束前删除旧库。

## 5. Git、版本、镜像与 Harbor 治理

### 5.1 Git 基线

- 旧 `codex-1` 已归并至 master；
- `pre-architecture-v2-20260801` 是重构前不可变源码标签；
- 所有施工只进入 `architecture-v2`；
- master 在重构验收前保持可恢复基线；
- 源码锁见 `architecture-v2/pre-refactor-source-lock.json`。

### 5.2 镜像版本

- `1.0.0`：旧架构发布基线，不覆盖；
- `arch-v2-<stage>-<git-sha>`：重构候选，不可变；
- `2.0.0`：Architecture v2 全部门禁通过后，对已验收的相同 digest 做标签晋级；
- 禁止为正式标签重新构建；
- K8s 验收与正式部署优先按 digest 固定。

### 5.3 Harbor 保护集

镜像保护集见 `architecture-v2/pre-refactor-image-lock.json`，包括：

- 19 个旧架构正式发布 digest；
- KIND 当前实际使用的额外回滚 digest；
- P0-008C 三个证据候选；
- 未进入本次清理范围的 Investment、Tools、RAGFlow、数据平台与 `k8s-images`。

现有 `prune_v1_harbor.py` 在未读取本锁文件前不得使用 `--execute`，因为其旧规则会把三项
P0-008C 证据候选误判为删除对象。

删除顺序必须是：重新采集工作负载引用 -> 计算 release/live/evidence/rollback 闭包 -> dry-run
人工审计 -> 删除 artifact -> Harbor GC -> 配额与 registry 空间复核。禁止执行无保护集的
`docker system prune -a` 或 Harbor 全项目清理。

## 6. 实施阶段与强制门禁

### R0 旧架构封板

| ID | 任务 | 状态 | 退出条件 |
| --- | --- | --- | --- |
| R0-001 | 审计 master/codex-1 分叉 | DONE | 所有差异分类 |
| R0-002 | 子仓 codex-1 归并 master | DONE | master tree 等于权威 codex tree |
| R0-003 | 父仓与 k8s 归并 | DONE | 子模块指向已归并 master |
| R0-004 | 建立源码基线标签 | DONE | 远端标签可解析至 master |
| R0-005 | 删除 codex-1 | DONE | 本地/远端均不存在且提交仍可达 |
| R0-006 | 建立 architecture-v2 | DONE | 21 个施工仓跟踪远端分支 |
| R0-007 | 建立源码/镜像锁 | DONE | 24 个源码仓和 35 个镜像 artifact 已验证 |
| R0-008 | 修正 Harbor 保护集工具 | DONE | dry-run 保护 35 项，删除候选为 0 |

R0 完成前不得开始 Backend 合并。

### R1 架构与迁移设计冻结

- R1-001：ADR：三个 App 保留、每 App 一个 Backend；
- R1-002：ADR：仓库重命名与归档策略；
- R1-003：Admin/Web/Internal API 与身份矩阵；
- R1-004：数据库归并清单、备份、回填、对账和回滚；
- R1-005：API/Worker/Agent Worker/Scheduler/Migration 运行角色矩阵；
- R1-006：模板继承契约与实例漂移门禁；
- R1-007：镜像晋级、保留窗与 Harbor GC 策略。

退出条件：ADR 全部 `ACCEPTED`，仓库/API/数据/部署目标无悬空决策。

状态：`DONE`。逐仓执行矩阵见 `architecture-v2/R1-migration-matrices.md`，门禁结果见
`architecture-v2/R1-gate-result.md`。R1 盘点同时发现 Info/Knowledge API 的 Redis ACL 配置
漂移；它是 R2 前必须清除的旧拓扑健康前置条件，不是新的架构悬空决策。

### R2 tpl-backend 合并

1. 建立或重命名规范 `tpl-backend`；
2. 冻结 Admin/Web Backend 能力清单；
3. 建立目标分层和依赖方向测试；
4. 合并认证、会话、审计、存储、消息、任务与 interaction；
5. 统一配置模型、异常模型、日志、健康检查和 Alembic；
6. 建立 API/Worker/Scheduler/Migration 启动入口；
7. Admin Next + Backend 配对门禁；
8. Web Next + Backend 配对门禁；
9. 两前端同时运行、身份隔离和共享数据库所有权门禁；
10. 旧两个 Backend 回滚验证。

退出条件：模板三组件可在隔离环境以不可变 digest 完整运行。

状态：`DONE`。统一 Backend、Admin Next、Web Next 已由真实 PostgreSQL/Redis、迁移往返、
Outbox/Inbox、角色启动、身份隔离和 16 条 Playwright 用例共同验收；三张候选镜像已按源码
commit 推送 Harbor 并从远端复核不可变 digest。证据见
`architecture-v2/R2-template-backend-result.md`。这些候选尚未晋级正式 `2.0.0`，也尚未部署
KIND；后者属于 R3。

### R3 K8s 模板重构

- 一个 Backend Config/Secret/Service；
- API 与 Worker 等角色由同一镜像、不同命令部署；
- 单一 Migration Gate；
- Admin/Web 两套 Ingress 和同源代理；
- Internal Service 与 NetworkPolicy；
- PDB/HPA/资源/探针按角色配置；
- 生成器和部署脚本 clean-room 验证。

退出条件：同一模板 release 以不可变 digest 完成结构、部署、Migration、严格 TLS、真实 Casdoor、
双端身份隔离、NetworkPolicy 报文级 allow/deny、原生回滚/前滚和资源清理门禁。

状态：`DONE / R3.2 REVALIDATED`。规范 scaffold、部署器、真实 Casdoor 双端门禁、R2 回滚/
R3.2 前滚复验和独立 Calico 策略集群均已通过；schema 2 模板 release
`architecture-v2-r3.2-20260808` 已取代 R3.1 锁，成为 R4 唯一来源。证据见
`architecture-v2/R3-kubernetes-template-result.md`、
`architecture-v2/R3.2-template-revalidation-result.md` 与
`architecture-v2/evidence/R3.2-template-gate/`。候选仍未晋级正式 `2.0.0`。

### R4 立即同步三个实例共同底座

严格串行：Info -> Knowledge -> Investment。每个实例必须：

1. 从已验收模板 release manifest 同步全部共同能力；
2. 保留领域代码并通过差异分类；
3. 完成 Admin/Backend 和 Web/Backend 两套配对；
4. 通过后才允许进入下一个实例。

R4 全部完成前停止新业务功能开发。

当前进度：Info 与 Knowledge 均已完成源码差异分类、两套配对、隔离 KIND、严格 TLS 双身份、
原生回滚/前滚和 Calico 报文门禁，证据见 `architecture-v2/R4-info-result.md` 与
`architecture-v2/R4-knowledge-result.md`。原 Research R4 已被 Investment 原地改名/迁移 R4 取代，
权威边界见 `../investment清理和改名.md`；不得先同步旧 Research 再重复改名。

### R5 实例 Backend 与数据库归并

按 Info -> Knowledge -> Investment 串行完成代码迁入、迁移链归并、数据回填、对账、切读、
切写、旧写入封锁和回滚门禁。Investment 还必须独立验证 Agent Worker、checkpoint、SSE、
取消、resume、工具副作用和长期记忆边界。

每个实例必须在进入下一个实例前同时完成以下五个闭环，缺一项都不得标记 R5 DONE：

1. 实例源码父仓只保留规范 `backend + admin-frontend + web-frontend` 活跃拓扑；
2. 数据库 migration、owner、runtime/migration role 和旧写入口完成可逆切换；
3. KIND/目标集群完成严格 TLS、真实身份、单写者、数据对账和原生回滚/前滚；
4. `k8s/sunmoonai/app-platform/<app>` 成为正式声明式部署唯一真相源，默认整体部署只能重建
   已验收的 v2 正式态，不能重新启用旧双 Backend；
5. 从干净生成目录执行 render/diff/apply/reconcile 门禁，证明 Git 清单与集群对象无漂移，且
   GitHub/Gitee SHA 一致。

候选 bundle、`$HOME/.local/state` 产物、手工 `kubectl patch/scale` 和运行态 smoke 都只能作为
迁移手段或证据，禁止替代第 4、5 项。v1 回滚声明在 R7 前必须保留于显式 `legacy-v1` 边界，
但不得继续被默认部署入口扫描或应用。此规则对 Info、Knowledge、Investment 完全相同；若前一
实例未完成声明式收口，禁止开始后一实例。

### R6 跨 App 真实竖线

真实文档 -> Info Artifact/Outbox -> Knowledge Ingestion/Index/Retrieval -> Investment 引用回答。
禁止 fake LLM、mock ingestion、伪造 retrieval 或绕过身份。

### R7 发布、观察窗与退役

- 同一候选 digest 晋级 `2.0.0`；
- 三 App 串行切流；
- 保留旧 Backend、数据库、Secret 和 `1.0.0` 回滚窗；
- 观察窗结束后归档旧仓、删除旧部署和旧数据角色；
- 重算 Harbor 保护集，再删除与 GC。

### R8 文档重建

从已部署、已验收的真实架构重新编写：

- 总体架构；
- 长期规划；
- 实施计划；
- Task；
- Handoff；
- 发布与运维手册。

旧 v5 文档标记为历史，不再与新文档并列为执行权威。

## 7. 测试和证据分层

每一阶段至少按以下层级选择适用门禁：

- L1：静态检查、格式、类型、依赖方向；
- L2：单元测试；
- L3：契约与 consumer-driven contract；
- L4：Backend 角色与数据库集成测试；
- L5：Admin/Backend、Web/Backend 配对测试；
- L6：KIND、严格 TLS、真实 Casdoor、故障注入和回滚；
- L7：跨 App 真实 E2E、观察窗和恢复演练。

代码提交、镜像构建或 Pod Ready 均不等于任务完成。证据必须记录源码 commit、镜像 digest、
配置摘要、测试结果、清理结果和回滚结果。

## 8. 禁止事项

- 禁止直接在 master 施工；
- 禁止先改实例、后补模板；
- 禁止同时批量替换三个实例；
- 禁止把 Admin/Web/Internal 复制成三套 application；
- 禁止合并三个 App 的数据库；
- 禁止让 Next.js 成为领域数据所有者；
- 禁止用新构建覆盖 `1.0.0`；
- 禁止删除镜像锁中的 digest；
- 禁止没有备份和对账就合并数据库；
- 禁止在新架构完成前删除旧 Backend 仓、旧数据库或旧 Secret；
- 禁止用阶段性 smoke 宣称 Architecture v2 完成。

## 9. 当前下一步

R0 证据见 `architecture-v2/R0-baseline-result.md`；R1 证据见
`architecture-v2/R1-gate-result.md`；R2 前置门禁见 `architecture-v2/R2-preflight-result.md`。
Redis ACL 旧拓扑已恢复，R2 模板代码和 R3 Kubernetes/身份/回滚/策略门禁均已通过；R3.2 又对
Web 配对部署标识和 Admin/Web 构建代理入口完成了模板优先修正及连续完整复验。当前唯一模板源
是 schema 2 release `architecture-v2-r3.2-20260808`，证据见
`architecture-v2/R3.2-template-revalidation-result.md`。Info 与 Knowledge R4 已按真实候选镜像
完成全部退出门禁，证据见 `architecture-v2/R4-info-result.md` 与
`architecture-v2/R4-knowledge-result.md`；当前只允许继续 Investment 原地改名/迁移 R4。R4 完成前不得开始 R5
数据归并、删除旧 Web Backend/数据库/Secret、晋级 `2.0.0` 或继续新业务开发。
