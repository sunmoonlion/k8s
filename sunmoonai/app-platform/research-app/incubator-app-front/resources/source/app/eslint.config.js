import withNuxt from './.nuxt/eslint.config.mjs'
import pluginVue from 'eslint-plugin-vue'
import vueTsEslintConfig from '@vue/eslint-config-typescript'
import pluginVitest from 'eslint-plugin-vitest'
import pluginCypress from 'eslint-plugin-cypress/flat'
import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'
import eslintConfigPrettier from 'eslint-config-prettier'

// 使用 withNuxt 来合并默认的 Nuxt 配置与自定义规则
export default withNuxt(
  // 自定义规则
  {
    name: 'app/files-to-lint',
    files: [
      '**/*.{ts,mts,tsx,vue}',
      'pages/**/*.{ts,vue}',
      'components/**/*.{ts,vue}',
      'layouts/**/*.{ts,vue}',
      'server/**/*.{ts,vue}'
    ]
  },
  {
    name: 'app/files-to-ignore',
    ignores: ['**/dist/**', '**/dist-front/**', '**/coverage/**']
  },
  
  // 合并 Vue 配置
  ...pluginVue.configs['flat/essential'],

  // 使用 @vue/eslint-config-typescript 配置
  vueTsEslintConfig(),

  // 使用 Vitest 配置
  {
    ...pluginVitest.configs.recommended,
    files: ['src/**/__tests__/*']
  },

  // 使用 Cypress 配置
  {
    ...pluginCypress.configs.recommended,
    files: ['cypress/e2e/**/*.{cy,spec}.{js,ts,jsx,tsx}', 'cypress/support/**/*.{js,ts,jsx,tsx}']
  },

  // 使用 Prettier 配置
  skipFormatting,
  eslintConfigPrettier,

  // 禁用特定规则
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-empty-object-type': 'off',
      '@typescript-eslint/triple-slash-reference': 'off',
      '@typescript-eslint/ban-ts-comment': 'off',
      'vue/multi-word-component-names': 'off'
    }
  }
)
