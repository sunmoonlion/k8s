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

后续：Harbor轮换仍需在线窗口执行；Casdoor轮换与其余账号预设并入新集群sunmoonai-kind冷建；verify.yaml的阶段Ready断言改为有界等待；T7聚合源码清理并入组件合并重构。接手后的重构方案另立检查点。
