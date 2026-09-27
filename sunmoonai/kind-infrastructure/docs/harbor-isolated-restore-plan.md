# Harbor 隔离恢复：首轮数据与镜像拉取验证

日期：2026-09-26。状态：所有者答复“按方案实施”后，本轮数据恢复与镜像读取验证已通过，临时副本已停止，数据保留。jobservice/完整后台能力及业务入口切换仍未实施。

## 1. 本轮要完成什么

从已校验冷备份恢复独立副本，证明数据库、镜像内容和访问凭据可以一起恢复，并由新 KIND 节点实际拉取镜像。旧 Harbor 继续正常服务。

首次恢复保持 Harbor 2.13.2 / PostgreSQL 17.6.0 / Redis 8.2.1 与原数据版本一致。本轮不借恢复升级 Harbor，也不切换业务入口。恢复后再评估长期版本和部署方式。

源数据：`~/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z/`。原始六份归档保持不变；配置变换和运行期写入只发生在独立副本。

## 2. 可审阅的实际交付

- 生成入口：`sunmoonai/cicd-platform/materials/harbor_restore_plan.py`，只读取备份并生成文件，不连接 Kubernetes API、不部署。
- 私有清单：`~/packages-to-be-installed/releases/harbor-preserve-20260926/restore-plan-20260926/manifests-private.json`，0700 目录、0600 文件，包含必要 Secret，不能入 Git。
- 清单 SHA256：`3aef6e503b50786915931ab7b70da819de7f428bdee09a686e71ab44d17f0239`。
- [脱敏资源与镜像摘要清单](../../scripts/results/luna-harbor-restore-plan.20260926.json)：59 个资源、8 个固定 Linux amd64 镜像；包含 6 个 PV、6 个 PVC、7 个 Harbor 控制器、1 个临时 TLS 网关。
- 所有控制器初始为 **0 副本**。应用清单不会立即启动空库或写入数据，数据归档导入完成后才按顺序启动。
- 已检查：六处存储与归档一一对应；明文配置和解码后的 Secret 字段没有旧 namespace、旧云端 IP、旧 registry 入口残留；镜像全部固定到 amd64 manifest digest，`imagePullPolicy: Never`。
- 已完成 API 服务端 dry-run、六卷恢复、运行与读取验证。下文第 7 节记录现场修正；原私有清单保持原摘要，修正另存证据。

## 3. 明确的目标和增量

| 项目 | 本次值 |
| --- | --- |
| kubeconfig | `~/.kube/sunmoon-kind-136.config`，API `127.0.0.1:16443` |
| namespace | `harbor-restore-20260926` |
| Harbor 与数据节点 | `sunmoon-kind-136-worker`（当前 `172.18.0.5`） |
| 六处独立数据目录 | 节点 `/var/local-path-provisioner/harbor-restore-20260926/{registry,database,redis,jobservice,trivy,trivy-active}` |
| PV 名称 | `harbor-restore-20260926-<上述目录名>`，Retain，精确绑定新 namespace 中的 PVC |
| 临时 registry 名称 | `harbor-restore.sunmoonai.com:18443` |
| TLS Service | `restore-gateway`，ClusterIP `10.97.60.20:18443` → 容器 `8443`；实施前复核地址未占用 |
| WSL 临时访问 | `kubectl port-forward --address 127.0.0.1`，仅监听 `127.0.0.1:18443` |
| 实际拉取验证节点 | `sunmoon-kind-136-worker2`（当前 `172.18.0.6`） |
| 增量预算 | 不超过 30 GiB，开始前至少 100 GiB 可用；内存限制总量约 8 GiB 以内（以实际渲染请求/限制复核） |

新节点的 `/var` 是新 KIND 自己的 Docker volume；不挂载旧 `/data/kind-local-storage/harbor`。六个 PV 只允许调度到指定新节点，避免 hostPath 在另一个节点出现空目录。使用 `hostPath.type: Directory`，必须先恢复真实目录。

这是一份本机恢复演练副本，不能因 KIND 有多个节点就声称跨主机高可用。

## 4. 需要处理的现场问题

### 4.1 旧云端地址与任务

原 core/jobservice 的 hostAliases 把 Harbor 域名指向 `101.126.151.0`。渲染时已删除。内部服务使用新 namespace 内的 Service，外部入口改为上述新域名和端口；代理变量清空。

原 Harbor 有两条启用的**手动**复制策略和两个定时任务（SYSTEM_ARTIFACT_CLEANUP、EXECUTION_SWEEP）。首轮保持 **jobservice 0 副本**，不启动复制、清理、扫描等作业；数据库中的原策略留作恢复证据，不修改备份。registry 上传目录自动清理关闭，Trivy 禁止联网更新数据库。

这是明确的验证范围：完成数据恢复和镜像读取链路，jobservice 作业执行及在线扫描不在首轮运行验收内。Harbor 综合 health 可能因 jobservice 暂停而非 healthy，不能用忽略该状态的方法宣称全套 Harbor 已恢复。后续在恢复副本里明确暂停调度/队列的机制后，再单独验证全部后台能力。

### 4.2 元数据补齐

原资源选择器遗漏动态 Trivy PVC/PV（其 instance 标签与主 release 不同）。**Trivy 数据已在六份冷备份内，且通过校验。**本轮补读同名、同 PV 绑定的元数据，保存于 `preparation/private/storage-addendum.json`，另有 SHA256 与补读原因；生成清单已纳入。

`harbor_prepare.py` 已修正为沿实际 Pod 的 PVC 引用补全存储依赖；该修正尚未重跑整轮冷备份，不能改写原备份时点的事实。

### 4.3 TLS 与节点拉取

备份证书 SAN 包含 `*.sunmoonai.com`、localhost 和 127.0.0.1，覆盖临时域名；有效期至 2027-06-22。沿用已备份的证书和 CA，不关闭 TLS 校验。临时网关复用已归档 portal 镜像内的 nginx，不增加公网下载依赖。

仅在新节点 `sunmoon-kind-136-worker2` 增加临时域名到 `10.97.60.20` 的解析，以及该 `host:18443` 对应的 containerd CA 配置；事先保存原文件与校验值。不修改 WSL 全局 hosts、Docker daemon、旧节点或旧 registry 域名的解析。凭据通过新 namespace 内限定到临时 registry 的 imagePullSecret 提供，不放在命令行。

**有效配置核对发现，该新节点的 `io.containerd.cri.v1.images.registry.config_path` 为空。**仅写 CA 文件不足以保证 CRI 使用它。本单元还包括：在该节点把 registry config_path 显式设为 `/etc/containerd/certs.d`，保留其余有效配置；用 `containerd --config <候选文件> config dump` 检查实际值和解析结果，通过后替换并仅重启该节点 containerd。原磁盘配置是 version 2，有效配置迁移为 version 4，必须基于实际解析结果生成候选，不能混用旧插件字段。结束时恢复原配置并再次重启该节点 containerd，核对节点 Ready/CNI 正常。影响限于新验证节点的容器运行时，可能短暂 NotReady；旧集群、WSL/Docker daemon 和另两个新节点不重启。

选用现有 `k8s-images/node@sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc` 做实际拉取验证；已只读确认 worker2 当前无此摘要缓存。验证 Pod 使用新 registry 名称、固定 digest 和 `imagePullPolicy: Always`，从 worker2 跨节点拉取。实施时再次核对缓存与镜像来源，不把预先导入业务镜像当作拉取验证。

## 5. 已批准的实施顺序

1. 复核备份全文件摘要、六份归档、TLS/存储补充清单和 8 个启动镜像，确认新 namespace/PV/目录不存在、新节点身份与磁盘空间符合方案。目标冲突则停止，不覆盖现有资源。
2. 保存旧 Harbor healthy/read_only/目录基线作为旁证；只读访问旧环境，不暂停它。
3. 创建新 namespace 和隔离策略，对私有资源做服务端 dry-run；将 8 个启动镜像导入指定新节点，核对 CRI 可按固定摘要定位。禁止临时从旧 Harbor 或公网补拉自举镜像。
4. 将六份归档安全解包到新节点独立目录，保留数值 UID/GID、权限、链接和扩展属性；校验路径不逃逸，确认 PostgreSQL PG_VERSION=17、registry 存在实际 blob。目标只允许空目录，失败保留现场，不覆盖源备份。
5. 应用 0 副本清单；先启动 PostgreSQL/Redis，再 registry/core/portal/Trivy 和临时 TLS 网关。jobservice 保持 0。新库恢复原快照中的 read_only=true，先确认这一状态再开放验证访问。
6. 通过仅绑定回环的 port-forward 验证 TLS、认证和完整目录；对比所有项目/仓库、tag/digest、子清单和附件。API 请求使用原认证输入，目标只允许本机临时端口，不泄露凭据或重写全局登录配置。
7. 按第 4.3 节完成 worker2 的真实镜像拉取与容器启动；记录镜像摘要、Pod 事件和来源。验证持久化及网络拒绝：从副本 Pod 到旧 Harbor/旧云端地址的访问应失败，内部服务正常；旧 Harbor 从 WSL 仍可正常访问，避免把目标本身不可达当成策略通过。
8. 留下恢复结果与证据；完成后停止临时 port-forward，删除本轮精确名称的临时验证 Pod（仅临时 Pod），将副本工作负载停到 0，数据、PV/PVC 与备份保留。恢复 worker2 临时域名/信任与 containerd 原配置，按上述方式重启其 containerd；只删除本轮新增且校验未变化的配置项，不做全局清理。

## 6. 网络边界与失败处置

生成两条新 NetworkPolicy，**不复用原来允许出站的策略**（策略放行会叠加）：命名空间内通信、到 CoreDNS 的 TCP/UDP 53；临时网关额外只接受新集群三个节点地址的 8443 流量。验证容器不使用 hostNetwork/hostPID，应用不挂 Kubernetes API token。策略对实际 CNI/节点路径的约束仍要用负例验证，不仅检查 YAML。

初次恢复预计新增约 18–22 GiB；上限 30 GiB，单轮实施/排障上限 60 分钟。失败时先停止新副本工作负载并保留数据、日志和生成清单；如新实例曾启动，停止后的目录只标记为本次恢复现场，不拿它冒充原始冷备份。旧 Harbor 保持服务。不得因此清空旧卷、重建集群或放宽 TLS/网络隔离。

规则对应：C-D1 保留旧 Harbor 为当前权威来源，副本只读；C-D3/存储隔离使用独立 namespace/PV/路径；C-R1/R2 固定备份与镜像摘要并记录证据；C-T8 临时网关只做 TLS/转发。业务 E2E 仍在整个建设最后。

技术依据：[Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)、[containerd registry hosts 配置](https://github.com/containerd/containerd/blob/main/docs/hosts.md)、[nginx 代理模块](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)。这些说明用于方案选择；运行结论以第 7 节实测证据为准。

## 7. 实际结果与复现要点

本轮于 2026-09-26 15:25 UTC 开始；最终读取验证及节点回滚完成于 15:44 UTC。随后单独核对网关来源解析的幂等处理，15:53:33 UTC 完成最终复核，约 28 分钟，小于 60 分钟窗口。容量保守上界 23.31 GiB（包含两个节点原有全部 containerd 数据），小于 30 GiB；磁盘剩余 500.87 GiB。运行入口是 `harbor_restore.py` 与 `harbor_restore_verify.py`，完整私有记录保存在同批次 `restore-run-20260926/`。

- 全文件 SHA256、服务端准入、8 个固定摘要自举镜像、6 个独立数据卷恢复均通过；镜像导入与解包不依赖公网或旧 registry。
- 恢复 API 使用原凭据与有效 TLS；`read_only=true`。3 项目、64 仓库、165 顶层制品、429 含子清单记录、164 tags，以及逐制品元数据/附件与冷备份一致。含子清单后的无标签记录为 292；此前的 28 是顶层无标签数量，两者口径不同。
- worker2 在目标摘要未缓存的情况下，经新临时域名、CA 和 imagePullSecret 实际拉取 57,641,907 字节的镜像并启动 Node `v24.18.0`。事件保留首次超时和后续成功，不能只报成功事件掩盖排障。
- 内部 core:80 可达；验证 Pod 到旧 Harbor `172.18.0.2:30443` 超时，WSL 对同一地址的正向连接成功。到旧云地址的连接也超时，但没有证明该云端当时在线，不能单靠此项认定隔离有效。
- registry Pod 重建后再次完整目录比对通过，且实际镜像 manifest 字节 SHA256 和响应 digest 一致。
- 最终新 namespace 无 Pod，8 个控制器为 0，6 PVC 均 Bound、PV 均 Retain；临时 port-forward 已关闭。worker2 原 config.toml、hosts 散列恢复一致，临时 CA/候选配置目录项已撤回，containerd/CNI 正常，三节点 Ready。旧 Harbor 7 控制器仍 1/1、healthy、read_only=false，完整目录保持一致。

三处现场修正已记录：

1. 新节点没有 `/etc/containerd/certs.d` 父目录。必须记录并创建本轮新增目录，回滚时只删除这些空目录；中途失败时应允许临时文件已不存在。首次失败发生在替换节点原配置之前。
2. manifest 请求只声明接受索引会得到 `MANIFEST_UNKNOWN`，旧 Harbor 对照也能复现。请求须同时接受 OCI/Docker 的单镜像 manifest 与多平台 index/list；没有改镜像数据或关闭 TLS。
3. **节点 Docker IP 不等于网关实际观察到的源 IP。**worker2 经 Service/VXLAN 路由使用 `10.245.175.64`，`ip route get` 和 conntrack 都证实该来源。原策略增加仅此 `/32` 到网关 TCP 8443 的允许项；未放行 Pod 网段。原清单不覆盖，修正保存在 `gateway-vxlan-patch.json`。验证脚本现从真实路由和节点接口取来源，检查网关选择器/端口后精确补充；该解析及已存在规则的幂等路径另行运行通过。未来重建必须重新取地址。

实际命令顺序（本次记录，**不要在已有批次上重新执行 prepare**）：

```sh
cd ~/worktrees/luna/k8s/sunmoonai/cicd-platform/materials
python3 harbor_restore.py prepare
python3 harbor_restore.py start
python3 harbor_restore_verify.py
```

失败会停止副本并保留现场，读取 `state.json`、`trust.json`、`acceptance*.json` 再决定继续步骤；断电/强制终止恢复方法见本目录对应的 [脚本说明](../../cicd-platform/materials/README.md)。已成功拉取后缓存存在，不能再次声称执行了同一“无缓存”检查。

正式证据：[脱敏结果](../../scripts/results/luna-harbor-isolated-restore.20260926.json)，含原始记录 SHA256、最终状态和容量统计。该结果证明本轮只读恢复链路；没有完成后台任务/扫描、可移植 OCI 导出、独立介质灾备、业务迁移或 CI/CD，旧 Harbor 继续保留。
