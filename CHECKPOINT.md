## 最新续接：2026-09-28 部署入口归档第一批与按需附盘接线

基线28683fe20ab9c82479c2954a9338064434a72cef，开工干净。所有者“继续”，本单元继续已批准部署入口整理；没有恢复现场迁移、停服或切换。

- 新根 README 和可执行 ./sunmoon（operations/cli.py）统一导航/转发已有实现，Harbor准备/启停/读写/备份/入口/物料/证书、formal建群/启停、storage ensure 共用原后端；cloud plan仅总控dry-run；platform plan/deploy对KIND/C1/C2/C3使用同一旧总控，默认计划，apply要求显式kubeconfig/kubectl/UID。平台总控拆掉自动建群，infrastructure_enabled=false；计划在Secret准备/连接之前退出；实际核映射与显式目标、工具、UID；整项目uninstall拒绝。WAIT_READY改为非空集合Ready/Succeeded，失败/超时返回非零并由调用点传播。当前子脚本/消费者配置尚未全迁移，main仍未建，不声明平台部署已验。
- 新 mount/ensure_storage.py 先核已发布root helper SHA/权限，正常挂载只读检查不碰Windows；异常才通过非提权Windows请求启动已有无窗口owner任务，核owner/action/launcher SHA，最多等50秒；最后独立核UUID/PID1/Docker视图。维护/禁用/缺任务/超时都拒绝启动，不创建磁盘/任务或开启轮询。已接入host_runtime CLI start（仅WSL）和formal lifecycle CLI start，在打开数据盘锁前执行；内部恢复流程不隐式附盘。REQUEST通过Windows Parser；未实际执行新请求、未重启WSL，也未启动服务。完整缺盘/重启及正式服务自启仍待验收。
- legacy/local与legacy/cloud落地，manifest共22项（含一组389个chart/resource原字节移动）。旧kind-up、deploy-kind、自制节点构建、cloud reset/runtime重装/三清理入口、集群内Harbor/两Secret部署脚本等11个原入口变最前置拒绝，归档实现也加拒绝头且去执行位。旧建群/外置Harbor/WSL E盘/NFS指南转指针。清理配置及cron示例归档，原执行入口不能误清理。旧Harbor chart移legacy/cloud/sunmoonai/cicd-platform/harbor/resources，harbor_prepare.py备份输入同步改址；chart树SHA ff6bca2a2a07785fc034bd0d37e56ee7c3ec0f590b975b41feeda80135ff72a5。原脚本/文档内容（扣归档门禁前缀）与基线摘要相同；不把相对依赖未齐的归档当可执行恢复包。
- 仍留原处的旧config及Harbor镜像公共helper有活调用者，含私有值，不复制到新清单。归档README列退出条件：本地迁移/消费者/重建独立性/观察期，云实机验证及旧源备份无依赖后另清。旧节点/卷仅登记历史身份快照，全部原地不动。原旧Harbor仍正式，inbox没变。
- 静态/默认计划：5 Python AST、14 Bash语法、REQUEST PowerShell Parser；storage/kind lifecycle/platform KIND/cloud C1 plans未执行部署。ShellCheck临时工具此前重启丢失，本机apt代理HTTP502/HTTPS SSL失败；按既有授权东京curl官方下载回传2845342B，SHA eadf78f4dfcb1a271f47a9be5e38d124dffe9d4fea74956fab34e8c3e322a854，dpkg-deb仅解/tmp/luna-shellcheck-20260928。error级0；总控仍有4个既存warning（2034,1090,2207×2），无新warning；新入口与云总控warning0。无应用测试套件。报告scripts/results/luna-deployment-entry-consolidation.20260928.json。
- 提交归档时普通cached diff把保留原入口的归档视为新增，报告旧原字节的尾随空格；未重写历史源码。归档全SHA仍一致，copy-aware `git diff --check -C --find-copies-harder` 与排除legacy后的所有当前文件检查均0。可复核时使用此命令，避免把历史空格当新增代码问题。
- 后续仍属于整理：逐调用方收口旧deploy-kind.conf/Harbor配置与共享镜像工具、平台子脚本目标/私有凭据入口；把已废旧说明/引用清完，完成共享消费链再继续正式迁移。实操准入：main/消费者/真实Docker-CI推拉、正式30443维护、完整重启/重建独立性、云闭包仍待完成；最终剩余清理必须最后执行，不删旧节点/卷，不通知“luna做完了”。

## 最新续接：2026-09-28 取消一分钟附盘轮询，修复反复 Windows 弹窗

基线 b23f1a6d。部署入口整理仍是主任务，尚未移动 legacy 或改总控；期间所有者要求核查旧 WSL/Harbor 障碍，随后反馈频繁 Windows 窗口并质疑每分钟检查。

- 找到 utils/HARBOR-KIND-EXTERNAL 两份 2026-03-04 外置方案，未找到放弃原因；旧 harbor-wsl-setup-changes.md 明确记 EOF 源于 dockerd NO_PROXY 缺 Harbor。不能认定这是唯一历史原因，也不能宣称所有 WSL 问题已解决。新 registry-platform/docs/wsl-feasibility.md 汇总证据及真正 Docker/CI、正式入口、重启和 KIND 重建独立性门槛，原旧外置文档仍未归档。
- 弹窗原因：刚注册的 sunmoon-data-mount 每分钟直接 powershell.exe，没有隐藏参数。所有者质疑后改为仅登录触发，保留 Interactive/Highest 所属用户、SHA/UUID/维护守卫；wscript 无控制台入口等待 Hidden PowerShell 返回退出码，不启动服务。
- 新 run-sunmoon-data-hidden.vbs 发布于 C:/wsl-disks/scripts/storage-automation-20260928-v2，SHA131877883b2ac97a9bd0220b444ef3433792a035ad36e289b5be59e5b66c3b8e，调用原 v1 runner SHA70ca2d6693881940231bdd39acaad9b2853f96d0c7ddbf5e9d523747e0a4c2bd。新 hide-sunmoon-data-task.ps1 的 v2/v3 管理发布在修改任务前因无机器前缀的 zymun 账号无法 Translate 而拒绝，均保留；只读确认 TaskOwner=zymun、Caller=ZYMUN\zymun 后按机器限定账号核 SID，v4修复成功。修复器最终 SHAae1b8e0bf7a6ba67ef791efead9ea0724e233e3edd1ed9f95d442adfa8600649。注册器也已改无窗口/只登录，需要显式 launcher SHA。没有覆盖旧管理副本。
- 原任务 XML 保存在 C:/wsl-disks/sunmoon-data-task-before-hidden-20260928-114605.xml；最终回执 sunmoon-data-task-hidden.json。任务回读仅一个登录触发器，11:46:07实际启动 LastTaskResult0，挂载状态already-mounted、ServicesStarted=false；公开 scripts/results/luna-storage-task-hidden.20260928.json。未更改数据/集群/Harbor/入口，未清理。两PS最终Parser通过；11:50:02只读回查仅一个登录触发器、RepetitionInterval=null、LastTaskResult0，LastRunTime仍11:46:07，约4分钟无重复执行；git diff --check通过。
- 重要未完项：取消轮询后，登录时Ubuntu未运行则跳过；登录后单独重启WSL不再自动触发。必须把按需附盘接入统一Harbor/KIND启动入口，不能把登录任务当覆盖所有重启，也不能绕过严格服务挂载门禁。完整WSL/Windows重启验收未做。
- 回到主任务：用户批准开始整理，保留 legacy/local、legacy/cloud 中必要旧代码及退出条件；旧节点/卷只登记不搬动清理。已读旧总控：KIND infrastructure分支仍调旧deploy-kind/kind-up，旧脚本可重建/清PV；cloud step00/reset、setup-runtime与image-cleanup需归档/禁止误用。旧配置含凭据，不输出或复制到新公开文件。当前工作树只本单元列出的脚本/文档/回执修改，不通知整体迁移完成。inbox仍旧kind。

## 最新续接：2026-09-28 自动附盘恢复与功能盘点；转入部署入口整理

本单元基线620e2cd9dc60d924592cefe3871b5530784aceca。所有者先暂停迁移，讨论后明确“好，那开始整理吧”：优先整理全仓部署功能/调用关系/统一操作入口，旧代码按legacy/local与legacy/cloud分别暂存，明确删除条件；已替代且不再需要的内容由Git留历史。旧节点/卷只登记，不搬动、不清理；镜像及Harbor数据库/密钥/配置/备份保护。不能先整理一层新说明便继续原先零散部署。

- 本次初查新数据VHDX未附加，系统与Docker视角都缺盘；所有者说明电脑原C/D/E分区已格式化、当前只剩C盘。管理员查询271任务，无旧docker-pv或新sunmoon-data-mount。不是旧任务运行失败，旧任务属于原环境，新任务此前尚未注册。
- 所有者明确授权助手执行管理员附盘；通过Windows RunAs/UAC调用已核SHA的v2附盘脚本成功，UUID a28de356-4ba1-4a21-93f5-744b9b9d8be0、三个挂载、PID1/Docker可见性通过；旧路径设备/inode2096/33554434未变，可用39169232896B。没有创建/格式化盘或启动服务。
- 新ensure-sunmoon-data.ps1/register-sunmoon-data-task.ps1已发布C:/wsl-disks/scripts/storage-automation-20260928-v1，目录Administrators/SYSTEM可写、当前用户RX；任务每次核runner SHA70ca2d6693881940231bdd39acaad9b2853f96d0c7ddbf5e9d523747e0a4c2bd及v2/helper摘要。sunmoon-data-mount按所属用户Highest/Interactive登录+每分钟运行，先查维护标记与Ubuntu运行状态，已挂载只检查，不启动服务。首次审批被误取消，确认未注册后按所有者要求重新申请并执行成功；首次LastTaskResult0及后续定时already-mounted通过。完整WSL/Windows重启、未挂载自动修复分支尚未实测；维护须标记+Disable并等运行结束，避免查询/关闭竞态。
- 新mount/README.md盘点挂载/自动挂载/持久化/回收/压缩/备份/旧清理入口；旧E盘文档加历史标记，storage-manager旧文档引用的主脚本不存在已标注。旧cloud image-cleanup两总开关false，有prune-a与通配包删除；kind-up清PV开关false，代码仍在。当前指定cron目录未发现对应cleanup/prune任务；fstrim.timer enabled/inactive，未执行清理或trim。
- 新source_snapshot.py默认plan，check只读，capture有界冻结5写端/PG17.6逻辑导出/4400文件全SHA复用归档/持久恢复日志/恢复原副本和只读设置；recover可显式续接。只读实际预检通过；源数据库只读session、49表10374行47序列读取成功；数据库库存共用方法仅提取传输方法，哈希编码不改。capture/recover均未执行，尚无source-snapshots批次，不能说停写/同步完成。docs/source-snapshot.md明确范围。
- 证据scripts/results/luna-storage-automation.20260928.json；Windows私有操作记录C:/wsl-disks/attach-20260928-luna-v1.log及任务状态/注册JSON。PowerShell Parser与Python AST/defaultplan/gitdiffcheck通过，无应用测试。任务持续运行属于已部署自动附盘功能；未停服务、未切30443、未建main，inbox仍旧kind。正式切换/最终清理/云实机验证均未完成。

下一步：先提交上述中断前同任务改动，再建立当前操作功能表、统一入口与legacy清单；逐调用方调整后才移动旧实现。仍只本地luna，不push。不通知“luna做完了”。

## 最新续接：2026-09-28 最新源在线对账通过、正式过渡代理已创建停止

基线0d04fa7212b258059588d44e8f504997f2f4c7be，本地luna、不push，开工工作树干净。本单元没有源端停写/同步/公开入口切换；最新源对账是在线两次观察，不能替代冻结后切换门禁。

- 新entry_reconcile.py默认计划，--apply持统一锁，仅GET旧源并启停只读main。主副本仍3原项目64仓库165顶层/429可达/164tags，与旧源全目录和元数据一致；新增两个验收项目匹配已恢复managed备份。旧源前后两次目录/身份/策略稳定，旧三节点身份/挂载不变。公开scripts/results/luna-entry-reconciliation.20260928.json。
- 修正host_identity_verify.collect覆盖盲区：/robots默认只列system，项目机器人按官方2.13.2 handler/robot.go的q=Level=project,ProjectID=<id>逐项目分页。旧源users列表0/system robots0/project robots0，管理员旧凭据两端认证通过；源原项目成员/metadata/选定配置一致。目标试验机器人ID6/7/8禁用、权限仅各自试验项目。历史0机器人结果不能当时就解释成包含项目机器人；此次补查实际亦0，没有发现遗漏原机器人。
- 首次v1策略比较failed，私有快照均保留。只差两条ID0 Local harbor src_registry.url：旧http://sunmoonai-harbor-core:80、新http://core:8080。复核本机已缓存官方源码/tmp/luna-harbor-v2.13.2-source.tar.gz中pkg/reg/manager.go和lib/config/systemconfig.go，此地址由部署CoreURL生成。v2仅允许这两个精确拓扑地址对应，远端URL/凭据/其余策略字段仍比较，passed=true；没有修改策略或触发复制。原两复制策略manual。私有目录main/entry-reconcile-20260928-v{1,2}。未核全数据库等价/密码散列/所有配置，未冻结源，不以成功报告准入切换。
- sni_proxy现在允许公共profile prepare/create/check/stop，start在CLI与Proxy.start两层继续拒绝等待单独维护流程。新增config/sni-local-transition.json，实际prepare/create通过：sunmoon-sni-transition-main-20260928，IDd969eaf924b523acddc2149a3c6233049ea20fb28d745ea4c6688bef45a4c887，image sha256:8f84ed99befc3891b8f329c5c202785278a2cfb7c25107d57fb2a134a3117433，created/running=false/restart=no。只有公开配置bind，无卷/私钥。目标30443未监听，旧CP仍占原端口。旧worker ID/network/IP仍精确固定，WSL重启后复核不能自动采信旧IP。
- 新formal/lifecycle.py显式check/start/stop；start核挂载UUID/服务视角20GiB/六原路径存在及同盘、不mkdir，节点ID/镜像/挂载/端口/restart=no，原UID和1.36.4客户端服务端，等待Ready。失败仅停本次启动的节点；stop保留节点/卷且不以容量不足挡住。仅AST/default plans及当前不存在正式锁时的只读check拒绝实测，没有main实际启停或自启安装。创建强杀的恢复/固定代码发布/systemd接线仍待完成。
- 收尾scripts/results/luna-entry-preparation.20260928.json：旧Harbor7控制器1/1Ready；main停止；运行只有旧/136六节点；卷46；旧入口严格TLS/health成功。没有清理、下载新物料、云部署、应用测试套件、main创建或inbox更新。4个Python AST、默认plans、git diff --check通过。新read-only采样controller UID可用于未来维护，但操作前必须重读；没有后台会话。
- 下一步是实现源端停写、最新逻辑备份与最终数据处理，以及正式入口切换/恢复执行器，再把所有者WSL压缩/停旧CP窗口做成可执行操作卡。不能因为公共proxy容器已准备，就直接绕过start门禁调用docker start。当前不要求所有者批准尚未备齐的维护步骤。全项目余项仍有main/CNI/共享平台/registry信任、真实Docker与CI推拉、重建独立性、云共享闭包、最终其余清理。inbox依旧kind/原~/.kube/kind-config/匹配1.27.3工具；旧worker2/所有卷保护，不通知“luna做完了”。

## 最新续接：2026-09-28 限定空间回收与新managed备份独立恢复通过

基线5248faaebb8462465452b62f15db98caed2ea38c；本地luna、不push。本单元先新增正式KIND创建/CNI代码，现场只读准入因新版备份未独立恢复拒绝；随后所有者明确批准“同意，仅这两处提前回收”，这个例外覆盖仅两处历史registry内容，其他清理仍最后且必须做。

- formal/cluster.py默认计划，create/install-cni必须--apply。创建要求新版备份独立恢复、受管正式30443已服务新只读Harbor、旧CP已由另行获准维护停下、固定旧三节点身份和全新main目录/端口/容量。三节点六挂载、记录工具/镜像/SHA/UID/kubeconfig，--retain不自动删除，finally仅新节点restart=no。CNI复用infrastructure/materials/cluster_config.py提取的calico_for_network，导入锁定3镜像，客户端/服务端1.36.4核对，等待节点与控制器Ready。创建/CNI仍未实机执行；异常崩溃可能越过finally，自动启动/中断续接尚待实现。云renderer前后fixture一致38对象，无云操作。公开luna-formal-kind-executor.20260928.json保留此前预检拒绝事实。
- restore_space.py完整复核旧host-main备份及2×4400文件、精确容器ID/停止/restart=no、物理C门槛后，只删除/data/harbor/candidates/harbor-2.13.2-20260927/recovery/registry与/data/harbor/instances/sunmoon-harbor-backup-20260927/registry内已核验内容，空目录保留。各净释放17890086912/17890078720B，扣新增收据整次净35780136960B（33.32GiB）。已保留私有可续接日志/data/harbor/reclaim-history/registry-copies-20260928-v1。两个旧演练root留下retired-registry-copy.json；host_runtime与recovery启动均拒绝，不删除标记直接重启。全部备份/数据库/密钥/配置、当前main、旧节点/卷和candidate输入保留。
- 审批清单SHA3c466a57985d3ff484826bce00e2ecc5cfa8ca6e11ce957f8128d7a865909d44；公共luna-restore-space-audit与luna-registry-copy-reclaim.20260928.json，docs/restore-space-exception.md。执行前Cfree92685406208B/dataVHD84628471808B，扣满100GiB增长+节点10GiB+2GiB后C57054793728B，过50GiB。没有压缩，不声称C物理立即释放33GiB。
- /var/backups/sunmoon-harbor/host-managed-20260927-v1在全新sunmoon-harbor-managed-restore-20260928恢复：4416文件17850818515B全SHA；PG17.6逻辑恢复49表11216行库存全同；严格CA/五年叶TLS、5项目66仓库167顶层/431可达/166tags一致，431manifest原始SHA与121690112B层通过，匿名拒绝和原30443realm保持。新runtime scanner/writer布局全部恢复，11基础/辅助+3writer容器及初始化器均保留。
- 恢复实例existing-registration实测：UUID07d3f625-ba80-11f1-b91d-a6673bbf47a3、5项目映射、真实Success/150发现、Core重启保留、恢复队列27键未清。reportSHA6b6f232042c8abe69f748c35b791068012ca3609565115305bbfb7a4291d578b。结束恢复只读且停止。record-restore新增scanner通过与writer三容器/挂载核对门槛，记录restore_verified=true/restore_writer_layout_verified=true/restore_writer_push_verified=false。未在恢复副本做push，不继承源实例结果。
- backup.json追加验收后SHAa7ca029de19eb28c3de7bda8b3a7e91ae6e7fafd15d6588e826e7ae7ca07f94e；registry/runtime归档SHA051b720a7def2b6aa41c2969e175011d5c4eed7302586688c7a3112070cbabc1和5ce7edca297ec028d3da31ccfe81393f52fccf6b7bd1d728cc82dbe4ebd26454不变。公开luna-harbor-managed-restore.20260928.json；私有详细回执在新实例scanner/recovery-verification-v1及runtime-state.json，源备份不含新增凭据外传。
- 收尾辅助脚本首次按Docker挂载列表顺序比较断言失败；复查三节点路径/卷/权限/端口相同，按Destination排序完整列表重核通过，formal保护比较同样修正，不忽略字段。最终main和恢复副本全部停止、main mode=read-only，仅旧/136六节点running，卷46，旧三节点ID/挂载/端口相同，datafree39172280320B（36.48GiB）。没有旧CP停服、入口切换、main创建、云部署或应用测试套件。
- 本单元8个Python AST、默认plan及git diff --check通过；上述备份/恢复是已授权实际迁移验收。唯一物料手册与备份/入口文档已更新。旧演练示例被明确标记退役，不可继续直接运行；新恢复实例占用保留，不自动再清。剩余正式入口执行器/源端冻结同步/自启、main集群与共享平台、真实Docker/CI推拉、重建Harbor独立性、云闭包与最终其余清理继续。旧控制面具体维护窗口尚未批准，WSL压缩仍由所有者合并入口窗口操作。inbox仍旧kind、~/.kube/kind-config、匹配1.27.3工具。不要通知“luna做完了”。

## 最新续接：2026-09-27 旧入口身份盘点和38443过渡候选实测通过

基线94c16285a3876ac354db5de8f8bc1173bad7dd59；本地luna、不push，开始工作树干净。本单元补P3前置实际证据；正式创建器/正式切换执行器仍未实现，不能误报本轮完成建群。

- 新entry_handoff.py默认计划，--check仅GET旧API、Docker inspect、无凭据严格TLS GET。固定1.27.3 kubectl SHA、旧kube-system UID、静态kubeconfig端点、原CA SHA。实际三节点身份/端口/挂载/网段、Traefik Service与Ready endpoints已记录到scripts/results/luna-entry-handoff-inspection.20260927.json。旧CP ID790e27...，worker ID6b0fef... IP172.18.0.3，worker2 ID7d5e66... IP172.18.0.4；不要仅按IP取代身份核验。
- Traefik ingress-platform-dev/traefik-sunmoonai，NodePort30080和30443–46，externalTrafficPolicy=Cluster；Ready端点10.244.1.16在kind-worker。旧公开30443及两个worker直接访问，Harbor/v2均401、health200healthy、原CA/hostname严格验证且证书DER SHA一致。sunmoonai.com根路径404仅TLS/HTTP路径证据，不是业务验收；实际停止旧CP后的可用性未验。
- sni_proxy增加transition-candidate（回环38443→18443/固定旧worker30443）和仅预览transition模式；后者及formal实际动作继续拒绝。prepare/start前固定worker容器ID/网络ID/IP/running状态，漂移失败；不自动换后端。sni_verify复用任意已准入候选端口/默认上游并要求Harbor mode=read-only，原28443保持兼容。
- 实际创建sunmoon-sni-transition-candidate-20260927，ID ec3e40eb1870f17c9ad32c3506ec7219ef1e637df1b978a4894512895445c233，镜像仍官方已锁NGINX1.30.5，无数据卷/私钥挂载。38443完整候选验收通过，结果scripts/results/luna-sni-transition-candidate.20260927.json：新Harbor严格TLS/401/token realm保持30443，6种ClientHello路由符合（其他域名/无SNI为路由观察），nginx版本/模块检查通过。私有acceptance-*在/data/harbor/entry-proxy/该实例下。
- 结束新代理/新只读Harbor停止保留，docker ps运行只有旧/136六节点，卷仍46。未停旧CP/worker2、未切正式30443、未清理、未下载/造镜像、未改inbox、无云操作/后台会话。AST/默认plan/render/gitdiffcheck通过，无应用测试套件。没有为本轮再盘点容量；前段容量快照仍需动作前刷新。
- 清理依赖提醒：公开harbor-main-local.json.source仍指/data/harbor/candidates/harbor-2.13.2-20260927，runtime_inspect.inputs还读取该处generator-state/inputs-receipt/private/compose/generated-config。最终清理不得把整个candidate目录当废物直接删；必须先解耦/保留必要输入，逐项列文件与恢复来源。本轮没有执行任何清理。
- 新docs/entry-maintenance.md列出维护顺序、停服影响、只读切换与写入后回退的不同边界：P3默认旧worker临时转发，P4后验证19443再转新集群。TLS-only过渡不承接80/30444–46，旧API43001也停；确切停服窗口未授权。此前方案60–90分钟及30分钟回退上限是建议，不冒充所有者批准。维护前新managed备份独立恢复/最新旧源停写同步未完成。剩余正式创建器/CNI共享接线/自启/真实Docker-CI推拉/重建独立性/云代码闭包继续推进。最终清理必须最后做，旧节点/卷/唯一备份保护，不通知“luna做完了”。

## 最新续接：2026-09-27 正式 KIND 参数与只读预检完成，尚未建群

基线964811057e4091b51e495da5dc81cc24483d6478；本地luna、不push，开始工作树干净。本单元新增kind-infrastructure/formal/prepare.py及README，更新主方案当前状态，公开预检scripts/results/luna-formal-kind-preflight.20260927.json。没有创建器/apply，不能拿render结果直接裸kind create。

- 复用isolated完整验收锁，现场10文件SHA和本地manifest逐字结构核验通过；未写旧物料批次、未下载。配置main三节点/六挂载按批准路径；API17443、pod10.246/16、service10.98/16，TLS下一跳127.0.0.1:19443→node30443，保留原80/30444–46监听；宿主Harbor路径不进KIND。
- sudo只读check实际退出2（未准建群，非成功创建）：存储UUID/PID1/Docker视图正确、旧目录设备/inode仍2096/33554434；新17443/19443空闲，80/30444–46占用。旧/136控制面GET kubeadm-config确认分别10.244/10.96与10.245/10.97，新网段与这些及当前主机路由无重叠。check现在要求旧控制面running；P3停服后未来创建器应消费维护快照并重核容器身份，不为预检重启旧控制面。
- 最新Cfree97992368128B，dataVHDX84628471808B，datafree24355438592B。初始节点预算10GiB+元数据2GiB+数据盘长满剩余增长后C预期62361755648B（≥50GiB）；data初始2GiB+20GiB保留可满足。此预算不含独立Harbor恢复副本/平台增长，不代表恢复空间问题解决，也不是实际配额。Windows只读PowerShell已执行。
- plan/render及Python AST检查已执行；未应用测试套件、未建目录/节点/PV、未改kubeconfig、未启动/停止容器、未清理。check只通过本地Docker socket查询和控制面内GET，不泄露凭据。
- 继续：补正式创建/存储门禁自启/CNI统一接线，以及P3维护卡/执行器。注意现SNI正式preview默认19443在P4前无后端，P3需先按已批准设计临时转发旧worker且核对其NodePort，不能把19443未建成当作全部域名已验。新managed备份独立恢复受空间限制仍未完成；不得降余量或擅自提前清理。旧控制面具体停服窗口尚未批准；owner压缩仍合并入口窗口。inbox旧kind不变，最终清理必须做，整体未完成，不通知“luna做完了”。无后台会话/子agent。

## 最新续接：2026-09-27 持续读写模式、冻结备份与系统盘完整归档通过

基线f0affe960ec940ba05e8612f64c0f696dd480c0c；本地luna、不push。新host_mode.py、writer_config.py；修改host_runtime/host_backup/host_verify/host_write_verify及操作文档。未改平台版本、未打扫描器镜像补丁。

- writer_config抽出试验/受管共用配置生成；main/writer-v1内新固定三个writer容器，共用同一数据目录，原readonly三个停止保留。原host-config.runtime.write_enabled=false为创建/恢复策略，运行模式以runtime-state.service_mode为唯一状态；identity/immutable/check/start/stop均选择对应容器，stop包含两套。普通writable start自动带scan-jobs。转换有mode_transition_open标记，未闭合拒普通启动；失败可显式read-only恢复，不丢弃已写数据。
- 实测prepare、RO→RW、普通start/stop、RW→RO通过。统一create再次执行原/writer全部ID未变。本地共用TLS客户端严格证书/地址核验成功；云分支改用明确私网IPv4:30443并核DNS一致，共用代码但未经实机验证、无远端动作。最终main两套+扫描器全部停止、mode=read-only，配置/模式转换标记false，无后台会话。旧/136六节点running、卷46未变。
- host_mode backup先容量准入再冻结，完成/失败后恢复原模式/运行状态；底层cold_backup拒绝writable。writer-v1和scanner纳入runtime，restore_prepare改写两套Compose新路径/身份，create创建两套停止容器；新增布局完整恢复仍未执行，不能承接旧布局restore_verified=true。
- 数据盘原Harbor占79640641536B：candidate18915119104，旧backup-restore实例17965412352，main21711003648，备份20866928640等。余22.68GiB不足完整新归档+20GiB保留；负例在停服前拒绝，容器状态/状态文件SHA相同。按既有保留/最后清理要求没有删除或搬移任何副本。
- 新支持WSL系统盘/var/backups/sunmoon-harbor/host-*（root私有），实时PowerShell读Cfree与dataVHDX Length；扣新备份+2GiB余量+data盘增长至100GiB后须C≥50GiB，不能拿WSL虚拟free代替C。系统备份和数据盘仍同物理盘，无机器外灾备。默认云不使用该系统盘适配器。
- 实际完整备份/var/backups/sunmoon-harbor/host-managed-20260927-v1完成：4416文件17.8508GB；49表11216行；5项目66仓库431reachable/166tags（含v1/v2验收项目）。registry.tar17868113920B SHA051b720a7def2b6aa41c2969e175011d5c4eed7302586688c7a3112070cbabc1；runtime.tar2996203520B SHA5ce7edca297ec028d3da31ccfe81393f52fccf6b7bd1d728cc82dbe4ebd26454；manifestSHA75ad11988835c82dfd635da5d649eafa7c650fb23df5c8138680e4ea46da6b8e。全tar和逐成员SHA核过，restore_verified=false。流程起始writable stopped→冻结→备份→恢复writable stopped通过，再主动RO收尾；运行中备份并恢复运行分支未实测。
- 公共scripts/results/luna-harbor-managed-mode.20260927.json，私有writer-v1/{lifecycle-verification,read-only-final,backup-capacity}.json、mode-*.json/dump、backup-run-*.json。最终Cfree98056019968B，dataVHDX84628471808B，data满100GiB后预计C余75310309376B；datafree24355438592B，rootfree485748375552B。没有清理、WSL压缩、入口切换、云操作或新main。AST/defaultplan/gitdiffcheck通过，无应用套件。
- 下一步：新完整备份独立恢复仍受容量安排约束，不能盲目降门槛；Docker实际推拉/CI、最终旧写端冻结同步、正式SNI窗口（旧控制面停服具体授权尚未取得）、main三节点双挂载及重建Harbor独立性；云SSH前置/离线工具闭包/自启继续未完。发现旧deploy-kind.conf仍1.27.3+RECREATE=true，kind-up已有绑定kubectl/UID历史保护；正式main绝不能走这个历史配置，需新正式入口接统一平台流程。inbox仍旧kind/原kubeconfig/匹配1.27.3工具。最终清理必做，旧节点/卷/唯一备份保护，不通知“luna做完了”。

## 最新续接：2026-09-27 宿主候选镜像推拉、权限负例与只读重启读取通过

基线d90762d3ed8dfe6443acb3c23100848eaa231266（受管scanner/备份单元已提交）；本地luna、不push。本单元新增host_write_verify.py与操作文档，host_runtime普通start增加write_acceptance_open保护。

- 新脚本只接受已停止且scanner验收完成、同实例完整备份、独立盘20GiB余量；原8服务/官方镜像不改。独立write-acceptance-v1/v2中生成三个临时registry/registryctl/core可写容器，共用候选数据目录；原对应容器停留。每轮预备PG17.6逻辑dump，API写窗口有持久journal；旧30443与节点完全未改。
- 首轮真正推拉成功，但负例误以为请求scope=pull会缩小已有写入账号权限；官方2.13.2 repositoryFilter直接按账号授权重设Actions，实际允许写。因此v1失败，账号6禁用、APIreadonly/停止恢复通过。不得将该问题说成版本不兼容或私有权限完全失效。v2独立项目/账号7写入、8只读，权限分离后真实上传/摘要拉取与匿名拒绝/只读拒写均通过；原项目目录完整一致。两账号结束均禁用。
- 新manifest sha256:a32ee319d77cd79e4d3973d5514315daf5b5f563d4aa320c4b87018fe931cd2b，config/layer/manifest782B。随后以原只读容器启动、管理员鉴权拉取三个对象全SHA相同后停止，证明宿主数据保留；不是KIND重建验收。v1/v2三个额外容器全部停止保留，main12容器停止，运行仅旧/136六节点，卷46，数据盘free24359378944B。无后台任务、无清理/入口变更。
- 私有结果main/write-acceptance-v2/result.json和read-only-restart.json；公共scripts/results/luna-harbor-write-acceptance.20260927.json。读回引用规范30443，实流量只经18443，不表示旧仓已有验收镜像。最后配置检查补了Docker CAP_前缀归一，全部六个停止容器配置核对通过。AST/defaultplan/gitdiffcheck通过；未跑应用套件。
- 备份host-scanner-20260927-v1保持原字节且新布局独立恢复尚未完成；当前registry新增两个canary项目，下一份备份不能盲目复用旧registry.tar。数据盘22.69GiB余量不允许完整新副本同时保留20GiB，不私自清理/降低门槛。旧布局恢复已验不代表新布局已验。
- 继续主线：永久可写生命周期与冻结备份、Docker/真实CI、正式30443窗口（旧控制面停机尚须具体授权）、main三节点双挂载及重建Harbor独立性、云统一代码/离线闭包/自启。尚未建main或切换；inbox仍旧kind/原kubeconfig/匹配kubectl1.27.3。最终清理强制保留，所有旧节点/卷/唯一备份保护，不通知“luna做完了”。

## 最新续接：2026-09-27 受管官方扫描器、统一启停与完整备份已通过

基线cee60c87e7c3cd281735d6d661b8e3ce8d3451f5；本地luna、不push。遵照所有者不做自制补丁镜像、优先集群迁移；官方scanner镜像不变。新host_scanner/host_scanner_verify将trivy、内部registry-route和独立队列scan-jobs纳入宿主Compose、启停和备份；原8容器不重建，旧jobservice停止保留。

- 默认登记sunmoon-trivy，UUID07d3f625-ba80-11f1-b91d-a6673bbf47a3；实际扫描150发现Success、3项目映射相同，Core重启仍保留。报告SHA8246529b6a40832f270a8dabd173736b5a08512121adf96ab35e239310396f49。第一次登记名含空格触发Trivy凭据列表按空格拆分，v2更名保留UUID通过；v1失败与私有日志保留。prepare首轮公开锁误走私有权限读取失败，严格复核旧配置/缓存后续接。均非版本不兼容。
- 统一start --with-jobs真实通过，之后统一stop；main11服务+初始化器停止，旧kind/136六节点running，卷仍46。五年证书严格验证，registry物理RO、APIreadonly恢复；30443仍旧生产。没有推镜像或清理。无后台任务。
- 新冷备份/data/harbor/backups/host-scanner-20260927-v1 complete=true；49表11156行；4400镜像文件17.85GB逐文件一致后硬链接已独立恢复的旧备份完整registry.tar，非链接实时数据。runtime新归档2.993GB含scanner/全目录。新备份restore_verified=false，另行独立恢复未做，--existing-registration分支仅静态/默认计划。数据盘可用24361865216B，不能在当前余量内再复制完整恢复实例并留20GiB；不可偷降门槛/提前清理。归档硬链接清理不能重复计回收量。
- 新部署preparation.scanner中registration_managed=false是准备时旧字段，不代表已登记失败；实际登记状态以runtime-state.scanner_acceptance与v2回执为准。后续代码改为registration_separate_step，不改写旧备份。
- 公共结果scripts/results/luna-harbor-managed-scanner.20260927.json；docs/host-scanner.md含失败修正与边界。下一步可写迁移/推拉CI-CD、正式入口窗口、main双挂载及重建独立性、云共享代码闭包和自启。最后清理仍必做，旧节点/卷/唯一备份保护。inbox仍旧kind/原kubeconfig/kubectl1.27.3，不通知整体做完。

## 最新续接：2026-09-27 所有者停止自制扫描器补丁，运行观察与身份迁移核对完成

基线af0149c091d7a45b1b7c49a1bb73d78f0aeb588c；本地luna、不push。所有者最新要求：不要自行打扫描器系统包补丁/自制镜像，核运行调用，未用于当前路径的问题作为已知项随官方升级，优先集群迁移。此决定覆盖前段“先安全补丁再迁移”的自定顺序；不要继续那条路线，也不要要求零CVE。

- 决定到达前东京已下载10个固定Photon官方RPM，共6655410B，primary SHA758424263d80240594fbb648ee1f7d04c865bbccb40560b8cbffd07c12c5ea97，锁SHA57638e3d18b22914d22ea14979d65fc655d4074e02ae363065b09662595d499b。本机releases/scanner-patches-20260927-v1；远端/home/zym/sunmoon-scanner-patches-20260927-v1。构建容器sunmoon-scanner-os-patch-build-20260927-v1退出1，首RPM签名实际OK，但脚本大小写匹配失败，未执行RPM安装、没有commit/export镜像。工作目录releases/harbor-scanner-osfix-20260927-v1保留，两个未提交补丁脚本已撤回。只列最终清理候选，不重试。
- 新scanner_runtime_observe.py只读/proc exe/maps/线程children，不读参数环境凭据；scanner_adapter_verify新增--observe-runtime，固定新批次releases/trivy-harbor-runtime-20260927-v1。原官方manifest215c07...未变，完整Harbor扫描再次Success，报告SHA8f4547a6f5b26336684c7f362e3b1dd037d35a6c889a96bb286a38274a892fd9；临时登记撤销/APIreadonly恢复，全部试验及候选容器停止。
- 运行8.32秒164次50ms采样，观察/home/scanner/bin/scanner-trivy和/usr/local/bin/trivy，两者共享库映射为空、无采样错误。结合已核ELF及官方v0.38.0 wrapper直接exec Trivy，支持本次扫描主流程未用这些系统动态库；不声称所有helper/输入均排除。Dockerhealthcheck不是子树采样对象，配置确实使用curl回环探针且fallback-k；正式配置覆盖为单一固定回环HTTP，registryTLS仍严格，不改镜像。Go内嵌依赖问题另记，不以静态链接宣称无漏洞。公有源码仅下载到/tmp/luna-adapter-v0.38.0-source.tar.gz，未执行。
- 新host_identity_verify.py GET核对旧30443/新18443管理员认证、用户/robot权限/项目成员/metadata/指定配置。v1因scan_all_policy为直接对象不是value项而KeyError退出并停源，v2按官方schema修正后通过。3项目、3成员，users/robots列表都0；不代表admin不存在，/users/current确认sysadmin。无普通用户/机器人令牌实际登录，未修改账号/口令/权限/正式扫描器。
- 证据luna-trivy-runtime-observation.20260927.json与luna-harbor-identity.20260927.json；README/扫描器/实例/唯一物料手册已更新。本轮无新镜像、无入口切换、无清理、无云部署；无后台任务。最终清理旧节点/卷保护仍有效。
- 下一步回迁移主线：将已验证官方扫描器变成受管永久服务/默认登记，并纳入启停/备份；推进可写推拉及CI-CD，再准备正式SNI切换窗口、main双挂载建群/重建独立性。旧controlplane停止影响API/80/30444–30446，具体窗口仍未批准。云共享代码/离线工具闭包/自启继续未完；inbox仍旧kind/原kubeconfig/kubectl1.27.3，不通知luna做完了。

## 最新续接：2026-09-27 新 Trivy 与 Harbor 完整扫描链路通过，正式准入未完

基线7ca58af1083901ea242bc8b8fbc94b3cc2d5f192；本地luna、不push。本单元交付为包含本段的提交。用户决定先完成Harbor2.13.2迁移，再独立升级；PG17.6/Redis8.2.1不变。最新问反复卡住是否版本不匹配：本次实际完整链路Success，前几次为验收代码问题，不能归因于版本不兼容。

- 新候选官方trivy-adapter-photon:v2.15.2，manifest215c07b71c37fc7fc16e02d9185d936dcb8884a80e810817c2cd058bbd7c4e98，实际Trivy0.72.0、adapter自报dev。东京仅下载公开物料，回本机唯一物料根全图摘要验证；没有云部署。独立rootfs扫描487包，CRITICAL17/HIGH82，formal_admission=false，详见scanner-offline文档与脱敏证据。
- adapter-v2直调私有nginx固定摘要成功。完整链路v1 Harbor已Success，但验收报告结构判断错；v2 Jobservice卷尾斜杠判断错；已修正，v3完整通过。首轮还修了报告media type造成的415。失败均留痕；不删除试验容器、缓存、Redis键。
- 完整成功批次releases/trivy-harbor-chain-20260927-v3，Core/Jobservice2.13.2→Trivy0.72.0，150条发现与直调一致。registry数据始终RO；候选API临时开放元数据写入，事前pg_dump，结束移除临时登记、恢复readonly。新Jobservice采用独立空队列命名空间，原试验26键保留。metadata_acceptance_open持久标记阻止中断后普通启动。永久登记仍false，不把临时兼容验收当正式接线完成。
- v3三个辅助容器和main9容器全exited；旧kind三个节点仍running；Docker卷46。最终只读盘点系统盘可用509658574848B，数据盘30347182080B。无后台任务；无入口切换/推送/旧节点清理。试验目录最终清理仍必做。
- 新prepare_scanner_candidate/scanner_adapter_verify/scanner_jobservice_verify及stable锁；复用数据库stage函数，HTTP Accept可显式指定；host_runtime加入未闭合元数据窗口启动保护。完整链路回执scripts/results/luna-trivy-harbor-chain.20260927.json；README、唯一物料手册、扫描器文档及Harbor版本决策均已同步。
- 下一步优先解决扫描器候选自身curl/NSS/OpenSSL发现，核适用性/固定修复及健康探针（继承curl备用-k），再永久登记/认证推拉/机器人/CI-CD、数据库定时更新及Java样本。完整安装/正式main双挂载/重建独立性、云只打印闭包、自启、正式30443维护窗口继续未完。不得跳过最终清理；保护旧节点/卷/唯一备份。整体尚未完成，inbox仍旧kind/原kubeconfig/匹配kubectl1.27.3，不能通知luna做完了。

## 最新续接：2026-09-27 Trivy原镜像与离线数据库、隔离扫描已核，正式版本待安全评估

基线8ff8b4968cbdbfd1f044e2cc1adfed2a9d490560；本地luna、不push，起始干净。用户继续推进，中途问旧镜像可否使用；已回答先复用隔离验证，实际发现严重问题后明确不能直接作为长期正式版本。交付为含本段的提交，整体迁移未完。

- 旧Trivy实际StatefulSet sunmoonai-harbor-trivy / namespace cicd-platform-dev，在kind-worker2，Ready、restart0。release label是sunmoonai，不是sunmoonai-harbor。原镜像bitnami/harbor-adapter-trivy:2.13.2-debian-12-r2；trivy --version为0.64.1；adapter metadata为dev/Unknown。临时loopback28080 port-forward读metadata后已关闭。尝试scanner-trivy --version不支持该flag，实际短暂启动第二进程，8080绑定失败后5秒timeout退出；未提交扫描任务，旧资源未改。
- 原缓存仅空目录12KiB；coldbackup trivy.tar/trivy-active.tar各10KiB。不能用Pod Ready证明扫描已成功。原镜像在固定coldbackup preparation/images/kind-worker2-harbor-amd64.tar，sourceSHAeef8fa55e3847e351c1989ccd675c5de4606ca2ee2ed00efc966e27c434b0c61；prepare_scanner.py抽取单镜像OCI、全图SHA核验。新物料releases/harbor-trivy-2.13.2-original-linux-amd64，97,976,320B SHA2232799c70feb49731350f872af70e0c33fae320b9a2189b473d146c6d4392c1。Docker已load，实际imageID为amd64manifest7c973faed0944ae77350605ea85d5a9d592fd1258e5bd0ad6f3feb701f826d1e，无声明卷，UID1001。
- prepare_scanner_db.py resolve/download/verify默认只打印；东京只执行public source viaSSH stdin，/home/zym/trivy-db-20260927-v1。两官方GHCR数据库manifest固定，全部压缩/解压字节校验；noDocker/noextract/no部署。rsync回本机同名release目录并再次完整核验。db格式2、UpdatedAt2026-09-27T07:04:17Z，Java格式1、01:08:08Z；压缩合计1,096,889,723B，解开2,986,643,742B。锁SHAeb4a458976d50357c844edc9b5cf87f6eee5fe24a5cf288cc7e5530b25e5bf16。repo scanner-db-20260927.lock.json。准入最大年龄db48h/java7d，不代表定时更新已接通；物料不是发布者签名认证。
- scanner_verify.py本机新目录rootfs实际验收：固定原镜像、networknone、UID1001、只读root、capdrop/nopriv、2GiB/2CPU、无端口/凭据/socket/管理卷。数据库必须在专用可写缓存，原归档保留。首次v1因目录umask和只读DB失败，仅修目录重试仍失败，日志保留；v2新独立缓存UID1001/dir0700/file0600可写后通过，识别954包，报告SHAf3124025d612c690e35501591610258d58e9fb2136e64a31f04ec812db9a5c75。Java归档全验但没有Java样本扫描；Harbor/adapter/jobservice/privateimage/CI-CD未验。
- 两试验实例路径releases/trivy-offline-trial-20260927及-v2，容器sunmoon-trivy-offline-20260927 exited1、-v2 exited0，v2 ID7b3634defdcf4fdec7f27f7821e7a207f8eeee0d82f8a55f848979c4952ff017；各0管理卷，总卷仍46，旧/验证6节点running。数据盘没再复制17GB，缓存放系统盘；约5.56GiB试验副本仅列最终清理候选，不现在删。没有Harbor启动/配置/入口切换、云部署或清理，无后台任务。
- 关键结论：原镜像自身扫描23条CRITICAL、309HIGH，CRITICAL去重9CVE，含SBOM/多包重复。formal_admission=false。已核Go CVE-2025-68121 TLS会话CA变化前提、grpc CVE-2026-33186服务端路径鉴权前提；Debian的CVE-2023-45853不应直接按zlib二进制可利用认定。其余尚未逐条适用性评估。不能把全部发现当可利用，也不能忽略后直接正式运行。docs/scanner-offline.md有来源与边界，证据scripts/results/luna-trivy-offline.20260927.json。没有决定/安装新扫描器版本或改PG/Redis。
- 当前下一步：核维护中的scanner/adapter最小安全修复候选与Harbor2.13.2接口兼容，随后恢复/映射扫描登记、Jobservice和私有镜像扫描。原8服务readonly副本WITH_TRIVYfalse问题仍未修，不能晋升正式。可写/推拉/CI-CD、共用安装/工具离线闭包/云SSH前置、挂盘自启、SNI30443维护窗口、正式main双挂载/重建独立性继续未完。旧controlplane停机窗口仍未批准，inbox仍旧kind/原kubeconfig/匹配1.27.3kubectl。最终清理必须最后做，保护旧节点/卷/备份。不能通知“luna做完了”。

## 最新续接：2026-09-27 宿主只读实例备份/独立恢复已验收，发现扫描器迁移缺项

基线53a7fffa（SNI候选已提交），本地luna、不push；本单元起始干净。交付为含本段的提交。用户本轮补充东京空间已腾出，实测22,092,984,320B=20.58GiB，超过原8GiB pull门槛，后续可拉取导出；不重复下载已验NGINX。

- 新host_backup.py默认计划，backup/verify/restore-prepare/record-restore；只接受已对账/验收、起始停止的只读源。本机UUID/PID1/Docker、主机生命周期锁、精确容器/镜像/配置、空间门禁；取得新catalog后停源，仅开PG17.6逻辑导出/前后全表等对账，再全停归档registry+明确私有runtime/身份/Redis/joblogs。只普通文件/目录、UID/GID/mode、全tar SHA+逐成员SHA/blob路径；备份root0700/files0600。失败保留、无cleanup/旧生产停写/外传/云执行。
- 实际备份/data/harbor/backups/host-main-20260927-v1，registry.tar17,868,021,760B SHA db2fad362a3e9b5d205e55764dc3ad8a675025e7a666ec759e53a5e8c9fbea3c；4400文件17,850,816,895B。runtime.tar1,116,160B SHA886b76caa15fa15412050ce8d001effc67e8665aee387eb2df01f4cf06ffc738。private backup.json约1.45MB，含逐文件目录，公共证据记录其最终SHA。
- restore-prepare新root/data/harbor/instances/sunmoon-harbor-backup-20260927；从备份私有runtime直接复用，Compose只改project/container/network和host路径前缀，保留原compose/host-config文件。源密钥/CA/叶不再生成；新registry完全复制重读SHA，PG目录空。target config就在root/host-config.json。复用host_runtime create、host_restore、host_verify，9容器均stop/retain。
- 实际PG17.6恢复49表10,792行及结构/角色/行SHA/序列等完全等于新备份；Harbor TLS五年叶、3projects/64repos/429reachable/164tags目录通过，429manifest原始字节SHA及匿名拒绝、121,690,112B层SHA ba9916be9d18f219a90a7eedd7d6a179dd9aecd3b38dc87d5ea85fbac2e18a2a通过。record-restore全备份重核，restore_verified=true；不表示正式生产备份或写入验收。
- 重要新发现：新主副本较最初旧快照恢复基线，audit_log_ext3478→3907(+429)，scanner_registration1→0，总10364→10792。实际新core/env仅白名单读到WITH_TRIVY=False。官方v2.13.2 src/core/main.go registerScanners在WithTrivy=false时移除不可变Trivy登记。此前全表一致是Core启动前，不能说启动后所有DB配置仍旧一致。
- 已只读查询旧30443：healthy；Trivy URL http://sunmoonai-harbor-trivy:8080，disabled=false/is_default=true，API未给adapter/version/health，不能推断扫描器Pod健康。旧源和最初备份未改。正式写入前必须核旧scanner精确镜像/配置并同版迁移/映射，补扫描/Jobservice验收；当前禁Trivy的8服务副本不得直接晋升。没有用SQL补回或掩盖差异。
- 现场：源main9+恢复backup9容器均停止（jobservice created），SNI候选停止；旧/验证6KIND节点running，旧Harborhealthy。卷仍46，本单元0新卷；SNI最初3个误建检查卷仍保留。数据盘可用30,350,438,400B≈28.27GiB，不能盲目再复制整套17GB；后续写入生命周期需考虑复用数据并保留受管旧容器，不能以空间为由清节点/卷/唯一备份。无后台任务。
- 证据scripts/results/luna-harbor-host-backup.20260927.json；方法registry-platform/docs/host-backup.md；README/host-instance/唯一物料手册已补。1PythonAST、4默认plan、git diff --check；未测试套件。外部传输目的地仍待所有者选，只有目录接口，没有外传。云端未经实机验证。
- 下一步优先核原Trivy实际部署与离线物料，修正式配置保存原scanner/其他非镜像配置；可写/Jobservice/认证推拉/CI-CD、通用全新主机安装/工具闭包/挂盘自启动/云SSH前置继续未完。然后正式SNI维护卡（旧controlplane停止会影响API/80/30444–30446，窗口未批准）、main双挂载/共享平台/独立性重建验收。业务E2E最后，最终清理仍必做且最后，不删容器/卷。inbox仍旧kind/原kubeconfig/1.27.3kubectl，不能通知luna做完了。

## 最新续接：2026-09-27 本地 SNI 候选已验收，正式入口未切换

基线59b94f7d0b42376500636f74de6d3d95c26facac，本地luna，不push；起始工作树干净。交付为包含本段的提交。

- NGINX1.30.5-alpine官方index/amd64固定摘要，经东京prepare_sni.py直接HTTPS下载压缩OCI、归档回本机唯一物料根。26,112,000B SHA cca17bf6af939d0ec69bfe92782e8e392cf50ae19cd2d1902fbed36aa028768d；10必要blob含8层全核。远端/home/zym/sunmoon-nginx-sni-20260927-v1/materials；未docker pull/解包/云部署。来源HTTPS与固定摘要，未独立发布者签名。原Harbor/PG/Redis不升版。
- 东京初始余7,945,834,496B不满足原8GiB pull门槛，直接下载维持6GiB门槛/512MiB压缩上限。用户本轮通知已清空间；复核余22,092,984,320B=20.58GiB，后续可用原pull/export，不重复下载这份已验证物料。
- sni_proxy.py默认计划，candidate严格绑定回环28443→精确Harbor18443/default旧30443；formal预览0.0.0.0:30443→18443/19443，只可render，实际动作拒绝。固定镜像、private管理目录、UUID服务可见性、配置内容/容器ID/标签/mount/权限准入；无私钥或Docker socket挂载，host网络UID101/RO/capdrop/nopriv/restart=no/tmpfs/日志容量限制。create停止、start nginx-t、stop保留。
- 实例/data/harbor/entry-proxy/sunmoon-sni-candidate-20260927，ID7141d1a57800e2b54aaffeebc4592d605c0d5a86d18ebdf780298bbf5bf45300。sni_verify.py实际启动新Harbor只读+代理，严格CA/hostname，直通五年叶DER SHA106bab970a87f1d2e5ac749e0efd61cf369f0f8baac7a5283dad7a6d3178e11e匹配；/v2/401及tokenrealm保留30443。6种ClientHello路由观察通过：Harbor大小写18443，普通/未知/伪装后缀/无SNI旧30443；后者不是完整应用TLS验收。完成后finally均停止，旧Harborhealthy/旧叶不变。
- 失误必须保留：最初旧nginx-photon1.26.2模块检查容器sunmoon-sni-module-inspection-20260927未用tmpfs覆盖镜像声明卷，新增3个匿名卷，已退出保留。卷数43→46，旧卷未删。后续实际代理0卷；不擅自清理检查容器/卷。代码准入拒绝新proxy镜像的隐式卷。
- 当前新Harbor9容器均停止（jobservice为created），新代理exited，旧/验证6节点仍running；无30443切换、无旧容器停止/删除、无挂载旧路径、无清理、无后台任务。证据scripts/results/luna-sni-entry.20260927.json；3PythonAST、默认计划、nginx-t通过，未测试套件。
- docs/sni-entry.md说明方法、实测、限制和维护卡前置。30443当前属于旧controlplane，停止也影响API/80/30444–30446；具体窗口尚未批准，不擅自切换。主方案要求先Harbor/入口后main，需如实写整个旧API停机时长，不能用短代理切换掩盖后续平台部署。先补最新冻结/备份恢复/写入验收与管理工具闭包，再就完整维护动作批准。
- 下一步：独立Harbor备份/恢复通用接口、可写/Jobservice/认证推拉与CI-CD、挂盘自动启动、云SSH前置未实机；然后正式SNI/main静动态卷/信任/共享平台、重建集群仓库不丢。整体仍未完成，不通知luna做完了。inbox仍旧kind/~/.kube/kind-config/1.27.3kubectl。最后清理必须做，保护节点/卷/备份。

## 最新续接：2026-09-27 新宿主实例已恢复并通过只读启停验收

基线 `cf246d4794771ba47b936bf48ae8adbd32f5f15c`，本地 luna，不 push，开始工作树干净。交付为包含本段的提交；没有把整体迁移写成完成。

- 当前实例sunmoon-harbor-main-20260927，/data/harbor/instances/sunmoon-harbor-main-20260927，公开config/harbor-main-local.json。Harbor2.13.2/PG17.6/Redis8.2.1版本不变；五年叶用于本实例18443，原30443仍旧Harbor。
- host_prepare.py实际完成新目录私有配置、raw env逐字比对、固定官方镜像导入/身份核对、registry复制；4400文件17850816895B逐文件重读SHA与blob路径一致。独立盘UUID/PID1/Docker可见性及预留空间通过；原演练/旧数据不改。runtime_inspect抽inputs复用同校验，runtime_config增加source_config_sha256字段区分归档config与运行ID。
- 首次准备失败点：镜像load成功后，用archive config ID去Docker inspect失败；本机Docker image ID实际是OCI manifest摘要。保留6官方别名和748544000B runtime-import.tar；只读moby内容读取核manifest SHA→原config SHA、config SHA及diff_ids后，固定真实运行ID。为排查重放过一次load，未启动容器。--resume-before-copy只对同配置/未创建容器/registry空/未prepared的中断点，全部私有文件字节/权限复核，旧Compose和host-config保存，再仅修正ID并续接。当前准备完成不可重复执行。
- host_runtime.py create/check/start/stop：默认只打印，受管标签+容器ID、配置SHA、精确mount/端口/网络/env、restart=no、无匿名卷；create8角色均停止。start要求数据库与层已核对且Jobservice停止，PG和Redis认证探针就绪才启动后续；stop停止保留含初始化器，不down/rm/prune。低磁盘容量不阻止stop；尚无systemd自动启动/离线工具安装/写入晋升。
- host_restore.py在空目标initdb并导入固定globals/registry.dump，复用原数据库库存helper，全表/行/序列/角色/结构/扩展等与逻辑备份逐项一致：49表10364行170006。完成后全部停止，原源数据未改。9新容器=8服务+database-init；状态与所有权记在私有runtime-state.json。
- host_verify.py实际启动7角色只读，五年叶与预备文件DER完全一致、CA严格校验、原凭据仅发18443；全目录3projects/64repos/429reachable/164tags。429manifest原始字节及响应digest全核，121690112B layer sha256:ba9916be9d18f219a90a7eedd7d6a179dd9aecd3b38dc87d5ea85fbac2e18a2a匹配，匿名私有manifest拒绝。结束stop并保留，Jobservice未启动、push未验。
- 目录验收前两次拒绝；保存快照后查明97个references仅排列不同，制品没有增删且所有字段/内容/重复次数一致。仅references最外层按完整JSON比较多重集合，嵌套数组/manifest/层原始字节不变；旧失败快照/差异统计保留。官方2.13.2 API Reference定义已查，未伪称上游承诺排序。修改比较器后完整HTTP验收通过。
- 收尾现场：新8服务+init全部停止、旧11recovery全部exited、旧/验证6节点running，Docker卷仍43，旧30443健康healthy。无入口切换/数据删除/云SSH/清理；root实例中receipt和日志私有不入Git。公开证据scripts/results/luna-harbor-host-instance.20260927.json；方法registry-platform/docs/host-instance.md。6Python AST、7默认plan、git diff --check，未跑测试套件。
- 仍欠：新空主机官方配置生成/完整Compose等工具物料、只读到可写与最新停写备份、Jobservice/认证push/CI-CD、通用备份恢复/自动启动、SNI30443→18443/19443、KIND main静态动态卷/本地适配和重建独立性、云SSH与step11前置整链（未经实机验证）。本次用旧冻结备份不代表后续新写入已同步。
- 最终清理必须最后做；本次runtime-import.tar可再生缓存仅登记候选，保护原备份/旧节点/卷/新实例数据。inbox仍旧kind/~/.kube/kind-config/匹配1.27.3kubectl，main未建，不能通知luna做完了。无后台任务/用户预算限制。

## 最新续接：2026-09-27 独立 Harbor 共用运行配置渲染

基线 `1bb77594f24b11459af1c9bf34ad5dedb06b1f07`，本地 luna，不 push，开始工作树干净。交付为包含本段的提交。

- runtime_config.py纯函数消费官方2.13.2原Compose和显式site/镜像元数据，产生8角色：6官方+原PG17.6/Redis8.2.1。每实例/data/harbor/instances/<deployment>，唯一project/labels，restart=no，明确bind/create_host_path=false和tmpfs覆盖镜像隐式卷；不自动沿用upstream任意权限/端口字段。本地loopback18443、云privateIP30443；内网backend+仅proxy前端无masquerade。
- runtime_files.py纯函数把原core加密/令牌签名/共享凭据/registry认证映射到新文件，HTTPS接五年Harbor叶；Redis认证同时接core/registry/jobservice，保留DB0/1/2与idle_timeout_seconds=30，AOF/everysec。只读模式禁Jobservice默认profile/registry数据RO；可写参数仅渲染，尚未部署或改写状态。GC/出站任务配置/自动启动仍待完整生命周期，不能称生产功能已齐备。
- runtime_inspect.py默认只打印；--check只读原root私有输入、installer全SHA、6官方configSHA、原PG/Redis本机digest、TLS配对/链。4组wsl/cloud+只读/可写各27私有文件在内存生成，原4类核心身份逐字节比对。Compose5.1.3从stdin解析，--no-env-resolution不访问未创建实例的env文件，未做有效env值/服务运行验收。云IP10.50.0.5仅内存例子，未SSH。
- 失败留痕：最初一次性元数据读取对Volumes=null直接list失败，正式读取器规范为null/空集合等价；首次渲染拒绝Redis查询参数，只读核到三URL都是idle_timeout_seconds=30后窄化白名单并原样保留。没删除失败副本、没放宽TLS/摘要检查。
- 证据scripts/results/luna-registry-runtime-render.20260927.json含8固定镜像ID与4组通过结果，3Python AST及默认计划通过；未测试套件/落盘私有配置/创建容器/复制DB或层/启动服务/切30443/清理。使用方法registry-platform/docs/runtime-rendering.md。
- 下一步：把这两纯函数接新实例准备与生命周期；固定Compose与Jobservice等物料、存储UUID/空目标与权限检查、完整env校验、同版逻辑恢复/全目录SHA、start/stop/backup/storage-gated unit；云前置SSH只演练。原配置生成器仍固定历史候选批次，不能把这三新模块说成通用安装已完成。
- 五年证书提交已完成且未在线安装；main仍未创建，恢复11容器保持停止、旧节点/卷/入口/inbox保护。旧Harbor近期健康未新核。最终清理不可遗漏且最后。整体任务未完成，不发luna做完了。无后台任务/预算上限。

## 最新续接：2026-09-27 原 CA 五年证书与统一消费入口

基线 `66a6a83b9bfe8bbe6b93d7cad746ceaa5f2a3266`，本地 luna，不 push。开始时只有本助手本单元新 certificates.py，未覆盖他人工作。交付为包含本段的提交。

- 所有者五年证书已实际签发：原 CA 路径 ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/{ca.crt,ca.key}，CA 公有 SHA30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec，到期2036-05-07。签发前后原证书/私钥字节相同，未复制/分发CA私钥。
- 新独立批次 ~/private/registry-platform/tls-20260927-five-year，parent/batch0700、文件0600，Git外；Harbor SAN harbor.sunmoonai.com；入口SAN sunmoonai.com及*.sunmoonai.com；独立RSA4096密钥，均到期2031-09-27T10:05:21Z。公有证书SHA e2700dc171e2e0a2d9f028d7d4fcab35e1af717e67ac19d71414af41e7be5b03 / b5a2ef29f1c4eeb68c9dd1865c32b5dca8cb969a3b5e1e14c02e663fdfd081ea。未安装在线服务、没换CA/令牌签名/加密密钥。
- certificates.py 默认只打印，issue --apply只允许新私有批次；rootCA显式SHA/配对/剩余期、SAN/EKU/KU/有效期/独立密钥、OpenSSL完整链/域名核对；check只读且不需CA私钥，默认90天续期门槛。输出ingress-bundle兼容step12。签发初次utcnow弃用警告已用明确UTC表达修正，没有重复签发。管理机cryptography41.0.7/Python/OpenSSL尚未构成新机离线工具闭包。
- config/local-wsl.conf已引用新批次/CA SHA/服务叶路径；cloud.example保留显式空输入，无自动拷贝。deploy-certificates.sh按KIND/C1/C2走相同tls_resources.execute，cloud STEP12优先、profile TLS_BUNDLE次之；不轮换、不覆盖已有Secret。KIND tls_local接线，入口ingress_local抽共用local_cluster连接：固定tool/私有kubeconfig每次重核，HTTPS静态凭据、每次API前UID、版本。根closure=false仍阻止实际API；未把适配代码就绪说成Secret安装成功。
- 证据scripts/results/luna-five-year-certificates.20260927.json：4Python AST、4shell bash-n/ShellCheck、KIND/C1/C2证书与入口共6只打印计划；真实新叶证书check、step12 load_bundle密码学检查通过。无测试套件、集群API/SSH/服务/下载/清理。方法registry-platform/docs/certificates.md；仍需真实客户端握手/证书安装/到期定时任务。
- 本单元Docker只读核到11恢复容器均exited、旧/验证6节点running，未再查询旧Harbor健康。所有恢复副本保持停止；正式Harbor生命周期/主机前置模块、SNI/main、KIND存储/镜像、推拉认证/CI-CD/备份/重建独立性继续待完成。本次先补齐证书和消费接线，不能通知“luna做完了”。
- 现场入口30443/inbox不切换，main未建；仅证书私有目录新增。最终清理必须做且最后，旧节点/卷/唯一备份继续保护，无后台任务/用户预算限制。

## 最新续接：2026-09-27 Traefik 3.7.13 物料与 step13 共用入口

基线 `a8a1a87f4052cf2031033e25e3e75b1439440020`，本地 luna，不 push。开始时 bootstrap/render.py、values.json 是本助手未提交原3.5.2试作，Harbor方案是此前确认范围的文档修改；均纳入本单元，未覆盖他人工作。交付为包含本段的提交。

- 所有者明确批准 Traefik3.7.13/chart41.6.0；随后将版本冻结范围收窄为数据库/数据引擎，其他组件按必要性评估。Harbor从Bitnami改宿主官方方式，应用版本实际仍2.13.2；PG17.6、Redis8.2.1不变。不要误报Harbor已升级或已正式切换。
- 官方chart索引固定SHA，经东京下载266558B包；DockerHub固定index/amd64manifest/config后拉取导出55225344B。公开下载目录东京 /home/zym/sunmoon-traefik-20260927-v1；只传公开下载脚本/源清单。回传唯一物料根 releases/traefik-3.7.13-chart-41.6.0-linux-amd64/；6blobs/4layers本机全核验。原3.5.2包/旧chart均保留，本轮无清理。
- 失败留痕：远端zsh未引号的=https展开失败；Docker把docker.io/library/traefik@digest缩写成traefik@digest，修正规范等价化但不放宽摘要；第二次重复pull碰8GiB余量门禁，改先复用已有完全同摘要镜像，不抬低门槛，export仍留6GiB。v1/v2/v3公开脚本均留远端，无容器启动、无云安装。
- 新bootstrap/sources.lock.json + values.json + render.py：只读固定官方chart离线生成10 Proxy CRDs、dev/prod各8资源；Helm3.19.0/PyYAML只作为现有准备工具，其自身离线供给未闭包。新版日志和HTTP结构、原生image.digest、默认TLS namespace、strictTLSOptions、有限crossProviderNamespaces已接。prod3副本/dev1，NodePort30080/30443/30444–30446；不含PVC/ACME/hostNetwork/Hub/Gateway。实际业务兼容验收未做。
- ingress-images/resources两份子锁由主锁SHA绑定，bundle ingress范围含5文件。step11消费新版本，registry_consumer不再硬写3.5.2。主锁共133文件1113542643B全SHA核过，closure_complete=false保留，pending为KIND存储/TLS/镜像及正式建群、独立Harbor主机生命周期/pre-step11/平台接线。
- ingress_resources.py是本地/云共用实现；显式UID、受管Active namespace、已安装TLS Secret再核crypto、全节点Ready、端口/defaultClass及资源归属全预检；缺项create，CRDEstablished后再查自定义资源并创建；等待Deployment代际和全部副本就绪。无接管/更新/删除/Helm卸载/宿主iptables/Harbor动作。verify不补建，真实路由/TLS握手结果明确false；Secret私钥只读内存，TLS诊断不打印。
- 云step13改短包装→cluster-step/control/node；公共SSH控制白名单20文件，含ingress模块/子锁；默认只打印，总控显式--apply。总配置只改Step13段，其他字节终检与基线精确比对不变。云上未经实机验证。
- ingress_local.py需要显式锁定kubectl、0600 kubeconfig、expectedUID、CA路径/SHA，核TLS/API版本，每次API前核UID；受closure门禁。平台总入口按--cluster KIND/C1/C2选择适配器，旧deploy-traefik入口exec转发，历史正文不执行。旧平台conf/values不再控制新版清单；C3暂无此适配器。KIND节点镜像导入、存储/TLS适配和正式main建群尚未接通，不宣称本地已部署。
- 证据scripts/results/luna-ingress-bootstrap.20260927.json：9Python+远端payload AST、4改动Shell bash-n/ShellCheck、主conf及历史兼容脚本bash-n；C1/C2共26个steps计划加6个平台/旧入口计划；133SHA与OCI图、两份18资源加载检查。仅静态/物料/只打印，未加跑测试套件、未连接集群API、未切换入口。复用方法docs/ingress-bootstrap.md，唯一物料手册已补本批。
- 下一步继续正式Harbor可复用生命周期/五年叶证书/主机前置步骤、KIND适配与SNI/main、推拉认证/CI-CD/备份/重建独立性。旧Harbor30443与inbox保持，未新核现场健康；main未建。最终清理必须做且最后，旧节点/卷继续保护；整体未完成，不能通知“luna做完了”。无后台任务，无用户指定预算。

# Luna 工作检查点

## 最新续接：2026-09-27 step12 已签发入口证书消费

基线 `1f2aa1313833c7f3db8c2a79060783330e9a987d`，本地 luna，不 push，开始时工作树干净。本段优先于旧step12仍可force/rotate的记录，交付为包含本段的提交。

- step12原278行替换短入口→共用cluster-step/control/node的certificates资源动作。默认只打印，--apply仅创建缺失TLS Secret，--verify检查不补建。移除调用旧unified证书工具/CA生成轮换/额外集群分发/失败跳过成功/弱SSH校验路径；旧工具本身保留未运行。菜单说明同步，历史文件名保留。
- tls_resources.py供两适配器共用，当前仅云端接线；管理机和target均核固定CA、证书SHA、PEM链、非CA叶证书、root+wildcard SAN、24h最低剩余期、私钥匹配、OpenSSL sslserver/auth_level2/hostname/有效期。CA来自registry-profile，与11同公开输入，无CA私钥。密码学函数尚未以真实输入执行。
- 新STEP12_TLS_BUNDLE_FILE为Git外私有JSON，描述一/两份dev/prod ingress namespace下traefik-tls-secret的证书文件/SHA/私钥文件；描述/私钥owner/root且无组/其他权限、非symlink、限大小、拒绝Git内私有输入。dry-run不读取这些输入。输入准备/五年签发待仓库正式模块，不要求所有者现在手填。
- 所有Namespace Active/UID/managed-by及已有Secret归属/data/type/注解冲突先检查，缺失才创建，读回逐字比较，永不覆盖/接管。kub每次前核clusterUID/CA；只到已登记master，节点身份复核。OpenSSL私钥走stdin，临时文件仅公开证书；kubectl stdin传Secret且日志屏蔽TLS错误stderr/正文。远端root0600请求仍包含叶私钥，文档明确按凭据保护，不是全机零写。
- 总配置仅Step12末段替换，前面所有字节精确比较未变。step12 targetmaster，默认空bundle明确标未配置；force/rotate/additional-clusters残留输入拒绝。总控对12显式--apply。公共SSH白名单18文件，新增tls_resources.py；根锁false保持，pending为13、KIND存储/TLS适配、独立仓库主机前置步骤/平台接线。
- 证据scripts/results/luna-tls-consumer.20260927.json：4Python+远端payload AST，3Shell bash-n/ShellCheck和主conf bash-n，C1/C2共24组01–12只打印，129文件1236303984B全SHA；OpenSSL verify/x509/pkey help确认需要的选项。本轮没测试套件、没读实际证书私钥、没SSH/API/服务/下载/清理。方法infrastructure/docs/tls-consumer.md。
- 续读入口dev/prod values全部：dev固定hsy-local-2，存在旧Harbor entrypoint额外参数；prod使用hostNetwork与fast-ssd/ACME，与本次本地/云共用目标待收敛。没有改/运行这些values，下游完整链仍需继续读。step13不得直接调用旧链宣称升级完成。
- 下一步step13入口固定chart/离线引用与统一配置、独立Harbor正式生命周期/原CA五年叶证书/主机前置步骤，随后SNI/main/CI-CD/备份。Secret存储加密/RBAC和实际TLS握手仍需生产准入验收；本模块没有配置etcd加密，不把base64视加密。
- 现场旧Harbor30443、inbox、容器/卷/物料保持，本轮未复核实时状态；main未建；五年证书尚未签发。最终清理必须做且最后。整体目标未完成，无后台任务/预算上限，不能通知luna做完了。

## 最新续接：2026-09-27 step11 独立仓库使用方

基线 `14e1cae361f1f944014016bae92f9faeca62c78a`，本地 luna，不 push；本段优先于旧 step11 尚未改写的记录。交付为包含本段的提交。

- 原1004行step11替换为短入口→cluster-step/control/node→registry_consumer.py。默认只打印，--apply明确变更，--verify只检查受管配置/镜像不修复；远端管理代码/请求/审计记录仍写入，文档明确并非全主机零写。新分支未经实机验证。
- 从registry-platform/lib/config.sh读取独立云主机profile，固定Harbor2.13.2和harbor.sunmoonai.com:30443；公网/master回退删去，CA绝对路径/无symlink/PEM证书only/SHA必须明确，私钥/密码不传。cloud.example加machine-id/CA SHA字段，云SNI=false。只核登记的独立身份，实际仓库主机身份/版本待主机生命周期步骤核，结果保留live_identity_verified=false。
- 控制顺序：主机/锁/物料→masterUID/CA/全节点identity/IP/version/Ready→全节点只读预检→逐节点补缺信任/hosts/Traefik→全节点复核。信任root0644且精确一致，underscore高优先目录/额外文件/冲突拒绝。hosts精确匹配+描述符锁追加、不删除。TLS直连私IP、规范SNI/Host，401/registry2/realm检查不带凭据、不表示登录推拉通过。无Docker/Harbor生命周期/服务重启。
- 复用原images/traefik_v3.5.2.tar，178587136B SHA d793cb1eedc662511704ba94f63cbc5e6278bf01e6e70ef21797e38328e08742；新ingress-images.lock.json被主锁SHA引用，bundle新增ingress范围、精确同步覆盖。OCI未压缩manifest不是公共registrydigest；alias docker.io/sunmoon-offline/traefik@sha256:c79033e751afa9c322db0cf83cd5d866c0a300b37960e923bdb28c49d0a46eee。step13仍须消费alias/Never，不声称Pod已可启动。旧Harbor启动包仍保留，平台版本没升。
- 主配置仅Step11区域修改，其他区域和历史共享字段私下逐字节核对相同；不输出完整conf/diff。移除旧STEP_IMAGE_*和旧DNS/文件名猜测字段；总控对11显式--apply。主锁false保持，pending改为12/13、KIND存储、独立仓库主机前置步骤/平台接线。公共SSH程序白名单17文件，含新module+lock。
- 证据scripts/results/luna-registry-consumer.20260927.json：5Python+远端AST，5Shell bash-n/ShellCheck与主conf bash-n，C1/C2共22组01–11计划全通过；129文件1236303984B全SHA、Traefik6blob核过。最初conf ShellCheck缺shell/外部变量注释已修；证据采集最初误当step01只输出一个JSON，已改逐节点解析。无测试套件/SSH/API/镜像导入/服务操作/下载/清理。方法infrastructure/docs/registry-consumer.md。
- 本轮续读step12全部278行：仍调用旧unified证书入口，force可删CA、verify缺参数/SSH失败会跳过成功；旧client还有Docker重启路径（README所述），未执行。step13仅入口脚本已去Harbor，但下游ingress/traefik还须完整审改；此次只读step13全部及ingress总控前145行，不声称下游完成。接下来证书应复用原CA、Harbor五年叶证书归仓库模块，集群不得借安装隐式轮换CA。
- 尚未完成仓库主机正式入口、总控step11前调用主机模块、step12/13、KIND使用方；不得把本单元当整个Harbor迁移完成。新main未建，旧Harbor30443、inbox和容器/卷保持，本轮未复核现场。最终清理必须做且最后。本单元下一步为证书与入口步骤、正式Harbor/CI/CD/备份，不能通知luna做完了；没有预算上限/后台任务。

## 最新续接：2026-09-27 step09 存储适配与现有物料保护

基线 `f253d203498c5783f368e129e827ed669ef2bf20`，本地 luna，交付为包含本段的提交，不 push；开工工作树干净。此节优先于旧“step09尚未写”的记录。

- 原1470行step09替换为短入口→cluster-step/control/node；默认只打印，总控显式--apply。删除旧脚本的自动删namespace/SC/RBAC再装、取消其他默认SC、跨Docker/nerdctl兜底、通配chart/浮动master清单、离线失败继续、自动创建/删除测试PVC/Pod等执行路径。本次没有运行任何实际删除/安装。
- 新storage_resources.py生成共用9对象，独立namespace sunmoon-local-storage、provisioner sunmoonai.com/local-path，避免接管KIND内置对象。固定原local-path0.0.32和os-shell12-debian-12-r51、摘要/Never；明确每节点path/禁用未声明节点；SC Retain+WaitForFirstConsumer；teardown失败并保留目录。先预检全部已有资源UID/配置SHA/声明字段/默认SC冲突，仅创建缺项，不覆盖漂移，等待controller就绪并复核。不声称数据IO已验证。
- 新storage_host.py只用于已登记云节点：明确/data挂载点、每节点预登记UUID、ext4/xfs/rw/整文件系统非系统盘、无nested mount/symlink、root父目录；未登记有数据拒绝。所有节点先只读预检→准备目录/root0600归属记录→共享image_import.import_items导入2镜像。无mount/mkfs/fstab/chmod现有目录/清理。归属记录不是完成记录，导入中断可同身份续；真实云执行未发生。
- 本机原images/rancher_local-path-provisioner_v0.0.32.tar与bitnami_os-shell_12-debian-12-r51.tar完整图SHA核过，合计233228288B。新storage-images.lock.json由主锁SHA钉住，bundle新增storage范围，精确同步自动覆盖；文件保持原位置没复制/下载/删除。两包是未压缩层的Docker-save OCI digest，不冒充公共registry digest；使用docker.io/sunmoon-offline/*离线别名和Never，不能公网拉。节点import分支未实际执行。
- 总清单现128文件1057716848B全SHA通过；公共SSH程序白名单15文件（新增storage资源/host程序和锁）。主锁closure_complete=false，pending为11/12/13、KIND存储适配及外部registry/platform接线。平台组件版本未升。
- conf仅Step09区域变：新增mountpoint /data和3个空UUID（真实apply前须预登记）；移除旧自动验证/在线目录/节点补包等废字段，等待改STEP09_WAIT_TIMEOUT，重复admin.conf只留一处，TARGET注释纠正；其余区域字节和保留字段值私下精确比对未变，不打印全conf/diff。
- 只读盘点custom-values/*kind-pv*.yaml：8份PV模板/12PV（7非Harbor组件卷+Harbor5卷），路径/affinity/SHA进证据，未改/部署。旧kind-worker固定绑定必须在新main平台部署时映射，节点内/data/kind-local-storage/<组件>保持。对象存储文件名是object-storage-kind-pv.yaml，不能只搜pv-pvc漏掉。ES动态、RabbitMQ持久化关闭是原有文件事实。
- 证据 sunmoonai/scripts/results/luna-storage-bootstrap.20260927.json：7Python/远端payload AST，3Shell逐个bash-n/ShellCheck零提示，C1/C2共20组步骤01–10只打印；两套storage各9对象、两镜像10blob内容核对；全128SHA。没加/跑测试，没SSH/API/实际导入/服务/磁盘操作。方法docs/storage-bootstrap.md，相关审查索引与入口文档已更新。
- 云CSI开关原false保持；若启用明确报无选定provider/精确物料/validated profile，不留旧腾讯占位假成功；首次上云需按选定provider补锁/验证。KIND存储主机适配、默认SC策略、三节点mount身份及静态卷绑定尚未接通，不能把云node程序拿到WSL执行。
- 下一步：继续step11镜像/独立仓库host地址、step12证书与step13入口接线；独立Harbor正式生命周期/五年叶证书/入口/推拉/CI/CD/备份，然后正式KIND建群及共用存储/平台。旧Harbor30443、inbox目标、所有容器/卷/物料保持；本轮没复核现场。最终清理必做且最后，不能清容器/卷。无后台任务，整体未完成，不能通知luna做完了；未设预算。

## 最新续接：2026-09-27 step07/08/10 共用资源入口

基线 `6c96233676a18846bf850eb854bc2032e2eb7716`，本地 luna；交付为包含本段的提交，不 push。工作树在本单元开始时干净。本段优先于下面历史待办。

- 新 `infrastructure/materials/cluster_resources.py` 是共享资源实现：命名空间只创建缺项，已有标签/UID不符拒绝接管；等待Active；污点仅补NoSchedule/PreferNoSchedule，全部冲突预检、RV条件patch、保留已有，无覆盖/删除/驱逐。空配置无patch。Step08核精确节点集合/machine-id/IP/工具及API版本、Ready/压力/cordon、核心Deployment/DaemonSet rollout、kube-system Pod及4个静态mirror Pod；失败阻止后续，基础就绪不等于平台验收。
- 云端07/08/10改短包装→既有cluster-step/control/node→resources；默认只打印，总控显式--apply。仅root0600 admin.conf，每次API前核建群记录UID/CA；资源结果/异常root0600日志。公共SSH发布白名单现在12文件，增加cluster_resources.py，未真实执行SSH。
- 本地 `resources_local.py` + `kind-infrastructure/apply-namespaces-existing-cluster.sh` 使用同一命名空间实现/配置；显式绝对路径kubectl SHA、0600 kubeconfig、已登记UID、TLS和1.36.4版本；默认只打印。移出原脚本附带StorageClass创建，交后续存储步骤。支持私有配置和KIND_命名空间字段覆盖，不导出整份配置。
- 历史 kind-up 调用改显式参数，并在任何原有主机操作前要求SUNMOON_KUBECTL/SUNMOON_EXPECTED_CLUSTER_UID。它不适用本次正式新建群，不能伪造预先未知UID绕过；新main创建→登记身份→共用平台的入口尚待接通。其他旧kind-up逻辑未审改，本单元未运行它。
- 总conf仅两项修正：原NAMESPACE_PLATFORM_APPLY_POLICIES=true是纯日志占位，现false，设true明确报无策略清单；删除独立STEP10_KUBECTL_VERSION=1.30.4，实际读锁定工具。其他字节精确比对未变，不打印含凭据的整个conf/diff。没有删除实际集群策略，真实隔离/配额还须清单与验收。
- 证据 `sunmoonai/scripts/results/luna-post-bootstrap-resources.20260927.json`：5Python和远端payload AST；7Shell逐个bash-n/ShellCheck零提示；C1/C2的01–08和10共18组只打印、命名空间本地14对象与云端render一致；126文件824488560B全部SHA复核。初次kind-up SC1091来源注释已修正，终检零提示。没加/跑测试套件，没连API，没操作云部署。
- 主锁closure_complete=false保留；pending具体为step09/11/12/13 + 外部registry/platform接线。节点安装日志绑定整锁，未来修改锁须在首次部署前定稿；目前云端从未安装，无已装节点被此次锁变化影响。
- 方法/边界/首次实机清单 `infrastructure/docs/post-bootstrap-resources.md`；审查索引、bootstrap、materials与历史kind文档已更新。C-D1/C-R1/R2适用，本单元无平台版本或镜像变更。
- 下一步继续完整改step09（自动清理namespace/SC、online fallback、静态路径与新版物料）、11/12/13和独立Harbor正式生命周期/入口/信任/推拉/CI/CD/备份；本轮只重读step09开头与危险调用定位，其1470行全读基线见早期audit，不声称新存储适配完成。
- 旧KIND、Harbor30443、inbox目标、数据和物料保持；宿主Harbor候选11容器仍按之前记录停止，本轮未复核现场。新main未建。最终清理必须做且放迁移验收后，禁止容器/卷清理。无后台任务；整体目标未完成，不能通知luna做完了。未设预算。

## 最新续接：2026-09-27 step04–06、固定镜像与 kubeadm/Calico 接线

基线 `4c3e17319aa23aa743a922f9492630f9b10f00d0`，交付为包含本段的本地 luna 提交，不 push。本节覆盖下文历史“配置仍1.30.4/step04–06待写”的状态。

- step04/05/06 已替换为短入口→utils/cluster-step.sh→materials/cluster_control.py→严格SSH公开代码发布→cluster_node.py。默认只打印，未发起真实SSH。原自动reset/删目录/强杀/在线补装/忽略预检/失败后另跑init等从三步移除。
- 新 cluster_config.py 生成v1beta4、显式节点IP/endpoint/SAN、iptables；Calico同一锁定3.32.2 YAML→38 JSON对象，VXLAN、InternalIP检测、3镜像摘要/Never。四静态核心Pod和CoreDNS生成摘要/Never补丁；kube-proxy init后API补丁，运行效果尚未实机验证。
- image_import.py完整核10归档的架构manifest/config/layer，104内容引用/72独立blob全部本地SHA通过。实际分支生成root私有OCI传输副本，ctr k8s.io精确导入、拒绝同名不同摘要，核目标manifest与CRI标签/摘要解析。**没有实际导入**。
- 集群控制程序：全节点预检/预装镜像→单master init→Calico→顺序worker join；仅支持当前单控制面IPv4设计，多控制面明确拒绝。验证节点IP实际归属、至少4GiB空间和时钟。身份、安装日志、二进制/配置与锁都匹配才执行。
- 新云集群记录将存/var/lib/sunmoon/clusters/cN，核kube-system UID和CA公钥摘要，未登记/半初始化状态拒绝自动恢复。admin.conf保持root0600，不覆盖本机配置。token10分钟，通过SSH内存协议和root私有文件，终端/argv/Git不含令牌；每worker核machine-id/IP/version/Ready，最终撤销本轮token，撤销失败不报完成。
- node_control发布白名单现11文件，含3个新节点模块；初始OS/runtime/tool操作仍拒绝已有集群，集群后续动作由匹配的私有记录准入。node_install新增allow_owned_cluster仅由新集群程序在身份核对后使用，第一阶段默认仍拒绝。
- 总conf只改3个集群层字段：CLUSTER_VERSION=1.36.4、STEP05_CALICO_CHART_VERSION=3.32.2、STEP04_KUBE_PROXY_MODE=iptables。其余行逐行比对未变，包括平台版本/凭据；不要打印全conf/diff。旧字段名保留兼容，新Calico不再走Helm。
- 主锁126文件824488560字节全SHA通过；closure_complete仍false，pending为step07–13与独立仓库/平台接线。实机验收单列validation_status=node/cloud not_run，发布准入与实机验收分开，避免首次上云的循环门禁。
- 证据 sunmoonai/scripts/results/luna-cluster-adapters.20260927.json：6Python及远端payload AST、5Shell逐个bash-n/ShellCheck、C1/C2各3阶段共6组只打印、既有step01–03与总控只打印通过。精确1.36.4工具C1/C2 init/join格式校验通过，7核心image list完全匹配。首次Join严格解码发现tlsBootstrapToken误放根级，已移到discovery后复核通过；只用公开无效示例token，未创建真实令牌。
- 文档 infrastructure/docs/cluster-bootstrap.md 含方法/边界/首次上云清单。未执行真实云操作、OCI导入、kubeadm init/join、Calico apply、证书替换或清理；新云代码均未经实机验证。
- 下一步：完整改step07–13与统一平台/存储、独立Harbor主机配置和入口、推拉/信任/CI/CD/备份接口。旧KIND inbox仍~/.kube/kind-config + releases/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl；旧Harbor30443不变，新main未建。最终清理和物料/网络手册复盘仍必做。当前无后台任务，不能通知luna做完了。

## 最新续接：2026-09-27 step01–03 统一节点安装接线

基线 `18e5d9f5`，交付为包含本段的本地 luna 提交，不 push。本段优先于下面的历史待办。

- step01/02/03 旧实现替换为默认只打印的短入口 → utils/node-step.sh → materials/node_control.py。原通配符选nerdctl-full、固定旧deb、在线补装和错误忽略从这三步移除。
- node_control实际分支要求完整锁、配置版本、全126文件SHA、预先登记的 EXPECTED_HOSTNAME/MACHINE_ID；严格SSH/sudo stdin JSON只发布8个公开程序/锁到root拥有的内容摘要目录、0444文件、Python -B -E -s，不传私有代码/配置。远端再次核机器和物料。**此实际分支未执行**。
- 新os_install实现专用新Ubuntu24.04离线APT：可信签名核验、root物料副本、空sources/隔离配置、模拟计划只允许锁内版本；拒绝降级/删除/未完成dpkg/多架构/竞争NTP/启用swap，记录日志，不自动修复/重试。写专用内核模块和sysctl，要求nft/NTP同步；不会改hostname/hosts/fstab。目标须预装发行版自举Python/rsync/APT/gpgv/keyring。
- runtime/kubernetes必须有同机器、同主锁、同OS锁的complete.json；kubernetes另要求runtime完成。代码为新节点首次部署，不做现有集群原地升级。
- 总控已改精确 sync-cluster-materials --apply，并向三个新步骤显式传--apply。整个变更仍被closure_complete=false和旧配置1.30.4不匹配拒绝；不能放开跑后续旧steps。后续平台物料同步仍未统一。
- 静态证据 `sunmoonai/scripts/results/luna-node-adapters.20260927.json`：5Shell逐个bash-n/ShellCheck零提示，3Python及远端payload AST；C1/C2各三阶段共6组只打印全部通过，无SSH；各3节点，身份尚未配置、版本尚不符。OS独立计划及总控计划通过；不是实机安装验收。
- 方法和首次云上核对清单 `infrastructure/docs/fresh-node-bootstrap.md`。主锁pending更新为OS实机验收、Calico镜像消费、节点离线部署验收。平台版本、现场服务、旧数据、inbox目标未变；全部回收留最后且必须完成。
- 下一步：读/改step04–06，准备kubeadm v1beta4 init/join、控制面镜像摘要导入与Calico共享清单；其后统一Harbor正式生命周期/入口/平台/CI/CD/备份。云端只代码和静态，未经实机验证；当前无后台任务，整体目标未完成。

## 最新续接：2026-09-27 Ubuntu 离线依赖准备与独立签名核验

基线 `709f76837ff1a47111f934ed1a5c9949379ebbbe`，本地 luna，不 push；本段优先于历史记录。

- 新 `prepare_os.py` 通过隔离 APT_CONFIG/空 dpkg 状态、官方固定快照、预装 archive keyring 解析依赖，仅 update/simulate/download-only；默认只打印，普通用户执行，不安装、不清理、不改服务。东京下载已实际完成，系统 dpkg 状态前后 SHA 一致。
- Ubuntu24.04 amd64，快照20260927T000000Z，20根依赖→94包31510444字节；9签名/索引112150216字节。物料已回本机 `~/packages-to-be-installed/releases/kubeadm-1.36.4-linux-amd64/os/ubuntu-24.04-amd64-20260927T000000Z/`。
- 新 `verify_os.py` 本机使用预装可信 keyring 独立验证3个InRelease、6个Packages以及94包的身份/SHA/大小；通过。下载完成并不代表目标节点离线安装成功；目标预检、拒绝降级/在线补包仍待实现。
- `os-dependencies.lock.json` SHA 已固定在主锁，bundle新增os作用域，支持Deb版本文件名中的%和~。同步自动消费精确新清单，C1三节点只打印预演通过，没有真实云同步。
- 当前总锁126文件824488560字节全部本机SHA通过；closure_complete仍false，pending为OS安装适配/目标预检、Calico和镜像消费、节点离线部署验收。未调整平台服务版本。
- 证据 `sunmoonai/scripts/results/luna-os-materials.20260927.json`；方法 `infrastructure/docs/offline-os-materials.md`。3Python AST、默认只打印、精确同步预演、git diff --check通过；没有测试套件或云部署。
- 初次URL探查zsh展开=https失败，后固定HTTPS HEAD通过；首次rsync缺父目录失败，新建专用OS批次目录后回传成功。所有旧物料、容器、卷保持，最终清理门禁有效。无后台任务。
- 下一步继续step01–03 OS基线/远程发布与节点安装接线，然后kubeadm/Calico、宿主Harbor正式生命周期；原整体目标未完成，不能通知luna做完了。

## 最新续接：2026-09-27 统一配置与精确物料消费、节点安装程序

基线 `180de198041c7fa348c994eec8f1ab1a451fc2a5`，本地 luna，不 push；交付为包含本段的提交。此节优先于下文。

- 所有者继续授权升级。完成 `infrastructure/utils/config.sh` 共用加载器，总控/common/step07/step12/package-sync 统一配置；重复 sync 节点与凭据先逐字比对一致后移除，没有移除唯一凭据。主配置历史凭据仍在、未宣称历史脱敏。显式 Cn，稀疏节点，空值覆盖，无 eval，单进程禁止切目标；可选 Git 外私有覆盖。
- common SSH 改密钥/agent、严格 known_hosts、明确端口/超时；sudo 只执行一次，经 stdin 传脚本，不再密码重试。kubeconfig 不再隐式 fallback 或 chmod0644。旧步骤内绕过公共函数的 raw SSH 仍须整改。
- 新 `materials/bundle.py` 统一工具/控制面/共享Calico/配置的精确路径和摘要；`sync.py` 严格SSH、远端同名不同摘要拒绝、精确rsync/no delete/远端复核；package-sync 的 `sync-cluster-materials` 默认只打印，显式 --apply 才传输，本次未执行远端传输。
- 五个公开配置已实际备料到 `~/packages-to-be-installed/releases/kubeadm-1.36.4-linux-amd64/configuration/`；只创建物料，不安装服务。containerd已核SHA二进制的 config dump 通过schema4/SystemdCgroup/registry路径；kubeadm1.36.4 init-defaults只读确认v1beta4。临时解析工具 `/tmp/luna-containerd-config-p_jbny13/containerd`，未启动daemon。
- `node_install.py` 独立安装程序已写：只打印默认；真实分支先完整闭包/主机身份/专用新Ubuntu24.04 amd64/systemd/cgroup2预检，拒绝WSL/Docker/Harbor/已有集群；白名单解包、实际输入内存再核SHA、独占创建不覆盖、日志/版本/CRI检查。实际 --apply 未运行，未经实机验证。尚未接到旧step02/03，不能声称云安装已升级。
- 当前23文件680827900字节SHA通过（包含共享Calico），主锁 closure_complete=false；pending为OS依赖、Calico消费、节点适配/离线验收。总控deploy与单步变更已加入版本和闭包准入，当前1.30.4旧配置会被拒绝，不能绕过门禁执行旧step。Step00在总控明确拒绝。
- 证据 `sunmoonai/scripts/results/luna-infrastructure-material-consumer.20260927.json`，方法 `infrastructure/docs/locked-node-materials.md`。6改动Shell bash-n/ShellCheck零提示，4新Python语法，C1/C2总控、C1三节点精确同步、两阶段安装只打印通过。本次首次预演因默认路径含../误判失败，已修正规范化路径，保留失败记录。
- 下步：补Ubuntu24.04 OS依赖完整离线集；将step01–03与控制脚本发布/机器身份准入接到新程序；kubeadm v1beta4 init/join和镜像导入、共享Calico；然后统一平台/宿主Harbor正式生命周期。已有授权不需再问技术方案。
- 未操作云主机、KIND、Harbor现场或旧物料；最终清理必须做且放最后。原大迁移目标未完成，不能通知“luna做完了”。没有后台工具会话。预算未设上限。


## 最新续接：2026-09-27 infrastructure 全目录审查和第一批总控修正

基线 `d661840e0c3a49bf1c5e8557236eb3380b0dadb8`；交付为包含此检查点的本地 luna 提交，不 push。此节优先于下方历史记录。

- 所有者最新要求：物料更新必须同步部署脚本，完整细读 infrastructure 的细节。已经逐文件阅读全部 38 文件/11,605 行，包含所有步骤、工具、配置与文档。逐文件 SHA 与修改前静态证据：`sunmoonai/scripts/results/luna-infrastructure-audit-baseline.20260927.json`。
- 审查发现及逐文件覆盖/调用链/后续顺序：`sunmoonai/infrastructure/docs/infrastructure-upgrade-audit.md`。目录外只追踪直接接口，不能宣称全仓已经审完。
- 第一批修正：普通总控移除自动 step00；无参数帮助、显式 Cn、命令白名单；总控映射去 eval/支持稀疏节点；菜单转发同一总控和别名；同步/入口子脚本错误向上传递；同步去掉 --delete 与 scp 前清空；历史自动清理默认关闭；fix_permissions 限当前工作树。
- 总控 `--cluster C1 deploy --dry-run`、C2、菜单 C1、step11 dry-run 只打印，无 SSH/部署/下载/删除；不会执行旧脚本。注意：直接运行旧步骤的 verify/dry-run 仍可能有副作用；step04/06 自动 reset 等待整改，移除总控 step00 不等于所有内部危险行为已修好。
- 修改的 5 个 Shell 文件 bash -n/ShellCheck 0.9.0 零提示；全目录 23 个 Shell 语法通过，其他历史文件仍有 144 条 ShellCheck 提示。证据 `luna-infrastructure-audit-followup.20260927.json`。云上未经实机验证。
- 活动旧 cloud 配置仍是 1.30.4，不能只换数字宣称已安装 1.36；新版 materials closure_complete=false。下一单元：统一节点/私有配置与 SHA 清单同步、OS 依赖闭包、systemd/运行时/工具安装，再 kubeadm API/init/join 与共享 Calico；随后独立 Harbor/统一平台接线。用户已授权技术实施，无需重新请求方案批准。
- 本单元未动集群、镜像缓存、离线包或 Harbor 现场。宿主 Harbor 恢复只读验收通过的状态继续有效；新候选容器停止保留，旧 Harbor 未切入口。最终清理仍必须完成且放验收后；旧 kind-worker2、任何旧容器/卷保护要求有效。
- 原迁移目标尚未完成，不应通知“luna 做完了”。没有运行中的工具会话。无预算上限指定。


## 最新续接：2026-09-27 宿主 Harbor 只读验收通过，整套集群物料继续准备

基线 `4f55b537182fc2bad2299d9522b7cda8c0eec0b8`，本地 luna，不 push。以下优先于历史“待审/未恢复”描述。

- 所有者授权助手实现目标并同步升级 infrastructure 云端代码（仅静态/dry-run，未经实机验证）。升级限 Kubernetes、网络、运行时、kubeadm 工具和对应镜像/依赖；平台服务保持原版本，例外须有1.36实际失败证据。东京只下载公开物料，不部署云集群。
- 物料根仍为 `~/packages-to-be-installed`，新版放 releases 独立批次；部署脚本须同步精确选包。不能只换工具不配控制面/网络镜像；不能把“新目录存在”当作旧脚本已经升级。
- 宿主 Harbor2.13.2只读恢复完成，PG17.6/Redis8.2.1保留：49表/10364行等一致；4400个registry文件全量摘要通过；3项目/64仓库/429含子清单制品/164tags及元数据一致，429个HTTP清单摘要、匿名拒绝、121690112字节层读取通过。11新容器停止保留、无匿名卷、Docker43卷不变、旧30443healthy，未切入口。证据 `sunmoonai/scripts/results/luna-host-harbor-readonly-recovery.20260927.json`。
- 私有状态 `/data/harbor/candidates/harbor-2.13.2-20260927/recovery/run-state.json` completed=true。不要再次 run/resume。`recovery_run.py stop --apply` 只停登记容器、不删。修复涉及root.crt挂载、原Redis认证、proxy前端网桥、core创建时env、registry目录权限，全部只作用新副本，原输入不改。详情 `registry-platform/docs/host-recovery-plan.md`。
- `recovery_candidate.py` 新准备 apply 暂时明确拒绝：正式可复用渲染器须吸收上述修复；旧临时Compose不能直接用作正式安装。jobservice/推送/扫描、正式入口、正式KIND重建独立性、CI/CD尚未验收。
- 云端7工具已东京下载→回传→本机SHA通过，共270598928字节：K8s1.36.4、containerd2.3.4、runc1.4.3（与实际新KIND对齐）、nerdctl2.3.5、crictl1.36.0。证据 `luna-cloud-cluster-tools-aligned.20260927.json`。先取得的nerdctl-full2.3.5已退出活动清单、文件留最终清理。
- `infrastructure/materials/cluster-artifacts.lock.json` closure_complete=false，OS依赖/systemd/控制面归档/Calico共享接线尚待补齐。`prepare_images.py` 在东京准备7镜像（K8s4个1.36.4、CoreDNS1.14.2、pause3.10.2、etcd3.6.8-0），仅pull/tag/save；远程 `/home/zym/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64/kubeadm-images.lock.json` 为状态。完成后rsync回同名本地releases并重新SHA验证。
- 物料只读盘点约40.81GiB；25旧集群文件0.946GiB和1个已替代新整合包0.267GiB，共候选1.214GiB，实际释放0。Harbor保留批次18.61GiB、原平台/应用镜像、旧1.27客户端继续保留。`materials/inventory.py` 可重算盘点；`kind-infrastructure/docs/cluster-material-retirement.md` 已并入最终清理与唯一物料手册。
- 当前仅CI/CD四集群Harbor开关关闭、总控拒绝集群内Harbor、step13仅入口、旧Harbor脚本/chart标历史；cloud steps02–05等多数仍旧版本。接下来仍要完成精确选包/安装适配、宿主仓库生命周期、总控/推拉/信任/CI/CD/备份恢复接线。不能宣称整体升级完成。
- 最终清理仍必须做且放验收后；任何容器/卷、旧kind-worker2继续保护。5年证书续签未执行、CA未变；Windows开机附盘/WSL关闭压缩由所有者操作。没有云实机部署。

补充：7控制面配套镜像已完成东京导出、本机回传及tar/config双摘要校验，共153397248字节；锁 `infrastructure/materials/kubeadm-images.lock.json`，证据 `luna-cloud-cluster-images.20260927.json`。主锁已登记其SHA；Calico清单与3归档也已重新核验并登记共享路径。没有仍运行的下载/验收会话。静态检查：Python AST、bash -n、step13/config.sh shellcheck、step13无副作用dry-run、git diff --check通过。shellcheck不在PATH，使用 `/tmp/luna-shellcheck-package/extracted/usr/bin/shellcheck`。

下一步：补齐OS依赖与systemd，继续统一选包/部署代码；随后入口维护窗口和正式KIND、业务/CI/CD、必做清理与手册复盘。无预算上限指定。

**最新单元（2026-09-27 04:30 UTC）：官方 Harbor 配置准备完成。** `registry-platform/harbor_inputs.py` 已向 `/data/harbor/candidates/harbor-2.13.2-20260927` 写入原密钥/TLS/凭据；`official_prepare.py` 生成配置并复核。第一次在镜像 User 空串/null 比较处退出，修正后通过显式 `--resume-import` 继续；已完成目录不可重跑。生成器已停止，无网络/端口/匿名卷，43 卷不变、旧 Harbor healthy。官方 Compose 尚未准入运行，不可直接 up。下一步准备具体恢复运行配置、registry 层复制与逻辑数据库导入、全目录摘要验收；未启动宿主 Harbor，未切入口或清理。代码基线 a6e299d84efca31c6c017d2a792f6e0e1e593f96，交付为包含本记录的本地 luna 提交。详细步骤及失败记录见 `sunmoonai/registry-platform/docs/config-preparation.md`。用户询问内部证书 5 年有效期，已确认现叶证书到 2027-06-22、根 CA 到 2036-05-07；建议迁移核对后统一续签，未签发/替换或旋转 CA。下面为此前单元记录。

**当前单元（2026-09-27）：所有者批准“你执行”，PostgreSQL 17.6 冷备份逻辑恢复演练已完成。** 49 表/10,364 行、结构/权限/角色口令哈希/序列/扩展/large objects 一致；3 个新容器停止并保留，旧 7 容器/43 卷未变，旧 Harbor healthy。新盘副本占 182,140,928 字节，私有 dump/角色文件不入 Git。证据 `sunmoonai/scripts/results/luna-registry-database-rehearsal.20260927.json`，执行卡同模块 docs 下。不要重新执行已有批次。下一步准备官方 Harbor 2.13.2 的配置/密钥映射、registry 数据恢复和完整摘要验收；尚未安装 Harbor/切入口/改云接线。剩余清理最终必须做，禁止容器/卷清理仍有效。下文为历史记录。


当前单元：独立 KIND A/B、Harbor 冷备份及只读隔离恢复、模板前后端物料 T0–T4 均完成。物料原始下载失败已由公开归档路径解决；本次通过应用产物/后端静态构建检查，未组装生产 OCI 镜像或完成 CI/CD。正在交回本地 luna 单元；后续方向已由所有者确定，统一部署/独立数据盘/集群外 Harbor 的方案已获总体同意及补充决定；本轮仅实施明确获批的 R1/R4，部署/迁移/附盘/入口切换未执行。
实施基线 `bee0b049ca9e84fead641928816fec4a6a1c6c48`；交付提交是包含本检查点的 `luna` 提交（用 git log 定位）。

## 决定与边界

- 当前主要在本机 KIND，面向将来云端；不按付费试运营立即部署云端。
- 用户要求先了解现场、讨论方案、确定后实施；不必机械执行 fable 原任务次序。
- 批准 Kubernetes 1.36.4 / KIND 0.33.0 / Calico 3.32.2，保留旧 kind/入口/数据。
- 允许 txy-tokyo 下载公开物料并回传；没有远程建群或清理远程服务授权。
- 国内云也不保证下载公共镜像；后续 CI/CD 需内部物料供应与失败恢复设计，尚未实施。
- 所有者原有“基础软件离线包 + Harbor 预存镜像”方式继续保留；明确缺口是 Git 源码与 npm/Python 依赖供应。先检查实际依赖，再讨论内部仓库与同步方案，不先安装新平台。
- 业务端到端测试最后做；本次网络/PVC 检查是基础设施验收。
- 所有者最新确认：旧业务数据无需保留，业务全新初始化。**私有 Harbor 镜像数据必须保留**：默认覆盖全部现存制品及其 registry、数据库、配置、Secret/证书和存储恢复依赖；不能缩减为当前运行镜像。已完成冷备份、首轮隔离只读恢复和新节点实际拉取，但尚未导出可移植制品、切换入口或批准删除旧环境。旧 Harbor/相关卷/目录/必要缓存继续保留。
- 所有者先批准“现在执行冷备份”，随后以“按方案实施”批准 `harbor-isolated-restore-plan.md` 的明确恢复单元，包括只重启新 worker2 的 containerd 及回滚。两单元均完成；不包含迁移入口、后台作业启用或清理旧数据。
- 所有者要求编写《物料提交备齐方案和方法.md》，可直接交给 AI 准备物料和 CI/CD；试验通过后再更新为可复用的方法。现已按模板限定范围完成 T0–T4，并将手册更新为 0.3；全项目和 CI/CD 仍未通过。
- 手册仅维护在 k8s 的 `sunmoonai/kind-infrastructure/docs/`，按所有者要求不保留家目录副本。
- 所有者明确要求：本次迁移（新环境全新初始化与切换，不迁移旧业务数据）成功后，必须回头完善手册，以实际命令、版本、故障修复与验收证据固化经验，便于下次 AI 复现；此项是本次工作的收尾交付，未完成不能宣称整体收尾。

## 证据与恢复

[交付记录](sunmoonai/scripts/results/luna-kind136.20260926-2200.md) 包含命令、校验值、失败与修复、最终验收和边界。
最终原始验收：`/home/zymun/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/verification-20260926T220335.json`。原始输出在同批次 `logs/`。
家目录统一网络规则：`/home/zymun/网络管理统一方案.md`。
新集群 kubeconfig `~/.kube/sunmoon-kind-136.config`；旧环境 `~/.kube/kind-config`。
验收命名空间和 PVC 留在新集群；不要把已有集群自动删建。

## 下一步

Harbor 结果：`sunmoonai/scripts/results/luna-harbor-cold-backup.20260926.json`；完整目录 `luna-harbor-catalog.20260926.complete.json`；方案 `sunmoonai/kind-infrastructure/docs/harbor-preservation-plan.md`。3 项目、64 仓库、165 顶层/429 含子清单制品、164 tags；6 份数据归档共 16.85 GiB。备份根 `~/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z`。`state.json` 保存恢复状态，`verification.json` 校验 1509 个 blob、429 个 manifest 与 1211 个层/config/子清单依赖摘要；隔离恢复 false。

服务恢复于 2026-09-26 14:59:57 UTC，7 个控制器均恢复 1/1 Ready、Harbor healthy、read_only=false，前后目录含空项目/仓库比对一致，无恢复警告。六份卷是停服后复制；输入和归档私有配置未入 Git。入口 TLS 额外依赖 `ingress-platform-dev/traefik-tls-secret`，已在 `preparation/private/` 保存，清单 `preparation/tls-addendum.json`。本机备份与源数据同磁盘，不是独立介质灾备。

隔离恢复方案 `sunmoonai/kind-infrastructure/docs/harbor-isolated-restore-plan.md` 已实施。原私有 59 资源清单在 `restore-plan-20260926/manifests-private.json`，SHA256 `3aef6e503b50786915931ab7b70da819de7f428bdee09a686e71ab44d17f0239` 保持不变；运行期精确网络补丁另存。新 namespace `harbor-restore-20260926`，worker 上独立 `/var/local-path-provisioner/harbor-restore-20260926/` 六目录；8 个固定 amd64 自举镜像已离线导入。**不要重新运行 prepare 或覆盖这些数据。**

本轮执行入口 `materials/harbor_restore.py`、`harbor_restore_verify.py`。原始证据在 `~/packages-to-be-installed/releases/harbor-preserve-20260926/restore-run-20260926/`，脱敏结果 `sunmoonai/scripts/results/luna-harbor-isolated-restore.20260926.json`。15:25 UTC 开始、15:44 读取验证及回滚通过，15:53:33 最终复核，约 28 分钟，小于 60 分钟窗口。容量保守上界 23.31 GiB（含两个节点原有全部 containerd 数据），小于 30 GiB；剩余 500.87 GiB。

结果：全部 3 项目/64 仓库/429 含子清单制品/164 tags 及元数据与备份一致；worker2 缓存原先不存在的 Node 摘要经新 TLS 域名实际拉取，启动 v24.18.0；网络负例和 registry 重建后读取通过。新副本 8 控制器为 0、无 Pod，6 PVC Bound/PV Retain；port-forward 关闭。worker2 原配置/hosts 按 SHA256 恢复，临时 CA 项撤回、containerd 重启后 RuntimeReady/NetworkReady，新三节点及 Calico Ready。旧 Harbor 7 控制器 Ready、healthy、read_only=false、完整目录不变。Service/独立存储保留，临时入口不在服务。

失败与修正：缺少 certs.d 父目录导致第一次中止；补齐目录与部分回滚。校验 HTTP Accept 缺少 OCI 单清单导致 404，旧环境对照复现后修正。worker2 经 VXLAN 的实际源为 `10.245.175.64`，原策略未含此地址；用 route/conntrack 确认后只追加该 /32 → 网关 8443，镜像拉取从超时恢复为成功（2.82 秒）。修正和历次失败 acceptance 均保留。验证脚本已固化路由/接口核对，最终单独验证幂等路径后网关停回 0。

恢复节点中断操作前先读 `trust.json` 和脚本 README；文件与本轮写入摘要不符时不强行覆盖。当前 trust.restored=true，无待处理回滚。下次恢复读取演练不能复用“原先未缓存”的断言，因为该 Node 镜像现在已缓存。

现场发现并已纳入方案：core/jobservice 原 hostAliases 指向 `101.126.151.0`，已在新清单删除；原有两条手动复制策略和两个清理类定时任务。首轮 jobservice 保持 0，只验证数据/镜像读取链路，不能宣称后台任务或全套 health 通过。出站限定本 namespace 和 DNS，registry upload purge 关闭，Trivy 禁联网更新。

恢复渲染发现原资源备份遗漏动态 Trivy PVC/PV 的元数据（instance 标签不一致），但其数据已归档校验。已按原绑定补读到 `preparation/private/storage-addendum.json`，校验与原因在 `preparation/storage-addendum.json`；renderer 已纳入。`harbor_prepare.py` 改为沿真实 Pod 的 PVC 引用补全元数据，未重跑冷备份。不要改写历史备份时点的事实。

构建物料试验批次：`~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`；入口在 `sunmoonai/cicd-platform/materials/`。已通过东京主机取得并以 rsync 回传 6 份公开工具文件，62,737,201 字节，复核 pnpm SRI/PyPI SHA256/Node 校验清单并登记 `preparation.json`。Node 24.18.0、pnpm 10.24.0、uv 0.11.32、Python 3.12.13 在实际基镜像的无网络非 root 临时容器中运行通过。远程磁盘阈值已改为 8 GiB，私有源码未上传。

本地 `materials.py packages` 在前端 pnpm fetch 阶段因 npm 官方源 ECONNRESET 有界重试后退出 1；日志 `evidence/20260926T225021131846.log`，命令信息为同名 JSON。后端包步骤未开始。已保存清单和独立缓存，可继续准备；工具通过不代表依赖闭包已齐。下一次可检查公开依赖清单后利用已授权远程中转，不能上传私有源码或应用凭据。

按 [物料操作手册](sunmoonai/kind-infrastructure/docs/物料提交备齐方案和方法.md) 生成执行卡，确定具体试验范围后，以模板前后端完成源码/子仓恢复、pnpm/uv/工具链物料与禁公网构建验证，再接真实 CI/CD。
[下一阶段方案](sunmoonai/kind-infrastructure/docs/production-readiness-next-plan.md) 保存平台全新初始化、可观测性与旧环境清理的顺序。业务 E2E 最后，云端包与旧部署脚本尚未升级。
不得把 A/B 通过写成整个项目达到生产标准。只本地提交，不 fetch/pull/rebase/push。


## 2026-09-27 当前交回与新约束

所有者要求本轮结束时明确改动文件、后续 inbox 集群/kubeconfig/kubectl，远程助手待所有者回传分支后审阅。本地提交，不 push；不主动向 inbox 或外部助手发消息。完整交接见 `kind-infrastructure/docs/luna-handoff-and-inbox-targets.md`（实际在 sunmoonai 下），逐文件清单一并保存。

所有者最新提醒已纳入：**sunmoon-kind-136 是一次性验证环境，不承载正式数据，切换前会重建**。当前不再往里面安装组件；正式化前要确定宿主挂载。旧 kind-worker2 无宿主目录挂载，沙箱持久卷在容器内部，禁止删除该节点容器。原“旧业务数据不保留”不能用来覆盖这一限制。新 Harbor 恢复副本 8 控制器继续为 0，六卷保留，不作为正式镜像源。所有者已选定本地与云上均在集群外运行 Harbor，本地为 WSL；不自动执行迁移。

方案 `sunmoonai/kind-infrastructure/docs/storage-and-harbor-placement-decision.md` 已按所有者决定更新：sunmoon-kind-main 三节点各挂 local-path 与 static 两目录，后者节点内保持 `/data/kind-local-storage`。上层部署代码统一，仅 KIND/kubeadm 两种建群适配；本地/云端 Harbor 都移出集群，官方 2.13.2，同版本逻辑库/registry/密钥恢复，云端仅统一代码、dry-run 与静态检查。仍只写方案，未获新代码、重建/迁移/清理执行授权。现有验收 PVC 数据在节点容器内，Pod 重建保留不代表节点删除持久。

业务 inbox 当前仍指向旧 kind：`~/.kube/kind-config`，匹配客户端 `~/packages-to-be-installed/releases/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl`，UID `5d71ab3a-ea5a-4535-adc6-d7698d820249`。新验证环境 `~/.kube/sunmoon-kind-136.config`，客户端 `~/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/bin/kubectl`，UID `f5b11e20-1428-48a0-8c7a-51bc9ef27896`。默认 PATH 工具不匹配，须显式选择；不改门禁预期 UID。只读现场快照 `sunmoonai/scripts/results/luna-handoff-clusters.20260927.json`。

模板离线构建结果 `sunmoonai/scripts/results/luna-materials-offline.20260927.{md,json}`。756 npm + 58 Python wheel，814 文件/276,598,294 字节，清单 SHA256 `decd851f3c4fa5721afa8c89d57325492dcad49be10c6dd379999dae406e55bb`。原锁不改，模板 Web 前端干净生产构建/standalone，后端离线安装/ruff/format/pyright/compileall 均通过；缺包、有效 ZIP 错误哈希、修复后成功及受控下载中断均通过。私有源码未上传，远程仅公开清单和下载/中断脚本。入口及完整方法在 `cicd-platform/materials/README.md`（sunmoonai 下）。

原始证据：批次根 `~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`；正例 `work/offline-trial-1790472978821158770/result.json`，负例 `work/offline-negative-1790473394048549144/result.json`，中断 `evidence/public-download-interruption.json`。首个损坏样本被 ZIP 检查拒绝，改成有效 ZIP comment 后明确 Hash mismatch；旧失败日志都保留。HTTP 半文件重取、完整文件复用；rsync 负责回传断点。

批次逻辑文件共约 4.02 GiB，低于 30 GiB；本机剩余约 496.64 GiB。结束时无本轮材料临时容器。原始归档不删，副本及历史日志保留；代码可 revert，无本单元集群回滚。管理前端只归档未构建；没有生产 Dockerfile 改动、OCI 发布、数据库/单元/E2E 测试、内部 Git/包仓或 CI/CD。下一步在所有者决策后推进正式存储与 Harbor 实施方案，不能直接沿旧文档将一次性验证集群晋升正式环境。


## 所有者最新存储决定与容量（2026-09-27 10:21）

拟新建 C:/wsl-disks/sunmoon-data.vhdx 动态 ext4 数据盘，挂 /mnt/sunmoon-data，分别 bind /data/kind-clusters 和 /data/harbor。**禁止在旧 /data/kind-local-storage 上挂载任何东西。**管理员 PowerShell 创建/附盘由所有者本人执行，方案包含完整审阅稿命令；现有 attach 脚本含旧 E 盘与旧路径卸载逻辑，不得直接执行。新脚本需沿用既有入口并扩展严格 UUID/挂载检查、启动门禁与开机/登录计划任务。

上限不固定 100G：实际静态数据 17.186 GiB、旧两 worker 动态卷合计 0.240 GiB，基线 17.427 GiB；三倍 52.281 GiB，**建议 60 GiB 待审**。Harbor 冷备份 16.851 GiB 单独留在新盘之外，不重复计入承载量。C 盘空闲 231.96 GiB；WSL 系统 VHDX 文件逻辑大小 480.45 GiB，ext4 已用 459.00 GiB。新盘长满 60 GiB、不回收任何旧数据时静态预计余 171.96 GiB；另留新备份/临时预算和元数据余量，创建前与运行期仍须守住至少 50 GiB。原始记录 `sunmoonai/scripts/results/luna-data-disk-sizing.20260927.json`。

新数据 VHDX 与系统 VHDX 在同一 C 盘物理硬盘，不防硬件故障。同盘备份防误删/升级失败；机器外只备数据库、对象存储、~/private，落点待所有者选移动硬盘或客户端加密对象存储；不外传、不创建资源。统一架构目标与全部后续改动清单以方案开头为准。本轮只做了只读调查和方案更新，没有执行方案中的 PowerShell、挂载、停服或部署。


## 新增只读空间盘点与回收方案

所有者要求解释 WSL 已用约 459 GiB 并逐项审批回收。新增 `sunmoonai/kind-infrastructure/docs/wsl-space-reclamation-plan.md`。严格禁止 docker system/volume/container prune 及任何等效的容器/卷清理；停止旧节点仍是观察期回退保障。回收顺序为构建缓存、宿主未引用镜像、节点未用镜像、离线物料/重复备份；每项给预算、影响和恢复依据，不自动实施。压缩要关闭 WSL，由所有者另开维护窗口；记录前后 VHDX Length/C盘free/Linux used，长期措施为 Harbor 保留与构建缓存生命周期。

Docker 只读 API 已得：2220 条构建缓存记录共 194.03 GiB，其中 158.04 GiB 与镜像共享，不能当全部可清。排除共享/InUse、7 天未用候选 854 条共 29.68 GiB，清单 `luna-build-cache-candidates.20260927.json`，未批准。宿主 208 镜像中 205 个未被宿主容器引用，仍须扣除 KIND/Harbor/离线与回退依赖；不能自动全部删除。六个运行节点与一个原有停止容器均保留。

全根 du 首轮超过 180 秒停止，改用有界分目录扫描；只停止了本轮对应 du 进程，未动服务。目录与 Docker/CRI 记录在 scripts/results/luna-{wsl,docker}-space-inventory.20260927.json。所有空间结果均为在线只读快照，不是新冷备份，也不代表清理/压缩已经完成。


空间回收盘点收尾：目录实际 du 为 home 88.25 GiB（含物料40.07 GiB）、Docker目录92.18 GiB（其中卷90.98 GiB，禁止清理）、usr11.16 GiB。containerd逐文件扫描120秒超时，不伪造其du总量；Docker API完整层记录245.29 GiB。宿主未引用镜像独有层合计59.41 GiB、节点未命中CRI引用记录合计41.52 GiB，均尚未扣系统/回退/自举保留集合，不能作为确定可回收量，也不能与缓存简单相加。

明确候选：R1 ≥7天、非共享、非InUse缓存29.68 GiB（若≥30天为27.66 GiB，两者包含）；R4七个独立inode重复文件全SHA相同0.547 GiB，清单 `luna-duplicate-materials-candidates.20260927.json`；审阅后可再生成的试验工作目录约3.12 GiB，保留结果/日志后才可提请删除。当前Harbor冷备份和正式物料建议回收0。所有候选未批准，未执行任何清理/压缩/停服。Docker/CRI盘点过程未启动原有停止容器。

交付机械检查：Python AST语法及新增JSON解析通过，git diff --check通过；前述获准模板T0–T4实际正负例已通过。统一部署/云SSH/dry-run/新挂载/压缩代码仍仅是方案，不能说bash -n或shellcheck验收过尚未编写的脚本。家目录网络手册已补§19记录实际离线物料结果与待审方案入口，没有改变运行配置。


## 本轮获批回收与 100 GiB 决定（2026-09-27）

本单元基线 c8b3ce6efb7bbb247917c728d6e94b0807f01f28。所有者批准 R1 ≥7 天档、R4 七个重复文件，明确 R2 必须在宿主 Harbor 恢复全目录验收后，R3 取消；试验目录待远程助手审分支后再定。另明确动态数据盘上限改为 **100 GiB**，更新主方案 PowerShell 为固定 100；创建仍由所有者本人操作。此前 60 GiB 待审文字均为历史建议，被本决定取代。

R1 854 条执行前均满足原条件，运行时精确 ID/年龄/非共享过滤，实际删除 375 条、6,386,095,842 字节（5.947 GiB）。195 条父缓存 LastUsedAt 在清理过程中刷新，它们与上游共 479 条 / 23.730 GiB 保留；不放宽 7 天门禁。最初 shared=false 预览零条在删除前停止，查本机版本源码后用 private="" 经同集合预览再执行。R4 七对文件重新核验 SHA256/大小/独立 inode 后删除副本，共 587,493,376 分配字节；正式副本和全部备份保留。操作脚本 space_reclaim_20260927.py 及证据见 scripts/results/luna-reclaim-*（sunmoonai 下）。

回收前后 root used 492,870,619,136 → 485,905,276,928 字节，净下降 6.487 GiB；VHDX Length 515,879,469,056 未变；Cfree 248,957,067,264，未压缩。208 个宿主镜像、7 个容器 ID/状态、卷名集合前后相同。所有节点/卷及旧 worker2 均保护，没有 system/container/volume prune 或等效操作。

R2 只读：105 个本地应用镜像与 Harbor exact index/manifest digest 相同；244 条经父子/别名关系筛选的专属缓存；content 6.274 + snapshot 28.240 = 34.514 GiB 去重规划估算，实际 GC/lease 可能降低收益，不是承诺。其余 100 镜像 API 独有层 32.973 GiB（未扣保护）：20 个 Harbor 来源、32 个 tar 精确描述符及必需 amd64 blobs 全 SHA256 来源，重叠17，合35个有核验来源，65个未证实继续保留。逐个来源 luna-r2-archive-sources.20260927.json；未执行 R2。

压缩与入口切换合并一个维护窗口，所有者操作；不启用自动收缩，不关闭本轮 WSL。主方案和空间方案已更新维护顺序、回退和实际量。业务 inbox 仍在旧 kind，~/.kube/kind-config，匹配 kubectl 1.27.3；sunmoon-kind-136 仅验证，新 main 尚未创建。下一步远程审阅本单元，再按主方案准备统一部署代码/物料和所有者附盘步骤；不把 R1/R4 完成说成迁移完成。

### 最新收尾指令（覆盖“立即继续回收”的安排）

所有者：“那就等最后再一起清理吧”“不过要记住一定要清理”。剩余回收延后到迁移与验收完成，作为不可遗漏的最终收尾门禁；现在停止追加清理。已经执行的 R1 375 条、R4 七文件不回写为未执行。待办：R1 剩余 479 条、R2 两类、远程审阅后的试验目录重新冻结清单并按授权执行；重新盘点各项实际量、更新物料手册与网络参考。来源/时龄不满足者保留并说明，绝不触碰容器/卷/观察期旧节点或唯一备份。空间方案第 8 节含逐项验收清单，未结清不能称整体迁移完成。

本轮机械检查：4 个新增 Python 脚本 AST、全部新增 JSON/JSONL 解析及 git diff --check 通过；R1/R4 前后保护对象一致。没有运行应用/云部署测试。家目录网络参考已追加第20节，未改运行配置。交付仍仅本地 luna 分支，不 push。

## 数据盘准备单元（基线 878c581ef3cb14c1d06896a1894d8d26962a857f）

修改 deploy-kind/attach-vhds.ps1 为显式 SunmoonData 模式、默认只打印，去掉旧 E 盘和任何卸载/重启操作；mount/ 两个副本改成转发。新增 initialize-sunmoon-data.ps1（所有者首次创建100GiB动态VHDX、唯一空设备防护）、sunmoon-data-storage.py（默认只打印的 setup/mount，以及只读 check）。检查含 UUID/ext4/rw、与系统盘不同设备、bind源inode一致、空间门禁、旧路径身份；setup只管理三条新fstab目标，有冲突失败，无自动fallback。旧native检查仍可用，新服务必须显式传 --layout sunmoon-data。

SHA256固定脚本与所有者执行卡已备齐。固定发布目录 C:/wsl-disks/scripts/storage-20260927-v1 与 /opt/sunmoon/admin/storage/storage-20260927-v1；不要让计划任务依赖临时worktree。owner-data-disk-100g.md 含完整命令、任务与中断续接。尚未运行任何Apply，未建盘、格式化、挂载、注册任务、改fstab或启动服务。

静态/只读结果 luna-data-storage-preparation.20260927.json：三PowerShell Parser通过；两shell bash -n/ShellCheck0.9.0通过；Python AST；Linux setup默认只打印、缺盘拒绝、旧native兼容通过。ShellCheck修正旧变量展开三处。Windows直接执行UNC默认plan被现有CurrentUser RemoteSigned拒绝，未修改/绕过策略；卡中给出本地固定副本发布供所有者操作，本地副本执行和真实挂盘/重启仍未验证。ShellCheck仅Ubuntu包下载解压/tmp，无系统安装。C盘剩余232.54GiB，目标VHDX不存在。

本单元只是存储前置，不是整个P1或迁移完成。registry-platform、官方Harbor2.13.2物料、PG17逻辑迁移、入口代理、云steps与消费开关仍待完成。先等待所有者按操作卡返回UUID及check输出，同时可继续独立准备仓库模块/物料。新服务启动门禁尚须实际接线，不得宣称已形成自动保护。
