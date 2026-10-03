# 服务公共编排

`config.yaml` 保存本批服务总开关、私有输入/备份路径和平台镜像选择；摘要仍取统一锁。
组件的开关、域名、卷配置和模板在 [gitops/components](../../gitops/components/README.md)，此处不保存第二份。
`layout.yaml` 只维护源码路径、命名空间映射及组件卷引用，不重复填写容量等用户值。

此处保留跨组件的物料准备、凭据保护/加密、证书签发、候选渲染、发布一致性检查和协议验收；部署仍由 Flux 协调。
从 `infrastructure/` 使用 `make services-render` 生成候选、按发布流程审查晋级，随后 `make services-bootstrap`。

`../Makefile` 用明确的 `CONFIG_FILES` 列表把各模块的唯一配置交给 Ansible；不扫描目录猜输入，不另建 CLI。
完整日常方法见 [服务操作](../../docs/platform-kind-v1/services.md)。

## 配置字段与修改条件

配置真源为本目录 `config.yaml`，由现有Make入口明确传给Ansible。下表说明当前支持边界；有字段不等于已有实例可直接修改。

| 字段 | 用途 | 修改条件与限制 |
| --- | --- | --- |
| `services_enabled` | 首批服务动作准入 | 当前各步骤分别检查；不是完整停服开关，不宣称所有组合已验收。 |
| `services_config_dir` | 平台私有输入/TLS目录 | 守卫限定/etc/sunmoon/services/<集群名>；credentials.yaml已有输入保留或从备份恢复。 |
| `services_backup_dir` | 私有输入/TLS独立副本 | 守卫限定/mnt/sunmoon-data/backups/services/<集群名>；修改密码必须另做轮换并同步备份。 |

组件用户名/密码/端口的逐项边界见[服务字段表](../../docs/platform-kind-v1/services.md#字段的维护边界2026-10-03-逐项核对)。本目录只保留公共编排；组件专属配置与模板留在各组件。资源用户入口、凭据轮换和Casdoor域名/节点参数贯通尚未完成。

`service_image_ids` 是本批平台镜像选择。公共准备与发布实现位于 `../artifacts/publish.yaml`，原services-plan/materials/verify-materials/publish入口不变；原services/materials.yaml已移走，无转发副本。
