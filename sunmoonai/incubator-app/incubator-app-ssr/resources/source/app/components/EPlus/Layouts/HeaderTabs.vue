<template>
  <div class="flex justify-between items-center px-2">
    <el-tabs
      type="card"
      class="myTabs overflow-hidden flex-1"
      closable
      v-on="forwardEvents"
      v-model="modelValue"
    >
      <el-tab-pane
        :name="(item?.fullPath || item.path) as string"
        v-for="item in data"
        :key="(item?.fullPath || item.path) as string"
        :label="item.meta?.title || ''"
      ></el-tab-pane>
    </el-tabs>
    <DropDown :items="items" class="w-6" @change="handleClick">
      <template #header> <Iconify icon="mdi:view-grid" size="18px" /></template>
      <template #item="{ item }">
        {{ item.text }}
      </template>
    </DropDown>
  </div>
</template>

<script setup lang="ts">
import { forwardEventsUtils } from '../../utils/format'
import DropDown from '../Menu/DropDown.vue'
import { TabActions } from './const'
import type { HeaderTabsProps, HeaderTabsEvents } from './types'

const eventsName = ['tabClick', 'tabChange', 'edit', 'tabRemove', 'tabAdd']

withDefaults(defineProps<HeaderTabsProps>(), {
  stretch: false,
  closable: false,
  addable: false,
  editable: false,
  tabPosition: 'top'
})

const emits = defineEmits<HeaderTabsEvents>()

const forwardEvents = forwardEventsUtils(emits, eventsName)

const modelValue = defineModel<any>()

const items = ref([
  {
    action: TabActions.closeOthers,
    icon: 'ep:close',
    text: '关闭其他'
  },
  {
    action: TabActions.closeLeft,
    icon: 'line-md:arrow-close-left',
    text: '关闭左侧'
  },
  {
    action: TabActions.closeRight,
    icon: 'line-md:arrow-close-right',
    text: '关闭右侧'
  },
  {
    action: TabActions.closeAll,
    icon: 'codicon:close-all',
    text: '关闭全部'
  }
])

const handleClick = (item) => {
  emits('tabMenuClick', item.action)
}
</script>

<style scoped lang="scss">
.myTabs {
  :deep(.el-tabs__header) {
    @apply p-0 m-0 border-b-none flex items-center;
    .el-tabs__nav {
      @apply border-none;
    }
    .el-tabs__nav-prev,
    .el-tabs__nav-next {
      line-height: 40px;
    }
  }
  :deep(.el-tabs__item) {
    @apply py-0 h-[34px] px-4;
    border-radius: 4px;
    border: 1px solid var(--el-border-color) !important;
    transition: padding 0.3s cubic-bezier(0.645, 0.045, 0.355, 1) !important;
    margin-right: 5px;
    &.is-active {
      color: var(--el-color-primary) !important;
      background: var(--el-color-primary-light-9) !important;
      border: 1px solid var(--el-color-primary) !important;
    }
  }
}
</style>
