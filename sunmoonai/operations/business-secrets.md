# 业务 Secret 部署

本批将下列 18 个既有入口接到 `utils/secret-management/lib/opaque-deploy.sh` 和
`opaque_secret.py`。本地/云上调用同一实现，**云上未经实机验证**。
数据库、应用版本和实际凭据未更改；这不是凭据轮换或数据库用户创建。

## 日常控制

保留各入口旁的同名 `.conf`、集群前缀映射和位置参数：

```bash
# 不加载配置、凭据，也不访问 API。
bash sunmoonai/data-platform/postgresql/deploy-postgresql/secrets/postgresql-auth-secret/deploy-postgresql-auth-secret/deploy-postgresql-auth-secret.sh --cluster KIND --dry-run
```

其中 16 个只写入口真实执行仍是 `[deploy] [project] [namespace] [environment] [false]`，不是默认计划。
`deploy` 前缀可省略；不支持的 `status/uninstall/generate` 会由原请求层拒绝。
必须先提供明确的 `CLUSTER`、`KUBECONFIG`、`SUNMOON_KUBECTL`、
`SUNMOON_EXPECTED_CLUSTER_UID`，与[统一部署目标](configuration.md#平台部署的固定目标传递)一致。
配置不能改变调用者选定的集群；没有默认 context、SSH 重连或退出清理。

另外两个 `redis-secrets`、`elasticsearch-secrets` 保留 `deploy/status/uninstall [namespace] [false]`；
Elasticsearch 保留原 `delete` 别名。它们分别读取原 `REDIS_SECRET_NAME/REDIS_NAMESPACE`、
`ELASTICSEARCH_SECRET_NAME/ELASTICSEARCH_NAMESPACE`，显式 namespace 优先。
status/uninstall 不读 stdin 或生成/校验业务值，只按配置身份查询/申请删除；`.conf` 仍会加载。
删除仅忽略 NotFound，不清 namespace/PVC/数据，不声称异步删除已完成。

- Secret 名称：`.conf` 的 `SECRET_NAME`，未设时使用入口对应名称。
- Namespace：明确位置参数 > `.conf`/环境的 `NAMESPACE` > `SECRET_NAMESPACE` > 平台默认值。
- 类型固定 `Opaque`；重复或非法键名、空数据集会拒绝。
- `RESTART_COMPONENTS` 必须为 `true/false`；支持重启的入口沿用 `RESTART_COMPONENTS_LIST`。
- `project/environment` 保留调用契约，不用它们暗中改 Secret 名称或拼密码。
- `.conf` 仍是受信任 Shell 配置。本批没有把已有业务凭据批量移出配置，也没有修改这些值。
  不要把新增真实凭据提交 Git；当前目录不是已完成的统一私有凭据存储。

### 输入和重复部署

普通字段继续沿用旧代码的“非空才提交”。PostgreSQL/MongoDB/Redis 等可选字段是否齐全，
仍需结合实际 Chart/消费者验收；不能因 Secret 已存在就认为数据库登录成功。

以下入口不再在普通部署中生成随机值：

| 入口 | 必须明确提供的变量 |
| --- | --- |
| pgAdmin | `pgadmin_password` |
| Flower | `flower_password` |
| Mongo Express | `mongo_express_password`、`mongodb_auth_password`、`basic_auth_password`、`site_cookie_secret`、`site_session_secret` |
| Redis 独立 `redis-secrets` 工具 | `REDIS_PASSWORD`、`REDIS_MASTER_PASSWORD`；`REDIS_DATABASE` 缺省仍为 `redis` |
| Elasticsearch 管理员 Secret | `ELASTICSEARCH_PASSWORD`、`ELASTICSEARCH_USERNAME`、`KIBANA_SYSTEM_PASSWORD` |

Mongo Express 的后两个变量以前每次运行都随机生成，现从已有 Shell 配置/明确传入的环境读取。
仓内原配置未包含这两个值，**真实部署前必须从原 Secret 安全保存并提供，或在新安装时单独准备**；
部署脚本不自动跨集群读取、不拿网页登录密码冒充 MongoDB 密码、不输出密码片段。
如果通过环境输入，可在单独终端预先读取 Git 外、所有者私有的凭据文件；不要把口令写进命令行或提交记录。
本批未读取或导出现场凭据，未声称这些新输入已经备妥。

## 覆盖和键名

路径规律：`sunmoonai/<平台>/<组件>/deploy-<组件>/secrets/<名称>/deploy-<名称>/deploy-<名称>.sh`。
各路径都保留，成为实际配置适配入口；不是旧实现的转发备用副本。

| 平台/组件 | 名称 | 配置变量 → Secret 键 | 重启规则（开关启用时） |
| --- | --- | --- | --- |
| data/postgresql | postgresql-auth-secret | `admin_password`、`dev_password` 原名 | 每次提交后 |
| data/postgresql | postgresql-authservice-db-secret | `DB_HOST/PORT/NAME/USER/PASSWORD/SSLMODE` 原名 | 每次提交后 |
| data/postgresql | postgresql-llmopsservice-db-secret | 同上 | 每次提交后 |
| data/mongodb | mongodb-auth-secret | `mongodb_root_password/passwords/metrics_password/replica_set_key` 的下划线转连字符 | 每次提交后 |
| data/mongodb | mongodb-llmopsservice-db-secret | `DB_HOST/PORT/NAME/USER/SSLMODE` 原名；旧实现不提交 `DB_PASSWORD` | 每次提交后 |
| data/redis | redis-auth-secret | `redis_password` → `redis-password` | 每次提交后 |
| data/redis | redis-secrets | `REDIS_PASSWORD/MASTER_PASSWORD/DATABASE` → 原 `REDIS_*_KEY` | 不重启 |
| data/redis | redis-myapp-secret | `REDIS_HOST/PORT/PASSWORD/SSL` 原名 | 旧实现无重启，不新增 |
| data/redis | redis-llmopsservice-secret | 同上，加 `REDIS_DB` | 旧实现无重启，不新增 |
| data/elasticsearch | elasticsearch-myapp-secret | `ES_HOST/PORT/USERNAME/PASSWORD/TLS` 原名 | 旧实现无重启，不新增 |
| data/elasticsearch | elasticsearch-secrets | 原管理员 password 键、`elasticsearch-username`、`kibana-password` | 不重启 |
| data/kibana | kibana-elasticsearch-secret | 同上 | 旧实现无重启，不新增 |
| data/logstash | logstash-elasticsearch-secret | 同上 | 旧实现无重启，不新增 |
| data/neo4j | neo4j-secrets | `neo4j_password` → `password` | 每次提交后 |
| messaging/rabbitmq | rabbitmq-auth-secret | `rabbitmq_username/password/erlang_cookie` 的下划线转连字符 | 原 Secret 已存在且内容变化；首次创建不重启 |
| ops/pgadmin | pgadmin-auth-secret | `pgadmin_password` → `PGADMIN_AUTH_SECRET_PASSWORD_KEY`，默认 `pgadmin-password` | 每次提交后 |
| ops/flower | flower-secrets | password/user 键由原 `FLOWER_*_KEY` 决定；`broker_url/broker_api_url` → `broker-url/broker-api-url` | 每次提交后 |
| ops/mongo-express | mongo-express-secrets | 六个原 `MONGO_EXPRESS_*_KEY` 配置决定 | 每次提交后 |

## 提交和失败边界

配置值经 Shell 内建 `printf` 和管道进入 Python，不作为外部进程的命令参数，
不生成临时明文目录或工作树 Secret YAML。Python 构造 `data`，以 stdin 做 server-side apply，
固定 field manager `sunmoon-business-secret`，不使用 `force-conflicts`。
历史客户端/其他 manager 的冲突会停止，不能盲目接管；已有其他键不擅自清空。
本 manager 以前管理的可选键在后续输入中省略，可能被 SSA 删除，改配置前需按实际用途确认。

每次 API 调用复核 kubeconfig 内容摘要；写入前后复核 kube-system UID。
API 请求 10 秒、命令进程 25 秒期限。Namespace 必须已存在，Secret 类型错误或正在删除时拒绝。
写后回读提交的每个键；API 输出和可能包含凭据的错误不原样打印。
这不隐藏私有数据对本机 root/同账号进程管理员的可见性，也不替代 Kubernetes RBAC/加密配置。

重启先查 Deployment，再查 StatefulSet。两者确实不存在时说明“尚待安装”，允许首次准备 Secret；
权限、网络或 restart 请求错误会失败，不能当作 NotFound。只提交重启请求，不等待 rollout。
Secret 提交、回读和多个工作负载重启不是事务：后一步失败时 Secret 可能已经更新；
尤其 RabbitMQ 再次运行时内容可能不再变化，须按失败记录明确补做未完成的重启和就绪检查。

## 退役与待验收

### 对象存储主部署的内嵌 Secret

对象存储主入口在加载旧公共连接库之前绑定明确目标，配置映射后再次核对；
`ensure_cluster_connection` 只复核原目标，不再失败后自动重连。
License 与根凭据复用同一个 Opaque 提交器：`minio.license` 从 `AISTOR_LICENSE_FILE` 读取，
必须绝对路径、调用者所有、owner-only、末级非软链、非空且不超过 64 KiB；
`config.env` 的原配置格式和值保留，经内建 printf 管道提交，不再把口令放入 kubectl 命令参数。
这不是自动改文件权限或凭据迁移；现存许可文件若不满足要求，部署会停止，须先由管理者准备。

拉取 Secret 按 `OBJECT_STORAGE_IMAGE_PULL_SECRET_NAME`，使用独立仓库的私有凭据与共享提交器核对/写回，
不再因同名存在即接受，也不借用 PostgreSQL 的配置来创建另一个名字。
三个 Secret 在内存提交并回读，失败传播。对象存储数据/License/账号、Chart 版本未改变。
旧公共库暂为静态卷/镜像检查提供函数，严格目标模式禁止自动连接清理。
主部署其余 Helm 状态/卸载吞错、等待和 provisioner 路径仍待整改，不把本批凭据路径改动当完整组件验收。
`config.env` 保留原格式；特殊字符与对象存储实际配置解析、许可证有效性和 root 登录仍需实际核验。

### 其他边界

上述 18 份入口里的重复 YAML 生成/自动连接/密码生成/吞错重启实现已删除。
部署不再读写各自的 `<名称>.yaml`，历史生成文件不作为真实输入。
Elasticsearch 总控仍需同时启用 `elasticsearch_myapp_secret_enabled` 和
`APPLY_ELASTICSEARCH_MYAPP_SECRET`，现在调用同一个配置入口，不再读取旁边的真实/示例 YAML。
管理员/Harbor/MyApp 三个子入口显式传播失败；开关原值未改变。
Redis 独立工具不再因同名 Secret 存在就跳过检查；deploy 必须提供明确值并提交回读，
只查看现存 Secret 应使用 status。其旧未初始化的 PROJECT_ROOT/配置路径依赖已移除。
Redis `secrets/deploy-secrets-all` 的 deploy/status/uninstall 共用原四组件启用列表和优先级，
按各子入口同一 `.conf` 读取实际名称。deploy 降序、uninstall 逆序；非法开关/优先级、
启用但缺失的入口或配置会失败，不再跳过后报成功。Namespace 使用明确参数，其次总控 `.conf`。
status 查询启用的业务/Harbor Secret，**uninstall 只申请删除启用的三个业务 Secret，保留共享 Harbor 拉取身份**，
不触及独立手工工具 `redis-secrets`、数据库数据、PVC 或 namespace。开关关闭的对象不追溯删除。
这是当前配置集合的动作，不是历史资源自动发现；卸载前应先核对 status 和业务影响。
三个业务薄入口的 CLI 仍只写；父级通过共享 `opaque_secret_lifecycle_entry` 查询/删除，
不生成业务值、不调用旧随机密码脚本，也不重新连接集群。多对象操作非事务，失败时保留已完成状态。
手工 Secret 生成库有独立用途，仍保留；通用证书分发工具、对象存储/数据库 provisioner、
其余主部署里的内嵌 Secret 路径不属于本表，需继续逐项审阅，不能泛称所有 Secret 完成。

本批完成 Shell/Python 静态检查与字段/入口清单核对，未运行部署或行为测试。
尚待实际验收：首次安装、重复提交、字段冲突、权限/网络故障、回读不一致、重启失败、
数据库登录与各组件就绪。云上未经实机验证。旧节点/卷、Harbor、必要备份保持保护。
