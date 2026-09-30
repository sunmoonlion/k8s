# 新部署体系交接

## 目标与边界

从零建立可长期维护、符合生产工程规范的部署代码，第一期 KIND。五仓工作区为 `/home/zymun/worktrees/platform-kind-v1`，分支均为 `platform-kind-v1`，从各自本地 master 建立；基线见 [输入盘点](docs/platform-kind-v1/inventory.md)。原 luna 只作参考，新代码不调用旧部署程序。

入口：[架构](docs/platform-kind-v1/architecture.md)、[版本](docs/platform-kind-v1/images.md)、[实际操作](platform/README.md)。

所有者已授权按方案继续：新体系不迁移旧业务数据或旧 Harbor 镜像，应用可适配并重新构建；业务 Python **3.13.15**。不因取消迁移而擅自删除受保护的旧节点、卷、备份或他人的 local-integration 工作。未 push，四个应用仓尚未修改。新工作区在当前工具默认可写范围之外，写入继续走工具权限流程。

## 当前实现

`platform/` 使用原生 Make/Ansible：工具引导、镜像查看/检查、宿主挂载预检、文件物料预览/下载/离线核验、工作区工具安装、官方 KIND 节点构建与全量内容检查、KIND/Calico 归档、Harbor 官方物料安装。Harbor 服务新装、KIND 集群创建、Flux/应用部署和统一启停仍未实现；现有运行环境不是新体系的验收结果。

- Ansible 2.21.4 的哈希锁已安装到 .venv，宿主 Python 3.12.3 不变。
- 55 个选定上游及建群配套镜像的 amd64 manifest 已取得并复算摘要。complete=true 只针对这份清单，offline_ready=false。
- 10 项文件共 **1,358,981,849 字节**，全部下载到 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/`，按 bin/packages/manifests 分类；本轮新增 kubeadm 1.36.5 与 Kubernetes server 1.36.5。
- KIND 0.33.0、kubectl/kubeadm 1.36.5 已通过新入口安装到工作区 `.tools/bin`，不替换系统工具。
- 新增 `kind-build.lock.json` 与 `cluster/build-node.yaml`：直接调用 KIND 官方 `--type file`，固定 base digest，输入已核验的 server 包。构建仍须联网取得辅助镜像，不能宣称构建全离线。
- 节点镜像 **sunmoon-kind-node:v1.36.5-kind0.33.0** 已在本机实际构建，Docker ID 为 **sha256:676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b**，Docker 报告 Size=384,868,691 字节（不能当成解压峰值或最终导出大小）。
- 实测 Kubernetes/kubeadm 1.36.5、containerd 2.3.4、runc 1.4.3。锁定 base 的 manifest 与 RootFS 前缀、10 个内置镜像配置摘要均核验通过。本轮新增 144 个 containerd 内容文件的逐文件 SHA256 核验，并完成节点归档；尚未创建新集群或验证 Pod 调度。
- kubeadm 配套 pause 为 3.10.2；KIND 官方构建按 base containerd 配置覆盖为 3.10，分别锁定，不混用。Calico 仍为正式集群选定 CNI，预载的 kindnet 属官方构建依赖。

## 本轮实际执行结果（2026-10-01，续接 e280a385）

- 新节点内容文件 144 个全部哈希匹配，已纳入 `make check-node`。
- `make fetch-bootstrap-images` 实际获取/导出四个归档：首次 ok=123、changed=24、failed=0；重复 ok=44、changed=0、failed=0。
- `make check-bootstrap-images` 离线核验：ok=48、changed=0、failed=0。不调用 Docker 或网络；固定文件摘要、全部 blob、OCI 与 Docker 兼容清单一致性均检查。
- 四个归档共 **641,355,776 字节**，放在物料缓存的 `images/`，与 `bin/packages/manifests` 分开。输入和输出锁在 `node-image.lock.json`、`bootstrap-archives.lock.json`，尚未发布到 Harbor。
- `make prepare-harbor-materials` 首次 ok=34、changed=3、failed=0：官方安装包六个文件原样解包，内层177个blob/12个镜像核验通过，已导入 Docker，逐标签 manifest/架构匹配。最终代码重复执行 ok=34、changed=0、failed=0。
- `.tools/harbor/v2.15.2/harbor` 是可重建的官方工具安装目录，不含新服务的运行数据或凭据。禁止直接执行 install.sh，它含 compose down -v；后续使用官方 prepare 与明确 Compose 命令。
- 官方 prepare 包装脚本还有迁移 `/data/secretkey`、`/data/defaultalias` 的分支，后续实施必须前置拦截，不能误动历史文件。

容量检查最后 C 空闲 131,585,736,704 字节；预留数据盘增长到 230 GiB 的 70,996,983,808 字节后剩 60,588,752,896 字节，仍大于 50 GiB。系统 VHDX 内复用已分配空间，不等于新物料不占用文件系统；下次操作须重新预算。本轮新增 Docker 镜像与离线归档，但没有修改 Docker 配置、启动新长期服务或操作已有容器/卷。东京本轮未连接，无新增远程文件。

Windows 容量助手仍在 `C:\wsl-disks\scripts\platform-kind-v1\windows-capacity.ps1`，无策略/计划任务变更。本轮自建临时源文件在提交前清理；正式物料与工具安装保留。

## Harbor 离线身份：下一步必须使用

只读确认 Docker 29.4.3、overlayfs、io.containerd.snapshotter.v1。官方安装包内为 OCI 镜像归档。

首次按上游 manifest 摘要查找归档只找到配置，未找到对应 manifest；核实原因是归档使用未压缩 OCI 层，不能混用分发与归档摘要。随后流式核验整个内层归档的 **177 个 blob** 均与路径 SHA256 相符，12 个镜像的配置摘要与已核实上游相同，每层实际 blob 摘要与配置 rootfs.diff_ids 一一对应，OCI index 引用也匹配。没有提取镜像层到磁盘。

映射保存在 `platform/artifacts/harbor-offline-images.lock.json`，绑定安装包 SHA256，分别记录上游和归档引用。**本轮已 docker load，并通过官方标签的 Descriptor.digest 核对 12 个归档 manifest；尚未启动新 Harbor 或验证 repo@digest 形式的运行引用。** 后续生成 Compose 时必须使用已验收的归档身份，不能混用上游压缩 manifest。

## 后续顺序

1. KIND/Calico 归档与 Harbor 启动物料已完成，下一步补 Docker 服务挂载可见性并推进新 Harbor 服务配置、证书/认证和统一启停；实际启动或切换前核实现场冲突。余下工具、chart 和平台/应用物料仍需补齐。
2. 补 Docker 服务挂载可见性、秘密引用和完整发布容量准入；保留 50 GiB 底线。物料缓存父目录在本机已存在，干净宿主的初始引导仍需实现。
3. 完成官方 Harbor 新装、独立证书和认证、入口、备份恢复，再做 KIND 和 Flux。现有服务仍保持原状，环境切换单列具体计划。
4. 模板优先接入真实业务链，再覆盖所有约定组件，复用已有功能验收；四个后端锁已有主要原生包的 cp313 wheel 记录，仍需实际构建。
5. 验收一键与单组件、统一启停、WSL/KIND 重启及 KIND 删除重建后的镜像和数据持久化；实现空间监控和受控清理。
6. 达到退出条件后按授权整理旧实现、旧物料及临时资源。只读粗盘点看到旧 releases 约 27 GiB，但有多个不可读目录，且包含约 19 GiB 保护备份；这不是可删除清单，本轮未删除其中任何文件。

本轮没有执行业务测试或测试套件、变更集群/Harbor/Docker 配置、关闭 WSL 或删除旧环境。未设 token 或时间预算。已授权实现不重复询问，新增破坏性动作仍按具体授权执行。
