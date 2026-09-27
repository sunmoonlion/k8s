# 固定物料清单与 kubeadm 节点安装入口

只有一套部署代码、两种建群方式。本文实现集群层的配置读取、物料消费和独立节点安装程序；平台服务版本保持原样。

**云上未经实机验证。** 当前完成代码、静态检查、东京公开备料、本地文件校验和只打印预演。没有连接 C1/C2、没有安装或重启运行时、没有部署集群。step01–03 已接到新程序，见 [新节点入口](fresh-node-bootstrap.md)；真实安装和 kubeadm/Calico 后续步骤未验收，不能绕过总控准入。

## 1. 现在使用哪些真源

| 信息 | 真源 | 调用者 |
| --- | --- | --- |
| 集群和节点 | `deploy-infrastructure-all/deploy-infrastructure-all.conf`，可选 `INFRA_PRIVATE_CONFIG_FILE` 覆盖 | 总控、common、步骤、package-sync 共用 `utils/config.sh` |
| 工具与配套配置 | `materials/cluster-artifacts.lock.json` | 备料、bundle、同步、node_install |
| 控制面镜像 | 主锁固定 SHA 的 `kubeadm-images.lock.json` | bundle 与后续导入器 |
| Calico | 主锁中的共享批次路径及 SHA | 复用原 KIND 批次，不复制另一份 |
| 物料根 | `INFRA_MATERIAL_ROOT`，默认 `~/packages-to-be-installed` | 本地校验和精确同步 |

加载器要求显式 `CLUSTER=Cn`，支持节点缺号和空值覆盖；禁止一个进程中途换集群/配置。配置是所有者维护的可信 Shell 文件，不能 source 下载来的任意文件。CLI 参数选择的集群优先于配置。预演不连接远端。

`package-sync.conf` 原有节点和凭据字段已逐项比对与总控一致后移除，保留路径设置；没有删除唯一凭据。主配置的历史凭据仍待后续迁出，不能宣称仓库历史已经脱敏。可通过 Git 之外的 `INFRA_PRIVATE_CONFIG_FILE` 指定主机、密钥路径和其他覆盖项，新脚本不输出这些凭据内容。

公共 SSH 改为密钥/agent、严格 known_hosts、明确端口及连接超时；不再携口令参数、不再失败后用密码重跑 sudo 命令。远端需要预先配置非交互 sudo。旧步骤中绕过 common 的原始 ssh/scp 仍需继续整改，不能把公共函数改完当成全部入口都已加固。

kubeconfig helper 只接受明确绝对路径且目标用户可读；不再回退任意 `~/.kube/config` 或复制为 0644。后续 init/join 接线负责创建归属明确的 0600 配置，并核对集群 UID。

## 2. 精确选包和校验

在 k8s 仓根目录：

```bash
python3 sunmoonai/infrastructure/materials/bundle.py plan
python3 sunmoonai/infrastructure/materials/bundle.py verify
```

当前锁共 126 文件：7 工具、7 控制面配套镜像归档、Calico 清单及 3 镜像、5 个配置文件、94 个 OS 依赖包和 9 个签名/索引。全部本地 SHA256 通过，共 824,488,560 字节。OS 包另已通过本机 Ubuntu 可信密钥验签，见 [OS 依赖方法](offline-os-materials.md)。

- `plan` 只解析锁；`verify` 逐文件检查路径、大小（锁声明时）和 SHA256。
- `files --null` 和 `checksums` 先完成本地校验，再输出 rsync 文件清单或校验清单。
- 根目录、条目路径和子锁不接受软链接或 `..` 逃逸；不扫描 glob、不使用“找到第一个 tar”。
- 控制面子锁的 SHA、批次、平台、来源集合必须与主锁一致；不会把 index/config/platform/tar 摘要混用。
- `--expected-kubernetes` 检查部署配置版本；`--require-complete` 额外要求 `closure_complete=true` 且 `pending` 为空。
- 当前 `closure_complete=false`。126 文件校验通过**不等于安装适配和离线验收都已完成**。

总控 `materials` 可执行同一只读校验。实际 deploy 或单步变更先经过“版本匹配 + 完整闭包”门禁，随后才可能做远端操作。当前旧配置仍为 1.30.4，门禁会拒绝其消费 1.36.4 物料；后续整套安装适配完成时再成套切换配置。总控拒绝 step00 reset。

## 3. systemd 和运行时配置物料

项目维护的五个文件在 `materials/configuration/`：

| 文件 | 将来节点安装位置 |
| --- | --- |
| `containerd.toml` | `/etc/containerd/config.toml` |
| `containerd.service` | `/etc/systemd/system/containerd.service` |
| `crictl.yaml` | `/etc/crictl.yaml` |
| `kubelet.service` | `/etc/systemd/system/kubelet.service` |
| `10-kubeadm.conf` | `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf` |

已用已核 SHA 的 containerd 2.3.4 二进制读取项目 TOML：`config dump` 成功，schema=4、SystemdCgroup=true、CRI registry config_path 正确。这里只解析配置，没有启动 daemon。kubeadm 1.36.4 的 `init-defaults` 也已只读确认 API 为 v1beta4。

来源与设计依据：对应版本的 [containerd 服务单元](https://github.com/containerd/containerd/blob/v2.3.4/containerd.service)、[CRI 配置](https://github.com/containerd/containerd/blob/v2.3.4/docs/cri/config.md)，以及 [kubelet 与 kubeadm 集成](https://v1-36.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)。本仓维护自己的配置字节并锁 SHA，不在部署时下载 upstream master。

备料命令：

```bash
python3 sunmoonai/infrastructure/materials/stage_configuration.py
# 已授权备料时，才实际新增离线文件；不安装系统服务：
python3 sunmoonai/infrastructure/materials/stage_configuration.py --apply
```

本次五文件已放入 `~/packages-to-be-installed/releases/kubeadm-1.36.4-linux-amd64/configuration/`。已有同摘要文件可复用；已有不同内容拒绝覆盖，不执行清理。修改配置后先更新锁，再使用新的物料批次，不能覆盖已冻结批次的不同字节。

## 4. 精确传输（云上未经实机验证）

```bash
CLUSTER=C1 bash sunmoonai/infrastructure/utils/package-preparation/package-sync.sh \
  sync-cluster-materials --dry-run
```

新命令省略选项也只打印。以后具备真实节点并确认身份后，显式 `--apply` 才传输。本次没有执行该选项。

流程：本地所有文件 SHA → 严格 SSH 指纹认证 → 远端逐路径/已存在文件摘要检查 → rsync 精确清单/断点目录 → 远端全部 SHA 再核验。远端已有不同摘要直接失败并保留，不覆盖；不带 `--delete`，不传仓库代码、私钥或业务配置。远端预检需要 Python ≥3.11 和 rsync，缺失不自动在线安装。

主机信息取同一配置；无 PUBLIC_IP 时可取明确 LOCAL_IP。路径可为明确绝对目录或目标用户家目录下的 `packages-to-be-installed`，不在本机提前展开远端 `~`。

历史 `sync-packages-to-all-nodes` 仍供旧平台物料路径参考，不作为新版集群闭包入口；其中旧口令认证、在线假设与清理命令还需后续统一。本次新流程只走 `sync-cluster-materials`。

## 5. 独立节点安装程序（未在主机执行）

```bash
python3 sunmoonai/infrastructure/materials/node_install.py --phase runtime
python3 sunmoonai/infrastructure/materials/node_install.py --phase kubernetes
```

默认只打印。step01–03 经共用控制器调用，实际安装分支已实现，但仍因闭包未完成而禁止使用；没有在本机或东京执行 `--apply`。它用于**全新专用 kubeadm 节点**，不负责旧集群原地升级。

安装前检查：完整物料闭包与 SHA、明确的 hostname/machine-id、Linux amd64、Ubuntu 24.04、systemd、cgroup v2、OS 所需命令、swap/ip_forward 状态。发现 WSL、容器、Docker、Harbor 或已有集群状态就拒绝，不自动清残留。其他 OS 需另备明确依赖配置，不把旧 deb 勉强装上去。

安装分支行为：

1. 仅从锁定归档中提取白名单普通文件，内存中的实际解包字节再次核 SHA；不使用解压覆盖整个 `/usr/local`。
2. 所有目标先预检；已有不同字节、权限、归属或软链接拒绝覆盖。新文件独占创建，root 所有，二进制 0755、配置 0644。
3. 将机器身份、输入锁和每个目标 SHA 写入 `/var/lib/sunmoon/bootstrap/<batch>-<phase>.json`；已有日志不匹配拒绝继续。中断保留文件和日志，不做自动卸载/回滚；残留 `.new` 或半文件须在维护时核实，不自动删掉重来。
4. runtime 安装 containerd/ctr/shim、runc、nerdctl、crictl，核版本，再启动 containerd 并检查 CRI RuntimeReady。
5. kubernetes 阶段要求同机器、同清单的 runtime 完成日志，安装三件工具、核版本、只 enable kubelet，等待后续 kubeadm 配置后启动。
6. 没有 apt/curl/wget、容器删除、镜像 prune、卷删除、cluster reset 或旧服务重启。

**仍未完成**：OS/运行时/工具的实机验收；control-plane 镜像按摘要导入及精确名称；kubeadm init/join、共享 Calico；统一平台与独立 Harbor 生命周期。云端第一台机器必须按审查文档的首次上云清单逐项验收。

## 6. 本次检查与下一步

[证据](../../scripts/results/luna-infrastructure-material-consumer.20260927.json) 包含 23 文件校验、配置解析、C1/C2 总控预演、C1 三节点传输预演、两个安装阶段预演与代码摘要。新增/修改的六个 Shell 文件通过 bash -n 和 ShellCheck，四个 Python 文件通过语法解析。没有执行实际安装或新增测试套件；预演不能代替远端验收。

预演首次失败原因：脚本自身默认路径带 `..`，被严格路径检查拒绝。默认入口路径已规范化，外部软链接/路径逃逸仍拒绝，复核通过；没有为了通过而取消完整性检查。

OS 物料及 step01–03 已继续完成代码接线，见 [新节点入口](fresh-node-bootstrap.md)。下一步改 step04–06 镜像/init/join/Calico，统一版本时保留平台原版本。最终清理依然在迁移验收之后，且必须执行批准清单并记录实际释放量。
