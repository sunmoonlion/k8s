"""
Flask app 所需环境变量（在 .env 或 K8s Secret 中设置）

AUTH_BACKEND_URL     auth-app-backend API 前缀（含版本）
                     示例：http://auth:3030/api/v1

AUTH_CLIENT_ID       OAuth client_id
                     机密客户端（有 secret）推荐安全性更高

AUTH_CLIENT_SECRET   OAuth client_secret
                     public client 可留空，但建议使用机密客户端（secret 在服务端，安全）

AUTH_REDIRECT_URI    OAuth 回调地址——必须是 SPA 侧路由（浏览器能访问）
                     示例：https://myapp.example.com/auth/callback

AUTH_JWT_AUDIENCE    JWT audience 校验值，需与 register-client.sh 中 audience 一致
                     示例：myapp-api

AUTH_SESSION_COOKIE  浏览器 session Cookie 名（默认 myapp_session）
                     示例：toutiao_session

REDIS_URL            Redis 连接串
                     示例：redis://:password@redis-host:6379/0

NODE_ENV             production 时 Cookie 启用 Secure 标志（HTTPS 专属）
"""

# Flask app 工厂示例（含 CORS 和 Blueprint 注册）
#
# from flask import Flask
# from flask_cors import CORS
# from auth_routes import auth_bp
#
# def create_app():
#     app = Flask(__name__)
#
#     # 允许 SPA 开发服务器跨域（生产环境收紧）
#     CORS(app, origins=[os.environ.get('SPA_ORIGIN', 'http://localhost:5173')],
#          supports_credentials=True)
#
#     app.register_blueprint(auth_bp)
#     return app
