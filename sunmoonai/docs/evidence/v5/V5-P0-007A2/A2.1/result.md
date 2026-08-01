# V5-P0-007A2 / A2.1 React Admin Shell 验收证据

日期：2026-07-13  
状态：ACCEPTED（仅 A2.1；P0-007A2 总任务仍为 IN_PROGRESS）

## 固定版本

- canonical 子仓库：`tpl-app/tpl-admin-frontend`
- A2 开工基线：`7a04bbe301bce4287734673e233e9e7155d2f5e4`
- A2.1 实现提交：`d2fa1a842d2ec94ee48d5a6c338d510cb4270e8a`
- 能力矩阵接受提交：`451d22f3ef13a8f04b52233768841b3562549b1f`
- `tpl-app` 父仓 gitlink 提交：`cad55543b8d28838e1f6e10ea5c2d128b32840af`
- 依赖锁：`tpl-app/tpl-admin-frontend/pnpm-lock.yaml`，本轮 frozen install 未产生漂移

## 实现范围

- 单一导航元数据驱动嵌套菜单、面包屑、页签和角色过滤；前端过滤只改善导航体验，不替代服务端资源授权。
- 桌面 Sider 与移动 Drawer 响应式切换，路由变化后自动关闭移动导航。
- 固定首页、关闭当前后的确定性回退、关闭其他/左侧/右侧/全部，以及按当前权限对持久化标签进行对账。
- 主题模式、主题色、舒适/紧凑密度、中文/英文、标签与面包屑显示偏好；Zustand 只持久化 UI 偏好，不保存服务端领域事实。
- route/global error boundary 提供恢复动作，并在生产模式隐藏原始异常文本。
- 更新 Vue -> React 映射、数据流、新增页面说明和细粒度能力矩阵；不引入 Info、Knowledge、Research 业务 DTO 或规则。

## 验证结果

```text
pnpm install --frozen-lockfile --offline
=> PASS（369 packages 均来自本地缓存，lockfile 无变化）

pnpm lint
=> PASS

pnpm typecheck
=> PASS（react-router typegen + tsc --noEmit）

pnpm test
=> PASS（Vitest：6 files，16 tests）

pnpm test:e2e
=> PASS（Playwright Chromium：4 tests）

pnpm exec prettier --check app tests e2e docs
=> PASS（写入统一格式后复核）

pnpm build
=> PASS（Vite client build 5.42s；SSR environment build 75ms；SPA Mode 生成 build/client/index.html）

git diff --check
=> PASS
```

Playwright 覆盖桌面导航/面包屑/详情抽屉/页签关闭、键盘可达的 landmark 与登录动作、主题/密度/语言刷新持久化，以及移动 Drawer 导航。Vitest 覆盖权限过滤、未授权已知路由、标签批量关闭与权限对账、设置状态和全局错误恢复动作。

## 安全与边界

- A2.1 的角色过滤不是授权边界；真实 session、CSRF、401/403、资源 owner/scope 和 logout 属于 P0-005 与 A2.2。
- `VITE_AUTH_MODE=demo` 仍只允许开发/E2E；本任务未把 demo 身份用于生产验收。
- 本任务未同步三个业务 Admin、未构建或切换业务镜像、未修改 K8s 流量。
- 本次 `pnpm build` 证明生产编译通过，但 Docker/Nginx/KIND、base path、完整 a11y/security negative 与 clean-room 重建仍由 A2.5 统一验收。

## 回滚与后续

- 子仓实现可回滚 `d2fa1a8`，矩阵接受记录可回滚 `451d22f`；父仓通过 `cad5554` 固定当前子仓版本。
- P0-007A2 不得因 A2.1 接受而标记完成，也不得向三个 App 推广模板。
- 下一串行任务为 P0-005；只有 P0-005/ADR-005 接受后才开始 A2.2 Identity/Data Foundation。
