# App 依赖预检查配置说明

本文说明 app-platform 中业务 App 部署前的依赖预检查规则。这里的“依赖”主要指 PostgreSQL、Redis、MongoDB、Elasticsearch，以及与这些依赖相关的 App 级 Secret/ConfigMap 生成逻辑。

## 基本原则

k8s 部署配置是依赖开关的权威来源。

业务仓库里的 `db-access-bootstrap/config/common.env` 只能作为 bootstrap 脚本的内部默认值，不能覆盖 k8s 部署脚本传入的开关。部署入口会保护调用方传入的 `ENABLE_POSTGRESQL`、`ENABLE_REDIS`、`ENABLE_NODEBULL_REDIS`、`ENABLE_MONGODB`，即使业务仓库的 `common.env` 写了固定值，也以 k8s 传入值为准。

PostgreSQL、Redis、MongoDB、Elasticsearch 的配置策略是一套：都由 app-all 配置决定是否启用，启用则预检查，关闭则不检查、不 bootstrap、不挂载对应运行时配置。当前底层执行器有历史差异：PostgreSQL、Redis、MongoDB 属于 DB 类资源，走 `db-access-bootstrap`；Elasticsearch 属于搜索资源，走 `search-access-bootstrap`。执行器不同不代表配置机制不同。

预检查只在会创建或校验资源的动作中执行：

- `deploy`
- `provision-resources`
- `validate-resources`

以下动作不会执行依赖预检查：

- `status`
- `resource-status`
- `logs`
- `uninstall`

## 适用范围

当前统一 app-all 依赖预检查适用于以下 App：

- `tools-app`
- `info-app`
- `research-app`
- `knowledge-app`
- `investment-app`

`auth-app` 目前是独立的组件编排形态，不走这套通用 backend resource bootstrap 流程。

## 配置位置

每个 App 的总控配置位于：

```text
sunmoonai/app-platform/<app-name>/deploy-<app-name>-all/deploy-<app-name>-all.conf
```

示例：

```text
sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.conf
```

## Backend 开关

每个 backend 使用以下开关控制依赖能力：

```bash
info_admin_backend_database_access_enabled="true"
info_admin_backend_redis_access_enabled="true"
info_admin_backend_mongodb_access_enabled="false"
info_admin_backend_storage_access_enabled="true"
info_admin_backend_search_access_enabled="true"
```

开关含义：

| 开关 | 控制内容 |
| --- | --- |
| `*_database_access_enabled` | PostgreSQL 预检查、DB bootstrap、PostgreSQL Secret 挂载 |
| `*_redis_access_enabled` | Redis 预检查、Redis Secret 挂载 |
| `*_mongodb_access_enabled` | MongoDB 预检查、MongoDB bootstrap、MongoDB Secret 挂载 |
| `*_storage_access_enabled` | 对象存储 bootstrap、S3 ConfigMap/Secret 挂载 |
| `*_search_access_enabled` | Elasticsearch 预检查、Search bootstrap、Elasticsearch ConfigMap/Secret 挂载 |

建议显式配置 `*_redis_access_enabled`。如果未配置，脚本会临时按 `*_database_access_enabled` 的值兜底，但新配置不要依赖这个隐式行为。

这些开关应被视为同一套依赖能力开关。不要把 ES 视为另一套独立策略；它只是由 `search-access-bootstrap` 执行，而不是由 `db-access-bootstrap` 执行。

## 集群级覆盖

支持使用 `C1_`、`C2_`、`C3_`、`KIND_` 等前缀进行集群覆盖。部署时 `apply_cluster_config_mapping` 会把当前集群前缀变量映射到无前缀变量。

示例：C1 不启用 Elasticsearch，但 KIND 启用。

```bash
info_admin_backend_search_access_enabled="true"
C1_info_admin_backend_search_access_enabled="false"
KIND_info_admin_backend_search_access_enabled="true"
```

如果以后 KIND 关闭某个 backend 或某类依赖，也会按同一套逻辑跳过，不依赖“KIND 全开”的假设。

## 预检查做什么

预检查由 `utils/app-dependency-preflight.sh` 实现。

当某个依赖开关为 `true` 时，部署脚本会检查对应基础组件是否已启动：

| 依赖 | 默认 Namespace | 默认 Service |
| --- | --- | --- |
| PostgreSQL | `data-platform-dev` | `postgresql-sunmoonai` |
| Redis | `data-platform-dev` | `redis-sunmoonai-master` |
| MongoDB | `data-platform-dev` | `mongodb-sunmoonai` |
| Elasticsearch | `data-platform-dev` | `elasticsearch-sunmoonai` |

检查项：

- Namespace 存在
- Service 存在
- Service 有 ready endpoint

任一检查失败，部署会立即报错退出。这样可以避免 App 已开始部署后才因为连不上依赖而 CrashLoop。

## 关闭开关时会发生什么

当某个依赖开关为 `false`：

- 不执行对应依赖预检查
- 不执行对应 bootstrap
- 生成 App YAML 时清空对应 Secret/ConfigMap 变量
- 业务仓库 `common.env` 中的默认值不会重新打开该依赖

例如：

```bash
info_admin_backend_mongodb_access_enabled="false"
```

结果：

- 不检查 `mongodb-sunmoonai`
- 不执行 MongoDB dbctl
- 不挂载 `INFO_ADMIN_BACKEND_MONGODB_SECRET_NAME`
- 即使 `info-admin-backend/db-access-bootstrap/config/common.env` 写了 `ENABLE_MONGODB=true`，也会被 k8s 调用方传入的 `ENABLE_MONGODB=false` 覆盖

## 启用 MongoDB 的正确方式

如果某个 App 确实需要 MongoDB，必须同时满足两边配置。

先确保 data-platform 当前集群启用了 MongoDB：

```bash
C1_mongodb_enabled="true"
```

并完成 MongoDB 部署，使 `mongodb-sunmoonai.data-platform-dev.svc.cluster.local` 对应 Service 有 ready endpoint。

然后在 App 配置里打开对应 backend 的 MongoDB：

```bash
info_admin_backend_mongodb_access_enabled="true"
```

重新执行 App 部署时，脚本会：

- 先检查 MongoDB 是否就绪
- 通过 `ENABLE_MONGODB=true` 执行 DB bootstrap
- 生成并挂载对应 MongoDB Secret

如果 data-platform 没有启用 MongoDB，但 App 打开了 `*_mongodb_access_enabled=true`，预检查会失败并退出。

## Redis 与 NodeBull Worker

NodeBull worker 依赖 Redis 队列 Secret。组件启用时有额外保护：

- `nodebullworker-xxx-backend` 必须在父 backend 启用时才会部署
- 父 backend 的 Redis 开关必须为 `true`

示例：

```bash
info_web_backend_enabled="true"
info_web_backend_redis_access_enabled="false"
nodebullworker_info_web_backend_enabled="true"
```

实际结果：`nodebullworker-info-web-backend` 会被跳过，避免 Redis 已关闭但 worker 仍引用 queue Redis Secret。

Celery worker 也跟随父 backend 是否启用；父 backend 关闭时，对应 Celery worker 会跳过。

## Elasticsearch

Elasticsearch 由 `*_search_access_enabled` 控制。

打开时：

- 检查 `elasticsearch-sunmoonai` Service 和 ready endpoint
- 执行 `search-access-bootstrap`
- 保留 Elasticsearch ConfigMap/Secret envFrom

关闭时：

- 不检查 Elasticsearch
- 不执行 search bootstrap
- 清空 `${BACKEND}_ELASTICSEARCH_CONFIGMAP_NAME`
- 清空 `${BACKEND}_ELASTICSEARCH_SECRET_NAME`

worker 当前不直接挂载 Elasticsearch Secret/ConfigMap，因此不额外用 ES 开关 gate worker。是否部署 worker 主要跟随父 backend 与 Redis 规则。

## 常见排查

如果日志中出现：

```text
MongoNetworkError: getaddrinfo ENOTFOUND mongodb-sunmoonai.data-platform-dev.svc.cluster.local
```

先看部署日志中是否出现：

```text
检查 xxx-backend 依赖: mongodb
```

如果出现，说明 App 配置中 `*_mongodb_access_enabled=true`，但 data-platform 没有部署 MongoDB 或 MongoDB 未就绪。

如果没有出现，但 bootstrap 仍尝试 MongoDB，说明业务仓库旧版 bootstrap 覆盖了 k8s 传入值。当前 k8s 调用侧已安装 source guard，会在 `source common.env` 后恢复调用方传入的 `ENABLE_MONGODB=false`；请确认已经使用包含该修复的 k8s 版本。

如果 Redis/Elasticsearch/PostgreSQL 检查失败，优先检查 data-platform 对应组件是否在当前集群启用并部署完成。

## 推荐配置习惯

- 每个 backend 都显式写出 `database`、`redis`、`mongodb`、`storage`、`search` 五类开关
- MongoDB 默认关闭，确有业务需求时再打开
- C1/C2/C3/KIND 的差异通过集群前缀变量表达
- 不在业务仓库 `common.env` 里表达部署策略；那里只放脚本默认值
- 修改依赖开关后，重新执行对应 App 的 app-all 部署，让 Secret 挂载、bootstrap 和预检查重新计算
