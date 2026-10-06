# Sandbox provisioner

默认关闭。源码 `sunmoonai/sandbox-platform/provisioner`，2026-10-06 起按新体系参数化：命名空间（`SANDBOX_NAMESPACE`、`APP_NAMESPACE`、`RELAY_NAMESPACE`）与会合点地址从环境变量来，拉起的沙箱 Pod 满足 restricted PSS，Pod 带标签 `sunmoonai.com/sandbox=true`（investment、knowledge 的入站策略按它放行）。镜像经 `make platform-build OBJECT=sandbox-platform/provisioner` 重建、锁改写成 `platform/sandbox-provisioner` 后，把 `services_sandbox_provisioner_enabled` 打开。

沙箱镜像是另一个只构建的对象 `sandbox-platform/sandbox`，锁在 `../sandbox/image.lock.yaml`。工作台经内网调供给器，不暴露公共 hostname；Knowledge MCP URL 与会合点地址由 config 注入；工作台记录工具服务的地址与令牌由工作台在每次拉起时随规格给。
