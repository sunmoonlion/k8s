<template>
  <el-badge :value="value">
    <slot>
      <Icon
        :icon="icon"
        :style="{ color: iconColor ?? '#333', fontSize: iconSize ? `${iconSize}px` : '18px' }"
      ></Icon>
    </slot>
  </el-badge>
</template>

<script setup lang="ts">
import Icon from '../Icons/Iconify.vue'
import type { NotificationProps } from './types'

const props = withDefaults(defineProps<NotificationProps>(), {
  icon: 'ep:bell',
  size: 12,
  scale: 1,
  color: ''
})
// translateX -> scale
function calculateTransform(scale: number) {
  // 定义scale和translateX的范围
  const minScale = 0.4
  const maxScale = 1
  const minTranslateX = 75 // 单位：%
  const maxTranslateX = 100 // 单位：%

  // 计算translateX的值
  const translateX =
    minTranslateX + (maxTranslateX - minTranslateX) * ((scale - minScale) / (maxScale - minScale))

  // 返回完整的transform属性值
  return {
    translateX: translateX,
    scale
  }
}

const transformData = computed(() => calculateTransform(props.scale))
const colorBg = computed(() => props.color || 'var(--el-color-danger)')
const contentFontSize = computed(() => props.size + 'px' || 'var(--el-badge-size)')
const translateX = computed(() => (transformData.value?.translateX || 100) + '%')
const contentScale = computed(() => transformData.value?.scale || 100)
</script>

<style lang="scss" scoped>
$color: var(--bg-color);
$size: var(--font-size);
$translate-x: var(--translate-x);
$scale: var(--scale);

:deep(.el-badge__content) {
  background-color: v-bind(colorBg);
  font-size: v-bind(contentFontSize);
  transform: translateY(-50%) translateX(v-bind(translateX)) scale(v-bind(contentScale));
}
</style>
