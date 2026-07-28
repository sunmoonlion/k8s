# V5-P0-007E Next Admin 默认模板与 FastAPI Admin 配对

状态：`ACCEPTED`

验收日期：2026-07-28（Asia/Shanghai）

## 1. 结论

新的 canonical `tpl-admin-frontend` 已使用 React 19 + Next 16 App Router + Node
standalone 建成，并逐项消费固定 React Router Admin legacy 的通用能力矩阵。它与
canonical FastAPI `tpl-admin-backend` 完成真实 Casdoor、严格 TLS、session/CSRF、
角色拒绝、审计、两副本、滚动/version-skew、回滚、clean-room 和不可变产物门禁。

P0-007E 没有修改 Info、Knowledge、Research 的源码、gitlink、Deployment、镜像或流量。
本任务接受后恢复 P0-008B/B6；P0-009 仍等待 B6，不允许越序同步实例。

## 2. 固定 tuple

| 产物 | 固定值 |
|---|---|
| Next Admin implementation commit | `6d3b28f12722a765bdde57f5832a07e773a35836` |
| Next Admin release commit | `fb69795b04e0b888a2917c3936f7f80aeac79cc9` |
| Next Admin Git tag | `p0-007e-next-admin-20260728` |
| Next Admin remote | `https://gitee.com/sunmoonlion/tpl-admin-frontend.git` |
| FastAPI Admin commit | `69e634b8e5b06da9d1dcd01c9b1350e0571d74bd` |
| FastAPI Admin Git tag | `p0-007e-admin-backend-20260728` |
| Parent commit | `7089e191b10d4ff33109691cf5e5e1b7f0dd8efe` |
| Parent Git tag | `p0-007e-next-admin-parent-20260728` |
| Accepted frontend digest | `sha256:b426551c0e027b25965995e23486c590c29fa52047779dd14721d93a245a74f1` |
| Rollback frontend digest | `sha256:f08d5a5840979e0435c28965eceeac84ea8afc6b24ed1996540864357275b251` |
| Accepted backend digest | `sha256:b24ce7a39e7e10a5541b2a29ff9795a6944d6f17ec4d0479e2051f59a0688c56` |
| Contract version | `1` |
| Final deployment identity | `p0-007e-accepted-6d3b28f-69e634b` |

`fb69795` 只把已经通过的能力矩阵标记为 ACCEPTED；其 `app/` tree 与构建镜像的
`6d3b28f` 完全一致。

## 3. 源码与通用能力门禁

- Node `24.18.0`、pnpm `10.24.0` 与冻结 lockfile；
- typecheck、lint、62 个双语 key 一致性检查通过；
- 10 个 Vitest 文件、42 个 unit/component 测试通过；
- Next production build 和 10 个 Chromium E2E 通过；
- 响应式 Shell、单一导航元数据、tabs、主题/密度/语言、public/protected/403/404、
  Query/Zustand 状态边界、CRUD、审计、上传下载和 rich-tool 安全边界均有实现与测试；
- authenticated SSR 响应为 `no-store`，新浏览器上下文读取 `/api/auth/me` 为 `401`；
- 模板没有业务资源模型，因此不伪造 owner negative；真实资源 ownership 必须由
  P0-009/M1 实例任务在领域资源上验证。

## 4. 真实 FastAPI/Casdoor 配对

严格 CA 校验下的真实浏览器结果保存在 `browser-pair.json`：

- anonymous `401`；
- real Casdoor login 后 authenticated `200`；
- invalid CSRF `403`；
- gate identity 的真实 non-admin role 被 server DAL 拒绝；
- `tpl:admin` 已由授权请求显式申请，合法写请求到达禁用下游并返回预期 `503`，而不是
  因 scope 漏配错误返回 `403`；
- logout `204`，退出后再次读取为 `401`；
- token、cookie、OIDC code/state/nonce、PKCE verifier 和 credential 均未输出。

## 5. Docker、KIND 与回滚

- accepted 镜像为 Node standalone，运行用户 UID `1001`，KIND 使用只读根文件系统、
  drop all capabilities、`/tmp` emptyDir；
- `/healthz` 动态返回 Admin surface 和 deployment identity，并禁止缓存；
- build proxy 只存在于 build stage；accepted 与 clean-room 最终运行镜像均无
  `HTTP_PROXY/HTTPS_PROXY` 环境残留；
- 生产必填环境变量缺失时镜像 fail-fast；
- FastAPI 与 Next 均为 `2/2`，PDB `minAvailable: 1`。

`rollout.json` 记录 accepted → rollback → accepted：

- 回滚期间严格 TLS 连续探测 `41` 次；
- 前滚期间严格 TLS 连续探测 `44` 次；
- 两方向各 `18` 个跨版本静态资源可读；
- 两个稳定点均重跑完整真实 Casdoor 浏览器门禁；
- 非目标业务 Deployment 快照不变；
- 最终状态恢复 accepted digest。

## 6. clean-room 与远端重放

从 Gitee `tpl-app@6fabab1` 首次递归 clean clone 后，在
`tpl-admin-frontend@6d3b28f` 执行冻结离线安装、typecheck、lint、i18n、42 tests、
production build、10 Playwright 和 clean-room Docker smoke，全部通过。随后正式父标签
`p0-007e-next-admin-parent-20260728` 再次递归 clone，精确检出：

```text
tpl-admin-backend        69e634b
tpl-admin-frontend       fb69795
tpl-admin-frontend-react 0b58adc
tpl-web-backend          6b6c71e
tpl-web-backend-nest     947021c
tpl-web-frontend         f746255
```

这证明新 canonical 仓、正式标签、父仓 gitlink 与全部既有 profile 可从远端重放。

## 7. 下一游标

P0-007E 已关闭。唯一下一代码任务恢复为 P0-008B/B6：对同一 Next Web 分别执行默认
FastAPI 和可选 Nest consumer/pair/release 门禁，并冻结统一模板 release。B6 接受后，
必须立即进入 P0-009A，再严格按 Info → Knowledge → Research 串行同步共同底座。

证据固化后已通过正式脚本删除 P0-007E 专用 Deployment、Pod、Service、PDB、
IngressRoute、PostgreSQL、Redis、migration、runtime Secret、Casdoor application 和
identity Secret；等待终止宽限期后，按 `sunmoonai.com/task=v5-p0-007e` 查询为空。清理前后
三个业务仓 HEAD 均保持 `info-app@37988c8`、`knowledge-app@2e410ad`、
`research-app@8121595`。
