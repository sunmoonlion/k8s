# 新部署体系交接

## 目标、工作区与授权

从零建立长期维护的部署代码，第一期 KIND，使用原生 Make/Ansible、官方 Harbor Compose、KIND、Flux/SOPS；不得调用旧 sunmoonai/utils/luna 部署链。五仓在 `/home/zymun/worktrees/platform-kind-v1`，各自分支 `platform-kind-v1` 从本地 master 建立，基线见 [输入盘点](docs/platform-kind-v1/inventory.md)。原 luna 仅参考。

用户已确认采用新版本、不迁移旧业务数据和旧 Harbor 镜像；应用可修改重建，业务 Python 3.13.15。旧节点、卷、备份和他人 local-integration 仍受保护。日志每容器 3×20 MiB 已获批；镜像、缓存、备份删除不因日志批准而放行。本轮仅 k8s 改动，应用四仓未改，无 push。

本单元基线 **f3573d511c78cb9b68cc7f4605ef151896f7321b**（独立 Harbor）；节点构建 e280a3850953584853a4717945a8183baf18e5ec，离线镜像 eef098e272932a0ac3e279bfc002e1ea0ef1b9a0。当前提交见本文件所在分支 HEAD，最终交付须报完整 SHA。

此前入口切换窗口已执行并回退。随后所有者明确说“那就升级吧”，批准Docker维护方案（20分钟维护、失败另15分钟恢复）。本次已执行但因维护检查代码错误回退；不是成功升级。窗口结束不继续反复停机。旧应用恢复例外及后续两个遗留数据库缩容分别获批。原入口已恢复，见下；Docker再次升级尚未批准新窗口。

## 当前现场：Docker升级已回退，原入口恢复通过；再次升级待新窗口

日期 2026-10-01（UTC 2026-09-30 晚间）。

- 正式 30443：保留的 `sunmoon-sni-transition-main-20260928`，Harbor 转 127.0.0.1:18443；其他域名转 **172.18.0.5:30443（kind-worker）**。不能改成 main 的 19443，那里尚无应用入口。
- 新 Harbor：`sunmoon-registry.service`，10 个官方 2.15.2 服务，127.0.0.1:11443，运行中；新 HAProxy：`sunmoon-entry.service`，候选 **127.0.0.1:32443**，运行中。两 unit **disabled**，尚未验开机启动；NRestarts=0。
- 新 Harbor data：`/data/harbor/platform-kind-v1/data`；私密配置 `/etc/sunmoon/registry`；运行文件 `/opt/sunmoon/registry`；数据盘 230 GiB、UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`。服务器证书 1825 天，到期 2031-09-29 UTC，CA 3650 天。
- 新入口配置 `/etc/sunmoon/entry`、运行 `/opt/sunmoon/entry`。HAProxy 只做 SNI TCP 分流，不持有私钥；官方摘要固定，UID10001，readonly/cap_drop ALL，有限 CPU/内存/PID/日志。
- 新项目 `platform` 为私有，publisher 仅 pull/push、puller 仅 pull，均无删除权限，有效期90天；文件 `/etc/sunmoon/registry/private/{publisher,puller}.json` 和对应 `*-auth.json`，root0600。到期须显式轮换，自动轮换/告警未完成。
- 新镜像仍在新仓库：`harbor.sunmoonai.com:30443/platform/haproxy@sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`；这是**新仓库中的目标引用**，当前正式地址已回旧仓库，不能直接认为该引用现可从30443获取。正式切换后才恢复该地址可用性。
- 旧 Harbor jobservice 状态 **created、StartedAt全零**，旧聚合健康 unhealthy；其他7个组件 healthy。不是本次停止造成。原卡“两个 Harbor 健康”的表述错误，已改为明确基线；本次没有擅自启动旧 jobservice。

### 最新维护结果（2026-10-01，优先于以下历史记录）

- 维护基线提交 `c1917447b814884b5b32d81ddc08ceb42daf0b93`；23:49:41Z开始。三包曾成功升至29.8.1，main/136六节点Ready；但挂载列表直接比较顺序，错误触发自动回退。**当前客户端/服务端及三包已回29.4.3，containerd始终2.2.3；没有执行升级后候选pull，也没有再切30443。**
- 首次APT `--no-download`对本地路径取归档失败，未改包。恢复自动启动原停止kind-control-plane、抢80端口，并导致节点动态IP变化及main控制面网络端点缺失。随后停止旧控制面，临时关闭restart策略，保留原八节点并按原IPv4/IPv6重新连接；现在使用显式IPAM地址。这是实际网络配置变化，不能写“现场完全未改”。原restart策略及rootless-extras的auto标记均已恢复。
- 私有证据/冷备份目录：`/data/harbor/maintenance/docker-20260930T234941Z/`（root0700/文件0600）。冷备份151,715,840字节/1725项，tar逐文件比较、归档和文件SHA256通过；**不是服务恢复演练**。原始失败、dpkg安装/回退输出和recovery-result.json保留。
- 最后恢复检查时间 2026-10-01T00:14:27.546438+00:00：156个原容器ID、卷集合、原27运行状态、完整挂载内容（按Destination排序）、原restart策略、八节点IPv4/IPv6和两个集群六节点Ready均匹配。新Harbor全部组件healthy；旧Harbor除原本未启动的jobservice外恢复健康。没有删除容器/卷/旧数据。
- **恢复期间曾失败：旧应用TLS入口**。kind-worker内Traefik退出，旧控制面原本停止，worker重启后无法从API恢复Pod，30443应用SNI握手EOF。后续经明确批准处理依赖后，当前入口已恢复；不能把第一次容器Running检查冒充当时路由已恢复。
- 所有者随后批准临时恢复旧控制面/应用入口，限10分钟、失败另5分钟，不升级Docker。00:12:37Z开始，69秒后保护性结束：旧API出现 `cicd-platform-dev/sunmoonai-harbor-postgresql-0` 与 `sunmoonai-harbor-redis-master-0` 的Running/Pending记录。按约定立即停回旧控制面、恢复main/旧代理；未缩容、删除或修改这两个工作负载。API状态可能陈旧，尚未证明其新写入；检查两worker时没有名称匹配harbor的运行容器。不能把保护条件触发写成已证明旧仓库重新写入。证据 `legacy-recovery-result.json`。
- 后续所有者批准：暂时停止旧worker kubelet，仅将明确的旧Harbor PostgreSQL、Redis StatefulSet缩容0，前提PVC保留，再恢复入口。实际05:20:08Z开始，114秒完成；两者原副本均1，现0。PVC保留策略与owner检查通过，原PVC/PV UID均保留。已保存原对象到私有legacy-db-before.json；不是删除数据。结果legacy-db-retirement-result.json。
+- 最终05:23:18Z恢复核对 **recovery-passed / issues=[]**：原156个容器与全部卷、原27运行状态/原restart策略/完整挂载、八节点IP一致，main与136六节点Ready，新Harborhealthy，旧Harbor恢复原组件基线；30443及候选32443应用SNI与直接kind-worker证书均回到原SHA256。Traefik Running/Ready，旧控制面已停回、两旧worker kubelet active。只验入口身份，不代表业务登录或全链路验收。
+- 下一次Docker重启仍须按顺序临时恢复旧API，使worker重载Traefik，然后停回旧控制面再启main/原代理。这个过渡依赖尚未消除；遗留数据库已0，禁止恢复其写入。新窗口必须明确包含这项恢复动作。
+- 本次维护错误已修正进操作卡：本地包用dpkg安装，禁止自动启动干扰；明确IP恢复；挂载按目标路径排序比较完整字段。回退不是29.8.1不兼容的证据，认证问题仍待真实拉取验证。

### 前一次入口切换实测（历史结果）

1. 候选 HAProxy TLS 路由、真实启停、重复部署通过。Compose5.5.1受控停止返回130，unit明确SuccessExitStatus=130；真正stop验到inactive，意外退出仍Restart=always。
2. `registry-accounts` 最终 **ok47 changed0 failed0**，两机器人均实际向可信后端申请token并核对subject/actions。创建接口返回服务器生成secret，不能依赖请求secret字段；项目列表按`Level=project,ProjectID`查询。前期误用字段/secret曾导致失败，仅显式重置新建且未使用的publisher一次，未改旧身份。
3. 第一次正式切换：空仓库返回`unknown: artifact <精确repo@digest> not found`，原检查只识别manifest/name unknown，误拦并自动回退；补精确错误匹配，不放行TLS/认证失败。
4. 第二次：受限容器不能读宿主用户0600归档，自动回退。公开且校验过的引导归档在正式prepare入口设0644；凭据仍0600。离线复核又发现skopeo用`/var/tmp`而非TMPDIR，已提供64MiB tmpfs，根目录仍只读。
5. 第三次切换与skopeo验收 **18秒**，`registry-publish-check`当时 **ok25 changed3 failed0**；真实推送、独立完整拉回 **6层/8blob**、manifest与config摘要、只读推送拒绝全部通过。临时拉回目录已精确清除，远端镜像保留。
6. 正式入口新CA/域名、Harbor管理员认证、健康均通过；应用分流前后证书SHA256相同。应用检查仅路由身份，不是登录/完整信任链验收。
7. 随后宿主Docker29.4.3真实pull失败：`failed to fetch oauth token ... x509: certificate signed by unknown authority`。专用CA已正确追加；与[Moby52600](https://github.com/moby/moby/pull/52600)及29.5.0发行说明一致。**整次最终判定未通过，按约定回退旧入口**；没有升级或重启Docker。
8. 回退验证：30443旧证书与18443相同，SHA256 `106bab970a87f1d2e5ac749e0efd61cf369f0f8baac7a5283dad7a6d3178e11e`；候选32443新证书与11443相同，SHA256 `e354e0268306e22baa03f629860166ee8decc8c28a985ab3cfeef419eaac2754`。旧Harbor组件状态如上。原应用证书SHA256 `a0c60b64911e69797bc8832be22e0a9eae96f9488a80ff6d59158b199842834d`。
9. 最终候选重复`entry-deploy` **ok20 changed0 failed0**。正式publish入口增加Docker版本前置准入及原生Docker实际拉取，当前29.4.3在任何写入前明确拒绝，已验拒绝路径；新增Docker成功路径尚未通过，不沿用先前skopeo结果冒充全部成功。

原始输出在本会话工具记录；没有新增/运行测试套件。实际推拉、权限拒绝、启停、故障回退、机械语法检查属于用户明确要求的部署验收。临时切换编排只用于本次维护，不是正式部署依赖。

## 新代码与物料

- `platform/host/entry.yaml` 与3个模板、`registry/accounts.yaml`/`tasks/robot.yaml`、`registry/publish.yaml`；Make只薄调用原生Ansible，保留开关。不新增Python统一CLI。
- 原`artifacts/bootstrap-images.yaml`重命名为`image-archives.yaml`，同一实现选bootstrap/host。原Make命令继续有效，旧文件删除，无转发壳。
- 新`host-archives.lock.json`：HAProxy3.4.6及官方skopeo归档共 **136,100,352字节**；全文件与blob校验通过。归档prepare先 **ok29 changed2 failed0**（两文件设0644），最终按完整repo@digest复核重复执行 **ok29 changed0 failed0**，离线check与bootstrap检查此前已通过。
- 官方skopeo容器实测 **1.22.3**，manifest `9182497536bb5485b4f0bdbad5dbab24cd0df7259c33005a1e732a34f5d78a99`。源码最新1.24.1不等于已发布镜像；记录明确版本例外，不自制镜像。
- 上游镜像锁现 **56项**，`offline_ready=false`。文件锁现 **16项**：原10项1,358,981,849字节，新增6个Docker deb98,306,132字节。物料在`/home/zymun/packages-to-be-installed/releases/platform-kind-v1/{bin,packages,manifests,images}`。
- 新增Docker deb：三个29.8.1升级、三个29.4.3回退。校验Docker InRelease签名、Packages摘要和文件SHA256/大小；`fetch-artifacts` **ok20 changed1 failed0**。已尝试安装29.8.1，当前回退至29.4.3。
- 宿主CA由`registry-accounts`追加`/etc/docker/certs.d/harbor.sunmoonai.com:30443/platform-kind-v1-ca.crt`，保留旧CA，未修改全局系统信任/daemon设置/代理。

### 前序成果仍有效

Ansible2.21.4（宿主Python3.12.3）、Compose5.5.1，`.tools/bin`固定KIND0.33.0/kubectl与kubeadm1.36.5。官方构建节点`sunmoon-kind-node:v1.36.5-kind0.33.0` manifest **676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b**；实际containerd2.3.4/runc1.4.3。节点+3项Calico3.32.2归档641,355,776字节，内置内容已核验，尚未用新体系创建集群。

Harbor2.15.2官方包177个blob/12镜像已核验，运行使用`harbor-offline-images.lock.json.archive_reference`（与上游压缩manifest不同）。service.yaml直接调用官方prepare镜像，官方Compose+有限override，挂载守卫、systemd唯一重启、3×20m日志。此前重复deploy **ok58 changed0 failed0**，真实stop/start及10容器healthy通过。Trivy DB未齐，扫描未验收；备份/恢复尚未完成。

## 下一步（按此顺序）

1. 原入口恢复已通过；下一项是Docker重试的新维护窗口。具体重试已准备为一次性维护编排：本地dpkg三包、临时抑制容器自动启动、恢复期先临时旧API/Traefik后main/代理、挂载排序比较完整内容。不给部署增加新框架。
2. 旧入口恢复后才安排Docker再次维护。修正后的步骤已在[维护方案](docs/platform-kind-v1/docker-maintenance.md)，重新确认窗口，不能沿用已结束窗口无限重试；候选/正式Docker拉取与skopeo整套验收均未完成。
3. 补扫描器DB、正式Harbor备份恢复演练，再创建新KIND/Flux，推进模板公共能力及平台/应用部署。
4. 完成单组件与整套一键、统一启停、开机自动挂盘、WSL/KIND重启及KIND删除重建后的Harbor摘要/新节点拉取验收。
5. 完成长期开销监控、受控清理；镜像/缓存/备份策略按具体清单批准。最后清理本次临时目录、重复物料和东京下载；受保护旧资源满足退出条件后再清理。

本次升级前容量复核：2026-09-30T23:46:23Z，C盘剩余131,381,755,904字节，计数据盘长到230GiB和2GiB本次预算后剩58,337,951,744字节，高于50GiB。后续仍须重测。

最后容量检查：2026-09-30T19:08:51Z，计数据盘长到230GiB及196,612,264字节下载预算后，C盘仍余 **60,361,613,144字节**，高于50GiB；后续操作须重测，不能当作整套部署均够空间。数据VHD实际分配176,064,299,008字节。Windows任务、附盘、执行策略和WSL没有变化，本轮未连接东京。

尚未实现新集群/完整部署/全套启停，不得宣布总体完成。当前无显式token预算。当前停在再次Docker维护的新窗口授权边界，普通文档、物料与代码工作不重复请求批准。

再次维护只读容量复核：2026-10-01T05:27:01Z，计230GiB数据盘长满及2GiB预算后剩58,367,475,712字节，高于50GiB。尚未据此启动新窗口。
