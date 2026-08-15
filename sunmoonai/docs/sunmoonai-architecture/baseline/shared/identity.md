# 身份与授权

> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15
> 仓内细节见各 [`../repos/`](../repos/) 的 §3 与 §6。

## 1. 两类身份，互不通用

| 类别 | 谁在用 | 凭据形态 | 校验位置 |
| --- | --- | --- | --- |
| **浏览器身份** | Admin / Web 前端的真人用户 | Casdoor OIDC → 后端会话 cookie | 各仓 `interfaces/http/admin/auth.py`、`http/web/auth.py` |
| **服务身份** | App 之间的 HTTP 调用 | Bearer token（subject allowlist 或 OAuth client credentials） | 见 §3 |

浏览器 cookie 不能用于服务间调用，服务 token 也不构成用户身份。

## 2. 浏览器身份

**Casdoor 由 auth-app 独立部署**，是 Helm 部署而非 App bundle
（`k8s/sunmoonai/app-platform/auth-app/deploy-auth-app-all/deploy-auth-app-all.conf:1-4`），
因此它没有 `deployment/bundle/release.json`，不受 [`release.md`](release.md) 的 digest 纪律约束。

每个 App 后端各自提供两组 OIDC 端点：

| 端点前缀 | 面向 | 位置（以 investment-app 为例） |
| --- | --- | --- |
| `/api/auth/admin/*` | Admin 前端 | `interfaces/http/admin/auth.py:23` |
| `/api/auth/web/*` | Web 前端 | `interfaces/http/web/auth.py:24` |

登录流程（以 tpl-app web 面为例）：访问 `/api/auth/web/login`（`web/auth.py:49-51`）
→ 重定向 Casdoor 并写入 transaction cookie（`:35-46`）→ 回调 `/api/auth/web/callback`（`:59+`）。
生产或已配置 Casdoor 时，启动阶段会校验 browser identity 配置（`bootstrap/api.py:42-43`）。

Casdoor 的 origin 记在各 App 的 `release.json.origins`
（`k8s/sunmoonai/app-platform/*/deployment/bundle/release.json:14-18`），与 admin/web origin 并列。

## 3. 服务身份

| 调用 | 凭据机制 | 校验位置 |
| --- | --- | --- |
| info → knowledge（ingest） | Bearer + subject allowlist | `knowledge-app/.../infrastructure/security/service_auth.py:71-74,153-164`；配置键 `INTERNAL_AUTH_*`（`.env.example:78-83`） |
| investment → knowledge（retrieve） | OAuth client credentials 取 token 后 Bearer | 客户端 `investment-app/.../external/knowledge_retrieval.py:131-179`；服务端配置键 `RETRIEVAL_AUTH_*`（`.env.example:84-89`） |
| Pilot Internal API 的调用方 | Bearer + `require_agent_pilot()` 全量配置 | `investment-app/.../pilot_service_auth.py:62-78`；`config.py:615-632` |
| 通用服务身份 JWT | `info-app/.../infrastructure/security/service_identity.py` | 中间件 `middleware/auth.py:100-115` |

凭据缺失时的行为不统一，按仓取值：knowledge 侧返回 401/403/503；
investment 侧的 knowledge 客户端抛 `KnowledgeRetrievalNotConfiguredError`
（`knowledge_retrieval.py:131-135`）。

## 4. Admin 授权 scope

| App | 所需 scope 或依赖 | 位置 |
| --- | --- | --- |
| info-app | `info:admin` | `core/config.py:443`；`middleware/auth.py:97` |
| knowledge-app | `knowledge:admin` | `core/config.py:409`；`middleware/auth.py:97` |
| investment-app | `require_investment_admin` 依赖 | `endpoints/agent_routes.py:61-62` |
| tpl-app | 模板侧仅提供中间件骨架 | `middleware/auth.py:100-133` |

## 5. 四仓共同的生产期身份约束

| 约束 | 位置（各仓 `core/config.py`） | 违反后果 |
| --- | --- | --- |
| 生产禁 `REFERENCE_INTERACTION_ENABLED=true` | tpl `:171-174`、info `:278-281`、knowledge `:244-247`、investment `:263-266` | 启动 `ValueError` |
| 生产 `ALLOWED_HOSTS` 禁 `*` | info `:269-271` | 启动 `ValueError` |
| 生产关闭 OpenAPI 与 `/docs` | knowledge `bootstrap/api.py:69-71` | 无文档端点 |
| 生产前端 `APP_ORIGIN` 须 HTTPS | tpl `tpl-web-frontend/app/env/server-schema.ts:64-65` | `throw new Error` |

前三条是启动期硬失败，不是运行期告警——配错了服务起不来。

## 6. 未接线处

`/api/internal/v1` 在 **tpl-app 与 info-app 中没有挂载 router**：tpl 只有
`get_internal_service_principal` 中间件（`middleware/auth.py:100-133`），
info 的 `interfaces/http/internal/` 只有包说明（`__init__.py:1`）。
真正有内部路由的是 knowledge-app（`endpoints/knowledge_routes.py:33-90`）
与 investment-app（`endpoints/pilot_runtime_routes.py:35-38`）。
