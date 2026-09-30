# 新部署体系交接

## 目标、工作区与授权

从零建立长期维护的部署代码，第一期 KIND，使用原生 Make/Ansible、官方 Harbor Compose、KIND、Flux/SOPS；不得调用旧 sunmoonai/utils/luna 部署链。五仓在 `/home/zymun/worktrees/platform-kind-v1`，各自分支 `platform-kind-v1` 从本地 master 建立，基线见 [输入盘点](docs/platform-kind-v1/inventory.md)。原 luna 仅参考。

用户已确认采用新版本、不迁移旧业务数据和旧 Harbor 镜像；应用可修改重建，业务 Python 3.13.15。旧节点、卷、备份和他人 local-integration 仍受保护。日志每容器 3×20 MiB 已获批；镜像、缓存、备份删除不因日志批准而放行。本轮仅 k8s 改动，应用四仓未改，无 push。

本单元基线 **f3573d511c78cb9b68cc7f4605ef151896f7321b**（独立 Harbor）；节点构建 e280a3850953584853a4717945a8183baf18e5ec，离线镜像 eef098e272932a0ac3e279bfc002e1ea0ef1b9a0。当前提交见本文件所在分支 HEAD，最终交付须报完整 SHA。

用户本次明确批准“现在切换并验收真实镜像推拉”，范围为 30443 约一分钟 TLS 中断、维护 10 分钟、恢复另 5 分钟。**该次窗口已执行并回退结束。不能解释为批准升级/重启宿主 Docker。**下一次影响全部 KIND/Harbor 的维护需确认，具体方案和物料已准备。

## 当前现场：入口已回退，Docker 修复待维护批准

日期 2026-10-01（UTC 2026-09-30 晚间）。

- 正式 30443：保留的 `sunmoon-sni-transition-main-20260928`，Harbor 转 127.0.0.1:18443；其他域名转 **172.18.0.5:30443（kind-worker）**。不能改成 main 的 19443，那里尚无应用入口。
- 新 Harbor：`sunmoon-registry.service`，10 个官方 2.15.2 服务，127.0.0.1:11443，运行中；新 HAProxy：`sunmoon-entry.service`，候选 **127.0.0.1:32443**，运行中。两 unit **disabled**，尚未验开机启动；NRestarts=0。
- 新 Harbor data：`/data/harbor/platform-kind-v1/data`；私密配置 `/etc/sunmoon/registry`；运行文件 `/opt/sunmoon/registry`；数据盘 230 GiB、UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`。服务器证书 1825 天，到期 2031-09-29 UTC，CA 3650 天。
- 新入口配置 `/etc/sunmoon/entry`、运行 `/opt/sunmoon/entry`。HAProxy 只做 SNI TCP 分流，不持有私钥；官方摘要固定，UID10001，readonly/cap_drop ALL，有限 CPU/内存/PID/日志。
- 新项目 `platform` 为私有，publisher 仅 pull/push、puller 仅 pull，均无删除权限，有效期90天；文件 `/etc/sunmoon/registry/private/{publisher,puller}.json` 和对应 `*-auth.json`，root0600。到期须显式轮换，自动轮换/告警未完成。
- 新镜像仍在新仓库：`harbor.sunmoonai.com:30443/platform/haproxy@sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`；这是**新仓库中的目标引用**，当前正式地址已回旧仓库，不能直接认为该引用现可从30443获取。正式切换后才恢复该地址可用性。
- 旧 Harbor jobservice 状态 **created、StartedAt全零**，旧聚合健康 unhealthy；其他7个组件 healthy。不是本次停止造成。原卡“两个 Harbor 健康”的表述错误，已改为明确基线；本次没有擅自启动旧 jobservice。

### 本次实测结果

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
- 新增Docker deb：三个29.8.1升级、三个29.4.3回退。校验Docker InRelease签名、Packages摘要和文件SHA256/大小；`fetch-artifacts` **ok20 changed1 failed0**。尚未安装。
- 宿主CA由`registry-accounts`追加`/etc/docker/certs.d/harbor.sunmoonai.com:30443/platform-kind-v1-ca.crt`，保留旧CA，未修改全局系统信任/daemon设置/代理。

### 前序成果仍有效

Ansible2.21.4（宿主Python3.12.3）、Compose5.5.1，`.tools/bin`固定KIND0.33.0/kubectl与kubeadm1.36.5。官方构建节点`sunmoon-kind-node:v1.36.5-kind0.33.0` manifest **676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b**；实际containerd2.3.4/runc1.4.3。节点+3项Calico3.32.2归档641,355,776字节，内置内容已核验，尚未用新体系创建集群。

Harbor2.15.2官方包177个blob/12镜像已核验，运行使用`harbor-offline-images.lock.json.archive_reference`（与上游压缩manifest不同）。service.yaml直接调用官方prepare镜像，官方Compose+有限override，挂载守卫、systemd唯一重启、3×20m日志。此前重复deploy **ok58 changed0 failed0**，真实stop/start及10容器healthy通过。Trivy DB未齐，扫描未验收；备份/恢复尚未完成。

## 下一步（按此顺序）

1. **取得新的Docker维护窗口批准**。已写[具体方案](docs/platform-kind-v1/docker-maintenance.md)：仅三个包升29.8.1，宿主containerd2.2.3保持；当前live-restore=false，影响27个运行容器（含8个KIND节点）。20分钟维护、失败另15分钟恢复。准备已做完：六包在本地、APT演练恰好3升级0删除；必须先冷备份新Harbor并校验，再按精确运行清单停启。旧停止容器不能批量启动。不能将包降级当作完整数据快照保证。
2. 宿主Docker修复后，先候选地址认证拉取，再按操作卡切30443，完整跑新版publish入口、应用分流和恢复基线。用户没有新批准前，不再切换/升级/重启。
3. 补扫描器DB、正式Harbor备份恢复演练，再创建新KIND/Flux，推进模板公共能力及平台/应用部署。
4. 完成单组件与整套一键、统一启停、开机自动挂盘、WSL/KIND重启及KIND删除重建后的Harbor摘要/新节点拉取验收。
5. 完成长期开销监控、受控清理；镜像/缓存/备份策略按具体清单批准。最后清理本次临时目录、重复物料和东京下载；受保护旧资源满足退出条件后再清理。

最后容量检查：2026-09-30T19:08:51Z，计数据盘长到230GiB及196,612,264字节下载预算后，C盘仍余 **60,361,613,144字节**，高于50GiB；后续操作须重测，不能当作整套部署均够空间。数据VHD实际分配176,064,299,008字节。Windows任务、附盘、执行策略和WSL没有变化，本轮未连接东京。

尚未实现新集群/完整部署/全套启停，不得宣布总体完成。当前无显式token预算。停在明确需要扩大停服范围的维护批准，普通文档、物料与代码工作不重复请求批准。
