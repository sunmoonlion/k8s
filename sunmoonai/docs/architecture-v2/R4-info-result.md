# Architecture v2 R4 Info 同步结果

状态：`DONE / KNOWLEDGE MAY START`

日期：2026-08-08

模板唯一来源：`architecture-v2-r3.2-20260808`

## 1. 结论

Info 已完整继承 R3.2 共同底座，同时保留 Info 领域代码和现有规范 Alembic 链。Admin 与 Web
两个 Next.js 表面均调用同一个 `info-backend`，并在隔离 KIND namespace 中通过真实
PostgreSQL、Redis、Casdoor、严格 TLS、原生回滚和 Calico 报文门禁。

本轮没有切换 `app-platform-dev` 现有流量，没有删除旧 Admin/Web Backend、数据库、Secret 或
PVC，也没有开始 R5 数据归并。Info R4 候选仍不是正式 `2.0.0` 发布。

## 2. 源码与镜像锁

| 组件 | 源码 commit | tree | 候选镜像 digest |
| --- | --- | --- | --- |
| `info-backend` | `2527e4ef9ea8acf1043e22b46556f78f43d18a60` | `2b2c7a44d901d2118ca77aaba39091d6e7648c4b` | `sha256:bab29c3fc2795f41cd80a0a3da75df0e9761d9465360600a9810c679db50c19c` |
| `info-admin-frontend` | `29f3cf6356303d597dca3c8074863bc1c5fb84a3` | `d7a128d0bf4782731aeac510db37bbd8e7bfb254` | `sha256:defacc2f58584541561ada6ce13918efe4be41e9dd7ef21decd30299cd2f149d` |
| `info-web-frontend` | `57ce5a743a666eea97dc77ff94c9762eaba1a49c` | `347b117bd4a978c2301c2f55c16f893b22e2c9bc` | `sha256:60f3f70a67630997cc3d0fe9884c166fd5023dac9eed81a3a03b22c5e5c66c52` |

原生回滚使用同一 Next.js standalone 运行合同的前一 Info Web commit `4133cd5`，远端不可变
摘要为 `sha256:c4b140ded816b495e07314b56c523973c4c1378661efb1a48fd4240e88578520`。
旧架构 Nginx `1.0.0` 镜像因端口和探针合同不同，不得伪装成同一 Deployment revision；它继续
由旧拓扑整体回滚路径保护。

## 3. 源码与配对门禁

- 三组件 clean-room 同步的 `prohibited-drift=0`；
- 稳态 plan 均为 `writes=0`、`deletes=0`、`prohibited-drift=0`；
- Backend 保留 Info source/document/artifact/distribution/outbox 领域实现；
- Admin/Backend Playwright：10/10 通过；
- Web/Backend Playwright：7/7 通过；
- Web 配对发现的 deployment identity 旧断言先修模板并完成 R3.2 复验，再同步回 Info；
- 模板和实例 Admin/Web 构建脚本都只接受显式 build-only proxy，运行镜像无代理变量。

## 4. 隔离 KIND 门禁

正式驱动脚本：`scripts/run_r4_info_gate.sh`。临时 namespace 为
`info-architecture-v2-r4`，两个 Casdoor application 和凭据 Secret 也使用 Info R4 独立名称。

通过项：

- Info 自身 Alembic `20260706_0001 -> 20260707_0002 -> 20260712_0003 -> 20260714_0004`；
- API、Worker、Scheduler 共用同一 Backend digest、使用不同命令；
- Migration/API/Worker/Scheduler 四个数据库 principal；
- 4 个 HPA、4 个 PDB、7 个 NetworkPolicy；
- Admin/Web OIDC client、redirect、cookie、policy namespace 隔离；
- 严格 TLS 下 Admin 与 Web 均完成 `401 -> 200 -> 204 -> 401`；
- 兼容旧 revision 原生 `rollout undo` 后严格 TLS 200，再按锁定 manifest 前滚；
- 前滚后再次完成双端真实 Casdoor 登录；
- Calico v3.28.2：internal caller 允许、frontend 允许、无标签 caller 拒绝。

## 5. 清理反证与旧拓扑保护

门禁退出后已确认：

- `info-architecture-v2-r4` namespace 不存在；
- `sunmoonai-architecture-v2-r4-info-identity` Secret 不存在；
- `info-r4-policy` KIND 集群不存在；
- 原 `app-platform-dev` 六个 Info Deployment 仍为 1/1，就地镜像引用未改变；
- 未读取或输出任何浏览器、Casdoor、数据库或 Harbor 凭据。

## 6. 证据与下一步

源码/同步证据：

- `evidence/R4-info-plan/`
- `evidence/R4-info-cleanroom/`

集群证据：`evidence/R4-info-gate/`，其中 `result.json`、`kind.json`、`browser.json`、
`browser-after-forward.json`、`rollback.txt`、`network-policy.txt` 和 `release.json` 共同构成退出
证据。

Info R4 关闭后，下一步只允许按同一 R3.2 release 开始 Knowledge R4；Research 仍不得修改。
