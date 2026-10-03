# 服务公共编排

`config.yaml` 仅保存本批服务总开关和私有输入/备份路径。
组件的开关、域名、卷配置和模板在 [gitops/components](../../gitops/components/README.md)，此处不保存第二份。
`layout.yaml` 只维护源码路径、命名空间映射及组件卷引用，不重复填写容量等用户值。

此处保留跨组件的物料准备、凭据保护/加密、证书签发、候选渲染、发布一致性检查和协议验收；部署仍由 Flux 协调。
从 `infrastructure/` 使用 `make services-render` 生成候选、按发布流程审查晋级，随后 `make services-bootstrap`。

`../Makefile` 用明确的 `CONFIG_FILES` 列表把各模块的唯一配置交给 Ansible；不扫描目录猜输入，不另建 CLI。
完整日常方法见 [服务操作](../../docs/platform-kind-v1/services.md)。
