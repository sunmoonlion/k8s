import { init } from 'echarts/core'
import * as echarts from 'echarts'

import type { SetOptionOpts } from 'echarts'

import type { CSSProperties } from 'vue'

type InitType = typeof init

type InitParameters = Parameters<InitType>
// type Theme = NonNullable<InitParameters[1]>
type InitOptions = NonNullable<InitParameters[2]>
type UpdateOptions = SetOptionOpts

type LoadingOptions = {
  text?: string
  textColor?: string
  fontSize?: number | string
  fontWeight?: number | string
  fontStyle?: string
  fontFamily?: string
  maskColor?: string
  showSpinner?: boolean
  color?: string
  spinnerRadius?: number
  lineWidth?: number
  zlevel?: number
}

type AutoresizeProp =
  | boolean
  | {
      throttle?: number
      onResize?: () => void
    }

export interface VEchartsProps {
  option: echarts.EChartsOption
  // theme: {
  //   type: Theme
  // }
  initOptions: InitOptions
  updateOptions: UpdateOptions
  group: string
  manualUpdate: boolean
  autoresize: AutoresizeProp
  loading: boolean
  loadingOptions: LoadingOptions
}

export interface VueEchartsProps extends Partial<VEchartsProps> {
  theme?: 'dark' | 'default' | string
  style?: CSSProperties
  height?: string | number
  charts?: string
  components?: string[]
  option: echarts.EChartsOption
}

export interface ChartsProps {
  options: Object
  width?: number | string
  height?: number | string
  autoresize?: boolean
}
