# 整套部署、启停与开机恢复

从k8s根目录操作。当前开发维护窗口2小时、容量底线10GiB。本文区分已经跑过的部署入口与尚待安装、重启验收的生命周期候选，不能把脚本存在当作完成。

## 整套部署（已实际重复部署）

```sh
make -C infrastructure platform-deploy
make -C infrastructure platform-check
```

`platform-deploy`读取各模块及应用原有`enabled`开关，依次执行宿主预检、Harbor物料/部署、入口、KIND、Flux/SOPS、基础声明、平台服务、tpl/info/knowledge/investment。每个模块使用独立Ansible进程，避免事实变量污染。配置选择文件`.build/host/deployment.mk`每次自动生成，不是用户配置。`platform-deploy-selected`是内部编排目标，日常调用前两条入口即可。

不重新构建应用镜像，不自动发布或批准新GitOps声明；使用已晋级源和已有固定镜像。更改配置仍须render/stage、审阅提交、发布、显式晋级。禁用开关跳过本模块，不删除已部署资源。现有数据盘、工具及物料、秘密主备、已发布镜像为前提；尚未验从空Windows主机完整引导，也未验删群后全量冷建。

`platform-check`复用原有集群/Harbor/入口/Flux检查及平台、四应用公共协议检查。它会创建限定协议探针/临时数据并清理，不是纯只读；采用SNI/Host和CA的真实端口检查不代替宿主DNS、系统证书信任或浏览器渲染验收。

## 启停候选（尚未安装/实际验收）

```sh
make -C infrastructure platform-plan
make -C infrastructure platform-status
```

计划生成候选、检查shell/存储身份、发布Windows审阅副本；会写候选文件，不安装任务、不启停服务。状态显示systemd单元的当前状态。首次维护安装后，日常入口为：

```sh
make -C infrastructure platform-start
make -C infrastructure platform-stop
```

启动顺序：已有盘附加/三挂载及systemd、Docker可见性 → Windows物理增长容量 → Harbor后端健康 → TLS入口 → 指定三节点/API身份 → Pod可用性和Flux当前代次Ready。停止为新入口→新节点→外置Harbor，保留所有节点、卷、数据、身份和镜像。原始kind不由此入口启动或删除。停止后再次开启WSL会按开机开关恢复；维护压缩前应设置维护标记并暂停Windows任务。

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

第一条预览，第二条按候选SHA256发布到`C:\ProgramData\Sunmoon\platform-kind-v1\boot-<摘要>`，保护父目录、文件的ACL和管理员所有权，再更新已有`sunmoon-data-mount`任务。只有所有者登录触发、最高权限、固定隐藏启动文件、无重复周期。新任务可启动Ubuntu并检查/附加现有VHDX；不会初始化磁盘或启动业务服务。原任务XML备份在候选目录。维护标记`C:\wsl-disks\sunmoon-data.maintenance`存在时附盘及新服务启动均拒绝。

Windows完成后回WSL：

```sh
make -C infrastructure platform-enable-boot
make -C infrastructure platform-start
make -C infrastructure platform-check
```

enable-boot先核对任务归属/权限/精确动作并完成一次真实附盘检查，再核对所有节点ID，改为systemd统一管理新节点重启、禁止原始kind三个节点自动重启，停用旧单次附盘单元，按`host_boot_enabled`启用新单次恢复单元。这不会立即停止旧worker或删除任何容器。

Windows任务只附盘；WSL的Type=simple单次恢复避免回调WSL时阻塞systemd就绪。新Harbor和入口保留现有独立systemd单元，Docker重启策略仍为no。Docker本身维护后应执行platform-start/check；目前不承诺任意意外Docker退出后的自动全套恢复。

## 本次候选维护范围

候选尚未安装。下一窗口在2小时内安装独立运行副本、管理员任务与统一目标，再实际统一停止/启动和重复启动检查；保留所有新旧节点、卷和身份。原始worker当前运行态保持，只修改它们的自动重启策略，原始控制面继续停止。维护前保存入口/单元、容器ID和运行态、PV/PVC身份、Harbor镜像目录/仓库manifest清单；暂停新Harbor后核对registry目录内容。恢复后核对完整镜像清单、认证拉取和平台/四应用协议。数据库/WAL/运行日志重启会变化，不能把这些文件的字节相等当作业务数据持久化标准。

不关闭WSL、不删除重建KIND，不改变DNS/业务版本、不删除数据。Windows任务安装可能需要一次管理员UAC；后续运行固定任务，不循环提权，不改变敏感动作防护规则。预检、语法或身份/摘要不符时停止安装/启用，保留原入口与当前服务；启停失败按下面备份回退。

## 实际验收与回退

获批2小时维护内：安装→任务实跑→启用→统一stop/start→公共协议检查→重复start/check；对比节点ID、卷UID及Harbor目录摘要、镜像清单。随后安排真实WSL/Windows重启，检查原控制面仍停、新三节点Ready、数据盘/Harbor和镜像摘要完整、新节点认证拉取。WSL关闭会中断当前助手，必须先保存检查与恢复步骤，由Windows侧回传结果。KIND删除重建是独立后续验收，不能因为这次启停成功便宣布它通过。

回退只恢复本次备份：停止新boot任务和新平台单元、恢复旧Windows任务XML、旧单元文件/启用状态，撤销本次新增的两个sunmoon-platform.conf依赖drop-in、按记录中的精确容器ID恢复原restart policy；按维护前运行状态恢复新Harbor/入口/三节点。旧控制面保持维护前停止状态，不用启动旧集群冒充新服务恢复。安装的独立文件保留用于诊断，不触及数据卷。

## 当前启动问题的依据

2026-10-05只读复核：Harbor和入口active但boot disabled；六个新旧节点仍为on-failure:1。原Windows附盘任务只有登录触发，上次结果1，回执仅保留“Mount validation failed”；旧WSL附盘单元那次先失败，随后复查成功，但明确未启动服务。旧任务在Ubuntu未运行时会跳过，并不保证开机新平台恢复。底层失败原因没有原始详细日志，不能确定为网络、扩盘或清理；新候选保留具体守卫失败点。

宿主DNS（包括Kibana）、Windows/WSL证书信任和真实浏览器检查尚待接入。本单元不改变hosts或宣称这些通过。
