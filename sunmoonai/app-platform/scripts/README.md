# App 镜像构建与推送

本目录用于统一构建并推送 App Platform 下各业务 App 的四个标准组件镜像：

```text
info
research
investment
tools
knowledge

admin-backend
admin-frontend
web-backend
web-frontend
```

脚本只负责本地 Docker 构建和推送镜像，不直接部署 Kubernetes 资源。Kind 和远程集群能否拉取镜像，取决于部署配置中使用的镜像仓库与这里推送的仓库是否一致。

## 文件

```text
build-push-app-images.sh      # 构建并推送镜像
build-push-app-images.conf    # 默认配置、集群仓库和镜像源
```

配置优先级：

```text
命令行环境变量 > build-push-app-images.conf > 脚本内置默认值
```

## 本地 Kind 使用

Kind 当前使用本机 Harbor：

```bash
cd ~/k8s/sunmoonai/app-platform

./scripts/build-push-app-images.sh
```

等价于：

```bash
CLUSTER=KIND ./scripts/build-push-app-images.sh
```

默认会推送到：

```text
harbor.sunmoonai.com:30443/app-images
```

并使用基础镜像仓库：

```text
harbor.sunmoonai.com:30443/k8s-images
```

## 远程集群使用

如果远程集群和 Kind 使用同一个 Harbor，只需指定远程集群 profile：

```bash
cd ~/k8s/sunmoonai/app-platform

CLUSTER=C1 ./scripts/build-push-app-images.sh
```

如果远程集群使用独立镜像仓库，优先修改 `build-push-app-images.conf` 中对应集群的配置：

```bash
C1_TARGET_REGISTRY="remote.example.com/app-images"
C1_BASE_REGISTRY="remote.example.com/k8s-images"
C1_TAG="1.0.0"
```

也可以临时覆盖：

```bash
CLUSTER=C1 \
TARGET_REGISTRY="remote.example.com/app-images" \
BASE_REGISTRY="remote.example.com/k8s-images" \
TAG="1.0.0" \
./scripts/build-push-app-images.sh
```

远程仓库必须已经存在基础镜像，例如 Python、Node 等 `k8s-images` 镜像，否则构建阶段会失败。

## 常用参数

指定版本：

```bash
TAG=1.0.1 ./scripts/build-push-app-images.sh
```

从某个组件继续：

```bash
START_FROM="research/admin-backend" ./scripts/build-push-app-images.sh
```

只打印命令，不执行构建和推送：

```bash
DRY_RUN=true ./scripts/build-push-app-images.sh
```

使用 Docker 构建缓存：

```bash
NO_CACHE=false ./scripts/build-push-app-images.sh
```

输出 plain 日志，便于排错：

```bash
PROGRESS=plain ./scripts/build-push-app-images.sh
```

只构建部分 App 或组件：

```bash
APPS="info knowledge" \
COMPONENTS="admin-backend web-frontend" \
./scripts/build-push-app-images.sh
```

## 登录 Harbor

执行前需要 Docker 已登录目标 Harbor：

```bash
docker login harbor.sunmoonai.com:30443
```

如远程仓库不同，登录对应仓库：

```bash
docker login remote.example.com
```

## 与部署配置的关系

构建脚本推送的镜像版本必须与各 App Kubernetes 配置中的镜像版本一致。

当前标准版本为：

```text
1.0.0
```

构建完成后，部署入口仍使用：

```bash
cd ~/k8s/sunmoonai/app-platform/deploy-app-platform-all
./deploy-app-platform-all.sh --cluster KIND deploy
./deploy-app-platform-all.sh --cluster C1 deploy
```

部署入口负责选择集群和启动组件；构建脚本负责把镜像放到相应仓库。
