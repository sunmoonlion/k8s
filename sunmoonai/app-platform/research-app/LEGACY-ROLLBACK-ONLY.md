# Research 旧运行态：仅用于回滚

状态：冻结 / 只读
最后更新：2026-08-09

本目录不是 Architecture v2 Investment 的开发或发布入口。它仅保存 R5/R7 前重建现有
Research 基线所需的旧部署资料；不得在这里新增 Investment 功能、复制新模板或进行机械改名。

当前有效边界：

- Investment v2 唯一部署入口是相邻的 `../investment-app/`；
- 新源码只存在于 `investment-backend`、`investment-admin-frontend`、
  `investment-web-frontend`；
- KIND/C1 中仍存在的 `research-*` Deployment、Service、PVC、数据库、凭据、Casdoor
  Client 和镜像是迁移回滚面；
- R5 负责真实数据迁移、切读、切写与旧写入封锁；
- 只有 R7 观察窗和正式发布门禁通过后，才允许按经审核的退役清单删除本目录和运行资源。

权威迁移文档：`sunmoonai/docs/investment清理和改名.md`。
