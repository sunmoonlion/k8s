// import zhCN from 'element-plus/dist/locale/zh-cn.mjs'
// import en from 'element-plus/dist/locale/en.mjs'

export default defineNuxtConfig({
  compatibilityDate: '2024-11-01',
  runtimeConfig: {
    // 私有配置（仅在服务器端可用）
    backendApiUrl: process.env.BACKEND_API_URL || 'http://47.100.19.119',
    // 公共配置（客户端和服务器端都可用）
    public: {
      // 如果需要在前端也使用，可以在这里配置
    }
  },
  devtools: { enabled: true },
  modules: [
    '@nuxt/content', 
    '@pinia/nuxt',
    'pinia-plugin-persistedstate/nuxt',
    '@unocss/nuxt',
    '@vueuse/nuxt',
    '@vite-pwa/nuxt',
    '@nuxt/icon',
    '@nuxt/eslint',
    '@element-plus/nuxt',
  ],
  icon: {
    serverBundle: {
      collections: ['uil', 'mdi']
    },
    customCollections: [
      {
        prefix: 'my-icon',
        dir: './assets/icons/svg',
      },
    ],
  },
  pwa: {   
    manifest: {
      name: 'Vite App',
      short_name: 'Vite App',
      theme_color: '#ffffff',
      icons: [
        {
          src: '/192x192.png',
          sizes: '192x192',
          type: 'image/png'
        },
        {
          src: '/512x512.png',
          sizes: '512x512',
          type: 'image/png'
        }
      ]
    },
    registerType: 'autoUpdate',
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.*']
    },
    devOptions: {
      enabled: false,
      suppressWarnings: true,
      navigateFallbackAllowlist: [/^\/$/],
      type: 'module'
    }
  },
  css: [
    '@unocss/reset/tailwind.css',
    
  ],
  elementPlus: { /** Options */ }
})
