"""
Flask config 接入 auth-app 所需的配置项。
复制到项目的 config/default.py 或对应配置类中。

三个变量必须与 auth-app-backend 保持一致：
  AUTH_JWKS_URL      → auth-app 的 /jwks 端点（验签用，无需密钥）
  AUTH_JWT_ISSUER    → JWT 的 iss 字段，通常是 auth-app 的 API 前缀
  AUTH_JWT_AUDIENCE  → JWT 的 aud 字段，本 app 独有，需要与 BFF login 时传的 aud 参数一致
"""


class DefaultConfig:
    # ── auth-app JWT 验签配置 ────────────────────────────────────────────────

    # auth-app JWKS 端点（公钥，无需认证即可访问）
    # 本地开发：http://localhost:3030/api/v1/jwks
    # K8s 集群内：http://auth-app-backend:3030/api/v1/jwks
    AUTH_JWKS_URL = 'http://localhost:3030/api/v1/jwks'

    # JWT 签发方（auth-app issuer），与 auth-app-backend .env 中的 OIDC_ISSUER 一致
    AUTH_JWT_ISSUER = 'http://localhost:3030/api/v1'

    # 本 app 的 audience 标识（自定义字符串，全局唯一）
    # 命名惯例：{app-name}-api，例如 myapp-api、order-api
    # 必须与 Nuxt BFF server/api/auth/login.get.ts 中的 aud 参数一致
    AUTH_JWT_AUDIENCE = 'myapp-api'   # ← 修改为本 app 的 audience
