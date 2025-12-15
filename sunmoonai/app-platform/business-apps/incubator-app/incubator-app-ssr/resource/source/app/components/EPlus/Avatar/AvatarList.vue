<template>
  <ul :class="wrapperClass">
    <li
      v-for="(item, index) in newImages"
      :key="index"
      class="rounded-full flex border-white"
      :style="{
        ...styles,
        borderColor,
        borderWidth,
        zIndex: reverse ? newImages.length - index : index
      }"
    >
      <slot name="item" :item="item">
        <el-avatar
          :src="typeof item !== 'string' ? item.src : item"
          :size="size"
          @click="() => handleClick(item, index)"
        ></el-avatar>
      </slot>
    </li>
    <li v-if="num && showMore" class="more" :style="moreStyle">...</li>
  </ul>
</template>

<script setup lang="ts">
import type { AavatarListProps, AvatarImageType } from './types'
import { computed, defineProps, defineEmits } from 'vue'

const props = withDefaults(defineProps<AavatarListProps>(), {
  images: () => [],
  num: 5,
  size: 32,
  gutter: 0,
  borderColor: 'white',
  borderWidth: '3px',
  direction: 'horizontal'
})

const emits = defineEmits(['click'])

const handleClick = (item: string | AvatarImageType, index: number) => {
  emits('click', { item, index })
}

const wrapperClass = computed(() => {
  let cls = [] as string[]
  if (props.direction === 'vertical') {
    cls = [...cls, 'flex-col', 'justify-center']
  } else {
    cls = [...cls, 'flex-row', 'items-center']
  }
  if (props.inline) {
    cls = ['inline', ...cls]
  } else {
    cls = ['flex', ...cls]
  }
  return cls
})

const styles = computed(() => {
  if (props.direction === 'horizontal') {
    return {
      marginRight: -props.gutter + 'px'
    }
  } else {
    return {
      marginBottom: -props.gutter + 'px'
    }
  }
})

const moreStyle = computed(() => {
  if (props.direction === 'horizontal') {
    return { marginLeft: props.gutter + 3 + 'px' }
  }
  return { marginTop: props.gutter - 5 + 'px' }
})

const newImages = computed(
  () => (props.num ? (props.images || []).slice(0, props.num) : props.images) || []
)
</script>

<style scoped lang="scss">
.inline {
  @apply inline-flex;

  li {
    @apply inline-flex;
  }

  .more {
    @apply self-center relative left-[-2px];

    position: relative;
  }
}
</style>
