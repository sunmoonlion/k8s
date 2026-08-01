# ADR-018：Admin/Web 前端统一采用 Next.js

状态：ACCEPTED（2026-07-26）

## 背景

P0-007 已把 Vue Admin 的通用能力迁移为 React 19 + React Router 8 Framework Mode SPA，
并以 Nginx 静态部署；P0-008 已把 Web 重基线为 React 19 + Next 16 App Router +
`standalone` Node。两条路线都可运行，但会长期维护两套路由、SSR/DAL、错误边界、i18n、
构建、Docker/K8s 和配对测试模型。

B5 已固定两个独立 FastAPI BFF：

```text
tpl-admin-backend@456bd65
tpl-web-backend@6b6c71e
```

因此现在统一前端框架不会要求合并 Admin/Web Backend，也不会改变两个 surface 的身份和
数据所有权边界。

## 决策

1. Admin 与 Web 默认前端均采用 React 19 + Next 16 App Router。
2. 两者均使用自托管 `standalone` Node 运行形态；Admin 不再以 Nginx 静态 SPA 作为默认
   模板。
3. Admin 与 Web 继续保持独立仓库、Casdoor client/audience、cookie、Redis namespace、
   Backend、Deployment、域名、release tuple 和 E2E。
4. Next 只承担 UI、SSR、server-only DAL、DTO 校验、路由/缓存和浏览器体验；`/api/*`
   仍由对应 FastAPI BFF 处理。禁止用 Next Route Handler 建立第三套通用 BFF。
5. authenticated Admin workspace 与 Web workspace 均为 dynamic/no-store；公开内容可按
   surface 的 route matrix 使用 static/SSG/受控 ISR。
6. Browser 只持有对应 BFF 的 HttpOnly session cookie；Next SSR 只向固定内部 Backend
   URL 转发 allowlist cookie、locale 和 correlation ID，不持有 Provider token。
7. 新 canonical `tpl-admin-frontend` 从固定 `tpl-web-frontend` 工程底座导出到空仓，使用
   新历史初始化；不能继承 Web Git 历史，也不能原样保留 Web workspace、Run/SSE/
   Citation 产品语义。
8. 已验收的 React Router Admin 先与 B5 Admin Backend 完成最终配对闭环，再原子改名为
   `tpl-admin-frontend-react`，只作可追溯 legacy/reference，不进入三个业务实例。
9. 新 Next Admin 必须消费 React Admin 的完整通用能力矩阵，逐项标记
   `adopted / adapted / deferred-with-trigger / rejected`；不得以共享 Shell 或登录页代替
   功能等价。
10. P0-009 只向 Info、Knowledge、Research 同步 Next Admin + FastAPI Admin 和
    Next Web + FastAPI Web 四个默认组件；Nest Web 与 React Router Admin 均不进入实例。

## 默认配对

```text
tpl-admin-frontend + tpl-admin-backend
  Next Node         + FastAPI Admin BFF

tpl-web-frontend + tpl-web-backend
  Next Node       + FastAPI Web BFF

tpl-web-frontend + tpl-web-backend-nest
  Next Node       + Nest Web BFF（可选模板 profile）
```

同为 Next 或同为 FastAPI 不代表合并服务。配对由 surface、audience、cookie、contract、
internal URL、镜像 digest、部署和回滚 tuple 定义。

## 施工顺序

```text
P0-007D React Admin Legacy Closure + 原子改名
  ->
P0-007E Next Admin Template + FastAPI Admin Pair
  ->
P0-008B/B6 Next Web Dual-profile Gate
  ->
P0-009A~E Info -> Knowledge -> Research
```

P0-007D/E 插入后，B6 不再是当前立即任务。P0-007E 与 B6 全部接受前不得生成统一模板
release；P0-009E 前不得新增普通业务功能或开始 P0-008C。

## P0-007D 退出条件

- 固定 React Admin、B5 Admin Backend commit/tag/image digest；
- 当前二者的 auth/me、login/callback、CSRF、logout、错误契约和严格 TLS 配对通过；
- React Admin 远端、父仓 path/gitlink/tag 原子改名为
  `tpl-admin-frontend-react`，旧 canonical 名称释放；
- 记录独立恢复步骤，不把 legacy React Router profile 加入业务发布矩阵。

## P0-007E 退出条件

- 新空远端 `tpl-admin-frontend` 使用固定 Next Web 工程 tree 作为可追溯输入并建立新历史；
- Web 专属路由、文案、Run/SSE/Citation 和 env 被显式删除或 Admin 化；
- React Admin 通用能力矩阵无未解释遗漏；
- 同源 `/api`、server-only Admin DAL/DTO、Admin session、CSRF、CSP、i18n、a11y、
  loading/error/not-found 和 route/cache matrix 完整；
- typecheck/lint/unit/component/contract/Playwright/clean-room/Docker/KIND、非 root、
  两副本、严格 TLS、滚动/version-skew/回滚通过；
- Next Admin + FastAPI Admin 有独立固定 commit/tag/digest/contract/recovery tuple；
- 三个业务 App 未提前修改。

## 被修订的既有决定

- ADR-013 中“Admin 默认 React Router SPA/Nginx”由本 ADR 取代；其 Vue 能力盘点、React
  Admin 历史实现和已验收证据继续作为迁移输入。
- ADR-016 中 Admin 配对的前端运行形态改为 Next Node；Web 双 Backend profile 决策不变。
- ADR-017 中四默认组件的 Admin Frontend 改为新 Next `tpl-admin-frontend`；模板先行、
  三实例串行收敛和禁止插入业务开发的纪律不变。

## 后果

- 收益：统一 App Router、server-only DAL、DTO、i18n、错误边界、测试、Node runtime、
  Docker/K8s 和前端发布模型。
- 成本：Admin 新增 Node 运行时、滚动升级、缓存和资源容量责任；必须重新实现并验证现有
  React Admin 的通用能力。
- 安全：Node 不扩大身份权限；最终认证和资源授权仍由对应 FastAPI BFF 完成。
- 回滚：P0-007D 固定的 React Router Admin 只用于模板迁移回滚和审计；业务实例仍使用各自
  Vue 迁移前 tag/image，直到 P0-009/M1 等价与切流门通过。
