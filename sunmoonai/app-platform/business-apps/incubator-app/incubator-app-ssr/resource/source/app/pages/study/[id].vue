<template>
    <div>
        id: {{ id }}
    </div>
</template>

<script setup lang="ts">
// 使用 definePageMeta 定义页面元数据
definePageMeta({
  layout: 'default'
})

// 使用 Nuxt 3 内置的 useRoute 获取路由参数
const route = useRoute()
const id = route.params.id as string
</script>

<style lang="scss" scoped>
</style>

