# App 镜像构建与推送

可复用的源码拓扑、模板三方同步与 Calico 检查在 [validation/](validation/README.md)。
旧重构目录已清退，不再从历史 R3/R5/R7 脚本启动开发发布。

## KIND 开发包部署

开发包沿用各 App 的 `deployment/render.py`、规范 `deployment/bundle/` 和
`deploy-*-app-all.sh`，不另建部署入口。正式渲染默认值保持不变；只有显式传入
`--development-input deployment/development-input.json` 才生成
`formal_release=false`、`deployment_target=KIND` 的开发包。

输入包含 `kind=kind-development-release-input`、`logical_app`、三个 `images`
digest、`migration_head` 和完整 `development_source_lock`。渲染时校验父仓源码锁、
三个干净子仓的 commit/tree 和实际 Alembic head；生成后须运行
`verify-formal-instance.py`，并将输出更新到唯一规范 bundle，同时更新 `.conf`。
来源锁记录的是源码准备时的事实；实际部署边界由新的 `release.json` 声明。

当前候选 `kind-b7-20260919` 显式声明 `runtime_identity_mode=independent-v1`，
渲染器据此启用 `CELERY_TASK_TOPOLOGY_PREDECLARED=true`。apply 检查每 App 的
`<app>-backend-runtime` 六个键：三个角色各自的 `DATABASE_URL` 与 `CELERY_BROKER_URL`，
必须是不同账号/密码、正确 App 数据库和 vhost；本批不使用 result backend。
**此检查只核结构，不证明账号存在或权限正确。**供给、真实登录/允许与拒绝探针、
迁移后授权及旧身份撤销仍须受控完成；不能靠创建一个 Secret 绕过运行验收。

开发 apply 不再隐式重跑 Investment 的旧 broker/Redis 供给或旧账号 LOGIN/NOLOGIN。
Knowledge/Investment 只读核对已批准的 active retrieval binding，不自动重写或重启。
旧 broker helper 和旧 RabbitMQ Helm 入口发现接管标记、新 runtime Secret 或启动定义内
新用户即拒绝，查询错误也拒绝；这是防误覆盖措施，不是阻止管理员绕过的授权边界。
如需更新共享 RabbitMQ，须走保留非目标条目的新供给流程，不能删除接管标记强行运行旧入口。

Knowledge 摄入授权必须单独显式给出；检索 allowlist 不授权上传。渲染时使用
`--ingestion-dataset-bindings-file deployment/ingestion-dataset-bindings.kind.json`，
由 Backend 的同一严格解析器校验并计入 ConfigMap/发布输入摘要。不传该参数时绑定为空，
所有新摄入请求仍被拒绝。当前 KIND 配置只获准写入既有 `codex-smoke`；不据此重放旧任务。
渲染配置或构建镜像不等于已应用到集群。

**只换镜像的升级**（2026-09-24 起）：运行身份不变、只换镜像并跑新迁移时，开发输入可声明
`runtime_identity_upgrade = {prepared_release_id, preparation_plan_sha256}`，指向已应用、已激活的
上一份身份准备（其 `applied.json` 的 `plan_sha256`）。apply 时 `--identity-preparation` 仍指向那份准备
目录；`--backup-receipt` 仍必须是本次 release 的新回执（第 2 到 4 步照做：停写、静止库备份、两次恢复
演练）。迁移后不再重建身份，而是在同一事务里核对目录（`validate_upgrade`：三个运行身份必须已存在、
无成员关系、关系全归迁移角色、无外来 grantee、客户端为零）并只重放评审过的 GRANT
（`upgrade_sql`：无 CREATE ROLE、无密码、无默认 ACL 变更、无撤销），再做真实登录与权限探针。
记录落在准备目录下 `database-upgrade-<release_id>/`。新表必须先进入该 App 的 `*_database_policy.py`
评审清单，否则编译拒绝；序列不在评审范围，新表主键一律用 UUID 默认值。

原准备目录丢失时用 `kind_identity_recover.py --app <app> --kubeconfig … --cluster-uid … --prepared-release-id <当时的 release>
--output <git 之外的新私有目录>` 从集群现状重建记录：只读线上运行 Secret（核对 release 注解与契约）与数据库目录
（三个运行身份已存在、旧登录已退役），当场做真实 DB 与 AMQP 登录正反例探针，全部通过才写出
`plan.private.json`/`applied.json`/`database-activation/complete.json`（标 `recovered_from_live`）。它不写集群、不写库；
产出的 `plan_sha256` 就是升级声明里的 `preparation_plan_sha256`。私有目录放在任何工作区之外，避免随工作区重建丢失。

开发升级仅允许 KIND 的全 App 事务；C1/production、组件单独 apply 均拒绝。
非 plan 操作还检查节点实际 `providerID`。迁移按以下顺序执行：

1. 静态门禁、隔离库迁移/数据对账/授权/回退演练。用 `kind_identity_prepare.py`
   生成私有计划，审查精确摘要后显式 `--apply --expected-plan-sha256 ...`；它只准备
   独立运行 Secret、broker 用户和权限，不授权数据库、不退休旧身份。真实 AMQP
   验收通过后，运行完整 `server-dry-run`。
2. 进入维护窗口，先停 API/Scheduler、待 Worker 正常排空后再停止，等待 Pod 全部退出；确认没有控制器
   把旧写进程拉起。不得清空队列或伪造完成回执。
3. 对静止的业务库再备份并实际恢复验证。备份以 0600 保存在 Git 外；回退窗口内保留。
4. 使用 `kind_database_rehearsal.py --cutover-release <本 App bundle/release.json>`
   出具 `cutover-receipt.json`。这会检查停写、两次真实恢复和恢复后原库行/目录未变化，
   绑定 cluster UID、App、完整 release 内容摘要、候选镜像/head 与备份 SHA；不手写
   `restore_verified=true` 来冒充真实恢复。Info 对象还须另核对归档与停写库引用一致。
5. 既有 deploy 入口同时接收 `--backup-receipt <cutover-receipt.json>` 和
   `--identity-preparation <准备计划目录>`，执行独立 Migration Job，然后在单事务内
   核对目录并创建/授权数据库新角色，真实认证和权限探针通过才恢复 runtime 与 ingress。
   验证 rollout、数据版本、健康检查及 drift。Info → Knowledge → Investment 串行。
6. 新运行身份及业务验收后，另行精确撤销旧库登录与旧 vhost 权限；供给和部署入口
   不会自动执行这一步。禁止把 rollout Ready 当旧身份已失效的证明。

准备出现部分失败时不可重复 `--apply`。仅当六个定点写入均有成功日志且实机状态
完全一致，可以显式 `--verify-prepared --expected-plan-sha256 ...` 只读重做认证验收；
此入口不补写、不覆盖、不删除服务器资源，原始计划和日志不变。新计划名字冲突时
仍拒绝。当前是一次性身份切换流程，不是任意新版本或既有角色的通用权限协调器。

备份回执是操作员验证记录，不是密码学证明。临时停副本只是维护步骤，不替代 Git
中的最终副本声明。存在未确认投递时 downgrade 必须拒绝；应使用已演练的备份恢复，
不能删除任务以让回退通过。开发包不得改写 `1.0.0` / `2.0.0` 发布别名。

备份准备工具（默认在线模式**不生成可用于部署的停机备份回执**）：

- `kind_database_rehearsal.py --help`：使用对应 Backend 的 venv（asyncpg、SQLAlchemy），
  显式 kubeconfig/集群 UID/候选镜像 digest/head/新私有目录；导出业务库并在固定 PG
  镜像的无外网临时容器内两次恢复、迁移、对账。当前固定镜像为本机 PG 17.6；换环境
  必须重审镜像与范围。角色/Secret/业务数据只落 Git 外 0700/0600 私有目录。
  只有显式 `--cutover-release` 并通过全部停写/恢复检查才额外输出切换回执。
- `kind_info_object_backup.py --help`：只读读取既有 Info API 配置和文件引用，核对
  明确版本或未版本化引用的记录摘要、大小，再导出私有 tar。任何缺失都失败，不跳过、
  不自动寻找别的版本、不改数据库；成功导出也不等于 S3 恢复已验证。
  `info_object_backup_payload.py` 是其 Pod 内只读载荷，stdout 含私有数据，勿直接打印。

## 应用构建 → OCI 批次 → 独立发布

`build-push-app-images.sh` 保留原文件名和 App/组件/构建参数配置，行为已改为：
**默认输出计划，实际执行只构建和准备制品，不再 docker push。**
四个 App 各有 backend、admin-frontend、web-frontend，共 12 个可选组件。
它不连接集群、不创建 Harbor tag，不触发 Harbor 复制。

| 控制项 | 当前用途 |
| --- | --- |
| `APPS` / `COMPONENTS` / `START_FROM` | 选择构建范围和续接点 |
| `SOURCE_ROOT` | 四个应用仓的父目录；默认与当前 k8s 仓并列 |
| `TAG` | 候选标识，只记入构建元数据；仍拒绝 `1.0.0` / `2.0.0` |
| `CLUSTER` | 记录使用环境，不切换仓库域名；旧 `KIND_*` / `C1_*` 等仓库配置拒绝 |
| `TARGET_REGISTRY` / `BASE_REGISTRY` | 固定独立 Harbor 的 app-images / k8s-images |
| `ARTIFACT_ROOT` | 必须事先准备的 Git 外绝对目录；每次生成新的 `app-build.*` |
| `PUBLICATION_SETTINGS` | Skopeo 路径/摘要、临时目录、空间、超时与重试；默认本机已备工具配置 |
| `DRY_RUN` | 默认 true；只有 false 才构建与导出 |
| `NO_CACHE` / `PROGRESS` / 依赖源 | 原构建控制继续保留；不会自动清缓存 |

环境变量优先于同名 `.conf`。默认计划不访问 Docker/Harbor；读取源码路径和 Git 状态。
实际执行要求应用父仓和组件子仓干净（含子模块状态）、构建前后两级提交不变，并分别记录；被 Git 忽略的文件和 Dockerfile 的网络下载
仍可能进入构建，因此这不是可复现构建证明，构建依赖闭包仍须单独验收。

```bash
# 在 k8s 仓根目录；先看计划。
APPS=investment COMPONENTS=backend bash sunmoonai/app-platform/scripts/build-push-app-images.sh

# 事先选择并准备 Git 外制品目录及 settings 中的临时目录，核对剩余空间。
# 本例路径须按实际盘点设置；本操作不会自动创建共享根目录。
ARTIFACT_ROOT=/absolute/prepared/app-artifacts DRY_RUN=false \
APPS=investment COMPONENTS=backend \
bash sunmoonai/app-platform/scripts/build-push-app-images.sh

# 复核本次 build.json、source.json、OCI 制品/摘要后，先看发布计划。
./sunmoon harbor publish --batch /absolute/prepared/app-artifacts/app-build.ID/investment-backend/oci/publication.json
# 获准写入所选仓库后，增加 --credentials-file /absolute/private/publisher.json --apply。
```

每个组件通过 Docker 的 `--iidfile` 固定本次 image ID，按 ID 导出，避免从可变 tag 猜制品。
`registry-platform/prepare_image.py` 把 Docker tar 转为 OCI，核 manifest 摘要并生成同一发布器
接受的 `publication.json`。转换可能改变 manifest digest，以转换后的实际摘要用于部署；
Docker image ID、构建器 digest 和 OCI manifest digest 不混用。

构建失败保留已有制品，不报“发布成功”；重试创建新目录，发布失败重用原批次，无须重新构建。
制品、Docker 构建缓存与导出包不随脚本自动清理，待按最终清理清单批准后处理。
只输出计划/通过静态检查不代表实际构建、转换、推送或 CI 已验收。
详细输入与边界见[统一发布说明](../../registry-platform/docs/publication.md)。

## 与部署配置的关系

正式 App 使用不可变 `repository@sha256:digest`，不再用可变 tag 驱动部署。每个 App 的
`deploy-<app>-app-all.conf` 是可读发布声明，`profiles/` 保存集群操作参数；入口会先与已门禁
bundle 逐项核对。完整合同见 `../docs/formal-deployment-configuration.md`。

构建/复制完成后，部署入口：

```bash
cd ~/master/k8s/sunmoonai/app-platform/info-app
./deploy-info-app-all/deploy-info-app-all.sh config --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND
```

当前 C1/production formal profile 默认禁用；在对应门禁完成前不得仅靠复制镜像或修改开关启用。
