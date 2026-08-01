# V5-P0-008B/B3 Web Interaction + Nest Pair 证据

状态：`ACCEPTED / B4_NEXT`

日期：2026-07-22（Asia/Shanghai）

## 1. 固定提交与范围

| 单元 | B3 固定提交 |
| --- | --- |
| `tpl-web-backend`（当前仍为 Nest） | `e1876a4ff669dfafcdde994f34d8a03fa9965b9a` |
| `tpl-web-frontend`（Next） | `d10cffa4fcfb73fa561a5a697bb45214c69fdb7d` |
| `tpl-app` gitlink | `8b1df6af4544aa287548ed368a5be319de1348c4` |

B3 只完成语言无关 Web interaction v1、Nest adapter boundary、Next 中性 reference
workspace 和真实 Next+Nest 进程级配对门禁。它没有修改三个业务 Web 仓、没有创建
FastAPI Web Backend、没有改名 Nest 仓、没有部署 KIND，也没有产生正式 release tag 或
镜像 digest；这些属于 B4/B5/B6。

## 2. Contract 与所有权

新增 `sunmoonai.web.interaction/v1`：

- `RunSnapshot`、严格有序 `RunEvent`、HITL `RunAction` 和稳定 Error envelope 均为
  exact-field browser boundary；未知字段、provider credential 和不匹配事件类型被拒绝。
- SSE 以 `event_id` 作为传输 id，以每个 Run 单调递增的 `sequence_no` 投影；重复事件去重，
  sequence gap 先重新拉取 snapshot，再从最新 cursor 恢复。
- Citation 不复制新 DTO：Web contract 通过 `$ref` 消费 Knowledge-owned
  `citation.schema.json`，并锁定其 SHA-256
  `b5cf350f4a9360cfd2211d66fcd65018fd3f1f1300e8071a480ce5ffcaa768c8`。
- 浏览器只能访问同源 `source_href`；Nest 在当前 principal 下重新授权证据解析，再返回
  受限相对地址，匿名请求不能取得来源。
- 清单逐文件固定摘要；4 个 Draft 2020-12 Schema、正式向量、2 个负向向量和外部 Citation
  引用已使用 `jsonschema` 验证通过。

## 3. Nest 与 Next 实现

Nest 提供 `WebInteractionPort` 和动态注册模块，覆盖 snapshot、SSE、HITL command 与
Citation resolution。所有下游返回值在离开 BFF 前重新做严格 runtime validation；浏览器
请求继续由 B2 的 session、ownership adapter、Origin/CSRF 和稳定错误边界保护。

Next 提供严格 Zod consumer、同源 typed client、TanStack Query projection、SSE
event-id 绑定、去重、gap reconciliation、有界指数退避，以及中性 Answer/Citation/HITL/
错误/离线状态。reference surface 默认关闭，只在受控测试环境显式启用。

`FixtureInteractionAdapter`、fixture session guard 和固定 Run 数据只位于 Nest `test/fixtures`
中；生产 `AppModule` 未导入 fixture。Playwright 启动真实 Nest 进程、Next standalone
进程和模拟正式 `/api/* -> Backend` 拓扑的入口网关，不再使用独立 ad-hoc mock server。

## 4. 质量门禁

Nest：

```bash
cd /home/zymun/tpl-app/tpl-web-backend/app
pnpm check
```

结果：typecheck、scoped lint、36/36 unit、2/2 HTTP E2E、Nest/SWC 204 files build
全部通过。

Next：

```bash
cd /home/zymun/tpl-app/tpl-web-frontend/app
pnpm check
pnpm test:e2e
```

结果：typecheck、lint、i18n（2 locales、64 keys）、31/31 unit/component、Next 16.2.2
production build、6/6 Chromium 全部通过。浏览器矩阵验证：

- public route 与 SSR 匿名 redirect；
- opaque session 经 Nest 校验后才渲染受权 workspace；
- SSE delta、Citation、HITL 和 terminal snapshot；
- 匿名 Citation source 为 401，受权解析为 302 到同源受限地址；
- not-found 与 runtime sitemap。

受限执行环境首次禁止本机测试进程绑定端口，导致 Nest Supertest 与 Turbopack 返回 EPERM；
在允许本机临时测试端口后，同一代码的全部门禁通过。这不是产品代码失败，也没有通过放宽
应用安全配置规避。

## 5. 固定静态门禁

```bash
cd /home/zymun/k8s
python sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b3.py
```

结果：

```json
{"backend_commit":"e1876a4ff669dfafcdde994f34d8a03fa9965b9a","backend_e2e_tests":2,"backend_unit_tests":36,"business_web_repositories_unchanged":true,"contract_version":1,"fixture_in_production_module":false,"frontend_commit":"d10cffa4fcfb73fa561a5a697bb45214c69fdb7d","frontend_tests":31,"paired_playwright_tests":6,"parent_commit":"8b1df6af4544aa287548ed368a5be319de1348c4","provider_tokens_exposed":false,"result":"passed","secrets_printed":false,"task":"V5-P0-008B-B3-source"}
```

## 6. 退出结论与下一游标

B3 的实现、契约、测试、固定提交和证据齐全，状态为 `ACCEPTED`。下一任务严格为 B4：
对当前 Next+Nest 执行真实 Casdoor/KIND、双 Pod、SSE/CSP、安全负向、滚动/version-skew、
回滚和不可变 tag/digest 门禁；全部通过后，才允许把现有 Nest 仓原子改名为
`tpl-web-backend-nest`。B4 前仍禁止创建新的 FastAPI `tpl-web-backend`，B6 前仍禁止同步
三个实例 App。
