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

上述 18 份入口里的重复 YAML 生成/自动连接/密码生成/吞错重启实现已删除。
部署不再读写各自的 `<名称>.yaml`，历史生成文件不作为真实输入。
Elasticsearch 总控仍需同时启用 `elasticsearch_myapp_secret_enabled` 和
`APPLY_ELASTICSEARCH_MYAPP_SECRET`，现在调用同一个配置入口，不再读取旁边的真实/示例 YAML。
管理员/Harbor/MyApp 三个子入口显式传播失败；开关原值未改变。
Redis 独立工具不再因同名 Secret 存在就跳过检查；deploy 必须提供明确值并提交回读，
只查看现存 Secret 应使用 status。其旧未初始化的 PROJECT_ROOT/配置路径依赖已移除。
Redis 父级聚合查询/卸载仍需继续审阅：历史路径指向 redis-secrets，而其部署集合使用 redis-auth-secret，
本批不把这两种身份混为一份，也不擅自删除另一份 Secret。
手工 Secret 生成库有独立用途，仍保留；TLS、对象存储/数据库 provisioner、
其余主部署里的内嵌 Secret 路径不属于本表，需继续逐项审阅，不能泛称所有 Secret 完成。

本批完成 Shell/Python 静态检查与字段/入口清单核对，未运行部署或行为测试。
尚待实际验收：首次安装、重复提交、字段冲突、权限/网络故障、回读不一致、重启失败、
数据库登录与各组件就绪。云上未经实机验证。旧节点/卷、Harbor、必要备份保持保护。
