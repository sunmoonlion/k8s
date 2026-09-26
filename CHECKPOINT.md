# Luna 工作检查点

当前单元：Kubernetes 离线物料与独立建群 A/B 已完成；Harbor 全量冷备份及原服务恢复已完成并校验，隔离恢复尚未执行。模板源码/基镜像/工具已准备，pnpm 包预取因公网连接重置失败；完整离线构建/CI/CD 尚未通过。
实施基线 `bee0b049ca9e84fead641928816fec4a6a1c6c48`；交付提交是包含本检查点的 `luna` 提交（用 git log 定位）。

## 决定与边界

- 当前主要在本机 KIND，面向将来云端；不按付费试运营立即部署云端。
- 用户要求先了解现场、讨论方案、确定后实施；不必机械执行 fable 原任务次序。
- 批准 Kubernetes 1.36.4 / KIND 0.33.0 / Calico 3.32.2，保留旧 kind/入口/数据。
- 允许 txy-tokyo 下载公开物料并回传；没有远程建群或清理远程服务授权。
- 国内云也不保证下载公共镜像；后续 CI/CD 需内部物料供应与失败恢复设计，尚未实施。
- 所有者原有“基础软件离线包 + Harbor 预存镜像”方式继续保留；明确缺口是 Git 源码与 npm/Python 依赖供应。先检查实际依赖，再讨论内部仓库与同步方案，不先安装新平台。
- 业务端到端测试最后做；本次网络/PVC 检查是基础设施验收。
- 所有者最新确认：旧业务数据无需保留，业务全新初始化。**私有 Harbor 镜像数据必须保留**：默认覆盖全部现存制品及其 registry、数据库、配置、Secret/证书和存储恢复依赖；不能缩减为当前运行镜像。独立备份、恢复、摘要比对与新集群拉取验证前，不删除旧 Harbor/相关卷/目录/必要缓存。已完成冷备份与旧服务恢复，未执行隔离恢复或旧集群清理。
- 所有者通过异步答复明确批准“现在执行冷备份”，范围为 `harbor-preservation-plan.md` 第 3 节。该单元已完成；授权不包含迁移入口或清理旧数据。新集群恢复的具体 manifests/独立存储和访问入口需先给出方案并讨论。
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

下一步：提出可审阅的新集群隔离恢复 manifests 和差异，明确独立 namespace/PV/PVC/路径、临时 TLS 入口、原版本组件、阻断副本访问旧服务及公网的网络策略；确认后恢复并从新集群实际拉取镜像。在此之前保留所有旧 Harbor 数据。备份/恢复脚本入口见 `sunmoonai/cicd-platform/materials/README.md`。

构建物料试验批次：`~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`；入口在 `sunmoonai/cicd-platform/materials/`。已通过东京主机取得并以 rsync 回传 6 份公开工具文件，62,737,201 字节，复核 pnpm SRI/PyPI SHA256/Node 校验清单并登记 `preparation.json`。Node 24.18.0、pnpm 10.24.0、uv 0.11.32、Python 3.12.13 在实际基镜像的无网络非 root 临时容器中运行通过。远程磁盘阈值已改为 8 GiB，私有源码未上传。

本地 `materials.py packages` 在前端 pnpm fetch 阶段因 npm 官方源 ECONNRESET 有界重试后退出 1；日志 `evidence/20260926T225021131846.log`，命令信息为同名 JSON。后端包步骤未开始。已保存清单和独立缓存，可继续准备；工具通过不代表依赖闭包已齐。下一次可检查公开依赖清单后利用已授权远程中转，不能上传私有源码或应用凭据。

按 [物料操作手册](sunmoonai/kind-infrastructure/docs/物料提交备齐方案和方法.md) 生成执行卡，确定具体试验范围后，以模板前后端完成源码/子仓恢复、pnpm/uv/工具链物料与禁公网构建验证，再接真实 CI/CD。
[下一阶段方案](sunmoonai/kind-infrastructure/docs/production-readiness-next-plan.md) 保存平台全新初始化、可观测性与旧环境清理的顺序。业务 E2E 最后，云端包与旧部署脚本尚未升级。
不得把 A/B 通过写成整个项目达到生产标准。只本地提交，不 fetch/pull/rebase/push。
