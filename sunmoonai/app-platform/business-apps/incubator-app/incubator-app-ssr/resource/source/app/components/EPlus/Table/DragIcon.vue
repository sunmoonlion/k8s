<template>
  <div class="flex items-center drag-btn">
    <i :class="['cursor-grab mr-2', icon]"></i>
    <slot></slot>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ icon: string }>(), {
  icon: 'i-icon-park-outline:drag'
})
</script>
