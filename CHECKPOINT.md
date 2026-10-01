# 新部署体系交接

## 目标、工作区与授权

从零建立长期维护的部署代码，第一期KIND，原生Make/Ansible、官方Harbor Compose、KIND、Flux/SOPS；不调用旧sunmoonai/utils/luna部署链。五仓在 `/home/zymun/worktrees/platform-kind-v1`，各自分支platform-kind-v1，从本地master建，基线见[输入盘点](docs/platform-kind-v1/inventory.md)。原luna仅参考。

已确认采用新版本、不迁移旧业务数据/Harbor镜像，应用可以修改重建，业务Python3.13.15。旧节点、卷、备份与他人local-integration受保护；日志3×20MiB已批准，其他删除策略需具体批准。本轮只改k8s，四个应用仓均干净，无push。

前序提交：独立Harbor `f3573d511c78cb9b68cc7f4605ef151896f7321b`、节点构建 `e280a3850953584853a4717945a8183baf18e5ec`、离线镜像 `eef098e272932a0ac3e279bfc002e1ea0ef1b9a0`、入口/认证及Docker物料 `c1917447b814884b5b32d81ddc08ceb42daf0b93`、失败与恢复记录 `b3c44e1e30a0ca566b5b8addabcb2ff08da1e1a3`。当前交付提交见HEAD，最终须报完整SHA。

## 当前现场：离线扫描与独立恢复通过（2026-10-01）

在前序提交 `7c2068d5cf3bc67d51ffeeaf14bab87656c0ac76` 上完成本单元；真实入口与既有集群保持运行。详情和日常命令见 [扫描与恢复](docs/platform-kind-v1/scanning-recovery.md)。本单元提交见 HEAD。

- 新增原生 Make/Ansible 的 scanner-db-plan/install/verify、registry-scan-check、registry-recovery-plan/check。`prepare-recovery.py` 仅校验冷备份和生成隔离的官方 Compose 副本，不管理部署生命周期；没有新通用 CLI，也不调用旧部署代码。
- 两个数据库归档纳入 `files.lock.json` 的独立 database 类型和 `databases/`。漏洞库 2026-10-01 01:24 UTC/schema2，Java 索引 2026-09-27 01:08 UTC/schema1；压缩共1,098,440,570字节，解包共3,008,844,062字节。Java不是今天最新版：两官方链路大文件只有几十KiB/s，东京SSH超时；官方GHCR不可变manifest重新核验后，以硬链接复用完整旧公共缓存，和旧脚本没有调用依赖。扫描入口要求两库均不超过七天。
- 初装数据库 ok52 changed8 failed0；修正为仅预算缺失库后重复安装 ok35 changed0 failed0。没有覆盖运行中的数据库；定期换版/回退和到期告警仍须补齐。
- Harbor真实扫描 ok48 changed4 failed0，Trivy v0.72.0，状态Success；报告 `/data/harbor/platform-kind-v1/scan-reports/haproxy-cud54j28.json`。验收镜像仍为固定HAProxy manifest `sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`。
- **安全待办**：201条包/CVE记录、86个不同CVE；High50条/11个不同CVE，Medium84、Low65、Unknown2，无Critical记录。OpenSSL/PCRE2相关包已有报告中的修复版本，而且入口进程实际加载这些库，不能一概解释为未使用；漏洞路径是否触达和官方镜像修复仍待评估。本单元只验扫描链路，不放行生产安全门禁，不自制补丁镜像；继续优先建群。
- 既有一致性冷备份 SHA256 `68f0f80957a655bdc1773f47af4ef223c92005190ac245f6957c0bc3d4ea0e96` 已实际恢复：1,625个普通文件逐一比对；16个registry数据文件在完整拉取后仍全部摘要一致；6层/8blob及config摘要一致。备份中的管理员、puller、加密密钥和证书可用；独立12443 token realm验证通过，没有借用正式仓库认证。
- 恢复入口 ok40 changed5 failed0。成功回执 `/data/harbor/platform-kind-v1/recovery/rehearsal-20261001061625045631223/verified.json`，结束状态同目录final-state.json。演练已停，正式Harbor仍healthy。备份早于本轮扫描情报和扫描报告，不能声称包含这些新数据；新备份创建与轮换仍待原生入口实现。
- 三次前置尝试分别被副本相对挂载路径识别、internal-only网络未发布宿主端口、realm检查请求缺少域名Host头拦住，均已修正。后端继续internal隔离，只有proxy另接access网络。两次已启动失败演练均停回；首次未创建容器。失败不冒充通过。
- 本轮原156容器的身份、挂载、完整restart策略和切换后的运行状态已只读复核。当前总186、运行26；新增30个演练容器全部停止。main/136共六节点Ready、仍v1.36.4，未在本轮新建集群。此前Docker29.8.1/正式入口状态维持。

### 本单元网络、空间、检查与清理队列

网络配置检查通过，无代理配置修改。GHCR最初EOF，默认mirror可读；大Java索引下载慢，保留458,883,072字节后接入原生curl续传（180秒连接上限、有限重试、最终SHA256+原子发布），实际续传增加字节，但本次最新Java归档没有下完，已停止。完整.part的验证/发布分支用已验漏洞库实操通过：ok26 changed1 failed0。两个最终归档离线核验 ok8 changed0 failed0；语法检查、Python AST、git diff检查通过，未加/跑测试套件。

06:26:21Z容量检查：C盘空闲127,469,379,584字节，230GiB盘尚可增长66,970,451,968字节，再扣250,027,436字节预算仍余60,248,900,180字节，高于50GiB；不代表全套部署已有充足预算。

最终清理务必包含：

- 本实例 recovery 下四目录：`rehearsal-20261001060549318303881`（无容器）、`rehearsal-20261001060643337524207`、`rehearsal-20261001061221251867522`、`rehearsal-20261001061625045631223`（后三者各10停止容器和专用网络）。先保留验收回执，按精确归属清理；不得波及正式实例、原节点/卷或源冷备份。
- 未选用的下载残片 `packages-to-be-installed/releases/platform-kind-v1/databases/trivy-java-db-76d004c32044.tar.gz.part`，不是正式物料。东京探测超时，无本轮远程下载文件。
- 本轮编写用 `/tmp/platform-*` 临时文件在提交前精确删除；不泛删其他人的 `/tmp` 文件。

下一工作单元是新KIND创建/节点信任/私有拉取，再Flux和平台。站点仍写sunmoon-kind-main，但已有同名受保护集群，不能直接覆盖；建群前落实目标名/端口/目录隔离或批准切换。开机/WSL重启、KIND删除重建、统一一键与生命周期、长期空间策略、应用全链路、云端实机均未完成。

## 前序现场：Docker升级及新Harbor正式入口通过（7c2068d）

所有者分别批准最初Docker维护、临时旧控制面恢复、遗留数据库缩容，以及修正后的第二个20分钟维护窗口（失败另15分钟）。第二个窗口已成功结束，不延伸为其他停机的无限授权。

- Docker客户端/服务端及三个包已 **29.8.1**；仅docker-ce/docker-ce-cli/docker-ce-rootless-extras升级，宿主containerd.io **2.2.3**保持。存储后端/目录不变，临时policy-rc.d已移除，rootless-extras原auto标记恢复。
- 正式 **0.0.0.0:30443 → 新HAProxy**。Harbor域名→新Harbor **127.0.0.1:11443**；其他域名→保留kind-worker **172.18.0.5:30443**。候选32443已退出监听。旧代理sunmoon-sni-transition-main-20260928停止并保留；旧Harbor仍在18443保留。
- 新Harbor2.15.2官方10服务healthy，unit sunmoon-registry.service；HAProxy3.4.6固定摘要，unit sunmoon-entry.service。两unit active、**boot disabled**，开机/WSL启动顺序尚未验收。systemd唯一重启管理者、Docker restart=no。
- 数据 `/data/harbor/platform-kind-v1/data`，秘密 `/etc/sunmoon/registry`，独立运行文件 `/opt/sunmoon/registry`；入口 `/etc/sunmoon/entry` 与 `/opt/sunmoon/entry`。数据盘230GiB，UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`。服务器证书1825天，2031-09-29 UTC到期，CA3650天。
- 私有platform项目，publisher仅pull/push、puller仅pull，均无删除权限，有效期90天。秘密在registry/private下root0600；自动轮换/到期告警尚未实现。新CA追加到宿主仓库专用certs.d，保留旧CA，未关闭TLS校验/改变全局信任或代理。
- 原 **156个容器身份和全部Docker卷保留**。原27运行容器中，仅旧代理按切换要求停止，现26运行。原挂载内容、restart策略、八个原运行KIND节点的IPv4/IPv6均核对。main、136两个既有集群共六节点Ready，仍是v1.36.4；**尚未用新体系建1.36.5集群**。

## 本轮证据与限制

最新私有记录 `/data/harbor/maintenance/docker-20261001T053018Z/`，root0700/文件0600；包含window、前后快照、dpkg日志、upgrade-result、cutover-result、publisher-repeat及final-state。前轮失败和恢复证据在 `docker-20260930T234941Z/`，不能覆盖成成功。凭据/备份不入Git、不公开。

1. 新窗口冷备份151,726,080字节，tar逐文件比较通过，SHA256 `68f0f80957a655bdc1773f47af4ef223c92005190ac245f6957c0bc3d4ea0e96`。此前冷备份151,715,840字节/1725项也保留。**字节比对不是独立服务恢复演练**。
2. 第二次升级及恢复检查通过，正式切换05:35:42Z通过，最终状态05:36:55Z核对通过，正式入口重复部署ok20 changed0 failed0；均在新20分钟窗口内。
3. Docker通过候选32443及正式30443、私有CA和只读身份实际pull；原token CA报错未再出现。registry-publish-check **ok28 changed3 failed0 skipped1**；已有相同manifest使发布步骤按幂等逻辑跳过。随后另以publisher向现有同摘要标签真实重复push并复核，publisher-repeat通过，不覆盖不同镜像。
4. 独立skopeo完整拉回 **6层、8blob**，manifest `sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`，config `sha256:c6f9accb39104d084a2e8012cdfc52f2a69db18790bf04e981cd6bbc8ea7c624`；只读push被拒。镜像地址 `harbor.sunmoonai.com:30443/platform/haproxy:3.4.6-trixie` 或上述digest。临时拉回/auth目录由正式入口清除。
5. 新Harbor TLS/管理员认证/健康通过；应用SNI证书与维护前、直接旧worker一致：`a0c60b64911e69797bc8832be22e0a9eae96f9488a80ff6d59158b199842834d`。这证明入口身份恢复，**不是业务登录/完整链路测试**。

### 已处理的维护错误和仍存在的过渡依赖

首次APT --no-download未取得本地归档，未安装；随后dpkg安装成功，但维护脚本直接比较Mounts列表顺序，误触回退。修正为按Destination排序比较完整字段。不能把维护检查错误说成29.8.1不兼容。

第一次daemon恢复意外启动原停止kind-control-plane，抢80端口并造成节点动态IP漂移及main端点缺失。保留原容器，八节点已按原IPv4/IPv6显式重连；这是实际IPAM配置变化。后续先暂时抑制全部restart策略再恢复原值，不能靠启动顺序保证动态IP。

旧worker重启后需要旧API重新提供Pod配置，原本停止的旧控制面导致Traefik无法恢复。第一次授权临时启动时出现遗留Harbor数据库Pod，按保护条件停止；随后所有者明确批准暂停两worker kubelet，核PVC保留和owner，再把 `cicd-platform-dev/sunmoonai-harbor-postgresql`、`sunmoonai-harbor-redis-master` 两个StatefulSet由1设0。原PVC/PV UID保留，原对象私有备份；两worker kubelet已恢复，旧控制面最终停回。

**后续Docker/旧worker重启仍有此过渡依赖**：临时启动旧API→核两个遗留数据库仍0→恢复Traefik→停旧控制面→恢复main/代理。此次新窗口已按此顺序实测通过。两个控制面以及代理存在宿主端口竞争，不能同时盲目启动。旧Harbor外置jobservice原本created未启动，聚合unhealthy，其他七组件healthy；没有擅自启动旧jobservice。

## 已准备的新体系代码与物料

原生Make/Ansible、官方Harbor生成器/Compose及有限override、HAProxy SNI分流、镜像验证与发布；不新增Python统一CLI。一次性维护编排不成为部署依赖。站点保留开关；正式entry地址/端口已写回site.yaml。

Ansible2.21.4、Compose5.5.1；KIND0.33.0、kubectl/kubeadm1.36.5。官方KIND构建节点sunmoon-kind-node:v1.36.5-kind0.33.0，manifest `676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b`，内含containerd2.3.4/runc1.4.3；节点+Calico3.32.2四归档641,355,776字节已核验，尚未创建新集群。

物料 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/{bin,packages,manifests,images}`。上游镜像锁56项，offline_ready=false；文件锁16项，含六个Docker新旧deb共98,306,132字节（回退包先保留）。Harbor官方包177blob/12镜像已核验；归档与上游压缩manifest不同，运行使用archive_reference。HAProxy/skopeo归档136,100,352字节；官方skopeo容器1.22.3，manifest `9182497536bb5485b4f0bdbad5dbab24cd0df7259c33005a1e732a34f5d78a99`，与源码最新版本的差异已有记录。

## 下一步（保持顺序）

1. 离线扫描与已有冷备份独立恢复已通过；后续补数据库定期更新、原生备份创建/轮换与扫描风险收敛。
2. 新KIND创建/配置、节点信任和私有拉取、Flux，再平台和模板/应用部署；现有main/136仍属保护对象，不能凭名字覆盖。
3. 单组件与整套一键、统一启停、开机附盘与服务顺序；WSL/KIND重启、KIND删除重建后的Harbor数据/摘要/新节点pull验收。
4. 长期容量监控、Harbor保留/GC、缓存/日志/备份轮换与统一预览/执行；除日志外删除策略具体确认。结束时清理本次全部临时物料/东京下载，受保护旧资源达到退出条件后再清理。

最近容量：05:35:37Z，计数据盘长到230GiB及本次512MiB拉回预算后C盘剩59,966,734,336字节，高于50GiB。后续重测，不表示全套部署均有足够空间。

当前Docker升级/正式仓库认证单元完成；新架构全量部署、重启/重建验收、云端实机验证未完成。没有新增或运行测试套件；实际部署验收、Python AST和git diff检查按用户授权执行。本轮未改Windows附盘/计划任务/执行策略，未连东京。

本轮9个一次性运维脚本已从/tmp移除，只在最新私有维护记录的script-audit中保留非执行文本副本及SHA256；4个临时文档/提交编辑文件已删除。旧luna任务的/tmp文件未混删，整体重整的最终清理仍列在后续步骤。
