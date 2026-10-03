# 模板后端（tpl-backend）

归属：`components/app-platform/tpl-app/tpl-backend/`，保留平台 → 应用 → 组件层级。用户配置、镜像锁、模板、声明和说明同处。当前先实现数据库与独立迁移阶段；API/worker/scheduler、Web/Admin及Redis/RabbitMQ/Casdoor身份仍待接入，不代表业务应用已部署完成。

## 文件与参数

| 位置 | 用途 |
| --- | --- |
| `config.yaml` | 数据库名、运行/迁移用户名、任务修订、预期schema、私有路径及本批容量预算；共享开关来自上一级config，namespace来自环境site.yaml的app_namespace，origin来自对应前端config |
| `image.lock.yaml` | 已构建并由Harbor只读身份核对的镜像摘要与源码提交；部署复用产物 |
| `database/` | 库与账号初始化、独立运行ServiceAccount和运行账号Secret；复用平台命名空间、网络策略及registry-puller |
| `migration/` | 独立迁移Job与真实权限/读写验收；复用同一后端镜像的规范迁移命令 |
| `stages.yaml.j2` | Flux的platform-services → tpl-database → tpl-migration依赖链 |

密码在 `config.yaml` 指定的私有目录 `credentials.yaml`，root0600；独立数据盘备份逐字节核对。首次自动生成两个独立强口令，已有声明后丢失口令必须从备份恢复，不能再随机生成。Git只保存SOPS密文；日志不输出连接串/密码。修改私有文件不等于完成数据库密码轮换，当前流程会拒绝其与备份不一致。

`enabled=false` 阻止本模块的部署动作，不表示删除或停止已运行工作负载。数据库/角色名与namespace是身份边界；已有数据后调整需要迁移，不能当作普通开关。端口5432沿用平台固定内部接口，Service、网络策略和连接串配套。Job修订用于显式创建新执行对象，不会原地改不可变Job；已完成Job和旧数据不会自动清理。

## 日常入口

在k8s仓根执行：

```sh
make -C infrastructure application-deployment-plan APP=tpl
make -C infrastructure application-stage APP=tpl
# 审查生成的GitOps声明、提交并通过既有Flux release流程晋级固定摘要后：
make -C infrastructure application-bootstrap APP=tpl
make -C infrastructure application-check APP=tpl
```

`application-stage` 仅生成可审查声明，不操作运行数据库；bootstrap串联渲染、与已提交/晋级声明核对、Flux协调、真实Job结果检查。启用初期先单元验收，未来应用运行阶段沿用这一条编排。运行镜像不执行自动迁移。

数据库归迁移账号所有；运行账号只有库连接、schema使用、业务表CRUD/sequence使用权，禁止建表及修改alembic版本表。初始化检测外来同名库/角色并拒绝接管，既有角色不静默重设密码。验收临时表名随机且由迁移账号创建/删除，不删除业务表；实际校验运行账号CRUD与DDL拒绝。

口令备份不是数据库备份；本单元是全新空库第一次部署，尚无旧数据迁移。将来对已有库升级前须准备数据库备份和恢复路径，不能将Git回退当作数据库回退。完整应用登录、任务及跨应用链路另验。

## 当前部署结果（2026-10-03）

库初始化 `data-platform-dev/tpl-database-v2` 和迁移 `app-platform-dev/tpl-migrate-5b38d39836dc-v1` 已成功，schema为20260911_0003；真实CRUD、运行身份DDL拒绝及迁移元数据写入拒绝均通过。完整bootstrap重复执行四阶段changed=0。API/Worker/Scheduler及前端仍待部署，不能据此判断业务已跑通。

成功的Completed Job保留为Flux期望对象；不要直接删除或加TTL，否则Flux可能重建并重新执行。失败v1 Job和误建tpl-app-dev已按精确归属清除。修改SQL必须更新bootstrap修订，修改迁移任务必须更新migration修订，经相同声明发布流程实施。

## Redis身份准备

redis_user为独立登录名（不得default），redis_key_pattern固定tpl:*以匹配模板业务键，redis_identity_revision控制一次性Job修订。私有redis.yaml及备份不输出、不入Git。redis/保存初始化及真实隔离检查；runtime.sops.yaml供后续业务角色读取，provision.sops.yaml只用于数据命名空间的一次性账号初始化。原有平台管理员Secret不复制到应用命名空间。

本单元准备持久ACL能力，须按docs/platform-kind-v1/tpl-redis-maintenance.md批准维护并验收后才算可用；RabbitMQ/Casdoor注册和常驻业务仍未完成。
