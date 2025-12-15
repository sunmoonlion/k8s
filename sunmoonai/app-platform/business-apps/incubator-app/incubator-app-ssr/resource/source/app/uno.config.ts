// uno.config.ts
import { defineConfig } from 'unocss'
import { presetWind,presetIcons,transformerDirectives,transformerVariantGroup} from 'unocss'

export default defineConfig({
  rules: [
    ['display-none', { display: 'none' }],
    ['display-block', { display: 'block' }],
  ],
  // 全局经常要使用的样式，可以通过 shortcuts 配置快捷方式
  shortcuts: {
    'bg-image': 'w-full h-full bg-cover bg-no-repeat bg-center-top',
    btn: 'px-4 py-2 bg-sky-400 text-white hover:bg-sky-500 cursor-pointer',
    'btn-plain':
      'px-4 py-2 border border-sky-400 text-sky-400 hover:(bg-sky-400 text-white) cursor-pointer'
    // 'btn-sm'
    // 'btn-large'
    // 'btn-default'
    // btn-danger btn-success btn-info btn-warning
  },
  presets: [
    presetWind(), presetIcons(
      {
        prefix: 'i-',
        extraProperties:
        {
          'display': 'inline-block',
          'vertical-align': 'middle'
        },
        autoInstall: true
      }
    )
  ],
  transformers: [
    transformerDirectives(),
    transformerVariantGroup(),
  ]
})