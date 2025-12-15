<template>
  <el-form-item v-bind="props">
    <el-col
      v-bind="child.colProps"
      :span="child.span || child.colProps?.span"
      v-for="(child, index) in schema"
      :key="index"
    >
      <FormItem
        v-bind="child"
        v-if="child.prop"
        v-model="modelValue[child.prop as string]"
      ></FormItem>
      <FormItem v-bind="child" v-else></FormItem>
    </el-col>
  </el-form-item>
</template>

<script setup lang="ts">
import type { FormItemProp } from './types'
import FormItem from './FormItem.vue'

const props = withDefaults(defineProps<FormItemProp>(), {
  showMessage: true,
  labelWidth: '',
  inlineMessage: '',
  required: undefined
})

const modelValue = defineModel<any>()
</script>

<style scoped></style>
