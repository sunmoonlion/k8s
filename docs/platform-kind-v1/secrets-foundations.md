# SOPS 与基础平台声明

本单元目标为 `sunmoon-kind`。沿用 Make/Ansible 引导、Flux 协调 Git 声明的职责划分；不用旧部署链。平台服务及应用在后续单元部署。本次增加的工具、声明和验收预算上限256MiB，所有者只为本单元批准临时40GiB容量门槛，站点默认仍为50GiB。

## 身份与恢复

| 内容 | 唯一位置/恢复来源 |
| --- | --- |
| SOPS/age工具和摘要 | `infrastructure/artifacts/files.lock.json`，原始物料在正式 `releases/platform-kind-v1` |
| 主解密身份 | `/etc/sunmoon/flux/sunmoon-kind/age.agekey`，root0600，目录0700 |
| 独立恢复副本 | `/mnt/sunmoon-data/backups/flux/sunmoon-kind/age.agekey`，同样限制权限；不在KIND目录或卷中 |
| 公钥 | `infrastructure/environments/kind/sops-recipient.txt`；Git保存公钥和 `.sops.yaml` 加密规则 |
| 集群引导身份 | `flux-system/sops-age`，只由Ansible引导，不放进它自己解密的声明 |
| 平台拉取凭据 | `gitops/clusters/kind/registry-puller.sops.yaml`，只有data字段密文，由Flux解密创建 |

准备入口复核工具摘要、存储挂载、目录类型及密钥权限；已有身份不会重建，两个副本不同立即失败。主文件缺失而备份存在时复制恢复，随后必须匹配Git公钥；两个副本都丢失且Git已有公钥时拒绝生成新身份。不得把重新生成密钥当作恢复。

恢复副本实际用于解密，并与原只读Harbor身份比较。它与WSL系统盘仍在同一物理C盘，不能防硬件故障；机器外备份落点尚待所有者决定。转移整个受限身份目录到批准的加密备份目的地即可接入，尚无自动外传任务。不要把私钥贴入聊天、Git、CI日志或公开制品。

## 日常入口

在新工作树 `k8s/infrastructure` 执行：

```bash
make install-secrets-tools   # 本地锁定物料，不联网选版
make secrets-prepare         # 生成/复用或从已有副本恢复；输出密文候选，不晋级
make secrets-status          # 只读核对主副本、Git公钥和集群身份
make foundations-bootstrap  # 安装工具、恢复/核对身份、注入并协调已晋级声明
make foundations-check      # 实际解密/拉取/DNS/隔离验收，结束删除专属临时Job
```

首次环境准备后，把 `.build/flux/sops-recipient.txt` 提升为站点公钥，把 `.build/flux/platform-puller.sops.yaml` 提升为声明目录中的密文；同步 `gitops/.sops.yaml` 中的公钥。提交后按既有 `flux-release` → 审核并提升候选摘要 → `flux-source-apply` 发布。日常重新部署只应用已经提交和晋级的版本，不自动轮换身份或发布未提交内容。

`make flux-bootstrap` 也编排了SOPS工具与身份步骤。`sops_enabled` 保留配置开关；关闭时不注入身份，源指针记录requires_sops，关闭SOPS时会在改集群前拒绝该加密源。禁用是拒绝新操作的配置边界，不自动删除既有Secret或数据。

`foundations-bootstrap` 是当前已实现的基础层入口，不是整套应用的一键部署。全平台入口、自动启停和开机恢复仍待后续单元完成。

## 声明与验收边界

- platform-system 采用 restricted Pod Security，策略版本固定v1.36。
- default与platform-runtime服务账号不自动挂API令牌；platform-runtime引用只读拉取Secret。
- LimitRange提供请求和限制默认值；后续每个组件仍应显式给出自己的容量需求。
- NetworkPolicy默认拒绝进出，只放行到集群CoreDNS的TCP/UDP53。后续服务需要显式增加必要访问规则，不先放开全部流量。
- Secret发布前，渲染结果必须具有SOPS元数据且data/stringData字段均为密文；私钥由受限宿主文件注入。运行时明文只存在进程内存和Kubernetes Secret，尚不能宣称etcd静态加密或完整租户隔离已实现。
- 验收从独立备份解密Git密文，并比较实际由kustomize-controller管理的Secret。临时非root Job只使用platform-runtime服务账号，Always拉取已锁定HAProxy，检查真实imageID、DNS、API令牌不存在及跨命名空间TCP拒绝。
- 证据保存于新集群 `bootstrap/evidence/foundations`，日志不含Secret；临时Job和所属Pod精确删除，命名空间及持久声明保留。失败同样保留状态证据。

回退时提升此前已验证的OCI摘要，再执行源应用；当前根声明prune=false，回退不会自动删除新增对象。密钥保留至其加密的全部历史恢复版本退出之后，轮换和删除须另行确认。

官方行为依据：[Flux SOPS/age](https://fluxcd.io/flux/guides/mozilla-sops/)。
