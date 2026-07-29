# V5 `1.0.0` 镜像收敛记录

日期：2026-07-29

## 结论

`1.0.0` 候选镜像标签已为 7 个模板镜像和 12 个实例镜像建立，但
不得把这些标签等同于稳定集群已经完成流量切换。

原因是稳定 KIND 集群仍运行旧部署拓扑与旧配置：

- 旧 Admin 前端是 Nginx/80，新默认 Admin 前端是 Next.js/3000。
- 旧 Web 后端是 NestJS/3000，新默认 Web 后端是 FastAPI/8000。
- Knowledge 的 Admin/Web 前端和 Web 后端尚无稳定 Deployment。
- P0-009 验收的是隔离环境中的模板继承与配对，不包含稳定业务 Deployment 切换。

直接替换镜像会使新后端在旧 ConfigMap/Secret 和旧迁移状态下启动失败。本轮已立即回滚，并将三个因 `1.0.0` 标签被重定向而失去可重启性的旧组件固定为旧镜像 digest。所有现有业务 Deployment 已恢复 Ready。

## 已完成

1. 轮换 Info、Knowledge、Research 的 PostgreSQL 应用角色密码。
2. 轮换 Info、Knowledge 的 Redis ACL 密码；Casdoor 与 Research Redis 已是近期轮换值，未重复变更。
3. 验证旧凭据失效、新凭据生效，API 与 Worker 完成滚动恢复。
4. 为 19 个目标镜像仓库建立统一 `1.0.0` 候选标签。
5. 修复四个 Next.js Web 前端最终运行镜像携带构建代理环境变量的问题，并重新构建、冒烟和推送：

| 镜像 | `1.0.0` digest |
| --- | --- |
| `tpl-web-frontend` | `sha256:c848bee9b5e3d852c8c5adfc36f66d4ac86d909030120f354bfece88b141bd78` |
| `info-web-frontend` | `sha256:909c3357d1924ee337142af6871db0cb6809abc541973ab6e769de3850e7295c` |
| `knowledge-web-frontend` | `sha256:92706a8939cf77dbac90190a501102540fe91dfa62c8d8e9fb75d6854890d39f` |
| `research-web-frontend` | `sha256:a34ba8238a1b116f2726a3e5bca2582d9ab1e7c388e28ad0b6f40d740906f04c` |

最终运行镜像已验证不存在非空 `HTTP_PROXY`、`HTTPS_PROXY`、`http_proxy` 或 `https_proxy`。

## 回滚后状态

- 现有 Info、Knowledge、Research API 与 Worker 均为 `1/1 Ready`。
- 现有 Info、Research Admin/Web 前端均为 `1/1 Ready`。
- 集群内前端 HTTP 探测返回 200；旧后端对不存在的 `/health` 返回 404，证明进程与 Service 可达。
- 以下旧运行镜像 digest 必须保留，直到正式稳定切换完成：
  - `info-web-backend@sha256:c94808763dd53855ffa07316026894837574abc58b6cb1455d54296feaec763b`
  - `info-web-frontend@sha256:ed24c44fcf8db2dafb4bd28c67334f35f8fad5fb93c94c8564488d1794f864eb`
  - `research-admin-frontend@sha256:c0a8b782ca578e30946719c2d0b35dde2a8ed16dfaaa31c779e5cf1aa0cc864c`
  - `research-web-backend@sha256:d550d9b54b2c33781c46cd51cae3f73c28b5924a81257dd412133e8c4c3208ae`

Info、Research 的旧 Node Bull Worker 原先也引用可变 `1.0.0` 标签。新
`1.0.0` 已是 FastAPI Web 后端，不能运行旧 Bull Worker 命令；两套 Worker
已分别固定到上述 Info、Research NestJS digest 并完成滚动恢复。

## 已执行的安全清理

- 清理范围严格限制为上述 19 个 Harbor 仓库。
- 删除了 115 个既非最终发布、也未被 Kubernetes 当前工作负载引用的
  artifact。
- 保留了 32 个发布或当前在用 artifact；清理后再次 dry-run，删除候选为 0。
- 清理后 19 个 `1.0.0` 标签逐一通过 digest 核验。
- 本机删除了 104 个带 Harbor 前缀的旧标签和 46 个无前缀构建候选标签；
  本机目标镜像仅保留 19 个 Harbor `1.0.0` 标签。
- 未触碰其他 Harbor 仓库，未执行 Harbor GC。

当前集群仍需使用的旧 artifact 不属于“无关镜像”，因此有意保留。待正式
稳定切换完成后，再运行同一保留集算法完成第二次收敛。

## 后续强制顺序

1. 为三实例生成并评审新的稳定 Deployment、Service、ConfigMap、Secret 引用、探针和端口清单。
2. 补齐 Knowledge 缺失的三个稳定 Deployment。
3. 在独立命名空间按 Admin 前后端、Web 前后端成对执行迁移、身份、浏览器和回滚门禁。
4. 串行切换 Info、Knowledge、Research，每个实例通过观察窗后再进入下一个。
5. 从实际稳定 Deployment 反查所有在用 digest，生成保留集。
6. 仅删除不在保留集、回滚集和 `1.0.0` 发布集中的 Harbor artifact；最后再执行 Harbor GC。

在第 4 步全部通过前，禁止“只保留 `1.0.0`”式清理。
