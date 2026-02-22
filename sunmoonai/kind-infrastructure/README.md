# Kind / 现成集群平台初始化

**要用 Kind，只需记住一条**：先 WSL 上跑一次 NFS 安装，之后每次跑 **`kind-up.sh`** 即可（创建集群 + 命名空间 + NFS）。配置与 k8s-admin.conf、deploy-infrastructure-all 同源，详见《kind使用指南.md》第 5.7 节。

## 使用步骤

**1. 一次性：在 WSL 上安装 NFS 服务**

```bash
cd k8s/sunmoonai/kind-infrastructure
./wsl-setup-nfs-server.sh
```

**2. 每次要用 Kind 时（含首次、或关机/重启后）**

```bash
cd k8s/sunmoonai/kind-infrastructure
./kind-up.sh
```

脚本会：创建 Kind 集群（已存在则跳过）→ 设置 KUBECONFIG → 执行命名空间 + NFS 存储初始化。执行完后本终端可直接部署应用；新开终端请先运行连接管理器或 `export KUBECONFIG=~/.kube/kind-config`。

---

## 脚本说明（供查阅，无需单独执行）

| 脚本 | 说明 |
|------|------|
| **`kind-up.sh`** | **唯一入口**：创建集群 + 命名空间 + NFS。 |
| `apply-namespaces-existing-cluster.sh` | 被 kind-up.sh 调用。对现成集群按配置创建命名空间（与 Step07 同源：deploy-infrastructure-all.conf 中的环境 × 平台，如 app-platform-dev、data-platform-dev 等），已有则跳过。 |
| `apply-nfs-existing-cluster.sh` | 被 kind-up.sh 调用；需 WSL 上已跑过 wsl-setup-nfs-server.sh。 |
| `wsl-setup-nfs-server.sh` | 在 WSL 中安装 nfs-kernel-server 并导出 `/data/kind-nfs`（一次性）。 |

Worker 数量与端口映射：见 `kind-cluster.yaml`（默认 2 workers；Traefik 等 NodePort 通过 extraPortMappings 暴露）。需自定义时改 kind-cluster.yaml 后跑 `kind-up.sh`。
