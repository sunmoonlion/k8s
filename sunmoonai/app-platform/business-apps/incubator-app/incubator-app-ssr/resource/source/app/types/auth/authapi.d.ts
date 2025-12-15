
// Token 响应的数据结构
interface AuthState {
  token: string | null;
  refreshToken: string | null;
  userName: string | null;
  userId: string | null;
}


// 刷新令牌的请求数据结构
export interface RefreshTokenRequest {
  refresh: string | null;
}

// src/types/auth/authapi.ts
export interface ErrorResponse {
detail?: string; // 后端返回的错误详情
code?: string; // 错误码（如果有的话）
// 可以根据实际情况扩展更多字段
}