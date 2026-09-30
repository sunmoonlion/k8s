# 新部署体系交接

## 目标与边界

从零建立可长期维护、符合生产工程规范的部署代码，第一期 KIND。五仓工作区为 `/home/zymun/worktrees/platform-kind-v1`，分支均为 `platform-kind-v1`，从各自本地 master 建立；基线见 [输入盘点](docs/platform-kind-v1/inventory.md)。原 luna 只作参考，新代码不调用旧部署程序。

入口：[架构](docs/platform-kind-v1/architecture.md)、[版本](docs/platform-kind-v1/images.md)、[实际操作](platform/README.md)。

所有者已授权按方案继续：新体系不迁移旧业务数据或旧 Harbor 镜像，应用可适配并重新构建；业务 Python **3.13.15**。不因取消迁移而擅自删除受保护的旧节点、卷、备份或他人的 local-integration 工作。未 push，四个应用仓尚未修改。新工作区在当前工具默认可写范围之外，写入继续走工具权限流程。

## 当前实现

`platform/` 使用原生 Make/Ansible：工具引导、镜像查看/检查、宿主挂载预检、文件物料预览/下载/离线核验、工作区工具安装、官方 KIND 节点构建与产物检查。Harbor 新装、KIND 集群创建、Flux/应用部署和统一启停仍未实现；现有运行环境不是新体系的验收结果。

- Ansible 2.21.4 的哈希锁已安装到 .venv，宿主 Python 3.12.3 不变。
- 55 个选定上游及建群配套镜像的 amd64 manifest 已取得并复算摘要。complete=true 只针对这份清单，offline_ready=false。
- 10 项文件共 **1,358,981,849 字节**，全部下载到 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/`，按 bin/packages/manifests 分类；本轮新增 kubeadm 1.36.5 与 Kubernetes server 1.36.5。
- KIND 0.33.0、kubectl/kubeadm 1.36.5 已通过新入口安装到工作区 `.tools/bin`，不替换系统工具。
- 新增 `kind-build.lock.json` 与 `cluster/build-node.yaml`：直接调用 KIND 官方 `--type file`，固定 base digest，输入已核验的 server 包。构建仍须联网取得辅助镜像，不能宣称构建全离线。
- 节点镜像 **sunmoon-kind-node:v1.36.5-kind0.33.0** 已在本机实际构建，Docker ID 为 **sha256:676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b**，Docker 报告 Size=384,868,691 字节（不能当成解压峰值或最终导出大小）。
- 实测 Kubernetes/kubeadm 1.36.5、containerd 2.3.4、runc 1.4.3。锁定 base 的 manifest 与 RootFS 前缀、10 个内置镜像配置摘要均核验通过。尚未逐层验证节点内镜像、导出节点归档、创建新集群或验证 Pod 调度。
- kubeadm 配套 pause 为 3.10.2；KIND 官方构建按 base containerd 配置覆盖为 3.10，分别锁定，不混用。Calico 仍为正式集群选定 CNI，预载的 kindnet 属官方构建依赖。

## 本轮实际执行结果（2026-10-01）

| 操作 | 结果 |
| --- | --- |
| make fetch-artifacts ARTIFACTS=kubeadm | ok=18、changed=1、failed=0 |
| make fetch-artifacts ARTIFACTS=kubernetes-server | ok=20、changed=1、failed=0 |
| make check-artifacts | 10 项大小/摘要完整，ok=8、changed=0、failed=0 |
| make install-binaries | 首次 ok=19、changed=2；重复 ok=19、changed=0、failed=0 |
| make check-images | 55 项，退出 0 |
| make build-node | 官方构建完成；首次版本输出解析断言失败，未误报验收通过 |
| 修复后 make check-node | ok=16、changed=0、failed=0，复核已有产物，不重建 |

两个现场发现已原位修复：`/kind/version` 没有末尾换行，须显式分行；本机 Docker 29/containerd 存储的 image ID 返回 manifest 身份，base 应核对 Descriptor.digest，不能等同 config digest。工具/文件下载与节点构建共用 `host/tasks/capacity.yaml`，不新增管理框架。

构建前 C 空闲 131,590,823,936 字节；未来数据盘增长 70,996,983,808 字节；扣除本次 **6 GiB 估计预算**后剩 54,151,389,184 字节，高于 50 GiB。构建后另一次容量检查 C 空闲 131,589,734,400 字节，扣未来数据盘增长和工具复核预算后剩 60,306,390,140 字节。WSL 已分配空间复用不等于构建没有占用；后续导出与部署须重新预算。

Windows 容量助手发布于 `C:\wsl-disks\scripts\platform-kind-v1\windows-capacity.ps1`，按现有 RemoteSigned 策略运行，无提权、无任务/策略修改。本轮东京 SSH 两次超时；所有下载和构建均在本机完成，东京未新增文件。

本地构建回执在 `platform/.build/node-image.json`（忽略提交）；完整固定输入已入源码。仅删除本轮自建临时文件和 KIND 构建临时目录/容器，未清理既有环境。

## Harbor 离线身份：下一步必须使用

只读确认 Docker 29.4.3、overlayfs、io.containerd.snapshotter.v1。官方安装包内为 OCI 镜像归档。

首次按上游 manifest 摘要查找归档只找到配置，未找到对应 manifest；核实原因是归档使用未压缩 OCI 层，不能混用分发与归档摘要。随后流式核验整个内层归档的 **177 个 blob** 均与路径 SHA256 相符，12 个镜像的配置摘要与已核实上游相同，每层实际 blob 摘要与配置 rootfs.diff_ids 一一对应，OCI index 引用也匹配。没有提取镜像层到磁盘。

映射保存在 `platform/artifacts/harbor-offline-images.lock.json`，绑定安装包 SHA256，分别记录上游和归档引用。**尚未 docker load，也未实际验证导入后的 repo@digest 查询或运行。** 新 Harbor 入口必须先验证这一步，不能把上游压缩 manifest 直接用到官方离线归档。

## 后续顺序

1. 先核验节点内镜像层、导出已构建的 1.36.5 节点归档并记录文件/manifest 身份，再完成 Calico 镜像离线归档、余下工具与 chart 锁。现有本地节点镜像不能代替可恢复的正式离线物料。
2. 补 Docker 服务挂载可见性、秘密引用和完整发布容量准入；保留 50 GiB 底线。物料缓存父目录在本机已存在，干净宿主的初始引导仍需实现。
3. 实现官方 Harbor 新装与归档镜像导入验证、独立证书和认证、入口、备份恢复，再做 KIND 和 Flux。现有服务仍保持原状，环境切换单列具体计划。
4. 模板优先接入真实业务链，再覆盖所有约定组件，复用已有功能验收；四个后端锁已有主要原生包的 cp313 wheel 记录，仍需实际构建。
5. 验收一键与单组件、统一启停、WSL/KIND 重启及 KIND 删除重建后的镜像和数据持久化；实现空间监控和受控清理。
6. 达到退出条件后按授权整理旧实现、旧物料及临时资源。只读粗盘点看到旧 releases 约 27 GiB，但有多个不可读目录，且包含约 19 GiB 保护备份；这不是可删除清单，本轮未删除其中任何文件。

本轮没有执行业务测试或测试套件、变更集群/Harbor/Docker 配置、关闭 WSL 或删除旧环境。未设 token 或时间预算。已授权实现不重复询问，新增破坏性动作仍按具体授权执行。
