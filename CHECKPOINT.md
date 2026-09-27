# Luna 工作检查点

当前单元：Kubernetes 离线物料与独立建群 A/B 已完成；Harbor 冷备份、原服务恢复和首轮隔离数据恢复/镜像读取验证均通过。隔离副本已停止，六卷保留；旧 Harbor 运行正常。模板源码/基镜像/工具已准备，pnpm 包预取因公网连接重置失败；完整离线构建/CI/CD 尚未通过。
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
- 所有者要求编写《物料提交备齐方案和方法.md》，可直接交给 AI 准备物料和 CI/CD；试验通过后再更新为可复用的方法。此次完成文档，不宣称试验通过。
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
