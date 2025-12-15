<template>
  <div ref="chartRef" :style="chartStyle"></div>
</template>

<script setup lang="ts">
import type { EChartsOption, ECharts } from 'echarts'
import * as echarts from 'echarts'
import type { ChartsProps } from './types'

const props = withDefaults(defineProps<ChartsProps>(), {
  autoresize: true
})
const attrs = useAttrs()

const chartRef = shallowRef()
const chartInstance = shallowRef<ECharts>()

const emits = defineEmits(['init'])

const chartStyle = computed(() => {
  // 直接设置到charts组件上的style属性
  const style = attrs.style || {}
  const width = formatDimension(props.width, '100%')
  const height = formatDimension(props.height, '400px')
  return {
    width,
    height,
    ...style
  }
})

watch(
  () => props.options,
  (newOptions) => {
    chartInstance.value?.setOption(newOptions as EChartsOption)
  },
  {
    deep: true
  }
)

const fn = useThrottleFn(resize, 50)

onMounted(() => {
  initChart()

  if (props.autoresize) {
    window.addEventListener('resize', fn)
  }
})

onBeforeUnmount(() => {
  chartInstance.value && chartInstance.value?.dispose()
  if (props.autoresize) {
    window.removeEventListener('resize', fn)
  }
})

function formatDimension(value: string | number | undefined, defaultValue: string) {
  if (typeof value === 'number') {
    return `${value}px`
  }
  return value || defaultValue
}

function initChart() {
  if (chartRef.value) {
    chartInstance.value = echarts.init(chartRef.value)
    chartInstance.value.setOption(props.options as EChartsOption)
    emits('init', chartInstance.value)
  }
}

function resize() {
  if (chartInstance.value) {
    chartInstance.value.resize()
  }
}
</script>

<style scoped></style>
