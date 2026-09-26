# 物料方法手册与下一阶段调查

日期：2026-09-26。基线：`k8s/luna@5a1c1f994a05df814b0fec974925838dce422447`。

所有者要求主动规划下一步，确认旧业务数据不需迁移，并要求编写可直接交给 AI 的《物料提交备齐方案和方法.md》。

## 本次交付

- [方法手册 0.1](../../kind-infrastructure/docs/物料提交备齐方案和方法.md)：执行卡、完整物料范围、Git/子仓恢复、pnpm/uv/系统依赖、Harbor 自举、网络与续传、隔离试验、CI/CD 分工、长期维护和三段 AI 任务文本。
- 按所有者最终要求，仅保留仓库内的手册作为唯一维护版本；已移除本次创建的家目录副本。
- [阶段方案](../../kind-infrastructure/docs/production-readiness-next-plan.md)：以全新初始化取代业务数据迁移；先准备独立物料，再初始化新平台和推进 CI/CD。
- [源码/依赖盘点](luna-production-readiness.20260926.inventory.json) 与 [旧集群元数据盘点](luna-production-readiness.20260926.cluster.json)。集群数据仅包含工作负载、镜像、PVC 元数据和 CRD 版本，没有采集 Secret 或业务数据。

## 主要发现

- 12 个组件子仓，9 份 pnpm 锁文件和 4 份 uv.lock；不能只解决公共容器镜像下载。
- 构建还依赖包管理器自身、APT、安装脚本额外资产和目标 libc；前端存在关闭 Corepack 完整性校验的配置，后续试验须修复。
- 旧 Harbor 随旧集群运行，清理前需要让必需镜像可以从独立物料恢复。
- 旧集群盘点到 54 个 Deployment/StatefulSet/DaemonSet、20 个 PVC、30 个 CRD；未发现 Jenkins Deployment/StatefulSet。现有流水线含历史示例和不安全参数，不作为已部署 CI 证明。

## 检查与边界

本次只读调查、官方文档核对和文档审阅；没有运行应用测试、构建、下载安装新组件、发布、初始化业务库或清理旧集群。
完整物料及 CI/CD 试验仍标记未执行，基础集群之前的成功证据只覆盖其已验收范围。
下一步按手册执行卡确定试验范围；获准后主动完成相应工作，并据真实试验补充验证版本、平台与证据。
