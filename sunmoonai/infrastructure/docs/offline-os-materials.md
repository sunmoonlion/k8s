# Ubuntu 节点依赖离线物料

统一部署代码，仅 KIND / kubeadm 两种建群入口。本页只涉及 kubeadm 节点操作系统依赖，不升级 PostgreSQL、Redis、Harbor 等平台服务。

**云上安装未经实机验证。** 已在获准的东京下载机准备公开物料，并回传本机核验；未安装任何 deb、未改服务。当前 OS 配置支持 Ubuntu 24.04 amd64，新主机采用其他系统时必须另备对应闭包，不能混用旧包。

## 本次结果

- 固定源：Ubuntu 官方 `20260927T000000Z` 快照，noble / noble-updates / noble-security，main + universe。
- 20 个根依赖解析出 94 个包，31,510,444 字节；9 个签名及包索引，112,150,216 字节。
- 新目录：`~/packages-to-be-installed/releases/kubeadm-1.36.4-linux-amd64/os/ubuntu-24.04-amd64-20260927T000000Z/`。
- 版本、来源、SHA256、大小记录于 `materials/os-dependencies.lock.json`，其 SHA 固定在主锁。`bundle.py` / `sync.py` 已按主锁消费这些精确文件。
- 全部集群物料现为 126 个文件，824,488,560 字节；本机全 SHA 通过。主锁仍 `closure_complete=false`，因为安装、镜像和网络适配尚未完成。
- 东京 `/var/lib/dpkg/status` 下载前后 SHA 相同。没有 apt 安装、清理或服务操作。

## 下载方法

只将公开的 `materials/prepare_os.py` 发到已获授权的下载主机。默认只打印；显式 `--apply` 才下载。下列命令在下载机普通用户下执行，不用 sudo：

```bash
python3 prepare_os.py \
  --root "$HOME/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64/os/ubuntu-24.04-amd64-20260927T000000Z"
# 确认属于已授权备料范围后，在相同命令末尾加 --apply。
```

脚本将 APT 配置、索引、缓存、日志、空 dpkg 状态全部放在独立目录。通过 `APT_CONFIG` 先指定私有配置目录，避免继承系统 APT hooks；检测到执行 hooks 就停止。使用空状态解析依赖，避免下载机已有软件让包遗漏。仅运行 update、simulate 和 download-only；实际安装命令不存在。

认证使用下载机预装的 Ubuntu archive keyring、HTTPS 和签名索引。下载包 SHA/大小必须与签名索引一致；解析计划与最终包集合必须完全相同。至少保留 6 GiB 可用空间，失败留日志和 partial，不自动清理。完成后重跑只核对锁中的包与索引，不追随浮动仓库更新。

固定快照不能等同于永久安全版本。后续补丁升级需新时间戳批次、重新解析和验收；签名有效期检查失败时停止，不自动关闭检查。目标主机若已装更新包，安装预检应拒绝降级，并要求匹配的离线批次。

## 回传和本机验证

精确回传列表由子锁 `files[].path` 和 `indexes[].path` 生成，另带子锁、sources.list、下载配置和记录。先创建目标父目录，再 `rsync --from0 --files-from`，配合 `--partial --append-verify` 和严格 SSH 指纹认证；不使用 `--delete`，不传私钥、业务源码或凭据。重试次数和超时必须有上限。

本机 k8s 仓根目录：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 sunmoonai/infrastructure/materials/verify_os.py \
  --root "$HOME/packages-to-be-installed/releases/kubeadm-1.36.4-linux-amd64/os/ubuntu-24.04-amd64-20260927T000000Z"
PYTHONDONTWRITEBYTECODE=1 python3 sunmoonai/infrastructure/materials/bundle.py verify
```

`verify_os.py` 使用本机预装可信 keyring 验证三个 InRelease 签名，校验其中记录的六个 Packages 摘要，再检查每个 deb 的名称、版本、架构、来源、SHA 和大小。没有把“与文件一起下载的公钥”自动当可信根。索引本身也留在离线目录，便于断网复核。正式同步由统一 `sync-cluster-materials` 精确清单完成，不扫描任意 deb 通配符安装。

本次首次回传因父目录不存在退出，创建新的 OS 批次父目录后重传成功；没有覆盖旧物料。早期只读 URL 探查遇到 zsh 对 `=https` 的命令展开，换成不含该参数的固定 HTTPS HEAD 探查后成功；下载器始终通过 subprocess 参数数组执行 APT。

## 仍须完成的部署接线

1. step01 接入专用新节点身份检查、离线包模拟安装及拒绝降级/删除/在线补包。
2. 预检已有包版本、发行版、systemd、cgroup、时钟服务冲突和内核支持；不能把东京下载成功当作目标节点安装成功。
3. 对明确批准的新节点安装 OS 基线；记录实际变更，随后接 runtime/kubeadm，不修改下载机。
4. step02–06 消费同一主锁、控制面镜像及 Calico；完成首次上云清单。没有新云主机时，只静态检查和只打印预演。

新包已齐不代表旧包可以删。旧包和缓存继续按最终清理清单保留到整体迁移验收完成。

依据：[Ubuntu 快照服务](https://snapshot.ubuntu.com/)、[APT 配置顺序与目录](https://manpages.ubuntu.com/manpages/noble/man5/apt.conf.5.html)、[Ubuntu 仓库验证链](https://documentation.ubuntu.com/security/software-integrity/archive-verification/)。
