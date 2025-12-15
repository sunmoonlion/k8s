<template>
    <svg aria-hidden="true">
      <use :xlink:href="symbolId" :fill="color" />
    </svg>
  </template>
  
  <script lang="ts" setup>
  const props = defineProps({
    prefix: {
      type: String,
      default: 'icon'
    },
    type: {
      type: String,
      required: true
    },
    color: {
      type: String,
      default: 'currentColor'
    }
  })
  //// 如果svg文件直接位于src/assets/icons目录下，可以直接使用
  // const symbolId = computed(() => `#${props.prefix}-${props.type}`)
  // 如果svg文件位于src/assets/icons/svg目录下，可以将文件夹的名称后面的"/"替换为"-"
  // 从而保证与vite-plugin-svg-icons插件生成的symbolId一致
  // （因为在vite-config.ts中symbolId是这样配置的: 'icon-[dir]-[name]'）
  const symbolId = computed(() => `#${props.prefix}-${props.type.replace('/', '-')}`)
  </script>