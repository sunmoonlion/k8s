# Sandbox provisioner

默认关闭。现有 `app-images/sandbox-provisioner` 镜像把沙箱 NetworkPolicy 写死为 `edge`，动态 Pod 也缺少 restricted PSS 字段；启用前须经应用构建链重建，参数化 `SANDBOX_NAMESPACE`/`RELAY_URL` 并对齐 restricted，再钉新摘要。

工作台经内网调供给器，不暴露公共 hostname。Knowledge MCP URL 与会合点地址由 config 注入。
