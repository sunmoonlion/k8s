"""
FastAPI auth Router — vite-spa BFF 后端
处理 OAuth PKCE 授权码流程，token 存 Redis，浏览器只持有 session UUID Cookie。

挂载到 FastAPI app：
    from auth_router import auth_router
    app.include_router(auth_router)

接入新 app 时修改：
    - 环境变量（见 config_example.py）
    - SESSION_COOKIE 改为本 app 的名字
"""

import base64
import hashlib
import json
import os
import secrets
import time
import uuid
import urllib.parse
from typing import Optional

import httpx
import redis.asyncio as aioredis
from fastapi import APIRouter, Cookie, HTTPException, Request, Response
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

# ─────────────────────────── 配置 ───────────────────────────
AUTH_BACKEND_URL = os.environ['AUTH_BACKEND_URL']
CLIENT_ID        = os.environ['AUTH_CLIENT_ID']
CLIENT_SECRET    = os.environ.get('AUTH_CLIENT_SECRET', '')
REDIRECT_URI     = os.environ['AUTH_REDIRECT_URI']
AUDIENCE         = os.environ.get('AUTH_JWT_AUDIENCE', 'myapp-api')  # ← 修改
SESSION_COOKIE   = os.environ.get('AUTH_SESSION_COOKIE', 'myapp_session')  # ← 修改
PKCE_COOKIE      = 'oidc_pkce'
IS_PROD          = os.environ.get('NODE_ENV') == 'production'

redis_client = aioredis.from_url(
    os.environ.get('REDIS_URL', 'redis://localhost:6379/0'),
    decode_responses=True,
)

auth_router = APIRouter(prefix='/api/auth', tags=['auth'])


# ─────────────────────────── 工具函数 ───────────────────────────

def _pkce_pair() -> tuple[str, str]:
    verifier  = base64.urlsafe_b64encode(os.urandom(32)).rstrip(b'=').decode()
    digest    = hashlib.sha256(verifier.encode()).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b'=').decode()
    return verifier, challenge


def _session_key(sid: str) -> str:
    return f'bff:sessions:{sid}'


def _pkce_key(pid: str) -> str:
    return f'bff:pkce:{pid}'


async def _get_session(session_id: str) -> dict | None:
    raw = await redis_client.get(_session_key(session_id))
    return json.loads(raw) if raw else None


async def _refresh_session(session_id: str, session: dict) -> dict | None:
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
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
            await redis_client.setex(_session_key(session_id), 7 * 24 * 3600, json.dumps(session))
            return session
        except Exception:
            await redis_client.delete(_session_key(session_id))
            return None


# ─────────────────────────── GET /api/auth/login ───────────────────────────

@auth_router.get('/login')
async def login(response: Response) -> RedirectResponse:
    """
    生成 PKCE，verifier 存 Redis（5 分钟），重定向到 auth-app 登录页。
    """
    verifier, challenge = _pkce_pair()
    state   = secrets.token_urlsafe(32)
    pkce_id = str(uuid.uuid4())

    await redis_client.setex(_pkce_key(pkce_id), 300, json.dumps({
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

    redirect_resp = RedirectResponse(url=f'{AUTH_BACKEND_URL}/authorize?{params}')
    redirect_resp.set_cookie(
        PKCE_COOKIE, pkce_id,
        httponly=True, samesite='lax',
        max_age=300, secure=IS_PROD,
    )
    return redirect_resp


# ─────────────────────────── POST /api/auth/callback ───────────────────────────

class CallbackBody(BaseModel):
    code:  str
    state: str


@auth_router.post('/callback')
async def callback(
    body:    CallbackBody,
    request: Request,
    response: Response,
    oidc_pkce: Optional[str] = Cookie(default=None, alias=PKCE_COOKIE),
) -> dict:
    """
    SPA 在 /auth/callback 页面取得 code + state 后，POST 到这里。
    """
    if not oidc_pkce:
        raise HTTPException(400, detail='missing pkce cookie')

    pkce_raw = await redis_client.get(_pkce_key(oidc_pkce))
    if not pkce_raw:
        raise HTTPException(400, detail='pkce session expired or not found')

    pkce = json.loads(pkce_raw)
    await redis_client.delete(_pkce_key(oidc_pkce))

    if pkce['state'] != body.state:
        raise HTTPException(400, detail='state mismatch')

    # code 换 token
    async with httpx.AsyncClient() as client:
        try:
            token_resp = await client.post(
                f'{AUTH_BACKEND_URL}/token',
                data={
                    'grant_type':    'authorization_code',
                    'code':          body.code,
                    'redirect_uri':  REDIRECT_URI,
                    'client_id':     CLIENT_ID,
                    'client_secret': CLIENT_SECRET,
                    'code_verifier': pkce['verifier'],
                    'audience':      AUDIENCE,
                },
                timeout=10,
            )
            token_resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            err = e.response.json() if e.response else {}
            raise HTTPException(502, detail=err.get('error_description', 'token exchange failed'))

    token_data = token_resp.json()
    session_id = str(uuid.uuid4())
    session    = {
        'access_token':  token_data['access_token'],
        'refresh_token': token_data.get('refresh_token'),
        'expires_at':    int(time.time() * 1000) + token_data.get('expires_in', 900) * 1000,
    }
    await redis_client.setex(_session_key(session_id), 7 * 24 * 3600, json.dumps(session))

    response.set_cookie(
        SESSION_COOKIE, session_id,
        httponly=True, samesite='lax',
        max_age=7 * 24 * 3600, path='/',
        secure=IS_PROD,
    )
    response.delete_cookie(PKCE_COOKIE)
    return {'ok': True}


# ─────────────────────────── GET /api/auth/me ───────────────────────────

@auth_router.get('/me')
async def me(
    request:  Request,
    response: Response,
) -> dict:
    """返回当前登录用户信息，必要时自动刷新 access_token。"""
    session_id = request.cookies.get(SESSION_COOKIE)
    if not session_id:
        raise HTTPException(401, detail='not authenticated')

    session = await _get_session(session_id)
    if not session:
        raise HTTPException(401, detail='session expired')

    if session['expires_at'] - time.time() * 1000 < 60_000 and session.get('refresh_token'):
        session = await _refresh_session(session_id, session)
        if not session:
            response.delete_cookie(SESSION_COOKIE, path='/')
            raise HTTPException(401, detail='session refresh failed')

    async with httpx.AsyncClient() as client:
        user_resp = await client.get(
            f'{AUTH_BACKEND_URL}/auth/me',
            headers={'Authorization': f'Bearer {session["access_token"]}'},
            timeout=10,
        )
        if user_resp.status_code == 401:
            await redis_client.delete(_session_key(session_id))
            raise HTTPException(401, detail='token invalid or expired')
        user_resp.raise_for_status()

    return user_resp.json()


# ─────────────────────────── POST /api/auth/logout ───────────────────────────

@auth_router.post('/logout')
async def logout(
    request:  Request,
    response: Response,
) -> dict:
    """撤销 refresh_token，删除 Redis session，清除 Cookie。"""
    session_id = request.cookies.get(SESSION_COOKIE)
    if session_id:
        session = await _get_session(session_id)
        if session and session.get('refresh_token'):
            async with httpx.AsyncClient() as client:
                try:
                    await client.post(
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
        await redis_client.delete(_session_key(session_id))

    response.delete_cookie(SESSION_COOKIE, path='/')
    return {'ok': True}
