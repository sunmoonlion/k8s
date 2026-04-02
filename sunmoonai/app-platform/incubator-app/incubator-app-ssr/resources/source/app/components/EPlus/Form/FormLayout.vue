<template>
  <template v-if="colProps || span">
    <el-col :span="colProps?.span || span" v-bind="colProps">
      <FormItem v-bind="props" v-model="modelValue"></FormItem>
    </el-col>
  </template>
  <template v-else>
    <FormItem v-bind="props" v-model="modelValue"></FormItem>
  </template>
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
