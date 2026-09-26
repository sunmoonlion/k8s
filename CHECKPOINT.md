# Luna 工作检查点

当前单元：Kubernetes 离线物料与独立建群 A/B 已完成；模板构建物料试验进行中，源码 bundle/恢复与两个基镜像归档已完成，完整离线构建/CI/CD 尚未通过。所有者补充 Harbor 数据必须保留，已修订方案并只读盘点存储。
实施基线 `bee0b049ca9e84fead641928816fec4a6a1c6c48`；交付提交是包含本检查点的 `luna` 提交（用 git log 定位）。

## 决定与边界

- 当前主要在本机 KIND，面向将来云端；不按付费试运营立即部署云端。
- 用户要求先了解现场、讨论方案、确定后实施；不必机械执行 fable 原任务次序。
- 批准 Kubernetes 1.36.4 / KIND 0.33.0 / Calico 3.32.2，保留旧 kind/入口/数据。
- 允许 txy-tokyo 下载公开物料并回传；没有远程建群或清理远程服务授权。
- 国内云也不保证下载公共镜像；后续 CI/CD 需内部物料供应与失败恢复设计，尚未实施。
- 所有者原有“基础软件离线包 + Harbor 预存镜像”方式继续保留；明确缺口是 Git 源码与 npm/Python 依赖供应。先检查实际依赖，再讨论内部仓库与同步方案，不先安装新平台。
- 业务端到端测试最后做；本次网络/PVC 检查是基础设施验收。
- 所有者最新确认：旧业务数据无需保留，业务全新初始化。**私有 Harbor 镜像数据必须保留**：默认覆盖全部现存制品及其 registry、数据库、配置、Secret/证书和存储恢复依赖；不能缩减为当前运行镜像。独立备份、恢复、摘要比对与新集群拉取验证前，不删除旧 Harbor/相关卷/目录/必要缓存。尚未执行备份、恢复或旧集群清理。
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

先完成 Harbor 全量制品、实际容量与宿主挂载盘点，给出一致性备份/隔离恢复的具体方案；只读模式、停服务和入口切换按实际影响讨论后实施。只读存储记录：`sunmoonai/scripts/results/luna-harbor-preservation.20260926.inventory.json`。

构建物料试验批次：`~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`；未提交入口在 `sunmoonai/cicd-platform/materials/`。本地 npm 官方元数据连续三次 TLS 失败已停止；公开工具下载代码已传至 txy-tokyo 的 `/home/zym/.cache/sunmoon-artifacts/template-public-tools-code-20260926/downloader.tar`，尚未执行远程解包下载。私有源码未上传。恢复工作前检查实际状态，按手册保留远程至少 8 GiB 可用空间（现有临时远程脚本的 6 GiB 阈值须修正）。

按 [物料操作手册](sunmoonai/kind-infrastructure/docs/物料提交备齐方案和方法.md) 生成执行卡，确定具体试验范围后，以模板前后端完成源码/子仓恢复、pnpm/uv/工具链物料与禁公网构建验证，再接真实 CI/CD。
[下一阶段方案](sunmoonai/kind-infrastructure/docs/production-readiness-next-plan.md) 保存平台全新初始化、可观测性与旧环境清理的顺序。业务 E2E 最后，云端包与旧部署脚本尚未升级。
不得把 A/B 通过写成整个项目达到生产标准。只本地提交，不 fetch/pull/rebase/push。
