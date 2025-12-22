<template>
  <el-breadcrumb :separator-icon="ArrowRight" class="ml-4" ref="breadcrumbRef">
    <transition-group name="breadcrumb">
      <!-- <transition-group name="breadcrumb" @enter="onEnter" :css="false"> -->
      <el-breadcrumb-item
        :to="{ path: item.name }"
        v-for="(item, index) in breadcrumbData"
        :key="item.name"
        :data-index="index"
      >
        <span>{{ item.meta?.title || '' }}</span>
      </el-breadcrumb-item>
    </transition-group>
  </el-breadcrumb>
</template>

<script setup lang="tsx">
import { useRoute } from 'vue-router'
// import gsap from 'gsap'

const ArrowRight = () => <i class="i-ep:arrow-right"></i>

// 获取页面路由数据
const route = useRoute()
const localData = ref()
// const change = ref(-1)

// 控制页面路由的
// const router = useRouter()

const breadcrumbData = ref<any>([])
const breadcrumbRef = ref()

function getBreadcrumbData() {
  if (route && route.matched) {
    breadcrumbData.value = route.matched.filter((item) => item.name && item.meta && item.meta.title)
    localData.value = route.matched.filter((item) => item.name && item.meta && item.meta.title)
  }
}

useResizeObserver(breadcrumbRef, (entires) => {
  const { height } = entires[0].contentRect
  if (height > 14) {
    breadcrumbData.value.shift()
  }
})

const oldWidth = ref(-1)

const fn = useThrottleFn((entries) => {
  const { width } = entries[0].contentRect
  if (oldWidth.value === -1) {
    oldWidth.value = width
  }
  if (width > oldWidth.value) {
    // 说明屏幕在变宽
    if (breadcrumbRef.value) {
      if (breadcrumbRef.value.$el.offsetHeight <= 14) {
        let item
        // 留在页面上的数组里面还有元素
        if (breadcrumbData.value.length > 0) {
          const index = localData.value.findIndex((item) => item === breadcrumbData.value[0])
          item = localData.value[index - 1 <= 0 ? 0 : index - 1]
        } else {
          // 页面上已经无元素，那么应该从最后一个元素添加起
          item = localData.value[localData.value.length - 1]
        }
        // 判断，是否在页面上已经有了该元素，如果有，则不再添加
        if (breadcrumbData.value.indexOf(item) === -1) {
          breadcrumbData.value.unshift(item)
        }
      }
    }
  }
  oldWidth.value = width
}, 500)
useResizeObserver(document.body, fn)

// watch(breadcrumbData, (newVal, oldVal) => {
//   change.value = 0
//   for (let i = 0; i < Math.max(newVal.length, oldVal.length); i++) {
//     if (newVal.length < i || oldVal.length < i || newVal[i] !== oldVal[i]) {
//       change.value++
//     }
//   }
// })

// function onEnter(el, done) {
//   let index = el.dataset.index
//   // 子菜单之间进行切换
//   if (change.value === 1) {
//     index = 1
//   }
//   gsap.fromTo(
//     el,
//     {
//       opacity: 0,
//       x: 30
//     },
//     {
//       opacity: 1,
//       x: 0,
//       delay: index * 0.15,
//       onComplete: done
//     }
//   )
// }

watch(
  route,
  () => {
    getBreadcrumbData()
  },
  {
    immediate: true
  }
)
</script>

<style scoped lang="scss">
.breadcrumb-move,
.breadcrumb-enter-active,
.breadcrumb-leave-active {
  transition: all 0.5s;
}

.breadcrumb-enter-from,
.breadcrumb-leave-to {
  opacity: 0;
  transform: translateX(20px);
}

.breadcrumb-leave-active {
  position: absolute;
}
</style>
