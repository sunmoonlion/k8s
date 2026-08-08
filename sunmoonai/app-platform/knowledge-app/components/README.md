# Knowledge 内部组件（源码保留区）

本目录当前仅用于保留组件源码，尚未纳入 Knowledge 的运行链。

- `document-converter-backend/`：从历史 `tools-app` 恢复的文档转换组件。
- `onlyoffice-docs-bff/`：从历史 `shared-apps` 恢复的 ONLYOFFICE BFF 组件。

当前阶段不启用这些组件的 Kubernetes、镜像、Service、Ingress、密钥或流量配置。后续完成总体架构和 Knowledge 运行方案后，再单独设计接入和部署。
