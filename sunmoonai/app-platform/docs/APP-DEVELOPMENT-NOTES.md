# App Platform 新增 App 注意事项

## App 与 tpl-app 组件的关系

新增领域 App 原则上从 `/home/zymun/tpl-app` 统一实例化。`tpl-app` 中的四个组件是技术栈样板，不是固定业务分层：

| 模板组件 | 技术栈 |
|---|---|
| `tpl-admin-backend` | Python / FastAPI |
| `tpl-web-backend` | JavaScript/TypeScript / NestJS |
| `tpl-admin-frontend` | Vue |
| `tpl-web-frontend` | Next.js |

必须遵循：

1. `tpl-app` 始终完整维护四个组件及其构建、数据库、S3、Elasticsearch 和 Kubernetes 接入能力。
2. 新 App 实例化时完整保留四个组件，不在源码工程阶段删除或禁用某个技术栈。
3. 根据实际功能选择合适技术栈并实现当前需要的组件；尚未承载业务的组件可以保留样板代码。
4. 是否启动某个组件只在 Kubernetes 部署阶段通过各集群的组件开关决定。
5. 在各组件的 `app` 目录中按领域需求编写不同代码。
6. 不因组件名包含 `admin` 或 `web`，就预设它只能承担某种业务职责。
7. 同一业务数据只允许一个 Backend 权威写入，具体归属在实现功能时确定并持续遵守。
8. Worker、Scheduler、Migration Job 等是运行角色，可以复用所选 Backend 的源码和镜像。

必须区分：

```text
领域 App       = 长期业务边界
tpl-app 组件   = 可选技术栈和工程样板
运行角色       = API、Worker、Scheduler、Migration Job 等进程形态
```

领域边界由 App 架构文档和数据所有权决定，不由模板目录名、编程语言或 Deployment 数量决定。

模板“全部具备”和运行时“全部启动”是两件事。工程骨架保持完整，部署配置可以按
`KIND`、`C1` 等集群分别决定实际运行哪些组件，不需要为此重新实例化 App。

## Harbor 地址必须按集群解析

新增 app 或新增可部署组件时，不要在脚本逻辑里手写 Harbor 地址；必须通过集群配置解析或在 `.conf` 中按集群前缀声明。

统一规则：

- `KIND` 使用 `harbor.sunmoonai.com:30443`
- `C1` / `C2` / `C3` 等远程集群当前也使用 `harbor.sunmoonai.com:30443`

部署脚本必须接入公共函数：

```bash
source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
apply_cluster_config_mapping

export APP_IMAGE_REGISTRY="${APP_IMAGE_REGISTRY:-$(get_cluster_harbor_registry)}"
export DOCKER_SERVER="${DOCKER_SERVER:-$(get_cluster_harbor_registry)}"
```

如果某个 app 需要覆盖集群差异，用集群前缀变量：

```bash
APP_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"
KIND_APP_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"

DOCKER_SERVER="harbor.sunmoonai.com:30443"
KIND_DOCKER_SERVER="harbor.sunmoonai.com:30443"
```

部署入口仍然只传集群参数，例如 `kind` 或 `c1`。不要让使用者手工修改 Harbor 端口。
