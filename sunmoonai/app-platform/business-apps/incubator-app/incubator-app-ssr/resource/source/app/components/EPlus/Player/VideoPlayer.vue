<template>
  <div ref="videoRef">
    <video ref="playerRef" class="video-js"></video>
  </div>
</template>

<script setup lang="ts">
import type { VideoPlayerProps, VideoJsOptions } from './types'
import videojs from 'video.js'
import 'video.js/dist/video-js.min.css'

const props = defineProps<VideoPlayerProps>()

const videoRef = ref()
const playerRef = shallowRef<HTMLVideoElement>()
const videojsInstance = shallowRef<any>()

const emits = defineEmits(['init'])

const defaultOptions = {
  fluid: true,
  aspectRatio: '16:9',
  autoplay: false,
  controls: true,
  playbackRates: [0.5, 1, 1.5, 2, 2.5, 3],
  muted: false,
  loop: false
} as VideoJsOptions

watch(
  () => props.options,
  (newOptions) => {
    if (videojsInstance.value) {
      videojsInstance.value.pause()
      videojsInstance.value.dispose()

      const newVideo = document.createElement('video')
      newVideo.className = 'video-js'
      videoRef.value.appendChild(newVideo)
      playerRef.value = newVideo
      videojsInstance.value = videojs(playerRef.value, Object.assign(defaultOptions, newOptions))
      emits('init', videojsInstance.value)
    }
  }
)

watch(
  () => props.options?.sources,
  (sources) => {
    if (videojsInstance.value) {
      // 暂停视频播放
      videojsInstance.value.pause()
      videojsInstance.value?.reset()
      videojsInstance.value?.src(sources)
      videojsInstance.value?.load()
    }
  },
  {
    deep: true
  }
)

onMounted(() => {
  if (playerRef.value) {
    videojsInstance.value = videojs(playerRef.value, Object.assign(defaultOptions, props.options))
    // videojsInstance.value.getChild('ControlBar').addChild('button', {
    //   className: 'icon-1',
    //   clickHandler: function (event) {
    //     videojs.log('Clicked')
    //   }
    // })
    emits('init', videojsInstance.value)
  }
})

onBeforeUnmount(() => {
  if (videojsInstance.value) {
    videojsInstance.value?.dispose()
  }
})
</script>

<style lang="scss">
// .icon-1 {
//   &:before {
//     content: url('data:image/svg+xml,%3Csvg xmlns="http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg" width="16" height="16" viewBox="0 0 24 24"%3E%3Cpath fill="white" fill-rule="evenodd" d="M16.25 3.75v1.69l2 1.6V3.75h-2Zm3.5 4.49V3.5c0-.69-.56-1.25-1.25-1.25H16c-.69 0-1.25.56-1.25 1.25v.74l-.407-.326a3.75 3.75 0 0 0-4.686 0l-8.125 6.5a.75.75 0 0 0 .937 1.172l.781-.626v10.29H2a.75.75 0 0 0 0 1.5h20a.75.75 0 0 0 0-1.5h-1.25V10.96l.782.626a.75.75 0 0 0 .936-1.172L19.75 8.24Zm-.5 1.52l-5.844-4.675a2.25 2.25 0 0 0-2.812 0L4.75 9.76v11.49h3.5v-4.3c0-.664 0-1.237.062-1.696c.066-.492.215-.963.597-1.345s.854-.531 1.345-.597c.459-.062 1.032-.062 1.697-.062h.098c.665 0 1.238 0 1.697.062c.492.066.963.215 1.345.597s.531.853.597 1.345c.062.459.062 1.032.062 1.697v4.299h3.5V9.76Zm-5 11.49V17c0-.728-.002-1.2-.048-1.546c-.044-.325-.114-.427-.172-.484c-.057-.057-.159-.128-.484-.172c-.347-.046-.818-.048-1.546-.048c-.728 0-1.2.002-1.546.048c-.325.044-.427.115-.484.172c-.057.057-.128.159-.172.484c-.046.347-.048.818-.048 1.546v4.25h4.5ZM12 8.25a1.25 1.25 0 1 0 0 2.5a1.25 1.25 0 0 0 0-2.5ZM9.25 9.5a2.75 2.75 0 1 1 5.5 0a2.75 2.75 0 0 1-5.5 0Z" clip-rule="evenodd"%2F%3E%3C%2Fsvg%3E');
//   }
// }
</style>
