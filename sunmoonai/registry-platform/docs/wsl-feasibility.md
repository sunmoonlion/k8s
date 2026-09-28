# WSL 集群外 Harbor：历史问题与验收边界

核查日期：2026-09-28。所有者记得早期因 WSL 问题放弃集群外 Harbor，随后指出可能是代理绕行。本次核查仓内文档、相关 Git 历史及迁移实际回执；没有读取私人聊天记录。

## 找到了什么

- 2026-03-04 提交 `965b6309` 已包含 `utils/HARBOR-KIND-EXTERNAL/` 的两份集群外 Harbor 方案，采用 WSL + 官方安装包 + Compose。它们是方案/操作说明，没有失败日志或放弃该架构的决策记录。现归档在 `legacy/local/utils/HARBOR-KIND-EXTERNAL/`，原位置只保留指引；不可按其中的安装/卸载命令操作当前环境。
- [旧排障纪要](../../kind-infrastructure/docs/harbor-wsl-setup-changes.md)第 4 节明确记载：Docker daemon 的 `NO_PROXY` 只有 localhost/127.0.0.1，访问 Harbor 经过代理，出现 EOF；增加仓库域名直连后，错误转为入口连接拒绝，进一步查到 Traefik/PVC 问题。这个记录支持“曾遇到代理绕行”，不能证明它就是当时放弃集群外方案的唯一原因。
- 2026-06-03 的 `bdb9caa1`、`a9a6669a`、`87c0a9de` 继续修复重启后的节点解析、CA 与拉取路径。说明重启和不同网络视角必须验收，不能只看当前终端能否访问。
- 旧外置操作卡把 Harbor 直接绑定 30443，没有处理当前应用与 Harbor 共用该端口的 SNI 分流。这是旧方案与当前拓扑的缺口；没有证据认定它是历史失败原因。现在采用独立入口代理，Harbor 转宿主后端，其他域名转集群入口。

**结论：没有找到“WSL 无法运行集群外 Harbor”的证据；已有宿主实例实际运行证据。但正式入口、客户端与重启恢复尚未全部验收，不能提前宣布迁移完成。**

## 已有实际证据

| 范围 | 结果及证据 | 不代表什么 |
| --- | --- | --- |
| 宿主 Harbor 运行、身份及 TLS | [独立实例](../../scripts/results/luna-harbor-host-instance.20260927.json)、[身份比对](../../scripts/results/luna-harbor-identity.20260927.json) | 不是正式入口已切换 |
| 受控制品读写 | [HTTP Registry API 推拉](../../scripts/results/luna-harbor-write-acceptance.20260927.json)，逐字节相同、匿名拉取/只读账号推送被拒 | 回执明确 `docker_engine_push_pull_verified=false`、`cicd_job_verified=false` |
| 完整备份独立恢复 | [恢复回执](../../scripts/results/luna-harbor-managed-restore.20260928.json)：4416 文件全 SHA、49 张表、431 份 manifest、TLS 与扫描验证通过 | 不是所有写入客户端或 KIND 重建已验证 |
| SNI 入口候选 | [38443 候选](../../scripts/results/luna-sni-transition-candidate.20260927.json) | 正式 30443 仍由旧 KIND 持有 |
| 存储可见性与自动任务 | [挂载回执](../../scripts/results/luna-storage-automation.20260928.json)：PID 1/Docker 可见、任务注册及周期检查成功 | 完整 Windows/WSL 重启、缺盘时自动修复分支尚未实测 |

自动任务随后按所有者反馈取消了一分钟轮询，改为无窗口、仅登录触发；[修复回执](../../scripts/results/luna-storage-task-hidden.20260928.json)记录修改后一次运行成功。Harbor/KIND 的 CLI 启动前现已接入按需附盘及重新核验；完整重启/缺盘恢复分支尚未实测，不把“登录时检查一次”当成覆盖任意 WSL 重启。

这些是过去运行的证据，不是本次又启动了服务。当前宿主实例停止保留，旧 Harbor 继续服务。

## 迁移完成前必须补齐

1. **代理直连分三处验收**：WSL Docker daemon、KIND 节点 containerd、真实 CI runner/构建环境。各自核生效的代理环境与仓库域名/IP直连规则；终端的 `NO_PROXY` 不能替代 daemon 配置。不打印代理口令或认证信息。
2. **不用规避 TLS 的方法通过验收**：始终使用 `harbor.sunmoonai.com:30443`，核对应主机/端口的 CA、域名及原令牌 realm；禁止用 `-k`、`skip_verify` 或临时改镜像引用冒充通过。
3. **从实际消费者访问正式入口**：Docker 和无试验镜像缓存的新节点按摘要真实拉取；CI 进行受控构建、推送、按摘要部署。候选端口/Registry API 成功不足以替代这些结果。
4. **维护窗口验重启恢复**：记录运行状态，按存储操作卡暂停自动任务并关闭 WSL；恢复后先核 UUID、绑定目录、PID 1/Docker 可见性，再启动 Harbor/代理/集群。缺盘时服务必须拒绝启动，不能写入系统盘同名空目录。检查节点地址漂移后重新核实际直连与 TLS。
5. **验集群独立性**：按[集群外统一方案第 6 节](../../kind-infrastructure/docs/harbor-external-integration-plan.md#6-重建集群不影响-harbor-数据的强制验收)在获准的新空载节点上做真实重建；无 Kubernetes API 时仓库仍能认证、拉取和备份，重建前后镜像摘要及身份不变。旧节点/卷不用于试验。

以上全部通过前保留原入口、旧节点/卷及完整备份；不会把“容器能启动”记为整体成功。若失败，保留现场并修复对应层，不通过删除旧环境强推切换。云端仍未经实机验证。

Harbor 脱离 KIND 后仍与 KIND 共用 WSL、Docker daemon 和 C 盘物理硬盘；KIND 生命周期独立，不意味着关闭 WSL 或硬盘故障时仓库仍可用。
