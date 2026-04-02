/**
 * nuxt.config.ts 中 runtimeConfig 的片段。
 * 将以下内容合并到项目的 nuxt.config.ts 中。
 *
 * 环境变量（在 .env 或 K8s Secret 中设置）：
 *   AUTH_BACKEND_URL    auth-app-backend 的 API 前缀
 *   AUTH_CLIENT_ID      OAuth client_id（在 auth-app 注册时确定）
 *   AUTH_CLIENT_SECRET  OAuth client_secret（在 auth-app 注册时确定）
 *   SESSION_SECRET      会话加密密钥（随机 32 位字符串，生产必须更换）
 */
export default defineNuxtConfig({
  runtimeConfig: {
    // 以下变量仅在服务端可见（不暴露给浏览器）
    authBackendUrl: process.env.AUTH_BACKEND_URL || 'http://localhost:3030/api/v1',
    authClientId: process.env.AUTH_CLIENT_ID || 'myapp-bff',         // ← 修改
    authClientSecret: process.env.AUTH_CLIENT_SECRET || '',
    sessionSecret: process.env.SESSION_SECRET || 'dev-session-secret-change-in-prod',

    public: {
      // 前端可见（用于触发登录跳转的路径，不含 secret）
      authCallbackPath: '/auth/callback',
    },
  },
})
