/**
 * GET /auth/callback
 * 接收 auth-app OIDC 回调：用 code 换 token，session 存 Redis，cookie 只写 sessionId
 *
 * 注意：此文件必须放在 server/routes/（不是 server/api/），
 * 因为 OAuth redirect_uri 是 /auth/callback，不含 /api 前缀。
 *
 * 接入新 app 时修改：
 *   - Cookie 名 {APP_NAME}_session 改为本 app 的名字
 *   - audience 与 login.get.ts 中 aud 参数保持一致
 */
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)
  const query  = getQuery(event)

  const code  = query.code  as string | undefined
  const state = query.state as string | undefined
  const error = query.error as string | undefined

  if (error) {
    return sendRedirect(event, `/api/auth/login?error=${encodeURIComponent(error as string)}`)
  }
  if (!code || !state) {
    return sendRedirect(event, '/api/auth/login?error=missing_params')
  }

  // 校验 state（防 CSRF）
  const savedState = getCookie(event, 'oidc_state')
  if (!savedState || savedState !== state) {
    return sendRedirect(event, '/api/auth/login?error=invalid_state')
  }

  // 取出 PKCE verifier
  const verifier = getCookie(event, 'oidc_verifier')
  if (!verifier) {
    return sendRedirect(event, '/api/auth/login?error=missing_verifier')
  }

  deleteCookie(event, 'oidc_state')
  deleteCookie(event, 'oidc_verifier')

  // 用 code 换 token
  const host        = getRequestHeader(event, 'host') || 'localhost:3000'
  const proto       = process.env.NODE_ENV === 'production' ? 'https' : 'http'
  const redirectUri = `${proto}://${host}/auth/callback`

  let tokenData: any
  try {
    tokenData = await $fetch(`${config.authBackendUrl}/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type:    'authorization_code',
        code,
        redirect_uri:  redirectUri,
        client_id:     config.authClientId,
        client_secret: config.authClientSecret,
        code_verifier: verifier,
        audience:      'myapp-api',   // ← 修改为本 app 的 audience
      }).toString(),
    })
  } catch (e: any) {
    const msg = e?.data?.error_description || e?.message || 'token_exchange_failed'
    return sendRedirect(event, `/api/auth/login?error=${encodeURIComponent(msg)}`)
  }

  // 生成 sessionId，将 token 存入 Redis（7 天 TTL）
  const sessionId = crypto.randomUUID()
  const session = {
    access_token:  tokenData.access_token,
    refresh_token: tokenData.refresh_token,
    expires_at:    Date.now() + (tokenData.expires_in ?? 900) * 1000,
  }
  const storage = useStorage('bff:sessions')
  await storage.setItem(sessionId, session, { ttl: 60 * 60 * 24 * 7 })

  // Cookie 只存 sessionId（HttpOnly，7 天）
  setCookie(event, 'myapp_session', sessionId, {   // ← 修改 Cookie 名
    httpOnly: true,
    secure:   process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge:   60 * 60 * 24 * 7,
    path:     '/',
  })

  return sendRedirect(event, '/')
})
