<template>
  <div class="flex flex-col items-center justify-center min-h-screen bg-gradient-to-r from-pink-100 to-blue-100">
    <!-- 图标容器 -->
    <div class="i-pepicons-pop:moon-circle text-blue-500 text-6xl mb-6"></div>
    
    <!-- 登录表单 -->
    <form method="post" class="w-full max-w-sm bg-white shadow-md rounded px-8 pt-6 pb-8 mb-4">
      <h1 class="text-xl font-bold text-center mb-6">用户登录</h1>
      <input type="text" name="username" placeholder="用户名" class="mb-4 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" autocomplete="off" v-model="username" @click="errshow = false">
      <input type="password" name="password" placeholder="密码" class="mb-4 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" v-model="password" @click="errshow = false">
      <div class="text-red-500 text-sm italic mb-4" v-show="errshow">{{ errmsg }}</div>
      <input type="button" value="登 录" 
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline w-full"
      @click="fnLogin">
    </form>
  </div>
</template>
<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import type { AuthState } from '@/types/auth/authapi';
import { useAuthStore } from '@/stores/useAuthStore';  // 导入 Pinia store

// 使用 definePageMeta 定义页面元数据
definePageMeta({
  layout: 'default'
})

const userName = ref('');
const passWord = ref('');
const errmsg = ref('');
const errshow = ref(false);
const router = useRouter();
const authStore = useAuthStore();  // 创建 Pinia store 实例

const fnLogin = async () => {
  if (!userName.value || !passWord.value) {
    errmsg.value = '用户名或密码不能为空';
    errshow.value = true;
    return;
  }

  try {
    // 使用 useFetch 调用 Nuxt 服务器端 API
    const { data, error } = await useFetch<AuthState>('/api/users/login', {
      method: 'POST',
      body: {
        userName: userName.value,
        passWord: passWord.value,
      },
    });

    if (error.value) {
      errmsg.value = error.value.message || '登录失败，请稍后再试';
      errshow.value = true;
      return;
    }

    if (data.value) {
      // 存储用户登录信息到 Pinia Store 和 localStorage
      authStore.setTokens({
        token: data.value.token,
        refreshToken: data.value.refreshToken,
        userName: data.value.userName,
        userId: data.value.userId,  // 使用不同的 userId 来区分不同用户
      });

      router.push({ path: '/' });
    }
  } catch (error) {
    errmsg.value = (error as Error).message;
    errshow.value = true;
  }
};
</script>

<style scoped>
/* 样式 */
</style>
