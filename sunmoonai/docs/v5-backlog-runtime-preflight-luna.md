# B7l：本地 KIND 角色、身份与升级前置核查（Luna）

2026-09-13，单人只读预检，不是发布验收或独立评审。
核查时段 UTC 08:33～08:41（北京时间 16:33～16:41）。

## 1. 结论与边界

当前三个 App 可运行，但仍是 9 月 11 日开发发布；本轮 B2～B7 的源码修复尚未进入
这些镜像。实际核查确认：同 App 的 API/Worker/Scheduler 共享数据库 principal 和
broker Secret 引用；Worker 仍只探测 pong，Scheduler 无活动探针；Info 需数据库升级，
Knowledge 需明确新摄入映射和旧协议任务的处置。**不能仅替换镜像后宣称旧账已还清。**

本包只新增本报告、更新[处置清单](v5-backlog-disposition-luna.md)和
[覆盖矩阵](v5-backlog-coverage-luna.md)。不改源码、历史 bundle、策略或业务数据。
未启动迁移/回放、部署、凭据轮换、备份导出、外部 Provider 调用或监控安装。
没有 push、master 更新、父仓 gitlink 更新或云端操作；两份预置协议草案不动。

| 约束 | 核查方式 |
| --- | --- |
| D1/D2/D3/D8 | 每个角色用自身现有连接读取其本 App 的版本和角色元数据；显式 READ ONLY，单 SQL 3 秒、整体协作超时 8 秒；不跨库、不迁移 |
| I3/I8 | 查询 Deployment 的 Secret 引用，不读取 Secret 对象内容；数据库不输出连接串，日志只输出固定白名单错误类型；配置仅取键名/少量非敏感参数 |
| R1～R4、T3～T5 | 同时核 bundle、实际 imageID、发布锁及数据库 revision；不把源码测试当部署验收，不把不同 ServiceAccount 当凭据已独立 |
| R6 | 本包无公共源码/模板修改；下一包修渲染覆盖时仍模板先行、Info → Knowledge → Investment 串行验证，保留领域挂载 |

k8s 起点 `4d6258ff9babc2ff1ce99a1c92d14b4baa98bb42`；四后端起点沿用
[B7k 固定 SHA](v5-backlog-retention-audit-luna.md)，本包不改变这些源码。

## 2. 实际集群与发布版本

本机 Docker 只有三个运行中的 KIND 节点；集群名 `kind`。三个 Node providerID 均为
`kind://docker/kind/...`，Ready=True。kube-system UID 为
`5d71ab3a-ea5a-4535-adc6-d7698d820249`，app-platform-dev UID 为
`b150948e-9ce4-4d82-82c4-9469e626ed5e`。未写用户 kubeconfig：每次显式取得 KIND
配置，经管道交给 kubectl，未打印配置或凭据。

kube-system 的 kindnet/kube-proxy 均 3/3；本地网络仍不是 Calico 的包级策略验收环境。
三个 App 各有 API 2、Worker 1、Scheduler 1，合计 12 个后端 Pod，全部 Running/Ready。
Deployment observedGeneration 均追上 generation；前后两次 Pod 重启计数不变。
这些是时点就绪证据，不代表完整浏览器业务旅程、消费进展或持续可用性。

| App | 当前 release_id / 发布锁中的后端源码 | 实际 Pod imageID 的 SHA-256（同 App 四 Pod 一致） |
| --- | --- | --- |
| Info | kind-info-dd-20260911 / `8c3b695e3e2b5b4064b5b14ce8d2b6d6767177e2` | `884dc222c2c7c3fc86787592ec03a5bb306a44a8bf069df10e3c9ed38806f1b9` |
| Knowledge | kind-know-dd-20260911 / `72f17d2e81bafaa5818a9a94e735c011720b9baf` | `36bc1dd6ac4631339070d29825f16373aa65a1f9fe65385d0f90a4564f87af17` |
| Investment | kind-invest-dd-20260911 / `00b1b55cb1d186224e57fe3528998b6734ecb327` | `6a30e2d50eb47735ba8cf449fb776a5d1c848d84311c7e4ce69e99ab8719a434` |

三份 `app-platform/<app>-app/deployment/bundle/release.json` 均 formal_release=false、
deployment_target=KIND；其 backend digest 与实际 imageID 一致。源码 SHA 来自发布锁
及 Pod 模板注解，本轮没有重新验证镜像构建证明、Harbor 拉取/恢复或 OCI 签名。
Worker 模板缺 release-id 注解，但有 source-commit；当前 bundle 也如此，不是本轮
发现某人临时改了集群。后续发布应补完整关联，不回填历史发布文件冒充当时已有。

## 3. 身份、探针与渲染覆盖的根因

对每 App 一个 API、Worker、Scheduler 共九个 Pod 的实际数据库查询均成功，事务
read_only=on。不是只根据 Secret 名称猜测数据库用户。

| App / 库 | API、Worker、Scheduler 实际 principal | 当前 revision / 本地源码 head |
| --- | --- | --- |
| Info / info_admin | 均 info_backend_user | 20260911_0007 / 20260913_0009 |
| Knowledge / knowledge_admin | 均 knowledge_backend_user | 20260911_0006 / 20260911_0006 |
| Investment / investment_admin | 均 investment_backend_user | 20260911_0007 / 20260911_0007 |

九次查询的 rolsuper/rolcreatedb/rolcreaterole/rolbypassrls 均 false；**不等于完整最小权限**，
没有检查全部角色继承、表所有权、ACL 或执行独立撤销。三个领域库仍分开，没有跨 App
合库证据。同一 App 的三角色显式引用相同 `<app>-backend-postgresql-conn/DATABASE_URL`
和 `<app>-backend-broker/CELERY_BROKER_URL`；本轮未连接 broker 检验其实际用户名/ACL。
Migration bundle 另引 `<app>-backend-migration-postgresql-conn/MIGRATION_DATABASE_URL`；
当前 app-platform-dev 没有 Job，不能据此证明迁移没跑过（其 Job 有清理机制），也不能
当作本轮 Migration principal 或备份恢复验收。

每个后端角色有独立 ServiceAccount 且 automountServiceAccountToken=false，但这不能
隔离已注入的同一数据库/消息凭据。模板 `tpl-app/k8s-deployment/templates/20-runtime.yaml.tpl`
本来分别使用 API/WORKER/SCHEDULER_DATABASE_URL 和对应 CELERY_BROKER_URL 键。
实际实例渲染链的 `app-platform/scripts/render_info_release_base.py`、
`render_knowledge_release_base.py`、`render_investment_release_base.py` 及各 deployment/render.py
保留旧迁移期环境覆盖，重写为共享运行身份；Info base 的注释称 role-specific，不能
据注释覆盖实际代码和九次元数据结果。修复落点是实例覆盖/配置供给/真实授权验收，不是
再造一套后端或只改 ServiceAccount 名称。

| 角色 | 当前运行声明 | 未闭合的验收 |
| --- | --- | --- |
| API | ready=/health/ready，live/startup=/health/live；grace 45 秒，preStop sleep 10 秒 | 镜像尚无 B7b 新 schema 探针；同名路径不证明新行为已上线；排空/恢复仍需演练 |
| Worker | readiness 为 inspect ping 后 grep pong；无 live/startup；grace 90 秒，preStop sleep 10 秒；并发 2 | B7e 队列/任务注册探针未接入；pong 不能证明 prefork 执行；SIGTERM/长任务回投需按获准负载验收 |
| Scheduler | 单副本 Recreate；无 ready/live/startup；grace 45 秒 | B7i 活动观测未进镜像；进程 Ready 不能证明 Beat tick 或发送；不以 broker 故障触发重启 |

旧实例 Worker 来自旧覆盖路径，模板升级不自动等于实例行为升级；新渲染验收必须检查
最终产物，不能只检查输入模板。新 Scheduler/Worker 策略仍需区分配置就绪、活动观测与
业务回执；不能见 null 就盲目加入会因外部依赖故障重启进程的 liveness。

## 4. Knowledge 历史任务与迁移前置

API 与 Worker 的实际环境均没有 `INGESTION_DATASET_BINDINGS`。新代码默认空映射，
`require_job_binding` / `execution_state` 还要求服务端受理历史标记；原检索 allowlist
不能代替摄入授权。不输出 Dataset ID、请求内容、Provider 凭据或任务样本。

只读聚合结果：54 条 knowledge_ingestion_job，首条历史中 binding 标记存在数 0，
执行标记精确等于 version=1 的数量 0。状态为：artifact_unreadable 10、artifact_verified
18、external_api_error 1、failed 6、legacy_binding_missing 3、succeeded 16。
这些都在当前源码 TERMINAL_STATUSES 内，**不是 54 条在途任务，也不是 54 条成功任务**。
本轮没有替旧任务补标记、重试或重放；它们今后若要恢复/重试，需要受控调查，不能让
客户端提交的旧 metadata 自动获得新协议授权。

knowledge.ingest.v1 的现存 Outbox 共 5 条，均缺 generation 或 step，但 5 条均有
匹配 Inbox；不是五条丢回执积压。knowledge_provider_operation 当前 0 行，**不能推出
历史远端没有副作用或所有旧上传回执已查清**。不查 Provider 也无法批准盲目重传。

Info 的 0008/0009 会核对存量 canonical/逻辑分发身份并加新写入保护；实际库仍 0007。
本轮只查 revision，没有运行两个业务 preflight、备份/恢复或变更。不能边跑旧写者边迁移，
也不能为让迁移过门禁自动合并重复业务记录。

## 5. 本轮失败调查与验证结果

- 最初 Docker 只读查询被沙箱拒绝；经平台批准重试成功，无容器变更。
- 一条压缩输出的 jq 表达式多写了结尾括号；该段没有生成有效部署结果，修正后完整
  重查九个 Deployment，并用 set -euo pipefail 防后续命令掩盖失败。不是集群故障。
- 首次 DB 探查误把原始 postgresql:// 直接交异步引擎，触发 ModuleNotFoundError，
  查询在第一个 Pod 停止。确认 /app/.venv/bin/python 和 sqlalchemy/asyncpg 存在，
  psycopg/psycopg2 不存在；生产 Settings 会将 URL 规范化为 asyncpg。探查改为复用
  镜像现有 get_settings().database_url 后九次通过；不安装依赖、不改生产配置。
- 初次统计中的人工“终态子集”得出 48 条不在子集，**不采用该值判断在途量**。
  已改查真实状态分布，并逐项对照当前源码 TERMINAL_STATUSES，确认这 54 条均是
  该枚举终态；不能用任意同义状态（如 indexed）代替领域状态机。
- 抽查三 App 各一个 API 的 previous 日志，均有 ConnectionError、Temporary failure
  in name resolution、Application startup failed；说明所采样的上次启动遇到 DNS 失败。
  当前已恢复 Ready，核查期间重启计数不变。未取得 DNS 服务当时全部历史，故不把
  相关时间上的宿主机重启当作已证明的最终根因，也不宣称修复了全部历史重启。

只读本地验证：三个已提交 bundle 的 `verify-formal-instance.py --bundle ...` 均通过；
`python3 -m unittest discover -s sunmoonai/app-platform/scripts/tests -q` 为 12 tests OK；
模板部署测试为 8 tests OK（0.188 秒）。这 20 项是现有脚本回归，不是新增后端测试，
也不能覆盖它们本来没有检查的分角色真实权限/旧任务切换。没有启动一次性测试容器。
本包三份文档 `doc-gate.py --staged` 及 `git diff --cached --check` 通过。

## 6. 后续工作与外部操作边界

下一源码包优先核修**实例渲染覆盖及验收门禁**：最终产物继承已验证模板能力、Worker
发布关联完整、角色权限输入明确且缺失失败关闭；测试同时保护各领域额外身份/存储
挂载，不把历史已部署 bundle 偷换成新产物。新增角色凭据供给和撤销验证须另列精确范围。
不能仅改 Secret 键名，却继续把相同密码/用户名灌进三个键。

最终共同发布前还必须具备：

1. 固定三后端新源码、镜像 digest 和新的开发 source lock，明确只发布本地 KIND；
   保留旧发布恢复能力，不覆盖正式版本或靠重新构建冒充晋级。
2. Info 的两个存量预检、各 App 可恢复备份/隔离恢复、旧写者排空和新旧角色权限证据；
   Knowledge 的批准 Dataset 映射及旧任务分类，不默认给所有历史任务新授权。
3. 按同版本 API/Worker/Scheduler + Migration 顺序切换并验收，不能在旧代码运行时
   先迁表；准备旧版本代码与匹配数据库/外部回执对账的回滚方案。
4. 实际角色探针、broker 丢消息/回执、排空/恢复、Info→Knowledge→Investment 主链
   及当前身份拒绝矩阵，不能由 Pod Ready 替代。

现有 `app-platform/scripts/development_release.py` 已要求明确 KIND、完整 App、匹配
cluster/release 的备份恢复回执及旧后端归零且 Pod 消失。不能为了快部署绕过它。
Investment 的 deployment/deploy.py 在迁移流程还会执行旧角色 LOGIN/NOLOGIN 变更；
调用整个 deploy.py 不是“只换镜像”，必须把这些副作用纳入批准/回滚对象。

本报告不批准上述外部操作，也不关闭 B7/B8/B9。继续遵守所有者“剩余处置完成后最终
一次性同步”；监控部署/告警仍由 N4-OPS-01 接收，归档欠账见 B7k，不在本包默默延期。
