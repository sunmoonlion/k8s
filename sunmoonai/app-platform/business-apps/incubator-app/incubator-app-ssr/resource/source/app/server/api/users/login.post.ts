import type { AuthState } from '@/types/auth/authapi'
import type { LoginRequest } from '@/types/users/loginapi'
import { forwardToBackend, handleBackendError } from '../../utils/backend'

/**
 * 登录 API - Nuxt 服务器端路由
 * 路径：POST /api/users/login
 */
export default defineEventHandler(async (event: any) => {
  try {
    // 读取请求体
    const body = await readBody<LoginRequest>(event)
    
    // 验证请求体
    if (!body.userName || !body.passWord) {
      throw createError({
        statusCode: 400,
        statusMessage: '用户名或密码不能为空',
      })
    }
    
    // 转发请求到后端
    const response = await forwardToBackend(event, '/api/login/', {
      method: 'POST',
      body: {
        userName: body.userName,
        passWord: body.passWord,
      },
    })
    
    // 返回响应数据
    return response as AuthState
  } catch (error: any) {
    return handleBackendError(error)
  }
})

