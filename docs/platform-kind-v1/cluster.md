# 新 KIND 集群：部署与验收

本页描述新体系的原生入口，不调用旧 luna、sunmoonai/infrastructure 或 kind-infrastructure 程序。

## 当前配置

所有者于 2026-10-01 指定名称 `sunmoon-kind`。站点真源为 `platform/environments/kind/site.yaml`；镜像和工具版本来自 artifacts 锁文件，站点不能覆盖镜像。

| 项目 | 值 |
| --- | --- |
| Kubernetes / KIND / Calico | 1.36.5 / 0.33.0 / 3.32.2 |
| 节点 | 1 控制面 + 2 worker |
| API / 待用入口后端 | 127.0.0.1:27443 / 127.0.0.1:29443 → 控制面 30443 |
| Pod / Service 网段 | 10.247.0.0/16 / 10.99.0.0/16 |
| kubeconfig / context | `~/.kube/sunmoon-kind.config` / `kind-sunmoon-kind` |
| 数据根目录 | `/data/kind-clusters/sunmoon-kind`，230 GiB 数据盘 |
| 节点静态目录 | `<role>/static` → `/data/kind-local-storage` |
| 节点动态目录 | `<role>/dynamic` → `/var/local-path-provisioner` |
| 本次 kube-system UID | `67d27d4a-f9ad-4f01-a37f-225144cacaef`；重建后必须重新记录 |

`role` 为 control-plane、worker、worker2，每个节点两条独立挂载。原 `sunmoon-kind-main` 已于 2026-10-01 按所有者决定退役。原 `kind` 和 `sunmoon-kind-136` 仍保护；原 kind-control-plane 保持停止。当前应用 SNI 仍到旧 worker，29443 尚无新 Traefik 服务，不表示业务入口已迁移。

## 日常操作

```bash
cd /home/zymun/worktrees/platform-kind-v1/k8s/platform
make cluster-plan        # 只读计划、同名集群身份和配置核对
make cluster-deploy      # 首次建群，或继续同一集群的 CNI/信任/DNS 配置
make cluster-status      # 节点、版本和基础工作负载状态
make cluster-pull-check  # 三节点真实私有拉取、运行及 DNS 验收

export KUBECONFIG="$HOME/.kube/sunmoon-kind.config"
./.tools/bin/kubectl get nodes
./.tools/bin/kubectl get pods -A
```

需要本机 Docker 权限和 Ansible sudo 权限。入口显式指定 kubeconfig/context，不修改默认 kubeconfig。这里只交付建群单元；整套平台一键和统一启停仍待后续实现。

## 原生部署链与保护条件

1. 校验三挂载 UUID/根目录、工具与归档 SHA256、锁定本地节点镜像；拒绝不安全路径。
2. 新建时检查 Windows 容量（包含数据盘长满、50 GiB 底线及额外 5 GiB 建群预算）、Docker 看到的实际数据根目录、端口和 kubeconfig 路径。
3. 渲染 KIND v1alpha4 配置，以官方 `kind create cluster` 和本地节点镜像创建。采用 `--retain`，失败留下节点供诊断，不自动删除。
4. 记录节点容器 ID、配置摘要及 kube-system UID；已有同名但无回执的集群、身份变化、配置变化或集群已删而回执仍在，均拒绝自动接管。创建失败在回执生成前的残留需要明确核对后处理，不能反复删除重试。
5. CNI 归档以官方 containerd `ctr images import --digests --base-name <完整仓库名>` 流式导入，逐一核对 manifest/config 身份。完整仓库名不可省略。
6. Calico 官方清单由原生 Kustomize 固定摘要、设置 VXLAN 和 Pod CIDR；由 Ansible 的 `sunmoon-bootstrap` field manager 所有，Flux 不再管理同一 CNI。先 diff，无差异不 apply。
7. 节点只挂公共 CA；containerd hosts.toml 不含口令、不跳过 TLS 校验。节点 hosts 和 CoreDNS hosts 记录使同一 Harbor 域名指向实测 Docker 网络网关，Pod 的拉取身份通过 namespace Secret 提供。
8. 实际核对每个节点静态/动态目录的 bind source 和宿主/容器内 device+inode；等待全部节点和基础工作负载就绪，结束再核容量。

参考：[KIND 挂载/网络配置](https://kind.sigs.k8s.io/docs/user/configuration/)、[KIND 仓库配置](https://kind.sigs.k8s.io/docs/user/local-registry/)、[Calico KIND 安装](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind)、[containerd 官方导入参数](https://github.com/containerd/containerd/blob/v2.3.4/cmd/ctr/commands/images/import.go)。

## 2026-10-01 实测

- 三节点均 Ready/v1.36.5，14 个基础 Pod 全部 Running、Ready，Calico VXLAN 可用。宿主与三节点各两条数据挂载身份一致。
- 最终重复 `cluster-deploy`：**ok80 changed0 failed0**；没有重建节点或重复改写 CNI。
- `cluster-pull-check`：**ok32 changed6 failed0**。临时 namespace 使用 restricted Pod 安全配置，三节点分别运行非 root Job，`imagePullPolicy: Always`，只读机器人 Secret，不给容器 Kubernetes API token。
- 镜像 `harbor.sunmoonai.com:30443/platform/haproxy@sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`；三个实际容器 imageID 与此一致，命令输出 HAProxy 3.4.6。三节点 Pod 都解析 Harbor 为 172.18.0.1、kubernetes.default 为 10.99.0.1。
- 初次验收三个新节点无该镜像，实际拉取及容器启动成功，但 DNS 步骤失败。修正后再次验收使用已有层缓存，Always 仍验证仓库认证；不能把第二次说成完全无缓存。失败 Job 和成功 Job 的临时 namespace/Secret 均已删除。
- 成功回执 `/data/kind-clusters/sunmoon-kind/bootstrap/bootstrap-pull-rhc28.json`，最终状态同名前缀 `-final.json`；节点/Pod/旧集群/Harbor记录 `verification-20261001.json`。运行日志另存 bootstrap/evidence，均不含凭据。
- 新 Harbor 10 服务 healthy；`sunmoon-kind-main` 随后按所有者决定删除。`sunmoon-kind-136` 和旧 `kind` 启停状态保持。

### 实际遇到的问题

最初使用 KIND 的通用 OCI 导入，归档未带仓库名，产生 `import-日期@digest` 引用。即使补上正确引用，containerd CRI 仍选择已规范化但不存在的匿名引用，Calico 初始化报 `failed to check if this is a checkpoint image ... not found`。正式代码改成显式 `--base-name` 导入；本次仅核对并移除新节点的错误别名、重新导入后刷新新节点 containerd 索引，保留镜像内容及正确引用。没有重启宿主 Docker或旧节点。

CoreDNS 首次生成把换行写成字面 `\n`，reload 拒绝新配置；改用 YAML 多行变量后 DNS 实测通过。另有计划阶段锁字段引用、网关模板转义错误，已修正。失败日志保留，不将中间失败写成一次成功。

## 当前限制与下一步

- **尚未做新集群删除重建**。本次节点从空白创建后做过上述修复，已验证最终部署入口重复执行；修正后的全新冷建路径仍须在后续重建验收中证明。
- 挂载比对不替代持久化验收：WSL/KIND 重启、KIND 删除重建后的 Harbor 全目录摘要、仓库清单摘要和新节点拉取仍在队列。
- Flux 引导、平台及应用部署、一键总控、统一启停、开机顺序、长期空间管理及云端实机均未完成。
- 11:50 UTC 容量：C 空闲 122,000,154,624 字节；扣数据盘未来增长后余 55,029,702,656 字节（约51.25 GiB），仅比50 GiB底线多约1.25 GiB。下一阶段需重新预算，不能把本次容量通过视为整套平台都能部署。
- 仅验证 HAProxy 镜像可运行/可拉取，不等于已关闭前序扫描发现的安全问题；继续执行官方修复评估，不自制系统包补丁镜像。

## 规则对照

| 范围 | 对照 |
| --- | --- |
| 发布 C-R1/C-R2 | 源码、镜像锁、KIND 配置摘要与集群 UID 记录；Calico/验收镜像用 digest |
| 身份 C-I8 | 所有权、错误目标、证书、认证、目录和容量不符即失败 |
| 拓扑 C-T5/C-T6 | 仅新五仓工作树的 k8s 仓改动，提交 SHA 交回，不推送 |
