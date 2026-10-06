# 当前工作：按组件统一操作与账号维护（2026-10-05）

所有者已批准上一轮完整方案并要求按任务表实施。基线53abb007e8960c53faea750ea6477f5c2e92a576，分支platform-kind-v1，仅修改新体系infrastructure/gitops/docs和本检查点；不push，不改旧sunmoonai/冻结Luna或四业务仓。日常Make→Ansible→Flux/SOPS，配置同组件放置。此次授权不自动延长上一单元08:25–10:25 UTC窗口，也不授权WSL关闭/删群；实际停服按具体范围另批2小时，容量10GiB及数据盘230GiB增长检查有效。

## 顺序任务表

| 编号 | 任务 | 依赖 | 验收条件 | 状态 |
|---|---|---|---|---|
| T1 | 逐对象盘点配置、阶段、依赖、账号及密码表映射 | 无 | 对象归属唯一；映射不输出秘密；确认人工账号范围 | 已完成 |
| T2 | 统一platform-*对象选择、只读计划/配置/状态及动作准入 | T1 | 整套/平台/应用/组件选择正确，未知对象拒绝；不增加重复CLI | 13项原生正反例通过；继续与T3联验 |
| T3 | 拆分共用Flux部署阶段与原生选中对象stage/deploy/check | T2 | 组件独立根、真实依赖；未选声明/Pod/Job/PV保持；整体源晋级范围透明 | 188个候选服务对象与原14阶段逐对象一致；拆26阶段；整套/PG/Tpl-Web实际stage范围通过；固定拓扑源已晋级，188对象归属交接通过 |
| T4 | 账号元数据、预设/导入/本机查看、恢复和密码规则 | T1 | 指定值首次生效、随机默认、主备保持；已有身份差异不自动覆盖 | 10类维护账号目录；三类真实登录通过；12/18导入及重复导入通过；PG/Redis/Rabbit首次预设已接入、未新建实演 |
| T5 | 按组件实现真实密码轮换与失败恢复 | T4 | 目标身份/权限核对，新密码登录、配置/备份一致；不重跑旧初始化Job | Harbor/Casdoor事务及原生恢复候选已实现；7项模拟故障/策略检查及6项真实SOPS/临时Git候选检查通过；实际轮换未执行，Kibana保持 |
| T6 | 原生发布、授权范围内实演单组件/整套与已选人工账号 | T3/T5 | 原门禁、真实协议、重复部署；原节点/卷/未选对象保持 | 拓扑部分完成：整套部署、PG/Tpl-Web单组件deploy/check、整套重复deploy、整套check（首次瞬时失败后重跑通过）；Harbor/Casdoor实际轮换未执行，窗口已关闭 |
| T7 | 删除失效公共入口、收敛维护说明及清理本轮临时文件 | T6 | 日常只有一套对象操作；文档准确；本地提交、工作区干净 | 仅完成/tmp证据归档（86文件逐一SHA256核对）；聚合源码清理、入口收敛未做，并入后续重构 |

## 盘点结论与当前候选

当前services layout已经有组件路径映射，但platform-services仍聚合core及三个平台；需要真实拆阶段，不能只把Make名字转接。ELK runtime也聚合Kibana/Logstash，分别处理依赖。应用已有backend/Web/Admin阶段，复用common机制且不修改既有Job字节。

基线已有密码文件会沿用；本轮接入私有初次预设、表导入及账号目录。Kibana当前值保持，未来预设允许8–128字符且不含首尾空白；PG/Redis/Rabbit首次预设候选不覆盖已有值。所有者明确要求保留密码修改表作为开发阶段实际密码查阅表，并授权写入实际值；本表是明确例外，不作为运行部署真源、不输出到对话/日志、不push，生产前统一轮换。新Kibana15d已与私有输入同步，旧ELK密码明确不适用。账号轮换成功后同步当前值。第12项Harbor admin、第18项Casdoor built-in/admin映射已获确认；第15项旧ELK共享管理员不是新Kibana只读账号，不能自动复用。所有者已选择：采用第12/18项，Kibana保持独立现有密码。除所有者授权的开发查阅表外，值只在私有候选/内存读取，不进入日志或Git；现有账号轮换仍先准备具体回退并确认实际停服范围。

本轮只读/候选证据暂在/tmp/component-render-inventory-audit.json、component-stage-scope-audit.json、account-native-audit.json、account-transaction-audit.json及对应root0600日志；交付前归档并逐字节核对后仅清本轮文件。13个选择正反例、188对象相同、149运行UID保持、整套及两个组件实际stage范围通过。账号目录扩为10类，除三类已检查的身份外，数据库管理员只是路径/查看与部分首次预设接入，真实轮换未实现，不能声称全账号已验证。

Casdoor真实检查先失败，原因是把Go IsGlobalAdmin()方法当JSON属性；官方v4.12.0由owner=built-in判断。按真实owner/admin/isAdmin及未禁用/未删除核对后通过，未降权。所有者提醒数据库管理员也属于人工维护范围，因此新增PG/Redis/Rabbit/Elastic/Neo4j/Mongo/对象存储账号元数据，未擅改其口令。

最终候选13项选择及六原生play语法、账号四play语法、188对象与原提交对比、公开PG/Tpl-Web stage范围再次通过。Harbor当前admin/database私有副本已补齐且逐字节一致；账号隧道缓存已隔离到自动清理目录，之前只清本轮33个API发现缓存文件。

维护卡docs/platform-kind-v1/component-account-maintenance.md；私有恢复快照/mnt/sunmoon-data/backups/host/component-account-20261005T124637Z，原51阶段/两个聚合阶段/149受保护对象，源摘要保持。候选已本地提交e59bdc006a2eaca8c7b3af367ad7e801a6136547，原生flux-release退出0，固定OCI摘要sha256:e26d2a19932686a64a7226cbf64666c457d797450fdf92f462b184a1ca7a2aef，requires_sops=true；未晋级/应用，运行源仍为原摘要。42份准备证据736435字节已逐字节归档到恢复快照下preparation-evidence/，本轮/tmp源暂留作实际维护后复核，T7仅清本轮文件。

2026-10-05T13:03:50Z容量只读检查：C剩119291076608字节，230GiB未来数据盘增长66802679808字节，维护预算3221225472字节，扣减后49267171328字节，10GiB底线通过。窗口开始前重测。下一步申请范围明确的26阶段所有权交接与Harbor/Casdoor轮换，实际T6未开始。Casdoor账号源必须与拓扑发布分为两个OCI候选；本轮仍未发布/晋级/修改API账号/停服。旧单元实际运行状态和剩余大目标如下，不将本次代码整理当成新运行验收。

---

# 新体系交接状态（2026-10-05）

本文件只保留当前续接需要的事实；历次开发过程从Git及私有证据取得，不作为日常维护入口。工作树 `/home/zymun/worktrees/platform-kind-v1/k8s`、分支 `platform-kind-v1`，五仓并列；当前只修改k8s新体系，不push，不改业务仓、旧sunmoonai或冻结Luna参考。

## 已完成单元与批准边界

所有者批准第二个两小时窗口：2026-10-05 08:25:05–10:25:05 UTC（16:25–18:25 CST）。范围是ES永久修复发布、整套统一停启、Harbor全目录摘要与真实节点拉取；不关闭WSL、不删除重建集群。停服前在执行进程内复核时间，预留15分钟恢复。当前开发阶段容量底线10GiB，仍扣除数据盘长满230GiB的增长及操作预算；进入真实服务阶段再确定运维约束。

## 已完成的运行状态

- 原生 Make→独立Ansible模块→Flux/SOPS；已有环境整套platform-deploy、统一platform-check已通过。修复说明文档误入发布门禁后，最后一次完整platform-deploy退出0，46个recap全部failed/unreachable=0；最终健康及Harbor/资产比对均通过。完整原始日志归档到本节私有证据，不保留/tmp作为依赖。
- 独立root运行副本 `/opt/sunmoon/host/sunmoon-kind`、统一target、cluster/boot单元及Harbor/entry依赖已安装。Windows `sunmoon-data-mount` 为所有者登录触发、Highest/Interactive、无分钟周期，实际执行0；固定输入在管理员持有的ProgramData目录，不依赖worktree。
- 六个新旧节点 restart=no；旧Linux附盘单元disabled、新boot enabled。boot当前inactive，因为通过手动start恢复；不能当作真实开机证明。新target/cluster/Harbor/entry active。
- 新三节点sunmoon-kind运行、Ready；原始kind控制面停、两个worker运行。57个Running Pod全部Ready、33个Completed Job保留；51个Flux阶段当前代次Ready，13组PV/PVC Bound/Retain。
- 第二窗口两轮完整stop/start和重复start通过；重复start前后90个Pod UID和重启计数一致。平台/四应用真实公共协议、Harbor认证推拉、三节点Always认证拉取和DNS通过。所有节点、Docker卷、业务卷与数据保留。

## 固定身份与路径

- kubeconfig `~/.kube/sunmoon-kind.config`，context `kind-sunmoon-kind`；kubectl `infrastructure/.tools/bin/kubectl`。Kubernetes1.36.5、KIND0.33.0、Calico3.32.2；版本事实源为物料/image锁。
- kube-system UID `67d27d4a-f9ad-4f01-a37f-225144cacaef`；节点精确ID/挂载事实源 `/data/kind-clusters/sunmoon-kind/bootstrap/identity.json`，不要手写复制ID执行删除。
- Harbor2.15.2，宿主后端11443，公共仓库 `harbor.sunmoonai.com:30443`；独立数据 `/data/harbor/platform-kind-v1`。新集群入口29443、API27443。
- 数据盘230GiB，UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`，`/mnt/sunmoon-data` bind到 `/data/kind-clusters` 和 `/data/harbor`；禁止覆盖 `/data/kind-local-storage`。同C物理盘，不防硬件故障。
- 新物料根 `~/k8s-packages`，唯一配置site.yaml；旧物料根仅供原始部署。真实秘密在各模块私有配置/独立备份和SOPS，不能输出或提交。
- 已晋级源 revision `a49760273f05320f16231647d253e25541a94e1f`，digest `sha256:9f7bce56f15708fa015a8c967b32f7f802724e50bab4aebb60ee02676140b33f`。文档/宿主修复提交不自动改变晋级源。

## 本单元修复与证据

1. ES emptyDir保留0440TLS副本导致普通cp重启失败。原模板改 `cp --remove-destination`，保留Secret/数据/权限；a4976027发布、3ef5f402晋级，实际镜像重复复制、滚动及两轮冷启动通过。一次临时权限恢复只为先恢复现网，不成为日常依赖。
2. Docker重写节点hosts丢失Harbor网关，解析127.0.0.1后误访问节点Traefik证书。19191323在原ready/start恢复拥有节点的精确网关记录；未关TLS、未改代理/外部DNS。拉取探针另修正shell参数转义并保存失败Job/events。
3. 原生Windows安装器规范化短账号SID；Bash JSON比较加引号；容量脚本在本地C路径与root副本核对，不绕过RemoteSigned；API readyz、Pod/Flux加入有界收敛等待。
4. 3b4a6912只排除组件README参与晋级对象diff；全GitOps工作区仍须提交，所有其他文件仍严格匹配。只读核对接受README差异、拒绝实际ES声明差异；原失败总入口日志保留。
5. 第二窗口基线40仓库/104镜像条目；data完整冷态清单2676文件。registry/secret共1086文件、13,210,981,875字节路径/大小/SHA256完全保持。24处可变内容仅23个PostgreSQL文件及1个Redis文件；不声称数据库物理字节不变。完整目录逻辑digest/标签/大小、PV/PVC及Job身份、六节点ID/挂载/运行态、Docker卷集合比对通过。

私有证据 `/data/kind-clusters/sunmoon-kind/bootstrap/evidence/lifecycle-maintenance-20261005T0825Z`；前窗口0419Z独立保留。原安装回退 `/mnt/sunmoon-data/backups/host/lifecycle-a2gzkked`。原窗口等管理员操作后已到期，停服前未重新核对；发现后结束新增停服并恢复。失败原始记录不得覆盖为成功。

## 日常入口与后续顺序

日常维护以docs/README.md和模块手册为准：platform-deploy/start/stop/status/check均由 `make -C infrastructure` 调用，保留模块配置开关及单组件入口。修改声明仍render/stage→审阅提交→flux-release→显式晋级→原生bootstrap，不自动部署未批准配置。

1. 本单元完整部署/两轮启停/镜像与卷验收已完成。临时日志和一次性助手逐字节归档后清理；实际运行文件、任务输入、原任务XML及必要回退备份保留。
2. Windows/WSL DNS和系统CA信任、真实浏览器访问；准备具体恢复操作卡后另批真实Windows/WSL关闭/重启。当前任务执行时盘已挂好，不证明缺盘冷启动。
3. 单独维护批准后执行KIND删除重建持久化验收：保护原始kind与Harbor，核对全目录/全部镜像摘要并由新节点认证拉取。不能用当前启停通过代替。
4. 长期空间管理：统一查看/预览/执行，持续容量/告警、Harbor保留GC、构建缓存、日志/索引和备份轮换；删除政策先确认，保护在用/回退镜像及必要备份。只已有批准日志轮转自动运行。
5. 数据库/对象原文/私有输入完整备份恢复、机器外落点待所有者选定；安全门禁/官方修复跟踪、按需身份轮换、业务完整功能和云端建群实机验证仍未完成。
6. 最终清理与维护文档收敛；保护原始kind、新体系及所有者指定Luna参考。本轮未使用东京；不能泛删别人/tmp或原始代码/数据。

本次维护已批准：2026-10-05 13:13:01–15:13:01 UTC；截止epoch 1791213181，14:58:01 UTC后不开始新增动作，预留15分钟恢复。源/旧阶段UID/spec/Ready与149个受保护对象重新核对完全一致。

### 本窗口最终结果（2026-10-05 14:45 UTC 关闭）

执行者在操作卡第5步结束时断网退出，剩余由接手者在同一窗口内收尾；所有动作在14:58 UTC"不开始新动作"线之前启动。

已完成（操作卡1–5）：拓扑源e59bdc00/digest e26d2a19经原生platform-deploy OBJECT=all应用，47段recap全部failed/unreachable=0。旧根在第一次新源应用前撤销了旧阶段暂停；发现后核对原UID/Orphan并重新暂停，显式收敛logstash后188个对象全部归属26个新阶段。仅删除elk-runtime/platform-services两个控制对象，DeleteOptions带UID/resourceVersion前置条件和Orphan传播；无工作负载/卷删除。公开PostgreSQL deploy（10段）/check（2段）、Tpl-Web deploy（7段）/check（2段）、整套重复deploy（47段）全部failed=0。整套platform-check OBJECT=all首次在14:00 UTC失败：第7段对tpl-database阶段的Ready断言在整套重复部署刚结束时取到瞬时非Ready，verify.yaml:51断言无等待直接判失败；期间审计63阶段Ready、无异常Pod。14:40:35–14:43:53 UTC重跑退出0，10段recap failed/unreachable=0（两段changed=1为协议探针回执）。关闭前审计audit-144449.json：149受保护对象UID/spec无差异、无新增对象、63阶段Ready、无暂停、源摘要不变。

未执行（操作卡6–8）：Harbor admin与Casdoor built-in/admin实际轮换均未开始，三个人工账号密码与窗口开始时相同，Kibana不变，密码表当前值未改。Harbor改密前105个镜像条目和1090个registry/secret文件摘要仍私有保存可供下次使用。

证据：/mnt/sunmoon-data/backups/host/component-account-20261005T124637Z（root 0600），含topology-all、scope-*、topology-repeat-all、首次失败的topology-public-check.log（保留不覆盖）、通过的topology-public-check-rerun2.log、audit-*.json；topology-public-check-rerun.log是被中止的首次重跑残片，仅到只读阶段，无副作用。本轮86个/tmp助手脚本与审计JSON已复制到同目录maintenance-tmp-evidence/并逐文件SHA256核对（MANIFEST.json），/tmp原件暂留待所有者确认后清理。

后续：Harbor轮换仍需在线窗口执行；Casdoor轮换与其余账号预设并入新集群sunmoonai-kind冷建；verify.yaml的阶段Ready断言改为有界等待；T7聚合源码清理并入组件合并重构。

---

# 重构检查点（接手后，2026-10-05起）

目标不变：dev/prod parity，本机KIND与将来云端共用同一套组件声明与发布链；只参数化环境。顺序：A 阶段真源下沉到组件并合并services/applications → B make ci → C 环境参数化（去sunmoon-kind/:30443/nodeSelector硬编码，platform与providers/wsl-kind分层）→ D 冷建sunmoonai-kind并预置管理员口令 → E 切换入口、退役sunmoon-kind → F/G 轮换工具与文档收敛。每阶段结束才做一次flux-release+显式晋级；阶段内只做离线等价验证，不碰集群。

## A1 已完成：阶段图唯一来源为组件stage.yaml

31个对象各得`gitops/components/<对象>/stage.yaml`（62阶段，含26平台+36应用）；`infrastructure/components/stages.py`扫描成图并承接原选择算法；`components/topology.yaml`渲染/暂存/校验单一`gitops/clusters/kind/stages.yaml`，替代services.yaml+4个applications-*.yaml和common/backend/stages.yaml.j2；`services/layout.yaml`只剩命名空间与卷清单；`host/deployment.yaml`不再硬编码应用名与四个文件路径（应用名在applications/config.yaml）。

离线验证：渲染的62个Kustomization文档与HEAD五文件逐文档相等；47个OBJECT（含分组、模块、两个非法值）在select动作下选择JSON（三个列表字段按集合比较）、.mk与退出状态与HEAD完全一致，另抽5对象×deploy/stage/check一致；`required_stages`仍满足拓扑序；`services-render OBJECT=all`实际运行（575任务）75个公开声明与已提交相等，`application-render APP=knowledge`14个相等；6个剧本syntax-check通过；`make -n`对比只多出topology步骤。

## 所有者补充的范围（2026-10-05 23:20）

旧体系有而新体系缺的组件，在通用渲染器完成后按组件契约补齐：`ops-platform/pgadmin`（密码表14）、`ops-platform/redisinsight`、`ops-platform/flower`（依赖rabbitmq）、`ops-platform/mongo-express`（旧KIND默认关，沿用）；`relay-platform/relay`与`sandbox-platform/provisioner`（自研镜像，走应用构建链）。待所有者决定：`cicd-platform/jenkins`（旧KIND未启用、仅远程集群；新体系CI为make ci+宿主Harbor）。不加：`question-data-demo`（演示）、`utils/db-provisioner`（已由common/backend/database替代）。

有Web界面但新体系未暴露的组件，各加`ui`子阶段，沿用`elk/kibana/ui`模式（独立hostname、平台CA证书、IngressRoute、NetworkPolicy、入口SNI路由、组件自身账号）：RabbitMQ管理台（15672）、Neo4j Browser（7473）、AIStor控制台（9001）已按该契约写入gitops并`services-stage`；拓扑`gitops/clusters/kind/stages.yaml`现含`rabbitmq-ui`/`neo4j-ui`/`object-storage-ui`。Kibana原本已有。RAGFlow本fork的9380是自定义HTTPS API（`/sunmoon/ready`），不是库存Web UI，本轮不加。Traefik仪表盘默认关。不做：Elasticsearch API路由、数据库TCP直通到公共入口。

所有者更正：新集群管理员从一开始全部映射密码表。已打开 1/4/8/10/11/12/15a/15d/18/19 的 `table_import`；第8/11/19项用户名改为新体系现网名以便导入校验。导入只写首次预设，不覆盖 sunmoon-kind 已有身份。冷建 `sunmoonai-kind` 时首次初始化读取这些预设。应用账号2/3/5–7/9不映射；Jenkins 待组件接入。pgAdmin 第14项已随 ops-platform 接入。

验证脚本已接到`services/verify.yaml`（选中对应`*-ui`或 ops 控制台阶段时走集群入口端口做TLS/登录页/有界API核对）。尚未flux-release、未晋级、未`platform-deploy`、未应用宿主entry；浏览器不可用。Traefik CRD命名空间已加入`messaging-platform-dev`与`ops-platform-dev`（已改生成的`traefik/workload.yaml`）；完整`OBJECT=ingress-platform/traefik make services-render`依赖`services-chart`产生的`.build/components/chart-source.yaml`，本轮未跑chart以免动Harbor。

待办门：工作树gitops已与晋级对象e59bdc00不同，`platform-deploy`会被validate-release拒绝直到下一次flux-release+晋级；`platform-check`不受影响。

## A2 已完成切片：应用渲染并入通用组件渲染器

已抽出 `gitops/components/app-platform/common/backend/prepare.yaml` 与 `common/frontend/prepare.yaml`；四应用 backend/web/admin 的 `stage.yaml` 指向它们。加密路径改为 `.build/components/<object>/...`。`application-render/stage/validate-release` 转接 `services-render/stage`（`OBJECT=app-platform/<app>-app`）；`platform-stage OBJECT=all` 只跑一次 `services-stage`。`applications/deploy.yaml` 负责 plan/validate。

离线/等价验证：阶段图 65/34，12 条应用 prepare 入图；`render.yaml`/`deploy.yaml` syntax-check 通过；`make application-render APP=tpl` 196 任务 failed=0，26 个候选与已提交公开结构及 SOPS 语义全等；`APP=info` 250 任务 failed=0，34 个候选（含 storage/service-identity）全等。未跑 knowledge（provider 会访问 RAGFlow API）、未 stage、未 flux-release。

## ops-platform：运维控制台已完成切片

已按 Kibana UI 契约写入 `ops-platform/{pgadmin,redisinsight,flower,mongo-express}`：独立 hostname、平台 CA、IngressRoute、NetworkPolicy、入口 SNI；命名空间 `ops-platform-dev`。pgAdmin 映射密码表第14项（`table_import` 已写入首次预设，未改现网其他账号）；Flower 独立 basic-auth（无表行）；RedisInsight 无控制台登录；mongo-express 默认关（镜像锁未收录，未渲染）。Traefik CRD 命名空间已含 `ops-platform-dev`。foundations 增加 ops 命名空间/puller，并把 ops 列为 PG/Redis/Rabbit 客户端。

离线验证：阶段图 69/38（含禁用的 mongo-express）；`render.yaml`/`topology.yaml`/`verify.yaml`/`accounts.yaml` syntax-check 通过；`OBJECT=ops-platform make platform-account-import` 仅第14项 `preset_changed=true, live_account_changed=false`；`make services-stage OBJECT=ops-platform` 178 任务 failed=0（flower/pgadmin/redisinsight 候选入树，mongo-express 未渲染）；随后 `OBJECT=foundations` 61 任务 failed=0（runtime/network/kustomization 含 ops，新增 `ops-platform-dev-puller.sops.yaml`；既有三个 puller 密文载荷与 HEAD 相同，已恢复以免无意义轮换）。拓扑 68 个启用阶段，含 `pgadmin`/`redisinsight`/`flower`。未 flux-release、未晋级、未 platform-deploy、未应用宿主 entry。

## 应用 check 拆分、relay 与 sandbox（本切片）

`application-check` / `application-check-public` 改为 `applications/verify.yaml`；`deploy.yaml` 只保留 plan/validate。`deploy.yaml`/`verify.yaml`/`render.yaml`/`topology.yaml`/`services/verify.yaml` syntax-check 通过。

`relay-platform/relay` 已写入并 stage：独立 hostname `relay.sunmoonai.com`、平台 CA、IngressRoute、无 NodePort；镜像钉 KIND v1-r3 的 `app-images/relay` 摘要。`sandbox-platform/provisioner` 契约已写但默认关：现镜像把沙箱 NP 写死 `edge`，动态 Pod 不满足 restricted PSS，启用前须经应用构建链重建。foundations 增加 `relay-platform-dev`/`sandbox-platform-dev` 命名空间与 puller。

离线验证：阶段图 71/40（含禁用的 mongo-express 与 sandbox-provisioner）；`OBJECT=relay-platform make services-stage` 82 任务 failed=0；随后 `OBJECT=foundations` 67 任务 failed=0。拓扑 69 个启用阶段，含 `relay`，不含 `sandbox-provisioner`。既有 data/messaging/app 三个 puller 密文载荷与 HEAD 相同，已恢复。未 flux-release、未晋级、未 platform-deploy、未应用宿主 entry、未跑应用构建链。

所有者补充（2026-10-06，远程记）：「先上 Argo」= 冷建时直接用 Argo，Flux 侧不再加功能；A 段只做与控制器无关的部分（聚合源清理、入口收敛），重构后的 flux-release/晋级只在现网需要发新声明（第 10 步的应用）时做一次。

所有者决定（2026-10-06，远程记）：新体系由远程接着做完，本地由 Cursor 按 `sunmoonai/docs/dev-investment-agent/switch-test/inbox/` 的待办跑。主线改两处：**B 段的 CI 是宿主上的 Jenkins**（容器，调本目录的 `make` 目标，不进集群），不再是 `make ci`；**D 段冷建 `sunmoonai-kind` 之前把 Flux 换成 Argo CD，并趁机规范化**（组件改 Helm chart / Kustomize overlay 让 Argo 原生渲染，依赖改 sync wave / app-of-apps，晋级钉 Git 提交号，密文走 ksops；Ansible 只留宿主与建群）。Flux 在现网用到退役为止。parity 不变：一套声明，环境只差参数。详见 `sunmoonai/docs/dev-investment-agent/tree-build/decisions.md`。

所有者决定（2026-10-06）：mongo-express / sandbox 保持默认关；不重建 Harbor 自研镜像。Jenkins 再议：现网 Harbor 已是宿主模块，不是集群内 `cicd-platform`；本机 KIND 旧体系也未跑 Jenkins。冷建路径下 A 收口不必 flux-release/晋级/deploy；这三步只在 D 冷建 `sunmoonai-kind` 前做一次，且只发布到 Harbor、晋级环境源指针，不往现网 `sunmoon-kind` 部署。当前主线：A 离线收口（审阅/本地提交）→ B `make ci` → C 环境参数化 → D 发布晋级并冷建。

---

# 远程接手后的事实（2026-10-06 起）

- 分支：新体系已并入 `fable`，此后在 `fable` 上改、在 `fable` 工位跑；待办在 `sunmoonai/docs/dev-investment-agent/switch-test/inbox/`，结果在 `sunmoonai/scripts/results/`。
- 待办 18（2026-10-06 12:55 +0800，fable 工位）：工具装上（`.venv` 37M、`.tools` 481M），`platform-plan OBJECT=all` 退出 0；`preflight`、`platform-status` 退出 2——`/data/kind-clusters`、`/data/harbor` 两个 bind 不在，`sunmoon-kind` 三节点、Harbor、入口容器和旧 kind 两个 worker 都在约 4 小时前同时退出（255），API 27443、Harbor 30443 都没在听。**这是第一次真实 WSL 开机，单次开机恢复单元没有把平台恢复起来**（验收边界「未完成项」第 1 条的实际表现）。待办 19 先查它停在哪，再用 `platform-start` 恢复。
- 本地助手的接手说明（结果文件第六节）：A 段还没做的——聚合源清理、入口收敛、重构后的 flux-release/晋级/部署、`make ci`、环境参数化；`flux-source.yaml` 仍指 `e59bdc00`/`e26d2a19`，与 `fb55eced` 之后的工作区不是同一提交，集群起来后也不能直接 `platform-deploy` 这次重构；`platform-kind-v1` 工位里唯一没提交的是密码表；`services-stage` 这个名字还在但和 `platform-stage` 同一渲染器；foundations 的 prepare 会重加密已有拉取密钥，要按等载荷恢复；晋级的 revision 必须是 OCI 包对应的 Git SHA。
- 待办 19、20（2026-10-06）：第一次真实开机的失败查清了。登录时的附盘任务先 `wsl.exe -d Ubuntu`（启动 Ubuntu）再 `wsl --mount`，systemd 按 fstab 挂盘时盘还没附上；事后挂的盘只在 PID 1 的挂载命名空间里，用户会话（包括 `wsl.exe -d` 新起的）永远看不见。另外系统盘上留有 10 月 3 日的 `/data/kind-clusters/sunmoon-kind` 残留（52K 空目录），守卫因此拒绝绑定；已改名 `/data/kind-clusters.rootfs-stale-20261003`，没删。用 `sudo nsenter --target 1 --mount --` 进 PID 1 命名空间跑 `platform-start` 退出 0（4 分 15 秒），现网恢复：3 节点、63 阶段 Ready、57 Running Pod、13 PV。`platform-check OBJECT=all` 退出 2：工位阶段图比现网（源 `e59bdc00`）多 ops 控制台、三个 UI、relay 共 7 个阶段，等第 10 步发新声明时一起上。修法（待办 21）：附盘脚本先附盘再启动 Ubuntu；Makefile 在命名空间不一致时自动 `nsenter`；真实重启验收是待办 22。
- 待办 21、22（2026-10-06 13:48–14:05）：附盘顺序修好、运行副本和 Windows 任务重新发布、真实 `wsl --shutdown` 后平台自己恢复（`verification.md`「真实开机恢复」）。开机恢复这一条闭合；Windows 整机重启、删群冷建仍未验。
- `infrastructure/` 的收敛（所有者 2026-10-06 问）：现在不动。B 段和 Jenkins 一起做入口收敛、`applications/` → `build/`、检查并进 `components/`；D 段换 Argo 时渲染层整体换掉；`artifacts/` 不重构。见 0010 第九节。
- 待办 23、23b、24、25（2026-10-06 下午，fable 工位）：12 个应用镜像按 fable 源码构建并发布，锁进 `gitops/`（`7800e159`）；会合点、供给器镜像发布并暂存（`005bd0e0`）；info、investment 候选暂存（`ee6e0216`），四个部署计划核到 fable 的迁移 head。没过的：沙箱镜像 1200 秒超时且没留日志；会合点暂存因阶段图漂移拒绝；knowledge 暂存卡在供给器前缀断言。远程处理（`e3ce871f`、`0559d44d`）：组件镜像脏树检查只看自己的源码目录、构建日志边跑边落盘、超时按镜像配（沙箱 3600）、Debian 源随下载模式、组件镜像可各钉各的提交、knowledge 只读前缀放宽到 `info/`（供给 Job 代次 v2，容忍「策略已挂」）。收尾在待办 26。
- 待办 26（2026-10-06 16:22–16:46，三次续跑）：沙箱镜像按 fable 源码建成（76 秒，`platform/sandbox@…e758ccb2…`，钉 `e3ce871f`），供给器候选的 `SANDBOX_IMAGE` 跟着换；会合点再暂存无差异；knowledge 暂存通过（`domain.sops.yaml` 只有验签公钥、密文；供给策略前缀 `info/`、Job 代次 v2）；四个部署计划与 `platform-plan OBJECT=all` 退出 0。途中两处修正：Debian 源改 http（slim 基础镜像没有 ca-certificates，`86d8f6de`）；只引用签名密钥对的应用不要求 `private_dir/domain.yaml`（`7f756882`）。0010 第 0–4 步闭合；第 5 步（待办 27）等维护窗口。
- 待办 27（2026-10-06 晚，进行中）：核对、`pg_dumpall`（840K，6 库）、`flux-release`（候选 `b5b9658e` / `sha256:ba81d7d9…`）、晋级提交都过了。整套部署三次停下：1）fable 工位没有 compose（已改：部署前自动装，`145fe107`）；2）入口配置要加 5 个域名，部署链拒绝改活着的监听（按设计先 `entry-stop`）；3）**`entry-stop` 连带停了 Harbor 和集群**：统一目标 `Requires=` 三个服务，停一个传播成停目标，目标再按 `PartOf=` 停其余。Harbor、入口已用 `registry-start` 恢复；集群要 `platform-start` 拉回。目标模板已改 `Wants=`，重装在待办 28（27 之后）。
- 待办 27 续四（2026-10-06 17:40–17:57）：集群 `platform-start` 拉回（184 秒）；整套部署进到发布/调和段，根 Kustomization 等 10 分钟未 Ready：71 个阶段里 30 个未就绪。两个原因：1）pgadmin、redisinsight、flower 三个控制台镜像不在 Harbor（ImagePullBackOff），发布段没有发它们（原因待查，账 47）；2）四个应用的 redis Job 和 info/investment 的 service-identity Job 因后端镜像换了而撞「Job 模板不可改」（rabbitmq、identity 两种 Job 同样用后端镜像，阶段还没到）。处理：四种身份 Job 的名字像迁移 Job 一样带后端镜像摘要（`common/backend/{redis,rabbitmq,identity,service-identity}`、`applications/verify.yaml`），账 46。现网状态：旧包的应用仍在跑（`lastAppliedRevision` 仍 `e26d2a19`），新包部分对象已建、在等依赖；未退回。下一步：四应用重新暂存 → 发布三个镜像 → 再发布、晋级、部署。
- 待办 27 续五（2026-10-06 18:16）：四应用重新暂存（Job 名带摘要）。三个控制台镜像的本地归档从没下载过（ops 切片后加的，没走过 `services-materials`），`services-publish` 在「拒绝不安全的已有归档」退出 2。账 47 查清：整套部署里发布平台镜像那一段（`services-bootstrap`）排在 `flux-bootstrap` 的 `flux-source-apply` 之后，源一应用全部阶段就开始拉镜像，发布段根本没跑到。已改：`platform-deploy` 在 `flux-bootstrap` 之前先 `services-verify-materials services-publish`；缺的归档仍要显式 `services-materials` 下载（物料规则不变）。
- 待办 27 续六（2026-10-06 18:28–18:52）：三个控制台镜像下载、发布；第二次发布晋级（`68aeb0fd` / `sha256:60450a67…`）；整套部署后 71 个阶段里只剩 flower、pgadmin 两个 HealthCheckFailed，根阶段因此未 Ready（`lastAppliedRevision` 仍旧包，但子阶段都已应用）。四应用带摘要的身份 Job、迁移 Job 都 Complete；runner、relay、provisioner 1/1；tpl、investment 的 application-check(-public) 退出 0；info、knowledge 的检查失败是验证脚本找不到本工位的 `mc`（整套部署没跑到装它那步）。处理：flower 加 `command: [celery, flower]` 和 `CELERY_BROKER_URL`；pgadmin 给 `/var/log/pgadmin` 临时卷；`application-check(-public)` 先装 mc。
- 待办 27 续七、续八（2026-10-06 19:00–19:19）：flower、pgadmin 重新暂存，第三次发布晋级（`2a0f9993`，指针 `084a3085` / `sha256:5ffeae56…`），`flux-source-apply` 后 **71 个阶段全 Ready，根阶段 `lastAppliedRevision` 已是新包**。fable 的应用第一次在新体系上跑起来。检查：tpl、info、investment 的 application-check(-public) 退出 0；`platform-check` 与 knowledge 的检查各差一处工具问题（`platform-check` 的对象存储检查在装 `mc` 之前跑；knowledge 检查写诊断文件的 `.build/models` 目录不存在），已改，重跑检查即可，不用再发布。Git tag `release-20261006-1` 打在 `2a0f9993`。
- 第 7 步开始（2026-10-06 19:30）：所有者用 Casdoor 管理员登录成功（现网密码仍是初始密码，没轮换到密码表第 18 项；`platform-account-check` 报 `verified_login: true, password_changed: false`）。登记模型 key 报 `internal_error`：后端用 `cryptography.Fernet` 加密凭据，要 32 字节 urlsafe base64 的密钥，而机制生成的随机值是 40 位字母数字。已改：`domain_secrets` 的随机值支持 `format: fernet`；investment 的 `WORKBENCH_CREDENTIAL_KEY` 改为 fernet，要换钥（删主备私有文件和密文候选后重新暂存，账 48）。
- 待办 27 续九（2026-10-06 19:27）：只重跑检查。`platform-check` 卡在 RabbitMQ 管理台检查读凭据文件时少了一层 `service_credentials`（ops 切片写的、从没跑过）；knowledge 的领域检查在 investment-api 里跑 HTTP 检索校验器报 ModuleNotFoundError：fable 的 investment 后端已没有 HTTP 检索端口（改走沙箱 MCP），校验器删去这一段。两处都只改检查，不用发布。
- 待办 27 续十（2026-10-06 20:03）：investment 的凭据密钥换成 Fernet 格式并第四次发布晋级（`194ab597`，指针 `6bbac954` / `sha256:11bebe39…`，tag `release-20261006-2`）；investment、knowledge 的检查全过。`platform-check` 只剩 Neo4j 控制台：Jetty 回 400 Invalid SNI，原因是 Traefik 对后端的 SNI 是集群内名字而透传的 Host 是公网名字；已改 IngressRoute `passHostHeader: false`，下次发布时带上。
- 所有者决定（2026-10-06）：**边缘放东京服务器**（远程助手所在的云 VM，Ubuntu 24.04，2 核 3G，80/443/7000 空闲，有 Docker）。边缘（Traefik、会合点、frps）和集群里的 frpc 做成新体系的部署单元，排在第 7 步人手点通之后；域名与证书、机房上行仍待定。`docs/拓扑.md` 第一节是正式拓扑，第二节是现网过渡形态。
- 待办 27 续十一（2026-10-06 20:27）：供给器新镜像（带拉取凭据）第五次发布晋级（`aa8e2634`，指针 `72113bee` / `sha256:a6575451…`，tag `release-20261006-3`）。Neo4j 控制台改成不透传 Host 后仍 400 Invalid SNI。按 Jetty 12 的源码：它核的是 **Host 头与服务端自己证书的名字**（`x509.matches(serverName)`），Neo4j 内部证书的 SAN 只有集群内名字；透传时 Host 是公网名字、不透传时 Traefik 把 Host 换成 Pod IP，都对不上。改法：`component-tls.yaml` 支持 `tls_extra_hostnames`，Neo4j 控制台开着时把公网名字签进内部证书；路由恢复透传。现网要重签一次 Neo4j 证书（删主备 `public.crt`，私钥不动，Neo4j 会滚动一次）。
- 第 7 步进行中（2026-10-06 21:10）：key 登记成功、沙箱运行中、本地代理（Linux 版，在 WSL 里）连上会合点（`relay connected`）。查出一个没做的环节：**代理连上后后端不知道有这台机器**（账 49），「项目」页因此显示没有工作区；先用 CLI 手工登记继续点。另：WSL 里要把 `relay.sunmoonai.com` 加进 `/etc/hosts`、把平台 CA 拷到用户目录给 `NODE_EXTRA_CA_CERTS`；`pnpm approve-builds` 要批准 esbuild。
- 所有者决定（2026-10-06 21:20）：第 7 步剩下的（项目、工作、专家、数据目录、申请入库）**等账 49 做好再点**，不手工登记机器。到此已点通：登录、登记 key、拉起沙箱、本地代理连上会合点。未跑的轮次：续十二（Neo4j 内部证书加公网名字，`321f58f7`）、待办 28（统一目标改 Wants）。远程下一件：账 49。
- 账 49 做完（2026-10-06 夜，远程）：本地代理 0.2.0 的 hello 带机器名、白名单目录、上限（runtime `bdcdddd`）；会合点记住并在管理通道加 `agents` 查询（`a43473f1`）；investment 后端 runner 每 10 秒对一次账，登记机器、置在线离线（`d3ff9046`，全量 828 通过）。新体系这边：会合点镜像钉到 `a43473f1`、investment 源码钉到 `d3ff9046`、runner 放行到会合点管理口。现网验证是待办 29（重建两个镜像、发布晋级应用、所有者换新代理看页面）。
- 待办 27 续十二（2026-10-06 21:21）：Neo4j 内部证书加公网名字后控制台 200，Neo4j 项通过；第六次晋级（`9d0f126d`，指针 `cc7b2287` / `sha256:9edd08a3…`，tag `release-20261006-4`）。`platform-check` 下一项停在对象存储控制台「错误口令必须被拒绝」（校验器只认 401/403，实际状态码未知，已让失败信息带上状态码）。后面还有 pgAdmin、RedisInsight、Flower、会合点、供给器几项从没在现网跑过，和待办 29 一起探一遍状态码再统一修。
- 待办 29、28 通过（2026-10-06 22:16）：会合点与 investment 后端新镜像上线（晋级 `7bdb1be0`，指针 `357a2ff4` / `sha256:9c808c72…`，tag `release-20261006-5`），runner 日志 `machine sync starting`；统一目标改 `Wants` 后单独停入口不再连带。所有者换 agent 0.2.0 接入后，机器自动登记，能新建项目、能请专家。
- 第 7 步问数（600009 营业收入）回 dataset unavailable：知识后端的默认样例库不在镜像里，目录整个不可用（账 50，已改 `ee3b0b0c`，全量 952 通过）；另外新集群上还没有任何登记的数据集，600009 要先在 info 里走一遍采集 → 建数据集 → 登记。`platform-check` 剩对象存储控制台登录 500（账 51）。

