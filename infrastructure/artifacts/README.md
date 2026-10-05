# 物料、镜像与版本锁

物料根唯一在[site.yaml](../environments/kind/site.yaml)。当前批次为`/home/zymun/packages-to-be-installed/releases/platform-kind-v1`；安装包、镜像、模型与情报库按用途分目录，不凭tar/tgz扩展名猜类型。

## 谁需要离线，谁从Harbor取得

| 类别 | 类型/来源 | 用途 |
|---|---|---|
| KIND/kubectl/kubeadm/Flux/Helm/SOPS/age/Compose/mc | `bin/`、`packages/`及文件锁 | 引导与维护工具 |
| KIND节点、Calico、宿主工具 | `images/`、`manifests/`，bootstrap/host归档锁 | 仓库/网络未就绪也能引导 |
| Harbor官方离线包及内层镜像 | `packages/`，安装成员/启动镜像锁 | 仓库独立启动和恢复，避免依赖自身 |
| chart、部署清单 | `charts/`、`manifests/` | 固定内容供原生部署链 |
| 固定模型、Trivy/Java DB | `models/`、`databases/` | 无启动时下载，校验字节/时间 |
| 平台服务与应用基础镜像 | 固定上游摘要→归档校验→skopeo发布Harbor | 集群认证拉取 |
| 应用业务依赖和成品 | 在线npm/pip/uv；成品发布Harbor | [应用构建](../applications/README.md)，不要求业务离线依赖包 |

## 唯一身份来源

| 锁 | 责任 |
|---|---|
| [files.lock.json](files.lock.json) | 外部工具/包/chart/模型/DB的URL、文件大小/SHA及成员 |
| [upstream-images.lock.json](upstream-images.lock.json) | 已解析上游linux/amd64 manifest/config及来源 |
| [kind-build.lock.json](kind-build.lock.json)、[node-image.lock.json](node-image.lock.json) | 节点固定构建输入与输出 |
| [bootstrap-archives.lock.json](bootstrap-archives.lock.json)、[host-archives.lock.json](host-archives.lock.json) | 完整镜像归档文件身份 |
| [harbor-package-files.lock.json](harbor-package-files.lock.json)、[harbor-offline-images.lock.json](harbor-offline-images.lock.json) | 官方包成员与内层启动镜像 |
| 组件`image.lock.*` | 应用成品/必要派生镜像，区别于上游原镜像 |

文件SHA256验证归档信封，manifest摘要验证镜像，config摘要验证运行配置，layer/blob验证实际内容。各自不可互换。物料本地已存在不代表已发布Harbor；tag存在也必须对应固定摘要。

## 原生准备与校验

```sh
make -C infrastructure plan-artifacts
make -C infrastructure fetch-artifacts
make -C infrastructure check-artifacts
make -C infrastructure plan-bootstrap-images
make -C infrastructure fetch-bootstrap-images
make -C infrastructure check-bootstrap-images
make -C infrastructure prepare-host-materials
make -C infrastructure check-host-materials
```

`ARTIFACTS=<逗号分隔锁ID>`限制文件；`SERVICE_IMAGES`只选平台镜像物料，不开启/关闭运行组件。各plan不下载；verify读已有完整字节。fetch计算原子临时文件/展开/传输峰值，有限重试与续传后核大小、SHA；完整验证后同文件系统原子发布，已有文件/回执缺一或摘要漂移拒绝覆盖。

当前Docker归档采用OCI布局。只读[verify-oci-archive.py](verify-oci-archive.py)核所有blob、descriptor引用/大小、amd64 config、OCI/Docker兼容元信息及适用的diff_ids，不启动容器或联网。不能假定任意Docker后端导出格式都兼容。

## 发布和清理边界

服务/应用发布由Make直接调用[publish.yaml](publish.yaml)和[同一任务](tasks/publish-image.yaml)。RAGFlow派生镜像使用同一入口，显式允许关闭的可选组件跳过；其它发布仍要求enabled准入，不将关闭或校验失败当作发布成功。目标已有相同digest则复核，tag不同digest拒绝，401/证书/网络失败不能当“不存在”；独立puller验证目标身份。确认发布成功后只精确清除本次应用传输归档，不删镜像/卷/备份。

宿主保留集合包括已停容器引用与非驻留引导工具：Harbor prepare用于挂载守卫、skopeo用于发布/恢复、exporter属于官方包。不能按“没有运行容器”就判无用。所需物料丢失按锁补回同批次后完整校验，不能去旧工作树转接。

升级审核输入与输出锁、兼容性/数据迁移、完整物料和恢复范围，再发布晋级；不跟随浮动latest。Skopeo容器版本曾与源码最新release不同，原因为官方同名容器tag未发布；以固定容器身份和真实版本为准，不冒充源码最新版。
