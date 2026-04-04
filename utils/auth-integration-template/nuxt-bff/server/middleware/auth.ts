/**
 * 服务端中间件：从 Redis 读取会话，注入用户上下文
 * access_token 临期（< 60 秒）时自动刷新并回写 Redis
 *
 * 接入新 app 时修改：
 *   - Cookie 名 myapp_session 改为本 app 的名字
 *   - audience 改为本 app 的 audience
 */
export default defineEventHandler(async (event) => {
  const sessionId = getCookie(event, 'myapp_session')   // ← 修改 Cookie 名
  if (!sessionId) return

  const storage = useStorage('bff:sessions')
  let session = await storage.getItem<{
    access_token: string
    refresh_token?: string
    expires_at: number
  }>(sessionId)

  if (!session) {
    deleteCookie(event, 'myapp_session')   // ← 修改 Cookie 名
    return
  }

  // access_token 还剩不足 60 秒时自动刷新
  const needsRefresh = session.expires_at - Date.now() < 60_000
  if (needsRefresh && session.refresh_token) {
    const config = useRuntimeConfig(event)
    try {
      const data: any = await $fetch(`${config.authBackendUrl}/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type:    'refresh_token',
          refresh_token: session.refresh_token,
          client_id:     config.authClientId,
          client_secret: config.authClientSecret,
          audience:      'myapp-api',   // ← 修改为本 app 的 audience
        }).toString(),
      })
      session = {
        access_token:  data.access_token,
        refresh_token: data.refresh_token ?? session.refresh_token,
        expires_at:    Date.now() + (data.expires_in ?? 900) * 1000,
      }
      // 回写 Redis（重置 TTL）
      await storage.setItem(sessionId, session, { ttl: 60 * 60 * 24 * 7 })
    } catch {
      // 刷新失败，清除会话
      await storage.removeItem(sessionId)
      deleteCookie(event, 'myapp_session')   // ← 修改 Cookie 名
      return
    }
  }

  // 将 access_token 注入请求上下文，server route 转发给后端时使用
  event.context.accessToken = session.access_token
})
