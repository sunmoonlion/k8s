import type { IconProps as IconPropsOrigin } from '@iconify/vue'

export interface IconProps extends /* @vue-ignore */ IconPropsOrigin {}

export interface NetIconProps {
  url: string
  prefix?: string
  fontFamily?: string
  type: string
}

