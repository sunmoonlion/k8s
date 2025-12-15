<template>
  <div class="w-full">
    <!-- title -->
    <slot name="title" v-if="title">
      <div class="py-2" v-scrollText="{ delay: 2000, duration: 5000 }">
        {{ title }}
      </div>
    </slot>
    <!-- player -->
    <div class="flex items-center w-full flex-wrap">
      <!-- 播放控制 -->
      <div class="flex items-center lt-sm:(w-full justify-between py-3)">
        <!-- 循环控制按钮 -->
        <span
          @click="handleLoopChange"
          class="hidden over lt-sm:(block text-xl flex items-center )"
          v-if="hasName('mode')"
        >
          <!-- 普通列表 -->
          <i class="i-bi:sort-down-alt" v-if="loop === 0"></i>
          <!-- 列表循环 -->
          <i class="i-cil:loop" v-else-if="loop === 1"></i>
          <!-- 单句循环 -->
          <i class="i-cil:loop-1" v-else-if="loop === 2"></i>
          <!-- 随机列表 -->
          <i class="i-ps:random" v-else></i>
        </span>
        <div class="flex items-center">
          <i
            class="i-iconoir:skip-prev lt-sm:(text-3xl)"
            @click="handleChangeAudio('prev')"
            v-if="hasName('prev')"
          ></i>
          <i
            class="i-iconoir:play mx-2 lt-sm:(text-5xl mx-9)"
            @click="togglePlay"
            v-if="!state.isPlay"
          ></i>
          <i class="i-iconoir:pause mx-2 lt-sm:(text-5xl mx-9)" @click="togglePlay" v-else></i>
          <i
            class="i-iconoir:skip-next lt-sm:(text-3xl)"
            @click="handleChangeAudio('next')"
            v-if="hasName('next')"
          ></i>
        </div>
        <!-- 速率控制按钮 -->
        <span
          class="cursor-pointer hidden min-w-10 lt-sm:(block text-xl) text-right select-none"
          @click="handleRateChange"
          v-if="hasName('rate')"
          >{{ rateList[rateCurrent] }}x</span
        >
      </div>
      <!-- 进度条部分 -->
      <div class="flex items-center flex-1 mx-4 flex-wrap lt-sm:mx-0">
        <div class="hidden lt-sm:(block flex justify-between py-2 w-full)">
          <span class="text-sm min-w-10 text-center">{{ formatTime(state.progress) }}</span>
          <!-- 播放总体时间 -->
          <span class="text-sm">{{ formatTime(state.duration) }}</span>
        </div>
        <i
          class="i-iconoir:backward-15-seconds lt-sm:(text-2xl)"
          @click="seekPlayback(PlayAction.Rewind)"
          v-if="hasName('rewind')"
        ></i>
        <!-- 进度条 -->
        <div class="flex-1 flex items-center mx-2 lt-sm:(my-2)">
          <!-- 播放时间 -->
          <span class="text-sm min-w-10 text-center lt-sm:(hidden)">{{
            formatTime(state.progress)
          }}</span>
          <ProgressBar v-model="progress"></ProgressBar>

          <!-- 播放总体时间 hh:mm:ss -->
          <span class="text-sm lt-sm:(hidden)">{{ formatTime(state.duration) }}</span>
        </div>
        <i
          class="i-iconoir:forward-15-seconds lt-sm:(text-2xl)"
          @click="seekPlayback(PlayAction.Forward)"
          v-if="hasName('forward')"
        ></i>
      </div>
      <div
        class="flex items-center mx-2 lt-sm:(w-full mx-0 my-2 justify-between) lt-sm:(hidden)"
        v-if="controls?.some((o) => ['volume', 'rate', 'mode'].includes(o))"
      >
        <i class="flex items-center group" v-if="hasName('volume')">
          <!-- 静音&音量调节按钮 -->
          <ProgressBar
            v-model="state.volume"
            class="transition-width invisible w-0 mx-0! group-hover:(visible w-[80px] ml-2! mr-4!)"
          ></ProgressBar>
          <i class="i-clarity:volume-mute-line mr-3" v-if="isMute" @click="toggleVolume"></i>
          <i class="i-clarity:volume-up-line mr-3" v-else @click="toggleVolume"></i>
        </i>
        <!-- 速率控制按钮 -->
        <span
          class="mr-3 cursor-pointer min-w-8 text-center select-none"
          @click="handleRateChange"
          v-if="hasName('rate')"
          >{{ rateList[rateCurrent] }}x</span
        >
        <!-- 循环控制按钮 -->
        <span @click="handleLoopChange" class="flex items-center" v-if="hasName('mode')">
          <!-- 普通列表 -->
          <i class="i-bi:sort-down-alt" v-if="loop === 0"></i>
          <!-- 列表循环 -->
          <i class="i-cil:loop" v-else-if="loop === 1"></i>
          <!-- 单句循环 -->
          <i class="i-cil:loop-1" v-else-if="loop === 2"></i>
          <!-- 随机列表 -->
          <i class="i-ps:random" v-else></i>
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type {
  AudioPlayerProps,
  HowlerGlobalOptionsKeys,
  AudioPlayerOptions,
  AudioPlayerEvents,
  ControlsType
} from './types'
import { Howl, Howler } from 'howler'
import { exposeEventsUtils, formatTime } from '@/utils'

const keys: HowlerGlobalOptionsKeys[] = [
  'usingWebAudio',
  'noAudio',
  'autoUnlock',
  'html5PoolSize',
  'autoSuspend',
  'ctx',
  'masterGain'
]

const exposeArr = [
  'play',
  'pause',
  'stop',
  'mute',
  'volume',
  'fade',
  'rate',
  'seek',
  'loop',
  'state',
  'playing',
  'duration',
  'on',
  'once',
  'off',
  'load',
  'unload'
]

type Options = Partial<AudioPlayerOptions>

const defaultAudioOptions: Options = {
  volume: 1,
  loop: false,
  rate: 1,
  mute: false
}

const props = withDefaults(defineProps<AudioPlayerProps>(), {
  controls: () => ['prev', 'next', 'forward', 'rewind', 'volume', 'rate', 'mode']
})

const progress = ref(0)
// 速率列表
const rateList = ref([0.5, 1, 1.5, 2])
const rateCurrent = ref(1)
const audioInstance = ref()

const emits = defineEmits<AudioPlayerEvents>()
const exposes = exposeEventsUtils(audioInstance, exposeArr)
defineExpose({ ...exposes })

enum PlayAction {
  Forward,
  Rewind
}

// 循环控制
const loop = ref(0)
const state = reactive({
  isPlay: false,
  duration: 0,
  progress: 0,
  volume: 1,
  oldVolume: 1,
  oldIsPlay: false,
  oldLoop: false
})

// 切换静音
const [isMute, toggle] = useToggle(false)

// 进度条变化
watch(progress, (newVal) => {
  if (audioInstance.value && newVal) {
    audioInstance.value.seek(newVal * state.duration)
    state.progress = newVal * state.duration
  }
})

// 音量变化
watch(
  () => state.volume,
  (newVal) => {
    if (audioInstance.value && !isNaN(newVal)) {
      audioInstance.value.volume(newVal)
      toggle(newVal <= 0)
    }
  },
  {
    deep: true
  }
)

// 监听options的变化
watch(
  () => props.options,
  (newOptions) => {
    // 记录旧的播放状态
    state.oldIsPlay = state.isPlay
    audioInstance.value.unload()
    const options = Object.assign({}, newOptions, { volume: state.volume })
    init(options)
  },
  {
    deep: true
  }
)

onBeforeMount(() => {
  init(props.options)
})

onBeforeUnmount(() => {
  if (audioInstance.value) audioInstance.value.unload()
})

// 切歌
const handleChangeAudio = (name: string) => {
  if (name === 'prev') emits('prev')
  if (name === 'next') emits('next')
  // 非循环模式
  if (loop.value !== 2) {
    state.progress = 0
    if (state.isPlay && audioInstance.value) {
      audioInstance.value.pause()
    }
  }
}

const step = () => {
  // 实例未创建
  if (!audioInstance.value) return
  state.isPlay = audioInstance.value.playing()
  // 音频未播放
  if (!state.isPlay) return
  state.progress = audioInstance.value.seek() || 0

  // 设置进度条的百分比
  progress.value = state.progress / state.duration

  requestAnimationFrame(step)
}

const togglePlay = () => {
  if (audioInstance.value) {
    state.isPlay ? audioInstance.value.pause() : audioInstance.value.play()
  }
}

// 快进快退
const seekPlayback = (type) => {
  if (audioInstance.value) {
    if (type === PlayAction.Forward) {
      state.progress = state.progress + 15 > state.duration ? state.duration : state.progress + 15
    }
    if (type === PlayAction.Rewind) {
      state.progress = state.progress - 15 < 0 ? 0 : state.progress - 15
    }
    progress.value = state.progress / state.duration
    audioInstance.value.seek(state.progress)
  }
}

// 静音切换
const toggleVolume = () => {
  toggle()
  if (isMute.value) {
    state.oldVolume = state.volume
  }
  if (audioInstance.value) {
    audioInstance.value.mute(isMute)
    const oldVolume = state.oldVolume === 0 ? 1 : state.oldVolume
    state.volume = isMute.value ? 0 : oldVolume
  }
}

// 速率切换
const handleRateChange = () => {
  rateCurrent.value++
  if (rateCurrent.value >= rateList.value.length) {
    rateCurrent.value = 0
  }
  if (audioInstance.value) {
    audioInstance.value.rate(rateList.value[rateCurrent.value])
  }
}

// 循环切换
const handleLoopChange = () => {
  loop.value++
  if (loop.value >= 4) {
    loop.value = 0
  }
  // 循环模式
  if (loop.value === 2) {
    state.oldLoop = props.options?.loop || false
    if (audioInstance.value) {
      audioInstance.value.loop(true)
    }
  } else {
    if (audioInstance.value) {
      audioInstance.value.loop(state.oldLoop)
    }
  }
  emits('mode', loop.value)
}

function runDefault(name, options, ...args) {
  if (options) {
    const onfunDefault = options[name]
    onfunDefault && onfunDefault(args)
  }
}

// 初始化
function init(options) {
  // const options = props.options
  if (options) {
    keys.forEach((key) => {
      if (key in options) {
        ;(Howler as any)[key] = options[key]
      }
    })
    state.volume = typeof options.volume === 'undefined' ? 1 : options.volume
  }

  audioInstance.value = new Howl(
    Object.assign(defaultAudioOptions, options, {
      onload: () => {
        runDefault('onload', options)
        state.duration = audioInstance.value.duration()
        if (state.oldIsPlay) audioInstance.value.play()
        state.oldIsPlay = false
      },
      onplay: (soundId: number) => {
        runDefault('onplay', options, soundId)
        step()
      },
      onend: () => {
        runDefault('onend', options)
        emits('next')
      }
    })
  )
  emits('init', audioInstance.value)
}

function hasName(name: ControlsType) {
  return (props.controls || []).includes(name)
}
</script>

<style scoped lang="scss">
i {
  @apply cursor-pointer;
}

:deep(.el-dropdown-menu__item) {
  &.active {
    color: var(--el-dropdown-menuItem-hover-color);
    background-color: var(--el-dropdown-menuItem-hover-fill);
  }
}
</style>
