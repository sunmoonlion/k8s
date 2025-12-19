<template>
  <el-menu
    ref="menuRef"
    v-bind="menuProps"
    :style="{ '--bg-color': backgroundColor }"
    class="border-r-0!"
    @select="handleSelect"
    @open="handleOpen"
    @close="handleClose"
    :default-active="getDefaultActive($route)"
  >
    <slot name="icon"></slot>
    <div class="flex-grow" v-if="isDefined(slots['icon'])" />
    <sub-menu
      v-for="menu in fileredMenus"
      :key="menu.path"
      :data="menu"
      :collapse="collapse"
      v-bind="subMenuProps"
    ></sub-menu>
  </el-menu>
</template>

<script setup lang="ts">
import type { MenuProps as ElMenuProps, SubMenuProps } from 'element-plus'
import type { AppRouteMenuItem, MenuSelectEvent, IconOptions, MenuOpenCloseEvent } from './types'
import { useMenu } from './useMenu'
import { type RouteLocationNormalizedLoaded } from 'vue-router'

interface MenuProps extends Partial<ElMenuProps> {
  data: AppRouteMenuItem[]
  subMenuProps?: Partial<SubMenuProps>
  iconProps?: Partial<IconOptions>
}

const props = withDefaults(defineProps<MenuProps>(), {
  data: () => [],
  iconProps: () => ({
    style: { fontSize: '22px' },
    class: 'mr-3'
  }),
  backgroundColor: 'transparent',
  ellipsis: true
})

const iconProps = reactive(props.iconProps)
const menuRef = ref()

watch(
  () => props.collapse,
  () => {
    iconProps.class = props.collapse ? '' : 'mr-3'
  }
)

provide('iconProps', iconProps)

const emits = defineEmits<{
  select: [item: AppRouteMenuItem]
  open: [arg: MenuOpenCloseEvent]
  close: [arg: MenuOpenCloseEvent]
}>()

const slots = useSlots()
const { generateMenuKeys, getItem, getParentMenu } = useMenu()

const fileredMenus = computed(() => generateMenuKeys(props.data))
const menuProps = computed(() => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { subMenuProps, data, ...restProps } = props
  return restProps
})

onMounted(() => {
  const item = getParentMenu(fileredMenus.value)
  if (item && item.meta && item.meta.key) {
    if (menuRef.value && menuRef.value.open) {
      !props.collapse && menuRef.value.open(item.meta.key)
    }
  }
})

function getDefaultActive(route: RouteLocationNormalizedLoaded) {
  // 最长匹配的路径
  let maxLength = 0
  let key = ''

  const path = route.name as string

  if (path === '/' && key === '') {
    const tmp = fileredMenus.value.find((item) => item.path === '/')
    return tmp && tmp.meta ? (tmp.meta.key as string) : ''
  }

  const findKey = (menus: AppRouteMenuItem[]) => {
    menus.forEach((item) => {
      const itemPath = item.name as string
      if (path.includes(itemPath)) {
        if (maxLength < itemPath.length) {
          maxLength = itemPath.length
          key = item.meta?.key as string
        }
      }
      if (item.children) {
        findKey(item.children)
      }
    })
  }

  findKey(fileredMenus.value)

  return key
}

const handleSelect = (...args: MenuSelectEvent) => {
  const [index] = args

  const item = getItem(fileredMenus.value, index)
  if (item) emits('select', item)
}
const handleOpen = (...args: MenuOpenCloseEvent) => {
  emits('open', args)
}
const handleClose = (...args: MenuOpenCloseEvent) => {
  emits('close', args)
}
</script>

<style lang="scss">
.el-menu--vertical .el-sub-menu__title {
  padding-right: 0 !important;
}

.el-menu--horizontal.el-menu {
  border-bottom: 0 !important;
}
</style>
