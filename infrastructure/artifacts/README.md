# 物料、镜像与版本锁

物料根唯一在[site.yaml](../environments/kind/site.yaml)。当前物料根为`/home/zymun/k8s-packages`；物料先按组件归属分类，再按bin/packages/images/charts/manifests/models/databases区分类型；不凭tar/tgz扩展名猜用途。运行数据、秘密、备份和构建日志不放在本目录。

新体系只使用`~/k8s-packages`；`~/packages-to-be-installed`属于原始旧体系，含legacy/kind中的旧kubectl，不从旧目录补物料或设置路径转接。根目录由site.yaml唯一配置，版本/摘要和组件相对路径仍由锁维护。

## 日常查看与目录归属

```sh
make -C infrastructure material-inventory
make -C infrastructure material-inventory MATERIAL_OWNER=components/data-platform
make -C infrastructure material-inventory MATERIAL_OWNER=components/data-platform/text-embeddings
make -C infrastructure material-inventory MATERIAL_OWNER=registry
```

这是只读查看：从现有版本锁生成物料ID、归属、本地相对路径和Harbor目标；“存在”不是完整性验证，“Harbor目标”不是已发布证明。未被当前锁引用的旧版本/部分下载也会列出，禁止据此自动删除。内容验证仍用下文check入口，Harbor发布状态仍由认证摘要核验确定。

批次内目录职责如下；只为实际物料建目录，不为每个配置或Job建空物料目录。

| 相对目录 | 对应代码/使用方 |
|---|---|
| `cluster/kind`、`cluster/kubernetes`、`cluster/calico` | infrastructure/cluster：建群工具、节点、网络及构建输入 |
| `host/docker`、`host/entry` | 宿主安装与infrastructure/entry；保留被锁引用的Docker回退包 |
| `registry/harbor`、`registry/harbor-scanner` | infrastructure/registry：官方安装包、扫描情报库 |
| `shared/tools`、`shared/flux`、`shared/build-base-images` | 共用工具、Flux与Python/Node基础镜像；每份只保存一次 |
| `components/<平台>/<组件或应用/组件>` | 对应gitops/components；ELK聚合相关镜像，向量组件同时拥有镜像与模型 |

例如向量组件的镜像在`components/data-platform/text-embeddings/images/`，模型在同组件`models/`；Traefik的chart和镜像也在同组件下。模型复制到节点数据目录后运行，缓存目录不作为运行卷。目录归属不决定命名空间，也不代表组件已部署。

Traefik组件的`packages/traefik-3.7.13-chart-41.6.0-linux-amd64/`保留整包的原镜像、chart、渲染清单和下载来源记录。批次内batch标识与相对路径保持原样；它属于组件的辅助完整包，当前新体系安装/发布仍以锁指明的组件charts/images为准。inventory将包内文件归入同一Traefik组件，未被当前锁引用不代表可以自动删除。

## 三个位置怎样配合

- **artifacts代码**：提供共用下载、完整性校验、归档和skopeo发布；文件版本/SHA与上游镜像摘要只由现有锁维护。
- **applications代码**：四应用固定源码、在线构建、声明准备、部署与真实验收；复用artifacts发布，不复制发布实现。
- **gitops/components**：就近保存用户配置、模板、部署声明及应用/派生成品锁；组件通过物料ID引用共享锁。
- **~/k8s-packages**：锁描述的实际文件；可以由下载入口补齐，不能代替配置、Git版本锁或Harbor持久数据。

文件完整相对路径由files/bootstrap/host锁的`path`维护；镜像归属由上游/node/派生锁的`material_owner`维护，共用脚本生成`<material_owner>/images/<id>-<manifest摘要>.tar`。归档锁里的path必须与镜像归属一致。修改归属必须同时迁移已有文件、更新相关归档锁并核对字节，不保留旧路径转接或目录扫描猜测。

应用成品仍在Harbor，通常没有永久离线文件；临时传输在`.build/applications/transfer`，发布验证成功后精确删除。已有历史归档可展示但不变成新部署前提。批次根不存另一份维护配置或摘要清单。

## 谁需要离线，谁从Harbor取得

| 类别 | 类型/来源 | 用途 |
|---|---|---|
| KIND/kubectl/kubeadm/Flux/Helm/SOPS/age/Compose/mc | 各归属目录的`bin/`、`packages/`及文件锁 | 引导与维护工具 |
| KIND节点、Calico、宿主工具 | cluster/host/shared归属下的`images/`、`manifests/`，bootstrap/host归档锁 | 仓库/网络未就绪也能引导 |
| Harbor官方离线包及内层镜像 | `registry/harbor/packages/`，安装成员/启动镜像锁 | 仓库独立启动和恢复，避免依赖自身 |
| chart、部署清单 | 各组件的`charts/`、`manifests/` | 固定内容供原生部署链 |
| 固定模型、Trivy/Java DB | 向量组件`models/`、registry扫描器`databases/` | 无启动时下载，校验字节/时间 |
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
