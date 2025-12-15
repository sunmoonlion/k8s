import type { AuthState,RefreshTokenRequest} from '@/types/auth/authapi';
import axios from 'axios'; 

export const refreshToken = async (refreshToken: RefreshTokenRequest): Promise<AuthState> => {
  try {
    // 如果 refreshToken 为 null，使用空字符串作为默认值
    const response = await axios.post('/token/refresh/', {
      refresh: refreshToken || '', // 如果是 null，传递空字符串
    });
    // 返回 { access, refresh } 两个字段
    return {
      token: response.data.token,
      refreshToken: response.data.refreshToken,
      userName: response.data.userName,
      userId: response.data.userId,
    };
  } catch (error) {
    console.error('刷新令牌失败', error);
    throw error; // 如果刷新失败，抛出错误
  }
};
