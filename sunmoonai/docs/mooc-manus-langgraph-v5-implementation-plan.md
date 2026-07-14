# MoocManus v5 详细实施方案

状态：Draft for Execution
架构依据：`mooc-manus-langgraph-longterm-plan-v5.md`
日期：2026-07-11

## 0. 使用方法

本文件是四仓统一施工清单。任务按依赖顺序执行，不以“代码已写”作为完成标准。

状态枚举：

```text
NOT_STARTED -> DESIGNED -> IMPLEMENTED -> UNIT_VERIFIED
-> INTEGRATION_VERIFIED -> DEPLOYED -> E2E_VERIFIED -> ACCEPTED

条件分支未被 ADR-001 选中：NOT_APPLICABLE（必须附 ADR 引用）
```

任务类型：

- `ARCH`：ADR、契约或高风险 Spike。
- `FUNC`：产品功能。
- `RELIABILITY`：幂等、恢复、事务、故障治理。
- `SECURITY`：身份、授权、Secret、网络和数据安全。
- `HARDENING`：规模、性能、HA、归档和运维。

优先级：

- P0：进入下一阶段或接流量的硬门槛。
- P1：当前阶段必须完成。
- P2：有明确触发条件的后续能力。

每项任务关闭前必须记录：commit SHA、测试命令/输出、migration revision、image digest、部署对象、API 样本、故障测试和回滚结论（按任务适用范围）。

## 1. 全局交付规则

### 1.1 分支与提交

- 四仓继续使用 `codex-1` 完成当前重构，合并前保持可独立审查。
- 跨仓任务按同一 Task ID 写入 commit/message/handoff。
- 一个提交只完成一个可验证目标；禁止把大规模格式化混入功能提交。
- 子模块指针只在子模块提交、测试和镜像证据完成后更新。

### 1.2 测试层次

```text
L1 Unit
L2 Component Integration
L3 Contract
L4 Cross-app E2E
L5 Failure Injection
L6 Evaluation/Quality
L7 Deployment/Operations
```

P0/P1 任务必须明确适用的测试层次，不能只写“补测试”。

### 1.3 证据目录

建议在各仓 `docs/evidence/v5/<task-id>/` 保存去敏后的：

- README/result.md。
- test-output.txt。
- request/response JSON。
- migration/current revision。
- image digest 和 deployment imageID。
- failure timeline。
- evaluation report。

不得提交 token、Cookie、数据库密码或 API key。

### 1.4 开流量规则

在 Gate M1b 未通过前：

- `AGENT_V4_TRAFFIC_ENABLED=false`，v5 新增独立 `AGENT_V5_TRAFFIC_MODE=off|shadow|canary|on`。
- 不复用 v4 flag 作为 v5 发布控制。
- smoke 走内部测试身份和明确的 test dataset。

### 1.5 单一权威规则

- 架构语义以 `mooc-manus-langgraph-longterm-plan-v5.md` 为唯一权威，本实施方案只描述执行增量、依赖和验收。
- API/Schema 以 `knowledge-app/contracts/` 发布物为唯一权威，规划文档中的字段只用于解释，不作为机器契约。
- ADR 是决策理由的唯一权威；Runbook 是操作步骤的唯一权威；Evidence 是完成结果的唯一权威。
- 发现重复且可能漂移的定义时，删除副本并改成引用，禁止两处同步维护。

### 1.6 V5-REC-001 前端执行偏差恢复与经验固化

- 类型/优先级：RELIABILITY/FRONTEND/P0；在继续任何前端迁移或 Harbor 清理前执行。
- 背景：后端 `P0-005E` 的 `1.0.1` 固化、Info Admin 的旧 Vue 治理页面以及 Research Web 的旧 v4 Agent Console 曾在模板资格链完成前分别落地，造成“组件已经迁移/全部前端已经固化”的错误印象。它们不能改变 P0-007/P0-008/M1 的依赖关系，也不能被倒推为模板或业务迁移验收证据。
- 当前前端基线（2026-07-14）必须明确记录为：
  - `info-admin-frontend:1.0.1`：旧 Vue 治理实现，保留为迁移前回滚基线；不计入 React Admin 迁移。
  - `info-web-frontend:1.0.0`：旧 Next 基线。
  - `research-admin-frontend:1.0.0`：旧 Vue 基线。
  - `research-web-frontend:1.0.1`：旧 v4 Agent Console 临时试点；仅限隔离 KIND 开发环境，不计入 P0-008C Accepted 或 M1-413C 完成。
  - `knowledge-admin-frontend`、`knowledge-web-frontend`：按配置关闭且无 Deployment；在对应 React/Next 迁移完成前不得启用。
- 严格规则：
  1. `SKELETON_ACCEPTED` 不产生业务迁移资格；只有 `TEMPLATE_MIGRATION_READY` 和 `P0-007C/P0-008C ACCEPTED` 才能进入 M1-411/M1-413。
  2. App 级 `*_APP_IMAGE_TAG` 不得隐式决定任一 Frontend tag；部署必须使用组件级 tag，并在生成后拒绝 `p0-*` 临时 tag（显式隔离测试模式除外）。
  3. 旧 Vue/旧 Next 镜像、迁移前 Git tag 和 digest 是回滚资产，不得因“统一版本号”删除或覆盖；React/Next 重构必须使用新的候选 tag 和新的正式版本号。
  4. 任一 App 迁移必须单独完成“迁移前 tag/digest → candidate 镜像 → 隔离部署 → 浏览器/E2E/回滚证据 → 正式 tag”，不得三个 App 批量切换。
  5. 任何提前实现只能标记为 `PROVISIONAL_EARLY_SLICE`，必须记录与正式任务的差异、风险和恢复路径，不能修改任务状态或 Gate 结论。
- 恢复顺序：先完成本节的版本矩阵/生成清单清理，再恢复 `P0-007A2/A2.2`；随后完成 `P0-007B/C`、`P0-008A/B/C` 和 Gate P0，最后才按 Info → Knowledge → Research 执行 M1-411 与 M1-413。
- Harbor 清理：本节完成前不得删除任何稳定 tag；只允许在 Deployment、回滚记录和 digest 三方确认无引用后删除临时 tag，且保留观察期内的旧稳定版本。
- 经验教训：后续每个任务关闭时必须同时更新“任务状态、Git/SHA、镜像 tag+digest、Deployment、测试证据、回滚结论”六项；任何一项缺失都保持 `IN_PROGRESS`，不得以“镜像已运行”代替迁移验收。
- 本次恢复执行记录（2026-07-14）：
  - 三个 App 的前端组件 tag 已从 App 级继承链中分离，并写入各自顶层配置；Knowledge 前端保持关闭。
  - `k8s/utils/app-dependency-preflight.sh` 及三套 App 模板/入口已增加前端 `p0-*` fail-closed 门禁；只有显式 `V5_FRONTEND_TEST_MODE=true` 才允许隔离测试。
  - 六个前端生成清单已重新生成并核对：Info Admin `1.0.1`、Info Web `1.0.0`、Knowledge Admin/Web `1.0.0`（未部署）、Research Admin `1.0.0`、Research Web `1.0.1`（仅隔离旧 v4 试点）。
  - 六个生成清单均通过 `kubectl apply --dry-run=client --validate=false`；Info/Knowledge/Research 的 `validate-resources --cluster KIND` 均通过。
  - 未删除 Harbor 镜像；稳定回滚版本和旧试点仍按规则保留。当前没有任何业务 App 迁移被宣称完成。
- 状态：ACCEPTED（2026-07-14；恢复证据为组件级 tag 矩阵、六份生成清单 dry-run、三套 validate-resources 结果；下一步仅进入 P0-007A2/A2.2）。本轮工作树改动尚未提交/推送，不得视为新的可发布 release；提交时仍须补齐 Git/SHA、变更文件和回滚记录。

## 2. Immediate Safeguard 与 Phase 0

### V5-IMM-001 配置真相紧急保护

- 类型/优先级：SECURITY/RELIABILITY/P0
- 仓库：`k8s`
- 时机：立即执行，不等待 Runtime ADR，不开启生产主链改造。
- 目标：消除 Git 生成清单 `traffic=true` 与集群实际 `false` 的危险漂移。
- 实施：将 Git desired state 固定为关闭；增加生成后断言和部署前 diff；v5 使用独立 traffic mode。
- 测试：从干净工作区重新生成并 dry-run，结果仍为关闭；CI 对意外开启返回失败。
- 验收：重新部署不会开启未验收流量；集群和 Git desired state 一致。
- 状态：ACCEPTED（2026-07-11；证据：`sunmoonai/docs/evidence/v5/V5-IMM-001/result.md`）

### 2.1 Phase 0 范围

目标：用八个阻塞性决策/验证包在重写生产主链前证伪最危险假设。核心 ADR Spike 时间盒仍建议 2~3 周且代码可被废弃；两个前端模板资格链另行估算，不把完整 Phase 0 虚报为同一 2~3 周。SSE/cancel/worker kill 并入 Runtime Spike，重复投递/外部副作用恢复并入可靠交付 Spike；P0-007 验证 React Admin，P0-008 在上游 stream/citation/identity 决策后再基线 Next Web。

### V5-P0-001 Runtime 选型 ADR

- 类型/优先级：ARCH/P0
- 仓库：`research-app`、`k8s`
- 目标：比较自建 Runtime、Agent Server、混合模式。
- 实施：为相同两节点 interrupt/tool graph 建三个候选中至少两个可运行原型；测创建、stream、SSE 断线对账、cancel、worker kill、resume、同 Thread 并发；以最小浏览器 harness 验证 Runtime stream 可被产品客户端恢复，不能只用命令行读取流。
- 测试：L2/L5/L7。
- 验收：评分矩阵、许可结论、运行证据、退出成本和 ADR-001 获批。
- 回滚：Spike 不接生产数据；删除部署即可。
- 状态：IN_PROGRESS / CANDIDATE_A_PARTIAL（2026-07-11；ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-001-runtime-selection.md`；证据：`sunmoonai/docs/evidence/v5/V5-P0-001/candidate-a-partial.md`）

### V5-P0-002 执行身份模型 Spike

- 类型/优先级：ARCH/P0
- 仓库：`research-app`
- 前置：P0-001 可并行调研，最终模型与选型对齐。
- 目标：验证 Session/Thread/Run/Attempt/Invocation 分离。
- 实施：最小迁移或隔离表；一个 Session 创建两个 Run；一次 worker retry 产生第二 Attempt；Subagent 产生子 Invocation。
- 测试：唯一性、状态转换、checkpoint mapping、并发条件更新、lineage 查询。
- 验收：任何 ID 不复用承担两种实体；waiting/resume/retry 能准确定位。
- 状态：NOT_STARTED

### V5-P0-003 Info-Knowledge Artifact Contract Spike

- 类型/优先级：ARCH/P0
- 仓库：`info-app`、`knowledge-app`、`k8s`
- 目标：用不可变 S3 引用替代未闭合 `info-artifact:`。
- 实施：Info 产生 `s3:// + hash + size + content_type + storage_version`；Knowledge 使用只读身份下载并校验。
- 安全：bucket/key allowlist、最大大小、hash mismatch 拒绝、日志脱敏。
- 测试：L3；篡改 hash、对象缺失、权限拒绝、超大对象。
- 验收：真实 Info DocumentVersion 产物被 Knowledge 读取，零数据库反查。
- 状态：ACCEPTED（2026-07-12；契约：`knowledge-app/contracts/artifact/v1`；schema SHA-256：`a3219604ed3562c436336d4650c2a0fd08afd9a8829e1d17b12d6a929f499c81`；ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-003-info-knowledge-artifact-contract.md`；证据：`sunmoonai/docs/evidence/v5/V5-P0-003/result.md`）

### V5-P0-004 Retrieval/Citation Contract Spike

- 类型/优先级：ARCH/P0
- 仓库：`knowledge-app`、`research-app`
- 目标：定义并实现最小 retrieve API。
- 实施：在 `knowledge-app/contracts/` 建权威 OpenAPI/JSON Schema；静态 allowlist dataset；query/top_k/filter/token_budget；返回 Evidence 和 Info lineage；发布版本化 contract artifact；定义前端可安全展示的 Citation DTO 与受权来源跳转，不把 Provider metadata 原样暴露给浏览器。
- 测试：L3；未知 dataset、空结果、权限拒绝、Provider timeout、citation 回溯。
- 验收：Research KnowledgePort 不引用 RAGFlow 类型即可完成查询；Knowledge provider compatibility、Info/Research consumer-driven tests 和 k8s 兼容矩阵均可在 CI 运行。
- 状态：NOT_STARTED

### V5-P0-005 身份与服务调用 Spike

- 类型/优先级：SECURITY/P0
- 仓库：四仓
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-005-identity-service-calls-browser-bff.md`（CANDIDATE）。
- 目标：区分浏览器用户、Info service、Knowledge service、Research worker；先关闭三套 Admin 和 Info -> Knowledge 的真实匿名/身份混用缺口，再由 P0-008B/C 把相同 contract 应用于三套 Web。
- 实施：Authorization Code + PKCE BFF session；严格 OIDC/JWKS 验证；Web/Admin 六 audience；App/Surface 隔离 cookie/session；CSRF/CORS；Principal 与 actor/scope/resource check；client-credentials 服务 token；K8s ServiceAccount 到服务主体的部署绑定。
- 测试：匿名、伪造签名、错误 issuer/audience、过期 token、state/nonce/PKCE 重放、跨用户 Session/资源、缺 scope、CSRF、浏览器 session 调 internal route。P0 固定 Admin/Web audience consumer vectors；真实 Web route 的双向误用测试在 P0-008C 完成。
- 验收：三套 Admin 业务路由不再匿名；关键资源不只检查“已登录”而检查 owner/scope；actor/reviewer 不信任请求体；Info -> Knowledge 使用真实、最小 scope 的服务 token；浏览器 token 不被当作跨仓服务凭据；前端路由守卫不承担最终授权。
- 状态：ACCEPTED（2026-07-14；三套 Admin 的真实匿名/服务 JWT、负向 token、浏览器 PKCE/CSRF/跨用户和严格 TLS 矩阵均通过；三组 API/worker 已以 1.0.1 运行并按 digest 核对；正式 ADR-005 可接受）

#### V5-P0-005A 冻结协议与测试向量

- 仓库：`k8s`。
- 实施：评审 ADR-005；以 `sunmoonai/docs/mooc-manus-v5/contracts/security/v1/` 为平台身份 contract 唯一真相源，固定六 application/audience、Principal、401/403、session/CSRF、OIDC callback、service binding 和路由分区语义；建立不含有效 credential 的配置模板和跨语言正/负 JWT claim fixtures。
- 验收：后续 Python/Nest/K8s 工作不再自行解释 audience、scope、cookie 或错误语义；ADR 保持 CANDIDATE，必须等真实 KIND 证据后才 ACCEPTED。
- 状态：ACCEPTED（2026-07-14；contract、正负 JWT 向量、KIND 服务身份证据和严格 TLS 浏览器证据已归档）

#### V5-P0-005B 三套 Admin 浏览器身份闭环

- 仓库：`info-app` -> `knowledge-app` -> `research-app`，按顺序逐仓验证，不并行批量复制。
- 实施：引入标准 JOSE/OIDC 能力；一次性 state/nonce/PKCE 登录事务；严格 ID Token 验证；安全 session 与 `/me`/POST logout；CSRF/CORS；shadow user migration；按 Public/Admin/Internal 分 Router；Admin 业务 route fail closed。
- 关键资源：Info/Knowledge 管理 scope；Research Session/Run/Event/SSE 从认证 Principal 得到 owner，忽略或拒绝 payload 冒充的 actor/security context。
- 测试：L1/L2/L3；每仓先跑共享安全向量，再跑本仓 allow/deny、旧行为回归和泄密断言。Research 还需跨用户 Session/Run/SSE 测试。
- 验收：无 cookie 401、失效 cookie 401、scope/owner 不足 403；三仓 `/auth/me` 与 Redis/log 抽查无 token；login path 无 DDL；credential CORS 无通配 origin。
- 状态：ACCEPTED（2026-07-14；Info `c1dad4e`、Knowledge `a38eefd`、Research `7724a58`；三仓测试 60/48/76 通过；KIND 匿名、跨用户、CSRF 和严格 TLS 浏览器矩阵已复验）

#### V5-P0-005C Info -> Knowledge 服务身份闭环

- 仓库：`info-app`、`knowledge-app`、`k8s`。
- 实施：Casdoor client credentials；Knowledge exact issuer/audience/subject 验证；关系权限由 `knowledge:ingest` 本地 subject binding 强制（Casdoor provider 返回的 `scope`/`scp` 仅做格式校验，不能替代本地关系授权）；ingestion command 迁移到 `/api/internal/v1/knowledge/ingestions`；Info worker 短时 token cache；删除静态 API key 和匿名 ingestion fallback。
- 测试：允许调用；无 token、Admin session、伪造签名、错误 audience、过期 token、未知 subject、畸形 scope 全拒绝；撤销 ingestion client 不影响浏览器 Admin；P0-003 artifact success/hash/404/403 回归。
- 验收：Knowledge 审计能同时定位 service principal 与 operation/correlation ID；token 不进入任务 payload、数据库、日志和错误响应。
- 状态：KIND_SERVICE_ACCEPTED（2026-07-12；Info `1fb07f9`、Knowledge `22ccd58` + `65c6552` + `3088815` + `e3eddcd`；真实 Casdoor client_credentials 通过标准 discovery issuer、RS256、audience、subject binding；证据见 `sunmoonai/docs/evidence/v5/V5-P0-005/result.md`）

#### V5-P0-005D K8s/Casdoor 真实验证与接受

- 仓库：`k8s`。
- 实施：以 Secret 引用配置六个浏览器 client/audience 和最小服务 client；Casdoor 注册通过 `post-deploy-setup.local.conf`（仅部署机、gitignore、权限 0600）注入，不把 client secret 写入仓库；脚本支持浏览器 `authorization_code` 与服务 `client_credentials` grant；绑定 workload ServiceAccount；构建、部署 traffic-off 镜像；运行允许/拒绝矩阵与停流回滚。
- 测试：L4/L6/L7；配置缺失、JWKS rotation/未知 kid、Casdoor/Redis 不可用均 fail closed。`sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_005_kind.py` 只输出状态码和去敏结果，不输出 access token/client secret；它覆盖三套 Admin 匿名拒绝、Research traffic-off 临时验证和真实 service client 到 Knowledge internal route 的认证边界；Playwright 严格 TLS 矩阵覆盖三套 Admin 的 PKCE/CSRF/跨用户、provider UI latency 和无外部主机请求。
- 验收：ADR-005 接受条件全部满足；归档 contract/config digest、镜像与 deployment digest、测试结果和回滚证据，然后把 P0-005/ADR-005 标记 ACCEPTED。
- 状态：ACCEPTED（更新于 2026-07-14；KIND 匿名/真实服务 JWT、负向 token、专用 migration role/Secret、运行时 DDL 撤权、Always-pull Deployment 前 Alembic gate、浏览器 PKCE/CSRF/跨用户和严格 TLS 矩阵全部通过；Research traffic 已恢复 false）

#### V5-P0-005F Casdoor UI / 配置 / 就绪硬化

- 类型/优先级：SECURITY/RELIABILITY/P0，且是 `P0-005E` 镜像固化的阻塞前置。
- 仓库：`k8s`（Casdoor Helm chart、部署脚本、Ingress、浏览器验证脚本）。
- 根因基线：Casdoor 3.42.0 登录页在 `organization.languages` 为 NULL 时会在前端读取 `.length` 并白屏；原部署后 SQL 只修 `owner=admin` 且数据库失败时仍放行；TCP/Pod phase 不能证明 HTTP/DB/静态资源就绪；`/conf` 曾允许 PVC 漂移和 `kubectl exec` 写入；UI 仍依赖 Google Fonts/Casdoor CDN，浏览器 gate 默认 60 秒且忽略 TLS。
- 实施：
  1. 所有环境使用 Secret 引用 `APP_DB_URI`，`app.conf` 由 ConfigMap 单一声明（`runmode=prod`、`copyrequestbody=true`、`staticBaseUrl="."`、`aiAssistantUrl=""`），删除向 `/conf` 写临时文件的 fallback；`deploy` 与 `upgrade` 走同一 identity/readiness 流程。
  2. Helm 启动时将静态包复制到 `emptyDir`，移除非必要外部字体/CDN；Ingress 仅对带 hash 的 `/static/` 使用压缩和 immutable cache，不缓存 OAuth/API/HTML。
  3. post-deploy 在所有组织上修补 `languages`，建立 JSON array 数据库不变量；PostgreSQL、ConfigMap、静态资源任一检查失败都必须返回非零。
  4. post-deploy 的 K8s PostgreSQL client 在同一轮初始化中复用并在退出时清理，禁止每条 SQL 重新创建 Pod。
  5. 删除仓库中的 Casdoor business credential/placeholder；P0-005 provision Job 是业务 identity 的默认唯一入口，legacy operator-only local config 必须显式开关；DB bootstrap 的管理员/租户密码改为 operator environment required。
  6. 真实 HTTP/DB/静态 readiness probe 取代 TCP probe；浏览器 gate 将 Casdoor UI 默认边界降到 20 秒，pageerror、静态/网络失败严格失败，并提供 `P0_BROWSER_STRICT_TLS=true` 的不忽略证书路径。严格模式使用完整 Chromium + 隔离 NSS DB 导入平台 Root CA；缺少 `certutil` 时必须 fail closed。
  7. KIND 环境的 Casdoor PostgreSQL DSN 固定使用 `sslmode=disable`（Casdoor 使用的 `lib/pq` 不支持 `prefer`），且 upgrade 在 Secret/ConfigMap 变化后显式滚动重启 Deployment。
  8. 迁移门禁 Job 使用共享脚本的可配置 `ttlSecondsAfterFinished`（默认 7 天）和默认 `imagePullPolicy: Always`，避免稳定 tag 被节点旧缓存覆盖；成功日志先进入集中/本地审计归档，再由 TTL 自动清理，禁止把长期保留 Completed Pod 当作审计系统。
- 测试：Helm lint/template（三环境）；shell/node syntax；静态 asset rewrite；`sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_005_casdoor_runtime.sh` 只读 runtime gate；Casdoor Pod 冷启动/删除 Pod 后 readiness；组织 `languages` NULL/invalid/array 负例；canonical host TLS；三套 Admin Playwright PKCE/CSRF/跨用户矩阵。
- 验收：连续冷启动首屏无白屏；Casdoor 外部字体/CDN 不再成为 UI 必需依赖；配置或数据库不变量失败时部署退出非零；`deploy` 和 `upgrade` 的结果等价；浏览器输出包含 provider UI latency 且不输出 credential/token。
- 状态：ACCEPTED（更新于 2026-07-14；KIND Helm upgrade、最终配置冷启动、runtime gate、三套 Admin 浏览器 PKCE/CSRF/跨用户矩阵、完整 Chromium 隔离 NSS Root CA 严格 TLS 和无外部主机请求检查均通过；迁移 Job 已归档并由 TTL 自动清理；Casdoor 首屏 UI latency 约 0.5–1.0 秒）

#### V5-P0-005E 镜像 tag 与组件部署隔离

- 仓库：`k8s`，镜像仓库由部署机操作。
- 规则：通过测试的 Info/Knowledge/Research Admin Backend API+worker 镜像统一发布为 `1.0.1`；Admin/Web/Frontend 未通过同一测试的组件不得继承 App 级临时 tag。部分组件部署必须使用组件级 `*_TAG`，不能把 `*_APP_IMAGE_TAG` 作为隐式全 App 发布开关。
- 切换顺序：先以 digest 核对并把已验证镜像 retag 为 `1.0.1`，再只滚动三个 Admin Backend/API+worker；验证 P0-005 与 readiness 后，才允许删除临时 `p0-*` tag。旧稳定 tag 不得在没有回滚副本/归档 digest 的情况下直接删除。
- 本次纠偏：原 Harbor `1.0.1` 中 Knowledge/Info 的旧 digest 未满足最终 migration/service contract，已先由 `p0-005-auth-*` 回滚 tag 保留，再将通过最终门禁的 digest 发布为 `1.0.1`；后续发布不得复用该纠偏流程，必须使用新候选 tag 后不可变 retag。
- 状态：ACCEPTED（2026-07-14；Info `1.0.1` -> `sha256:0dd720796ad52086345ca3b5f5b87a52bf2e2141fa00214a1c301561dda570ad`，Knowledge `1.0.1` -> `sha256:29fdbabc8a59ed855141bb292b2525a585bf94cfdb3ddb434973fcc91774911f`，Research `1.0.1` -> `sha256:1ad5ef63069f4345ce52a4951b1a82eacb2e86267c848561c172b399e5e114ef`；六个 API/worker 实际 imageID 已核对，迁移/服务/浏览器门禁均通过；旧 digest 仍由 `p0-005-auth-*` 回滚 tag 保留，未删除 `1.0.0`）

### V5-P0-006 可靠交付 ADR 与最小原型

- 类型/优先级：ARCH/RELIABILITY/P0
- 仓库：`info-app`、`knowledge-app`、`research-app`
- 目标：为“数据库提交成功、消息未投递”选择统一语义，不要求立即抽取共享框架。
- 实施：比较 transactional outbox、数据库 pending scanner 和 broker transaction 限制；至少在一个链路实现并注入 broker 故障；验证稳定 operation ID 和外部副作用阶段恢复。
- 测试：DB commit 后阻断 RabbitMQ、dispatcher 重启、重复 publish、两个 dispatcher 竞争、外部 upload 后 kill/retry。
- 验收：ADR-006 获批；选定方案能自动发现并补投，不产生重复业务效果；明确 M1 各仓落地任务。
- 状态：NOT_STARTED

### 前端物理仓库与差异基线（2026-07-13）

该基线只描述当前事实，任务与验收仍以 P0-007/P0-008 为唯一权威：

| 角色 | 当前仓库/提交 | 事实与处置 |
|---|---|---|
| React Admin 模板 | `tpl-app/tpl-admin-frontend@451d22f`（A2.1 实现 `d2fa1a8`；A2 开工基线 `7a04bbe`） | 唯一 Admin 模板；React 19 + React Router 8 Framework Mode + Ant Design 6；A2.1 Shell 已接受，身份、CRUD、Rich/Utility 和 Production Gate 仍未完成 |
| Vue Admin 输入 | Info `fd3a943`、Knowledge `6a33732`、Research `3ef205a` | 三个现有 App 约 250 个文件且高度同源；Info 仅多真实 `src/pages/info/crawl.vue`，其余少量差异主要来自生成内容；作为 A2 能力盘点和后续业务迁移输入，不再另建 Vue 模板仓库 |
| Next Web 模板 | `tpl-app/tpl-web-frontend@e529332` | 现有 Next 16/App Router 仓库原地重构，不创建 v2 仓库 |
| 三个 Web 实例 | Info `29dc4dc`、Knowledge `c99ef6e`、Research `bd2b987` | 与模板约 37~38 个文件且高度同源；Research 仅多 Agent 组件和相应 dashboard 差异；均在现有仓库内改造 |

仓库纪律：模板通用能力只进入两个既有模板仓库；业务能力只进入对应 App；任何迁移先打 Git tag、记录镜像 digest 和回滚步骤；不得再创建 `*-react`、`*-next-v2` 或平行业务仓库。

### V5-DOC-HYGIENE-001 工具无关文档收敛

- 类型/优先级：MAINTAINABILITY/IMMEDIATE；P0-007A2/A2.1 前置卫生任务。
- 仓库：`tpl-app`、`info-app`、`knowledge-app`、`research-app` 及其 15 个含旧引用的子仓。
- 实施：删除根仓和子仓重复且失真的 AI 工具专属文档树及引用；曾用于过渡的根 `docs/README.md` 已在确认不承担权威入口后删除。当前事实以代码/OpenAPI/tests、明确标注的领域文档与 k8s v5 权威文档为准，不再维护易失真的总索引或手写契约副本。
- 保留：Info Spider MVP、Knowledge ingestion worker 和 Knowledge API 早期快照以 Git rename 迁入 `docs/history/`，并明确标记为历史审计资料；其他旧内容保留于 Git 历史，不作为当前恢复入口。
- 验收：四仓普通/隐藏文件及全部子模块搜索旧目录名为零；旧目录不存在；`git diff --check` 通过；未改业务代码、依赖、镜像或集群状态。
- 提交：第一轮收敛为 tpl `9f1adcd`、Info `05cfacb`、Knowledge `9c8b9da`、Research `6080a4e`；过渡索引删除为 tpl `1fd597c`、Info `1c9b1e9`、Knowledge `32878d3`、Research `c155e1a`。子仓与父仓均已按顺序推送。
- 状态：ACCEPTED（2026-07-13；工具专属文档树和过渡索引均已退出当前基线）

### V5-P0-007 React Admin Template Rollup

- 类型/优先级：ARCH/FRONTEND/P0
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-013-frontend-technology-rendering.md`（Accepted）。
- 目标：按 `P0-007A -> P0-007A2(A2.1) -> P0-005 -> P0-007A2(A2.2~A2.5) -> P0-007B -> P0-007C` 完成 React Admin 模板资格链并冻结 React Admin v1；A2.1 不依赖浏览器身份，P0-005 是 A2.2 真实身份接入和 007B 试点的安全前置，父任务不直接写代码。
- 重要边界：`P0-007A` 只代表技术骨架通过，不代表 Vue 模板功能等价，也不允许据此同步三个 App。`P0-007A2` 是新增的完整模板能力对齐门。
- 完成条件：P0-007A、P0-007A2、P0-007B、P0-007C 四个子任务全部 ACCEPTED；任一子任务失败，父任务保持 IN_PROGRESS，禁止向三个 App 应用未冻结模板。
- 状态：IN_PROGRESS（P0-007A、P0-007A2/A2.1、A2.2 与 P0-005 已接受；A2.3/A2.4/A2.5、P0-007B/C 未开始）

### V5-P0-007A tpl-app React Admin 生产骨架

- 类型/优先级：ARCH/FRONTEND/P0；Frontend 轨道第一任务。
- 仓库：`tpl-app`
- 前置：ADR-013；不依赖其他 Phase 0 代码任务。
- 实施：在 canonical React 子仓库 `tpl-admin-frontend` 中建设 React 19、TypeScript strict、React Router Framework Mode route modules/typegen、`ssr: false`、TanStack Query、typed client 接入点、auth/protected layout、i18n、403/404/error、security/test/build/deploy 骨架；Vue 能力基线来自三个 App 的现有源码和历史 commit。
- Vue 对齐：保持菜单、侧栏、面包屑、标签/导航、内容密度、登录跳转、权限路由、表格/表单/Dialog/Drawer、配置名和 Nginx/Docker 接口的可识别对应；采用 React 正常实现，不模拟 Composition API、Pinia 或 Element Plus API。此处只建立骨架接入点，不宣称已覆盖 Vue 模板的全部组件和页面。
- 必需文档：`docs/vue-react-mapping.md`、`docs/add-a-page.md`、`docs/data-flow.md`、`docs/migration-guide.md`；包含文件路径和常用概念对照。
- Reference Page：模板内只提供通用表格、筛选、分页、详情、表单、权限、错误、审计确认示例，使用中性 fixture，不包含 Info/Knowledge/Research 领域代码。
- 不做：不修改三个 App 的 Vue 源码或切换其流量，不引入 Nuxt/Next Admin，不复制 Electron/PWA/演示页等未决 legacy 能力，不先建设共享 UI 平台。
- 测试：typecheck、lint、unit/component、Playwright smoke、可访问性 smoke、route typegen/lazy split、Nginx history fallback、base path、Docker smoke。
- 验收：静态镜像无需 Node runtime 即可运行；熟悉现有 Vue Admin 的人能通过对照文档定位骨架中的路由、页面、状态、API、i18n 和部署配置；三个 App 的 Vue 源码和部署零修改。该验收状态命名为 `SKELETON_ACCEPTED`，不能作为业务迁移资格。
- 证据：模板 commit、依赖锁、命令输出、镜像 digest、页面截图/trace、Vue/React 对照清单。
- 状态：ACCEPTED（2026-07-11；范围为 `SKELETON_ACCEPTED`；证据：`sunmoonai/docs/evidence/v5/V5-P0-007A/result.md`）

### V5-P0-007A2 React Admin 模板完整能力对齐

- 类型/优先级：ARCH/FRONTEND/MAINTAINABILITY/P0；P0-007A 之后、真实业务试点之前。
- 仓库：`tpl-app`；只在发现通用缺口时回改模板，不把业务代码带入模板。
- 前置：P0-007A；从三个现有 App 的 Vue Admin 源码和历史 commit 冻结基线、文件清单及实际差异；`tpl-app` 不再保留独立 Vue 模板子仓库。
- 目标：让 React 模板覆盖仍由模板承担的生产相关能力，而不是只有 Shell、Reference Page 和登录占位。逐项建立 `Vue source -> React target -> behavior/API -> test/evidence -> owner` 映射。
- 必须实现或明确对照：布局/菜单/标签/主题/响应式密度、登录/退出/受保护路由/权限、i18n、typed API/Query 状态、Table/筛选/分页、Form/校验、Dialog/Drawer/Description、通知、Icon、上传/下载、Editor/Media、Chart、UI 持久化、错误/安全边界、CSP/CSRF/CORS/session 接入、Nginx/Docker/K8s 接口和测试工具链。
- 串行施工包：
  1. `A2.1 Shell`：菜单元数据/权限过滤、侧栏/移动 Drawer、面包屑、可关闭标签、主题/密度/语言、route/global error；已以实现提交 `d2fa1a8` 和矩阵提交 `451d22f` 接受，证据见 `sunmoonai/docs/evidence/v5/V5-P0-007A2/A2.1/result.md`。
  2. `A2.2 Identity/Data Foundation`：在 P0-005 ACCEPTED 后接入真实 `/auth/me`、login/logout/return URL、401/403、CSRF/session，统一 typed error/correlation、TanStack Query 约定和 i18n 持久化；不得使用生产 demo auth。
  3. `A2.3 CRUD Toolkit`：Table/筛选/分页/排序/选择、Form/schema/校验、Description、Modal/Drawer、通知、上传/下载和受审计写操作；使用中性 fixture 与 adapter contract。
  4. `A2.4 Rich/Utility Toolkit`：Icon registry、Chart、Editor、Audio/Video、copy/debounce/throttle/drag/long-press/watermark 等 React idiomatic 对应；Electron/PWA 和纯展厅逐项 `REIMPLEMENT/DEFER/REMOVE`。
  5. `A2.5 Production Gate`：CSP/CORS/session 负例、a11y、responsive/reduced-motion、typecheck/lint/unit/component/Playwright、base path、Nginx/Docker/KIND 和 clean-room install；回填能力矩阵与证据。
- 每包完成定义：实现、单元/组件测试、键盘与错误状态、能力矩阵行和提交 SHA 同时齐全；只写代码或只更新矩阵均不得进入下一包。
- Legacy 处置：Electron、PWA、纯演示/组件展厅等必须在矩阵中标记 `KEEP/REIMPLEMENT/DEFER/REMOVE`，写明理由、影响和恢复任务；禁止静默删除。若任一 App 依赖该能力，则不得标记 `DEFER` 后继续迁移。
- 不做：不逐行翻译 Vue API，不把 Element Plus/Pinia/Composition API 机械搬到 React；不把 Info/Knowledge/Research 领域页面、DTO、业务规则写入模板；不接任何 App 流量。
- 测试：模板全量 typecheck/lint/unit/component/Playwright/a11y；组件行为和错误状态矩阵；route/base path/Nginx/Docker smoke；clean-room 从固定 commit 重新生成；Vue/React 映射无未解释项。
- 验收：能力矩阵无未分配的 `MUST` 项；所有 `DEFER` 有批准的 ADR/任务；从干净目录可重复构建；核心组件行为、权限和可访问性通过；状态命名为 `TEMPLATE_MIGRATION_READY`。只有本任务通过后，P0-007B 和三个 App 的 React 基础前端替换才可开始。
- 状态：IN_PROGRESS（A2.1、A2.2 已接受；A2.3 当前施工包，A2.4/A2.5 尚未开始；P0-007A 现有证据不替代本任务）
- A2.3 当前施工已在 `tpl-admin-frontend` 开始：首批 `DataTable`、`SchemaForm`、`ResourceDescription`、`AuditedActionModal`、通知、上传 adapter 和 same-origin 下载工具已实现，并以 Reference Page 中性 fixture 验证。仍需补服务端分页/排序 adapter、受审计写操作 correlation 对账、通知集成和可访问性矩阵；未完成前不得进入 A2.4。

### V5-P0-007B Info Admin 真实业务试点

- 类型/优先级：FRONTEND/CONTRACT/P0
- 仓库：`info-app`、`k8s`；仅在发现通用缺口时回改 `tpl-app`。
- 前置：P0-007A、P0-007A2、P0-003、P0-005 均 ACCEPTED；不得用前端路由守卫替代后端鉴权，也不得以 mock success 验收 B。
- 实施：先为现有 `info-admin-frontend` 创建迁移前 tag 并记录当前镜像 digest，再在该仓库的迁移分支中以 canonical `tpl-admin-frontend` 的 007A/007A2 固定 commit 原地替换基础实现；实现 Artifact/Delivery list/detail，覆盖筛选、分页、状态刷新、受权 retry/re-dispatch、审计原因和 correlation ID。验证使用隔离 Deployment/入口，不创建新的业务仓库。
- 边界：Info 业务代码只在 Info App；模板只接收经复盘证明通用的修正，并记录 backport/cherry-pick 或重新实例化方式。Artifact Contract v1 仅支持 `upsert`，因此 deactivate/delete 不进入本任务；待 Knowledge domain identity 与生命周期契约落地后另行实现。
- 测试：真实 contract/provider、匿名/403/过期 session、hash mismatch、对象缺失、重复操作、并发冲突、XSS/危险 URL、刷新恢复、Nginx/Docker/K8s 隔离 smoke。
- 验收：不依赖 mock ingestion success；Vue/React 可并行部署但仅隔离测试入口访问；React 页面能沿 operation/correlation ID 对账；有明确旧 Vue 回滚路径。
- 证据：模板源 commit -> Info 实例 commit 映射、contract digest、E2E trace、镜像/deployment digest、差异与回流清单。
- 状态：NOT_STARTED

### V5-P0-007C React Admin v1 修正与冻结

- 类型/优先级：ARCH/MAINTAINABILITY/P0
- 仓库：`tpl-app`、`info-app`、`k8s`
- 前置：P0-007A2、P0-007B ACCEPTED。
- 实施：分类试点差异为 template/common、Info-specific、deferred；只回收 common；补齐原地替换清单、版本清单、升级传播机制、compatibility matrix 和三个 App 等价迁移 checklist。
- 冻结产物：`react-admin-template-version`（tag 或 commit SHA）、Node/pnpm/dependency lock、目录契约、环境变量契约、Docker/Nginx/K8s 接口、UI/Data Grid 选型记录、已知限制。
- 停止条件：若模板必须引入 Node SSR/BFF、无法满足 auth/security、或真实页面需要大量绕开框架约定，P0-007 标记 BLOCKED 并重开 ADR-013，不得带病批量复制。
- 验收：从模板干净 checkout 可重复构建并通过全套测试；在三个 App 的临时干净 checkout 中执行 dry-run 替换清单，可得到名称/config 正确且来源可追溯的骨架，不向远端创建新仓库或提前提交业务替换；试点所需通用能力已进入模板且不含 Info 业务；能力矩阵、迁移 checklist 和 legacy 处置记录均已冻结。
- 状态：NOT_STARTED

### V5-P0-008 Next Web Template Re-baseline Rollup

- 类型/优先级：ARCH/FRONTEND/P0
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-014-next-web-template-rebaseline.md`（Proposed）。
- 目标：按 `P0-008A -> P0-008B -> P0-008C` 保留 Next/App Router 技术路线、重建可信 Web v2，并以 Research 真实 streaming 薄切冻结模板；父任务不直接写代码。
- 顺序纪律：Frontend 轨道先完成 P0-007C；ADR-001/004/005 没有可执行输出前不开始 008B；008C 前禁止把 v2 应用到三个 Web 实例。
- 完成条件：三个子任务全部 ACCEPTED；否则现有仓库通过迁移前 tag/镜像回退，P0-008 保持 IN_PROGRESS/BLOCKED。
- 状态：NOT_STARTED

### V5-P0-008A Web 架构契约冻结与紧急卫生

- 类型/优先级：ARCH/SECURITY/FRONTEND/P0
- 仓库：`tpl-app`、`k8s`
- 前置：P0-007C ACCEPTED；P0-001/004/005 已分别给出 stream adapter、Citation DTO、浏览器身份/BFF 的可执行决策证据。
- 实施：接受或重开 ADR-014；固定 Server/Client、server-only DAL/DTO、typed browser client、BFF/直接 API、render/cache、SSE reconciliation、CSP、自托管多副本和发布拓扑；盘点三实例差异。仅执行不依赖未决契约的紧急卫生：停止跟踪 `.env.local`、禁止 secret/default credential、移除硬编码 origin、迁移 Next 16 `middleware.ts -> proxy.ts`、校准 Node/pnpm/.nvmrc/README。
- 外部参考：以 MIT 许可的 `ixartz/Next-js-Boilerplate` 固定参考 commit 和依赖清单作为工程能力输入，逐项提取 App Router 目录约定、严格 TypeScript、环境校验、国际化、错误/加载边界、测试/Storybook/CI 组织和可访问性实践；必须形成“采用/改造/拒绝”矩阵，不得复制其产品页面或整套依赖。
- 兼容性决策：上游当前 README 要求 Node 24+，不因此自动升级 SunmoonAI 基础镜像；ADR-014 必须单独记录 Node/Next/React 支持矩阵、镜像可用性和升级回滚证据。Casdoor OIDC/BFF 替代 Clerk，后端 API/Provider Contract 替代 Drizzle/PGlite/前端数据库，未经批准的 SaaS 集成全部排除。
- Spike：分别证明 protected route 的服务端 session check、public static route、authenticated dynamic route、同源/直连 API 选中拓扑，以及 Runtime adapter 的浏览器断线对账；不得把 Proxy 当最终授权。
- 测试：错误/过期 session、跨 locale return URL、CSRF/CORS/audience、cache 泄露、CSP、同一用户跨 Pod、滚动版本、stream cursor/reconcile。
- 验收：ADR-014 Accepted；一张当前/目标拓扑、route rendering matrix、cache owner matrix、BFF allowlist、环境变量和部署兼容矩阵获批；所有未决项都有 owner/阻断任务，不以“模板以后处理”放行。
- 状态：NOT_STARTED

### V5-P0-008B tpl-app Next Web v2 生产骨架

- 类型/优先级：ARCH/FRONTEND/P0
- 仓库：`tpl-app`
- 前置：P0-008A ACCEPTED。
- 实施：在现有 `tpl-web-frontend` 仓库的迁移分支内重构并冻结 Next Web v2；保留 React 19、Next 16 App Router、next-intl、Tailwind/shadcn/Base UI 候选和 `standalone` 自托管；实现 ADR-014 冻结的 Server/Client、DAL/DTO、typed client、auth/BFF、render/cache、stream adapter、错误/correlation、观测、安全、测试和 Docker/KIND 骨架，不创建新的 Web 模板仓库。
- 能力吸收边界：参考 ixartz 的工程化组织而非其 SaaS 业务；新增 strict env schema、server-only DAL、Casdoor session、统一 API/error/correlation、route metadata、loading/error/not-found、a11y、Playwright/Vitest、Storybook（若 ADR-014 认为有价值）和可重复 CI。前端不拥有数据库，不引入 Clerk/Drizzle/PGlite/第三方遥测或外部字体/CDN 作为运行时依赖。
- 串行施工包：`B1 Repo/Env/Rendering` -> `B2 Auth/DAL/DTO` -> `B3 UI/Query/Stream` -> `B4 Security/Test/Deploy`；每包在现有仓库提交并可回滚，不复制目录形成 v2 副本。
- Reference surfaces：只提供中性 public content、authenticated workspace、stream timeline/HITL、citation/error 状态示例；fixture 只验证组件，不得伪装成真实 Run/Retrieval 成功。
- 不做：不做无 tag/digest 的不可回滚覆盖、不改三个 App 流量、不把 Run/Artifact/Retrieval 领域状态放入 BFF/Zustand、不预建跨 App 共享 UI 平台、不用 nonce CSP 无条件强制全部 route dynamic。
- 测试：typecheck、lint、unit/component、Playwright/a11y、route rendering/cache assertions、auth/CSRF/CSP、stream reconnect/reconcile、多标签、Docker/KIND、非 root/probes、两个 Pod 滚动版本与 cache/version-skew smoke。
- 验收：从干净目录可重复构建；public 与 authenticated route 的渲染/cache 证据符合矩阵；最终镜像和 K8s 接口可追溯；迁移前 tag/镜像可恢复，三个 Web 实例未被提前修改。
- 状态：NOT_STARTED

### V5-P0-008C Research Web 真实试点与 Next v2 冻结

- 类型/优先级：FUNC/RELIABILITY/FRONTEND/P0
- 仓库：`tpl-app`、`research-app`、`knowledge-app`、`k8s`
- 前置：P0-008B ACCEPTED；P0-001 选中 Runtime 有隔离可运行 endpoint，P0-004/005 有可执行 Provider/身份；不要求生产流量，但禁止 fake SSE、fake citation、mock Run success。
- 实施：从固定 v2 commit 实例化 Research 隔离入口；跑通真实 session/run、SSE cursor/reconnect、snapshot reconciliation、cancel/resume、HITL、citation 与受权来源跳转；把差异分类为 template/common、Research-specific、deferred，只回收 common。
- 故障测试：刷新/断网/重复事件/事件缺口/陈旧 terminal、多标签、Runtime/Next Pod 重启、滚动版本、过期 approval、跨用户 URL、Citation 404/403、浏览器取消与后端竞态。
- 冻结产物：`next-web-template-version`、依赖锁、route/render/cache/BFF/env/deploy 契约、三 Web migration checklist、旧模板回滚和 compatibility matrix。
- 验收：真实试点可从稳定 URL 恢复且最终与服务端 Projection 收敛；浏览器不读原始 LangGraph/Provider 类型；两个 Pod/滚动版本无静默状态丢失；v2 固定 commit 可干净重建并按迁移清单应用，且模板不含 Research 领域代码。
- 状态：NOT_STARTED

### Gate P0

全部条件满足才进入 M1 主链重构：

- ADR-001~006、ADR-013/014 Accepted。
- Artifact/Retrieval consumer-provider contract tests 通过。
- 身份模型可实施且不依赖匿名 API。
- Runtime 分支由 ADR-001 明确激活；其他分支停止。
- Runtime Spike 的 SSE/cancel/worker-kill 与可靠交付 Spike 的副作用恢复证据通过。
- 最小浏览器 harness 证明 stream 断线后能通过 cursor/Projection 收敛；Citation DTO 与浏览器身份边界进入 ADR-004/005 验收证据。
- P0-007A/A2/B/C 全部 ACCEPTED；React Admin v1、完整模板能力矩阵、真实 Info 薄切和固定 commit 干净重建/dry-run 原地替换证据通过；Vue 回滚由各 App 的迁移前 tag/镜像提供。
- P0-008A/B/C 全部 ACCEPTED；现有 Next Web 仓库内的 v2、真实 Research streaming/HITL/citation 薄切、多副本自托管和固定 commit 干净重建/迁移证据通过；旧实现由迁移前 tag/镜像提供回退。
- v5 架构按 Spike 结果更新并标记 Baseline Accepted。

### 2.2 关键路径、工作流与串行执行纪律

下图只表达依赖，不授权并行施工。本轮由单一执行者推进：任何时刻最多一个代码任务处于 `IN_PROGRESS`；当前任务完成测试、证据、状态回填和提交后，才激活下一任务。R1~R6 只是责任域/证据归档分类。

```text
V5-IMM-001（立即、独立）

P0-001 Runtime ADR ──> P0-002 Execution Identity ──> Runtime branch activated
        |                         |
        |                         +-------------------------------+
        v                                                         |
P0-003 Artifact ──> Info/Knowledge internal path                  |
P0-004 Retrieval + contract CI ──> Knowledge/Research path       |
P0-007A2/A2.1 ──> P0-005 Identity ──> P0-007A2/A2.2~A2.5 ──> P0-007B |
P0-006 Delivery ADR ──> Reliability track                        |
P0-007A ────────────────────────────────────────> P0-007C ──> Frontend track |
P0-001/004/005 + P0-007C ──> P0-008 Next Web v2 ──> Web track   |
        +-------------------------+-------------------------------+
                                  v
                         M1a Internal Vertical Slice
                                  v
                       M1a.5 Memory/Subagent Validation
                                  v
                 Security Track + Reliability Track converge
                                  v
                             Gate M1b Canary
                                  v
                         M1c Limited Production
```

工作流分类：

- R1 Runtime/Research：P0-001/002，之后 Runtime Common 和选中分支。
- R2 Info/Artifact：P0-003，随后 Info immutable artifact/delivery。
- R3 Knowledge/Contract：P0-004，随后 Knowledge domain/retrieval。
- R4 Security/K8s：IMM-001、P0-005，随后 auth/network/secret/migration。
- R5 Reliability/Evaluation：P0-006，随后 dispatcher/failure/E2E/evaluation。
- R6 Frontend/Experience：严格按 P0-007A -> A2.1 -> P0-005 -> A2.2 -> A2.3 -> A2.4 -> A2.5 -> P0-007B -> P0-007C；再等待 P0-001/004 决策输出，按 P0-008A -> P0-008B(B1~B4) -> P0-008C 在现有 Web 仓库内重基线 Next Web。P0-007A2 通过才具备模板迁移资格；P0-007C/008C 分别使两个模板具备推广资格。Gate P0 后按 Info -> Knowledge -> Research 串行执行 411A/411B/411C/411D 和 413 的原地迁移/回滚验证；两个模板资格链完成后进入 M1-400~413 与跨仓浏览器 E2E。

粗粒度工作量用于容量规划，不是承诺日期：原七项约 14~22 人周；新增 P0-008A/B/C 约 5~9 人周（A 1~2、B 2~3、C 2~4），完整 Phase 0 调整为约 19~31 人周。P0-007A/A2/B/C 重新估算约 10~18 人周（A 已完成；A2 4~8、B 3~5、C 1~2），三个 App 的 411A 原地替换另计约 1~2 人周，411B/C/D 业务等价迁移另计约 8~16 人周，三个 Web 实例 413 原地迁移另计约 3~6 人周。Frontend 内部按用户要求串行，因此不得再以“多人并行”承诺 2~3 个日历周；核心 ADR Spike 可保持各自 2~3 周时间盒，完整 Gate 以证据完成为准。M1a 因 Research Web 薄切前移到 P0-008C，重估为约 18~30 人周；M1a.5 约 4~7 人周；M1b 约 23~40 人周；M1c canary 观察至少 1~2 个自然周。每次 Gate 后重估，禁止把区间当固定 deadline。

### 2.3 交付里程碑定义

- M1a Internal Vertical Slice：可重复内部 demo；无公网、无生产数据、test identity/test dataset；不代表可接用户。
- M1a.5 Architecture Validation：用真实 Runner/LLM 验证 Memory 和 Subagent，二次冻结相关边界。
- M1b Controlled Canary：安全与可靠性门禁全绿，允许极小真实流量。
- M1c Limited Production：canary 指标和恢复演练通过，允许受限生产使用。

里程碑最小任务包：

| 里程碑 | 必需任务/输出 |
|---|---|
| M1a | Gate P0；P0-003/004 的可运行最小 Provider；M1-201/205；M1-301/304~308 的最小 Common + 选中 Runtime adapter；M1-400~405/411 的最小面；M1-600 |
| M1a.5 | M1-701/702 与 ADR-002/009/010 二次冻结 |
| M1b | 全部 M1 P0 任务；M1-601~604；migration/rollback/recovery；安全与可靠性轨道汇合 |
| M1c | M1-605 与 canary 观察/停流演练 |

M1a 允许 P0 契约原型继续作为隔离环境 Provider，但 M1b 前必须由正式 M1 实现替换并通过完整契约、迁移和故障测试。

## 3. 安全与配置工作流（M1b 前完成）

### V5-M1-001 三套 API 路由分区与鉴权

- 类型/优先级：SECURITY/P0
- 仓库：`info-app`、`knowledge-app`、`research-app`
- 实施：`/user`、`/admin`、`/internal` 或等价 Router；统一 AuthContext dependency；资源级授权。
- 测试：每个写接口和敏感读接口至少包含 allow/deny 用例。
- 验收：匿名只访问 login/callback/health/docs（生产 docs 可关闭）。
- 状态：NOT_STARTED

### V5-M1-002 服务身份与 scopes

- 类型/优先级：SECURITY/P0
- 仓库：四仓
- 实施：Info ingestion、Research retrieval 使用不同 credential/audience/scope；轮换机制；禁止共享 admin token。
- 验收：撤销 Info credential 不影响 Research retrieval；反向亦然。
- 状态：NOT_STARTED

### V5-M1-003 Secret 治理

- 类型/优先级：SECURITY/P0
- 仓库：`k8s`
- 实施：盘点 Git 历史明文；轮换；引入选定 Secret 管理；generated Secret 进入 ignore/加密流程；secret scan CI。
- 验收：仓库扫描无有效凭据；Pod 仅获得所需 Secret。
- 状态：NOT_STARTED

### V5-M1-004 配置真相与流量开关

- 类型/优先级：RELIABILITY/P0
- 仓库：`k8s`
- 实施：修复 Git/集群 flag 漂移；环境 overlay；v5 独立 traffic mode；部署前 diff。
- 验收：重新生成/部署不会意外开启 Agent；drift check 可阻断 CI。
- 状态：NOT_STARTED

### V5-M1-005 最小 NetworkPolicy 与容器安全

- 类型/优先级：SECURITY/P1
- 仓库：`k8s`
- 实施：namespace default-deny 或应用选择器 deny；只开放真实调用；worker non-root/drop capabilities/seccomp。
- 测试：允许路径连通，越权路径不可达，Pod 正常启动。
- 状态：NOT_STARTED

## 4. Info 可靠文档版本与交付工作流

### V5-M1-101 canonical identity 与并发

- 类型/优先级：RELIABILITY/P1
- 仓库：`info-app`
- 实施：URL normalization policy；canonical identity 唯一约束；upsert/lock；version_no 并发安全。
- 测试：并发抓取相同 URL、重定向、tracking query、相同内容。
- 验收：一个逻辑文档、版本号严格唯一。
- 状态：NOT_STARTED

### V5-M1-102 抓取 SSRF 和资源限制

- 类型/优先级：SECURITY/P0
- 仓库：`info-app`
- 实施：协议/端口/地址检查、DNS rebinding 防护、redirect 重检、流式大小限制、来源并发和 timeout。
- 测试：loopback、link-local、metadata IP、私网、超大响应、重定向攻击。
- 状态：NOT_STARTED

### V5-M1-103 Artifact 不可变与完整性

- 类型/优先级：RELIABILITY/P1
- 仓库：`info-app`
- 实施：object key/version/hash；staging/committed 状态；孤儿对象 reconciler 最小实现。
- 验收：数据库失败不会留下永久不可追踪对象；Knowledge 可校验。
- 状态：NOT_STARTED

### V5-M1-104 Knowledge Delivery Record v2

- 类型/优先级：RELIABILITY/P0
- 仓库：`info-app`
- 实施：contract_version、稳定幂等唯一键、attempt_count、next_retry_at、correlation、目标响应 ID；合法状态转换。
- 验收：同一 Version/Dataset 重复创建返回同一逻辑交付。
- 状态：NOT_STARTED

### V5-M1-105 最小可靠 dispatcher

- 类型/优先级：RELIABILITY/P0
- 仓库：`info-app`
- 实施：事务 outbox 或 pending scanner（二选一由 ADR）；`FOR UPDATE SKIP LOCKED`/lease；指数退避；stuck record reconciliation。
- 故障测试：DB 成功/RabbitMQ 失败、重复 delivery、worker kill。
- 状态：NOT_STARTED

## 5. Knowledge 领域与检索工作流

### V5-M1-201 Knowledge 领域 schema

- 类型/优先级：FUNC/P0
- 仓库：`knowledge-app`
- 实施：KnowledgeDocument、KnowledgeVersion、DatasetBinding、ProviderBinding；迁移和 backfill 当前 job。
- 验收：内部 stable ID 与 RAGFlow ID 分离；source lineage 唯一。
- 状态：NOT_STARTED

### V5-M1-202 Ingestion 状态机与外部幂等

- 类型/优先级：RELIABILITY/P0
- 仓库：`knowledge-app`
- 实施：resolve/verified/uploaded/parsing/ready/failed；保存 provider ID 后再 poll；重复 job 续跑。
- 验收：parse timeout retry 不产生 `(2)` 重复文档。
- 状态：NOT_STARTED

### V5-M1-203 非阻塞 parse polling

- 类型/优先级：RELIABILITY/P1
- 仓库：`knowledge-app`
- 实施：每个 poll task 只查询一次，未完成用 countdown 重投；deadline/backoff；减少 INFO SQL/HTTP 日志。
- 验收：长 parse 不持续占用 worker slot。
- 状态：NOT_STARTED

### V5-M1-204 Dataset allowlist

- 类型/优先级：SECURITY/P1
- 仓库：`knowledge-app`
- 实施：静态配置的 `dataset_key -> dataset_id/policy`；数据面禁止任意创建。
- 说明：完整 Dataset Registry UI 延后 M2/M3。
- 状态：NOT_STARTED

### V5-M1-205 Retrieval API

- 类型/优先级：FUNC/P0
- 仓库：`knowledge-app`
- 实施：按 P0-004 契约实现 query/filter/top_k/token budget；标准 Evidence；服务授权。
- 测试：unit、RAGFlow integration、contract、timeout/degraded。
- 验收：不泄漏无权限 dataset；引用 lineage 完整。
- 状态：NOT_STARTED

### V5-M1-206 deactivate/delete/reindex 最小 API

- 类型/优先级：FUNC/P1
- 仓库：`knowledge-app`、`info-app`
- 实施：source version 状态传播；Provider binding 清理或失效；Retrieval 不返回失效版本。
- 状态：NOT_STARTED

## 6. Research Runtime 工作流（受 ADR-001 控制）

本节不是默认自建清单。任务适用性如下：

```text
Runtime Common：M1-301、303、305~309、312（实现形态按选型适配）
Custom only：M1-302、310、311
Agent Server only：M1-313
Hybrid only：M1-314
```

ADR-001 获批后，在任务跟踪中把未选分支标记为 `NOT_APPLICABLE` 并记录 ADR 引用。Common 任务不得重复实现选定 Runtime 已可靠提供的能力，只负责产品领域和 ACL 适配。

### V5-M1-301 新执行 schema

- 类型/优先级：FUNC/P0
- 仓库：`research-app`
- 适用：Runtime Common。
- 实施：按 ADR-002 建产品 Session/Run/AgentInvocation/ToolExecution；Thread/RunAttempt 是本地实体还是远程映射由 ADR-001 决定；保留 Phase 0 数据或迁移标记。
- 验收：输入快照、effective config、owner、lease、deadline、usage 可查询。
- 状态：NOT_STARTED

### V5-M1-302 Run 创建、投递与幂等

- 类型/优先级：RELIABILITY/P0
- 仓库：`research-app`
- 适用：Custom only；Agent Server/Hybrid 使用对应分支的 durable run API，不重复建 dispatcher。
- 实施：持久化完整 user_input；新建/已存在明确返回；只为新 Run 产生 delivery；可靠 dispatcher。
- 测试：并发同 idempotency key、broker 故障、重复 delivery。
- 状态：NOT_STARTED

### V5-M1-303 Resume/Cancel 原子命令

- 类型/优先级：RELIABILITY/P0
- 仓库：`research-app`
- 适用：Runtime Common；原子性落在本地命令表还是远程 Run API 由 ADR-001 决定。
- 实施：resume token hash/expiry/single-use；idempotency；条件状态更新；Cancel 持久化。
- 测试：双击 resume、旧 token、跨用户、resume/cancel 竞态。
- 状态：NOT_STARTED

### V5-M1-304 Production Graph Resolver/Runner

- 类型/优先级：FUNC/P0
- 仓库：`research-app`
- 适用：Runtime Common 的 graph resolution；本地 GraphExecutor 仅 Custom，远程 adapter 由 M1-313/314 实现。
- 实施：Walking Skeleton 保留为测试 graph；根据 EffectiveRunConfig 解析 graph，并委托选定 Runtime。
- 验收：生产任务不 import 固定 walking skeleton builder。
- 状态：NOT_STARTED

### V5-M1-305 LangGraph State 与 Reducer

- 类型/优先级：FUNC/P0
- 仓库：`research-app`
- 实施：使用官方 message/reducer 或显式 Annotated channel；plan/artifact/tool result 合并策略。
- 测试：重复 update、乱序 version、checkpoint replay、结合律。
- 状态：NOT_STARTED

### V5-M1-306 真实 ModelPort 与 Prompt

- 类型/优先级：FUNC/P0
- 仓库：`research-app`、`k8s`
- 实施：单 Provider 可用；结构化 tool calls；timeout、usage、model/prompt version；录制回放 adapter。
- 验收：非 fake 模型完成 golden text/tool tasks；Secret 不进入 state/event。
- 状态：NOT_STARTED

### V5-M1-307 KnowledgePort 与 Citation

- 类型/优先级：FUNC/P0
- 仓库：`research-app`
- 实施：调用 Retrieval API；Evidence context assembler；citation validation；无证据降级。
- 验收：回答 citation 可回溯 InfoDocumentVersion；不存在伪造 evidence_id。
- 状态：NOT_STARTED

### V5-M1-308 最小 Tool/Sandbox

- 类型/优先级：FUNC/SECURITY/P1
- 仓库：`research-app`、`k8s`
- 实施：至少一个只读工具和一个受控副作用工具；SandboxPort 真实实现；权限、timeout、artifact。
- 验收：副作用恢复测试通过；越权命令/路径/网络被拒绝。
- 状态：NOT_STARTED

### V5-M1-309 Run Journal 与 Projection

- 类型/优先级：RELIABILITY/P0
- 仓库：`research-app`
- 实施：明确持久事实；状态+事件同事务；安全 cursor；Projector 可重建；Redis 仅 live。
- 验收：中途投影失败后可重建相同 UI 时间线。
- 状态：NOT_STARTED

### V5-M1-310 SSE/Streaming v2

- 类型/优先级：FUNC/RELIABILITY/P0
- 仓库：`research-app`
- 适用：Custom only；其他分支使用远程 stream adapter，并在 M1-313/314 验证相同产品 cursor 语义。
- 实施：采用 ADR-001 Runtime Spike 的 streaming/SSE 证据；cursor header/query 兼容；heartbeat；backpressure；final reconciliation。
- 状态：NOT_STARTED

### V5-M1-311 Lease、reconciler 与 worker shutdown

- 类型/优先级：RELIABILITY/P0
- 仓库：`research-app`、`k8s`
- 适用：Custom only；Agent Server/Hybrid 验证其 lease/queue/drain 能力，不重复实现。
- 实施：attempt lease/heartbeat；stuck Run 扫描；lock contention 延迟；SIGTERM drain。
- 故障测试：worker kill、Pod eviction、RabbitMQ redelivery。
- 状态：NOT_STARTED

### V5-M1-312 Budget、timeout、error taxonomy

- 类型/优先级：FUNC/P1
- 仓库：`research-app`
- 实施：step/tool/LLM/token/cost/time；deadline propagation；用户可理解错误和内部 cause 分离。
- 状态：NOT_STARTED

### V5-M1-313 Agent Server 执行适配

- 类型/优先级：FUNC/RELIABILITY/P0
- 适用：Agent Server only。
- 仓库：`research-app`、`k8s`
- 实施：产品 Session/Run 与 assistant/thread/run 映射；auth、remote stream、cancel、Store/checkpoint、版本和产品事件投影。
- 测试：远程 worker kill、同 Thread 并发、stream reconnect、cancel、升级恢复。
- 状态：NOT_STARTED

### V5-M1-314 Hybrid 控制面/执行面适配

- 类型/优先级：FUNC/RELIABILITY/P0
- 适用：Hybrid only。
- 仓库：`research-app`、`k8s`
- 实施：远程执行 contract、delegated identity、EffectiveRunConfig/version mapping、stream/event reconciliation、故障归属。
- 测试：控制面和执行面分别重启、网络分区、重复 remote create。
- 状态：NOT_STARTED

## 7. 前端架构与产品体验工作流

本工作流覆盖六个现有 Frontend，而不是只覆盖 Research Web。M1 的关键产品面是 Research Web、Info Admin 和 Knowledge Admin；Research Admin 在 M1b 前补齐运行治理最小面；Info Web/Knowledge Web 保持领域门户边界，不承载内部控制面。前端不得直接调用跨仓内部 API、RAGFlow、Redis、对象存储长期凭据或 Agent Server 管理 API。

### V5-M1-400 前端架构基线与现状盘点

- 类型/优先级：ARCH/FUNC/P0
- 仓库：`info-app`、`knowledge-app`、`research-app`、`k8s`
- 前置：P0-007C、P0-008C；ADR-013/014。
- 实施：消费两个模板资格链的证据，记录六个实例相对固定模板版本的用户、路由、部署、认证、API/BFF、状态管理、测试和 owner；冻结跨 App deep-link 与实例迁移顺序；记录 Vue legacy -> React Admin 和旧 Next -> Next v2 的 route/feature/evidence 映射，不重复进行 P0 已完成的模板现状审计。
- ADR 输入：ADR-005 浏览器身份、ADR-007 UIProjection、ADR-001 stream adapter、ADR-013/014 技术与模板边界；不另造重复契约。
- 测试：从每个已部署入口验证路由、登录跳转、API audience/CORS；检查浏览器无法直连内部服务。
- 验收：形成一张当前/目标拓扑和 gap 清单；每个界面能力有唯一 owner；Info Web/Knowledge Web 不被误用为治理控制面。
- 状态：NOT_STARTED

### V5-M1-401 前端契约客户端

- 类型/优先级：FUNC/P0
- 仓库：三个 App 的 Web/Admin Frontend
- 实施：从各 App 产品/管理 OpenAPI 生成或校验 typed client；Research 覆盖 Session/Run/resume/approve/cancel/events/artifact，Info 覆盖 DocumentVersion/Artifact/delivery，Knowledge 覆盖 ingestion/retrieval/citation diagnostics。
- 约束：生成 DTO 不手改；页面不得导入数据库/RAGFlow/LangGraph 类型；统一错误模型包含 `code/message_key/retryable/correlation_id/field_errors`。
- 测试：schema breaking check、client compile、错误兼容 fixture、服务端新增可选字段。
- 验收：四仓 CI 中 Provider/Consumer 版本矩阵可执行；页面无散落重复 DTO。
- 状态：NOT_STARTED

### V5-M1-402 Research Web Agent 工作台

- 类型/优先级：FUNC/P0（M1a 最小工作台；增强体验可按 P1 分期）
- 仓库：`research-app/research-web-frontend`
- 前置：P0-008C；必须从固定 Next v2 commit 和 Research 真实试点演进，不重新创建第三套 workspace/stream client。
- 实施：Session history、消息、plan/step、tool approval/input、artifact、citation、cancel/retry、错误恢复；URL 可恢复稳定 Session/Run。
- 状态机：idle/submitting/queued/running/waiting/reconnecting/reconciling/completed/failed/cancelled；以服务端 Projection 为真相。
- 安全：Markdown/Citation/URL sanitizer；下载/预览走受权短期 URL 或代理；权限拒绝和过期 approval 明确展示。
- 说明：旧 Phase 0 Console 只保留在 dev route；P0-008C 的 v2 真实薄切直接演进为本任务最小产品面，模板中性示例不作为最终产品页面。
- 测试：刷新、返回、重复提交、陈旧 token、跨用户 URL、长内容、无证据和部分失败。
- 验收：不读原始 LangGraph event；不依赖内存 store 保持 Run 正确性；citation 可导航到受权来源摘要。
- 状态：NOT_STARTED

### V5-M1-403 SSE 客户端恢复

- 类型/优先级：RELIABILITY/P0
- 仓库：`research-app/research-web-frontend`
- 前置：P0-008C；复用已冻结 stream adapter/cursor/reconciliation contract，本任务补齐 M1 产品规模和观测，不另造客户端协议。
- 实施：cursor 持久化、指数退避+jitter、去重、final delta reconcile；选择并实现单 active stream 协调或多连接去重策略。
- 测试：浏览器断网、刷新、后台恢复、重复 named event。
- 验收：LiveDelta 丢失后仍由持久 Projection 收敛；陈旧事件不能覆盖 completed/cancelled 终态；无无限重连风暴。
- 状态：NOT_STARTED

### V5-M1-404 Info Admin Artifact/Delivery 治理面

- 类型/优先级：FUNC/P0（M1a 最小只读链路，M1b 补齐受权动作）
- 仓库：`info-app/info-admin-frontend`
- 实施：从 Source/Crawl 定位 DocumentVersion、审核、Artifact hash/size/content-type、Knowledge delivery operation、attempt 和失败分类；提供受权 retry/deactivate 并要求操作原因。
- 测试：hash mismatch、对象缺失、重复交付、权限拒绝、并发审核冲突、失败重试。
- 验收：M1a E2E 的真实 Artifact/交付状态可在页面追踪；写动作产生审计事件，页面不直接改状态字段。
- 状态：NOT_STARTED

### V5-M1-405 Knowledge Admin Ingestion/Retrieval 治理面

- 类型/优先级：FUNC/P0（M1a 最小诊断链路，M1b 补齐受权动作）
- 仓库：`knowledge-app/knowledge-admin-frontend`
- 实施：Dataset/Provider binding、KnowledgeVersion、parse/index 状态、source lineage、失败重试；提供使用受限测试身份的 Retrieval/Citation 诊断。
- 测试：未知 dataset、Provider timeout、空结果、权限拒绝、旧版本 citation、重试竞争。
- 验收：能由 InfoDocumentVersion 定位 KnowledgeVersion/Provider binding，并由 evidence_id 回溯；不在浏览器暴露 Provider 管理凭据。
- 状态：NOT_STARTED

### V5-M1-406 Research Admin Runtime/Evaluation 治理面

- 类型/优先级：FUNC/SECURITY/P1（M1b 前完成最小面）
- 仓库：`research-app/research-admin-frontend`
- 实施：Run/Attempt/Invocation/ToolExecution lineage、EffectiveRunConfig 版本、预算、失败分类、correlation ID、evaluation 结果、traffic mode 只读状态和受权人工处置。
- 约束：M1 不建设低代码 Agent Builder；版本发布和停流动作走受审计 Command API，不通过 ConfigMap 任意编辑表单实现。
- 测试：角色/范围、旧版本 waiting Run、attempt 重试、越权处置、停流确认。
- 验收：值班人员无需查数据库即可解释一次失败并定位 runbook；普通 Web 用户不可访问。
- 状态：NOT_STARTED

### V5-M1-407 浏览器身份与前端安全

- 类型/优先级：SECURITY/P0
- 仓库：三个 App 的 Web/Admin Frontend、后端、`k8s`
- 前置：ADR-005。
- 实施：落实 OIDC/session、cookie/token、CSRF、CSP、CORS、audience、logout/revocation；Web/Admin 权限面分离；Artifact/Citation/Markdown 下载与渲染策略。
- 测试：匿名、跨用户深链、错误 audience、CSRF、XSS/Markdown、危险 URL、过期 session、权限在 SSE 期间撤销。
- 验收：路由守卫不作为授权证明；token 不进入不受控持久存储/日志；浏览器不能调用 internal API。
- 状态：NOT_STARTED

### V5-M1-408 可访问性、国际化与完整状态

- 类型/优先级：QUALITY/P1（M1b 关键流程门禁）
- 仓库：M1 涉及的四个 Frontend
- 实施：loading/empty/partial/waiting/denied/retryable/terminal/cancelled；键盘、焦点、ARIA live、对比度、reduced-motion；稳定错误 code 映射中英文 message key。
- 测试：axe 或等价自动检查 + 键盘/读屏人工走查；中英文长文本与时区。
- 验收：关键流程无严重可访问性问题；切换语言不改变错误判定逻辑。
- 状态：NOT_STARTED

### V5-M1-409 前端性能与可观测性

- 类型/优先级：OBSERVABILITY/P1
- 仓库：三个 App Frontend、观测基础设施
- 实施：Web Vitals、route/operation latency、SSE reconnect/reconcile、错误 code/correlation ID；长时间线分页/虚拟化、delta 合批、后台降频。
- 隐私：不上报 prompt/evidence/memory 正文、token、signed URL。
- 验收：可由浏览器错误关联服务端 trace；长 Run 不导致无界内存/DOM 增长。
- 状态：NOT_STARTED

### V5-M1-410 前端测试金字塔与浏览器 E2E

- 类型/优先级：QUALITY/RELIABILITY/P0
- 仓库：四仓 CI
- 实施：状态机/错误映射/sanitizer 单元测试；关键组件测试；typed client contract；Playwright/Cypress 浏览器 E2E。
- E2E：登录 -> Info Artifact/交付 -> Knowledge ingestion/diagnostic -> Research 创建/stream/HITL/refresh/cancel/citation -> Admin lineage；包含断网、多标签、重复动作和权限拒绝。
- 验收：M1a 跑内部真实竖线浏览器子集；M1b 跑完整安全/恢复子集并保存截图、trace、video 或等价证据；后端脚本不能替代本任务。
- 状态：NOT_STARTED

### V5-M1-411 三个 React Admin 等价迁移 Rollup

- 类型/优先级：FRONTEND/FUNC/P0
- 目标：按 `411A -> 411B Info -> 411C Knowledge -> 411D Research` 串行推进；父任务只汇总迁移状态和共同风险。
- 前置：Gate P0、P0-007A2/007C 已通过；411A 只能按冻结 commit 和替换清单做基础前端原地替换，不能绕过后端契约、安全和模板能力门。
- M1a 要求：411A、411B、411C 的 M1a 最小面 ACCEPTED。
- M1b 要求：411B/C/D 完整约定范围 ACCEPTED，逐 App 切换/回滚证据通过。
- 状态：NOT_STARTED

### V5-M1-411A 固定模板替换三个 App 基础前端

- 类型/优先级：FRONTEND/MAINTAINABILITY/P0
- 仓库：`info-app`、`knowledge-app`、`research-app`、`k8s`
- 前置：Gate P0、P0-007C ACCEPTED；只允许使用包含 P0-007A2 能力矩阵的冻结 React Admin v1 标识，禁止复制工作目录未提交状态；三个 App 在现有前端目录内原地替换，不创建新仓库。
- 实施：在每个 App 的迁移分支中，以固定 React Admin v1 替换现有 Vue Admin 基础实现；替换 app name、API base、OIDC audience、locale、镜像/Deployment 名称；保留同版本目录契约、测试和部署接口，并在替换前创建 Git tag、镜像 digest 和回滚记录。
- 传播机制：记录 template version、实例 commit、允许定制点、升级步骤和漂移检查；不得把三个 App 变成互相复制的模板来源。
- 测试：三个实例分别 install/typecheck/lint/unit/build、Nginx fallback、Docker import/smoke、配置负例；验证无 Info 试点业务泄漏到 Knowledge/Research。
- 验收：三个骨架来源可追踪且替换步骤可在临时干净 checkout 重放；尚未开放生产路由；迁移前 tag/镜像均可恢复。
- 状态：NOT_STARTED

### V5-M1-411B Info Admin React 等价迁移

- 类型/优先级：FRONTEND/FUNC/P0
- 仓库：`info-app`、`k8s`
- 前置：411A；复用 P0-007B 试点，不重新实现同一页面；必须消费 P0-007A2 的通用能力映射。
- 实施：把试点提升到固定模板 v1；迁移现有真实 Info 页面以及 M1-404 Artifact/Delivery 治理范围；建立 Vue route -> React route -> API/contract -> E2E 的逐项映射。
- 验收：功能、安全、可访问性、性能、浏览器 E2E 和部署等价；隔离流量切换与回滚演练通过。M1a 可只接受 Artifact/Delivery 最小面，M1b 前完成双方约定的全部保留页面。
- 状态：NOT_STARTED

### V5-M1-411C Knowledge Admin React 等价迁移

- 类型/优先级：FRONTEND/FUNC/P0
- 仓库：`knowledge-app`、`k8s`
- 前置：411A；P0-004 contract 可消费；必须消费 P0-007A2 的通用能力映射。
- 实施：迁移保留页面并实现 M1-405 Dataset/Provider binding、Ingestion、Retrieval/Citation 诊断最小面；不把 RAGFlow credential/provider SDK 暴露浏览器。
- 验收：逐 route/contract/E2E 等价；M1a 最小诊断链通过真实 Provider，M1b 前完成约定保留范围和切换/回滚演练。
- 状态：NOT_STARTED

### V5-M1-411D Research Admin React 等价迁移

- 类型/优先级：FRONTEND/SECURITY/P0（M1b 前完成）
- 仓库：`research-app`、`k8s`
- 前置：411A；ADR-001 Runtime 分支和 M1-406 管理 API 范围已明确；必须消费 P0-007A2 的通用能力映射。
- 实施：迁移保留页面并实现 Run/Attempt/Invocation/ToolExecution lineage、EffectiveRunConfig、evaluation、traffic mode 只读状态和受审计人工处置。
- 验收：普通 Web 用户不可进入；旧 waiting Run/attempt/越权/停流场景通过；逐 route/contract/E2E 等价及切换/回滚演练通过。
- 状态：NOT_STARTED

迁移共同纪律：Vue 只修严重缺陷；同一 v5 新功能不在 Vue/React 双写；每个 App 独立 canary/切换/回滚，不做三个 Admin 同时替换；迁移前用 Git tag 和镜像 digest 保留回滚基线，但不再作为默认生产实现。

### V5-M1-412 Vue Admin 退出与模板收敛

- 类型/优先级：MAINTAINABILITY/P1（M1b 后、三个实例稳定后执行）
- 仓库：`tpl-app`、三个 App、`k8s`
- 实施：React 版本提升为默认 `tpl-admin-frontend`；Vue 模板/实例归档为 tag 或历史分支；移除 Vue 构建矩阵、Electron/PWA 等未被明确采用的 legacy 能力和双栈文档。
- 验收：三个实例均已越过约定观察窗且无回滚需求；模板只存在一个默认 Admin 技术栈；历史版本仍可审计但不接收功能开发。
- 状态：NOT_STARTED

### V5-M1-413 三个 Next Web 原地迁移 Rollup

- 类型/优先级：FRONTEND/FUNC/MAINTAINABILITY/P0（M1b 前完成）
- 仓库：`tpl-app`、`info-app`、`knowledge-app`、`research-app`、`k8s`
- 前置：Gate P0、P0-008C ACCEPTED；使用冻结的 `next-web-template-version`，不得从任一业务 App 反向复制形成模板。
- 目标：按 `413A Info -> 413B Knowledge -> 413C Research` 串行把 Next Web v2 的通用基础应用到三个现有 Web 仓库；不创建新仓库，不一次覆盖三个 App，不把“模板替换完成”误判为业务等价或切流完成。
- 共同实施：每个 App 先创建迁移前 Git tag、记录当前镜像 digest/环境变量/route 清单，再在原仓迁移分支内重构；保留真实业务页面并逐项迁移，不以空模板覆盖后宣称完成。通用修正回流 `tpl-web-frontend`，领域页面、DTO 和规则留在 App。
- `413A Info Web`：验证 public content、登录后 workspace、locale、render/cache 和 Info 真实业务 route；完成后才开始 Knowledge。
- `413B Knowledge Web`：验证 public entry、授权检索/个人空间、Citation 跳转和 provider 隔离；完成后才开始 Research。
- `413C Research Web`：复用 P0-008C 真实试点和 M1-409 workspace，不重复创建 stream client；验证 Run/HITL/citation、多标签恢复和滚动版本。
- 测试：三个实例分别 install/typecheck/lint/unit/build、route/render/cache matrix、auth/CSRF/CSP、Playwright/a11y、Docker/KIND、多副本/version-skew；每个 App 独立切换和回滚演练。
- 验收：三实例均可追溯到同一冻结模板版本且无未解释漂移；各自业务 route/contract/E2E 通过；M1b 前完成全部迁移，任一 App 失败只回滚该 App，不连带切换其他 App。
- 状态：NOT_STARTED

## 8. 部署、迁移与观测工作流

### V5-M1-501 Migration Job Gate

- 类型/优先级：RELIABILITY/P0
- 仓库：`k8s`、三个 App
- 实施：每个 schema owner 独立 Job；revision check；失败阻止 rollout；禁止多 Pod 启动迁移。
- 状态：NOT_STARTED

### V5-M1-502 健康检查

- 类型/优先级：HARDENING/P1
- 实施：live/ready/startup；ready 验证 schema 和必要依赖；worker readiness 验证 consumer。
- 状态：NOT_STARTED

### V5-M1-503 结构化观测

- 类型/优先级：FUNC/P1
- 实施：correlation/lineage；关闭非 debug SQL echo；metrics：queue/outbox/lease/retrieval/run/SSE。
- 状态：NOT_STARTED

### V5-M1-504 镜像与部署可追踪

- 类型/优先级：RELIABILITY/P1
- 实施：API/worker 同一代码版本校验；记录 digest；submodule SHA -> image -> deployment 追踪。
- 状态：NOT_STARTED

## 9. 里程碑 E2E 与流量门禁

### V5-M1-600 M1a 内部真实竖线

- 类型/优先级：FUNC/P0
- 仓库：四仓
- 环境：隔离 namespace、test identity、test dataset、无公网入口、无生产数据。
- 最小范围：Info 提供一个真实不可变 Artifact；Knowledge 完成摄取和 Retrieval；Research 使用选定 Runtime、真实 LLM 和至少一个最小工具生成 citation answer；Research Web 通过真实 API 展示 Run/HITL/citation，Info Admin 与 Knowledge Admin 可查看对应交付/摄取诊断。
- 允许暂缓：完整用户 OIDC、全故障矩阵、canary 网络开放、GA 硬化；但禁止 fake LLM、mock ingestion success 和手工伪造 retrieval result。
- 测试：可重复脚本、基础 contract tests、成本/延迟记录。
- 验收：连续 10 次从空测试数据运行成功；引用可回溯；重复执行没有重复逻辑文档；浏览器刷新后可恢复同一 Run，三个前端视图可沿 correlation/source/evidence ID 对账。
- 状态：NOT_STARTED

### Gate M1a

- V5-M1-600 ACCEPTED。
- Runtime 使用 ADR-001 选定分支，不走未选实现。
- 环境隔离和 test identity 经审查，确认不能被公网访问。
- 结果仅证明产品回路，不允许把 traffic mode 切到 canary/on。

### V5-M1-701 长期记忆架构薄切

- 类型/优先级：ARCH/FUNC/P1
- 仓库：`research-app`
- 前置：Gate M1a；必须使用真实 Runner、真实模型和真实 Session 身份模型。
- 实施：一个 preference 或 corrected experience；人工确认写入；新 Session 召回；纠错和删除。
- 测试：权限、敏感过滤、删除后不召回、来源展示、checkpoint 与 memory 分离。
- 验收：不依赖共享 checkpoint 即可跨 Session 生效；结果形成 ADR-009 输入。
- 状态：NOT_STARTED

### V5-M1-702 Subagent 架构薄切

- 类型/优先级：ARCH/FUNC/P1
- 仓库：`research-app`
- 前置：Gate M1a；使用真实 ModelPort、KnowledgePort 和 Invocation lineage。
- 实施：主 Agent 调用一个隔离上下文 Research Subagent；结构化输入输出、独立预算、取消传播。
- 测试：私有上下文不可见、超时、失败、并行调用、HITL、相对单 Agent 质量/成本。
- 验收：调用树和预算正确；结果形成 ADR-010 输入，不要求完整 Supervisor。
- 状态：NOT_STARTED

### Gate M1a.5

- M1-701/702 ACCEPTED，或有证据证明其中一种目标模式需要改造并已更新 v5。
- Thread/Invocation/Context/Memory 边界完成二次冻结。
- 若薄切推翻 ADR-002/009/010，先更新 ADR 和受影响任务，不进入 M1b。

### V5-M1-601 真实跨仓 E2E

- 类型/优先级：FUNC/P0
- 仓库：四仓
- 场景：
  1. Info 以允许来源抓取真实文档。
  2. 创建不可变 DocumentVersion/Artifact。
  3. 可靠交付 Knowledge。
  4. Knowledge 幂等摄取并完成 parse。
  5. Retrieval 返回 Evidence/Citation。
  6. Research 真实 LLM 调用 KnowledgePort。
  7. 前端展示带引用回答。
  8. Info/Knowledge/Research Admin 用受权身份沿 lineage 查看同一链路。
- 验收：全 lineage/hash/IDs 可追踪；重复运行不产生重复业务对象；Research Web 刷新/重连后与服务端终态一致。
- 状态：NOT_STARTED

### V5-M1-602 故障矩阵

- 类型/优先级：RELIABILITY/P0
- 场景：broker 不可用、worker kill、RAGFlow timeout、S3 403/hash mismatch、模型 timeout、重复 resume、SSE 断线、Pod rollout。
- 验收：无静默丢失；状态可解释；可自动或按 runbook 恢复。
- 状态：NOT_STARTED

### V5-M1-603 安全门禁

- 类型/优先级：SECURITY/P0
- 场景：匿名、跨用户、错误 service audience、缺 scope、CSRF、XSS/Markdown、开放重定向、SSRF、artifact/citation URL 注入、prompt injection、tool 越权、SSE 期间撤权。
- 状态：NOT_STARTED

### V5-M1-604 Golden/Evaluation Gate

- 类型/优先级：FUNC/P0
- 样本：纯文本、知识引用、无证据、一次/多次工具、工具失败、HITL、附件、长上下文、取消。
- 指标：任务成功、citation precision、工具选择、恢复正确、token/cost/latency。
- 状态：NOT_STARTED

### Gate M1b

开 canary 前全部满足：

- P0 任务 ACCEPTED。
- E2E/故障/安全/evaluation 报告通过。
- M1-400~410 P0 任务、M1-411A/B/C/D 和 M1-413 ACCEPTED；六个前端的关键流程可访问性人工走查、浏览器恢复及逐 App 回滚证据通过。M1-412 可在 M1b 后执行，但必须已有明确退出日期和 owner。
- migration、rollback、recovery runbook 演练通过。
- Git desired state 为 `off`，发布者显式切 `canary`。
- canary 有监控、自动/人工停流条件。

### V5-M1-605 Canary 观察与恢复演练

- 类型/优先级：RELIABILITY/SECURITY/P0
- 前置：Gate M1b。
- 实施：极小白名单真实流量；观察成功率、错误、成本、queue/outbox lag、SSE、权限拒绝；执行一次停流和回滚演练。
- 验收：达到预设 SLO/预算，未发生越权或静默丢失，回滚和恢复证据完整。
- 状态：NOT_STARTED

### Gate M1c

- M1-605 ACCEPTED，canary 至少覆盖约定观察窗。
- 产品、平台、安全负责人共同签署有限生产范围和停流条件。
- traffic mode 只能从 `canary` 切到 `on` 的有限策略，不代表 M2/M3 已完成。

## 10. M2：长期记忆与多智能体产品化

### V5-M2-001 LongTermMemory schema/store

- scope、visibility、provenance、version/conflict、sensitive、TTL、embedding version。
- 状态：NOT_STARTED

### V5-M2-002 Memory extraction/confirmation

- 候选、价值判定、人工确认、去重和纠错。
- 状态：NOT_STARTED

### V5-M2-003 Memory recall/evaluation

- scope filter、rerank、token budget、selected/used feedback、误召回评估。
- 状态：NOT_STARTED

### V5-M2-004 Memory deletion/governance

- 查看、纠错、删除、级联索引清理和审计。
- 状态：NOT_STARTED

### V5-M2-005 Memory 用户治理界面

- 仓库：`research-app/research-web-frontend`、`research-admin-frontend`
- 用户可查看来源、scope、使用记录并纠错/删除；管理员只能在授权范围内审计敏感过滤、删除级联和质量指标。
- 测试：跨用户、删除后刷新/召回、并发纠错、敏感字段、审计不可抵赖。
- 状态：NOT_STARTED

### V5-M2-101 AgentInvocation runtime

- 独立上下文、预算、deadline、lineage、输出 schema。
- 状态：NOT_STARTED

### V5-M2-102 Subagent-as-tool 产品化

- 至少 Research/Code 或 Research/Critic 组合，以真实任务评估是否优于单 Agent。
- 状态：NOT_STARTED

### V5-M2-103 Router/Handoff 决策实现

- 仅在产品场景证明需要时实现；不因“多智能体”标签堆叠 Agent。
- 状态：NOT_STARTED

### V5-M2-104 版本锁定与灰度

- Graph/Prompt/Model/Toolset/MemoryPolicy pin；新旧版本并存和 resume 兼容。
- 状态：NOT_STARTED

### V5-M2-105 多智能体透明度与控制界面

- 仓库：`research-app/research-web-frontend`、`research-admin-frontend`
- 用户界面显示可解释的子任务、等待/失败/取消和汇总结果，不暴露私有上下文或原始 chain-of-thought；管理界面显示 Invocation lineage、预算和质量对照。
- 测试：子 Agent 超时/失败/HITL、取消传播、私有上下文脱敏、大调用树性能。
- 状态：NOT_STARTED

### Gate M2

- 记忆提升指标为正且污染率低于阈值。
- 多 Agent 在目标任务上相对单 Agent 有可量化收益。
- 私有上下文无泄漏，失败/取消/预算传播通过。
- 旧 Run 在升级后可恢复或有明确终止迁移方案。

## 11. M3/GA：规模化硬化（触发式）

以下任务不属于 M1 P0，但必须保留为生产目标：

- V5-M3-001 标准化四仓 outbox/inbox 库或规范。
- V5-M3-002 完整 Provider operation journal。
- V5-M3-003 Dataset Registry 控制面与审批。
- V5-M3-004 Info 核心治理 JSONB 拆表（由查询/并发/审计需求触发）。
- V5-M3-005 多租户、配额和 bulkhead。
- V5-M3-006 API HPA、worker KEDA、PDB、topology spread。
- V5-M3-007 分区、归档、CQRS/read model。
- V5-M3-008 备份恢复、RPO/RTO 演练。
- V5-M3-009 canary/自动回滚/SLO。
- V5-M3-010 多 Provider Model Gateway。

每项进入实施前必须记录触发指标，例如 queue lag、数据量、第二 Provider、真实多租户合同或 SLO 要求。

## 12. 追踪矩阵

| 架构目标 | 关键任务 | 主要验收 |
|---|---|---|
| 四仓数据闭环 | P0-003/004, M1-104/201/205/307/601 | 真实 E2E + citation 回溯 |
| 安全 | P0-005, M1-001~005, M1-603 | 未授权/SSRF/tool 越权测试 |
| durable execution | P0-001/002/006, M1-301~314（按 ADR-001 选择分支） | kill/retry/resume/SSE |
| 前端产品闭环 | P0-001/004/005/007A/A2/B/C/008, M1-400~413, M1-600/601 | React Admin 模板完整能力矩阵、六实例逐 App 原地迁移、Next Web v2、浏览器真实 E2E、HITL、刷新/断网恢复、跨 Admin lineage、legacy 退出 |
| 长期记忆 | M1-701, M2-001~005 | 跨 Session、纠错、删除、用户治理、质量 |
| 多智能体 | M1-702, M2-101~105 | 隔离、预算、质量增益、用户可解释控制 |
| 可维护演进 | M1-501/504, M2-104 | migration、digest、版本兼容 |
| 生产可靠性 | M1-105/202/311/502/602 | 无静默丢失、可恢复 |

## 13. 每个任务的完成模板

```markdown
### <TASK-ID> <title>

- 状态：ACCEPTED
- 负责人：
- 仓库/提交：
- 架构/契约版本：
- Migration revision：
- Image digest：
- 实现摘要：
- 单元测试：命令 + 结果
- 集成/契约测试：命令 + 结果
- E2E/故障测试：命令 + 结果
- 安全影响：
- 观测指标：
- 回滚步骤与演练结果：
- 已知限制/后续任务：
- 证据路径：
```

## 14. 第一执行批次

在不修改生产主链前，当前按项目负责人要求串行执行以下 Phase 0 顺序。任何时刻只允许一个代码任务为 `IN_PROGRESS`；“下一项”必须等待上一项的测试、证据、状态回填和提交完成：

1. V5-IMM-001 配置真相紧急保护（已完成，可与其余任务独立）。
2. V5-DOC-HYGIENE-001 工具无关文档收敛（`ACCEPTED`，2026-07-13；不再使用 AI 工具专属文档树）。
3. Frontend-1：V5-P0-007A `tpl-app` React Admin 生产骨架（`SKELETON_ACCEPTED`，2026-07-11）。
4. Frontend-1A2.1 Shell（`ACCEPTED`，2026-07-13；实现 `d2fa1a8`，矩阵 `451d22f`，证据 `V5-P0-007A2/A2.1/result.md`）。
5. Frontend-1A2.2（施工入口）：P0-005/ADR-005 已 ACCEPTED，消费真实身份契约；不得回退到 demo/mock auth。`ACCEPTED` 证据见 `sunmoonai/docs/evidence/v5/V5-P0-007A2/A2.2/result.md`。
6. Frontend-1A2.2 Identity/Data Foundation（`ACCEPTED`，2026-07-14）：真实 session、typed client/error/correlation、TanStack Query、i18n 基础，以及三应用严格 TLS/CORS/CSRF/跨用户/过期 session consumer 矩阵均通过；实现 `tpl-admin-frontend@0b68498`，扩展 gate `k8s@3558a08`。
7. **当前任务** Frontend-1A2.3 CRUD Toolkit：完成通用 Table/Form/Description/Modal/Drawer/通知/上传下载和写操作约定。
8. Frontend-1A2.4 Rich/Utility Toolkit：完成或显式处置 Icon/Chart/Editor/Media/通用指令工具与 legacy 能力。
9. Frontend-1A2.5 Production Gate：完成全套测试、安全负例、Docker/KIND、clean-room install、矩阵和证据，接受 P0-007A2。
10. Contract-1：复核已接受的 V5-P0-003 Artifact Contract 仍为 007B 可用前置，不重复实现。
11. Frontend-2：V5-P0-007B 在现有 Info Admin 仓库内做真实业务试点和隔离部署。
12. Frontend-3：V5-P0-007C 修正、dry-run 替换验证和 React Admin v1 冻结（产生 `TEMPLATE_MIGRATION_READY`）。
13. Contract-2：V5-P0-004 Retrieval/Citation Contract。
14. Runtime：恢复 V5-P0-001，完成选型后执行 V5-P0-002。
15. Reliability：V5-P0-006 可靠交付 ADR 与最小原型。
16. Web Re-baseline：严格执行 V5-P0-008A -> 008B/B1~B4 -> 008C；其依赖此时已齐备。

P0-007A2/007C 前禁止向三个 App 应用 React Admin；P0-008C 前禁止向三个 Web 实例应用 Next Web v2。P0-007C/008C 只表示模板可推广；Gate P0 后依次执行 M1-411A -> 411B Info -> 411C Knowledge -> 411D Research，再执行 M1-413A Info -> 413B Knowledge -> 413C Research 的 Web 原地迁移。每个 App 都直接改造现有仓库，但必须先有 tag、镜像 digest、隔离部署和独立回滚；不能把基础替换当作切流量。完成全部 Phase 0 后更新 v5、按 ADR-001 激活唯一 Runtime 分支，再进入 M1a。禁止绕过 Gate P0 直接把 Walking Skeleton 扩建为生产 Runner；Memory/Subagent 薄切只能在 Gate M1a 后执行。
