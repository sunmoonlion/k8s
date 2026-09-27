# 集群层离线物料

物料总根保持 `~/packages-to-be-installed`，新批次为 `releases/kubeadm-1.36.4-linux-amd64/`。这是新 kubeadm 适配器的输入，**旧 steps 尚未全部接线，不能直接运行旧总控安装新版**。云端安装未经实机验证。

版本与范围真源是 `cluster-artifacts.lock.json`。平台服务版本保持原样；KIND 使用 `kind-infrastructure/isolated/profile.json` 和既有批次。Calico归档在共享批次只保留一份，锁中 `shared_calico_materials` 的路径相对物料总根解析，不能清理其唯一副本。

## 部署方消费入口（2026-09-27）

新增的 `bundle.py` 统一解析和验证精确清单，`sync.py` 默认只打印、显式 apply 才通过严格 SSH 传输并在远端重新校验；`stage_configuration.py` 把锁定的五个节点配置放进离线批次；`os_install.py` / `node_install.py` 提供专用新节点的 OS/运行时/工具安装分支。step01–03 已经由 `node_control.py` 接入，全部默认只打印，真实云安装未经验证，见 [新节点入口](../docs/fresh-node-bootstrap.md)。

现在 128 文件、本地全量 SHA 通过（含两份复用的现有存储镜像，见 [存储适配](../docs/storage-bootstrap.md)）；其中 OS 依赖 94 包及 9 个签名/索引已在东京下载、本机独立验签。step01–10 已完成云端代码接线，见 [集群入口](../docs/cluster-bootstrap.md) 与 [共用资源入口](../docs/post-bootstrap-resources.md)；剩余平台/仓库入口未完成，主锁仍 `closure_complete=false`，总控实际变更被版本/闭包门禁阻止。详细命令、配置来源和未验边界见 [固定物料与节点入口](../docs/locked-node-materials.md)、[OS 依赖准备](../docs/offline-os-materials.md)。

## 下载与回传

同一脚本可在本机或所有者授权的公开物料下载主机运行。脚本默认只打印计划；显式 `--apply` 才下载或拉取/导出镜像，不部署、不启动容器、不清理缓存。远程仅上传公开备料脚本和版本清单，不上传业务源码、kubeconfig、登录凭据或私钥。OS 包使用 `prepare_os.py`，方法见上方专页。

```bash
python3 prepare_public.py --manifest cluster-artifacts.lock.json \
  --root "$HOME/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64"
python3 prepare_images.py --manifest cluster-artifacts.lock.json \
  --root "$HOME/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64"
```

在已授权准备范围内给上述命令加 `--apply`。脚本每次操作前检查磁盘余量：普通操作至少6GiB、镜像pull至少8GiB；不足直接停止，不能自行清理主机。

- 普通文件：HTTPS严格校验、有界超时/重试、`.part`续传、最终SHA-256与锁一致才晋升完整文件。
- 镜像：先解析版本tag→index→linux/amd64 manifest→config摘要；先落锁，再按digest拉取。导出专用别名，核对归档内config摘要，再记录tar文件SHA-256。
- Docker classic image store与containerd image store的image ID语义不同：分别可能是config或manifest摘要。两者不能混为一个校验值；同时保留config_digest、platform_digest、docker_image_id与archive SHA。
- 镜像pull失败保留已拉内容和锁，下次重跑复用固定摘要。未完成导出保留独立`.partial`文件，最终清理时另行复核，不当完整包使用。
- `kubeadm-images.lock.json` 的complete只证明这7个归档完成；主锁 `closure_complete` 还须覆盖OS依赖、systemd单元、CNI/运行时配置、适配器及离线部署验收。

本次已授权东京路径回传（从本机执行）：

```bash
rsync -a --partial --append-verify \
  -e 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10' \
  txy-tokyo:/home/zym/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64/ \
  "$HOME/packages-to-be-installed/releases/kubeadm-1.36.4-linux-amd64/"
```

不加 `--delete`。回传后在本机重新计算所有文件SHA-256并核对锁；rsync成功不能代替完整性验证。正式安装还需要核对导入后目标containerd中的manifest身份并为kubeadm期待的精确名称建立引用，不能只执行docker load便宣称节点可启动。

## 整理与退役

`inventory.py` 仅读物料目录、计算候选摘要、记录代码引用位置，报告写stdout；没有任何删除入口。旧脚本通过通配符或拼接变量选包，字面引用为空不能说明没人在用。

```bash
python3 sunmoonai/infrastructure/materials/inventory.py \
  --root "$HOME/packages-to-be-installed" > /tmp/sunmoon-material-retirement.json
```

执行顺序与容量见 [集群升级物料对应与最终清理](../../kind-infrastructure/docs/cluster-material-retirement.md)。所有者要求最后一起清理且必须清理；新物料未齐、引用未切、迁移未验收时，旧包保留。平台/应用镜像、Harbor冷备、旧集群客户端与受保护节点/卷不属于按版本批量删除范围。
