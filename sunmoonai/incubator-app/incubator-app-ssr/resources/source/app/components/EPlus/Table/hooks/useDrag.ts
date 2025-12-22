import Sortable from 'sortablejs'
import DragIcon from '../DragIcon.vue'

export function useDrag() {
  function addId(flag: boolean, arr: any[]) {
    const ids = Math.random().toString(36).slice(2)
    if (flag && arr.length && !arr[0].id) {
      arr.forEach((item, index) => {
        item.id = ids + '-' + index
      })
      // rowKey.value = 'id'
    }
    return arr
  }

  function columnDrop(elem, handle = '.el-table__header-wrapper tr', cb) {
    nextTick(() => {
      const el = elem.querySelector(handle)
      Sortable.create(el, {
        delay: 0,
        animation: 300,
        onEnd: (...args) => {
          // const draggedItem = localCols.value.splice(oldIndex, 1)[0]
          // localCols.value.splice(newIndex, 0, draggedItem)
          // emits('drag-col-change', localCols.value)
          cb && cb(args)
        }
      })
    })
  }

  function rowDrop(elem, handle = '.el-table__body-wrapper tbody', cb) {
    nextTick(() => {
      const el = elem.querySelector(handle)
      Sortable.create(el, {
        delay: 0,
        handle: '.drag-btn',
        animation: 300,
        onEnd: (...args) => {
          // const draggedItem = localData.value.splice(oldIndex, 1)[0]
          // localData.value.splice(newIndex, 0, draggedItem)
          // emits('drag-row-change', localData.value)
          cb && cb(args)
        }
      })
    })
  }

  function setColumn(arr) {
    const defaultSlot = arr[0].defaultSlot
    arr[0].defaultSlot = (_prop) => {
      return h(
        DragIcon,
        {
          props: _prop
        },
        {
          default: () => {
            const { row } = _prop
            return defaultSlot
              ? defaultSlot(_prop)
              : h('span', { props: _prop }, arr[0]?.prop ? row[arr[0].prop] : '')
          }
        }
      )
    }
  }

  return {
    addId,
    columnDrop,
    rowDrop,
    setColumn
  }
}
