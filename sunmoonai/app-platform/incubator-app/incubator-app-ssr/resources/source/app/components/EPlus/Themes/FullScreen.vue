<template>
  <component
    :is="tag"
    @click="toggle"
    :class="[
      !isFullscreen ? 'i-ep:full-screen' : 'i-ri:fullscreen-exit-fill',
      'cursor-pointer',
      iconClass
    ]"
  ></component>
</template>

<script setup lang="ts">
const { isFullscreen, toggle } = useFullscreen()

defineProps({
  tag: {
    type: String,
    default: 'i'
  },
  iconClass: {
    type: String,
    default: 'text-xl'
  }
})
</script>

<style scoped></style>
