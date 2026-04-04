"""
Flask auth Blueprint — vite-spa BFF 后端
处理 OAuth PKCE 授权码流程，token 存 Redis，浏览器只持有 session UUID Cookie。

挂载到 Flask app：
    from auth_routes import auth_bp
    app.register_blueprint(auth_bp)

接入新 app 时修改：
    - 环境变量（见 config_example.py）
    - SESSION_COOKIE 改为本 app 的名字（如 myapp_session）
"""

import base64
import hashlib
import json
import os
import secrets
import time
import uuid
import urllib.parse

import redis
import requests
from flask import Blueprint, abort, jsonify, redirect, request

# ─────────────────────────── 配置 ───────────────────────────
AUTH_BACKEND_URL = os.environ['AUTH_BACKEND_URL']          # http://auth:3030/api/v1
CLIENT_ID        = os.environ['AUTH_CLIENT_ID']            # myapp-bff（confidential）或 myapp-spa（public）
CLIENT_SECRET    = os.environ.get('AUTH_CLIENT_SECRET', '') # public client 留空
REDIRECT_URI     = os.environ['AUTH_REDIRECT_URI']         # https://myapp.com/auth/callback（SPA 侧路由）
AUDIENCE         = os.environ.get('AUTH_JWT_AUDIENCE', 'myapp-api')  # ← 修改
SESSION_COOKIE   = os.environ.get('AUTH_SESSION_COOKIE', 'myapp_session')  # ← 修改
PKCE_COOKIE      = 'oidc_pkce'
IS_PROD          = os.environ.get('NODE_ENV') == 'production'

redis_client = redis.from_url(
    os.environ.get('REDIS_URL', 'redis://localhost:6379/0'),
    decode_responses=True,
)

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')


# ─────────────────────────── 工具函数 ───────────────────────────

def _pkce_pair() -> tuple[str, str]:
    """返回 (code_verifier, code_challenge)"""
    verifier  = base64.urlsafe_b64encode(os.urandom(32)).rstrip(b'=').decode()
    digest    = hashlib.sha256(verifier.encode()).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b'=').decode()
    return verifier, challenge


def _session_key(sid: str) -> str:
    return f'bff:sessions:{sid}'


def _pkce_key(pid: str) -> str:
    return f'bff:pkce:{pid}'


def _get_session(session_id: str) -> dict | None:
    raw = redis_client.get(_session_key(session_id))
    return json.loads(raw) if raw else None


def _refresh_session(session_id: str, session: dict) -> dict | None:
    """用 refresh_token 换新 access_token，回写 Redis。失败返回 None。"""
    try:
        resp = requests.post(
            f'{AUTH_BACKEND_URL}/token',
            data={
                'grant_type':    'refresh_token',
                'refresh_token': session['refresh_token'],
                'client_id':     CLIENT_ID,
                'client_secret': CLIENT_SECRET,
                'audience':      AUDIENCE,
            },
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        session.update({
            'access_token':  data['access_token'],
            'refresh_token': data.get('refresh_token', session['refresh_token']),
            'expires_at':    int(time.time() * 1000) + data.get('expires_in', 900) * 1000,
        })
        redis_client.setex(_session_key(session_id), 7 * 24 * 3600, json.dumps(session))
        return session
    except Exception:
        redis_client.delete(_session_key(session_id))
        return None


# ─────────────────────────── GET /api/auth/login ───────────────────────────

@auth_bp.get('/login')
def login():
    """
    生成 PKCE，将 verifier 存 Redis（5 分钟），重定向浏览器到 auth-app 登录页。
    pkce_id 通过 HttpOnly Cookie 带回给 /callback。
    """
    verifier, challenge = _pkce_pair()
    state   = secrets.token_urlsafe(32)
    pkce_id = str(uuid.uuid4())

    redis_client.setex(_pkce_key(pkce_id), 300, json.dumps({
        'state':    state,
        'verifier': verifier,
    }))

    params = urllib.parse.urlencode({
        'response_type':         'code',
        'client_id':             CLIENT_ID,
        'redirect_uri':          REDIRECT_URI,
        'scope':                 'openid profile email',
        'state':                 state,
        'code_challenge':        challenge,
        'code_challenge_method': 'S256',
        'aud':                   AUDIENCE,
    })

    resp = redirect(f'{AUTH_BACKEND_URL}/authorize?{params}')
    resp.set_cookie(
        PKCE_COOKIE, pkce_id,
        httponly=True, samesite='Lax',
        max_age=300, secure=IS_PROD,
    )
    return resp


# ─────────────────────────── POST /api/auth/callback ───────────────────────────

@auth_bp.post('/callback')
def callback():
    """
    SPA 在 /auth/callback 页面取得 code + state 后，POST 到这里。
    后端用 Redis 中的 verifier 换 token，写入 Redis session，设 HttpOnly Cookie。

    请求体（JSON）：{ "code": "...", "state": "..." }
    """
    body  = request.get_json(force=True, silent=True) or {}
    code  = body.get('code')
    state = body.get('state')

    if not code or not state:
        abort(400, description='missing code or state')

    pkce_id = request.cookies.get(PKCE_COOKIE)
    if not pkce_id:
        abort(400, description='missing pkce cookie')

    pkce_raw = redis_client.get(_pkce_key(pkce_id))
    if not pkce_raw:
        abort(400, description='pkce session expired or not found')

    pkce = json.loads(pkce_raw)
    redis_client.delete(_pkce_key(pkce_id))

    if pkce['state'] != state:
        abort(400, description='state mismatch')

    # code 换 token
    try:
        token_resp = requests.post(
            f'{AUTH_BACKEND_URL}/token',
            data={
                'grant_type':    'authorization_code',
                'code':          code,
                'redirect_uri':  REDIRECT_URI,
                'client_id':     CLIENT_ID,
                'client_secret': CLIENT_SECRET,
                'code_verifier': pkce['verifier'],
                'audience':      AUDIENCE,
            },
            timeout=10,
        )
        token_resp.raise_for_status()
    except requests.HTTPError as e:
        err = e.response.json() if e.response is not None else {}
        abort(502, description=err.get('error_description', 'token exchange failed'))

    token_data = token_resp.json()
    session_id = str(uuid.uuid4())
    session    = {
        'access_token':  token_data['access_token'],
        'refresh_token': token_data.get('refresh_token'),
        'expires_at':    int(time.time() * 1000) + token_data.get('expires_in', 900) * 1000,
    }
    redis_client.setex(_session_key(session_id), 7 * 24 * 3600, json.dumps(session))

    resp = jsonify({'ok': True})
    resp.set_cookie(
        SESSION_COOKIE, session_id,
        httponly=True, samesite='Lax',
        max_age=7 * 24 * 3600, path='/',
        secure=IS_PROD,
    )
    resp.delete_cookie(PKCE_COOKIE)
    return resp


# ─────────────────────────── GET /api/auth/me ───────────────────────────

@auth_bp.get('/me')
def me():
    """
    返回当前登录用户信息。读 Redis session，必要时自动刷新 access_token。
    """
    session_id = request.cookies.get(SESSION_COOKIE)
    if not session_id:
        abort(401, description='not authenticated')

    session = _get_session(session_id)
    if not session:
        abort(401, description='session expired')

    # access_token 不足 60 秒时刷新
    if session['expires_at'] - time.time() * 1000 < 60_000 and session.get('refresh_token'):
        session = _refresh_session(session_id, session)
        if not session:
            resp = jsonify({'error': 'session refresh failed'})
            resp.status_code = 401
            resp.delete_cookie(SESSION_COOKIE, path='/')
            return resp

    user_resp = requests.get(
        f'{AUTH_BACKEND_URL}/auth/me',
        headers={'Authorization': f'Bearer {session["access_token"]}'},
        timeout=10,
    )
    if user_resp.status_code == 401:
        redis_client.delete(_session_key(session_id))
        abort(401, description='token invalid or expired')
    user_resp.raise_for_status()

    return jsonify(user_resp.json())


# ─────────────────────────── POST /api/auth/logout ───────────────────────────

@auth_bp.post('/logout')
def logout():
    """撤销 refresh_token，删除 Redis session，清除 Cookie。"""
    session_id = request.cookies.get(SESSION_COOKIE)
    if session_id:
        session = _get_session(session_id)
        if session and session.get('refresh_token'):
            # 通知 auth-app 撤销 refresh_token（尽力而为）
            try:
                requests.post(
                    f'{AUTH_BACKEND_URL}/logout',
                    data={
                        'client_id':     CLIENT_ID,
                        'client_secret': CLIENT_SECRET,
                        'refresh_token': session['refresh_token'],
                    },
                    timeout=5,
                )
            except Exception:
                pass
        redis_client.delete(_session_key(session_id))

    resp = jsonify({'ok': True})
    resp.delete_cookie(SESSION_COOKIE, path='/')
    return resp
