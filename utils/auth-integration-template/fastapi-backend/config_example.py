"""
FastAPI 配置示例：用 pydantic-settings 管理 auth-app 相关环境变量。

依赖：
    pip install pydantic-settings

使用方式：
    将此文件重命名为 config.py，放到项目的 app/ 或 core/ 目录下，
    然后在 jwks_auth.py 中 from .config import get_settings 即可。

环境变量（在 .env 或 K8s Secret 中设置）：
    AUTH_JWKS_URL      auth-app 的 JWKS 端点
    AUTH_JWT_ISSUER    JWT 签发方（iss 字段）
    AUTH_JWT_AUDIENCE  本 app 的 audience（aud 字段）
"""
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── auth-app JWT 验签配置 ───────────────────────────────────────────────

    # auth-app JWKS 端点（公钥，无需认证即可访问）
    # 本地开发：http://localhost:3030/api/v1/jwks
    # K8s 集群内：http://auth-app-backend:3030/api/v1/jwks
    auth_jwks_url: str = 'http://localhost:3030/api/v1/jwks'

    # JWT 签发方（与 auth-app-backend .env 中的 OIDC_ISSUER 一致）
    auth_jwt_issuer: str = 'http://localhost:3030/api/v1'

    # 本 app 的 audience（命名惯例：{app-name}-api）
    # 必须与 Nuxt BFF login.get.ts 中的 aud 参数一致
    auth_jwt_audience: str = 'myapp-api'   # ← 修改为本 app 的 audience

    class Config:
        env_file = '.env'
        env_file_encoding = 'utf-8'
        # pydantic-settings 默认读取全大写环境变量
        # AUTH_JWKS_URL → auth_jwks_url


@lru_cache
def get_settings() -> Settings:
    """返回单例 Settings，供 jwks_auth.py 调用。"""
    return Settings()
