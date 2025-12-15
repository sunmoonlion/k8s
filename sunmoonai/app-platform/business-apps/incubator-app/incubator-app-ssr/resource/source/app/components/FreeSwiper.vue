<template>
  <div>
    <!-- Swiper Container -->
    <div 
      ref="swiperContainer"
      class="swiper"
      :class="GetClassAndStyle(props.height).class"
      :style="GetClassAndStyle(props.height).style"
      v-bind="$attrs"
    >
      <!-- Swiper Wrapper -->
      <div class="swiper-wrapper">
        <!-- Swiper Slides -->
        <div class="swiper-slide" v-for="(item, index) in items" :key="index">
          <slot :item="item">
            <div class="w-full h-full bg-cover bg-no-repeat bg-center-top"
              :style="{ backgroundImage: `url(${item.image})` }">
              <Container class="h-full">
                <div class="flex flex-col justify-center items-start">
                  <p class="text-4xl font-bold text-white">{{ item.title }}</p>
                  <p class="text-xl text-gray-100 pt-4">{{ item.subTitle }}</p>
                </div>
              </Container>
            </div>
          </slot>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// core version + navigation, pagination, scrollbar, autoplay modules:
import Swiper from 'swiper'
import  { Navigation, Pagination, Scrollbar, Autoplay } from 'swiper/modules';
// import Swiper and modules styles
import 'swiper/css';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import 'swiper/css/scrollbar';

  
// 定义 props
import type { SwiperItemType } from './types';
import type { PropType } from 'vue';
import type { Swiper as SwiperType } from 'swiper';

const props = defineProps({
  height: {
    type: String,
    default: 'h-80',
  },
  items: {
    type: Array as PropType<Array<SwiperItemType>>,
    default: () => [],
  },
});

  
// 定义 Swiper 初始化逻辑
import { onMounted, onBeforeUnmount, nextTick, ref } from 'vue';

const swiperContainer = ref<HTMLElement | null>(null);
let swiperInstance: SwiperType | null = null;

onMounted(() => {
  if (import.meta.client && swiperContainer.value) {
    nextTick(() => {
      swiperInstance = new Swiper(swiperContainer.value!, {
        modules: [Navigation, Pagination, Scrollbar, Autoplay], // 添加 Autoplay 模块
        slidesPerView: 1,
        spaceBetween: 0,
        navigation: {
          prevEl: '.prev',
          nextEl: '.next',
        },
        pagination: {
          el: '.pagination',
          type: 'fraction',
        },
        scrollbar: {
          el: '.swiper-scrollbar', // 滚动条容器
          hide: false,  // 设置为false使得滚动条始终可见
          draggable: true, // 允许拖动滚动条
        },
        autoplay: {
          delay: 3000, // 自动播放时间间隔，单位毫秒
          disableOnInteraction: false, // 用户交互后继续自动播放
        },
        loop: true, // 循环播放
      });
    });
  }
});

onBeforeUnmount(() => {
  if (swiperInstance) {
    swiperInstance.destroy(true, true);
    swiperInstance = null;
  }
});

// 动态样式和类名生成函数
function GetClassAndStyle(str: string) {
  return {
    style: /(rem|em|px)/.test(str) ? { height: str } : {},
    class: /h-/.test(str) ? str : '',
  };
}
</script>
