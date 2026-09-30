# Docker 认证修复维护方案

状态：**物料准备和只读演练完成，升级、Docker 重启和再次切换尚待维护批准。**

## 原因、目标和范围

2026-10-01，新 Harbor 经正式 30443 的 skopeo 推送、独立完整拉回、八个 OCI blob 和 manifest/config 摘要核验、只读账号推送拒绝均通过；宿主 Docker **29.4.3** 拉取却在 `/service/token` 报 `x509: certificate signed by unknown authority`。registry 专用 CA 已安装、使用同一 CA 的真实 TLS 访问通过。

该症状与 [Moby 52600](https://github.com/moby/moby/pull/52600) 一致；[Docker 29.5.0 发行说明](https://docs.docker.com/engine/release-notes/29/#2950) 明确修复 token 请求忽略仓库 TLS 配置。29.8.1 是本次核实的稳定发行。尚未通过升级后的现场复测，不能把根因判断写成修复已完成。

本次拟将 `docker-ce`、`docker-ce-cli`、已安装的 `docker-ce-rootless-extras` 从 `5:29.4.3-1~ubuntu.24.04~noble` 升为 `5:29.8.1-1~ubuntu.24.04~noble`。宿主 `containerd.io=2.2.3-1~ubuntu.24.04~noble` 满足新包要求，本次固定不变，避免同时改变内容存储运行时；它仍需在完整宿主版本选型中单独评估。KIND 节点里的 containerd/runc 是独立发布，不随此包变更。

不卸载 Docker，不改变存储驱动，不迁移 `/var/lib/docker` 或 `/var/lib/containerd`，不启用 insecure registry，不关闭证书校验。不执行 autoremove 或任何 prune。

## 已完成的准备

- 六个新旧 deb 共 **98,306,132 字节**，在物料根目录 `releases/platform-kind-v1/packages/`；ID 为 `docker-ce-{next,rollback}`、`docker-ce-cli-{next,rollback}`、`docker-ce-rootless-extras-{next,rollback}`。
- `platform/artifacts/files.lock.json` 保存 URL、包版本、大小、SHA256、用途和签名元数据摘要。通过已有 Docker APT 公钥验证 InRelease 签名，再核对 Packages 摘要；下载后逐文件核对大小和 SHA256。
- APT 只读演练：**3 upgraded, 0 newly installed, 0 to remove**。现场若出现额外变更就停止。
- 当前 `live-restore=false`。共有 **27 个运行容器**：新 Harbor 10、新入口 1、旧 Harbor 7、旧入口 1、现有 main 3、验证 136 3、保留的 kind-worker/worker2 2。
- 旧 Harbor jobservice 的状态为 `created`，开始时间全零，先前未启动；旧聚合健康因此为 unhealthy，其他七个组件健康。这是基线缺口，恢复时不得自动把所有停止容器启动，也不能宣称旧聚合健康恢复为 healthy。
- 新 Harbor `/etc` 配置约 12 KB、运行文件约 32.36 MB、数据约 116.49 MB；维护前重测，冷备份及验证预留 1 GiB。
- 现入口已回退：30443 → 旧 Harbor 18443，新候选 32443 → 新 Harbor 11443。所有旧节点、卷和备份保留。

## 停服范围和时限

需所有者批准 **20 分钟维护，失败另留 15 分钟恢复**。Docker 停止期间，新旧 Harbor、已有 KIND API/工作负载及相关入口均可能不可用；这超出之前仅约一分钟 TLS 中断的授权。计划任务和 WSL 本身不重启。

维护记录放独立 root:0700 目录 `/data/harbor/maintenance/<UTC 批次>/`，不放物料或 Git。记录只含必要元数据；完整配置和冷备份含秘密，文件 root:0600。

## 执行顺序（批准后由助手完成）

1. 重新检查存储 UUID、Docker 可见性、C 盘增长预算、六个包摘要及 APT 演练。记录当时运行容器的完整 ID、名称、健康、IP、重启策略和挂载身份；记录新旧 Harbor、集群 API/节点及入口实际基线。记录 Docker/containerd 包版本、配置与 unit。若与上述范围不同，先核清差异。
2. `make entry-stop`、`make registry-stop`。对新 Harbor 做一次一致性冷备份，覆盖 `/etc/sunmoon/registry`、`/opt/sunmoon/registry` 和 `/data/harbor/platform-kind-v1/data`，保留权限/属主及加密密钥；计算清单摘要，将归档完整读回/解包到本批次校验目录逐文件比对。不把该检查冒充服务恢复演练。冷备份失败即恢复候选服务，停止升级。
3. 仅按第 1 步确认的运行 ID 停止其余容器，保留所有对象。停止 `docker.service` 和 `docker.socket`，不停止或升级 containerd。确认 Docker 不再被 socket 自动拉起。
4. 若 `/usr/sbin/policy-rc.d` 已存在，先核实其作用，不覆盖。当前不存在时，仅在本次包安装期间创建退出 101 的临时策略，阻止包脚本自行启动服务；使用 finally 清理本次创建的策略。从已校验本地 deb 安装三个精确版本，使用 `apt-get --no-download --no-remove --no-install-recommends install <三个精确 deb 路径>`。执行前再以相同本地路径模拟，变更名单必须仍恰好三个；安装失败立即进入回退。
5. 启动 Docker socket/service，确认服务版本 29.8.1、原存储后端和数据目录未变、旧容器/卷 ID 完整。按维护前清单恢复原运行节点；原本停止的节点/演练容器保持停止。旧 Harbor 先数据库/Redis，再 registry/registryctl/core/portal/proxy，恢复原 30443 入口；新 Harbor 经 `make registry-start` 恢复，新入口经 `make entry-start` 恢复候选 32443。以原健康基线对照，不只看容器 Running。
6. 先为候选地址 `harbor.sunmoonai.com:32443` 添加独立的 Docker CA 文件（保留其他信任），在 root:0600 临时 auth 文件中把同一只读身份限定到该地址，完成 Docker 实际拉取；临时认证文件验后删除。使用新 CA，不降级 TLS；确认回退旧入口仍可用。再按 [入口操作卡](entry-cutover.md) 接管 30443，用正式 `make registry-publish-check` 验 skopeo 推拉、摘要、只读推送拒绝和 Docker 拉取；核对普通应用分流身份。再次切换包含在本窗口范围内。
7. 成功后新入口保留 30443；旧代理停止并保留。记录全部容器/卷、集群及两个 Harbor 的实际恢复结果；所有未通过项明确保留。开机自启仍待后续挂载/重启验收，不能顺手开启。

## 故障恢复

- 正式入口验收失败：先 `make entry-stop`，恢复旧代理 30443；站点改回候选 32443。新 Harbor 和验收镜像保留。
- Docker 包升级失败或新 daemon 无法正常使用原数据目录：停止 Docker/socket，从三个已校验 **29.4.3** 本地 deb 执行明确 `--allow-downgrades --no-download --no-remove` 的包回退；containerd 不变。恢复原配置并启动 Docker，再按原运行清单恢复。
- 包回退不是完整 Docker 数据存储快照；若原目录在旧版下不能安全启动，停止并保护现场，禁止删除/重建 Docker 数据目录或容器/卷，报告恢复未完成。新 Harbor 冷备份可用于后续独立恢复，但本卡不授权覆盖旧数据。
- 不把 skopeo 成功当作 Docker 修复证据，也不把退出码 0 当作集群或业务验收通过。

## 准入限制

本卡只解决已复现的宿主 Docker 认证阻断。数据库扫描、完整备份恢复、全新 KIND 创建、Flux、应用以及 WSL/KIND 重启重建验收仍按 CHECKPOINT 的顺序继续。新架构代码不调用原 luna 部署程序；本卡中的旧容器身份仅用于这一次维护期间的保留与恢复。
