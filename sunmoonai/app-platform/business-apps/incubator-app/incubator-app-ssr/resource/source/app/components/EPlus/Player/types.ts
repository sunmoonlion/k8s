import type { Component } from 'vue'

export interface VideoJsOptions {
  // Standard <video> Element Options
  autoplay?: boolean | string
  controlBar?: {
    remainingTimeDisplay?: {
      displayNegative?: boolean
    }
  }
  controls?: boolean
  height?: string | number
  loop?: boolean
  muted?: boolean
  poster?: string
  preload?: 'auto' | 'metadata' | 'none'
  src?: string
  width?: string | number

  // Video.js-specific Options
  aspectRatio?: string
  audioOnlyMode?: boolean
  audioPosterMode?: boolean
  autoSetup?: boolean
  breakpoints?: {
    tiny?: number
    xsmall?: number
    small?: number
    medium?: number
    large?: number
    xlarge?: number
    huge?: number
  }
  children?: Array<any> | Object
  disablePictureInPicture?: boolean
  enableDocumentPictureInPicture?: boolean
  experimentalSvgIcons?: boolean
  fluid?: boolean
  fullscreen?: {
    options?: {
      navigationUI?: string
    }
    [key: string]: any
  }
  id?: string
  inactivityTimeout?: number
  language?: string
  languages?: Object
  liveui?: boolean
  liveTracker?: {
    trackingThreshold?: number
    liveTolerance?: number
  }
  nativeControlsForTouch?: boolean
  normalizeAutoplay?: boolean
  notSupportedMessage?: string
  noUITitleAttributes?: boolean
  playbackRates?: Array<number>
  plugins?: Object
  preferFullWindow?: boolean
  responsive?: boolean
  restoreEl?: boolean | Element
  skipButtons?: {
    forward?: number
    backward?: number
  }
  sources?: Array<{
    src: string
    type: string
  }>
  suppressNotSupportedError?: boolean
  techCanOverridePoster?: boolean
  techOrder?: Array<string>
  userActions?: {
    click?: boolean | Function
    doubleClick?: boolean | Function
    hotkeys?: boolean | Function | Object
  }
  vttjs?: string
  [key: string]: any
}

export type VideoPlayerOptions = VideoJsOptions

export interface VideoPlayerProps {
  options?: VideoJsOptions
  slots?: Component
}

export interface HowlerOptions {
  src: string | string[] // 音轨的源路径（URL或base64数据URI）
  volume: number // 音轨的音量，从0.0到1.0
  html5: boolean // 设置为true强制使用HTML5 Audio
  loop: boolean // 设置为true以自动循环播放声音
  preload: boolean | 'metadata' // 自动开始下载音频文件，如果使用HTML5 Audio，可以设置为'metadata'以仅预加载文件的元数据
  autoplay: boolean // 设置为true在声音加载后自动开始播放
  mute: boolean // 设置为true以静音加载音频
  sprite: { [key: string]: [number, number, boolean?] } // 定义声音的音轨精灵
  rate: number // 播放速率，从0.5到4.0，1.0为正常速度
  pool: number // 非活动声音池的大小
  format: string[] // 显示指定文件格式
  xhr: {
    method?: string
    headers?: { [key: string]: string }
    withCredentials?: boolean
  } // 使用Web Audio时的XHR请求选项
  onload: () => void // 载入完成时触发
  onloaderror: (soundId: number, error: string) => void // 载入错误时触发
  onplayerror: (soundId: number, error: string) => void // 播放错误时触发
  onplay: (soundId: number) => void // 开始播放时触发
  onend: (soundId: number) => void // 播放完成时触发
  onpause: (soundId: number) => void // 暂停时触发
  onstop: (soundId: number) => void // 停止时触发
  onmute: (soundId: number) => void // 静音/取消静音时触发
  onvolume: (soundId: number) => void // 音量变化时触发
  onrate: (soundId: number) => void // 播放速率变化时触发
  onseek: (soundId: number) => void // 搜索时触发
  onfade: (soundId: number) => void // 渐变完成时触发
  onunlock: () => void // 音频自动解锁时触发
}

export type AudioPlayerOptions = HowlerOptions & HowlerGlobalOptions

export type HowlerMethods = {
  play: (spriteOrId?: string | number) => number | void
  pause: (id?: number) => void
  stop: (id?: number) => void
  mute: (muted?: boolean, id?: number) => void
  volume: (volume?: number, id?: number) => number | void
  fade: (from: number, to: number, duration: number, id?: number) => void
  rate: (rate?: number, id?: number) => number | void
  seek: (seek?: number, id?: number) => number | void
  loop: (loop?: boolean, id?: number) => boolean | void
  state: () => 'unloaded' | 'loading' | 'loaded'
  playing: (id?: number) => boolean
  duration: (id?: number) => number
  on: (event: string, fn: Function, id?: number) => void
  once: (event: string, fn: Function, id?: number) => void
  off: (event: string, fn?: Function, id?: number) => void
  load: () => void
  unload: () => void
  // play: [spriteOrId?: string | number]
  // pause: [id?: number]
  // stop: [id?: number]
  // mute: [muted?: boolean, id?: number]
  // volume: [volume?: number, id?: number]
  // fade: [from: number, to: number, duration: number, id?: number]
  // rate: [rate?: number, id?: number]
  // seek: [seek?: number, id?: number]
  // loop: [loop?: boolean, id?: number]
  // state: []
  // playing: [id?: number]
  // duration: [id?: number]
  // on: [event: string, fn: Function, id?: number]
  // once: [event: string, fn: Function, id?: number]
  // off: [event: string, fn?: Function, id?: number]
  // load: []
  // unload: []
}

export type ControlsType = 'prev' | 'next' | 'forward' | 'rewind' | 'volume' | 'rate' | 'mode'

export interface AudioPlayerProps {
  options?: AudioPlayerOptions
  title?: string
  controls?: ControlsType[]
}

export type AudioPlayerMethods = HowlerMethods

export type AudioPlayerEvents = {
  init: [ins: any]
  prev: []
  next: []
  mode: [index: number]
}

export interface HowlerGlobalOptions {
  usingWebAudio: boolean
  noAudio: boolean
  autoUnlock: boolean
  html5PoolSize: number
  autoSuspend: boolean
  ctx: boolean // 注意：这里的类型可能需要根据具体实现调整
  masterGain: boolean // 注意：这里的类型可能需要根据具体实现调整
}
export type HowlerGlobalOptionsKeys = keyof HowlerGlobalOptions

export interface HowlerGlobalMethods {
  mute: (muted: boolean) => void
  volume: (volume?: number) => number | void
  stop: () => void
  codecs: (ext: string) => boolean
  unload: () => void
}
