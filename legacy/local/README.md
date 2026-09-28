# 本地回退与历史实现

文件见 [总清单](../manifest.json)。本组当前收纳旧建群链及旧操作说明，原入口已拒绝执行或转为说明指针。

## 原地保留的资源

- 旧 `kind-control-plane`、`kind-worker`、`kind-worker2`：仍承载原入口/回退状态，不能删除。特别是 worker2 没有宿主数据绑定，其 Docker 卷不可清理。
- `sunmoon-kind-136`：验证用途，不承载正式数据；节点/卷当前仍受此前保护。
- 宿主 `/data/kind-local-storage`：禁止覆盖挂载、清空或挪动。
- 当前 Harbor 和所有必要备份：只在最终逐项核对后处置。

实际容器身份和挂载快照见 [入口盘点](../../sunmoonai/scripts/results/luna-entry-handoff-inspection.20260927.json)、[恢复收尾](../../sunmoonai/scripts/results/luna-harbor-managed-restore.20260928.json)。这些是历史快照，清理前必须重读实际 ID/引用，不靠名字删除。

## 尚未搬动的依赖

旧 `deploy-kind.conf` 仍被部分 hosts/镜像帮助工具读取，旧 `kind-cluster.yaml` 随之保留；不用于正式建群。配置可能含私有值，不复制到归档清单。旧外置 Harbor 2.11 安装包仍在原处，属于最终物料回收范围，本次没有删除。

退出条件：新 Harbor 正式入口、Docker/节点/CI 实际推拉、空载正式 KIND 重建独立性通过，备份能独立恢复，观察期结束；再核引用并按获准具体清单清理。归档代码由 Git 留历史即可，运行资源处置另行完成。
