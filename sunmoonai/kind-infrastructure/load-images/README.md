# 旧通用 KIND 镜像加载入口已退役

`load-kind-images.sh` 现在只提示替代入口并返回非零，不读取旧配置、不扫描 tar、不拉取或导入镜像。
旧实现暂存于 `legacy/local`；`kind-cli.sh` 中配套的两个通用导入函数已移除，历史由 Git 保留。
本目录 `.conf`、默认列表及已有物料暂留待最终清点，不再由入口使用。

- 平台/应用镜像发布：使用 [统一发布器](../../registry-platform/docs/publication.md)，提供锁定的 OCI 批次；节点通过 Harbor 拉取。
- 新 KIND 建群：使用 [正式建群入口](../formal/README.md)，自举阶段仍按锁导入 Calico 镜像。
- 隔离验证工具：`isolated/cluster.py` 保留其自举导入，但 `sunmoon-kind-136` 仍是一次性验证环境。

Skopeo 发布尚未完成真实推拉验收，应用构建/CI 的旧发布调用也尚未全部接线。
缺镜像时应补齐正式物料与发布批次，不恢复“推送失败后改塞节点”的回退。
旧文档提到的 `load-initial-images-kind.sh` 在当前仓库中不存在，不是可用兼容入口。

逐项状态、保留理由和删除条件见 [迁移文档第 9 节](../docs/harbor-external-integration-plan.md#9-镜像脚本退役与保留清单2026-09-28)。
