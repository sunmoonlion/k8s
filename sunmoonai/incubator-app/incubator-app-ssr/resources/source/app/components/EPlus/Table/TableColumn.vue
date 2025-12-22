<template>
  <el-table-column v-bind="props">
    <template #default="scope" v-if="defaultSlot">
      <component :is="defaultSlot" v-bind="scope"></component>
    </template>
    <template #header="scope" v-if="headerSlot">
      <component :is="headerSlot" v-bind="scope"></component>
    </template>
    <template v-if="children && children.length">
      <VpTableColumn v-for="(child, index) in children" :key="index" v-bind="child"></VpTableColumn>
    </template>
  </el-table-column>
</template>

<script setup lang="ts">
import type { TableColumnType } from './types'

const props = defineProps<TableColumnType>()
</script>

<style scoped></style>
