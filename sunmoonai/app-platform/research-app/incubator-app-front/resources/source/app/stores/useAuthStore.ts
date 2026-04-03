import type { AuthState } from '~/types/auth/authapi';

export const useAuthStore = defineStore('auth', {
  state: (): AuthState => ({
    token: null,
    refreshToken: null,
    userName: null,
    userId: null,
  }),

  actions: {
    setTokens(data: AuthState) {
      this.token = data.token;
      this.refreshToken = data.refreshToken;
      this.userName = data.userName;
      this.userId = data.userId;

      // 根据 userId 生成唯一的 key 来存储不同用户的数据
      const userKey = `user_${data.userId}`;

      // 保存到 localStorage，确保每个用户有独立的存储项
      localStorage.setItem(`${userKey}_token`, String(data.token));
      localStorage.setItem(`${userKey}_refresh_token`, String(data.refreshToken));
      localStorage.setItem(`${userKey}_username`, String(data.userName));
      localStorage.setItem(`${userKey}_user_id`, String(data.userId));
    },

    clearTokens() {
      if (this.userId) {
        const userKey = `user_${this.userId}`;
        // 清除特定用户的数据
        localStorage.removeItem(`${userKey}_token`);
        localStorage.removeItem(`${userKey}_refresh_token`);
        localStorage.removeItem(`${userKey}_username`);
        localStorage.removeItem(`${userKey}_user_id`);
      }

      // 清空 store 中的值
      this.token = null;
      this.refreshToken = null;
      this.userName = null;
      this.userId = null;
    },

    loadFromLocalStorage(userId: string) {
      const userKey = `user_${userId}`;
      this.token = localStorage.getItem(`${userKey}_token`);
      this.refreshToken = localStorage.getItem(`${userKey}_refresh_token`);
      this.userName = localStorage.getItem(`${userKey}_username`);
      this.userId = localStorage.getItem(`${userKey}_user_id`);
    }
  }
});
