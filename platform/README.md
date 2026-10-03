# 新部署体系：宿主、集群与平台服务

本目录使用原生 Make、Ansible 和声明文件，不调用旧 `sunmoonai/`、`utils/` 或 luna 工作区部署程序。当前提供物料准备、宿主挂载预检、官方 KIND 建群、独立 Harbor、TLS 直通入口、Flux/SOPS 与首批平台服务。业务应用、全平台统一启停及开机恢复尚未完成。

## 日常入口

在本目录执行：

```sh
make tools            # 将带哈希锁的 Ansible 安装到 .venv
make images           # 查看上游镜像和 linux/amd64 摘要
make check-images     # 验证镜像清单完整性及引用/摘要一致性
make preflight        # 只读检查宿主挂载
make plan-artifacts   # 只读查看文件物料；不联网、不修改物料目录
make fetch-artifacts  # 核容量后下载并校验；不安装工具或启动服务
make check-artifacts  # 不联网核对物料文件的大小和 SHA256
make install-binaries # 从物料安装 KIND/kubectl/kubeadm 到 .tools/bin
make plan-node-build  # 查看官方 KIND 构建参数，不构建
make build-node       # 核容量、构建并检查新节点镜像；不创建集群
make check-node       # 重新核验已有构建产物和全部内置内容文件，不重建
make plan-bootstrap-images   # 预览 KIND/Calico 离线镜像归档
make fetch-bootstrap-images  # 按摘要获取、导出并核验归档
make check-bootstrap-images  # 不联网、不调用 Docker，核验完整归档
make prepare-harbor-materials # 官方安装文件解包及启动镜像导入；不启动服务
make install-binaries BINARIES=compose # 安装已核验的 Compose
make registry-plan           # 查看新 Harbor 的部署范围
make registry-deploy         # 配置并启动新 Harbor，不切换旧入口
make registry-status         # 查看新 Harbor 的 systemd 状态
make registry-stop           # 停止新 Harbor，保留数据
make registry-start          # 检查挂载并启动，验健康与认证
make prepare-host-materials  # 准备 HAProxy/skopeo 离线归档和本机镜像
make check-host-materials    # 离线校验两项宿主工具归档
make entry-plan              # 入口路由预览
make entry-deploy            # 原生 HAProxy 入口部署，当前正式30443入口
make entry-stop              # 停止本次入口
make entry-start             # 启动本次入口并验 Harbor TLS
make entry-status            # 查看本次入口状态
make registry-accounts       # 新项目及独立推拉身份；实际 token 认证
make registry-publish-check  # 正式切换后执行真实推送/拉回和权限拒绝核验
make scanner-db-plan        # 查看已锁定的离线漏洞库/Java 索引
make scanner-db-install     # 首次安装；已有数据库不覆盖
make scanner-db-verify      # 复核全部数据库文件摘要
make registry-scan-check    # 通过 Harbor 发起真实扫描并保存报告
# registry-recovery-plan/check 另需 BACKUP 与 BACKUP_SHA256，见扫描与恢复文档
```

支持同一入口选择部分文件，例如 `make fetch-artifacts ARTIFACTS=kind,kubectl`；默认选择锁文件内全部文件。不存在的名称报错，不跳过。站点参数可用 `SITE=environments/kind/site.yaml` 指定。当前首次创建物料缓存要求其父目录已存在，以便先核验所在文件系统的可用空间。

`make tools` 使用宿主现有 Python 3.12，满足 Ansible 2.21.4 要求，不替换系统 Python；业务镜像独立固定 Python 3.13.15。依赖源为 `tools/requirements.in`，安装锁为 `tools/requirements.lock`。更新命令：

```sh
uv pip compile --python-version 3.12 --generate-hashes --no-header \
  --index-url https://pypi.org/simple tools/requirements.in \
  --output-file tools/requirements.lock
```

审查 diff 后再同步环境。uv、宿主 Python 和 jq 是当前入口的前置工具；全新离线宿主的完整引导物料尚未完成。

## 输入与目录

| 文件 | 职责 |
| --- | --- |
| `environments/kind/site.yaml` | 站点路径、盘 UUID、仓库地址、Windows 容量底线；不含凭据和镜像覆盖 |
| `host/inventory.yaml` | Ansible 本机连接 |
| `host/preflight.yaml` | 核对精确挂载点、ext4、UUID、bind 子目录并报告容量 |
| `host/windows-capacity.ps1` | 只读计算 C 盘、数据 VHDX 实际分配、最大增长与本次操作预算 |
| `artifacts/upstream-images.lock.json` | 镜像来源 tag、amd64 manifest 摘要、config 摘要及压缩层大小 |
| `artifacts/files.lock.json` | 工具、安装包和官方清单的 URL、版本、类型、大小、文件 SHA256 |
| `artifacts/files.yaml` | 原生 Ansible 的预览、下载、离线核验 |

当前缓存为 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/`：

- `bin/`：原始二进制物料；当前下载模式为 0644，尚未安装到 PATH。
- `packages/`：工具压缩包和 Harbor 官方离线安装包。Harbor 安装包内带启动镜像，类型仍标为整套安装包。
- `manifests/`：未经部署修改的上游 YAML。
- `databases/`：带日期、schema 和摘要的漏洞库/Java 索引快照；不是运行镜像。
- `images/`：KIND 节点、三个 Calico、HAProxy 和 skopeo 的离线 OCI 归档及校验回执。备份、日志和临时下载不进正式物料清单。

文件 SHA256 与镜像 manifest digest 是不同身份，不能互相替代。

## 下载行为与空间保护

执行 fetch 时先发布容量助手到 Windows 本地 `C:\wsl-disks\scripts\platform-kind-v1\windows-capacity.ps1`，按现有 RemoteSigned 策略运行，避免 WSL UNC 路径被判为未签名远程脚本。不改执行策略，不申请管理员权限，不设置计划任务。

容量算法使用 64 位整数：C 盘实际空闲减去「230 GiB 减数据 VHDX 实际分配」的非负部分，再减本次缺失文件大小的两倍（文件与临时空间），必须至少剩 50 GiB。同时检查缓存文件系统空间。此预算只覆盖所选下载，不能据此认定节点构建、解包或整套部署空间足够；其他系统盘增长仍需独立预算。

下载继承当前进程代理环境，普通文件使用 Ansible get_url；大体积 database 类型由原生 curl 续传 `.part`，每次连接最长 180 秒，失败有限重试。HTTPS 校验始终开启，归档完成后核大小和 SHA256，再发布为正式文件。成功文件重跑时复用，已有文件不符合锁则拒绝覆盖；失败的 `.part` 保留供下一次续传，不算正式物料。get_url 普通文件仍不支持跨进程续传。

## 已核实与未完成

56 个选定上游及建群配套镜像的 linux/amd64 manifest 已全部取得。通过东京及本机原生 `docker manifest inspect --verbose` 读取公开元数据，对 Base64 Raw 解码后复算 SHA256，与 Descriptor 对比。Calico 三项使用官方清单指定的 quay.io；Casdoor 已确认使用不带 v 的 4.12.0。查询临时程序不作为部署依赖。

`check-images` 通过仅证明这一批镜像身份完整；文件校验通过仅证明选中文件可用。KIND/Calico 引导归档已经完成；集群验收、完整宿主工具/构建依赖、chart/辅助镜像、自有应用镜像和完整离线发布尚需完成，因此两份锁均保持 `offline_ready=false`。

宿主挂载预检、Harbor 数据目录的 Docker 可见性、新 Harbor 部署及后端 TLS/认证已实际通过。正式入口 skopeo 推送/完整拉回/摘要和权限拒绝已实际通过；宿主Docker已升29.8.1，候选/正式认证pull通过，正式30443已切新Harbor。WSL/KIND 重启与重建恢复仍待验收；未执行业务测试。

## 本批物料的实际结果

10 项文件共 1,358,981,849 字节已经下载。此前 8 项重复 fetch 为 changed=0；新增 kubeadm 和 server 包均通过统一入口下载并校验。

Harbor 官方包内 177 个 OCI blob 已流式复算 SHA256，12 个镜像的配置及未压缩层身份与上游一致。由于层的压缩表示不同，归档 manifest 摘要与上游分发摘要不同，映射见 `artifacts/harbor-offline-images.lock.json`。导入后的 Docker 摘要查询及按归档 digest 启动新 Harbor 已验证；不得混用这两类摘要。

## 规则对应

| 规则 | 本单元处理 |
| --- | --- |
| C-R1 / C-R2 | 分开固定文件与镜像身份；最终镜像引用为 repo@sha256；完整发布待形成 |
| C-R4 | 站点参数不覆盖镜像；依赖版本来自锁文件 |
| C-R6 | 应用改动仍从模板开始，目前四个应用仓未改 |
| C-D3 / C-D8 | 本轮不改数据库身份或迁移链；后续保持独立逻辑库和迁移 Job |

## KIND 节点构建

`make install-binaries` 默认选择 kind/kubectl/kubeadm，可用 `BINARIES=kind,kubectl` 缩小范围。只安装在工作区 `.tools/bin`，不替换系统工具；源文件和安装后文件都核对 SHA256。`.tools/`、`.venv/`、`.build/` 不提交 Git。

`make build-node` 直接使用 KIND 官方文件构建模式，base 使用锁定摘要。`kind-build.lock.json` 引用已有文件/镜像 ID，不从站点配置覆盖镜像版本。构建会联网拉取官方辅助镜像，结束后在无网络临时容器中核对 Kubernetes 版本和十个内置镜像的配置摘要。现有输出标签会拒绝覆盖，失败产物不能被自动视为已验收。

构建前同时检查 Windows 增长预算和 Docker/临时目录文件系统。当前新增空间预算为 **6 GiB 估计值**，覆盖约 1 GiB server 解包、base 和内容解压、工作容器与提交镜像及余量；不是硬配额，也不覆盖后续导出。构建后复核剩余容量。原生 KIND 清理它自己创建的构建容器；Ansible 仅删除该次 tempfile 返回的 `.node-build-*` 解包目录，不清理已有容器、卷或构建缓存。

本地回执位于 `.build/node-image.json`，保存输入摘要、Docker image ID、大小、实际版本及内置配置身份。**不能把 Docker image ID 直接当成完整仓库引用**（本机 Docker 29 的 containerd 存储返回 manifest 身份，应读取 Descriptor 确认类型）；只有后续导出校验及发布完成，才能生成用于部署的不可变节点产物引用。节点镜像构建通过也不代表集群或项目验收通过。

2026-10-01：本机官方构建已完成，`make check-node` 为 ok=16、changed=0、failed=0；实际 Kubernetes 1.36.5、containerd 2.3.4、runc 1.4.3。节点归档已在后续本轮完成，实际建群仍未完成，详细过程见根目录 CHECKPOINT.md。

## 离线镜像归档

`bootstrap-archives.lock.json` 固定四个实际归档的文件 SHA256、大小、manifest/config 摘要；`node-image.lock.json` 固定本次真实构建产物。节点的 `origin=local-build` 表示本地产物，记录的仓库名称**尚未发布到 Docker Hub 或 Harbor**；不可把它当作已能远程拉取的地址。

| 物料 | 本次来源 | 后续用途 |
| --- | --- | --- |
| KIND 节点 | 本机官方 KIND 构建，保存为 images/kind-node-摘要.tar | 离线导入宿主 Docker 后建群 |
| Calico 三个镜像 | 从 quay.io 按 linux/amd64 digest 获取，分别保存 images/calico-组件-摘要.tar | 集群引导时导入节点，清单使用相同 digest |
| Calico 清单 | manifests/calico-v3.32.2.yaml | 保留原件，部署修改另在声明中表达 |
| Harbor 启动组件 | packages 中的官方 Harbor 离线安装包 | 独立恢复仓库，不依赖仓库自身 |
| 后续平台和业务镜像 | 尚待准备、构建并发布到新 Harbor | 集群通过认证从 Harbor 拉取 |

获取入口使用原生 `docker pull`/`docker image save` 准备引导归档；这不是镜像发布入口。发布到 Harbor 使用 skopeo，首个固定镜像的真实推拉已通过；通用应用发布流水线尚未完成。当前 Docker 29/containerd 导出为 OCI 格式，验证器按此格式检查，不能将别的 Docker 存储后端导出格式直接假定兼容。

每个归档验证完整文件 SHA256、所有内容 blob、index 引用的存在与大小、amd64 配置、OCI 与 Docker 兼容清单一致性。Harbor 未压缩层同时核对 rootfs.diff_ids。验证器是只读标准库程序，不解包、不联网、不管理部署状态。[OCI 文件布局](https://github.com/opencontainers/image-spec/blob/main/image-layout.md)、[Docker 导出命令](https://docs.docker.com/reference/cli/docker/image/save/)。

生成时先写私有临时文件，验证后用同一文件系统的硬链接发布，目标已存在则失败。已有归档只复核，不覆盖；文件与回执缺一、字节与 Git 锁不符都会停止。操作中断留下不完整发布时，先核对固定摘要再处理，不能盲删正式归档。更新版本必须显式评审输入与输出锁；入口不会自动修改 Git 中的期望摘要。

归档共 **641,355,776 字节**。已用于新 sunmoon-kind 创建并通过节点认证拉取；WSL/KIND 重启及删除重建持久化验收仍未完成。

## Harbor 官方物料准备

`make prepare-harbor-materials` 只做这些动作：校验官方安装包，原样解包到 `.tools/harbor/v2.15.2/harbor/`，逐文件校验六个成员，核对内层 OCI 归档的 177 个 blob 和 12 个镜像，再导入 Docker 并核对每个标签的 manifest 身份。若已有官方标签对应另一份镜像则拒绝覆盖；重复执行复用已验证文件和镜像。

Harbor 安装包解包约 735 MB，内部未压缩镜像内容约 2.03 GB；本次准备预留 6 GiB，覆盖解包、内容存储、展开副本与余量。这是容量估计，不是配额。Windows 增长预算以及工作目录、Docker 目录的文件系统空间均检查；已完成的重复操作不重复要求新增 6 GiB。

**不要直接执行该目录的 install.sh**：官方脚本含 `compose down -v`。新入口直接调用官方 prepare 镜像生成配置，避免包装脚本搬动全局历史文件，再用原生 Compose/systemd 管理服务。新 Harbor 已独立运行且正式仓库入口已切换；应用域名仍转原集群。配置路径、日志授权、日常操作和验收边界见 [独立 Harbor](registry/README.md)。

## 宿主入口与镜像发布身份

[入口操作](host/README.md)与 [本次切换卡](../docs/platform-kind-v1/entry-cutover.md)明确候选端口、现有路由及回退。当前正式30443入口已通过Docker认证拉取和完整镜像验收，旧代理停止保留。

`artifacts/image-archives.yaml` 是 KIND/Calico 与宿主工具共用的唯一归档实现，旧名称 bootstrap-images.yaml 已移除，原 Make 命令保持不变。宿主两项归档共 **136,100,352 字节**，按固定文件摘要及全部 blob 核验。重复 prepare-host-materials 不重复导出。

官方 skopeo stable 镜像解析并固定为 `quay.io/skopeo/stable@sha256:9182497536bb5485b4f0bdbad5dbab24cd0df7259c33005a1e732a34f5d78a99`，实际版本 **1.22.3**。源码最新 release 为 1.24.1，但该版本同名容器 tag 不存在；这是一项明确的工具版本例外，不把 stable 镜像误报为源码最新版。后续可随官方镜像更新审查摘要，部署不跟踪浮动 latest。[官方安装方式](https://github.com/podman-container-tools/skopeo/blob/main/install.md)、[源码发布](https://github.com/podman-container-tools/skopeo/releases/tag/v1.24.1)。

项目和推拉认证操作见 [Harbor 文档](registry/README.md)。新仓库真实推拉和拒绝只读身份推送已通过，首批服务镜像现由相同 skopeo 发布实现处理。


宿主 Docker 维护物料也在同一 `files.lock.json` 和 `packages/` 中：三个 29.8.1 升级包与三个 29.4.3 回退包，共 98,306,132 字节，已经下载核验；最终已成功安装29.8.1并验收（早先误判回退的历史保留在维护文档）；后者是临时回退用途，不是新生产版本。当前物料范围以锁文件为准。具体影响与批准范围见 [Docker 维护方案](../docs/platform-kind-v1/docker-maintenance.md)。


当前维护限制（2026-10-03）：Docker29.8.1和新 Harbor 可用、新 sunmoon-kind Ready，main/136已退役；旧应用入口经后续授权已恢复；两个遗留Harbor数据库保持0副本、PVC/PV保留。再次重启Docker须先临时恢复旧API使worker重载Traefik，仍有过渡依赖。恢复方案及授权边界见根目录CHECKPOINT和Docker维护操作卡。

## 扫描与恢复

离线数据库、Harbor 真实扫描、既有冷备份的隔离恢复入口与验收范围见 [扫描与恢复](../docs/platform-kind-v1/scanning-recovery.md)。恢复使用独立目录、Compose 项目和回环端口，结束后停止；不修改正式入口。

## Flux 与声明发布

原生入口、固定OCI摘要源、清理保护与验收边界见 [Flux 操作](../docs/platform-kind-v1/flux.md)。整套一键部署及开机恢复仍按 CHECKPOINT 后续顺序实现。

## SOPS 与基础声明

操作及恢复边界见 [SOPS/基础平台](../docs/platform-kind-v1/secrets-foundations.md)。`make foundations-bootstrap` 编排本层部署，`make foundations-check` 验证实际解密及拉取。整套应用一键仍待后续接入。

## 首批平台服务

Traefik、Retain 存储、PostgreSQL、Redis、RabbitMQ、Casdoor 已通过 Flux 部署。`make services-bootstrap` 编排本批重复部署，`make services-check` 做实际读写/消息/TLS登录验收。普通配置、私有输入、密码恢复及晋级方式见 [首批平台服务](../docs/platform-kind-v1/services.md)。本批不切换旧应用入口，不代表完整应用和生命周期交付已完成。
