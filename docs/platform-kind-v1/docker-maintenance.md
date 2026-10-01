# Docker 认证修复维护方案

状态：**2026-10-01 所有者批准后已尝试升级；29.8.1 曾成功启动，但维护脚本的挂载列表顺序误判触发回退。当前29.4.3，正式入口未切换；后续依赖恢复通过，见 CHECKPOINT。原20分钟窗口不用于无限重试。**

## 原因、目标和范围

2026-10-01，新 Harbor 经正式 30443 的 skopeo 推送、独立完整拉回、八个 OCI blob 和 manifest/config 摘要核验、只读账号推送拒绝均通过；宿主 Docker **29.4.3** 拉取却在 `/service/token` 报 `x509: certificate signed by unknown authority`。registry 专用 CA 已安装、使用同一 CA 的真实 TLS 访问通过。

该症状与 [Moby 52600](https://github.com/moby/moby/pull/52600) 一致；[Docker 29.5.0 发行说明](https://docs.docker.com/engine/release-notes/29/#2950) 明确修复 token 请求忽略仓库 TLS 配置。29.8.1 是本次冻结的维护目标，不代表始终最新。升级后的候选与正式地址拉取尚未执行，不能把根因判断写成修复已完成。

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
3. 先记录每个原有容器完整 restart policy（包括 MaximumRetryCount），临时将非 no 策略改为 no，覆盖原本停止的旧控制面，防止 daemon 启动时自动抢占80端口。再仅按第 1 步确认的运行 ID 停止其余容器，保留所有对象。节点必须保存 IPv4/IPv6；不能依靠启动顺序保证动态分配地址。现场八个原运行 KIND 节点已在恢复时按基线固定原地址；再次操作先核对，不重复断连。停止 `docker.service` 和 `docker.socket`，不停止或升级 containerd。确认 Docker 不再被 socket 自动拉起。
4. 若 `/usr/sbin/policy-rc.d` 已存在，先核实其作用，不覆盖。当前不存在时，仅在本次包安装期间创建退出 101 的临时策略，阻止包脚本自行启动服务；使用 finally 清理本次创建的策略。从已校验本地 deb 安装三个精确版本，使用 `DEBIAN_FRONTEND=noninteractive dpkg --install <三个已校验的精确 deb 路径>`。执行前仍用 APT 对相同本地路径和固定 containerd 版本模拟，变更名单必须恰好三个；不要使用 `apt-get --no-download` 安装这些路径，本次它在取得归档阶段失败、未安装。dpkg 不联网；安装失败立即进入回退。
5. 启动 Docker socket/service，确认服务版本 29.8.1、原存储后端和数据目录未变、旧容器/卷 ID 完整。按维护前清单恢复原运行节点；除下文新窗口明确包含的旧控制面临时恢复外，原本停止的节点/演练容器保持停止。旧 Harbor 先数据库/Redis，再 registry/registryctl/core/portal/proxy，恢复原 30443 入口；新 Harbor 经 `make registry-start` 恢复，新入口经 `make entry-start` 恢复候选 32443。以原健康基线对照，不只看容器 Running。恢复原 restart policy，核对仍无意外启动；恢复 rootless-extras 原 auto 标记。挂载按 Destination 排序后比较完整字段，不依赖 docker inspect 的列表顺序；容器ID、卷集合、原运行/停止状态、节点IPv4/IPv6、存储后端与目录均须一致。
6. 先为候选地址 `harbor.sunmoonai.com:32443` 添加独立的 Docker CA 文件（保留其他信任），在 root:0600 临时 auth 文件中把同一只读身份限定到该地址，完成 Docker 实际拉取；临时认证文件验后删除。使用新 CA，不降级 TLS；确认回退旧入口仍可用。再按 [入口操作卡](entry-cutover.md) 接管 30443，用正式 `make registry-publish-check` 验 skopeo 推拉、摘要、只读推送拒绝和 Docker 拉取；核对普通应用分流身份。再次切换包含在本窗口范围内。
7. 成功后新入口保留 30443；旧代理停止并保留。记录全部容器/卷、集群及两个 Harbor 的实际恢复结果；所有未通过项明确保留。开机自启仍待后续挂载/重启验收，不能顺手开启。

## 故障恢复

- 正式入口验收失败：先 `make entry-stop`，恢复旧代理 30443；站点改回候选 32443。新 Harbor 和验收镜像保留。
- Docker 包升级失败或新 daemon 无法正常使用原数据目录：停止 Docker/socket，从三个已校验 **29.4.3** 本地 deb 使用 `DEBIAN_FRONTEND=noninteractive dpkg --install <三个已校验旧版 deb>` 回退；containerd 不变。恢复原配置并启动 Docker，再按原运行清单恢复。
- 包回退不是完整 Docker 数据存储快照；若原目录在旧版下不能安全启动，停止并保护现场，禁止删除/重建 Docker 数据目录或容器/卷，报告恢复未完成。新 Harbor 冷备份可用于后续独立恢复，但本卡不授权覆盖旧数据。
- 不把 skopeo 成功当作 Docker 修复证据，也不把退出码 0 当作集群或业务验收通过。

## 准入限制

本卡只解决已复现的宿主 Docker 认证阻断。数据库扫描、完整备份恢复、全新 KIND 创建、Flux、应用以及 WSL/KIND 重启重建验收仍按 CHECKPOINT 的顺序继续。新架构代码不调用原 luna 部署程序；本卡中的旧容器身份仅用于这一次维护期间的保留与恢复。

## 2026-10-01 现场异常与修正

- 私有维护记录：`/data/harbor/maintenance/docker-20260930T234941Z/`，root0700，文件0600。冷备份 `new-harbor-cold.tar` 151,715,840字节、1,725项；GNU tar逐文件比较通过，另保存归档及每个普通文件的SHA256。这是冷备份字节验证，不是服务恢复演练。
- 第一次APT安装在取本地归档时失败，未改包。daemon恢复自动拉起原本停止的 `kind-control-plane`，占用80端口；已停止该原停止容器，保留全部节点和卷。节点动态IP分配同时变化，main控制面端点缺失；恢复时保留容器并重新连接八个原运行节点的原IPv4/IPv6，显式固定地址。该变化须保留到旧节点退出，不宣称网络配置完全未变。
- 第二次三个包已安装29.8.1，客户端/服务端版本均核实；main、136共六节点Ready。但恢复检查直接比较Mounts列表，代理容器返回顺序不同，触发自动回退。事后按Destination排序比较，完整字段一致。这是维护检查代码缺陷，不能归因于Docker29.8.1不兼容。没有完成升级后的镜像认证拉取，也没有切换30443。
- 下一次开始前，必须先对恢复后的所有容器跑修正后的比较：完整内容排序一致、原运行/停止状态、卷、原IP、原restart策略、节点Ready和旧入口路由均通过；保留本次失败记录，不改写成成功。重新核容量、冷备份与本地包身份，临时禁止自动重启，然后只进行一次升级和候选/正式认证验收。
- 新窗口仍需明确批准：20分钟维护、失败另15分钟恢复。范围不变，仅三个Docker包，containerd不变；不清理容器、卷或备份。超时恢复服务后停止，不自行续窗。


### 恢复遗留应用入口：例外已获批，保护性停止

恢复核对发现：156个原容器身份和卷集合均完整，原27运行状态、挂载内容、restart策略、八节点IPv4/IPv6、main与136共六节点Ready均匹配；新Harbor健康，旧Harbor恢复原组件基线。**旧应用TLS入口未恢复**：kind-worker内Traefik已退出，kubelet访问已停止的kind-control-plane失败。此项不能省略或用Harbor健康代替。

此前要求原停止容器保持停止，所以不能自行启动旧控制面。建议仅批准一次恢复例外：

1. 保存当前状态。临时暂停 main 控制面和旧30443代理；它们分别占用旧控制面需要的80/30444–30446和30443。保留main工作节点、新Harbor11443、候选入口32443及验证集群。
2. 临时启动原有kind-control-plane，最多等待5分钟核对API、旧worker及Traefik恢复。观察是否出现旧Harbor写入或超出预期的工作负载启动；有则立即停止并报告，不据此扩大恢复范围。
3. 无论成功失败，都停止旧控制面，按原状态恢复main控制面及旧30443代理，核对六节点Ready和Harbor基线。成功还须取得原应用TLS证书摘要一致；不能只看容器Running。
4. 本恢复例外限10分钟、失败另5分钟；不删除或重建节点/卷，不升级Docker，不切新Harbor。通过后旧控制面仍停止，旧工作节点的依赖问题纳入退出旧集群的限制，不能承诺再次重启仍可自行恢复。

所有者随后批准该例外，00:12:37Z开始，69秒结束。旧API出现原Harbor PostgreSQL与Redis两个Pod的Running/Pending记录，触发保护条件；立即停回旧控制面、恢复main及旧代理。未修改这两个工作负载、未证明它们已经写入。旧应用入口仍未恢复。


### 遗留数据库退役及入口恢复（随后批准并完成）

旧应用入口需要旧API，而旧API又保留旧Harbor数据库工作负载。下一次维护建议仅处理此依赖，不继续升级Docker：

1. 保存两旧worker的kubelet状态并临时停止kubelet，防止旧控制器恢复期意外启动数据库Pod。保留节点容器、运行时与磁盘；这会暂时影响旧worker的工作负载管理。
2. 按上节端口顺序临时恢复旧控制面。核对上述两个Pod的真实owner及期望副本；仅当明确属于旧Harbor、且缩容不会删除PVC时，保存原配置，把对应工作负载副本设为0。若PVC保留策略为Delete或归属不明，停止，不更改策略或删除数据。此缩容需要所有者明确批准，不能由先前临时启动授权推导。
3. 恢复两旧worker的kubelet，等待Traefik及原应用TLS身份通过；再停回旧控制面、恢复main/代理。保留旧Harbor工作负载为0及其PVC/PV，不恢复其写入，不影响两套外置Harbor。
4. 上限10分钟、失败另5分钟。无论成功失败都恢复两worker的原kubelet状态、main和旧代理，并给出未恢复项。此方案随后经所有者明确批准执行：两个原副本1的StatefulSet设0，PVC/PV UID完整保留，114秒恢复，最终入口SHA256与基线一致；原配置已私有备份。


## 再次升级的具体安排（待新维护窗口）

原入口已在后续独立授权下恢复。新窗口仍20分钟、失败另15分钟，范围仅三包29.4.3→29.8.1、containerd固定；同时明确包含重启后的旧API临时恢复，不能重复遗漏此依赖。

1. 核挂载、当前完整恢复清单、六个deb、APT仅三包演练和2GiB空间预算，重新冷备份新Harbor并逐文件比较。
2. 临时把全部原容器restart策略设no，按原运行ID停容器和Docker/socket。本地dpkg安装三个新包，临时policy-rc.d阻止安装脚本自行启动服务；结束移除。无需现场联网下载。
3. 启动Docker，先启动原运行节点（暂不启动占80等端口的main控制面）。临时启动保留的旧控制面，核实两个遗留数据库仍0副本，等待旧Traefik入口恢复。接着停回旧控制面，启动main控制面、原外置Harbor与代理，再经原生Make恢复新Harbor和候选入口。恢复原restart策略与auto包标记。
4. 对照完整基线：全部原容器和卷身份，运行/停止状态、完整挂载字段（按Destination排序）、原IPv4/IPv6、Docker数据目录/存储后端、两个集群节点Ready及原应用证书。私有CA下先实际Docker候选pull，再执行既有正式入口切换和registry-publish-check。
5. 失败停止新动作，回退包/入口并按第3步恢复。归档失败记录和修正依据，不把检测失败写成组件不兼容。只读预检已通过，尚未执行此新窗口。

准备脚本为本次一次性维护编排，不属于长期部署代码；临时文件收尾移出/tmp，仅保留私有审计副本。部署仍使用既有Make/Ansible。
