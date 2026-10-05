# RAGFlow：派生检索服务

原文权威属于Info等业务对象桶，本组件仅保存派生检索。配套Infinity/Valkey及PostgreSQL/AIStor/TEI通过同一平台依赖链；不使用ELK新ES作RAG索引。

## 初始化、运行与身份

platform-services→ragflow-database/storage→initialize→runtime，Flux协调，平台bootstrap无需人工先初始化。prepare直接使用common的database/storage模板，初始化与运行使用本组件模板；生成声明仍留在本组件对应目录。独立Job持schema拥有者，创建两个独立租户/令牌（knowledge与acceptance）；API/Worker以ragflow_runtime运行，无CREATE权限，不挂PG/S3管理员或init拥有者/知识服务token。

私有ragflow.yaml、TLS及独立副本由prepare维护，秘密只发布SOPS。runtime直调固定官方模块，跳过entrypoint隐式DDL，API使用ASGI/TLS仅api/v1及ready，不提供公共UI/注册/Sandbox/socket/启动公网下载。初始化补独立session marker满足官方token接口，它不是浏览器会话也不复用API令牌。

S3只写ragflow-derived版本桶，不能读Info原文/管理桶；网络精确允许PG/S3/Infinity/Valkey/TEI和受限Knowledge调用。Infinity/Valkey明文例外见各手册，单实例不具HA。临时logs/cache的emptyDir有上限，正式数据在数据库/对象/索引/队列。

## 必要最小派生镜像

Dockerfile取固定官方base，/root内置uv Python3.13路径与NLTK数据只做非root可读权限适配，默认UID1000；不联网安装/升级包或语料。另有一处官方db_utils.py受完整源SHA守卫的bulk写前检查：表须已存在，缺表失败，替代运行时不必要DDL；上游文件变化立即拒绝套补丁。

派生image.lock.json记录原基底、Dockerfile与成品/归档不同身份，上游锁不改；平台bootstrap原生包含services-ragflow-image与services-ragflow-image-publish，固定归档存正式物料images。发布target直接调用artifacts/publish.yaml，组件关闭时跳过、不读取派生锁或发布镜像；开启时继续完整校验、容量检查及认证发布。预算按已验证归档逐层只读测展开字节，计入Docker展开/转换/最终归档与余量，不保存额外docker-save大副本。运行与探针显式用/ragflow/.venv/bin/python3。

## 检查和恢复

services-check验TLS、错误token、runtime DDL拒绝、S3越权拒绝、独立租户中文上传→worker解析→检索、跨租户拒绝。只清本次随机dataset；官方delete会保留S3版本，探针额外核DB行/精确派生前缀版本清空，不扩大为业务保留规则。

Knowledge真实HTTP/异步领域链另在provider维护；PDF、公共UI、重启/删群/灾备不由纯文本协议验收覆盖。升级需数据库/派生内容及身份备份，核官方模块调用兼容、init代次/模型绑定与真实检索；只换镜像不能保证schema兼容。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_ragflow_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `ragflow_database` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `ragflow_database_owner` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `ragflow_database_runtime` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `ragflow_bucket` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `ragflow_storage_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `ragflow_initialize_generation` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `ragflow_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `ragflow_node` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `ragflow_ingestion_timeout_seconds` | 整数 | 操作预算/限时；调整须匹配真实峰值及当前容量检查。 |
| `ragflow_api_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_api_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_api_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_api_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_worker_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_worker_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_worker_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `ragflow_worker_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
