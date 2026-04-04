/**
 * POST /api/auth/logout
 * 通知 auth-app 撤销 token，删除 Redis session，清除 Cookie
 *
 * 接入新 app 时修改：
 *   - Cookie 名 myapp_session 改为本 app 的名字
 */
export default defineEventHandler(async (event) => {
  const config    = useRuntimeConfig(event)
  const sessionId = getCookie(event, 'myapp_session')   // ← 修改 Cookie 名

  if (sessionId) {
    const storage = useStorage('bff:sessions')
    const session = await storage.getItem<{ refresh_token?: string }>(sessionId)

    if (session?.refresh_token) {
      // 通知 auth-app 撤销 refresh_token（尽力而为，失败不阻断登出）
      await $fetch(`${config.authBackendUrl}/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id:     config.authClientId,
          client_secret: config.authClientSecret,
          refresh_token: session.refresh_token,
        }).toString(),
      }).catch(() => {})
    }

    await storage.removeItem(sessionId)
  }

  deleteCookie(event, 'myapp_session', {   // ← 修改 Cookie 名
    httpOnly: true,
    secure:   process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path:     '/',
  })

  return { ok: true }
})
