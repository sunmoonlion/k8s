# 整套部署、启停与开机恢复

从k8s根目录操作。当前开发维护窗口2小时、容量底线10GiB。整套部署、独立启停运行副本和Windows附盘任务已安装；实际停止/恢复已执行。两轮完整停止/启动、重复启动及镜像目录/认证拉取已实际通过。Windows/WSL真实重启及删群重建仍须完成，不能把启停通过当作全部持久化通过。

## 整套部署（已实际重复部署）

```sh
make -C infrastructure platform-deploy
make -C infrastructure platform-check
```

`platform-deploy`读取各模块及应用原有`enabled`开关，依次执行宿主预检、Harbor物料/部署、入口、KIND、Flux/SOPS、基础声明、平台服务、tpl/info/knowledge/investment。每个模块使用独立Ansible进程，避免事实变量污染。配置选择文件`.build/host/deployment.mk`每次自动生成，不是用户配置。`platform-deploy-selected`是内部编排目标，日常调用前两条入口即可。

不重新构建应用镜像，不自动发布或批准新GitOps声明；使用已晋级源和已有固定镜像。更改配置仍须render/stage、审阅提交、发布、显式晋级。组件README可独立更新；发布一致性核对只排除这些说明文件，其他GitOps文件仍须与晋级Git对象一致，未提交文件仍被拒绝。禁用开关跳过本模块，不删除已部署资源。现有数据盘、工具及物料、秘密主备、已发布镜像为前提；尚未验从空Windows主机完整引导，也未验删群后全量冷建。

`platform-check`复用原有集群/Harbor/入口/Flux检查及平台、四应用公共协议检查。它会创建限定协议探针/临时数据并清理，不是纯只读；采用SNI/Host和CA的真实端口检查不代替宿主DNS、系统证书信任或浏览器渲染验收。

## 日常统一启停（两轮停启已验证）

**单独停一个单元**（2026-10-06）：`sunmoon-platform.target` 原来 `Requires=` 三个服务，systemd 会把「显式停其中一个」传播成「停目标」，目标再通过 drop-in 的 `PartOf=` 把另外两个也停掉——第 27 轮 `entry-stop` 就这样连带停了 Harbor 和集群。模板已改成 `Wants=`（`platform-stop` 本来就是逐个停、`boot.sh` 逐个启，不依赖 Requires），要重装运行副本（`platform-install-lifecycle`）才生效；重装前任何 `entry-stop` / `registry-stop` 都等于整套停。

```sh
make -C infrastructure platform-plan
make -C infrastructure platform-status
```

计划生成候选、检查shell/存储身份、发布Windows审阅副本；会写候选文件，不安装任务、不启停服务。状态显示统一target、boot、集群、Harbor及入口单元。cluster的active/exited是oneshot正常状态；boot enabled但inactive表示本次用手动start恢复、尚未执行真实WSL开机恢复，不应当作开机验收成功。当前已安装，日常入口为：

```sh
make -C infrastructure platform-start
make -C infrastructure platform-stop
```

启动顺序：已有盘附加/三挂载及systemd、Docker可见性 → Windows物理增长容量 → Harbor后端健康 → TLS入口 → 指定三节点/API身份 → 有界等待API就绪、Pod可用性和Flux当前代次Ready。停止为新入口→新节点→外置Harbor，保留所有节点、卷、数据、身份和镜像。原始kind不由此入口启动或删除。停止后再次开启WSL会按开机开关恢复；维护压缩前应设置维护标记并暂停Windows任务。

日常启动不会build、重新随机生成秘密、发布源或申请UAC。失败停止后续步骤并在journal显示原因，不启动原始kind作为自动回退，也不自动格式化/清卷。已成功启动的前置服务可能保持运行，先查看状态再恢复；不要将一次失败当作全部服务已停。

## 首次维护安装与Windows任务

先完成计划、审阅本地提交和维护批准，执行：

```sh
make -C infrastructure platform-install-lifecycle
```

安装保存当前节点ID/运行状态/完整restart policy及旧单元文件到`/mnt/sunmoon-data/backups/host/lifecycle-*`，安装root持有的独立运行副本和新单元，不启用boot。运行不依赖worktree或冻结Luna代码。

随后在**所有者本人账号的管理员PowerShell**执行一次固定候选安装；不得以另一个管理员账号创建另一份WSL环境：

```powershell
$Candidate = 'C:\wsl-disks\scripts\platform-kind-v1\candidate'
& "$Candidate\install-task.ps1" -CandidateDirectory $Candidate
& "$Candidate\install-task.ps1" -CandidateDirectory $Candidate -Apply
```

第一条预览，第二条按候选SHA256发布到`C:\ProgramData\Sunmoon\platform-kind-v1\boot-<摘要>`，保护父目录、文件的ACL和管理员所有权，再更新已有`sunmoon-data-mount`任务。只有所有者登录触发、最高权限、固定隐藏启动文件、无重复周期。新任务可启动Ubuntu并检查/附加现有VHDX；不会初始化磁盘或启动业务服务。原任务XML安装时备份在候选目录，收尾归档到上述私有证据目录；恢复前核对其摘要。维护标记`C:\wsl-disks\sunmoon-data.maintenance`存在时附盘及新服务启动均拒绝。

Windows完成后回WSL：

```sh
make -C infrastructure platform-enable-boot
make -C infrastructure platform-start
make -C infrastructure platform-check
```

enable-boot先核对任务归属/权限/精确动作并完成一次真实附盘检查，再核对所有节点ID，改为systemd统一管理新节点重启、禁止原始kind三个节点自动重启，停用旧单次附盘单元，按`host_boot_enabled`启用新单次恢复单元。这不会立即停止旧worker或删除任何容器。

Windows任务只附盘；WSL的Type=simple单次恢复避免回调WSL时阻塞systemd就绪。新Harbor和入口保留现有独立systemd单元，Docker重启策略仍为no。Docker本身维护后应执行platform-start/check；目前不承诺任意意外Docker退出后的自动全套恢复。

## 开机恢复看哪里

`sunmoon-platform-boot.service` 是 `Type=simple`（附盘要回调 WSL，不能用 oneshot 阻塞 systemd 就绪），所以 `is-active` 一启动就是 `active`。要判断恢复做完没有，看进程退出没有、结果是什么：

```sh
systemctl show sunmoon-platform-boot.service -p ExecMainPID -p ExecMainStatus -p Result
journalctl -b -u sunmoon-platform-boot.service --no-pager | tail -5
```

`ExecMainPID=0`、`Result=success`，日志尾部是「Owned Harbor, TLS entry and KIND restored」才算完。附盘脚本从 2026-10-06 起先 `wsl --mount` 再第一次 `wsl.exe -d`：盘在 Ubuntu 启动前附好，fstab 在最初的命名空间里挂，用户会话才看得见；详见 [诊断](troubleshooting.md#开机后数据盘只有-systemd-看得见)。

## 安装状态与剩余维护

2026-10-05已安装独立运行副本、管理员任务和统一目标；任务实际运行返回0，只有一个登录触发、无重复周期。六个新旧节点的自动重启均为no，新恢复单元已启用、旧附盘单元已停用。原始控制面保持停止、两worker保留运行。

已完成两轮整套stop/start和一次重复start。重复start前后90个Pod的UID及重启计数保持；57个Running Pod全部Ready，33个已完成初始化Job保留。平台/四应用公共协议、宿主真实Harbor认证推拉及三个新节点Always认证拉取通过。

暂停Harbor时完整记录data目录2676个文件的路径、大小和SHA256。两轮冷态之间registry/secret共1086个文件、13,210,981,875字节逐一一致；全量40仓库/104镜像条目的digest、标签及大小一致。变化仅为23个PostgreSQL文件和1个Redis文件，属于重启写入；不声称数据库物理字节不变。13组PV/PVC及既有Job身份、六节点ID/挂载/运行态、全部Docker卷保持。

原始成功与失败日志、完整文件清单及资产快照保存在私有`/data/kind-clusters/sunmoon-kind/bootstrap/evidence/lifecycle-maintenance-20261005T0825Z`；不得公开其中的输入/日志。此前窗口证据独立保留，不能用本轮成功覆盖失败记录。

不关闭WSL、不删除重建KIND，不改变DNS/业务版本、不删除数据。Windows任务安装可能需要一次管理员UAC；后续运行固定任务，不循环提权，不改变敏感动作防护规则。预检、语法或身份/摘要不符时停止安装/启用，保留原入口与当前服务；启停失败按下面备份回退。

## 实际验收与回退

获批2小时维护内：安装→任务实跑→启用→统一stop/start→公共协议检查→重复start/check；对比节点ID、卷UID及Harbor目录摘要、镜像清单。本次已完成上述停启、目录及协议核对。随后安排真实WSL/Windows重启，检查原控制面仍停、新三节点Ready、数据盘/Harbor和镜像摘要完整、新节点认证拉取。WSL关闭会中断当前助手，必须先保存检查与恢复步骤，由Windows侧回传结果。KIND删除重建是独立后续验收，不能因为这次启停成功便宣布它通过。

回退只恢复本次备份：停止新boot任务和新平台单元、恢复旧Windows任务XML、旧单元文件/启用状态，撤销本次新增的两个sunmoon-platform.conf依赖drop-in、按记录中的精确容器ID恢复原restart policy；按维护前运行状态恢复新Harbor/入口/三节点。旧控制面保持维护前停止状态，不用启动旧集群冒充新服务恢复。安装的独立文件保留用于诊断，不触及数据卷。

## 重启恢复中发现的组件问题

Elasticsearch的emptyDir在节点重启后仍保留。旧init命令把证书复制为0440，再次执行普通cp无法覆盖只读副本；表现为prepare-config CrashLoopBackOff、Kibana随之未就绪。已恢复当前Pod的三个临时副本权限以完成启动，原Secret、私钥内容及数据PVC未改。原模板及渲染候选改用`cp --remove-destination`，在实际固定镜像中连续复制两次，摘要及0440均通过；永久修复已按原生stage/提交/发布/晋级流程应用，后续两轮全节点停启已实际通过。不得把临时chmod当日常恢复方案。

Docker会在节点重启时重建`/etc/hosts`，丢失建群时添加的Harbor网关记录。原生节点ready步骤在核对精确ID和bind身份后，恢复且仅恢复该网关/仓库域名记录；统一start也会调用它，CoreDNS的Pod域名配置保持。实际修复后三节点Always认证拉取及DNS检查通过；不能用宿主127.0.0.1拉取代替节点拉取。

统一启动的API检查已增加有界readyz等待，避免RBAC尚未加载就检查节点；Pod和Flux有界收敛等待，不跳过健康标准。Windows容量助手在本地C盘运行，并与root运行副本逐字节核对，避免UNC触发RemoteSigned限制；未放宽Windows执行策略。安装器规范化旧任务的本机短账号后再核对SID，不更换WSL所有者。


原两小时窗口在等待管理员安装等操作期间已过期，停服前未及时复核截止时间；发现后结束新增停服并恢复平台。后续停服单独确认，从新批准时间计时，并在每次实际停服前核对窗口余量。

## 当前启动问题的依据

2026-10-05只读复核：Harbor和入口active但boot disabled；六个新旧节点仍为on-failure:1。原Windows附盘任务只有登录触发，上次结果1，回执仅保留“Mount validation failed”；旧WSL附盘单元那次先失败，随后复查成功，但明确未启动服务。旧任务在Ubuntu未运行时会跳过，并不保证开机新平台恢复。底层失败原因没有原始详细日志，不能确定为网络、扩盘或清理；新候选保留具体守卫失败点。

宿主DNS（包括Kibana）、Windows/WSL证书信任和真实浏览器检查尚待接入。本单元不改变hosts或宣称这些通过。
