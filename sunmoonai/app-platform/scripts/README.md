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

本目录的 `build-push-app-images.sh` 只做一件事：**在 WSL 本地构建镜像，并直推到指定 Harbor**。

```text
tpl / info / knowledge / investment
  × backend / admin-frontend / web-frontend
```

ADR-0007 把 `admin-backend` 与 `web-backend` 并成了单一 `backend`；`research`
已退役。共 12 个镜像。

脚本不部署 Kubernetes，也不触发 Harbor 复制。

## 两种镜像到达远程的方式（勿混淆）

| 机制 | 入口 | 配置位置 |
|------|------|----------|
| **本地构建直推** | `build-push-app-images.sh` | 本目录 `build-push-app-images.conf` |
| **Harbor 复制** | Kind Harbor UI → 复制管理 | `cicd-platform/harbor/docs/kind-to-c1-sync-README.md` |

直推：改代码后 `docker build` + `docker push`，按 `CLUSTER` 推到对应 Harbor。  
复制：镜像已在源 Harbor 中，由复制规则同步到目标 Harbor，无需重新构建。

## 文件

```text
build-push-app-images.sh      # 构建并直推镜像
build-push-app-images.conf    # 各 CLUSTER 的直推仓库地址
```

配置优先级：

```text
命令行环境变量 > build-push-app-images.conf > 脚本内置默认值
```

## 直推目标：KIND 与 C1 配置不同

Kind 与 C1 是**两套独立 Harbor**。`CLUSTER` 决定直推落到哪套：

| CLUSTER | 本机 WSL 直推地址 | 其它机器直推 C1 |
|---------|-------------------|-----------------|
| `KIND` | `harbor.sunmoonai.com:30443` | 不适用（无本机 Kind 时无 KIND 直推场景） |
| `C1` | `harbor-c1.sunmoonai.com:30443` | `harbor.sunmoonai.com:30443`（无本地 Kind 冲突，可直接用主域名） |

本机 WSL 同时跑着 Kind Harbor，`harbor.sunmoonai.com` 会解析到本地实例，因此 C1 直推需用 `harbor-c1` 别名（`/etc/hosts` 指向 C1 公网 IP）。在其它机器上构建直推远程 C1 时，改 `build-push-app-images.conf` 中 `C1_*` 为 `harbor.sunmoonai.com:30443` 即可。

对应配置项见 `build-push-app-images.conf` 中的 `KIND_*` 与 `C1_*`。

## 推到 Kind Harbor

```bash
cd ~/master/k8s/sunmoonai/app-platform

docker login harbor.sunmoonai.com:30443

CLUSTER=KIND ./scripts/build-push-app-images.sh
# 或省略 CLUSTER（DEFAULT_CLUSTER=KIND）
./scripts/build-push-app-images.sh
```

## 直推到远程 C1 Harbor

```bash
cd ~/master/k8s/sunmoonai/app-platform

docker login harbor-c1.sunmoonai.com:30443

CLUSTER=C1 ./scripts/build-push-app-images.sh
```

远程 `k8s-images` 中需已有 Python、Node 等基础镜像，否则 Dockerfile 构建阶段会失败。

临时覆盖仓库地址：

```bash
CLUSTER=C1 \
TARGET_REGISTRY="harbor-c1.sunmoonai.com:30443/app-images" \
BASE_REGISTRY="harbor-c1.sunmoonai.com:30443/k8s-images" \
TAG="architecture-v2-dev" \
./scripts/build-push-app-images.sh
```

## 常用参数

指定版本（默认 `architecture-v2-dev`）：

```bash
TAG=my-feature ./scripts/build-push-app-images.sh
```

⚠ **`1.0.0` 与 `2.0.0` 被拒绝**——它们分别是 v1 与 v2 的正式发布 tag，
指向已过门禁的 digest；本脚本产出的是未经门禁的本地构建，不该占用它们。
详见脚本内 `PROTECTED_TAGS` 上方的说明。确需覆盖：

```bash
ALLOW_PROTECTED_TAG=true TAG=2.0.0 ./scripts/build-push-app-images.sh
```

从某个组件继续：

```bash
START_FROM="knowledge/backend" ./scripts/build-push-app-images.sh
```

只打印命令，不执行构建和推送：

```bash
DRY_RUN=true ./scripts/build-push-app-images.sh
```

使用 Docker 构建缓存：

```bash
NO_CACHE=false ./scripts/build-push-app-images.sh
```

输出 plain 日志，便于排错：

```bash
PROGRESS=plain ./scripts/build-push-app-images.sh
```

只构建部分 App 或组件：

```bash
APPS="info knowledge" \
COMPONENTS="backend web-frontend" \
./scripts/build-push-app-images.sh
```

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
