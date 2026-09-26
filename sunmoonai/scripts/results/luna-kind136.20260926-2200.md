# 独立 KIND 升级 A/B 交付记录

日期：2026-09-26；工位：`~/worktrees/luna/k8s`；分支：`luna`。
实施基线：`bee0b049ca9e84fead641928816fec4a6a1c6c48`（已讨论的升级方案）。
授权：所有者明确选择“按方案推进物料准备和独立建群”，之后提供 `txy-tokyo` 并授权远程下载回传。

## 交付与范围

- A：独立 profile、明确物料清单、文件校验、镜像摘要、离线预检、目标保护、有界重试、远程下载入口。
- B：新建 `sunmoon-kind-136`，Kubernetes 1.36.4 / KIND 0.33.0 / Calico 3.32.2；1 控制平面 + 2 worker，containerd 2.3.4。
- API：`127.0.0.1:16443`；kubeconfig：`~/.kube/sunmoon-kind-136.config`；Pod/Service：`10.245.0.0/16` / `10.97.0.0/16`。
- 旧 `kind`、旧 kubeconfig、业务端口、`/data/kind-local-storage` 保留；新集群不挂载旧数据。
- 没有业务迁移、云端部署、CI/CD 实施、监控/HA 实施或业务 E2E；后续先讨论具体方案。

代码与使用方式：[isolated/README.md](../../kind-infrastructure/isolated/README.md)。
公开物料清单：[artifacts.lock.json](../../kind-infrastructure/isolated/artifacts.lock.json)。

## 物料与网络

物料路径：`/home/zymun/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64`。
最终 manifest SHA256：`e44650c170ca010769233f7bbf642f9dc58dc95826336758edd10391b5729586`。
profile SHA256：`f41fafcdfa692a76c5928a4c8e3ad6f6632f9d6175f5a9d711cc84081c96ebdb`。

本地下载已取得部分物料，随后遇到 TLS 中断。根因未确定，不能将“配置检查通过”写成“公网稳定”。
远程准备公开物料，严格验证 SSH 已知主机；rsync 续传并完整校验后回传。
复用本地 525112212 字节，实际接收 189229694 字节；收据是 `transfer-provenance.json`。
远程仅下载/导出，缓存保留在 `/home/zym/.cache/sunmoon-artifacts/kind-1.36.4-calico-3.32.2-linux-amd64/`，
检查时目录约 682 MiB、磁盘剩余约 11 GiB，Docker 缓存另占空间。

新集群实际节点地址加入本机统一 NO_PROXY，`sunmoon-network check` 返回 `ok=true`、`drift=[]`。
配置源备份：`~/private/network-backups/kind136-source-20260926T215811/`；
原生配置备份：`~/private/network-backups/20260926T215827383935+0800/`。
Docker 守护进程 NO_PROXY 的历史差异仍记录，没有重启 Docker。

家目录网络方案补充远程中转、配置与稳定性区别，以及 CI/CD 不能假设国内云可随时拉公网镜像的约束。
这些 CI/CD 约束是后续设计输入，不代表依赖缓存/内部供应能力全部落地。
所有者进一步明确 Git/npm 尚无内部供应方案；后续调查须涵盖源码副本、包依赖与安装脚本额外下载，确定具体方案后再实施。

## 验证与证据

完成时间：`2026-09-26T22:06:32.206623+08:00`。
最终完整验收：`/home/zymun/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/verification-20260926T220335.json`。
原始命令输出：批次 `logs/`；公开结果副本：`luna-kind136.20260926-2200.verification.json`。

| 条件 | 实际结果 |
| --- | --- |
| 三个节点与版本 | 全部 Ready，v1.36.4 |
| Calico | 三个节点就绪；120 秒内每 15 秒检查，UID 和重启计数不变 |
| DNS、跨节点 Pod/Service | 全部通过 |
| 默认拒绝 | 两个原本能访问的客户端均超时拒绝；不把任意执行错误算成功 |
| 精确放行 | 指定客户端恢复 Pod/Service/DNS；另一客户端继续拒绝 |
| PVC | 写入随机标记，删除 writer 后新 reader 读到同一数据 |
| 旧环境 | 三节点仍 Ready；容器身份、端口、kubeconfig 散列、存储目录设备/inode 与创建前一致 |
| 本地保护回归 | `python3 -m unittest -v test_cluster.py`，11 项通过 |
| 物料完整性 | 全文件 SHA256 通过；没有因失败更换来源或忽略校验 |

验收资源保留在新集群的 `sunmoon-infra-check`。再次完整运行需先核对归属并清理此测试命名空间；
脚本拒绝覆盖已有验收现场。旧业务的数据内容未做全量校验，旧入口未重跑业务 E2E。

## 实施中发现并修复的问题

1. Docker 归档导入 containerd 后名称增加 `docker.io/`；修正别名处理后成功，增加回归测试。
2. VXLAN 后端的生成清单只移除了 BIRD readiness，遗漏 BIRD liveness，导致周期性重启。
   初次 `verification-20260926T215732.json` 虽短时通过，但不足以证明稳定；该记录保留，最终以上述复验为准。
   修复同时移除两种 BIRD 检查，保留 Felix 检查，符合
   [Calico 官方说明](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/config-options)。
   增加渲染回归与 120 秒稳定观察，完整重跑网络策略/PVC/旧环境检查。
3. 旧生成清单、旧 manifest 和校验文件保留在 `revisions/before-vxlan-liveness-fix/`。
   只更新已明确修正的生成配置与其校验值，上游二进制、镜像、清单未变。
   远程下载缓存仍是修正前生成版本；恢复应采用本机最终批次或重新按已提交代码生成并审阅差异。

部署命令使用本地物料；Calico、测试 Pod 和三个系统工作负载使用 `Never`。
控制平面静态 Pod 保留官方 `IfNotPresent`，镜像预装在已锁定的节点镜像内。
本次事件检查未发现 Pulling/镜像拉取失败，未做主机全流量抓包或断公网建群试验；
不能把本次结果扩大为任意未来工作负载均可离线部署。

## 使用与回退

在 `sunmoonai/kind-infrastructure/isolated/` 执行：

```sh
python3 cluster.py validate
python3 cluster.py plan
```

集群已存在，不能重新执行 create 冒充升级；脚本会拒绝覆盖。
继续使用原 kubeconfig 即仍操作原环境。未来删除新集群或切换业务先讨论范围。
单机 KIND/local-path 不提供主机故障高可用，PVC 验证只证明替换 Pod 后数据保留。

后续单元：平台兼容性与迁移方案，再按已确认顺序推进 CI/CD、监控与 HA 设计，业务 E2E 放最后。
