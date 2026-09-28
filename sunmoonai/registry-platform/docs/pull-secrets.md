# 集群镜像拉取 Secret 的统一部署

目标仍是同一套平台部署代码，本地和云端只在建集群阶段分开。
本页覆盖 17 个 Harbor/Kaniko Secret 部署入口；共享实现为
[`lib/pull-secret.sh`](../lib/pull-secret.sh) 与 [`pull_secret.py`](../pull_secret.py)。云端未经实机验证。

## 配置与参数

组件相邻的 `.conf` 保留 Secret 名称、命名空间、类型、重启选项，父级开关/优先级仍由父级总控管理。
这 17 份配置已删除旧 DOCKER_SERVER/DOCKER_USERNAME/DOCKER_PASSWORD 等认证字段。
部署只读取 `REGISTRY_CONFIG_FILE` 中引用的 `REGISTRY_CREDENTIALS_FILE`；本地 KIND 可使用
[`local-wsl.conf`](../config/local-wsl.conf)，云端必须显式指定仓库主机配置。
私有 JSON 沿用 [`credentials.py`](../credentials.py)：绝对路径、调用者所有、仅所有者权限、最多 64 KiB，
字段为 registry / username / password，可选 email。registry 必须为 `harbor.sunmoonai.com:30443`。
私有文件和内容不提交 Git；不要把口令写进终端命令。

实际执行必须显式提供 CLUSTER、KUBECONFIG、SUNMOON_KUBECTL、SUNMOON_EXPECTED_CLUSTER_UID，
或继承已通过平台总控准入的绑定。映射仍读 `utils/k8s-admin.conf` 或显式 `UNIFIED_CONFIG_FILE`。
独立运行不会读取当前 context 猜目标，不自动建立隧道。正式 main 未建成前，不能填入虚构 UID。

| 入口类型 | 保留的位置参数 |
| --- | --- |
| 13 个只写 Secret 入口 | `[deploy] [project namespace environment dry_run]`，其余动作拒绝 |
| Jenkins Harbor / Kaniko 两个入口 | `action [namespace dry_run]` |
| OnlyOffice / Document Converter 两个入口 | `action [project namespace environment dry_run]` |

后四个入口支持 deploy/status/uninstall/help；不再调用生成器或消费落在工作树中的凭据 YAML。
Document Converter 原 `generate` 部署动作退役；人工导出改用 `./sunmoon harbor export-secret`，见[私有导出说明](export-pull-secret.md)；两个旧生成脚本和 Document Converter 旧配置/模板已删除，不留转发入口。
传入 namespace 优先于配置，默认依次取 NAMESPACE、SECRET_NAMESPACE、平台默认值。
`--cluster` 使用公共解析器，`--dry-run` 在加载组件配置及凭据之前返回；无参数旧入口仍默认实际部署，必须先满足目标准入。
直接调用 Python 工具默认只打印计划；Shell 实际分支在准入通过后显式传 `--apply`。

## 执行边界

- 部署在内存中编码 `.dockerconfigjson`，用标准输入提交，不把口令放进 kubectl 参数，不创建临时凭据/YAML 文件。
- 使用 `data` 和 server-side apply，field manager 为 `sunmoon-registry`，不强行覆盖其他管理者。
  遇到字段冲突失败并交由运维核对；不自动删 Secret 再创建。
  选择依据：[Kubernetes Secret 配置说明](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-config-file/)、
  [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)。
- 写入前核对绑定、kubeconfig SHA256 和 kube-system UID；Python 每条命令重核文件摘要，写入前后再核 UID。
  固定指定的 kubectl/kubeconfig，API 请求 10 秒、子进程 25 秒；不重连或切换集群。
- 现有 Secret 类型不符、正在删除、权限/网络异常均失败；部署后回读认证数据并在内存比较。
  回读失败可能发生在成功写入之后，不自动删资源或声称回滚。
- 所有 kubectl 输出先捕获；错误仅输出固定说明，不打印可能包含提交凭据的 API 诊断。
  status 只确认类型与仓库键，既不读取本地口令文件，也不输出 Secret 数据。
- `RESTART_COMPONENTS=true` 且 `RESTART_COMPONENTS_LIST` 有内容时沿用重启选项。
  先查 Deployment，再查 StatefulSet；只有 NotFound 才换资源类型，权限/网络失败不会伪装成不存在。
  重启失败返回失败，Secret 可能已经更新；本入口不等待工作负载 rollout 成功。
- uninstall 只删除调用方显式选择的 namespace/name；忽略已不存在，但网络/权限失败返回错误。
  不触碰 Harbor 数据、镜像、节点或卷。删除为异步请求，不宣称删除已完成。

Jenkins 原 Kaniko Secret 名称保留，供构建器拉取基础镜像时挂载。它现在从统一私有文件取得拉取身份，
应使用只读机器人并在验收时确认权限；不再依赖旧推送口令。镜像发布仍走 skopeo，发布身份的写权限由发布流程独立管理。

## 覆盖清单

- [sunmoonai/app-platform/auth-app/casdoor/deploy-casdoor/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/app-platform/auth-app/casdoor/deploy-casdoor/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/app-platform/knowledge-app/components/document-converter-backend/deploy-document-converter-backend/secret/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/app-platform/knowledge-app/components/document-converter-backend/deploy-document-converter-backend/secret/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（action）
- [sunmoonai/app-platform/knowledge-app/components/onlyoffice-docs-bff/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/app-platform/knowledge-app/components/onlyoffice-docs-bff/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（action）
- [sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（namespace）
- [sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/kaniko-registry-secret/deploy-kaniko-registry-secret/deploy-kaniko-registry-secret.sh](../../../sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/kaniko-registry-secret/deploy-kaniko-registry-secret/deploy-kaniko-registry-secret.sh)（namespace）
- [sunmoonai/data-platform/elasticsearch/deploy-elasticsearch/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/elasticsearch/deploy-elasticsearch/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/data-platform/kibana/deploy-kibana/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/kibana/deploy-kibana/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/data-platform/logstash/deploy-logstash/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/logstash/deploy-logstash/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/data-platform/mongodb/deploy-mongodb/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/mongodb/deploy-mongodb/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/data-platform/neo4j/deploy-neo4j/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/neo4j/deploy-neo4j/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/data-platform/postgresql/deploy-postgresql/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/postgresql/deploy-postgresql/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/data-platform/redis/deploy-redis/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/data-platform/redis/deploy-redis/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/messaging-platform/rabbitmq/deploy-rabbitmq/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/messaging-platform/rabbitmq/deploy-rabbitmq/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/ops-platform/flower/deploy-flower/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/ops-platform/flower/deploy-flower/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/ops-platform/mongo-express/deploy-mongo-express/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/ops-platform/mongo-express/deploy-mongo-express/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/ops-platform/pgadmin/deploy-pgadmin/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/ops-platform/pgadmin/deploy-pgadmin/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）
- [sunmoonai/ops-platform/redisinsight/deploy-redisinsight/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh](../../../sunmoonai/ops-platform/redisinsight/deploy-redisinsight/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh)（deploy-project）

## 未覆盖和验收状态

通用 Secret 生成库、其他应用资源生成工具、业务数据库 Secret 仍有各自用途；旧 Harbor 专用生成路径已被私有导出工具替代。
本轮仅切换上述 17 个部署入口；不能据此宣称全仓已无历史凭据字段或所有上层资源生成器都已退役。
17 份当前组件配置的旧字段被删除，不会从 Git 历史中抹除；如果曾有真实口令进入版本历史，后续需按原凭据轮换安排处理。

本轮只进行 Shell 语法/ShellCheck 错误级、Python AST、配置字段保留、清单/路径与差异静态检查。
未执行行为测试、任何入口计划/实际分支、API 或镜像登录。尚待本地实机验收：
指定 namespace/UID、缺失私有文件、创建与重复部署、字段冲突、凭据更新、status/uninstall、节点拉取、CI 拉取。
公共集群配置映射同时移除了二次 `eval`，用 `printf -v` 保留配置值中的美元号和引号，不再次执行其中的表达式。
配置/回读相同不代表 Harbor 账号可登录、授权正确或 Pod 能拉镜像。首次云端另行实机验收。

代码回退仅通过 Git 审阅；不要运行旧脚本来回退现场凭据。集群迁移和入口切换未恢复；
旧节点/卷/Harbor/备份继续保护，最终本机重构临时目录与东京中转下载仍需按清单清理。

| 规则 | 本轮对应 |
| --- | --- |
| C-I8 | 缺私有凭据、目标/类型不符、API 失败或字段冲突均失败 |
| C-R1/C-R2/C-R3 | 不改变源码/镜像关联、digest、平台版本或晋级流程；这里只更新认证消费者 |
| C-D1 | 不创建第二份仓库数据，不把凭据复制到代码工作树 |

### RAGFlow 主入口

RAGFlow的内嵌拉取身份准备也复用本Python实现，见[组件说明](../../app-platform/knowledge-app/providers/ragflow/README.md#部署入口整改2026-09-28)。上述17项独立入口清单不变；另增加这一父级调用路径。它不再写认证临时文件，也不因同名Secret存在就直接认定通过；业务Helm values不是本模块管理的凭据。
