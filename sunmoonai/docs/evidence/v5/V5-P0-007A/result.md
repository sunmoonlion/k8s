# V5-P0-007A tpl-app React Admin 生产骨架执行证据

日期：2026-07-11  
状态：ACCEPTED

## 固定产物

- 仓库：`/home/zymun/tpl-app`
- 模板：`tpl-admin-frontend-react`
- Git commit：`fe8fc5cfd2a9d23f4f8a1bcd0465440b2341d85e`
- 依赖锁：`tpl-admin-frontend-react/pnpm-lock.yaml`
- 本地镜像：`tpl-admin-frontend-react:p0-007a`
- Image/manifest-list digest：`sha256:51a16cb429fc3c1041b380a9a500b4e094afbb6efbe7268798715bfbfa03f25a`
- Image config digest：`sha256:0188257c12962f1d780bf15ecf2c44a22e283c281291bb3be5117df3c757143c`

技术基线为 React 19.2.7、React Router Framework Mode 8.2.0、TypeScript 5.9.3、Vite 7.3.6、Ant Design 6.5.0、TanStack Query 5 和 Zustand 5。生产构建为 `ssr: false` 的静态 SPA；最终镜像仅含 Nginx 1.30.1，不含 Node runtime。

## 实现结果

- 新建 React Admin 模板；原 `tpl-admin-frontend` Vue 模板零修改。
- 提供 route modules/typegen、protected layout、session/demo auth 接入点、typed API/error/correlation ID、i18n、Query/UI state 分工及 403/404/global error。
- Shell 对齐 Vue Admin 的侧栏、菜单、面包屑、页签、用户区和内容密度。
- 中性 Reference Page 覆盖筛选、分页、表格、详情 Drawer、确认操作和错误/空状态，不含三个领域的业务代码。
- Nginx 提供 history fallback、根路径和非根 `BASE_PATH` 资源 fallback、健康检查、HTML no-store、hash asset immutable cache 与安全响应头。
- 文档覆盖 Vue/React 映射、新增页面、数据流与迁移方式。

## 自动化验证

```text
pnpm typecheck
=> PASS（React Router typegen + tsc --noEmit）

pnpm lint
=> PASS

pnpm test
=> PASS（3 files，5 tests）

pnpm exec prettier --check .
=> PASS

pnpm test:e2e
=> PASS（Chromium，2 tests，一次通过）
```

浏览器 smoke 覆盖 Vue 对齐 Shell 导航、Reference Drawer、main/menu/heading landmarks、登录操作可见和键盘 focus。该结果是基础可访问性 smoke，不声称替代完整 WCAG 审计。

## Build、Nginx 与 base path

根路径 Docker build 在 build stage 执行 typecheck、unit test 和 React Router build，结果：

```text
SPA Mode: Generated build/client/index.html
manifest list sha256:51a16cb429fc3c1041b380a9a500b4e094afbb6efbe7268798715bfbfa03f25a
```

`BASE_PATH=/admin pnpm build` 成功，生成的 manifest、entry、route chunks 均使用 `/admin/assets/*`。将该产物只读挂载到相同 Nginx 配置后：

```text
GET /admin/           => 200 text/html, Cache-Control: no-store
GET /admin/reference  => 200 text/html, history fallback
GET /admin/assets/*   => 200 application/javascript, public immutable
```

根路径镜像运行时复核：

```text
GET /health           => 200 text/plain, ok
GET /                 => 200, history root
GET /reference        => 200, history fallback
GET /assets/*.js      => 200, one-year immutable cache
nginx -t              => successful
command -v node       => absent
```

HTML、健康检查和静态资源响应均包含 CSP、`X-Content-Type-Options: nosniff`、`X-Frame-Options: DENY`、Referrer Policy 与 Permissions Policy。

## Kubernetes smoke

镜像导入本地 KIND 后，在 `app-platform-dev` 创建一次性 Pod；未创建 Ingress、未修改三个 App、未切流量：

```text
pod/v5-p0-007a-smoke condition met
GET 127.0.0.1/health => ok
phase=Running, ready=true, restartCount=0
imageID=docker.io/library/import-2026-07-11@sha256:51a16cb429fc3c1041b380a9a500b4e094afbb6efbe7268798715bfbfa03f25a
pod deleted
```

## 回滚与限制

- Vue 模板仍为当前默认和回退路径；React 模板未同步到任何 App，也未承接流量。
- 回滚 React 模板只需 revert `fe8fc5c`；当前镜像未进入任何长期 Deployment。
- `VITE_AUTH_MODE=demo` 仅用于开发/E2E，生产构建显式拒绝该值。
- P0-007A 只证明通用模板；真实 Artifact/Delivery 契约、权限失败、审计操作和真实 K8s Deployment 属于 P0-007B，不能用 Reference fixture 替代验收。
- Node 22.22 build image 在进入 P0-007C/M1 前必须按 digest 镜像到 Harbor；不得因镜像缺失回退 Node 18。
- 未执行 `git push`；由项目负责人按仓库流程推送。
