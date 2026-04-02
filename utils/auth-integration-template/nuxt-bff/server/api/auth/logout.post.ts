/**
 * POST /api/auth/logout
 * 通知 auth-app 撤销 token，清除本地会话 Cookie，重定向到首页
 *
 * 接入新 app 时修改：
 *   - Cookie 名 myapp_session 改为本 app 的名字
 */
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)

  const sessionStr = getCookie(event, 'myapp_session')   // ← 修改 Cookie 名
  if (sessionStr) {
    try {
      const session = JSON.parse(sessionStr)
      // 通知 auth-app 撤销 refresh_token（尽力而为，失败不阻断登出）
      await $fetch(`${config.authBackendUrl}/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: config.authClientId,
          client_secret: config.authClientSecret,
          refresh_token: session.refresh_token ?? '',
        }).toString(),
      }).catch(() => {})
    } catch {}
  }

  // 清除会话 Cookie
  deleteCookie(event, 'myapp_session', {   // ← 修改 Cookie 名
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
  })

  return sendRedirect(event, '/')
})
