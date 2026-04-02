<template>
  <el-form :model="model" :rules="rules" ref="formRef">
    <slot name="default">
      <el-row :class="rowClass" :style="rowStyle">
        <template v-if="schema && schema.length">
          <template v-for="(item, index) in schema" :key="index">
            <FormLayoutSchema
              v-bind="item"
              v-model="model"
              v-if="item.schema && item.schema.length"
            >
            </FormLayoutSchema>
            <FormLayout v-else v-bind="item" v-model="model[item.prop as string]"></FormLayout>
          </template>
        </template>
      </el-row>
    </slot>
    <slot name="actions"></slot>
  </el-form>
</template>

<script setup lang="ts">
import { exposeEventsUtils } from '@/utils/format'
import type { FormProps } from './types'
import { useForm } from './useForm'
import type { FormInstance, FormItemProp } from 'element-plus'

const exposeEvents = [
  'validate',
  'validateField',
  'resetFields',
  'clearValidate',
  'scrollToField',
  'fields'
]

const props = withDefaults(defineProps<FormProps>(), {
  inline: false,
  labelPosition: 'right',
  hideRequiredAsterisk: false,
  requireAsteriskPosition: 'left',
  showMessage: true,
  inlineMessage: false,
  statusIcon: false,
  validateOnRuleChange: false,
  disabled: false,
  scrollToError: false
})

const formRef = ref<FormInstance>()

const emits = defineEmits<{
  validate: [prop: FormItemProp, isValid: boolean, message: string]
  'update:modelValue': [model: any]
}>()
const exposes = exposeEventsUtils(formRef, exposeEvents)

defineExpose({ ...exposes })

const { model, rules } = useForm(props.schema || [])

watch(
  model,
  () => {
    emits('update:modelValue', model.value)
  },
  {
    deep: true
  }
)
</script>

<style scoped></style>
