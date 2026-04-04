/**
 * useAuth — Vite SPA 登录态管理（调用自有后端，token 不落浏览器）
 *
 * ┌─────────────────────────────────────────────────────────────────┐
 * │  token 存在服务端 Redis，浏览器只持有 UUID session Cookie（HttpOnly）  │
 * │  SPA 侧无任何 token，XSS 无法窃取 access/refresh_token             │
 * └─────────────────────────────────────────────────────────────────┘
 *
 * 用法：
 *   const { user, isLoggedIn, login, logout } = useAuth()
 *
 * 需要对应的后端（三选一，见 vite-spa-backend/）：
 *   Flask   → vite-spa-backend/flask/auth_routes.py
 *   FastAPI → vite-spa-backend/fastapi/auth_router.py
 *   NestJS  → vite-spa-backend/nestjs/auth.controller.ts
 *
 * 接入新 app 时修改：
 *   - BFF_BASE_URL：自有后端地址（如 http://localhost:8000）
 *   - /auth/callback 页面确认调用了 handleCallback()
 */

const BFF_BASE_URL = import.meta.env.VITE_BFF_BASE_URL || ''  // 同源时留空

export interface UserProfile {
  id:              string
  email:           string
  full_name:       string
  email_validated: boolean
  is_active:       boolean
  is_superuser:    boolean
  role:            string
}

// ---- 全局单例状态 ----
const user      = ref<UserProfile | null>(null)
const isLoggedIn = computed(() => !!user.value)

export const useAuth = () => {
  return { user, isLoggedIn, login, logout, handleCallback, fetchUser }
}

// ---- 登录：跳转到后端 /api/auth/login，由后端生成 PKCE 并重定向 ----

export function login(): void {
  // 记录登录前页面，callback 后回跳
  sessionStorage.setItem('auth_redirect', location.pathname)
  location.href = `${BFF_BASE_URL}/api/auth/login`
}

// ---- 回调处理：在 /auth/callback 页面 onMounted 调用 ----
// 把 URL 中的 code + state POST 给后端，后端完成 token 换取

export async function handleCallback(): Promise<boolean> {
  const params = new URLSearchParams(location.search)
  const code   = params.get('code')
  const state  = params.get('state')
  const error  = params.get('error')

  if (error) {
    console.error('[auth] callback error:', error, params.get('error_description'))
    return false
  }
  if (!code || !state) return false

  try {
    const resp = await fetch(`${BFF_BASE_URL}/api/auth/callback`, {
      method:      'POST',
      headers:     { 'Content-Type': 'application/json' },
      credentials: 'include',   // 携带 Cookie（pkce 临时 Cookie + 写入 session Cookie）
      body:        JSON.stringify({ code, state }),
    })
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({}))
      console.error('[auth] callback failed:', err)
      return false
    }
    await fetchUser()
    return true
  } catch (e) {
    console.error('[auth] callback error:', e)
    return false
  }
}

// ---- 获取用户信息（页面加载时调用，恢复登录态） ----

export async function fetchUser(): Promise<void> {
  try {
    const resp = await fetch(`${BFF_BASE_URL}/api/auth/me`, {
      credentials: 'include',   // 携带 session Cookie
    })
    if (!resp.ok) {
      user.value = null
      return
    }
    user.value = await resp.json()
  } catch {
    user.value = null
  }
}

// ---- 登出 ----

export async function logout(): Promise<void> {
  try {
    await fetch(`${BFF_BASE_URL}/api/auth/logout`, {
      method:      'POST',
      credentials: 'include',
    })
  } catch {
    // 网络失败也要清本地状态
  }
  user.value = null
  location.href = '/'
}
