<template>
    <div>
      <!-- Swiper Container -->
      <div class="swiper"
      :class="GetClassAndStyle(props.height).class"
      :style="GetClassAndStyle(props.height).style">
        <!-- Swiper Wrapper -->
        <div class="swiper-wrapper">
          <!-- Swiper Slides -->
          <div class="swiper-slide" v-for="item in items" :key="item.image">
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
  
        <!-- Pagination -->
        <div class="pagination swiper-pagination w-unset! font-bold mr-4"></div>
  
        <!-- Navigation Buttons -->
        <div class="prev swiper-button-prev i-mdi-arrow-left-thin" style="font-size: 2rem"></div>
        <div class="next swiper-button-next i-mdi-arrow-right-thin" style="font-size: 2rem"></div>
  
        <!-- Scrollbar -->
        <div class="swiper-scrollbar"></div>
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
  // 定义 emit 事件
const emit = defineEmits(['slideChange']); // 子组件触发 slideChange 事件

    
  // 定义 Swiper 初始化逻辑
  import { onMounted, nextTick } from 'vue';
  onMounted(() => {
    nextTick(() => {
      new Swiper('.swiper', {
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
          delay: 1000, // 自动播放时间间隔，单位毫秒
          disableOnInteraction: false, // 用户交互后继续自动播放
        },
        on: {
        slideChange: (e) => {
          // 当 slideChange 事件发生时，使用 emit 将事件传递给父组件
          emit('slideChange',e);
        },
      },
      });
    });
  });
  
  // 动态样式和类名生成函数
  function GetClassAndStyle(str: string) {
    return {
      style: /(rem|em|px)/.test(str) ? { height: str } : {},
      class: /h-/.test(str) ? str : '',
    };
  }
  </script>
  