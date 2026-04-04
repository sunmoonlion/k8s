<template>
  <div>{{ message }}</div>
</template>

<script setup lang="ts">
/**
 * /auth/callback 页面
 * 把 URL 中的 code + state 转交给后端处理，后端完成 token 换取并写 session Cookie。
 *
 * 在 Vue Router 中注册此路由：
 *   { path: '/auth/callback', component: () => import('./pages/AuthCallback.vue') }
 */
import { handleCallback } from '@/composables/useAuth'

const message = ref('正在处理登录...')

onMounted(async () => {
  const ok = await handleCallback()
  if (ok) {
    const redirect = sessionStorage.getItem('auth_redirect') || '/'
    sessionStorage.removeItem('auth_redirect')
    location.href = redirect
  } else {
    message.value = '登录失败，请重试'
    setTimeout(() => { location.href = '/' }, 2000)
  }
})
</script>
