# 独立 KIND 验证入口

对应 [已讨论的升级方案](../docs/kubernetes-upgrade-plan.md)。仅操作
`sunmoon-kind-136`，不调用旧的自动重建入口。当前目标是 Kubernetes 1.36.4、
KIND 0.33.0、Calico 3.32.2（VXLAN，保留 iptables kube-proxy）。

依赖 Python 3.10+、PyYAML、Docker（`save/load --platform`）、buildx、curl。
已在本机检查到这些依赖；不自动安装系统软件。

## 准备物料

在本目录执行：

```sh
sunmoon-network run -- python3 cluster.py prepare
python3 cluster.py validate
python3 cluster.py plan
```

`profile.json` 固定目标和文件校验值。`prepare` 从公开来源解析架构清单摘要并立即
保存到 `preparation.json`，后续重试不重新选 tag。每个联网命令最多 3 次尝试；
失败保留日志与已经校验的文件，明确返回非零。

完整批次位于 profile 中的 `artifacts` 路径；`manifest.lock.json` 只有在所有
物料齐全、生成配置完成后才写入。文件校验、镜像 registry 摘要、镜像架构和
归档文件校验分别记录。离线阶段使用独立本地镜像别名，并在创建前核对实际镜像
身份；Calico 和验收 Pod 使用原 registry 的架构摘要与 `imagePullPolicy: Never`。

更换 profile 需使用新的物料批次。不能只改校验值来接受损坏文件。网络规则参照
`/home/zymun/网络管理统一方案.md`，不要在脚本中写死 Windows 代理。

## 经远程主机中转

所有者本次授权 `txy-tokyo` 作为公开物料下载中转。该主机不是新集群的部署目标。
只向其独立目录传输 `cluster.py`、`remote_prepare.py`、`profile.json` 和公开的
`artifacts.lock.json`（首次准备时尚无锁文件）；不传 SSH
私钥、kubeconfig、Harbor 凭据或应用配置。

```sh
# 在远程的独立 code 目录执行；--artifacts 必须位于远程用户的专用缓存下。
python3 remote_prepare.py --artifacts \
  ~/.cache/sunmoon-artifacts/kind-1.36.4-calico-3.32.2-linux-amd64/artifacts
```

远程仅下载、Docker 拉取和导出，不创建 Kubernetes 集群。拉取前要求至少 8 GiB
可用磁盘，其余操作前至少 6 GiB；这是操作前余量检查，不是硬配额。下载失败或空间
不足时停止，不清理远程既有镜像、容器或服务。

回传采用校验已知主机密钥的 SSH 和 `rsync --partial --append-verify`，先接收至
本机独立目录。再用同一 profile 执行 `cluster.py --artifacts <接收目录> validate`，
核对与本地已锁定镜像摘要一致，最后才接入本地批次。不能用“传输结束”代替完整性检查。
远程副本作为缓存保留；回收空间时只处理本批次明确列出的文件或镜像，不做全局 prune。

## 创建与安装

以下命令已被本次所有者的 A/B 范围授权，但以后重建、清理和业务切换仍须按对应范围执行。

```sh
python3 cluster.py create
python3 cluster.py install-cni
python3 verify.py
```

- `create` 先检查全部物料、名称、kubeconfig、回环端口、路由、内存和磁盘；同名
  集群或目标 kubeconfig 已存在就停止。没有 delete/recreate 命令。
- kubeconfig 始终显式指定，初期不发布业务端口，不挂载旧数据路径。
- 关闭默认 CNI 后，安装 Calico 前节点 NotReady 属于正常安装阶段。失败保留现场。
- `install-cni` 只操作拥有指定 KIND 标签的三个目标节点，离线导入镜像并校验 CRI
  可见性，再应用本批次 Calico 清单。重复执行可以修复未完成安装，不会删建集群。
- `verify.py` 在 `sunmoon-infra-check` 中验证 DNS、跨节点 HTTP、NetworkPolicy
  正反例和 PVC 在替换测试 Pod 后保留数据。它会为新集群 local-path 的 helper Pod
  设置已导入镜像并重启该 provisioner；不操作旧集群的 provisioner。
- 测试命名空间已存在时拒绝重新开始，保留失败现场供检查。测试资源只在新集群；
  local-path 的持久性不代表节点故障高可用。

原始命令结果位于批次 `logs/`，结构化验收结果是 `verification-*.json`。
日志不采集 Secret、原始 kubeconfig 或业务环境变量。成功不代表业务迁移已完成。

## 本地保护检查

```sh
python3 -m unittest -v test_cluster.py
```

这些检查不访问 Docker 或 Kubernetes；覆盖离线验证不联网、文件缺失/损坏、
profile 漂移、目录逃逸、旧环境目标保护、已有 kubeconfig 和代理环境隔离。

## 本次发现的兼容细节

- Docker 归档导入 containerd 后，本地镜像别名会规范化为
  `docker.io/sunmoon-offline/...`；随后从这个名称添加已锁定的 registry 摘要引用。
- VXLAN 后端不启动 BIRD，必须同时移除 BIRD 的 readiness 和 liveness 检查，保留
  Felix 的两种检查。只改 readiness 会出现“短时 Ready，但周期性重启”。参照
  [Calico 官方配置说明](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/config-options)。
- 验收增加了 120 秒观察，每 15 秒检查三个 Calico Pod，要求始终 Ready、Pod UID 和
  重启计数不变，然后再做网络与存储检查。这是有限时间验收，不代表长期稳定性保证。
- 上述两点和已验收镜像摘要复用都有本地回归检查，当前共 11 项。

仓库中的 `artifacts.lock.json` 是本次最终批次清单的公开副本。恢复本批次优先复制
完整缓存并按该清单核对。`prepare` 检测到与 profile 相符的这份锁文件时，使用其中
全部镜像的 index digest，避免同版本标签重新解析而漂移。没有已验收锁文件的新
profile 会解析一次并立即保存摘要。Docker 重新导出的 tar 字节也可能不同，应保留
已验收归档；归档散列和 registry 镜像摘要分别核对。
