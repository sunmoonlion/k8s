<template>
  <el-table
    v-loading="loading"
    v-bind="props"
    v-on="events"
    :style="tableStyle"
    ref="tableRef"
    :data="localData"
  >
    <Column
      v-for="(column, index) in columns"
      v-bind="setColumnDefaults(column)"
      :key="column.id || index"
    >
    </Column>
    <slot></slot>
    <template #append>
      <slot name="append"></slot>
    </template>
    <template #empty>
      <slot name="empty"></slot>
    </template>
  </el-table>
  <slot name="footer">
    <div class="flex justify-between">
      <div class="flex items-center">
        <slot name="footer-actions"></slot>
      </div>
      <div :class="['p-2 flex', paginationClass]" v-if="isDefined(pagination)">
        <el-pagination v-bind="pagination" v-on="pageEvents">
          <template #default="scope" v-if="pagination.defaultSlot">
            <component :is="pagination.defaultSlot" v-bind="scope"></component>
          </template>
        </el-pagination>
      </div>
    </div>
  </slot>
</template>

<script lang="tsx" setup>
import { nextTick } from 'vue'
import { exposeEventsUtils, forwardEventsUtils } from '@/utils/format'
import type { TableEmitsType, TableProps, TableColumnType } from './types'
import Sortable from 'sortablejs'
import Column from './TableColumn.vue'
import DragIcon from './DragIcon.vue'

const columnDefaults = {
  sortable: false,
  sortOrders: ['ascending', 'descending', null],
  resizable: true,
  align: 'left',
  reserveSelection: false,
  filterMultiple: true
}

const props = withDefaults(defineProps<TableProps>(), {
  // pagination: () => ({
  //   align: 'right',
  //   small: false,
  //   background: false,
  //   layout: 'total, sizes, prev, pager, next, jumper',
  //   pagerCount: 7,
  //   pageSizes: [10, 20, 30, 40, 50, 100],
  //   total: 0
  // }),
  stripe: false,
  border: false,
  fit: true,
  showHeader: true,
  highlightCurrentRow: false,
  emptyText: 'No Data',
  defaultExpandAll: false,
  tooltipEffect: 'dark',
  showSummary: false,
  flexible: false,
  selectOnIndeterminate: true,
  indent: 16,
  tableLayout: 'fixed',
  scrollbarAlwaysOn: false,
  adaptive: false,
  loading: false,
  draggableCol: false,
  draggableRow: false
  // rowKey: 'id'
})
const tableRef = ref()
const tableStyle = ref({ width: '100%', height: 'auto' })

const emits = defineEmits<TableEmitsType>()

const eventsName = [
  'select',
  'select-all',
  'selection-change',
  'cell-mouse-enter',
  'cell-mouse-leave',
  'cell-contextmenu',
  'cell-click',
  'cell-dblclick',
  'row-click',
  'row-contextmenu',
  'row-dblclick',
  'header-click',
  'header-contextmenu',
  'sort-change',
  'filter-change',
  'current-change',
  'header-dragend',
  'expand-change'
]

const pageEventsName = ['size-change', 'current-change', 'prev-click', 'next-click']

const exposeEvents = [
  'clearSelection',
  'getSelectionRows',
  'toggleRowSelection',
  'toggleAllSelection',
  'toggleRowExpansion',
  'setCurrentRow',
  'clearSort',
  'clearFilter',
  'doLayout',
  'sort',
  'scrollTo',
  'setScrollTop',
  'setScrollLeft'
]
// ref, exposeEvents

const events = forwardEventsUtils(emits, eventsName)
const pageEvents = forwardEventsUtils(emits, pageEventsName, 'page-')
const exposes = exposeEventsUtils(tableRef, exposeEvents)

const localCols = ref(props.columns as TableColumnType[])
const localData = ref(props.data as any[])
const rowKey = ref(props.rowKey)

defineExpose({ ...exposes })

const paginationClass = computed(() => {
  let defaultClass = 'justify-center'
  if (props.pagination && props.pagination.align) {
    if (props.pagination.align === 'left') {
      defaultClass = 'justify-start'
    }
    if (props.pagination.align === 'right') {
      defaultClass = 'justify-end'
    }
  }
  return defaultClass
})

watch(
  [() => props.data, () => props.columns],
  async () => {
    dragInit()
    await nextTick()
    init()
  },
  {
    deep: true
  }
)

const fn = useDebounceFn(setAdaptive, 200)

onBeforeMount(() => {
  dragInit()
})

onMounted(() => {
  init()
  window.addEventListener('resize', fn)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', fn)
})

function dragInit() {
  localCols.value = addId(props.draggableCol, props.columns)
  localData.value = addId(props.draggableRow, props.data)
  if (props.draggableRow && localData.value.length) {
    const defaultSlot = localCols.value[0].defaultSlot as unknown as any
    localCols.value[0].defaultSlot = (_prop) => {
      const { row } = _prop
      return (
        <DragIcon>
          {defaultSlot ? (
            defaultSlot(_prop)
          ) : (
            <span>{localCols.value[0]?.prop ? row[localCols.value[0].prop] : ''}</span>
          )}
        </DragIcon>
      )
    }
  }
}

function init() {
  if (props.adaptive) {
    setAdaptive()
  }
  if (props.draggableCol) {
    columnDrop()
  }
  if (props.draggableRow) {
    rowDrop()
  }
}

function setColumnDefaults(column: object) {
  return { ...columnDefaults, ...column } as TableColumnType
}

function addId(flag: boolean, arr: any[]) {
  const ids = Math.random().toString(36).slice(2)
  if (flag && arr.length && !arr[0].id) {
    arr.forEach((item, index) => {
      item.id = ids + '-' + index
    })
    rowKey.value = 'id'
  }
  return arr
}

async function setAdaptive() {
  await nextTick()
  if (props.adaptive) {
    let offset = 50
    if (typeof props.adaptive === 'number') {
      offset = props.adaptive
    }
    const height = window.innerHeight - tableRef.value.$el.getBoundingClientRect().top - offset
    tableStyle.value.height = height + 'px'
  }
}

function columnDrop() {
  nextTick(() => {
    const el = tableRef.value.$el.querySelector('.el-table__header-wrapper tr')
    Sortable.create(el, {
      delay: 0,
      animation: 300,
      onEnd: ({ newIndex, oldIndex }) => {
        if (newIndex && oldIndex) {
          const draggedItem = localCols.value.splice(oldIndex, 1)[0]
          localCols.value.splice(newIndex, 0, draggedItem)
          emits('drag-col-change', localCols.value)
        }
      }
    })
  })
}

function rowDrop() {
  nextTick(() => {
    const el = tableRef.value.$el.querySelector('.el-table__body-wrapper tbody')
    Sortable.create(el, {
      delay: 0,
      handle: '.drag-btn',
      animation: 300,
      onEnd: ({ newIndex, oldIndex }) => {
        if (newIndex && oldIndex) {
          const draggedItem = localData.value.splice(oldIndex, 1)[0]
          localData.value.splice(newIndex, 0, draggedItem)
          emits('drag-row-change', localData.value)
        }
      }
    })
  })
}

// function getColumnProps(column: TableColumnType) {
//   return computed(() => {
//     const { label, prop, ...restProps } = column
//     return restProps
//   })
// }
</script>
