<template>
  <div class="p-2">
    <slot name="title">
      <div class="flex justify-between items-center">
        <span :class="titleClass">{{ title }}</span>
        <span
          :class="[
            'i-ep:arrow-down transition-all transition-duration-500',
            { 'transform-rotate-180': active }
          ]"
          @click="() => toggle()"
        ></span>
      </div>
    </slot>
    <CollapseTransition>
      <el-descriptions v-show="!active" v-bind="descriptionProps">
        <template #extra>
          <slot name="extra"></slot>
        </template>
        <template #default>
          <slot name="default">
            <el-descriptions-item v-bind="item" v-for="(item, index) in data" :key="index">
              <!-- 默认default slot，可以展示tag & link -->
              <template #default v-if="!item.defaultSlot">
                <el-tag v-if="item.tag" v-bind="item.tag">{{ item.value }}</el-tag>
                <el-link v-else-if="item.link" v-bind="getLinkAttributes(item)">{{
                  item.value
                }}</el-link>
                <template v-else>{{ item.value }}</template>
              </template>
              <!-- 用户自定义defaultSlot -->
              <template #default v-else>
                <component :is="item.defaultSlot" v-bind="item"></component>
              </template>
              <!-- 用户自定义labelSlot -->
              <template #label v-if="item.labelSlot">
                <component :is="item.labelSlot" v-bind="item"></component>
              </template>
              <!-- 默认slot，可以传icon -->
              <template #label v-else>
                <div class="flex items-center">
                  <Iconify v-bind="item.icon" v-if="item.icon" class="mr-2"></Iconify>
                  {{ item.label }}
                </div>
              </template>
            </el-descriptions-item>
          </slot>
        </template>
      </el-descriptions>
    </CollapseTransition>
  </div>
</template>

<script setup lang="ts">
import type { DescriptionProps } from './types'
import { useToggle } from '@vueuse/core'

const props = defineProps<DescriptionProps>()

const [active, toggle] = useToggle(props.collapse || false)

const descriptionProps = computed(() => {
  const { title, ...restProps } = props
  return restProps
})

function getLinkAttributes(item) {
  const linkAttrs = { ...item.link }
  linkAttrs.target = linkAttrs.target || '_target'
  return linkAttrs
}
</script>

<style scoped></style>
