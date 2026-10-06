# 应用共用机制

此目录由通用组件渲染器通过 `common/backend/prepare.yaml` 与 `common/frontend/prepare.yaml` 渲染，四应用都使用它。各应用自己的 config、image.lock、生成声明及 SOPS 仍在所属应用/前后端目录。

## 模板归属

| 路径 | 维护责任 |
|---|---|
| backend/database、migration | 建库/运行与迁移账号隔离、schema核对 |
| backend/redis、rabbitmq | 应用持久身份、键前缀/vhost与真实拒绝检查 |
| backend/identity | Web/Admin注册与精确回调，不授予业务权限 |
| [backend/service-identity](backend/service-identity/README.md) | Info摄入和Investment检索的独立服务身份 |
| [backend/storage](backend/storage/README.md) | 应用原文桶、版本与受限S3身份 |
| backend/runtime | API/Worker/Scheduler运行声明；Flux阶段依赖在各应用组件的stage.yaml |
| web、admin | 分面独立的前端运行声明 |

模板不定义第二套用户名、域名、镜像版本。修改共用模板前查看四应用的生成差异；不能只检查tpl，把其它应用作为未经审阅的副作用。初始化Python模板经渲染进入所属Job的ConfigMap。

## 应用自己的配置、秘密、角色与网络（0010，2026-10-06）

四个字段都可不写；不写时生成的声明一个字节不变（改模板时用四个应用的旧变量各渲染一遍对比过）。

| 字段 | 作用 | 规则 |
|---|---|---|
| `cross_app_enabled` | 从三个网页端的 `origin` 推出 `CROSS_APP_TARGETS_JSON`、`CROSS_APP_SOURCES_JSON` 进 ConfigMap | 不手配地址；谁去哪按 PRD/apps/README.md 4.1 |
| `domain_env` | 明文配置，进 `<app>-runtime` ConfigMap | 键 `^[A-Z][A-Z0-9_]{2,63}$`，值是字符串，不许和模板已管的键重名 |
| `domain_secrets` | 只写来源，值不进 Git；进 Secret `<app>-domain-runtime`（`runtime/domain.sops.yaml`） | 来源：`random`（首次生成 40 位，存 `private_dir/domain.yaml` 主备）、`component-input`（平台级输入 `services_config_dir/<name>.yaml` 的一个键）、`workbench-signing`（共享 ES256 密钥对，`private_key_pem` / `public_key_pem`）、`private`（所有者手工放进 `private_dir/domain.yaml`） |
| `domain_secrets_roles` | 哪些角色拿这个 Secret | 不写是 api、worker、runner |
| `runner_replicas` | 第四个角色 `runner`（`python -m app.bootstrap.runner`，不开端口，Recreate） | 不写是 0；写了要配 `resources.runner` |
| `domain_egress` | 应用级出站放行，每条一个 NetworkPolicy | `name`、`roles`、`ports`，目标二选一：`namespace_var` + `pod_labels` 或 `cidrs` |
| `domain_ingress` | 应用级入站放行，只到 api 端口 | `name`、`namespace_var`、`pod_labels` |

实现：`backend/domain/prepare.yaml`（校验、读秘密、推链接），`backend/runtime/workload.yaml.j2`（渲染）。共享签名密钥对由 `infrastructure/components/tasks/workbench-signing.yaml` 准备，investment 用私钥，knowledge 与 relay 用公钥。

## 更新与不可变Job

后端镜像由各应用源码提交及锁定构建产生。生产async_sessionmaker需expire_on_commit=False，实际API检查此行为，避免异步任务访问提交后回执触发MissingGreenlet；此约束属于业务源码，不由部署模板修补运行容器。

已完成Job内容不可原地修改。初始化输入或引用的后端镜像改变时，审阅受影响阶段并显式更新该阶段revision；迁移Job同时按镜像摘要命名。复用原身份与逐字节备份，不能以新Job代次冒充密码轮换。

成功Job留作Flux期望对象；直接删除或加TTL会使Flux可能重建。旧Job退役须确认已从晋级声明移出、依赖不再引用，保存结果后按具体UID/resourceVersion清理；不按Completed状态批量删。

## 维护流程

先在一个受影响应用准备候选并审阅，再核对其他应用；提交、发布、显式晋级和执行方法统一见[应用手册](../../../../infrastructure/applications/README.md)。验收既查初始化回执，也查实际角色/登录/消息，范围见[应用与业务链路](../../../../docs/platform-kind-v1/verification.md#应用与业务链路)。

业务schema、持久身份或远端数据变化不能仅靠Git回退；此目录不增加另一个部署CLI、业务启动脚本或删除策略。
