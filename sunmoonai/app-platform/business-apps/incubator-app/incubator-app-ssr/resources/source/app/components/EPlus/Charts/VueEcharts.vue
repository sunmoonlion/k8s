<template>
  <v-chart v-bind="props" :style="computedStyle" />
</template>

<script setup lang="ts">
import type { VueEchartsProps } from './types'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import * as Charts from 'echarts/charts'
import * as ChartsComponents from 'echarts/components'
import * as ChartsFeatures from 'echarts/features'
import VChart from 'vue-echarts'
import { COMPONENTS_MAP, CHARTS_MAP } from './const'

const props = withDefaults(defineProps<VueEchartsProps>(), {
  autoresize: true,
  theme: 'default',
  height: '400px'
  // charts: 'PieChart',
  // components: () => [
  //   'TitleComponent',
  //   'TooltipComponent',
  //   'LegendComponent',
  //   'AriaComponent',
  //   'GridComponent'
  // ]
})

const computedStyle = computed(() => {
  let result = {} as Record<string, any>
  const { theme, style, height } = props
  if (theme && theme.startsWith('#')) {
    result = { backgroundColor: theme }
  }
  result.height = typeof height === 'number' ? `${height}px` : height
  return { ...style, ...result }
})

if (import.meta.env.MODE !== 'production') {
  onBeforeMount(() => {
    let deps: string[] = []
    if (props.option) {
      Object.keys(props.option).forEach((key) => {
        if (COMPONENTS_MAP[key]) {
          deps.push(COMPONENTS_MAP[key])
        }
      })
    }

    if (props.components) {
      deps = props.components
    }

    let type = 'pie'
    let features: string[] = []
    let series = Array.isArray(props.option.series) ? props.option.series[0] : props.option.series

    if (series) {
      type = series.type || 'pie'

      if (series.labelLayout) {
        features.push('LabelLayout')
      }
      if (series.universalTransition) {
        features.push('UniversalTransition')
      }
    }

    use([
      CanvasRenderer,
      Charts[CHARTS_MAP[type]],
      ...deps.map((o) => ChartsComponents[o]),
      ...features.map((o) => ChartsFeatures[o])
    ])
  })
}
</script>

<style scoped></style>
