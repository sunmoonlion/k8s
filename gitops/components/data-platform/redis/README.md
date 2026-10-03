# Redis

`config.yaml` 是本组件普通用户参数的唯一入口。`workload.yaml.j2` 是实现模板，`workload.yaml` 是审查提交后的部署声明；修改参数后通过 `make -C infrastructure services-render`（从仓库根执行）生成候选并按统一发布流程晋级。

配置和声明不会因为文件相邻自动关联：现有 Make/Ansible 读取明确配置并渲染，Flux 读取 Kustomization 中明确列出的声明。密文由已有 SOPS 流程管理。

操作和输入边界见 [组件说明](../../README.md) 与 [服务操作](../../../../docs/platform-kind-v1/services.md)。

持久应用账号采用/data/users.acl（既有Redis数据卷内）。initContainer只在缺失时初始化原默认身份，不覆盖现有ACL；应用Job通过ACL SAVE持久化独立账号。首次启用需短维护和重启验收，见[模板Redis维护](../../../../docs/platform-kind-v1/tpl-redis-maintenance.md)。2026-10-03首次声明滚动替换与独立账号认证/隔离已通过；账号创建后的再次重启未执行，持久化验收仍未完成。

后续检查发现ACL SAVE会替换文件，原初始化容器的umask不足以保持0600。修正候选已给主进程设置umask077，统一检查会核对文件权限和主进程掩码；尚未发布，现场权限缺陷仍待修复，见维护卡最新一节。
