import type { AuthState } from '@/types/auth/authapi'
import { forwardToBackend, handleBackendError } from '../../utils/backend'

/**
 * 刷新 Token API - Nuxt 服务器端路由
 * 路径：POST /api/token/refresh
 */
export default defineEventHandler(async (event: any) => {
  try {
    // 读取请求体
    const body = await readBody<{ refresh: string }>(event)
    
    // 验证请求体
    if (!body.refresh) {
      throw createError({
        statusCode: 400,
        statusMessage: '刷新令牌不能为空',
      })
    }
    
    // 转发请求到后端
    const response = await forwardToBackend(event, '/token/refresh/', {
      method: 'POST',
      body: {
        refresh: body.refresh,
      },
    })
    
    // 返回响应数据
    return response as AuthState
  } catch (error: any) {
    return handleBackendError(error)
  }
})

