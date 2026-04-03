<template>
  <div ref="editorRef"></div>
</template>

<script setup lang="ts">
import('vditor/dist/index.css')
import { ref, onMounted } from 'vue'
import Vditor from 'vditor'
import type { EditorProps, EditorOptions } from './types'

const defaultOptions: EditorOptions = {
  rtl: false,
  mode: 'ir',
  value: '',
  debugger: false,
  typewriterMode: false,
  height: 'auto',
  minHeight: 400,
  width: 'auto',
  placeholder: '',
  fullscreen: { index: 90 },
  counter: {
    enable: false, // 默认值: false
    type: 'markdown' // 默认值: 'markdown'
  },
  link: {
    isOpen: true // 默认值: true
  },
  image: {
    isPreview: true // 默认值: true
  },
  cache: { enable: true, id: Math.random().toString(16).slice(2) },
  lang: 'zh_CN',
  theme: 'classic',
  icon: 'ant',
  cdn: 'https://unpkg.com/vditor@3.9.6'
}

const props = defineProps<EditorProps>()
const modelValue = defineModel()

const editorRef = ref()
const editorInstance = shallowRef<Vditor>()
const history = ref('')

const emits = defineEmits(['init'])

watch(modelValue, (newVal) => {
  if (editorInstance.value && newVal && `${newVal}` !== editorInstance.value.getValue()) {
    editorInstance.value.setValue(newVal + '')
  }
})

const fn = useDebounceFn((newOptions) => {
  if (editorInstance.value) {
    try {
      history.value = editorInstance.value?.getValue()
      editorInstance.value?.destroy()
    } catch (error) {
      history.value = ''
    }
    initEditor(newOptions)
  }
}, 100)

watch(() => props.options, fn, {
  deep: true
})

function initEditor(options) {
  const defaultAfter = options?.after
  const defaultInput = options?.input
  const instance = new Vditor(
    editorRef.value,
    Object.assign(defaultOptions, {
      ...options,
      after: () => {
        defaultAfter && defaultAfter()
        if (history.value) {
          instance.setValue(history.value, true)
        }
        const tmp = instance.getValue()
        if (!tmp) {
          modelValue.value = tmp
        }
      },
      input: (md) => {
        defaultInput && defaultInput(md)
        modelValue.value = md
      }
    })
  )
  editorInstance.value = instance
  modelValue.value = options?.value || ''
  return instance
}

onMounted(() => {
  initEditor(props.options)
  emits('init', editorInstance.value)
})

onBeforeUnmount(() => {
  editorInstance.value?.destroy()
})
</script>

<style scoped></style>
