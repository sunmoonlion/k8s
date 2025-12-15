import type { Component } from 'vue'
import type { IconProps } from '../Icons/types'
import type { TagProps, LinkProps } from 'element-plus'

export interface DescriptionItemProps {
  label: string
  span: number
  width: string | number
  minWidth: string | number
  align: string
  labelAlign: string
  className: string
  labelClassName: string
  value: string | number
  tag: TagProps
  link: LinkProps
  icon: IconProps
}

export interface DescriptionItem extends Partial<DescriptionItemProps> {
  labelSlot?: Component
  defaultSlot?: Component
}

export interface DescriptionProps {
  border?: boolean
  column?: number
  direction?: 'horizontal' | 'vertical'
  size?: '' | 'default' | 'small' | 'large'
  extra?: string
  title?: string
  titleClass?: string
  collapse?: boolean
  data: DescriptionItem[]
}
