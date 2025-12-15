<template>
  <div class="inline-block flex-1 mx-4 relative" ref="progressRef">
    <!-- 进度条 -->
    <span
      class="cursor-pointer z-50 absolute top-1/2"
      :style="{ left: left + 'px' }"
      @mousedown="startDrag"
      @touchstart="startDrag"
    >
      <i
        class="absolute left-0 top-1/2 translate-x--1/2 translate-y--1/2 block i-ic:outline-circle text-2xl color-[var(--el-color-primary)]"
      >
      </i>
      <i
        class="absolute left-0 top-1/2 translate-x--1/2 translate-y--1/2 block i-ic:round-circle text-xl color-[var(--el-bg-color)] z-20"
      >
      </i>
    </span>
    <div
      class="h-2 w-full bg-[var(--el-fill-color-darker)] rounded cursor-pointer"
      @mousedown="jumpTo"
      @touchstart="jumpTo"
    >
      <div
        class="h-2 bg-[var(--el-color-primary)] rounded-l absolute z-10"
        :style="{ width: left + 'px' }"
      ></div>
    </div>
  </div>
</template>

<script setup lang="ts">
// [0,1]
const modelValue = defineModel('modelValue', { default: 0 })

const left = ref(0)
const progressRef = ref()
const progressWidth = ref(0)
onMounted(() => {
  if (progressRef.value) {
    progressWidth.value = progressRef.value.offsetWidth
  }
})

// watch(left, (newVal) => {
//   if (progressWidth.value && !flag) {
//     modelValue.value = Math.min(Math.max(newVal / progressWidth.value, 0), 1)
//   }
// })

// modelValue -> left ; left -> modelValue
watch(modelValue, (newVal) => {
  if (!isNaN(newVal) && typeof newVal !== 'undefined') {
    left.value = newVal * progressWidth.value
  }
})

useResizeObserver(progressRef, (entries) => {
  const { width } = entries[0].contentRect
  left.value = modelValue.value * width
  progressWidth.value = width
})

function updatePosition(clientX, startX) {
  if (progressRef.value) {
    const rect = progressRef.value?.getBoundingClientRect()
    const originLeft = startX - rect.left
    // 拿到偏移量
    const newLeft = Math.min(
      Math.max(originLeft + clientX - startX, 0),
      progressRef.value.offsetWidth
    )
    left.value = newLeft
    modelValue.value = newLeft / progressRef.value.offsetWidth
  }
}

function startDrag(e) {
  e.preventDefault(e)
  const isTouch = e.type === 'touchstart'
  const startX = isTouch ? e.touches[0].clientX : e.clientX

  const onMove = (moveEvent) => {
    const clientX = isTouch ? moveEvent.touches[0].clientX : moveEvent.clientX
    updatePosition(clientX, startX)
  }

  const onEnd = () => {
    document.removeEventListener(isTouch ? 'touchmove' : 'mousemove', onMove)
    document.removeEventListener(isTouch ? 'touchEnd' : 'mouseup', onEnd)
  }

  document.addEventListener(isTouch ? 'touchmove' : 'mousemove', onMove)
  document.addEventListener(isTouch ? 'touchEnd' : 'mouseup', onEnd)
}

// 点击跳转
function jumpTo(e) {
  e.preventDefault(e)
  const isTouch = e.type === 'touchstart'
  const startX = isTouch ? e.touches[0].clientX : e.clientX
  const rect = progressRef.value?.getBoundingClientRect()
  updatePosition(startX, rect.left)
}
</script>

<style scoped></style>
