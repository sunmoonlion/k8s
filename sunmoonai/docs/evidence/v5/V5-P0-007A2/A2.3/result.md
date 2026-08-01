# V5-P0-007A2/A2.3 CRUD Toolkit 施工证据

日期：2026-07-14  
状态：`ACCEPTED`

## 范围

只在 `tpl-app/tpl-admin-frontend` 建设与领域无关的 CRUD 基础能力，不引入
Info、Knowledge、Research DTO、接口 URL 或业务规则；Reference Page 只使用
中性 fixture。

## 已实现

- `app/components/crud/data-table.tsx`：统一 Table 的 loading、empty、error、retry
  边界；列、分页、排序和 query adapter 由消费方注入。
- `app/components/crud/schema-form.tsx`：声明式字段 schema、校验规则和提交 adapter。
- `app/components/crud/resource-description.tsx`：只读详情与空态。
- `app/components/crud/audited-action-modal.tsx`：写操作必须提供最小长度原因，
  支持 confirm loading 和错误回调，不产生未处理 Promise rejection。
- `app/components/crud/feedback.tsx`：从 Ant Design App provider 获取统一通知入口。
- `app/components/crud/contract-upload.tsx`：上传 transport 由 App 注入，模板不持有
  领域 URL 或凭据；包含文件大小边界。
- `app/lib/download.ts`：Blob 下载和 same-origin 下载 URL 校验。
- `app/components/crud/server-query.ts`：服务端分页、排序和筛选的 transport-neutral
  参数 contract；固定页码/页大小边界和稳定 query 编码，支持消费方注入 `AbortSignal`。
- `app/components/crud/use-crud-mutation.ts`：受审计 mutation 的 correlation/operation
  context、请求 header contract 和 `idle/running/succeeded/failed` 状态转移。
- Reference Page 已改用 DataTable、ResourceDescription、AuditedActionModal，并展示
  中性上传/下载 adapter。

## 验证

```text
pnpm install --frozen-lockfile --offline => PASS
pnpm typecheck                          => PASS
pnpm lint                               => PASS
pnpm test                               => PASS（8 files，31 tests）
pnpm test:e2e                            => PASS（Chromium，5 tests）
pnpm build                              => PASS（SPA Mode）
git diff --check                         => PASS
```

已覆盖：Table 空态/错误态/重试、分页/排序/筛选参数归一化和 query 编码、审计原因校验、
mutation correlation/operation header 与状态转移、SchemaForm 提交、上传 adapter、
same-origin 下载 URL、Blob 下载调用、Ant Design notification provider 集成、dialog/label/button
基础可访问性语义和既有 Reference Page 行为。浏览器验证使用固定模板启动流程，未接入任何
Info/Knowledge/Research 领域接口或凭据。

## 边界与后续

- 这里的可访问性是 A2.3 基础 role/label/dialog smoke；完整键盘路径、屏幕阅读器、响应式和
  reduced-motion 矩阵属于 A2.5 Production Gate，不能以本证据替代。
- 领域 App 必须提供自己的 resource DTO、query/mutation adapter、后端授权和错误映射；模板
  contract 不代表 Info/Knowledge/Research 业务已迁移。
- A2.4 Rich/Utility 尚未开始；A2.3 接受后仍禁止向三个 App 直接替换前端。

A2.3 已接受，可以进入 A2.4；在 A2.5 与 P0-007A2 整体接受前，仍不得开始任何三个 App 的
React 基础替换。
