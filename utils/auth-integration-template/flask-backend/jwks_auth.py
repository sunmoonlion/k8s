"""
JWKS-based JWT verification for auth-app RS256 tokens.
从 auth-app JWKS 端点获取公钥并缓存，验证 Bearer token。

依赖：
    pip install python-jose[cryptography] requests

Flask config 需要设置：
    AUTH_JWKS_URL      # 例：http://auth-app:3030/api/v1/jwks
    AUTH_JWT_ISSUER    # 例：http://auth-app:3030/api/v1
    AUTH_JWT_AUDIENCE  # 例：myapp-api（与 BFF login 时的 aud 参数一致）
"""
import time
import threading
import requests
from flask import request, g, current_app
from functools import wraps


# 公钥缓存（进程内，TTL 10 分钟）
_jwks_cache = {'keys': None, 'fetched_at': 0}
_jwks_lock = threading.Lock()
_JWKS_TTL = 600  # 秒


def _get_jwks():
    """从 auth-app 获取 JWKS 公钥，带本地缓存。"""
    now = time.time()
    with _jwks_lock:
        if _jwks_cache['keys'] and now - _jwks_cache['fetched_at'] < _JWKS_TTL:
            return _jwks_cache['keys']

    jwks_url = current_app.config.get('AUTH_JWKS_URL')
    if not jwks_url:
        raise RuntimeError('AUTH_JWKS_URL is not configured')

    resp = requests.get(jwks_url, timeout=5)
    resp.raise_for_status()
    keys = resp.json().get('keys', [])

    with _jwks_lock:
        _jwks_cache['keys'] = keys
        _jwks_cache['fetched_at'] = time.time()

    return keys


def verify_token(token):
    """
    验证 RS256 JWT，返回 payload dict。
    校验 aud（AUTH_JWT_AUDIENCE）和 iss（AUTH_JWT_ISSUER），失败时返回 None。
    """
    try:
        from jose import jwt as jose_jwt
        keys = _get_jwks()
        if not keys:
            return None

        audience = current_app.config.get('AUTH_JWT_AUDIENCE')
        issuer = current_app.config.get('AUTH_JWT_ISSUER')

        options = {}
        if not audience:
            # 未配置 audience 时关闭校验（开发阶段兜底）
            # 生产环境务必设置 AUTH_JWT_AUDIENCE
            options['verify_aud'] = False

        payload = jose_jwt.decode(
            token,
            {'keys': keys},
            algorithms=['RS256'],
            audience=audience or None,
            issuer=issuer or None,
            options=options,
        )
        return payload
    except Exception:
        return None


def login_required(func):
    """
    装饰器：要求请求携带有效的 Bearer token（auth-app RS256 JWT）。
    验证通过后，将以下内容写入 Flask g：
        g.user_id      (int)  JWT sub 字段
        g.user_payload (dict) 完整 JWT payload
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return {'message': 'Unauthorized'}, 401

        token = auth_header[len('Bearer '):]
        payload = verify_token(token)
        if not payload:
            return {'message': 'Invalid or expired token'}, 401

        g.user_id = int(payload.get('sub', 0))
        g.user_payload = payload
        return func(*args, **kwargs)

    return wrapper


def login_optional(func):
    """
    装饰器：token 有效时注入用户信息，无 token 时也放行（匿名访问）。
    无 token 或 token 无效时：g.user_id = None，g.user_payload = None
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        g.user_id = None
        g.user_payload = None

        auth_header = request.headers.get('Authorization', '')
        if auth_header.startswith('Bearer '):
            token = auth_header[len('Bearer '):]
            payload = verify_token(token)
            if payload:
                g.user_id = int(payload.get('sub', 0))
                g.user_payload = payload

        return func(*args, **kwargs)

    return wrapper
