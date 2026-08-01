# ADR-015：Admin 富组件与通用工具边界

状态：ACCEPTED  
日期：2026-07-14  
决策范围：`tpl-app/tpl-admin-frontend` 的 A2.4 模板能力对齐

## 背景

三个 Vue Admin 的 `el-admin-components` 同时包含生产可复用能力和早期展厅/第三方
集成：ECharts/VueEcharts、Vditor、Howler、Video.js、Iconify/NetIcon，以及若干
directive。当前三个 App 的业务页面没有依赖这些第三方富组件；它们主要出现在组件/指令
示例页。若在 React 模板中直接复制 CDN、Vue directive 或全部第三方运行时，会扩大 CSP、
供应链、bundle 和 SPA 维护面，也会把展厅代码误当作业务契约。

## 决策

1. A2.4 先冻结与领域无关的 React boundary：本地图标 registry、Avatar、可访问 SVG
   chart、受控纯文本 Markdown editor、同源原生 audio/video、progress/details/watermark，
   以及 copy/debounce/throttle/drag/long-press/typing/scroll/reduced-motion utilities。
2. 模板不默认引入 Vditor CDN、远程 Iconify/NetIcon、Howler、Video.js 或 ECharts 全量
   option runtime。当前需要 rich WYSIWYG、音频播放队列、视频高级插件或复杂图表时，业务
   App 必须提出独立 adapter/ADR，证明数据量、交互、CSP、bundle 和可访问性需求后再引入。
3. Markdown 默认 preview 只显示文本，不使用 `dangerouslySetInnerHTML`；媒体 URL 默认
   仅允许相对路径或当前 origin，图标仅从本地 registry 取值。
4. Vue directive 不逐项机械翻译为 React directive；行为改为 hook/component，且必须有
   生命周期清理和 reduced-motion/keyboard 语义。PWA/Electron 继续 `DEFER`，除非有真实
   App 依赖和产品 owner。

## 后果与恢复条件

- 正向：模板保持静态 SPA、无 Node runtime/第三方 CDN 依赖，默认 CSP 和测试面较小；
  通用能力已有稳定的 React 接入点，业务 App 可替换 renderer/adapter。
- 代价：A2.4 不承诺 Vditor/Howler/Video.js/ECharts 的逐 API 兼容；需要这些能力的
  业务必须承担专项依赖、契约、a11y、bundle 和回滚验证。
- 恢复条件：任何 App 提交真实页面/依赖证明、资源安全评估、依赖锁与许可证审查、浏览器
  错误矩阵和回滚镜像后，重新打开本 ADR 的对应条目；不得以“示例页需要”为由直接恢复。
