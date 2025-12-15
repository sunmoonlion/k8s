<template>
  <div :class="['flex items-center flex-nowrap h-[50px] z-100 bg-white dark:bg-dark']">
    <Iconify
      :icon="collapseModel ? 'ep:expand' : 'ep:fold'"
      class="ml-2 text-2xl cursor-pointer"
      @click="collapseModel = !collapseModel"
      v-if="settings?.mode !== 'top'"
      v-show="showCollapse"
    ></Iconify>
    <Breadcrumb v-if="!['mix', 'top'].includes(settings?.mode || '')"></Breadcrumb>
    <div class="relative overflow-x-hidden flex-grow">
      <slot></slot>
    </div>
    <el-row class="items-center flex-nowrap">
      <ThemeSettings v-bind="settings" @change="handleChange"></ThemeSettings>
      <DarkModeToggle
        :dark="settings?.darkMode"
        @change="handleDarkModeToggle"
        class="mr-2"
      ></DarkModeToggle>
      <FullScreen class="mr-2"></FullScreen>
      <el-divider direction="vertical"></el-divider>
      <!-- 用户头像下拉菜单 -->
      <AvatarMenu
        v-if="username || src"
        class="mr-4"
        v-bind="avatarProps"
        @command="handleCommand"
      ></AvatarMenu>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import type { ThemeSettingsProps } from '../Themes/types'
import Iconify from '../Icons/Iconify.vue'
import DarkModeToggle from '../Themes/DarkModeToggle.vue'
import FullScreen from '../Themes/FullScreen.vue'
import ThemeSettings from '../Themes/ThemeSettings.vue'
import AvatarMenu from '../Avatar/AvatarMenu.vue'
import type { HeaderProps } from './types'

const props = withDefaults(defineProps<HeaderProps>(), {
  collapse: false,
  showCollapse: true
})

const collapseModel = defineModel('collapse', {
  default: false
})

const localProps = reactive({ ...props })

const emits = defineEmits<{
  menuChange: [arg: string | number | object]
  settingsChange: [settings: ThemeSettingsProps]
}>()

const avatarProps = computed(() => {
  const { collapse, locales, settings, ...restProps } = props
  return restProps
})

const handleCommand = (command: string | number | object) => emits('menuChange', command)

watch(
  () => localProps.settings,
  () => {
    emits('settingsChange', localProps.settings!)
  },
  {
    deep: true
  }
)

// 获取菜单设置
const handleChange = (settings: ThemeSettingsProps) => {
  localProps.settings = settings
  // emits('settingsChange', localProps.settings)
}
const handleDarkModeToggle = (dark: boolean) => {
  localProps.settings!.darkMode = dark
  // emits('settingsChange', localProps.settings!)
}

</script>

<style scoped></style>
