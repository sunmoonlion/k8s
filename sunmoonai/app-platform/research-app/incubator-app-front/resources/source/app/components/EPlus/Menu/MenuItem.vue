<template>
  <el-menu-item :index="getIndex(data)" :disabled="data.meta?.disabled" v-if="!data.meta?.icon">{{
    data.meta?.title || ''
  }}</el-menu-item>
  <template v-else>
    <el-menu-item v-if="collapse" :index="getIndex(data)" :disabled="data.meta?.disabled">
      <Iconify
        :icon="data.meta?.icon"
        :style="iconProps?.style"
        :class="iconProps?.class"
      ></Iconify>
      <template #title>
        <span class="ml-3">
          {{ data.meta?.title || '' }}
        </span>
      </template>
    </el-menu-item>
    <el-menu-item v-else :index="getIndex(data)" :disabled="data.meta?.disabled">
      <Iconify
        :icon="data.meta?.icon"
        :style="iconProps?.style"
        :class="iconProps?.class"
      ></Iconify>
      <span>{{ data.meta?.title || '' }}</span>
    </el-menu-item>
  </template>
</template>

<script setup lang="ts">
import type { AppRouteMenuItem, IconOptions } from './types'
import { useMenu } from './useMenu'
import Iconify from '../Icons/Iconify.vue'

interface MenuItemProps {
  data: AppRouteMenuItem
  collapse?: boolean
}

defineProps<MenuItemProps>()

const iconProps = inject('iconProps') as IconOptions

const { getIndex } = useMenu()
</script>

<style scoped></style>
