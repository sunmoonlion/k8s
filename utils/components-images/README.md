# 组件镜像清单目录

- 每组件一份 `<component>-images.txt`，一行一个明确的 `repository:tag` 或 `repository@sha256:<64hex>`。
- 共享检查器在部署前核对独立 Harbor 的 manifest；缺失、认证或网络失败均停止部署。
- 备料和发布在部署前单独完成，组件部署不自动从 tar 补推。
- 默认计划：`./sunmoon harbor images check --component postgresql`（在仓库根）。
- 配置、映射、结果边界见 [检查说明](../../sunmoonai/docs/harbor-component-image-ensure.md)。

现有 tag 清单仍需与真正渲染的部署镜像、发布摘要锁核对；manifest 存在不代表镜像层、目标架构或节点拉取已验收。
