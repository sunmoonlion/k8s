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

对象存储接入同一服务链，配置和专属实现位于 data-platform/object-storage；现有 services-materials/publish 覆盖固定 AIStor 与同日客户端镜像。services-stage 将已渲染声明写入工作树，不直接应用集群；提交、flux-release、核对并晋级 source-candidate 后运行 services-bootstrap。services-check 包含真实许可/TLS/版本对象读写，仅清除此轮探针。

## ELK 与图服务

ELK及Neo4j复用上述物料、stage、固定源晋级、services-bootstrap/check链，无新增部署入口。用户配置和实现分别在[ELK](../../gitops/components/data-platform/elk/README.md)、[Neo4j](../../gitops/components/data-platform/neo4j/README.md)，版本摘要仍由上游镜像锁提供。

ELK独立秘密输入为services_config_dir下elk.yaml，图管理员为neo4j.yaml，均root0600并有独立备份；不是旧credentials.yaml中的字段。不要将明文移入组件公共config.yaml。services-check只输出无秘密验收结果；修改既有密码需要轮换与备份同步，不能直接改备份触发重新生成。

两个单节点服务当前只开放受控内网检查；公共UI入口、应用全量日志采集、业务图身份/接入及重启/灾备验收另有后续范围。
