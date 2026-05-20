# App Platform 新增 App 注意事项

## Harbor 地址必须按集群解析

新增 app 或新增可部署组件时，不能把镜像仓库或 imagePullSecret 的 Docker Server 写死为 `harbor.sunmoonai.com:30443`。

统一规则：

- `KIND` 使用 `harbor.sunmoonai.com:30443`
- `C1` / `C2` / `C3` 等远程集群使用 `harbor.sunmoonai.com`

部署脚本必须接入公共函数：

```bash
source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
apply_cluster_config_mapping

export APP_IMAGE_REGISTRY="${APP_IMAGE_REGISTRY:-$(get_cluster_harbor_registry)}"
export DOCKER_SERVER="${DOCKER_SERVER:-$(get_cluster_harbor_registry)}"
```

如果某个 app 需要覆盖集群差异，用集群前缀变量：

```bash
APP_IMAGE_REGISTRY="harbor.sunmoonai.com"
KIND_APP_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"

DOCKER_SERVER="harbor.sunmoonai.com"
KIND_DOCKER_SERVER="harbor.sunmoonai.com:30443"
```

部署入口仍然只传集群参数，例如 `kind` 或 `c1`。不要让使用者手工修改 Harbor 端口。
