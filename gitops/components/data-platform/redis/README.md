# Redis

`config.yaml` 是本组件普通用户参数的唯一入口。`workload.yaml.j2` 是实现模板，`workload.yaml` 是审查提交后的部署声明；修改参数后通过 `make -C infrastructure services-render`（从仓库根执行）生成候选并按统一发布流程晋级。

配置和声明不会因为文件相邻自动关联：现有 Make/Ansible 读取明确配置并渲染，Flux 读取 Kustomization 中明确列出的声明。密文由已有 SOPS 流程管理。

操作和输入边界见 [组件说明](../../README.md) 与 [服务操作](../../../../docs/platform-kind-v1/services.md)。

持久应用账号采用/data/users.acl（既有Redis数据卷内）。initContainer只在缺失时初始化默认身份，并收紧文件权限；主进程以umask077启动，确保后续ACL SAVE仍保持0600。应用Job保存独立账号，application-check核对当前认证、文件权限/属主及主进程掩码。

2026-10-03已通过实际滚动重启：默认与应用账号可用，ACL摘要和原PVC不变，再次ACL SAVE后仍0600；原生统一部署入口重复changed=0。见[模板Redis维护记录](../../../../docs/platform-kind-v1/tpl-redis-maintenance.md)。这不替代Redis业务数据备份恢复演练或整个应用验收。
