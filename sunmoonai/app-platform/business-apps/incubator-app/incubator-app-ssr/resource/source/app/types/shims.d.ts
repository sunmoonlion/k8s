// 用于声明静态文件类型，如 .png
declare module '*.png' {
  const value: string;
  export default value;
}

// 用于扩展 NuxtApp 类型，确保 $axios 拥有 AxiosInstance 类型
import { AxiosInstance } from 'axios';

declare module '#app' {
  interface NuxtApp {
    $axios: AxiosInstance;
  }
}

// assets.d.ts
declare module '*.svg' {
  const content: string;
  export default content;
}

