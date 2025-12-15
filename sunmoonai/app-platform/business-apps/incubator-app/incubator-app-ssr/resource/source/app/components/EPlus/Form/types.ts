import type { IconifyIcon } from '@iconify/vue'
import type {
  FormProps as EPFormProps,
  FormMetaProps,
  FormItemProps,
  ColProps,
  FormItemRule,
  FormItemInstance
} from 'element-plus'
import type { CSSProperties, Component } from 'vue'

// 适用于第三方登录的
export interface LoginItem {
  icon: IconifyIcon | string
  url: string
}

export interface LoginFormProps {
  position?: 'left' | 'center' | 'right'
  title?: string
  loginItems?: LoginItem[]
}

type NewFormProps = EPFormProps & FormMetaProps

export type ComponentType =
  | 'input'
  | 'button'
  | 'input-number'
  | 'select'
  | 'option'
  | 'text'
  | 'link'
  | 'rate'
  | 'slider'
  | 'switch'
  | 'checkbox'
  | 'checkbox-group'
  | 'radio'
  | 'radio-button'
  | 'radio-group'
  | 'cascader'
  | 'color-picker'
  | 'time-picker'
  | 'time-select'
  | 'date-picker'
  | 'transfer'
  | 'avatar'
  | 'image'
  | 'progress'
  | 'tag'
  | 'timeline'
  | 'tree'
  | 'steps'
  | 'step'
  | 'upload'
  | ''
  | undefined

type FormItemChild = {
  type?: ComponentType
  label?: string
  value?: any
  [key: string]: any
}

export interface FormItemProp extends Partial<FormItemProps> {
  prop?: string
  type?: ComponentType
  // 事件
  events?: any
  // 扩展属性
  attrs?: any
  slots?: any
  span?: number
  colProps?: ColProps
  value?: any
  children?: FormItemChild[]
  schema?: FormSchema
  rules?: FormItemRule[]

  defaultSlot?: Component
  labelSlot?: Component
  errorSlot?: Component
  prefixSlot?: Component
  suffixSlot?: Component
  // slots?: {
  //   default: Component
  //   label: Component
  //   error: Component
  // }
  // itemRef
  itemRef?: (ref: FormItemInstance) => void
  childRef?: (ref: any) => void
}

export type FormSchema = FormItemProp[]

export interface FormProps extends Partial<NewFormProps> {
  schema?: FormSchema
  rowClass?: string
  rowStyle?: CSSProperties
}
