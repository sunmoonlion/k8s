/**
 * GET /api/auth/login
 * 发起 OIDC 授权：生成 state + PKCE code_verifier，重定向到 auth-app /authorize
 *
 * 接入新 app 时修改：
 *   - aud 参数改为本 app 的 audience（与 Python 后端 AUTH_JWT_AUDIENCE 一致）
 */
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)

  // 生成 state（防 CSRF）
  const state = crypto.randomUUID()

  // 生成 PKCE code_verifier + code_challenge（S256）
  const verifier = generateCodeVerifier()
  const challenge = await generateCodeChallenge(verifier)

  // 存入 HttpOnly Cookie（5 分钟有效，对齐授权码有效期）
  const cookieOpts = {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax' as const,
    maxAge: 60 * 5,
    path: '/',
  }
  setCookie(event, 'oidc_state', state, cookieOpts)
  setCookie(event, 'oidc_verifier', verifier, cookieOpts)

  // 构建 auth-app 授权 URL
  const authUrl = new URL(`${config.authBackendUrl}/authorize`)
  authUrl.searchParams.set('response_type', 'code')
  authUrl.searchParams.set('client_id', config.authClientId)
  authUrl.searchParams.set('redirect_uri', getRedirectUri(event))
  authUrl.searchParams.set('scope', 'openid profile email')
  authUrl.searchParams.set('state', state)
  authUrl.searchParams.set('code_challenge', challenge)
  authUrl.searchParams.set('code_challenge_method', 'S256')
  authUrl.searchParams.set('aud', 'myapp-api')   // ← 修改为本 app 的 audience

  return sendRedirect(event, authUrl.toString())
})

function getRedirectUri(event: any): string {
  const host = getRequestHeader(event, 'host') || 'localhost:3000'
  const proto = process.env.NODE_ENV === 'production' ? 'https' : 'http'
  return `${proto}://${host}/auth/callback`
}

function generateCodeVerifier(): string {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return base64urlEncode(array)
}

async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return base64urlEncode(new Uint8Array(digest))
}

function base64urlEncode(buffer: Uint8Array): string {
  return btoa(String.fromCharCode(...buffer))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')
}
