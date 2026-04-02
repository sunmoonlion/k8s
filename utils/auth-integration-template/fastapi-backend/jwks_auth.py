"""
JWKS-based JWT verification for auth-app RS256 tokens — FastAPI 版本。
使用 FastAPI 依赖注入（Depends）模式，而非 Flask 装饰器。

依赖：
    pip install python-jose[cryptography] httpx pydantic-settings

用法：
    from fastapi import Depends
    from .jwks_auth import require_user, optional_user, CurrentUser

    @router.get("/profile")
    def get_profile(user: CurrentUser = Depends(require_user)):
        return {"user_id": user.user_id}

    @router.get("/feed")
    def get_feed(user: CurrentUser = Depends(optional_user)):
        # user.user_id 为 None 表示匿名
        ...
"""
import time
import threading
from typing import Optional

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt as jose_jwt
from pydantic import BaseModel

from .config import get_settings  # 见 config_example.py


# ── 公钥缓存（进程内，TTL 10 分钟）─────────────────────────────────────────

_jwks_cache: dict = {'keys': None, 'fetched_at': 0.0}
_jwks_lock = threading.Lock()
_JWKS_TTL = 600  # 秒


def _get_jwks() -> list:
    """从 auth-app 获取 JWKS 公钥，带本地缓存。"""
    now = time.time()
    with _jwks_lock:
        if _jwks_cache['keys'] and now - _jwks_cache['fetched_at'] < _JWKS_TTL:
            return _jwks_cache['keys']

    settings = get_settings()
    resp = httpx.get(settings.auth_jwks_url, timeout=5)
    resp.raise_for_status()
    keys = resp.json().get('keys', [])

    with _jwks_lock:
        _jwks_cache['keys'] = keys
        _jwks_cache['fetched_at'] = time.time()

    return keys


# ── JWT 验证 ────────────────────────────────────────────────────────────────

class CurrentUser(BaseModel):
    """注入到路由函数的用户信息。"""
    user_id: int
    role: str = 'user'
    payload: dict  # 完整 JWT payload，按需取其他字段


def _verify_token(token: str) -> Optional[dict]:
    """
    验证 RS256 JWT，返回 payload dict，失败返回 None。
    校验 aud 和 iss（若配置了的话）。
    """
    try:
        settings = get_settings()
        keys = _get_jwks()
        if not keys:
            return None

        options = {}
        if not settings.auth_jwt_audience:
            options['verify_aud'] = False

        payload = jose_jwt.decode(
            token,
            {'keys': keys},
            algorithms=['RS256'],
            audience=settings.auth_jwt_audience or None,
            issuer=settings.auth_jwt_issuer or None,
            options=options,
        )
        return payload
    except Exception:
        return None


# ── 依赖项 ──────────────────────────────────────────────────────────────────

_bearer = HTTPBearer(auto_error=False)


def require_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> CurrentUser:
    """
    依赖项：要求有效 Bearer token。
    无 token 或 token 无效时抛出 401。

    用法：
        @router.get("/me")
        def me(user: CurrentUser = Depends(require_user)):
            return {"user_id": user.user_id}
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Missing Bearer token',
            headers={'WWW-Authenticate': 'Bearer'},
        )

    payload = _verify_token(credentials.credentials)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid or expired token',
            headers={'WWW-Authenticate': 'Bearer'},
        )

    return CurrentUser(
        user_id=int(payload.get('sub', 0)),
        role=payload.get('role', 'user'),
        payload=payload,
    )


def optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> Optional[CurrentUser]:
    """
    依赖项：token 有效时注入用户信息，无 token 时返回 None（允许匿名访问）。

    用法：
        @router.get("/feed")
        def feed(user: Optional[CurrentUser] = Depends(optional_user)):
            if user:
                # 已登录
            else:
                # 匿名
    """
    if not credentials:
        return None

    payload = _verify_token(credentials.credentials)
    if not payload:
        return None

    return CurrentUser(
        user_id=int(payload.get('sub', 0)),
        role=payload.get('role', 'user'),
        payload=payload,
    )
