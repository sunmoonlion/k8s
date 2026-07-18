# ADR-016：Web BFF 双实现模板与 FastAPI 默认主线

状态：ACCEPTED
日期：2026-07-18
决策者：项目负责人、架构评审

## 1. 背景

ADR-014 已确认 Next Web Frontend 必须与同产品 Web Backend/BFF 成对发布和验收，但其
初始版本把 NestJS 固定为默认实现。后续复核确认：

1. Next App Router 的 SSR/SSG/CSR 与后端语言无关；边界是 HTTP/JSON/SSE、同源 cookie、
   server-only DAL/DTO 和版本化契约。
2. 当前 Nest `tpl-web-backend` 仍是旧认证原型，但已完成 Node 24/JOSE 运行时基线；项目
   希望将其补齐为以后可直接实例化的 NestJS Web BFF 模板，而不是删除。
3. Info、Knowledge、Research Admin Backend 与 Research Runtime 已以 Python/FastAPI 为
   主，Web 默认后端改为 FastAPI 可统一安全内核、Principal、错误、服务身份、审计、
   OpenAPI/Pydantic、SSE 和 Kubernetes 运维方式。
4. 当前 canonical `tpl-admin-backend` 本身尚未追上三套业务 Admin 在 P0-005 已验证的
   PKCE/state/nonce/JWKS、最小 session、CSRF、migration 和 fail-closed 基线；直接复制
   会传播旧缺陷。

## 2. 决策

### 2.1 仓库与默认实现

模板最终保留两个 Web Backend 实现：

```text
tpl-web-backend         FastAPI，默认实现
tpl-web-backend-nest    NestJS，受维护的可选实现
```

现有 `tpl-web-backend` 先在原仓完成 Nest 生产骨架和 Next 配对验收，固定 Git tag、镜像
digest、契约版本和回滚证据后，远程及子模块改名为 `tpl-web-backend-nest`。随后创建新的
`tpl-web-backend`，以修复后的 FastAPI 通用母版为种子并改造成 Web surface。仓库改名和
新仓建立必须在同一受控任务内完成，禁止出现父仓 gitlink 指向错误远端或两个仓库同名的
中间状态。

`tpl-app` 默认实例化 `tpl-web-backend`（FastAPI）。Nest 仓是明确支持的实现 profile，
不是默认部署，也不是历史代码坟场。若不能持续通过共享契约门禁，必须降级标记为
`REFERENCE_ONLY`，不得宣称可直接使用。

### 2.2 FastAPI 通用母版来源

不得把当前 `tpl-admin-backend` 原样复制为 FastAPI Web 主线。顺序固定为：

1. 从 Info/Knowledge/Research 已通过 P0-005 的实现中只提取通用安全与基础设施能力，
   反向补齐 canonical `tpl-admin-backend`；不得带入 Document、Ingestion、Run 等领域代码。
2. `tpl-admin-backend` 通过模板级身份、CSRF、migration、审计、配置、Docker/KIND 和
   clean-room 门禁后，才可作为 FastAPI Web Backend 的生成输入。
3. 新 `tpl-web-backend` 可在文件树层面由该固定 commit 初始化，但必须立即替换为 Web
   专属 surface、Casdoor client/audience、cookie、Redis namespace、API allowlist、
   下游 service relations 和 Next internal-DAL contract。

“继承全部通用能力”指经过验证的配置、日志、错误、数据库/Alembic、Redis、OIDC、
Principal、CSRF/CORS、服务身份、审计、health/readiness、测试和部署能力；不表示共享
Admin 路由、Admin cookie/audience、领域模块或数据库所有权。

### 2.3 配对与信任边界

默认发布单元为：

```text
tpl-admin-frontend  + tpl-admin-backend       # React SPA/Nginx + FastAPI Admin
tpl-web-frontend    + tpl-web-backend         # Next Node + FastAPI Web（默认）
tpl-web-frontend    + tpl-web-backend-nest    # Next Node + Nest Web（可选 profile）
```

前后端配对取决于 contract、surface、audience、cookie、部署和回滚 tuple，不取决于是否使用
不同编程语言。Admin 与 Web 即使都使用 FastAPI，仍是两个独立信任面、仓库、Deployment、
Casdoor client、session namespace 和发布单元；二者不得互相替代验收。

Next 继续负责 App Router 混合渲染和 Node standalone 运行；Web Backend 负责 OIDC/BFF
session、CSRF、资源授权、同源 `/api`、下游协议适配和 SSE。Next Route Handler 不复制
第二套 auth/domain BFF，Server Component 只经 `server-only` DAL 调用选中 backend 的
内部 Service URL。

### 2.4 共享契约与双实现门禁

FastAPI 与 Nest 必须消费同一语言无关契约：

- `/api/auth/*`、browser-safe Principal、CSRF、cookie 和稳定错误语义；
- `/api/web/v1/*` allowlist、correlation/operation ID；
- SSE event/cursor/reconnect/reconcile/cancel/resume；
- Citation DTO 和受权来源跳转；
- health/readiness/version、OpenAPI/JSON Schema 及兼容窗口。

Next 的 typed client/DAL 不得按实现语言分叉。共享 consumer/contract vectors 对两个 backend
运行；浏览器 E2E 分别证明 Next+FastAPI 和 Next+Nest，业务 App 与 P0-008C 只使用默认
FastAPI profile。禁止在同一入口把两个实现无状态混合负载均衡。

### 2.5 长任务与状态所有权

无论 backend profile 为何，Web BFF 都不能执行或拥有 LangGraph 长任务、Run Journal、
Artifact、Retrieval 或 Citation 真相。它只进行 session/授权、DTO 组装、命令转发和受控
流式透传；长任务由 Research Runtime/worker 执行，持久事实仍归对应领域数据库和投影。

## 3. 实施顺序

P0-008B 串行拆为：

1. B1：Node/Next/Nest 运行时与 clean-room 基线（已接受）。
2. B2：Nest Web BFF 身份安全内核与 Next server-only DAL/DTO。
3. B3：Next UI/query/stream/citation 与 Nest 配对协议。
4. B4：Nest 双 Pod、浏览器、安全、滚动/回滚门禁；固定并改名
   `tpl-web-backend-nest`。
5. B5：反向补齐 `tpl-admin-backend` FastAPI 通用母版；创建并完成默认
   `tpl-web-backend` FastAPI Web surface。
6. B6：共享 contract vectors、Next+FastAPI 配对 E2E、双实现差异矩阵与默认发布 tuple。

B1~B6 全部接受后 P0-008B 才完成。P0-008C 的 Research 真实试点和三个业务 Web 的后续
原地迁移只使用 FastAPI 默认实现；Nest profile 不能作为业务主线完成证据。

## 4. 拒绝的替代方案

1. **删除 Nest 实现**：拒绝。项目明确需要一套可直接实例化的 Nest Web BFF 模板。
2. **当前 `tpl-admin-backend` 直接整树复制并立即发布**：拒绝。它仍含未验签 token、
   非一次性 state、完整 Provider token session、GET logout 和登录路径 DDL 等旧原型。
3. **Admin 与 Web 合并成同一 FastAPI 服务**：拒绝。会混淆 audience、cookie、授权面、
   发布节奏和故障半径。
4. **Next Route Handler 成为第三套 BFF**：拒绝。会重复 session/token、增加往返并制造
   第二份领域/授权逻辑。
5. **两个 backend 同时挂在一个生产入口做随机切流**：拒绝。只有显式 profile、独立
   release tuple 和有状态兼容验证后才可切换。

## 5. 接受条件

本 ADR 接受表示方向和施工顺序已冻结，不表示任一 backend 已生产就绪。完成证据必须由
P0-008B/B2~B6 提供，包括两个仓库远端/gitlink、不可变 tag/digest、共享契约结果、两套
配对 E2E、FastAPI 母版来源清单、无领域代码泄漏、双 Pod/滚动/回滚和安全负向矩阵。
