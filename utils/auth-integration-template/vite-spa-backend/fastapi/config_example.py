"""
FastAPI app 所需环境变量（在 .env 或 K8s Secret 中设置）

AUTH_BACKEND_URL     auth-app-backend API 前缀（含版本）
                     示例：http://auth:3030/api/v1

AUTH_CLIENT_ID       OAuth client_id

AUTH_CLIENT_SECRET   OAuth client_secret（public client 可留空）

AUTH_REDIRECT_URI    OAuth 回调地址——必须是 SPA 侧路由（浏览器能访问）
                     示例：https://myapp.example.com/auth/callback

AUTH_JWT_AUDIENCE    JWT audience 校验值
                     示例：myapp-api

AUTH_SESSION_COOKIE  浏览器 session Cookie 名（默认 myapp_session）

REDIS_URL            Redis 连接串
                     示例：redis://:password@redis-host:6379/0

NODE_ENV             production 时 Cookie 启用 Secure 标志
"""

# FastAPI app 工厂示例（含 CORS 和 Router 注册）
#
# import os
# from fastapi import FastAPI
# from fastapi.middleware.cors import CORSMiddleware
# from auth_router import auth_router
#
# app = FastAPI()
#
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=[os.environ.get('SPA_ORIGIN', 'http://localhost:5173')],
#     allow_credentials=True,        # 允许携带 Cookie，必须为 True
#     allow_methods=['*'],
#     allow_headers=['*'],
# )
#
# app.include_router(auth_router)
