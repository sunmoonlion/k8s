# ADR-005：用户身份、服务身份与浏览器 BFF 边界

状态：CANDIDATE  
日期：2026-07-12  
决策者：项目负责人、四仓 owner、架构与安全评审

## 1. 背景与已确认事实

Info、Knowledge、Research 三套 Admin Backend 来自同一模板，当前实现存在相同缺口：

1. `get_current_user()` 已定义但未挂到业务 Router，业务 API 和 `/internal/tasks` 可匿名访问。
2. OIDC login 生成 `state` 却不保存、不在 callback 校验；没有 PKCE、nonce 和一次性登录事务。
3. callback 只 base64 解码 ID Token payload，不验证签名、issuer、audience、时间声明和 nonce。
4. Redis 使用无 App/Surface 隔离的 `session:{id}`，并保存完整 token response；`/auth/me` 又把该结构返回浏览器。
5. 登录时执行 DDL 创建 shadow user table，数据库 schema 不受 migration gate 管理。
6. 三套 Admin Backend 均允许 credential CORS 配合通配 origin。
7. Info -> Knowledge 可选静态 API key，但 Knowledge ingestion 路由不验证该 key；浏览器身份和服务身份没有协议隔离。
8. 三套 Nest Web Backend 也只解码未验签 token，多数业务 Controller 未挂 Guard，且 Admin/Web 没有 audience 隔离。

所以，本 ADR 不是为既有安全闭环补充术语，而是替换不可信的认证原型。P0-005 必须先让三套 Admin 和首条跨仓调用 fail closed；三套 Web 的同一模型落地与 Next Web v2 基线任务合并验收，不能用前端路由守卫代替。

## 2. 决策

### 2.1 身份面与信任边界

1. Casdoor 是唯一 OIDC Provider，但六个浏览器面使用六个独立 client/audience：`Info|Knowledge|Research x Admin|Web`。Admin cookie/token 不得访问 Web API，反向亦然。
2. 浏览器只持有所在 App/Surface 的不透明会话 cookie，只调用同产品 Backend/BFF。浏览器不得持有或转发跨仓服务凭据，也不得编排 Info -> Knowledge -> Research。
3. 后端从已验证身份构造内部 `Principal`；业务 payload 中的 `actor_id`、`reviewer`、`tenant_id`、role 和 scope 一律不可信。
4. 人类会话、服务 Bearer token 和 K8s ServiceAccount 是三个不同证据：
   - 人类会话证明交互用户及所在 App/Surface；
   - Casdoor client-credentials token 证明调用服务；
   - ServiceAccount 绑定 Pod/workload，只作为部署绑定与网络策略输入，不能代替可验证 token。
5. worker 不携带浏览器 token。Run 持久化不可变的 delegated identity snapshot；worker 用自身服务身份执行，并把有效权限限制为“用户授权快照、worker policy、tool policy”的交集。

浏览器 Casdoor application 的逻辑名固定为：

```text
sunmoonai-info-admin       sunmoonai-info-web
sunmoonai-knowledge-admin  sunmoonai-knowledge-web
sunmoonai-research-admin   sunmoonai-research-web
```

expected audience 是对应 application 的实际 `client_id`，由 Secret 注入，不能把 application name 当作 audience。expected issuer 和 `jwks_uri` 必须读取该 application 的 discovery metadata，不能从 host 或 token claim 自行拼接。

### 2.2 浏览器登录与会话

三套 Admin 和未来三套 Web 采用 Backend-for-Frontend 会话模式：

1. Authorization Code Flow + PKCE S256。
2. `/auth/login` 生成高熵 `state`、`nonce`、PKCE verifier/challenge 和临时 transaction ID。Redis 只保存短 TTL 登录事务；浏览器收到 App/Surface 专属、HttpOnly 的临时 transaction cookie。
3. callback 必须原子消费登录事务，并同时校验 callback `state`、transaction cookie、PKCE 和 ID Token nonce；失败、重复 callback、过期事务均拒绝。
4. OIDC metadata/JWKS 从 Casdoor discovery 获得。验证器必须固定允许的非对称算法，并严格校验签名、discovery issuer、当前 client 的精确 audience、`exp`、`iat`、nonce；不得仅解码 JWT，不得信任 token 自带算法选择。
5. callback 成功后轮换为 App/Surface 专属会话 ID。Redis key 使用 `sunmoonai:auth:{app}:{surface}:session:{opaque-id}`；会话 TTL 不超过已验证身份有效期和本地上限。
6. P0 会话只保存最小、可序列化的 `Principal`、policy version 和 CSRF secret，不保存 access/id/refresh token。需要 refresh/offline access 时另行设计服务端加密 token vault；P0 到期后重新登录。
7. `/auth/me` 只返回浏览器安全 DTO 和 CSRF token，不返回 token、client secret、Redis payload、Provider metadata 或内部 policy 细节。
8. 正式 cookie 为 host-only、`HttpOnly`、`Secure`、`SameSite=Lax`、`Path=/`。本地 HTTP 仅允许显式 development 配置关闭 `Secure`，不得由请求头自动降级。
9. `/auth/logout` 使用 `POST`，校验 CSRF 后删除服务端 session 和 cookie。旧 GET logout 删除，不保留有副作用的 GET 兼容入口。
10. `return_to` 只允许当前前端 origin 下的相对路径 allowlist，禁止开放重定向。

### 2.3 CSRF、CORS 与前端边界

1. 所有 cookie-auth 的非安全方法同时校验严格 Origin allowlist 和 `X-CSRF-Token`，token 使用 constant-time comparison。SameSite 不是唯一 CSRF 防线。
2. CORS 按 App/Surface 配置精确 origin；`allow_credentials=true` 时禁止 `*`。允许的 method/header 取最小集合。
3. 前端路由守卫只改善 UX。每个 Backend/BFF Router 和资源操作必须在服务端重新认证和授权。
4. SSE 可使用同源 cookie 建连，不要求自定义 CSRF header，但建连前必须验证 session、audience 和资源所有权；重连/对账时重新授权，并定义权限撤销后的断流策略。
5. React Admin 不直接解析 JWT，不把 token 写入 localStorage/sessionStorage。typed client 默认携带 cookie，并只为非安全方法注入 `/auth/me` 获得的 CSRF token。

### 2.4 内部 Principal 与授权输入

P0 固定以下语义；字段名可在各语言内本地建模，但含义不能漂移：

```text
Principal
  actor_type: user | service
  subject: Provider sub 或受控 service subject
  app: info | knowledge | research
  surface: admin | web | internal
  audience: 经验证的精确 audience
  actor_id: 本地稳定 ID（用户时必填）
  display_name/email: 可选展示字段
  roles/scopes: 经过本地 allowlist/policy 映射后的集合
  authenticated_at/expires_at
  policy_version
```

授权判定输入统一为：

```text
principal + action + resource owner/tenant/project + policy_version
```

未识别 role/scope、缺 owner、资源不存在与 policy version 不兼容均 fail closed。对外 401 表示未认证/凭据失效，403 表示主体已认证但无权；不得用 200 + null 掩盖失效会话。

### 2.5 服务身份与 Info -> Knowledge

1. 服务调用使用 Casdoor OAuth 2.0 client credentials。每条调用关系使用独立 confidential client/subject，不共享 Admin client、浏览器 token 或静态 API key。
2. Knowledge internal resource server 使用为该 service relation 显式配置的 discovery/JWKS 验证签名、issuer、精确 target audience、`exp`/`iat`，再以本地 binding 把 service subject 映射为 scopes。未知 subject 或 binding 默认拒绝；Provider 返回的 `scope`/`scp` 只作为格式化输入，不能替代本地关系授权（Casdoor client-credentials 令牌可能只返回 provider 级 `openid` scope）。浏览器 BFF 仍使用 application-specific discovery；Casdoor 当前版本的 client-credentials access token 使用基础 issuer，因此 service relation 的 `INTERNAL_AUTH_DISCOVERY_URL` 指向标准 discovery，issuer 必须完全取自该 metadata，禁止从 token 自行推断或放宽为任意 host。
3. P0 第一条 binding 为 `Info distribution worker -> Knowledge ingestion`，scope 为 `knowledge:ingest`。该 credential 不能调用 Knowledge Admin API、Research retrieval 或其他 internal API。
4. Knowledge ingestion command 迁移到版本化 internal route（目标：`POST /api/internal/v1/knowledge/ingestions`）；浏览器管理查询/重试继续走 Admin session route。旧匿名 ingestion route 在未接生产流量前直接关闭，不保留双写或匿名兼容。
5. Info worker 按需取得并以内存短时缓存 access token，按 `exp` 留安全余量刷新；token 不写数据库、日志、事件、错误响应或任务 payload。
6. 每次请求携带稳定 operation/correlation ID。Knowledge 的审计记录同时保存 service principal 和由业务命令提供、但经本地规则约束的 delegated actor reference；两者不能互相替代。
7. P0-004 后新增独立 `Research worker -> Knowledge retrieval` client/scope；撤销 ingestion credential 不影响 retrieval，反向亦然。

第一条服务 application 的逻辑名固定为 `sunmoonai-info-knowledge-ingest`。Casdoor client-credentials token 的实际 `sub`、`aud`、issuer 和 scope claim 形状必须由 P0-005A/D 在当前部署版本中实测并形成去敏 fixture；在此之前不得用文档示例或用户 token 形状推断。若 Provider 不能直接表达资源 audience/scope，仍以独立 application/client + exact client audience + 本地 subject binding 实现单关系最小权限，不放宽验证。

### 2.6 路由分区

| 分区 | 认证方式 | P0 示例 | 默认策略 |
|---|---|---|---|
| Public | 无业务身份 | login、callback、health；development docs | 只允许显式清单 |
| Admin/User | App/Surface 专属 BFF session | Info documents/distributions、Knowledge 管理查询、Research sessions/runs | session + scope + 关键 owner check |
| Internal | service Bearer token | Knowledge ingestion、内部任务投递 | exact audience + subject binding + scope |

生产 docs/OpenAPI 默认关闭或受 Admin session 保护。仅将 URL 改名为 `/internal` 不构成安全边界。

### 2.7 数据库与审计

1. shadow user、identity binding 和必要审计字段只能通过 Alembic migration 创建；login path 禁止 DDL。
2. shadow user 以 Provider issuer + subject 建稳定唯一约束，不以可修改 username/email 作为身份。
3. 安全审计至少记录时间、App/Surface、actor type/ID、action、resource ID、decision、reason code、policy version、operation/correlation ID；不记录 token、cookie、authorization code、PKCE verifier、nonce、client secret 或完整正文。
4. 日志中的认证失败使用稳定 reason code；对客户端保持克制，避免泄露 subject 是否存在、JWKS 细节或 policy 内部结构。

### 2.8 Python 安全内核选型

Python Admin 不引入全栈认证框架，也不继续手写 JOSE：

1. 保留现有 `httpx` 完成 discovery、code/token exchange 和 client-credentials 请求。
2. 使用 `joserfc >= 1.7.3, < 2` 完成 JWK Set、JWS/JWT 解码和 claims registry 验证；调用时显式传入允许算法，并在解码后显式校验 essential claims。
3. state、nonce、PKCE、Redis 原子消费、session、CSRF 与本地 policy 是应用安全内核职责，不委托给客户端可修改数据。
4. 三仓先复制小而清晰的协议实现和共享测试向量，不在 P0 抽取远程共享包。

选择 `joserfc` 而不是旧实现中的 base64 解码或新增完整 Authlib Web Client，是因为本项目已有 async HTTP client，且需要显式 Redis 登录事务；独立 JOSE 库覆盖最危险、最不应自研的签名/JWK/claims 部分，同时避免引入与现有 session 模型冲突的框架隐式状态。

## 3. P0-005 与后续任务边界

P0-005 必须真实完成：

1. 冻结本 ADR、Principal/错误语义和六 audience 命名规则。
2. 建立 Python Admin 安全内核，并在 Info、Knowledge、Research 三仓应用：可信 OIDC callback、隔离 session、安全 `/me`/logout、CSRF/CORS、业务 Router fail closed。
3. 对 Research Session/Run/SSE 和 Info/Knowledge 关键资源至少完成 owner/管理 scope 检查；不能只做“有 cookie 即放行”。
4. 建立真实 Info -> Knowledge client-credentials 路径，删除静态 API key/匿名 ingestion 依赖。
5. 在 KIND 使用真实 Casdoor/JWKS 跑通允许矩阵和匿名、伪造签名、错误 issuer/audience、过期 token、state/nonce/PKCE、CSRF、跨用户资源、缺 scope、浏览器凭据调用 internal route等拒绝矩阵。
6. 为 Nest Web 提供相同 audience/Principal/错误 contract 的 consumer tests。Web Controller 的正式 fail-closed 落地由 P0-008B 完成；P0-008C 前必须在真实 Web route 证明 Admin/Web token 双向拒绝。

P0-005 不包含：完整 RBAC 管理 UI、全量细粒度资源策略、Provider token vault/refresh、Secret 管理产品选型、全量 NetworkPolicy。它们分别进入 M1-001/003/005；但这些后续项不能推翻本 ADR 的身份和协议边界。

## 4. 备选方案与拒绝理由

### 4.1 浏览器保存 access token 并直连全部 API

拒绝。扩大 XSS/泄露半径，鼓励跨仓编排和 audience 混用，也无法给六个前端面建立清晰边界。

### 4.2 继续使用不透明 cookie，但只解码 ID Token

拒绝。cookie 是否不透明与上游 token 是否可信是两个问题；未验签/未校验 issuer、audience、nonce 的 claims 不能生成可信 session。

### 4.3 共享静态 API key 或 Admin token 做服务调用

拒绝。没有标准过期/audience，无法区分调用关系和最小撤销，且把人类权限扩散到 worker。

### 4.4 只依赖 K8s ServiceAccount/NetworkPolicy

拒绝。网络身份与应用层授权互补；进入 Pod、共享网络或配置漂移后，目标服务仍必须验证可撤销的 cryptographic principal 和 scope。

### 4.5 立刻抽取跨仓共享认证 SDK

暂不选择。先冻结协议和 contract，在三套 Admin 以同一测试向量实现；两次真实落地后再判断共享包，避免把错误抽象变成四仓关键依赖。

## 5. 回滚与故障策略

1. 认证/授权不可用时业务和 internal route fail closed；health/readiness 可区分 Provider/JWKS/Redis 故障，但不得绕过身份。
2. JWKS 使用受限 TTL cache，并支持 key rotation 后刷新；未知 `kid` 只触发一次受控刷新，仍不匹配即拒绝，禁止回退为不验签。
3. Casdoor、Redis 或 token endpoint 故障时保留可审计错误和 operation ID，不启用匿名模式或静态 key fallback。
4. 发布采用 traffic-off/隔离入口验证；回滚到上一镜像不得重新开放匿名业务 API。若旧镜像不满足该条件，只能停流而不能回滚。

## 6. 接受条件

本 ADR 在以下证据齐全后由 CANDIDATE 转为 ACCEPTED：

- 三套 Admin contract/unit/integration 测试和真实 KIND 负向矩阵通过；
- Info -> Knowledge 使用真实 client-credentials token，Knowledge 确认 exact audience/subject，并以本地 `knowledge:ingest` binding 授权（同时记录去敏的 provider scope 形状），Artifact Contract v1 仍通过；
- 浏览器响应、Redis session、日志/事件抽查无 Provider token 和 Secret；
- 三套业务 Router 匿名访问为 401，已认证越权为 403，关键资源跨用户访问被拒绝；
- K8s 配置从 Secret 引用六个 client 与服务 client，不提交有效 credential；
- 证据目录记录 contract digest、测试命令、镜像/deployment digest、允许/拒绝矩阵和回滚演练。

## 7. 标准依据

- Casdoor OIDC discovery、authorization/token/userinfo/JWKS、PKCE 与 claims：<https://casdoor.ai/docs/how-to-connect/oidc-client/>
- Casdoor OAuth 2.0 client credentials 服务调用：<https://casdoor.ai/docs/basic/public-api/>
- Casdoor JWT certificate/JWKS 验证：<https://casdoor.ai/docs/cert/overview/>
- joserfc JWT/JWK 与显式 claims validation：<https://jose.authlib.org/en/guide/jwt/>
- joserfc 安装与依赖：<https://jose.authlib.org/en/install/>
- OAuth 2.0 Authorization Server Issuer Identification（RFC 9207）：<https://www.rfc-editor.org/rfc/rfc9207>
- OAuth 2.0 PKCE（RFC 7636）：<https://www.rfc-editor.org/rfc/rfc7636>
- OpenID Connect Core nonce、ID Token validation：<https://openid.net/specs/openid-connect-core-1_0.html>
