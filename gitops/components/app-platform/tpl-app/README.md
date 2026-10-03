# 模板应用（tpl-app）

保留平台 → 应用 → 前后端组件 → 运行角色/部署阶段：

- `tpl-backend/`：后端配置、镜像锁、database/migration；后续API、Worker、Scheduler共用同一后端镜像并归这里。
- `tpl-web-frontend/`：Web前端配置、镜像锁和后续运行声明。
- `tpl-admin-frontend/`：Admin前端配置、镜像锁和后续运行声明。

本目录 `config.yaml` 只保存应用共享开关和命名空间。口令在私有输入/SOPS密文；用户名、数据库及迁移参数在后端配置，浏览器origin在对应前端配置。其它应用采用同样的应用/组件层级。

当前单元只部署后端独立数据库与迁移，前端及完整业务链尚未部署。原生入口、保护和验收说明见 [后端](tpl-backend/README.md)。
