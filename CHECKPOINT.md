# 新部署体系交接

## 目标与边界

从零建立可长期维护、符合生产工程规范的部署代码，第一期 KIND。五仓工作区为 `/home/zymun/worktrees/platform-kind-v1`，分支均为 `platform-kind-v1`，从各自本地 master 建立；基线见 [输入盘点](docs/platform-kind-v1/inventory.md)。原 luna 只作参考，新代码不调用旧部署程序。

入口：[架构](docs/platform-kind-v1/architecture.md)、[版本](docs/platform-kind-v1/images.md)、[实际操作](platform/README.md)。

所有者已授权按方案继续：新体系不迁移旧业务数据或旧 Harbor 镜像，应用可适配并重新构建；业务 Python **3.13.15**。不因取消迁移而擅自删除受保护的旧节点、卷、备份或他人的 local-integration 工作。未 push，四个应用仓尚未修改。新工作区在当前工具默认可写范围之外，写入继续走工具权限流程。

## 当前实现

`platform/` 使用原生 Make/Ansible：工具引导、镜像查看/检查、宿主挂载预检、文件物料预览/下载/离线核验。Harbor 安装、KIND 创建、Flux 和应用部署、统一启停仍未实现。

- Ansible 2.21.4 与依赖哈希锁已安装到 .venv，使用宿主 Python 3.12.3；不改变系统 Python。
- `upstream-images.lock.json` 中 43 个选定上游镜像全部取得 linux/amd64 manifest 并复算 Raw SHA256，complete=true。上一轮 4 个缺口已关闭。
- Calico 三项统一用官方固定版本 YAML 指定的 quay.io/calico；Casdoor 确认为不带 v 的 4.12.0。
- `files.lock.json` 锁定 8 项文件，合计 **929,341,287 字节**：KIND 0.33.0、kubectl 1.36.5、Compose 5.5.1、SOPS 3.13.3、age 1.3.2、Flux 2.9.5、Harbor 2.15.2 官方离线安装包、Calico 3.32.2 上游清单。
- 8 项均通过新入口下载到 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/`，按 bin/packages/manifests 分类，大小和 SHA256 全部通过。未解包安装工具，未导入镜像。
- 两份输入锁仍为 offline_ready=false：完整宿主引导、KIND 构建、kubeadm 配套、chart/辅助镜像、自有应用和发布闭包未完成。

## 本轮实际执行结果（2026-10-01）

| 操作 | 结果 |
| --- | --- |
| make check-images | 退出 0，43 项身份完整 |
| make plan-artifacts | ok=7、changed=0、failed=0，不下载 |
| make fetch-artifacts | ok=18、changed=4、failed=0，8 项下载校验完成 |
| make check-artifacts | ok=8、changed=0、failed=0，不联网复核全部文件 |
| 再次 make fetch-artifacts | ok=17、changed=0、failed=0，下载全部跳过 |
| 原宿主挂载预检 | 上轮 ok=5、changed=0、failed=0；不代表 Docker 命名空间已验收 |

此前直读 WSL UNC 路径中的 PowerShell 脚本，被当前用户 RemoteSigned 策略拒绝。已修为发布只读助手到 Windows 本地 `C:\wsl-disks\scripts\platform-kind-v1\windows-capacity.ps1`，再按现有策略执行；未改策略、未提权、未新建计划任务。代理由所有者开启后，本地官方站点和镜像仓库查询恢复，实际下载全部在本机；东京本轮只有只读查询，无新增远程文件。

容量助手通过 Win32 API 查询 VHDX 实际分配，按 64 位整数预算。下载前 C 空闲 131,626,299,392 字节，数据 VHDX 已分配 175,963,635,712 字节，230 GiB 上限还需 70,996,983,808 字节；再预留下载体积两倍后剩 58,770,633,010 字节，大于 50 GiB。重跑时扣除未来数据盘增长后剩 60,611,080,192 字节。此结果只批准该批下载，节点构建、解包和整套部署需重新计算，不能视为还有无限空间。

## Harbor 离线身份：下一步必须使用

只读确认 Docker 29.4.3、overlayfs、io.containerd.snapshotter.v1。官方安装包内为 OCI 镜像归档。

首次按上游 manifest 摘要查找归档只找到配置，未找到对应 manifest；核实原因是归档使用未压缩 OCI 层，不能混用分发与归档摘要。随后流式核验整个内层归档的 **177 个 blob** 均与路径 SHA256 相符，12 个镜像的配置摘要与已核实上游相同，每层实际 blob 摘要与配置 rootfs.diff_ids 一一对应，OCI index 引用也匹配。没有提取镜像层到磁盘。

映射保存在 `platform/artifacts/harbor-offline-images.lock.json`，绑定安装包 SHA256，分别记录上游和归档引用。**尚未 docker load，也未实际验证导入后的 repo@digest 查询或运行。** 新 Harbor 入口必须先验证这一步，不能把上游压缩 manifest 直接用到官方离线归档。

## 后续顺序

1. 完成余下工具/构建依赖、KIND 1.36.5 官方构建输入、kubeadm 配套及 chart 锁。当前没有已完成的 1.36.5 节点镜像，不能用 1.36.4 充数。
2. 补 Docker 服务挂载可见性、秘密引用和完整发布容量准入；保留 50 GiB 底线。物料缓存父目录在本机已存在，干净宿主的初始引导仍需实现。
3. 实现官方 Harbor 新装与归档镜像导入验证、独立证书和认证、入口、备份恢复，再做 KIND 和 Flux。现有服务仍保持原状，环境切换单列具体计划。
4. 模板优先接入真实业务链，再覆盖所有约定组件，复用已有功能验收；四个后端锁已有主要原生包的 cp313 wheel 记录，仍需实际构建。
5. 验收一键与单组件、统一启停、WSL/KIND 重启及 KIND 删除重建后的镜像和数据持久化；实现空间监控和受控清理。
6. 达到退出条件后按授权整理旧实现、旧物料及临时资源。只读粗盘点看到旧 releases 约 27 GiB，但有多个不可读目录，且包含约 19 GiB 保护备份；这不是可删除清单，本轮未删除其中任何文件。

本轮没有执行业务测试、变更集群/Harbor/Docker 配置、关闭 WSL 或删除旧环境。未设 token 或时间预算。已授权实现不重复询问，新增破坏性动作仍按具体授权执行。
