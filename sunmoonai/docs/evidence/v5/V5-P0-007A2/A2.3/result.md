# V5-P0-007A2/A2.3 CRUD Toolkit 施工证据

日期：2026-07-14  
状态：`IN_PROGRESS`

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
- Reference Page 已改用 DataTable、ResourceDescription、AuditedActionModal，并展示
  中性上传/下载 adapter。

## 验证

```text
pnpm install --frozen-lockfile --offline => PASS
pnpm typecheck                          => PASS
pnpm lint                               => PASS
pnpm test                               => PASS（8 files，27 tests）
pnpm test:e2e                            => PASS（Chromium，5 tests）
pnpm build                              => PASS（SPA Mode）
git diff --check                         => PASS
```

已覆盖：Table 空态/错误态/重试、审计原因校验、SchemaForm 提交、上传 adapter、
same-origin 下载 URL、Blob 下载调用和既有 Reference Page 行为。

## 尚未完成

- 服务端分页/排序/选择的 Query adapter contract 和请求取消/重试约定。
- 受审计写操作的 correlation/operation 对账与统一 mutation 状态。
- 通知 hook 的真实集成测试、键盘/屏幕阅读器和 reduced-motion 矩阵。
- 从固定 commit clean-room 重建后的组件证据和 A2.3 最终 commit/SHA。

A2.3 未接受前不得进入 A2.4，也不得开始任何三个 App 的 React 基础替换。
