# V5-P0-007D React Router Admin Legacy 最终配对与原子改名

状态：`ACCEPTED`

验收日期：2026-07-28（Asia/Shanghai）

## 1. 结论

React Router 8 Framework Mode（`ssr:false`）+ Nginx Admin legacy 已与 B5 固定
FastAPI Admin Backend 完成最后一次真实 Casdoor、严格 TLS、双副本、滚动和双向回滚
配对。它已经从默认仓名退出，并原子改名为 `tpl-admin-frontend-react`，只作为
P0-007E 的完整能力迁移输入、审计和恢复 profile。

本任务没有创建 Next Admin，也没有修改 Info、Knowledge 或 Research 的源码、gitlink、
Deployment、镜像或流量。

## 2. 固定 tuple

| 产物 | 固定值 |
|---|---|
| Legacy source commit | `0b58adc4035d2b695646b0700dfc2fb707d14b57` |
| Legacy Git tag | `p0-007d-react-legacy-20260728` |
| Legacy remote | `https://gitee.com/sunmoonlion/tpl-admin-frontend-react.git` |
| Parent commit | `a280ea2eed40d2eb262e428918961299490e2026` |
| Parent Git tag | `p0-007d-react-legacy-parent-20260728` |
| Accepted frontend digest | `sha256:358f24459dcf62b52cd10fcb84a0fa2ac6432d5b96dff2b07d279bc3f98759e2` |
| Rollback frontend digest | `sha256:4eda1d8db806855ec43893d493c623918759aa07a18314362fd17a0c6077c8f8` |
| B5 Admin Backend commit | `456bd65be77140f07c46ab00b955ab376f3052d2` |
| B5 Admin Backend digest | `sha256:0fe898a76e33fd72fba53c1c1c4cd9f9d51ea0a8632c75c16705f41efa8e29ba` |
| Contract version | `1` |
| Final deployment identity | `p0-007d-v2-compat` |

两个 frontend release 都使用各自的 HTML、CSP 和 Nginx 配置，同时只合并一个明确指定的
rollback-window `/assets` 集合。生产 Dockerfile 会拒绝任何构建产物中的
`http(s)://*.invalid`；兼容 Dockerfile 默认使用 `scratch`，必须显式给定两个不可变输入
镜像。该设计修复了真实滚动中旧 HTML 引用 content-hash asset 返回 404 的问题，没有以
共享可写卷或运行时下载规避不可变发布。

## 3. 配对门禁

最终 2+2 tuple 重新执行 `verify_p0_007d_browser.mjs`，结果保存在
`browser-pair.json`：

- anonymous `401`；
- real Casdoor login 后 authenticated `200`；
- invalid CSRF `403`；
- 超出隔离身份 scope 的 mutation `403`；
- logout `204`，退出后再次读取 `401`；
- CSP、严格 CA 校验、后端审计日志均通过；
- token、cookie、OIDC code/state/nonce、PKCE verifier 和 credential 均未输出。

## 4. 滚动与回滚

`verify_p0_007d_rollout.mjs` 从 accepted v2 回滚到 v1，再前滚到 v2：

- 回滚期间严格 TLS 连续成功探测 `105` 次；
- 前滚期间严格 TLS 连续成功探测 `75` 次；
- v2 的 `18` 个静态资源在 v1 回滚窗口全部可读；
- v1 的 `18` 个静态资源在 v2 前滚窗口全部可读；
- 两个稳定点都重新执行完整真实 Casdoor 浏览器配对；
- 非目标 Deployment 快照保持不变；
- 失败路径会恢复 accepted digest，最终状态为 `p0-007d-v2-compat`。

原始摘要保存在 `rollout.json`。

## 5. 原子改名与 clean-room

改名顺序为：

1. 先把 source commit 和 annotated tag 推送到原远端；
2. 通过 Gitee v5 `PATCH /repos/{owner}/{repo}` 同时更新 `name` 与 `path`；
3. 将本地目录、父仓 `.gitmodules`、父仓内部 submodule metadata、child `origin` 和
   gitlink 同步到 `tpl-admin-frontend-react`；
4. 推送父仓 commit/tag；
5. 从父仓发布标签执行完整 `git clone --recursive`。

递归 clean clone 固定并成功检出：

```text
tpl-admin-backend        456bd65
tpl-admin-frontend-react 0b58adc
tpl-web-backend          6b6c71e
tpl-web-backend-nest     947021c
tpl-web-frontend         f746255
```

clean clone 中旧本地路径 `tpl-admin-frontend` 不存在，新 child origin 指向改名后的 Gitee
远端。Gitee 对旧 URL 保留兼容重定向，但 API 返回的唯一真实 repository path 是
`tpl-admin-frontend-react`；这不是第二个仓库。

## 6. 零业务实例变更与下一游标

任务前后业务父仓 HEAD 保持：

```text
info-app      37988c873e8dc4e6a7f019ee8eec26f90ce8c82d
knowledge-app 2e410ad0ba8f813844147df39cda56269618a97e
research-app  81215951809ead1cb5b06df182937551b026ebed
```

P0-007D 关闭后，唯一任务切换为 P0-007E：创建新的空 canonical
`tpl-admin-frontend`，从固定 Next Web 工程树建立全新 Git 历史，并逐项消费本任务固定的
legacy 完整能力矩阵。B6、P0-009、P0-008C 和业务开发仍保持阻断。

证据固化后已按正式脚本删除 P0-007D 专用 Deployment、Pod、Service、PDB、IngressRoute、
PostgreSQL、Redis、migration、runtime Secret、Casdoor application 和 identity Secret；
等待 Pod 终止宽限期结束后，按 `sunmoonai.com/task=v5-p0-007d` 查询结果为空。三个业务
Admin Backend Deployment 未被清理流程触碰。
