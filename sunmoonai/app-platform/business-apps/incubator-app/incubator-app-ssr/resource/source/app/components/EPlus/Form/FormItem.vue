<template>
  <el-form-item
    v-bind="props"
    :ref="(ref) => props?.itemRef && props.itemRef(ref as FormItemInstance)"
  >
    <!-- <template v-if="props?.prefixSlot">
      <component :is="props.prefixSlot" v-bind="props"></component>
    </template> -->
    <template #default>
      <!-- 前缀 -->
      <template v-if="props?.prefixSlot">
        <component :is="props.prefixSlot" v-bind="props"></component>
      </template>
      <component v-if="props?.defaultSlot" :is="props.defaultSlot" v-bind="props"></component>
      <div v-else>
        <el-select v-if="type === 'select'" v-model="modelValue" v-bind="attrs" v-on="events">
          <el-option
            :label="item.label"
            :value="item.value"
            v-bind="item"
            v-for="(item, index) in children"
            :key="index"
          />
        </el-select>
        <el-checkbox-group
          v-else-if="type === 'checkbox' || type === 'checkbox-group'"
          v-model="modelValue"
          v-bind="attrs"
        >
          <component
            :is="'el-' + item.type"
            :label="item.label"
            :value="item.value"
            v-bind="item"
            v-on="events"
            v-for="(item, index) in children"
            :key="index"
          />
        </el-checkbox-group>
        <el-radio-group
          v-else-if="type === 'radio' || type === 'radio-group'"
          v-model="modelValue"
          v-bind="attrs"
          v-on="events"
        >
          <component
            :is="'el-' + item.type"
            v-for="(item, index) in children"
            :key="index"
            :label="item.value"
            >{{ item.label }}</component
          >
        </el-radio-group>
        <component
          :is="'el-' + type"
          v-else-if="
            !['checkbox', 'radio', 'select'].includes(type || '') &&
            typeof type !== 'undefined' &&
            type !== ''
          "
          v-model="modelValue"
          v-bind="attrs"
          v-on="events"
          :ref="(ref) => props.childRef && props.childRef(ref)"
        />
        <span v-else v-bind="attrs">{{ value }}</span>
      </div>
      <!-- 后缀 -->
      <template v-if="props?.suffixSlot">
        <component :is="props.suffixSlot" v-bind="props"></component>
      </template>
    </template>
    <template #label="scope" v-if="props?.labelSlot">
      <component :is="props.labelSlot" v-bind="scope"></component>
    </template>
    <template #error="scope" v-if="props.errorSlot">
      <component :is="props.errorSlot" v-bind="scope"></component>
    </template>
  </el-form-item>
</template>

<script setup lang="ts">
// import { exposeEventsUtils } from '@/utils/format'
import type { FormItemProp } from './types'
import type { FormItemInstance } from 'element-plus'

const props = withDefaults(defineProps<FormItemProp>(), {
  showMessage: true,
  labelWidth: '',
  inlineMessage: '',
  required: undefined
})

const modelValue = defineModel()

onBeforeMount(() => {
  // 针对于select类型，如果value为空串，则改成undefined
  if (props.type === 'select' && props.value === '') {
    modelValue.value = undefined
  } else {
    modelValue.value = props.value
  }
})
</script>

<style scoped></style>
