/**
 * Vue Router 鉴权守卫
 *
 * 用法（在 router/index.ts 中）：
 *   import { setupAuthGuard } from './authGuard'
 *   setupAuthGuard(router)
 *
 * 在需要登录的路由上加 meta.requiresAuth = true：
 *   { path: '/dashboard', component: Dashboard, meta: { requiresAuth: true } }
 */
import type { Router } from 'vue-router'
import { isLoggedIn, refreshToken, login } from '@/composables/useAuth'

export function setupAuthGuard(router: Router) {
  router.beforeEach(async (to) => {
    if (!to.meta.requiresAuth) return true

    // 已有 access_token（内存中）
    if (isLoggedIn.value) return true

    // 尝试用 refresh_token 静默恢复
    const restored = await refreshToken()
    if (restored) return true

    // 无法恢复，跳转登录
    sessionStorage.setItem('auth_redirect', to.fullPath)
    login()
    return false
  })
}
