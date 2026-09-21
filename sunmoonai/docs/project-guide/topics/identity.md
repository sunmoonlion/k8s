# 身份与授权

> 后端身份源码复核：2026-09-13 ｜ 相关规则见 [`../../dev-agent/rules/constraints.md`](../../dev-agent/rules/constraints.md)「身份」I1–I8

## 1. 两类身份，互不通用

| 类别 | 谁在用 | 凭据形态 |
| --- | --- | --- |
| **浏览器身份** | Admin / Web 前端的真人用户 | Casdoor OIDC → 后端会话 cookie |
| **服务身份** | App 之间的 HTTP 调用 | 签名的 workload JWT，或 OAuth client credentials |

**浏览器 cookie 不能用于服务间调用；服务 token 也不构成用户身份。**

## 2. Casdoor 的位置

由 `auth-app` 以 **Helm 单独部署**，**不进入 App bundle / release.json 门禁**（其制品治理由自己的 Helm 链负责），
不可变制品治理由 auth-app 自己的 Helm 链负责，不是豁免（见 [`release.md`](release.md)）。

它只做身份提供：管用户 / 组织 / 应用 / OIDC / token。
**领域授权在各 App Backend**——Casdoor 不替代任何 App 的资源级授权。

## 3. 浏览器身份：Admin 与 Web 是两个安全边界

每个 App 后端提供两组 OIDC 端点：`/api/auth/admin/*` 与 `/api/auth/web/*`。

`BrowserSurfaceProfile`（**不可变**）为每个表面固定一组边界：
client_id / client_secret · redirect_uri · frontend origins · session cookie 名 ·
transaction cookie 名 · Redis key 前缀 · required_scopes。

**关键不对称**（`core/config.py`）：

```python
required_scopes=(f"{self.app_slug}:admin",) if surface == "admin" else ()
```

- **Admin 强制要求 `{app}:admin` scope**
- **Web 不要求任何 scope**

各 App 的 Admin scope 分别是 `info:admin` / `knowledge:admin` / `investment:admin`。

### 3.1 登录流程

```
GET /api/auth/{surface}/login
  → 生成 transaction_id / state / nonce / PKCE verifier，事务写 Redis（NX + TTL）
  → 重定向 Casdoor
GET /api/auth/{surface}/callback
  → 原子消费事务（GETDEL）
  → hmac.compare_digest 验 state
  → 换码，verify_id_token 严格校验 issuer / audience / nonce
  → 影子用户 upsert 到 auth_user（issuer + subject 唯一）
  → 会话 NX 写 Redis
```

会话过期时间取 `min(provider exp, now + session_ttl)`。

### 3.2 CSRF

非安全方法必须同时满足：`Origin ∈ frontend_origins` 且 `X-CSRF-Token` 与会话内的
csrf 值 hmac 相等。

## 4. 服务身份

### 4.1 通用验证链（`infrastructure/security/service_identity.py`）

```
验 audience（SERVICE_AUTH_AUDIENCE）
  → 取 sub / iss
  → subject 必须命中 service_auth_subject_bindings 的精确键
     （不在表中 → service_subject_unbound）
  → token_scopes ⊆ allowed_scopes（该 subject 的最大授权集）
  → required_scopes ⊆ token_scopes
```

绑定表由 `SERVICE_AUTH_SUBJECT_BINDINGS_JSON` 提供，是 subject → 最大 scope 集的**精确映射**。

### 4.2 knowledge-app 的双关系验证器

knowledge 是两条入站关系的提供方，用**两个独立的验证器实例**：

| 关系 | 调用方 | scope |
| --- | --- | --- |
| `ingest` | info-app | `knowledge:ingest` |
| `retrieve` | investment-app | `knowledge:retrieve` |

各自独立的 audience、subject allowlist、discovery / backchannel 配置。

代码注释记录了一个要点：Casdoor 的 client-credentials token 可能只带 provider 的
`openid` scope，**关系 scope 由本地 subject allowlist 授予**并体现在 Principal 上。

### 4.3 出站

`DownstreamServiceClient` 用 client credentials 取 token；路径必须命中 allowlist 前缀
（默认 `/api/internal/v1`）；**拒绝指向本 Backend 自身的 base_url**；生产强制 verify_ssl。

## 5. 生产期的身份硬约束

以下全部是**启动期硬失败**，不是运行期告警——配错了服务起不来：

| 约束 | 位置 |
| --- | --- |
| 禁 `REFERENCE_INTERACTION_ENABLED=true` | 四仓 `core/config.py` 一致 |
| `ALLOWED_HOSTS` 禁通配、禁空 | `core/config.py` |
| `CASDOOR_VERIFY_SSL` 须 true | `core/config.py` |
| `SESSION_COOKIE_SECURE` 不得 false | `core/config.py` |
| `CASDOOR_ENDPOINT` 须 HTTPS | `core/config.py` |
| frontend origins 禁通配、须 origin-only | `core/config.py` |
| `SERVICE_AUTH_AUDIENCE` / 绑定表 不得缺失或非法 | `core/config.py` |
| 前端 `APP_ORIGIN` 须 HTTPS | 各前端 `env/server-schema.ts` |

前端侧另有一条：`DEPLOYMENT_ENV` / `AUTH_APP` / `APP_ORIGIN` / `BACKEND_INTERNAL_URL` /
`DEPLOYMENT_ID` 在生产运行时缺任一即 `throw`。

## 6. Internal 入站与运行身份

四仓都已挂载受保护的 `GET /api/internal/v1/delivery/metrics`：独立服务主体、精确
audience/subject 绑定及 `delivery:observe`，不接受浏览器 Cookie 替代，不默认授权主体。

| 仓 | 状态 |
| --- | --- |
| knowledge-app | 摄入/检索领域面 + 公共投递指标 |
| investment-app | Pilot Runtime + 公共投递指标 |
| tpl-app | 公共投递指标，无领域 Internal 用例 |
| info-app | 公共投递指标，不因此新增资讯领域入站契约 |

数据库/broker 进程身份不同于上述 HTTP 服务身份。源码渲染已使用 API/Worker/Scheduler
分角色键；2026-09-20 本机 KIND 的三个 App 已切换到独立 PG 与 RabbitMQ 运行身份，
旧 backend DB 登录和旧 vhost 权限已退出并实测拒绝。详见
[发布现状与验收边界](release.md#8-当前-kind-切换事实与剩余验收)；这不代表云端部署或生产验收。
生产者只写预建的精确任务交换机，Worker 保留读写任务及必要控制/事件资源；开关
`CELERY_TASK_TOPOLOGY_PREDECLARED` 默认关闭，必须先供给 durable 拓扑再启用。
漏建交换机/队列/绑定必须使发布失败，不得静默丢任务。

这些不是租户/行级/工具或人的审批规则：Worker 的 read 仍允许 purge，pidbox 资源 ACL
不区分 inspect/shutdown。联合验证范围见[B7u](../../legacy-backlog/verification-index.md)；
真实账号供给、旧连接撤销和重启一致性不由配置键名证明。
