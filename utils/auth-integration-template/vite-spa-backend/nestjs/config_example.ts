/**
 * NestJS app 所需环境变量（.env 或 K8s Secret）
 *
 * AUTH_BACKEND_URL     auth-app-backend API 前缀（含版本）
 *                      示例：http://auth:3030/api/v1
 *
 * AUTH_CLIENT_ID       OAuth client_id
 *
 * AUTH_CLIENT_SECRET   OAuth client_secret（public client 可留空）
 *
 * AUTH_REDIRECT_URI    OAuth 回调地址——必须是 SPA 侧路由（浏览器能访问）
 *                      示例：https://myapp.example.com/auth/callback
 *
 * AUTH_JWT_AUDIENCE    JWT audience 校验值
 *                      示例：myapp-api
 *
 * AUTH_SESSION_COOKIE  浏览器 session Cookie 名（默认 myapp_session）
 *
 * REDIS_URL            Redis 连接串
 *                      示例：redis://:password@redis-host:6379/0
 *
 * NODE_ENV             production 时 Cookie 启用 Secure 标志
 */

// main.ts 示例（含 cookie-parser 和 CORS）
//
// import { NestFactory } from '@nestjs/core'
// import * as cookieParser from 'cookie-parser'
// import { AppModule } from './app.module'
//
// async function bootstrap() {
//   const app = await NestFactory.create(AppModule)
//
//   app.use(cookieParser())
//
//   app.enableCors({
//     origin:      process.env.SPA_ORIGIN || 'http://localhost:5173',
//     credentials: true,   // 允许 Cookie 跨域，必须为 true
//   })
//
//   await app.listen(3000)
// }
// bootstrap()
//
// 依赖（package.json）：
//   npm install cookie-parser
//   npm install -D @types/cookie-parser
