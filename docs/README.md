# SunMoonAI维护导航

本导航适用新体系`infrastructure/`、`gitops/`与`docs/`。从五仓并列的platform-kind-v1/k8s根目录执行手册命令；新开发集群是sunmoon-kind，原始kind属于受保护旧环境。

## 按任务进入

| 我要做什么 | 维护入口 | 能力状态 |
|---|---|---|
| 查看环境/配置来源 | [总入口](../infrastructure/README.md)、[环境](../infrastructure/environments/kind/README.md) | 原生入口存在 |
| 改组件参数、用户名、port | [组件分类](../gitops/components/README.md)，进入对应组件config/README | 就近参数；已有身份/卷变更有限制 |
| 数据盘/容量/启动故障 | [host](../infrastructure/host/README.md)、[诊断](../infrastructure/host/troubleshooting.md) | 预检/峰值门槛存在；整体开机恢复未完成 |
| Harbor安装/启停/推拉/认证 | [registry](../infrastructure/registry/README.md) | 模块部署与启停存在 |
| 扫描器/扫描情报 | [scanning](../infrastructure/registry/scanning.md) | 固定库安装/真实扫描；自动更新待实现 |
| 仓库备份/恢复 | [recovery](../infrastructure/registry/recovery.md) | 既有冷备隔离演练；自动创建/轮换待实现 |
| 域名/公共30443切换 | [entry](../infrastructure/entry/README.md) | 原生预览/启停/配置部署 |
| KIND建群/节点拉取 | [cluster](../infrastructure/cluster/README.md) | 拥有的集群原生引导；整体重建持久化待验 |
| 物料/工具/版本来源 | [artifacts](../infrastructure/artifacts/README.md)、[tools](../infrastructure/tools/README.md) | 固定锁与校验 |
| 发布部署声明/晋级/退回 | [Flux](../infrastructure/flux/README.md) | 不可变OCI与显式晋级 |
| 密钥/Secret生成和恢复 | [secrets](../infrastructure/flux/secrets.md) | SOPS/私有主备；统一轮换待实现 |
| 组件阶段/依赖（stage.yaml） | [components](../infrastructure/components/README.md) | 图由组件目录汇成 |
| 平台部署/检查 | [services](../infrastructure/services/README.md) | 平台bootstrap存在 |
| 应用构建/发布/部署/真实检查 | [applications](../infrastructure/applications/README.md) | 4应用共享原生入口 |
| 理解职责/适用边界 | [架构](platform-kind-v1/architecture.md) | 稳定设计 |
| 看已验证和未完成 | [验收边界](platform-kind-v1/verification.md) | 带日期结论，不代表实时状态 |

## 日常规则

共享参数来自site，组件参数来自同目录config，版本/摘要来自锁，源码提交来自sources，秘密来自私有输入/SOPS。用户不在生成YAML里散改默认值，不重新随机生成已有账号或age密钥。

先计划/准备、审阅差异、提交与显式晋级，再原生部署和检查。render/stage/check可能有文件/API/探针写入；关闭enabled不等于停服。当前维护窗口2小时、容量底线10GiB，仍做VHDX未来增长和峰值检查，删除策略需独立批准。

整套一键部署已实际重复部署通过；[统一启停/开机恢复](../infrastructure/host/lifecycle.md)候选、Harbor重启/删群持久化和长期空间管理尚待实际完成，具体出口在[未完成项](platform-kind-v1/verification.md#未完成项)。
