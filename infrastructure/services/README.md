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


## MongoDB

MongoDB接入同一Make/Ansible/Flux服务链，用户配置、模板、独立初始化Job、协议验收和说明在[MongoDB组件](../../gitops/components/data-platform/mongodb/README.md)。镜像取统一不可变版本锁，本次官方9.0.2-noble；内部TLS单成员副本集，不具备HA。services-check验证受限库CRUD、提交/回滚、匿名/错误口令/跨库/管理权限拒绝。

私有用户名、密码和副本集密钥在services_config_dir/mongodb.yaml，证书在mongodb-tls，均有独立逐字节备份；不是公开config.yaml字段。日常公开端口/副本集名称/卷/资源参数在组件config.yaml。当前端口只支持27017；既有副本集名称、卷节点和已完成初始化Job不可随意修改，改变身份要另做轮换，不会静默重设密码。20Gi卷声明不是文件系统配额。开关不隐式删既有运行资源或数据。

实际MongoDB Pod重建后同一随机标记、受限账号及TLS/事务验证通过，PV/PVC UID不变；临时标记已精确移除。这不代替整机/集群重启、KIND删除重建或数据库备份恢复。

## RAGFlow 检索服务

Infinity、专用Valkey与RAGFlow均复用同一services-bootstrap/check链。配置、独立身份与实现分别位于data-platform下各组件目录；不与ELK索引或业务Redis身份混用。RAGFlow初始化由独立Job执行，API/Worker仅持DML角色；原文权威仍在业务对象存储。

官方0.27.2镜像的UV解释器和NLTK数据位于/root，最小派生镜像调整非root读取权限，并把官方批量写入的冗余建表调用改为检查已初始化的表；固定原始文件SHA256、不升级包，缺表仍失败。构建/摘要锁及说明见[RAGFlow组件](../../gitops/components/data-platform/ragflow/README.md)。首次使用make services-ragflow-image、services-ragflow-image-publish准备；完整services-bootstrap已包含校验与发布，不需要另行手工初始化。services-check包含真实中文上传、解析和向量检索以及权限拒绝；协议结果不能替代业务领域接入或整机重建验收。

2026-10-04实际结果：完整services-bootstrap连续两轮成功；RAGFlow中文纯文本上传/解析/检索与身份及DDL拒绝通过，验收临时数据含S3版本精确清空。54个运行Pod身份/重启数及13个Retain卷声明不变；具体固定源、原失败及未完成范围见根CHECKPOINT.md。这不替代知识业务领域接入、其它文档格式或整机/集群重建验收。
