# 独立 Harbor 使用方与入口离线镜像

目标：只有一套平台和应用部署代码，加上 KIND、kubeadm 两种建集群方式。Harbor 在集群外运行，所有集群使用 `harbor.sunmoonai.com:30443`。

**云上未经实机验证。** 本单元完成 step11 的云节点使用方代码、公开 CA 传递、精确入口镜像消费。没有执行 SSH、修改节点配置、导入运行时镜像或调用 Kubernetes API。Harbor 正式生命周期和总控 step11 之前的仓库主机步骤仍待接通；主锁 `closure_complete=false` 保持，不能提前开放总控。此文优先于旧 step11 的操作说明。

## 操作与范围

```bash
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step11_load-initial-images.sh --dry-run
CLUSTER=C2 bash sunmoonai/infrastructure/steps/step11_load-initial-images.sh --dry-run
```

省略参数也只打印，不联系任何主机。首次上云准备完成后：

- `--apply`：所有节点预检通过后，逐节点补齐精确信任文件、hosts 映射和入口镜像，再逐节点复核。
- `--verify`：实际访问节点和仓库，检查现有配置与镜像；缺失或冲突直接失败，不补载镜像、复制补包、改 hosts 或修证书。SSH 管理程序仍会发布公开控制代码、保存 root 私有请求及审计日志，因此不是整台机器零写入。
- 旧 `verify` / `dns` / `cleanup_dns` 等位置参数不再执行；使用上述显式动作。没有自动 DNS 清理或其他回退分支。

总控已给 step11 显式传 `--apply`，但完整安装依然被闭包门禁阻止。该步骤不运行 Docker、不启动/停止 Harbor、不接触仓库数据、数据库、私钥或登录口令。

## 独立仓库主机配置

主配置提供 `REGISTRY_CONFIG_FILE`；可通过 `C1_REGISTRY_CONFIG_FILE`、`C2_REGISTRY_CONFIG_FILE` 或已有 Git 外私有覆盖指定所有者管理的配置。空值仅用 `registry-platform/config/cloud.example.conf` 打印尚未填写的计划。正式执行必须填写：

| 配置 | 意义 |
| --- | --- |
| `REGISTRY_VERSION` / `REGISTRY_ADDRESS` | 固定 2.13.2、harbor.sunmoonai.com:30443 |
| `REGISTRY_TRANSPORT` | 云端 ssh；本地 profile 不得误用 |
| `REGISTRY_SSH_HOST` / `REGISTRY_MACHINE_ID` | 单独登记的仓库主机和 machine-id；后者不得等于任何集群节点 |
| `REGISTRY_PRIVATE_IP` | 节点可直连的独立主机 RFC1918 IPv4；不得回退 master/worker IP |
| `REGISTRY_CA_FILE` / `REGISTRY_CA_SHA256` | 管理机上绝对路径的公开 PEM CA 文件与文件 SHA256；拒绝符号链接和私钥内容 |
| `REGISTRY_LOCAL_SNI_PROXY` | 云端 false；本地入口代理由本地适配负责 |

`registry-platform/lib/config.sh` 只向使用方导出明确的公开字段。CA 通过 SSH 请求传递并在节点再次核 SHA；私钥、Harbor 口令及完整配置不进入请求。TLS 固定规范域名和端口，不能改成 IP SAN 绕过域名检查。

本步骤核对的是**已登记配置**中的独立身份和仓库 TLS 端点，没有 SSH 登录仓库主机验证其实际 machine-id、Harbor 二进制版本或数据盘归属。该职责属于待完成的仓库主机生命周期/就绪步骤；输出明确保留 `registry_host_live_identity_verified=false`。HTTP `/v2/` 也不能证明服务版本就是 2.13.2。

## 实际分支的顺序

1. 管理机先检查完整锁、所有物料 SHA、Kubernetes/Calico 配置、节点 hostname/machine-id、SSH 目标和公开 CA。任一缺项在 SSH 前停止。
2. 通过已有严格 SSH/root 管理入口，核主节点记录的 kube-system UID/CA、全部节点名称、machine-id、InternalIP、Kubernetes 版本和 Ready。远端再次核材料、已安装工具/配置和建群记录。
3. 全部节点先检查信任目录、hosts 映射、现有镜像引用、完整离线 OCI 内容图和直连 TLS。任一冲突阻止进入配置阶段。
4. 仅创建缺失的 `/etc/containerd/certs.d/harbor.sunmoonai.com:30443/ca.crt` 与 `hosts.toml`，root:root、0644；只配置 pull/resolve。既有文件内容/权限不同或有额外文件就停止，不覆盖。高优先级 `harbor.sunmoonai.com_30443_` 目录存在也停止。
5. `/etc/hosts` 按完整域名匹配，不做子串删除；既有地址冲突就停止。缺项才在锁定文件描述符、复核 inode/权限后追加。结束核系统解析结果必须只有已声明的仓库 IP。
6. 只导入本节锁定的 Traefik。以共享 `image_import.import_items` 核图、生成 root 私有导入副本、导入 containerd k8s.io、建立摘要引用；同名不同摘要拒绝。
7. 复核全部节点信任内容、解析、运行时 manifest 内容和 CRI 引用解析。没有服务重启，没有关闭 TLS 校验，没有复制主机 Docker 认证。

TLS 检查直连已配置 IP、SNI/Host 保持规范域名，校验公开 CA、域名和有效期；`GET /v2/` 必须是 401、registry/2.0 和正确的 Bearer token realm。请求不带认证信息、不跟随重定向、不请求 token。返回明确标记 `authentication_or_pull_verified=false`；后续仍必须做认证推拉与 Pod 拉取验收。

containerd 2.3.4 的 certs.d 文件更新无须重启 daemon，目录优先级和 CA 配置依据[该固定版本文档](https://github.com/containerd/containerd/blob/v2.3.4/docs/hosts.md)。本步骤不更改 kubeadm CA 或证书期限；五年 Harbor 叶证书由仓库模块处理。

## 当前入口物料（所有者获准升级后）

step11 当前消费主锁中的 Traefik 3.7.13 官方 amd64 镜像，与 step13 的 chart 41.6.0/CRD/清单一致；容器引用固定为 registry manifest 摘要、pullPolicy 为 Never。下载、摘要及旧包保留安排见 [共用入口](ingress-bootstrap.md)。旧 3.5.2 的检查记录是历史证据，旧包仍保留，不再由新版 step11 导入。仅导入镜像不表示 Pod 就绪或路由验收通过。

存储的两份镜像由 step09 负责；Harbor 及其数据库/缓存启动物料交仓库模块。旧 STEP_IMAGE_*、节点 IP 回退、文件名猜测和模糊匹配逻辑已移除；历史共享配置字段未打印或顺带修改。

## 首次上云核对清单

- 完成仓库主机共用安装/恢复入口及总控前置步骤，实际核独立主机 machine-id、版本、数据盘 UUID、证书和备份；不可仅凭本步骤 HTTP 成功判定。
- [step12证书消费](tls-consumer.md)现已接线；在仓库/KIND 等剩余闭包接线完成后，复核本地/云端各自 profile、节点私网路由和防火墙；云端不复制 WSL 代理/SNI 配置。
- 先保存原信任目录/hosts 与运行时清单，再查看默认计划；运行获准的安装，核全节点 TLS、DNS、CRI 和固定镜像。
- 使用专用凭据验认证推拉与目标 Pod 拉取，核 imagePullSecret、凭据隔离和 CI/CD；本步骤不写管理员口令到 containerd。
- 验证集群删除/重建不改变独立 Harbor 数据与生命周期；本地还要验 30443 域名分流和入口维护窗口。
- 中断后已写内容必须与精确输入相同才可续行；不自动撤销/删除文件或镜像，不把部分节点成功当全部完成。冲突保留现场，回退按备份逐项处理。

## step11 初次接线的历史检查与余项

证据：`sunmoonai/scripts/results/luna-registry-consumer.20260927.json`。5 个 Python AST 及远端 payload、5 个 Shell 文件的 bash -n/ShellCheck、主配置 bash -n、C1/C2 的 step01–11 共22组只打印计划通过；129 文件、1,236,303,984 字节 SHA 全通过，Traefik 的6个 OCI blob 全核对。没有新增/运行测试套件。

C-R1：代码与锁共同交付；C-R2：离线工作负载目标按摘要锁定；C-I8：配置/身份/信任冲突拒绝继续；C-D1：仓库数据不由集群步骤接管。仓库正式启停、五年叶证书、入口代理、CI/CD、备份恢复、KIND 适配与重建验收仍未完成。最终清理保留到迁移验收后且必须做，本轮释放空间为零。
