# V5-P0-008B/B6 Frontend Common Kernel 与 Vue 参考配对证据

状态：`B6.1_ACCEPTED / B6.2_ACCEPTED / B6.3_ACCEPTED / B6.4_ACCEPTED / P0-008B_ACCEPTED`

验收日期：2026-07-28 / 2026-07-29（Asia/Shanghai）

## 1. 本次结论

B6.1 已把模板前端能力明确划分为 `COMMON`、`ADMIN_ONLY`、`WEB_ONLY`、`DEFERRED`，
并补齐 Next Web 缺少的通用能力核。能力实现门与前后端配对门继续是两个独立门禁：
组件/客户端代码通过，不能替代真实 FastAPI/Casdoor 配对。

B6.2 已把历史 Vue Admin 作为第七个子模块纳入 `tpl-app`，修正身份并补齐当前
FastAPI Admin 的 session/CSRF/POST logout、同源 API、CSP、无运行时 CDN、非 root、
只读根文件系统和可重复测试。Vue 与 canonical FastAPI Admin 完成真实配对及
`Vue -> Next -> Vue` 恢复验证。

Vue tuple 固定为 `REFERENCE_ONLY`。它不进入默认模板 release，也不进入
Info/Knowledge/Research 的 P0-009 传播清单。

现行模板配对矩阵同时显式保留 P0-007D 已验收的
`React Router Admin + FastAPI Admin`。该 tuple 与 Vue 一样属于 `REFERENCE_ONLY`，
但仍保留真实 Casdoor、严格 TLS、2+2、CSRF/logout、双向回滚和固定 digest 证据；
不能因为它退出默认仓名而从兼容清单中删除。

## 2. 固定源码与产物

| 单元 | 固定值 |
|---|---|
| Next Web COMMON implementation | `400fa6478ceca2e0c274cf35c3b45879a1530498` |
| Vue Admin reference implementation | `9b3d29b8913989970f3da5093ee84d4f7d4cdfcf` |
| FastAPI Admin accepted implementation | `69e634b8e5b06da9d1dcd01c9b1350e0571d74bd` |
| Parent implementation | `aa04199` |
| Vue candidate tag | `tpl-admin-frontend-vue:b6-reference-20260728` |
| Vue immutable digest | `sha256:5380b1b56b3c6f0c825b2e0a2df03b0e23517eb8de6d440edccbe2579b738a57` |
| FastAPI Admin immutable digest | `sha256:b24ce7a39e7e10a5541b2a29ff9795a6944d6f17ec4d0479e2051f59a0688c56` |
| Next Admin recovery digest | `sha256:b426551c0e027b25965995e23486c590c29fa52047779dd14721d93a245a74f1` |

父仓保留外部 `/home/zymun/tpl-admin-frontend-vue` 工作副本，但唯一模板固定点是
`tpl-app/tpl-admin-frontend-vue` 子模块与其 gitlink。

## 3. B6.1 COMMON 能力门

`frontend-capability-matrix.json` 固定 7 项 COMMON：

- session/CSRF；
- API/error/correlation；
- Query/mutation；
- table/form/description/feedback；
- audited action/upload/download；
- safe rich/chart/progress；
- theme/locale/responsive。

Admin Shell/menu/tabs/settings 仍是 `ADMIN_ONLY`；public SEO/SSR/cache 与
Run/SSE/HITL/Citation 仍是 `WEB_ONLY`。没有把整套 Admin 页面复制进 Web，也没有提前
建立共享 UI 包。

Next Web 通过 typecheck、lint、双语 64 key、10 个 Vitest 文件和 42 个测试；
API 测试覆盖同源 `/api`、CSRF、correlation 和错误归一化，查询测试覆盖分页边界、
下载路径和文件名清理。

静态门结果见 `common-kernel.json`。

## 4. Vue 源码、构建与容器门

Vue 参考模板通过：

- `vue-tsc --build`；
- 维护兼容面的 ESLint；
- 1 个 Vitest 文件、4 个认证测试；
- Vite production build；
- Docker clean build 内再次执行上述全部门禁；
- UID `101`、Nginx `8080`、无 Node、只读根文件系统、drop capabilities；
- `/health`、深链接 fallback、静态资源 404、严格 CSP/security headers。

旧 Vue 依赖树仍产生约 3.32 MiB 主 chunk（gzip 约 1.05 MiB），并包含 PWA/Electron/
ECharts/Vditor/Video.js/Howler 历史能力。因此它只作为理解、审计和灾难恢复输入；
默认 Next 模板不会继承这些依赖。

## 5. 真实配对门

隔离拓扑复用已接受 P0-007E 的 FastAPI Admin 基础设施脚本，但最终验收时前端已经替换为
Vue/Nginx 固定 digest；引导 Next 不计入 Vue 成功证据。最终前后端均为 `2/2`。

严格 CA 校验下的真实浏览器结果：

- anonymous `/api/auth/me`：`401`；
- real Casdoor login 后：`200`；
- invalid CSRF：`403`；
- 合法 scope/CSRF 到达禁用下游：`503`；
- gate identity 不具备 admin role，角色负向成立；
- POST logout：`204`，退出后：`401`；
- CSP 完整、无 `unsafe-eval`；
- 应用运行时无第三方 CDN 主机；
- credential、token、cookie、OIDC code/state/nonce、PKCE verifier 均未输出。

机器可读结果见 `vue-pair.json`。

## 6. 独立恢复门

同一 FastAPI Admin 与同一隔离数据库/session 基础设施上执行：

```text
Vue reference -> accepted Next Admin -> Vue reference
```

两个稳定点均重跑真实 Casdoor、session、CSRF、角色负向和 logout 门禁。切换期间
FastAPI Admin digest 未变化，Info/Knowledge/Research 的 Deployment 镜像快照未变化，
最终恢复 Vue 固定 digest。结果见 `vue-rollback.json`。

## 7. B6.3 Dual Web Profile 配对门

同一 Next Web（含 `expires_at` 对 FastAPI `+00:00` 的 DTO 修复）对默认 FastAPI Web
与可选 Nest Web 完成共享 consumer vectors、真实 Casdoor、严格 TLS、2+2、SSE/CSRF/
资源授权和独立前后端回滚。Info/Knowledge/Research Deployment 镜像快照未变化。

| 单元 | 固定值 |
|---|---|
| Next Web commit | `1db9377d38dac5510331149d9122f8d375d83fe3` |
| FastAPI Web commit | `289f2c46410e0aa2891fdf3da28242ceb1a33bdb` |
| Nest Web commit | `8a24e24126c86a0faccdedbc6c5474b3ffc9cef4` |
| FastAPI candidate digest | `sha256:41dc3a781033dda3e60cd3594ffac7caf767e3c8cb2295ac0b8a21986fbd2414` |
| Nest candidate digest | `sha256:8d17b350df03968c4a847a4f089a2145e3ba326cdbb16db1f2996146cb359536` |
| Next Web candidate digest（r3） | `sha256:2a359c8d213813ecbc3b5dbf6a6ed828e73a4c26b6dffaa1d163a507756db2b3` |
| Next Web rollback baseline digest（r2） | `sha256:d695dc24c29890ebf58c327c0f19d31f9a2283d462777c36de632367aa39437a` |
| FastAPI rollback baseline digest（B5） | `sha256:f47f1ddd633cb3e8fa8561780a05e53c2f660193aed672d6b553d700dc9f2773` |
| Nest rollback baseline digest（B4） | `sha256:78b9929ddf6735341768093ae1093fd0f05420f581189af60913577d6f2f2e3a` |

机器可读证据：

- `consumer-vectors.json`
- `b63f-pair.json` / `b63f-rollback.json`
- `b63n-pair.json` / `b63n-rollback.json`
- 更新后的 `pairing-matrix.json`

隔离 B6.3F runtime 与 Casdoor application 已 cleanup；既有 B4 Nest 拓扑已恢复到验收前
digest，未保留候选镜像占用。

## 8. B6.4 Unified Release / Clean-room

从本地固定 commit 对七个子模块执行 fresh `git clone` + `git clean -fdx`，重放
install/typecheck/lint/unit(/e2e)/build；校验既有不可变镜像 digest；引用 B6.2/B6.3/007D/007E
的配对与回滚证据。未推 Gitee，因此远端递归 clone 重放记为
`deferred_until_push_authorized`。

`template_release_id`：`p0-008b-b6-unified-20260729`

默认 release（进入 P0-009 传播）：

| 组件 | commit | digest |
|---|---|---|
| Next Admin | `fb69795` | `sha256:b426551c…` |
| FastAPI Admin | `69e634b` | `sha256:b24ce7a3…` |
| Next Web | `1db9377` | `sha256:2a359c8d…` |
| FastAPI Web | `289f2c4` | `sha256:41dc3a78…` |

非默认 profile（只留模板门 / 恢复边界，不进入业务实例）：

| 组件 | class | commit | digest |
|---|---|---|---|
| React Router Admin | `REFERENCE_ONLY` | `0b58adc` | `sha256:358f2445…` |
| Vue Admin | `REFERENCE_ONLY` | `9b3d29b` | `sha256:5380b1b5…` |
| Nest Web | `OPTIONAL` | `ecb01d9` | `sha256:8d17b350…` |

机器可读证据：`unified-clean-room.json`；父仓清单：
`tpl-app/template-release-manifest.json`。

说明：冻结的 FastAPI Admin tree 在当前锁内 `ruff 0.16.0` 下出现一处
`ruff format --check` 漂移；`ruff check` 与 pytest 通过，已记为
`format: tool_skew_recorded`，未改动冻结 commit。

## 9. 下一游标

B6.1~B6.4 与 P0-008B 关闭。P0-009A 已冻结三实例迁移基线（见
`sunmoonai/docs/evidence/v5/V5-P0-009A/result.md`）。唯一下一任务是 **P0-009B**：
只在 Info 原地同步四默认组件共同底座并验收；通过前不得开始 Knowledge。
