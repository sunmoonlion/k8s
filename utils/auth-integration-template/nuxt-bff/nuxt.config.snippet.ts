/**
 * nuxt.config.ts 中需要合并的片段。
 *
 * 环境变量（在 .env 或 K8s Secret 中设置）：
 *   AUTH_BACKEND_URL    auth-app-backend 的 API 前缀（含版本，如 http://auth:3030/api/v1）
 *   AUTH_CLIENT_ID      OAuth client_id
 *   AUTH_CLIENT_SECRET  OAuth client_secret
 *   SESSION_SECRET      会话加密密钥（随机 32 位字符串，生产必须更换）
 *   REDIS_URL           Redis 连接串（格式：redis://:<password>@<host>:<port>/<db>）
 *                       不设置时退回内存 driver，仅单实例开发可用
 */
export default defineNuxtConfig({
  nitro: {
    storage: process.env.REDIS_URL
      ? { 'bff:sessions': { driver: 'redis', url: process.env.REDIS_URL, base: 'bff:{APP_NAME}:' } }
      : {},  // 无 REDIS_URL 时 Nitro 自动回退到内存 driver
  },

  runtimeConfig: {
    // 以下变量仅在服务端可见（不暴露给浏览器）
    authBackendUrl: process.env.AUTH_BACKEND_URL || 'http://localhost:3030/api/v1',
    authClientId:     process.env.AUTH_CLIENT_ID     || 'myapp-bff',   // ← 修改
    authClientSecret: process.env.AUTH_CLIENT_SECRET || '',
    sessionSecret:    process.env.SESSION_SECRET     || 'dev-session-secret-change-in-prod',

    public: {
      authCallbackPath: '/auth/callback',
    },
  },
})
