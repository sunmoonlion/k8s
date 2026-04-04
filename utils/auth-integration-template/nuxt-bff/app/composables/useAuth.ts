/**
 * useAuth — 前端登录态管理
 *
 * 用法：
 *   const { user, isLoggedIn, login, logout } = useAuth()
 *
 * 注意：useFetch 在 SSR 阶段不会自动携带浏览器 Cookie，
 * 必须用 useRequestHeaders(['cookie']) 显式转发，否则服务端渲染永远显示未登录。
 *
 * 接入新 app 时修改：
 *   - UserProfile 接口字段与 auth-app-backend /auth/me 返回值对齐
 */

export interface UserProfile {
  id: string
  email: string
  full_name: string
  email_validated: boolean
  is_active: boolean
  is_superuser: boolean
  password: boolean
  totp: boolean
}

export const useAuth = () => {
  // SSR 阶段必须将浏览器 Cookie 转发给内部 API，否则服务端拿不到 session
  const headers = useRequestHeaders(['cookie'])

  const { data: user, error, refresh } = useFetch<UserProfile>('/api/auth/me', {
    headers,
    onResponseError({ response }) {
      if (response.status !== 401) {
        console.error('[useAuth] unexpected error', response.status)
      }
    },
  })

  const isLoggedIn = computed(() => !!user.value && !error.value)

  function login(redirectTo?: string) {
    const params = redirectTo ? `?redirect=${encodeURIComponent(redirectTo)}` : ''
    navigateTo(`/api/auth/login${params}`, { external: true })
  }

  async function logout() {
    await $fetch('/api/auth/logout', { method: 'POST' })
    user.value = null
    navigateTo('/')
  }

  return { user, isLoggedIn, login, logout, refresh }
}
