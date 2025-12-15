import {
  ElButton,
  ElInput,
  ElInputNumber,
  ElSelect,
  ElOption,
  ElText,
  ElLink,
  ElRate,
  ElSlider,
  ElSwitch,
  ElCheckbox,
  ElCheckboxGroup,
  ElRadio,
  ElRadioButton,
  ElRadioGroup,
  ElCascader,
  ElColorPicker,
  ElTimePicker,
  ElTimeSelect,
  ElDatePicker,
  ElTransfer,
  ElAvatar,
  ElImage,
  ElProgress,
  ElTag,
  ElTimeline,
  ElTree,
  ElSteps,
  ElStep
} from 'element-plus'

import 'element-plus/theme-chalk/el-select.css'
import 'element-plus/theme-chalk/el-option.css'
import 'element-plus/theme-chalk/el-text.css'
import 'element-plus/theme-chalk/el-link.css'
import 'element-plus/theme-chalk/el-rate.css'
import 'element-plus/theme-chalk/el-slider.css'
import 'element-plus/theme-chalk/el-switch.css'
import 'element-plus/theme-chalk/el-checkbox.css'
import 'element-plus/theme-chalk/el-checkbox-group.css'
import 'element-plus/theme-chalk/el-radio.css'
import 'element-plus/theme-chalk/el-radio-button.css'
import 'element-plus/theme-chalk/el-radio-group.css'
import 'element-plus/theme-chalk/el-cascader.css'
import 'element-plus/theme-chalk/el-color-picker.css'
import 'element-plus/theme-chalk/el-time-picker.css'
import 'element-plus/theme-chalk/el-time-select.css'
import 'element-plus/theme-chalk/el-date-picker.css'
import 'element-plus/theme-chalk/el-transfer.css'
import 'element-plus/theme-chalk/el-avatar.css'
import 'element-plus/theme-chalk/el-image.css'
import 'element-plus/theme-chalk/el-progress.css'
import 'element-plus/theme-chalk/el-tag.css'
import 'element-plus/theme-chalk/el-timeline.css'
import 'element-plus/theme-chalk/el-tree.css'
import 'element-plus/theme-chalk/el-steps.css'
import 'element-plus/theme-chalk/el-step.css'

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

export const componentsNames: ComponentType[] = [
  'select',
  'option',
  'text',
  'link',
  'rate',
  'slider',
  'switch',
  'checkbox',
  'checkbox-group',
  'radio',
  'radio-button',
  'radio-group',
  'cascader',
  'color-picker',
  'time-picker',
  'time-select',
  'date-picker',
  'transfer',
  'avatar',
  'image',
  'progress',
  'tag',
  'timeline',
  'tree',
  'steps',
  'step'
]

const componentsMap = new Map<ComponentType, Component>()

componentsMap.set('button', ElButton)
componentsMap.set('input', ElInput)
componentsMap.set('input-number', ElInputNumber)
componentsMap.set('select', ElSelect)
componentsMap.set('option', ElOption)
componentsMap.set('text', ElText)
componentsMap.set('link', ElLink)
componentsMap.set('rate', ElRate)
componentsMap.set('slider', ElSlider)
componentsMap.set('switch', ElSwitch)
componentsMap.set('checkbox', ElCheckbox)
componentsMap.set('checkbox-group', ElCheckboxGroup)
componentsMap.set('radio', ElRadio)
componentsMap.set('radio-button', ElRadioButton)
componentsMap.set('radio-group', ElRadioGroup)
componentsMap.set('cascader', ElCascader)
componentsMap.set('color-picker', ElColorPicker)
componentsMap.set('time-picker', ElTimePicker)
componentsMap.set('time-select', ElTimeSelect)
componentsMap.set('date-picker', ElDatePicker)
componentsMap.set('transfer', ElTransfer)
componentsMap.set('avatar', ElAvatar)
componentsMap.set('image', ElImage)
componentsMap.set('progress', ElProgress)
componentsMap.set('tag', ElTag)
componentsMap.set('timeline', ElTimeline)
componentsMap.set('tree', ElTree)
componentsMap.set('steps', ElSteps)
componentsMap.set('step', ElStep)

export { componentsMap }
