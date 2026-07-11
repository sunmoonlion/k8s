# ADR-013：前端技术栈与渲染策略

状态：ACCEPTED
日期：2026-07-11
决策者：项目负责人、架构评审

## 1. 背景

`tpl-app` 及三个实例当前不是“两套 Vue”：

- `tpl-web-frontend` 与三个 Web 已是 React 19 + Next.js App Router。
- `tpl-admin-frontend` 与三个 Admin 是 Vue 3 + Vite SPA + Element Plus，由 Nginx 静态部署。

v5 要同时建设 Research Agent 工作台与 Info/Knowledge/Research 治理面。继续永久维护 React Web/Vue Admin 会分裂类型、路由、组件、测试、身份、安全和流式交互生态；但把内部 Admin 全部改为 Next 又会引入没有明确收益的 Node/RSC/SSR 运行复杂度。

当前 Admin 真实业务量仍小，是进行受控替换的合适窗口。

## 2. 决策

1. 六个前端统一 React + TypeScript 开发生态。
2. 三个 Web 保持 Next.js App Router，并按页面/组件采用 SSG/SSR/CSR 混合策略。
3. 三个 Admin 采用 React Router Framework Mode + Vite，配置 `ssr: false`，生成 SPA 静态产物并继续由 Nginx 部署。
4. 不采用 Nuxt，不为 Admin 增加 Node Server，不把“统一 React”误解为“统一 Next”。
5. TanStack Query 管理 API server state；React Router 管理 route module、进入条件、pending/error 和代码拆分。Router loader 不复制 Query cache。
6. 现有 Vue Admin 为迁移期 legacy；React 等价替换完成后归档，不永久提供 Vue/React 两套默认模板。
7. 先并行创建 `tpl-admin-frontend-react` 最小生产模板，再用 Info Artifact/Delivery 真实薄切验证，禁止用 Hello World 判定模板完成。
8. 不在 Vue 页面内长期混嵌 React；迁移以路由/应用边界替换，旧实现保持可回退直到等价门禁通过。
9. React Admin 在页面布局、菜单/导航、交互密度、配置和部署接口上尽量与现有 Vue Admin 对齐，并提供 Vue -> React 文件与概念映射；内部仍采用标准 React/Router/Query 分工，不机械翻译 Vue API 或继承未采用的 Electron/PWA/自动导入包袱。
10. React Admin v1 采用 React Router 8 与 Ant Design 6；Ant Design Table 是默认表格实现。只有真实业务数据量、编辑或虚拟化需求证明其不足时，才以单场景 ADR 引入专项 Data Grid，禁止预先并存两套完整 UI/表格体系。

## 3. 产品面策略

| 产品面 | 决策 |
|---|---|
| Info Web | Next；公开内容 SSG/ISR/SSR，登录交互 CSR |
| Knowledge Web | Next；入口可服务端渲染，受权检索 CSR |
| Research Web | Next 应用壳；Agent workspace/SSE/HITL 为 Client Components |
| 三个 Admin | React Router Framework Mode SPA；Nginx 静态部署 |

## 4. React Router 模式理由

不用仅含基础 `<BrowserRouter>` 的 Declarative Mode，因为共享模板需要类型安全 route module、统一 pending/error 和自动代码拆分。相比手工 Data Mode，Framework Mode 提供 Vite 插件、类型生成和项目约定；`ssr: false` 仍是纯 SPA，不等同 SSR 或全栈 Node 应用。

参考：

- [React Router modes](https://reactrouter.com/start/modes)
- [React Router rendering strategies](https://reactrouter.com/start/framework/rendering)
- [React Router deployment](https://reactrouter.com/start/framework/deploying)
- [Next.js App Router](https://nextjs.org/docs/app)

## 5. Template Spike 最小验收

模板必须同时证明：

- React/TypeScript strict、Framework Mode、`ssr: false`、route type generation 和 lazy splitting。
- protected layout、login callback、403/404、route/global error boundary、pending/empty/error。
- TanStack Query、typed API client、稳定错误模型和 correlation ID。
- i18n、键盘/基础可访问性、CSP/CSRF/CORS/session 约束。
- Vitest/Testing Library/Playwright、build、Nginx SPA fallback、Docker/K8s smoke。
- 不直接访问 internal API，不在不受控持久存储保存 token。
- `vue-react-mapping`、新增页面、数据流和迁移指南齐全；Reference Page 覆盖熟悉的表格/筛选/详情/Dialog/权限/错误路径。

真实 Info Artifact/Delivery 薄切必须另外证明表格、筛选、详情、异步状态、受权 retry/deactivate 和审计原因；业务代码不得回流模板。

## 6. 迁移与回滚

- React 模板验收前不改变现有三个 Admin 流量。
- 每个 App 独立完成 contract、功能、安全、可访问性和浏览器 E2E 等价后切换。
- 迁移期间 Vue 只修复严重缺陷，不并行开发同一项新平台能力。
- 任一实例切换失败可回退旧 Vue 镜像/路由；数据和 API 契约不依赖前端框架。
- 三个实例完成后，React 版本成为默认 `tpl-admin-frontend`；Vue 归档为 tag/历史分支。

## 7. 后果

正向：统一 React 人员与测试生态；Web 保留 Next 能力；Admin 保留静态部署和较小运行面；现在迁移成本低于 M1 治理页面完成后迁移。

代价：短期存在两个 Admin 模板；需要重建现有 Vue shell/组件；Element Plus 不能直接复用；Ant Design 与 Ant Table 必须通过 Info 真实薄切继续验证。该短期双轨必须有退出条件，不能演变为永久双栈。
