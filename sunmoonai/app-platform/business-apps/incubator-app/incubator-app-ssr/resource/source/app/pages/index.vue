<template>
  <div>
  <div class="w-full z-50 transition-all duration-300 h-10 " :class="[{ 'lt-sm:(bg-black h-full)': show }]">
    <!-- 这里修复滚动时h-0的bug -->
    <div :class="[{ 'fixed top-0 bg-pink bg-opacity-30 shadow-lg': y > 50 }]">
      <container>
        <!-- <div class="i-pepicons-pop:moon-circle text-blue-500 text-6xl lt-sm:mx-auto"></div> -->
        <Menu v-show="show" class="lt-sm:(absolute top-0 right-0 w-full flex-col)"></Menu>
        <div
          :class="['display-none text-2xl text-gray-300 absolute right-5 top-3 cursor-pointer hover:text-white lt-sm:display-block']"
          @click="toggle()">
          <transition name="rotate-icon" mode="out-in">
            <div class="i-ic-round-menu" v-if="!show"></div>
            <div class="i-radix-icons:cross-2" v-else></div>
          </transition>
        </div>
      </container>
    </div>
  </div>
  <div>
    <FreeSwiper :items="items" height="h-50"></FreeSwiper>   
    <EPlusThemesDarkModeToggle></EPlusThemesDarkModeToggle>
  </div>
</div>
</template>

<script setup lang="ts">

import { useThemeStore } from '~/stores/useThemeStore'
import { useHomeStore } from '~/stores/useHomeStore'

import type { SwiperItemType } from '@/components/types';
import type { Swiper as SwiperType } from 'swiper'

// 使用 public 目录下的图片（直接通过路径访问，不需要导入）
// public 目录下的文件会被直接复制到构建输出的根目录
const bg = '/bg.png';

// Swiper element registration removed - using component-based Swiper instead

const { y } = useWindowScroll();
const [show, toggle] = useToggle(false);
const flag = ref(false);
if (import.meta.client) {
  useResizeObserver(document.body, () => {
    const width = window.innerWidth;
    if (width >= 640) {
      toggle(true);
      flag.value = false;
    } else {
      if (flag.value) return;
      flag.value = true;
      toggle(false);
    }
  });
}

const items: SwiperItemType[] = [
  {
    image: bg,
    title: "上海国际集团",
    subTitle: "资管公司"
  },
  {
    image: bg,
    title: "上海国际集团",
    subTitle: "资管公司"
  },
  {
    image: bg,
    title: "上海国际集团",
    subTitle: "资管公司"
  },
  {
    image: bg,
    title: "上海国际集团",
    subTitle: "资管公司"
  }
]

onMounted(() => {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.ready.then((registration) => {
      if (registration) {
        setInterval(() => {
          registration.update();
        }, 1000 * 60 * 60 * 24);
      }
    });
  } else {
    console.log('Service Worker is not supported in this browser.');
  }
});
</script>

<style scoped lang="scss">
.rotate-icon-enter-active {
  animation: scaleYIn 0.3s;
}

.rotate-icon-leave-active {
  animation: scaleYIn 0.3s reverse;
}

@keyframes scaleYIn {
  0% {
    opacity: 0;
    transform: scaleY(0);
  }

  100% {
    opacity: 1;
    transform: scaleY(1);
  }
}
</style>

