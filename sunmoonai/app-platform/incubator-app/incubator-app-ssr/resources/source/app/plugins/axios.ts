import axios from 'axios';  // 导入 axios 实例
import { useAuthStore } from '@/stores/useAuthStore'; // 引入 Pinia store
import { getCSRFToken } from '@/server/utils/csrf'; // 获取 CSRF Token 工具函数
import { useRouter } from 'vue-router'; // 导入 useRouter 钩子
import type { AuthState } from '@/types/auth/authapi'; // 导入类型

// 创建 Axios 实例（TypeScript 自动推导类型）
const instance = axios.create({
  baseURL: 'http://47.100.19.119/', // 后端 API 地址
  timeout: 10000, // 请求超时
});

// 请求拦截器：自动携带 Authorization 和 CSRF token
instance.interceptors.request.use(
  (config) => {
    const csrfToken = getCSRFToken();
    const authStore = useAuthStore();

    if (authStore.token) {
      config.headers['Authorization'] = `Bearer ${authStore.token}`;
    }

    if (csrfToken) {
      config.headers['X-CSRFToken'] = csrfToken;
    }

    return config;
  },
  (error) => Promise.reject(error)
);

// 响应拦截器：处理 401 错误（未授权），自动刷新 token
instance.interceptors.response.use(
  (response) => response,
  async (error) => {
    const { config, response } = error;
    const router = useRouter();
    const authStore = useAuthStore(); // 在拦截器中获取 store
    if (response && response.status === 401 && !config.__isRetryRequest) {
      config.__isRetryRequest = true;

      try {
        if (authStore.refreshToken) {
          // 使用服务器端 API 刷新 token（在客户端使用 $fetch）
          const data = await $fetch<AuthState>('/api/token/refresh', {
            method: 'POST',
            body: {
              refresh: authStore.refreshToken,
            },
          });

          authStore.setTokens(data);
          config.headers['Authorization'] = `Bearer ${data.token}`;
          return instance(config); // 重新发起请求
        } else {
          throw new Error('Refresh token is null');
        }
      } catch (refreshError) {
        console.error('令牌刷新失败', refreshError);
        authStore.clearTokens();
        router.push({ path: '/login' });
      }
    }
    return Promise.reject(error);
  }
);

// 将 axios 实例提供给 Nuxt 应用
export default defineNuxtPlugin(nuxtApp => {
  // 提供 axios 实例
  nuxtApp.provide('axios', instance);
});
