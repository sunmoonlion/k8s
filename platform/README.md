# 新部署体系：物料与宿主预检

本目录使用原生 Make、Ansible 和声明文件，不调用旧 `sunmoonai/`、`utils/` 或 luna 工作区部署程序。当前提供物料准备与宿主挂载预检；Harbor 新装、KIND 创建、平台部署和统一启停尚未实现。

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
make check-node       # 重新核验已有构建产物，不重建
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
- 后续的镜像归档将单独进入 `images/`；备份、日志和临时下载不进正式物料清单。

文件 SHA256 与镜像 manifest digest 是不同身份，不能互相替代。

## 下载行为与空间保护

执行 fetch 时先发布容量助手到 Windows 本地 `C:\wsl-disks\scripts\platform-kind-v1\windows-capacity.ps1`，按现有 RemoteSigned 策略运行，避免 WSL UNC 路径被判为未签名远程脚本。不改执行策略，不申请管理员权限，不设置计划任务。

容量算法使用 64 位整数：C 盘实际空闲减去「230 GiB 减数据 VHDX 实际分配」的非负部分，再减本次缺失文件大小的两倍（文件与临时空间），必须至少剩 50 GiB。同时检查缓存文件系统空间。此预算只覆盖所选下载，不能据此认定节点构建、解包或整套部署空间足够；其他系统盘增长仍需独立预算。

下载继承当前进程代理环境，使用 Ansible get_url 的 TLS 校验和 SHA256 校验。成功文件重跑时复用；已存在但摘要/大小不符的文件会报错，不覆盖。断连后按有限次数重试，get_url 不支持跨进程断点续传，未完成文件可能需要重新传输；已完成文件不重复下载。下载后的完整核验仍检查每个文件的大小与 SHA256。

## 已核实与未完成

55 个选定上游及建群配套镜像的 linux/amd64 manifest 已全部取得。通过东京及本机原生 `docker manifest inspect --verbose` 读取公开元数据，对 Base64 Raw 解码后复算 SHA256，与 Descriptor 对比。Calico 三项使用官方清单指定的 quay.io；Casdoor 已确认使用不带 v 的 4.12.0。查询临时程序不作为部署依赖。

`check-images` 通过仅证明这一批镜像身份完整；文件校验通过仅证明选中文件可用。KIND 1.36.5 产物导出与集群验收、配套镜像的离线归档、完整宿主工具/构建依赖、chart/辅助镜像、自有应用镜像和离线发布尚需完成，因此两份锁均保持 `offline_ready=false`。

宿主挂载预检已实际通过（ok=5、changed=0、failed=0），但 Docker 服务命名空间可见性、TLS/认证、服务部署和重建恢复仍需后续准入及验收。当前没有执行业务测试或服务重启。

## 本批物料的实际结果

10 项文件共 1,358,981,849 字节已经下载。此前 8 项重复 fetch 为 changed=0；新增 kubeadm 和 server 包均通过统一入口下载并校验。

Harbor 官方包内 177 个 OCI blob 已流式复算 SHA256，12 个镜像的配置及未压缩层身份与上游一致。由于层的压缩表示不同，归档 manifest 摘要与上游分发摘要不同，映射见 `artifacts/harbor-offline-images.lock.json`。导入后的 Docker 摘要查询和启动尚未验证；安装阶段不得混用这两类摘要。

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

2026-10-01：本机官方构建已完成，`make check-node` 为 ok=16、changed=0、failed=0；实际 Kubernetes 1.36.5、containerd 2.3.4、runc 1.4.3。节点归档和实际建群仍未完成，详细过程见根目录 CHECKPOINT.md。
