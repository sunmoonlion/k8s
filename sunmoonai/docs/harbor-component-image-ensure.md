# 组件镜像 Harbor 确保机制说明

本文说明组件部署前的镜像检查和补齐机制。该机制用于保证业务组件、数据平台组件、运维组件等在部署前，所需镜像已经存在于目标 Harbor 项目中。

## 设计目标

组件部署前只做一件事：确保目标 Harbor 中存在部署所需镜像。

统一流程：

1. 读取组件镜像清单
2. 查询目标 Harbor 是否已有镜像
3. 如果 Harbor 已有，直接跳过
4. 如果 Harbor 缺失，再从本地或远程 tar 补齐
5. 如果无法确认 Harbor 状态，或 tar/load/tag/push 任一步失败，直接报错退出

这不是“每次部署都强制推镜像”。旧函数名 `push_component_images_to_harbor` 仍保留兼容，但现在语义已经变成 strict ensure：先查，缺失才补齐。

## 基础设施例外

Harbor 本身和更早安装的 Traefik 不受该机制约束。

原因：

- Traefik 安装时 Harbor 还不可用
- Harbor 安装时 Harbor 自身也不可作为前置镜像仓库依赖

Harbor 安装完成后，Harbor 部署脚本中“推送基础设施镜像到 Harbor”的逻辑应保留。该步骤用于把后续组件部署依赖的基础镜像准备好，不属于普通组件部署前的镜像 ensure 流程。

因此顺序是：

1. 部署 Traefik
2. 部署 Harbor
3. Harbor 完成后推送基础设施镜像
4. 后续其它组件统一走组件镜像 ensure

## 入口函数

核心入口在：

```text
utils/unified-deployment-template.sh
```

推荐新代码调用：

```bash
ensure_component_images_in_harbor "<component-name>"
```

旧调用仍可用：

```bash
push_component_images_to_harbor "<component-name>"
```

但应理解为兼容名，实际语义是：

```bash
push_component_images_to_harbor() {
    ensure_component_images_in_harbor "$@"
}
```

## 镜像清单

每个组件维护一份镜像清单：

```text
utils/components-images/<component-name>-images.txt
```

示例：

```text
utils/components-images/postgresql-images.txt
utils/components-images/redis-images.txt
utils/components-images/info-app-backend-images.txt
```

清单格式：

```text
repository:tag
```

一行一个镜像，空行和 `#` 注释会被忽略。

示例：

```text
bitnami/postgresql:17.6.0-debian-12-r4
bitnami/postgres-exporter:0.17.1-debian-12-r16
bitnami/os-shell:12-debian-12-r51
```

清单中的镜像可以是短引用，也可以带上游 registry：

```text
mysql:8.0.39
docker.io/library/mysql:8.0.39
quay.io/minio/aistor/minio:RELEASE.2026-05-28T20-50-32Z
```

推送到 Harbor 时会生成目标引用。一般情况下，最终落到：

```text
<registry>/<project>/<image-name>:<tag>
```

特殊路径如 `minio/aistor/*` 会保留必要的 repo 路径，避免多个 MinIO 相关镜像压成同名。

## Harbor 状态检查

对每个目标镜像，脚本先判断 Harbor 中是否已存在。

检查顺序：

1. Harbor API
2. `docker manifest inspect`
3. `skopeo inspect`

Harbor API 返回含义：

| HTTP 状态 | 结果 |
| --- | --- |
| `200` | 镜像存在 |
| `404` | 镜像缺失 |
| 其它 | 状态未知，进入 fallback |

fallback 只能确认“存在”。如果 Harbor API 不可用，且 `docker manifest inspect` / `skopeo inspect` 都不能确认存在，结果会是 `unknown`。

`unknown` 不会被当成缺失自动补齐，而是直接失败退出。这样避免 Harbor 网络、认证、TLS、项目路径错误时被误判成“缺镜像”，然后做错误推送。

## Harbor 已存在时

如果检查结果为 `exists`：

```text
[images] Harbor 已存在，跳过: harbor.sunmoonai.com:30443/k8s-images/xxx:tag
```

不会 load tar，也不会 push。

## Harbor 缺失时

如果检查结果为 `missing`，才进入补齐流程。

补齐方式取决于部署目标：

| 目标 | 补齐方式 |
| --- | --- |
| KIND | 本机 `docker load` + `docker tag` + `docker push` |
| C1/C2/C3 等远程集群 | 使用 `utils/registry-push-management/loadimage.sh remote-push-by-ref` |

## KIND 流程

KIND 使用本机 Docker。

默认从本地目录查找 tar：

```text
~/packages-to-be-installed/images
```

可用环境变量覆盖：

```bash
COMPONENT_IMAGE_TAR_DIR=/path/to/images
```

查找 tar 后执行：

1. `docker load -i <tar>`
2. 解析 `Loaded image: ...`
3. `docker tag <loaded-ref> <target-ref>`
4. `docker push <target-ref>`

如果本地 tar 不存在，直接失败退出。KIND 不会再尝试从公网 pull。

## 远程集群流程

远程集群使用：

```text
utils/registry-push-management/loadimage.sh
```

调用方式：

```bash
PROJECT_NAME="$project" REGISTRY_URL="$registry" \
  utils/registry-push-management/loadimage.sh --cluster "$CLUSTER" remote-push-by-ref "<repo:tag>"
```

`remote-push-by-ref` 的策略：

1. 优先在远端节点的 `REMOTE_IMAGE_DIR` 查找 tar
2. 远端没有 tar，则尝试从本地 `LOCAL_IMAGE_DIR` 上传
3. 仍然找不到 tar，则失败退出
4. 找到 tar 后远端 load/tag/push

这里不会把“本地/远程 tar 都不存在”当成可忽略问题；缺 tar 会阻断组件部署。

## tar 命名规则

tar 查找会尝试多种文件名。

例如镜像：

```text
bitnami/postgresql:17.6.0-debian-12-r4
```

可能匹配：

```text
bitnami/postgresql:17.6.0-debian-12-r4.tar
bitnami_postgresql_17.6.0-debian-12-r4.tar
postgresql:17.6.0-debian-12-r4.tar
postgresql_17.6.0-debian-12-r4.tar
```

也支持 `.tar.gz`。

远程查找主要使用安全文件名：

```text
bitnami_postgresql_17.6.0-debian-12-r4.tar
bitnami_postgresql_17.6.0-debian-12-r4.tar.gz
```

实际打包时建议统一使用安全文件名：把 `/` 和 `:` 替换为 `_`。

## 目标 registry/project

默认值来自：

```text
utils/registry-push-management/loadimage.conf
```

常用变量：

```bash
REGISTRY_URL="harbor.sunmoonai.com:30443"
PROJECT_NAME="k8s-images"
```

组件也可以通过函数参数覆盖 project：

```bash
ensure_component_images_in_harbor "casdoor" "k8s-images"
```

业务 App 自身镜像通常进入 `app-images`，Casdoor 等平台基础镜像通常进入 `k8s-images`。

KIND 场景还会读取：

```text
sunmoonai/kind-infrastructure/push-to-harbor/push-images-to-harbor.conf
```

用于获取 KIND Harbor 地址、项目、管理员账号密码等。

## 如何接入新组件

1. 新增镜像清单：

```text
utils/components-images/<component-name>-images.txt
```

2. 在部署脚本里定义函数：

```bash
push_<component>_images_to_harbor() {
    push_component_images_to_harbor "<component-name>"
}
```

或直接：

```bash
ensure_component_images_in_harbor "<component-name>"
```

3. 在真正部署 workload 前调用该函数。

4. 不要吞掉失败返回值。错误写法：

```bash
push_xxx_images_to_harbor || log_warn "镜像推送失败，继续部署"
```

正确做法是让失败阻断部署：

```bash
push_xxx_images_to_harbor
```

## 跳过开关

调试时可显式跳过组件镜像 ensure：

```bash
SKIP_COMPONENT_IMAGE_ENSURE=true
```

该开关只用于临时调试。正常部署不要开启，否则可能出现 Pod 拉镜像失败。

Harbor 等待也可跳过：

```bash
SKIP_HARBOR_WAIT=true
```

这只跳过 Harbor 就绪等待，不改变后续镜像检查逻辑。

## 常见失败与排查

### 找不到镜像清单

```text
[images] 找不到组件镜像清单
```

检查是否存在：

```text
utils/components-images/<component-name>-images.txt
```

以及部署脚本传入的 `<component-name>` 是否和文件名前缀一致。

### Harbor 状态 unknown

```text
[images] 无法确认 Harbor 镜像状态，停止部署
```

常见原因：

- Harbor API 不通
- 账号密码错误
- Harbor TLS/证书问题
- project/repository 解析错误
- 本机缺少 `curl`、`python3`，且 fallback 工具也无法确认

优先用以下方式确认：

```bash
curl -k https://harbor.sunmoonai.com:30443/v2/
docker manifest inspect harbor.sunmoonai.com:30443/k8s-images/<image>:<tag>
skopeo inspect --tls-verify=false docker://harbor.sunmoonai.com:30443/k8s-images/<image>:<tag>
```

### Harbor 缺失但找不到 tar

```text
[images] 本地 tar 不存在
本地也未找到 tar
```

检查：

- KIND：`COMPONENT_IMAGE_TAR_DIR` 或 `~/packages-to-be-installed/images`
- 远程：`REMOTE_IMAGE_DIR`
- 本地 fallback：`LOCAL_IMAGE_DIR`
- tar 文件名是否符合命名规则

### 远程 load/tag/push 失败

检查：

- 远程节点能否执行 `nerdctl`
- `CONTAINERD_NAMESPACE` 是否正确
- 远程节点能否访问 Harbor
- `REGISTRY_LOGIN_BEFORE_PUSH`、`REGISTRY_USERNAME`、`REGISTRY_PASSWORD` 是否需要配置

## 与旧检查脚本的关系

旧脚本如 `check-local-immage.sh`、`check-node-images.sh` 主要用于检查本地或节点侧镜像/tar 状态。现在组件部署前的主流程应使用 `ensure_component_images_in_harbor`。

部署前不再只检查“本地有没有”或“节点有没有”，而是以目标 Harbor 是否已有镜像为准。Harbor 没有时才补齐，无法补齐就失败退出。

## 总结

组件镜像机制的关键点：

- Harbor 是部署拉镜像的目标事实源
- 组件部署前必须确认 Harbor 有所需镜像
- Harbor 已有就跳过，不重复推
- Harbor 缺失才从 tar 补齐
- tar 不存在或推送失败必须阻断部署
- Traefik 和 Harbor 自身是前置基础设施例外
- Harbor 安装完成后的基础设施镜像推送逻辑保留
