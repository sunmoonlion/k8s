# Architecture v2 R3 Kubernetes 模板重构结果

状态：`DONE / ACCEPTED AS R4 SOURCE`

日期：2026-08-01

## 1. 结论

R3 已通过。Architecture v2 模板现已具备可生成、可校验、可部署、可回滚和可清理的
Kubernetes 基线：一个 FastAPI Backend 镜像按 API、Worker、Scheduler、Migration 四种角色
运行，Admin/Web 为两个独立 Next.js SSR 前端，并通过同源 `/api` 接入同一个 Backend。

本结论不等于正式发布：所有镜像仍是不可变候选 digest，未创建或覆盖 `2.0.0`，旧架构
`1.0.0` 继续作为受保护回滚基线。

## 2. 源码与镜像锁

| 项目 | 锁定值 |
| --- | --- |
| Backend commit | `8997e9e9422fd5fefaff6ab3519bd0367075fdb0` |
| Admin commit | `f993e1211b1a1a1d0029aeefa4c7044e32137275` |
| Web commit | `e07b12136998bd3989a6cfb70573d792dad2b2df` |
| R3 scaffold source commit | `90fea5c0804e9f33c4de12d70078993c2974c678` |
| R3 release manifest commit | `db2174a1581f090d635cd37dcc8cbcd5a9fb5588` |
| Backend image | `tpl-backend@sha256:131793e27f5782511b7e6f8ce4c688639f9c2d460fe57fbe1ea805989ca481f1` |
| Admin image | `tpl-admin-frontend@sha256:84c8343f57ae2475cc11bd871379bb7b506ed2b81b474a20affcc9249a6c5f81` |
| Web image | `tpl-web-frontend@sha256:54c62d90c833b4577d304b79cffef63c980b39c98262bbf082546839added33d` |

`tpl-app/template-release-manifest.json` 已升级为 schema 2，锁定组件 commit/tree、镜像 digest、
K8s scaffold tree、契约版本、身份/数据库策略、差异分类和 R4 串行顺序。机器校验器
`tpl-app/verify_template_release.py` 已通过。

## 3. 已实现的部署基线

- `scaffold.py` 只接受不可变 `repository@sha256` 镜像，生成五份带 SHA-256 的锁定清单；
- `deploy.py` 校验 bundle hash 和 Secret 文件权限，按
  `prerequisites/secret/policy -> migration -> runtime -> ingress` 执行；
- Migration 成功后立即删除 Job，不遗留长期 `Completed` Pod；
- API、Worker、Scheduler 共用 Backend digest，但命令、ServiceAccount、DB/broker key 分离；
- API 2 副本，Admin/Web 各 2 副本；PDB、HPA、资源、探针、只读 rootfs、非 root、drop ALL
  和禁用 ServiceAccount token 均进入清单；
- Admin/Web 使用独立 OIDC client、secret、cookie/session/policy namespace 和 Origin；
- 两套 Traefik TLS 入口把 `/api` 同源路由到唯一 Backend Service，其余路径进入对应 Next；
- NetworkPolicy 显式限定 Traefik、双前端、内部调用者、数据依赖和跨 namespace Casdoor。

## 4. 验收结果

| 门禁 | 结果 |
| --- | --- |
| 模板单元测试、渲染、hash/Secret 校验 | 通过 |
| PostgreSQL Migration 到 `20260801_0002` | 通过 |
| API/Worker/Scheduler/Admin/Web rollout | 通过 |
| Backend 同 digest、不同 entrypoint | 通过 |
| Migration/API/Worker/Scheduler 四个 DB principal | 通过 |
| 4 个 HPA、4 个 PDB、7 个 NetworkPolicy | 通过 |
| Admin 严格 TLS + 真实 Casdoor 登录/登出/撤销 | `401 -> 200 -> 204 -> 401` |
| Web 严格 TLS + 真实 Casdoor 登录/登出/撤销 | `401 -> 200 -> 204 -> 401` |
| 双 OIDC client 和 surface 隔离 | 通过 |
| Kubernetes 原生回滚到 R2 | 通过，严格 TLS `/zh-CN` 为 200 |
| 前滚恢复 R3 | 通过，严格 TLS `/healthz` 为 200 |
| 前滚后的 Admin/Web 真实登录复验 | 通过 |
| Calico 报文级 NetworkPolicy | internal 200、frontend 200、unlabelled denied |

当前长期 KIND 使用 kindnetd，不能执行 NetworkPolicy。因此结构门禁和报文门禁没有混为一谈：
完整应用/浏览器验收继续使用长期 KIND，报文级策略验收在一次性
`disableDefaultCNI: true` 的 KIND + Calico v3.28.2 中执行。该做法符合 Calico 官方对 KIND
安装和从其他 CNI 迁移边界的说明：

- <https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind>
- <https://docs.tigera.io/calico/latest/network-policy/get-started/kubernetes-default-deny>

## 5. 证据与清理

机器证据位于 `architecture-v2/evidence/R3-template-gate/`。证据扫描只出现 Secret key 名称和
`credentials_printed=false`，没有 Secret 值、token、证书私钥或密码。

门禁结束后已确认：

- `tpl-architecture-v2-r3` namespace 已删除；
- R3 临时 Casdoor application/client 与身份 Secret 已删除；
- 一次性 `tpl-r3-policy` KIND/Calico 集群已删除；
- 长期 KIND 仅保留原 `kind` 集群，原业务 namespace 未被替换。

## 6. 下一步边界

R3 关闭后只允许进入 R4，并严格按 `Info -> Knowledge -> Research` 串行同步同一个 schema 2
模板 release。同步必须继承完整共同能力、保留并分类领域扩展、使 `prohibited-drift=0`，且每个
实例的 Admin/Backend、Web/Backend、双前端身份、数据和回滚门禁全部通过后才能进入下一个。

R4 全部完成前继续禁止新增业务功能；R5 前禁止合并实例数据库、删除旧 Backend/Secret 或晋级
正式 `2.0.0`。
