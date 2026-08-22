# App 镜像构建与推送

本目录的 `build-push-app-images.sh` 只做一件事：**在 WSL 本地构建镜像，并直推到指定 Harbor**。

```text
info / research / investment / tools / knowledge
  × admin-backend / admin-frontend / web-backend / web-frontend
```

脚本不部署 Kubernetes，也不触发 Harbor 复制。

## 两种镜像到达远程的方式（勿混淆）

| 机制 | 入口 | 配置位置 |
|------|------|----------|
| **本地构建直推** | `build-push-app-images.sh` | 本目录 `build-push-app-images.conf` |
| **Harbor 复制** | Kind Harbor UI → 复制管理 | `cicd-platform/harbor/docs/kind-to-c1-sync-README.md` |

直推：改代码后 `docker build` + `docker push`，按 `CLUSTER` 推到对应 Harbor。  
复制：镜像已在源 Harbor 中，由复制规则同步到目标 Harbor，无需重新构建。

## 文件

```text
build-push-app-images.sh      # 构建并直推镜像
build-push-app-images.conf    # 各 CLUSTER 的直推仓库地址
```

配置优先级：

```text
命令行环境变量 > build-push-app-images.conf > 脚本内置默认值
```

## 直推目标：KIND 与 C1 配置不同

Kind 与 C1 是**两套独立 Harbor**。`CLUSTER` 决定直推落到哪套：

| CLUSTER | 本机 WSL 直推地址 | 其它机器直推 C1 |
|---------|-------------------|-----------------|
| `KIND` | `harbor.sunmoonai.com:30443` | 不适用（无本机 Kind 时无 KIND 直推场景） |
| `C1` | `harbor-c1.sunmoonai.com:30443` | `harbor.sunmoonai.com:30443`（无本地 Kind 冲突，可直接用主域名） |

本机 WSL 同时跑着 Kind Harbor，`harbor.sunmoonai.com` 会解析到本地实例，因此 C1 直推需用 `harbor-c1` 别名（`/etc/hosts` 指向 C1 公网 IP）。在其它机器上构建直推远程 C1 时，改 `build-push-app-images.conf` 中 `C1_*` 为 `harbor.sunmoonai.com:30443` 即可。

对应配置项见 `build-push-app-images.conf` 中的 `KIND_*` 与 `C1_*`。

## 推到 Kind Harbor

```bash
cd ~/master/k8s/sunmoonai/app-platform

docker login harbor.sunmoonai.com:30443

CLUSTER=KIND ./scripts/build-push-app-images.sh
# 或省略 CLUSTER（DEFAULT_CLUSTER=KIND）
./scripts/build-push-app-images.sh
```

## 直推到远程 C1 Harbor

```bash
cd ~/master/k8s/sunmoonai/app-platform

docker login harbor-c1.sunmoonai.com:30443

CLUSTER=C1 ./scripts/build-push-app-images.sh
```

远程 `k8s-images` 中需已有 Python、Node 等基础镜像，否则 Dockerfile 构建阶段会失败。

临时覆盖仓库地址：

```bash
CLUSTER=C1 \
TARGET_REGISTRY="harbor-c1.sunmoonai.com:30443/app-images" \
BASE_REGISTRY="harbor-c1.sunmoonai.com:30443/k8s-images" \
TAG="1.0.0" \
./scripts/build-push-app-images.sh
```

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

## 与部署配置的关系

正式 App 使用不可变 `repository@sha256:digest`，不再用可变 tag 驱动部署。每个 App 的
`deploy-<app>-app-all.conf` 是可读发布声明，`profiles/` 保存集群操作参数；入口会先与已门禁
bundle 逐项核对。完整合同见 `../docs/formal-deployment-configuration.md`。

构建/复制完成后，部署入口：

```bash
cd ~/master/k8s/sunmoonai/app-platform/info-app
./deploy-info-app-all/deploy-info-app-all.sh config --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND
```

当前 C1/production formal profile 默认禁用；在对应门禁完成前不得仅靠复制镜像或修改开关启用。
