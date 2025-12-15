<template>
  <div class="py-4">
    <!-- tab按钮，切换swiper中的slide -->
    <ul class="flex justify-evenly items-center w-full pb-4">
      <li
        v-for="(item, index) in titles"
        :key="index"
        :class="[
          'flex flex-col items-center cursor-pointer transition-all text-gray-400 item',
          { active: activeIndex === index }
        ]"
        @click="changeSlide(index)"
      >
        <div class="text-2xl border-b-2 pb-2 px-2 line">{{ index + 1 }}</div>
        <div class="pt-4 text">{{ item }}</div>
      </li>
    </ul>

    <div>
      <!-- Swiper Container -->
      <div
        ref="swiperRef"   
        class="swiper"
        :class="classAndStyle.class"
        :style="classAndStyle.style"
      >
        <!-- Swiper Wrapper -->
        <div class="swiper-wrapper">
          <!-- Swiper Slides -->
          <div
            class="swiper-slide"
            v-for="item in items"
            :key="item.image"
          >
            <slot :item="item">
              <div
                class="w-full h-full bg-cover bg-no-repeat bg-center-top"
                :style="{ backgroundImage: `url(${item.image})` }"
              >
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
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue';
import Swiper from 'swiper';
import type { Swiper as SwiperType } from 'swiper';
import { Navigation, Pagination, Scrollbar, Autoplay } from 'swiper/modules';
// import Swiper and modules styles
import 'swiper/css';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import 'swiper/css/scrollbar';

// Props类型定义
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
  titles: {
    type: Array as PropType<Array<String>>,
    default: () => [],
  },
});

const swiperRef = ref<SwiperType | null>(null);
const activeIndex = ref<number>(0);

// Tab 切换事件
const changeSlide = (index: number) => {
  swiperRef.value?.slideTo(index, 500);
  activeIndex.value = index;
};

// 定义 emit 事件
const emit = defineEmits(['slideChange']);

// 计算动态类和样式
const classAndStyle = computed(() => {
  return {
    style: /(rem|em|px)/.test(props.height) ? { height: props.height } : {},
    class: /h-/.test(props.height) ? props.height : '',
  };
});

// 初始化 Swiper 实例
onMounted(() => {
  nextTick(() => {
    if (swiperRef.value) {
      swiperRef.value = new Swiper(swiperRef.value.el as HTMLElement, {
        modules: [Navigation, Pagination, Scrollbar, Autoplay],
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
          el: '.swiper-scrollbar',
          hide: false,
          draggable: true,
        },
        autoplay: {
          delay: 1000,
          disableOnInteraction: false,
        },
        on: {
          slideChange: () => {
            emit('slideChange');
          },
        },
      });
    }
  });
});

// 组件销毁时销毁 Swiper 实例
onBeforeUnmount(() => {
  swiperRef.value?.destroy();
});
</script>

<style scoped lang="scss">
.swiper-button-disabled {
  color: rgba($color: #000, $alpha: 0.3);
}

.item {
  &.active,
  &:hover {
    .line {
      color: orange;
      border-color: orange;
    }
    .text {
      color: orange;
    }
  }
}

.prev,
.next {
  font-size: 2rem;
}

.pagination {
  font-weight: bold;
  margin-right: 1rem;
}
</style>
