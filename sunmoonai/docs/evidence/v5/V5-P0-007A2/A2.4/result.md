# V5-P0-007A2/A2.4 Rich/Utility Toolkit 施工证据

日期：2026-07-14  
状态：`ACCEPTED`

## 范围

只在 `tpl-app/tpl-admin-frontend` 建设领域无关的 React 富组件和通用工具，不引入
Info、Knowledge、Research DTO、接口 URL、业务规则或生产凭据。第三方富组件与 legacy
能力的取舍遵循 `ADR-015-frontend-rich-utility-boundaries.md`。

## 实现

- `app/components/rich/icon-registry.tsx`：本地 Lucide registry，未知 key 安全回退；不
  接受任意远程 SVG/HTML。
- `avatar-tools.tsx`：AvatarList overflow、键盘按钮和 AvatarMenu command。
- `metric-chart.tsx`：SVG metric chart，提供空/加载/错误状态和 accessible data table；
  消费方可在 adapter 层替换 renderer。
- `markdown-editor.tsx`：受控纯文本 Markdown boundary，预览使用 React text，不使用
  `dangerouslySetInnerHTML`。
- `media-player.tsx`：同源/相对 URL、原生 audio/video controls 和加载错误；拒绝协议相对
  或跨 origin 地址。
- `progress-tools.tsx`、`text-effects.tsx`：Progress、native details、watermark、typing/
  scroll effects；遵循 reduced-motion。
- `app/lib/rich-utils.ts`：duration/color、copy、debounce、throttle、long-press、drag、
  reduced-motion hooks；事件监听器在 cleanup 时移除。
- `/rich-reference`：中性 fixture 验收页，覆盖组件组合和错误边界，不代表业务页面。

## 验证

```text
pnpm install --frozen-lockfile --offline => PASS
pnpm typecheck                          => PASS
pnpm lint                               => PASS
pnpm test                               => PASS（9 files，37 tests）
pnpm test:e2e                            => PASS（Chromium，6 tests）
pnpm build                              => PASS（SPA Mode）
git diff --check                         => PASS
```

已覆盖：本地图标回退、Avatar overflow、SVG/表格可访问替代、文本预览与控制字符清理、
不安全媒体 URL、媒体加载错误、Progress/Collapse/Watermark 语义、copy/long-press、
Reference route 和 Playwright route/error smoke。Vitest 中 Ant Design/jsdom 的
`getComputedStyle`/CSS 警告是测试环境已知噪声，不影响断言结果。

固定模板提交：`tpl-admin-frontend@a9aed42e9c7d380e371144a03cab52e7c8288a80`。

## 明确边界

- Vditor CDN/WYSIWYG、ECharts 全量 option runtime、Howler/Video.js 高级播放、远程
  Iconify/NetIcon、PWA/Electron 没有被静默删除；当前三个 Admin 没有生产依赖，按 ADR-015
  标记为延期/专项 adapter。恢复必须提供真实页面、依赖/许可证/CSP/a11y/回滚证据。
- A2.4 接受不等于完整 P0-007A2 接受；A2.5 仍需完成全量 WCAG/a11y、responsive/
  reduced-motion、clean-room、Docker/Nginx/KIND 和生产门禁。三个 App 仍不得开始 React
  基础替换。
