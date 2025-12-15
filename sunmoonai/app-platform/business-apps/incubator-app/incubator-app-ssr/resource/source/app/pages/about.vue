<template>
  <div class="about">
    <h1>This is an about page</h1>
  </div>
</template>

<script lang="ts" setup>
import { RouterLink } from 'vue-router/auto'

// 使用 definePageMeta 定义页面元数据
definePageMeta({
  layout: 'default'
})
</script>

<style>
@media (min-width: 1024px) {
  .about {
    min-height: 100vh;
    display: flex;
    align-items: center;
  }
}
</style>