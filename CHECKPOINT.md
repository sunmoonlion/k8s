# 当前优先状态：Redis首次维护通过，重启持久化验收待新窗口（2026-10-03）

工作树/分支platform-kind-v1，仅k8s，无push。实现f6817ba0，修正61b771b2aedd2032bbf6b2b2efdf8cd2e09c79ae、062b9b68；当前源sha256:84bcfc316cb46bcfabcf9c29254959643a57263e57b98209f48b993faf23c566。以下为最新状态，后文数据库单元是历史。

## 已实施与核对

- 所有者批准的首次10分钟维护始于2026-10-03T11:23:07Z，至11:33:07Z结束；已完成声明滚动替换，Redis从原PVC的/data/users.acl读取账号。原PVC/PV保留，其余26个原有Pod的UID及重启次数未变。
- tpl-redis-v2实际验证tpl_runtime账号写读、跨tpl:*前缀拒绝、管理命令拒绝和ACL SAVE；FLUSHALL仅ACL DRYRUN，没有执行。原生application-check另验证当前进程的真实账号认证。
- 原生application-bootstrap APP=tpl完整重复通过：render ok63、validate ok49、Flux apply ok24、check ok18，全部changed=0/failed=0；8个Flux阶段均Ready且同一摘要。
- 两处验收实现曾失败并已修复：ACL DRYRUN的权限拒绝可以作为普通字符串返回；Ansible原生模板中内嵌转义引号导致用户名带引号，改用YAML块标量。失败记录保留，不能称为首次全通过。
- 剩余窗口检查在第二次Pod删除前阻止执行，故尚未验证账号在创建后再次重启仍可用。原窗口不自动延长；需新的短维护批准。
- 已精确删除不再被Flux引用的失败Job tpl-redis-v1及旧ConfigMap tpl-redis-provision-v1。随后只读确认失败Pod已消失，成功v2 Job保留；不得直接删除受Flux管理的成功Job或机械加TTL。

## 下一步与边界

先按docs/platform-kind-v1/tpl-redis-maintenance.md的补充窗口复核容量和现场，再仅重建当前redis-0一次：PVC UID不变、Pod UID变化、ACL全文件摘要和0600权限不变、默认与应用账号真实认证以及键隔离通过。新窗口拟5分钟、失败恢复另5分钟，待批准；不重新发布声明。未批准不重启。

仍执行50GiB底线与原1GiB预算；最近检查计未来增长和预算后53,906,837,504字节，执行前必须复核。证据infrastructure/.build/applications/redis-unit-20261003/：window.json、before.json、bootstrap.log、bootstrap-v2.log、check-live-fixed.log、bootstrap-repeat.log、first-window-result.json。原始窗口记录保留；新窗口单独记录。仅有口令备份不等于完整数据恢复演练。

Redis持久化验收完成后才继续RabbitMQ独立身份/vhost、Casdoor注册、API/Worker/Scheduler及Web/Admin。尚无模板常驻业务Pod，应用未完整跑通；统一开机恢复、Harbor跨重启/重建持久化及长期空间管理仍是后续交付项。

---

# 当前优先状态：模板数据库与迁移通过，错误资源已清理（2026-10-03）

本节优先于以下历史。工作树/分支platform-kind-v1；本单元仅k8s，无push。实现提交128aaa66、命名空间修正08a7d9b1、晋级cd94bc87、验收解析修正e94171268ac665776c5b58acf7e9ee951f3b2cde。

## 当前实际结果

- 所有者已明确：所有应用统一使用环境 `app_namespace=app-platform-dev`；平台→应用→前后端组件的目录层级保留。Casdoor现归auth-app/casdoor，模板归tpl-app的三个组件目录。应用配置不另设namespace。
- 正式GitOps源为 `sha256:e2708f2ef172a55c85f291a436b209b30812d779e8d3e428c01e016c3828cdd3`，源码08a7d9b110d123345b600e4db499e1fb53ed1d23。7个Flux阶段均当前generation Ready、同一摘要。目录变更未改变原25个Pod的UID或重启次数。
- `data-platform-dev/tpl-database-v2`成功；`app-platform-dev/tpl-migrate-5b38d39836dc-v1`成功。tpl库使用独立tpl_runtime/tpl_migrator身份，迁移到20260911_0003。实际执行运行账号CRUD、拒绝DDL、拒绝修改迁移版本表；不是仅凭Job完成推定。
- 统一 `make -C infrastructure application-bootstrap APP=tpl`重复通过：render ok45 changed0、validate ok35 changed0、Flux apply ok24 changed0、check ok13 changed0。未重新建库或重跑已完成Job。
- 仍用常规50GiB门槛。最后按1GiB本批预算、计数据盘未来增长后余53,913,817,088字节，约50.21GiB；此前40GiB例外未使用。之后新单元必须重新盘点，不能拿此读数作为额外容量授权。

## 错误、修正和清理

首次SQL裸双美元定界符在执行中出错，v1初始化失败；更正命名空间并改带名字的定界符后v2成功。随后验收条件中的冒号被YAML解析成映射，改为解析最后一行JSON并核对schema/库名/独立身份/布尔结果，整条入口才通过。所有失败日志仍保存，未冒充首次成功。

所有者要求清理后，先枚举误建namespace的46种可列举资源，确认无Pod/PVC/业务数据并核对Flux inventory已不引用。现已确认删除Namespace/tpl-app-dev、遗留NetworkPolicy/data-platform-dev/tpl-postgresql、失败Job/data-platform-dev/tpl-database-v1及其两个Error Pod。namespace首次请求最后返回resourceVersion冲突，但随后确认namespace已不存在；按真实结果记录，未把非零退出当作完全无副作用。其余删除用准确UID前置条件。过期的独立puller候选密文逐字节比对后移除。

成功Completed Job仍是Flux期望对象；直接删除会重新创建执行，暂保留。禁止给这些受协调的一次性Job机械添加TTL造成循环执行；将来如需回收须先设计发布完成后的声明退役。原集群、Harbor、数据卷和必要备份未清理。

私有证据在 `infrastructure/.build/applications/database-unit-20261003/`：bootstrap.log（失败/中止）、stage-shared-namespace.log、bootstrap-shared.log（Job成功但结果解析失败）、bootstrap-repeat.log（完整成功）、before-pods.json、incorrect-namespace-inventory.json、incorrect-resources-cleanup.json、final-state.json（2026-10-03T10:57:38Z）。凭据与独立备份沿既定私有路径保存，不入Git。

## 下一步

按原顺序接入模板Redis ACL、RabbitMQ身份/vhost、Casdoor应用注册与运行配置，然后API/worker/scheduler、Web/Admin和业务链。当前尚无模板常驻业务Pod，不能声称整个应用跑通。其余实例、统一生命周期/开机恢复、Harbor重启重建持久化、长期空间管理、最终清理与云实机验证仍未完成；入口仍沿原路由，本单元没有切换。

---

# 当前优先状态：按所有者确认统一应用命名空间，数据库重试准备（2026-10-03）

所有者明确所有应用统一使用 `app-platform-dev`。应用层级只决定目录职责；命名空间来自环境 `site.yaml` 的 `app_namespace`，不再在tpl配置重复设置。独立数据库和角色保留。

首次已发布源码128aaa66（晋级25ec68a1），tpl-database-v1执行失败：`syntax error at or near "$" at character 4`，迁移未执行。SQL的裸双美元定界符在容器参数处理中不能安全保留，改用带名字的 `$bootstrap$`，Job显式升v2。错误尝试不算验收通过。

用户指出命名空间后终止本次客户端等待（退出-15；未终止Flux控制器）。模板改用独立tpl-runtime SA并复用foundations已有namespace、默认网络策略和registry-puller；不在两个阶段重复管理同名基础资源。移除应用独立puller密文。渲染和15根Kustomize检查通过；准备发布修正，暂未宣称恢复通过。

误建tpl-app-dev当前保留以供核对；修正协调完成后仅清除本次错误对象，先核对Flux inventory、全部命名空间资源及无卷/工作负载，不涉及Casdoor和旧集群。原始失败Job和客户端输出在infrastructure/.build/applications/database-unit-20261003/bootstrap.log。更新渲染stage-shared-namespace.log通过，仍用原凭据，未重新生成口令。

---

# 当前优先状态：应用层级纠正，模板数据库声明已准备（2026-10-03）

本节优先于下方历史。工作树/分支 platform-kind-v1，基线 d82f37c7cacd65b48f8a1d3e350e5ed199d8f804；本单元只改 k8s。所有者明确保留“平台 → 应用 → 前后端组件”，不把模板应用特殊化，也不另建平行的 gitops/applications。

- Casdoor 已归 `gitops/components/app-platform/auth-app/casdoor/`，原 database/init/主服务阶段保留；迁移前后16份非README文件逐字节一致，部署引用同步更新。目录移动不改变命名空间或资源身份。
- 模板归 `gitops/components/app-platform/tpl-app/`，其下分别为 tpl-backend、tpl-web-frontend、tpl-admin-frontend。应用共享开关和namespace在应用config；各组件config、image.lock.yaml、模板与说明同处。database/migration和后续API/Worker/Scheduler归后端。info/knowledge/investment后续遵循相同结构，尚未生成它们的运行声明。
- 原生 Make/Ansible 增加模板数据库 plan/render/stage/validate/check/bootstrap；准备独立运行/迁移身份、SOPS密文、初始化Job及独立迁移Job。仅文件候选已生成，尚未发布Flux源、执行Job或创建应用数据库；前端运行声明尚未实现。没有切入口或重启服务。
- 私有凭据已生成并逐字节备份，不得重生成或输出。根目录 /etc/sunmoon/applications/sunmoon-kind/tpl；备份 /mnt/sunmoon-data/backups/applications/sunmoon-kind/tpl。口令备份不代表数据库备份。
- 正常50GiB容量门槛，数据库单元1GiB预算通过准备检查；前序40GiB例外不沿用。私有证据 infrastructure/.build/applications/tpl-database-stage-2.log、tpl-database-stage-3.log；最新stage为ok10 changed1 failed0。第一次被空fileglob误判拦住，修正长度判断后成功，失败日志保留。
- services-render通过；层级纠正后的15个Kustomize根全部渲染成功、Ansible语法及git diff检查通过。运行层验收未做，不能声称数据库部署成功。部署前Pod身份快照在 infrastructure/.build/applications/database-unit-20261003/before-pods.json，不覆盖。

下一步：审查并本地提交声明 → 原生flux-release发布不可变源并晋级 → application-bootstrap APP=tpl → 检查独立Job、真实CRUD/DDL拒绝及既有平台Pod状态。随后继续Redis/RabbitMQ/Casdoor应用身份、后端角色和前端，最后业务链；新应用入口切换需另行确认维护窗口。部署路径已含tpl-backend，禁止退回合并目录。

规则对应：C-T2/T3单后端按角色部署，C-R1/R2/R3固定源码与镜像摘要并复用产物，C-D3/D8独立数据身份和迁移阶段。本轮未修改业务仓或推送。

---

# 当前优先状态：应用配套下载演练通过，四应用共用构建入口（2026-10-03）

本节优先于下方历史。本单元基线e14ae087，工作树/分支platform-kind-v1。所有者要求真实演练后统一新体系所有后端/Web/Admin，旧build-image.sh按退役计划处理；随后要求与家目录网络方案配合。本单元只改构建与说明，没有部署应用、改Flux源、切入口或重启服务，无push。

## 已实施与实际验证

- 共用原生Ansible build-network/build-attempt，默认国内直连，确认依赖下载网络失败才本次切官方源+HTTPS_PROXY并重试一次；无代理/不可达/重试失败均非零退出。编译、认证、TLS、签名、哈希错误不切源。工具仓 `/home/zymun/toolboxes/Vlinux/utils/set-up-tools/proxy-setting/网络管理统一方案.md` 已补“当前执行口径”，明确宿主代理管理与项目配套源选择职责、pip工具下载与uv锁文件地址两段、离线引导/在线应用边界、Fake-IP和CA限制；该文件现由Vlinux工具仓管理，所有者负责推送，不随k8s仓交付；2026-10-03已从家目录移动，~/AGENTS.md、工具仓README和本仓构建说明均指向新位置。
- Python实际演练先让国内pip连接失败，再官方代理pip安装uv0.11.32、uv冻结安装模板依赖、成功导入FastAPI；共2次构建。59锁包/624候选文件身份保留，不是下载所有624文件。前几次curl28/35失败保留；独立探测曾成功，最终演练成功，未证明家庭网络稳定或唯一根因。
- 修复合法uv锁中无size候选文件被误拒绝，size存在才检查而SHA256仍必需；helper失败时不再被changed_when的JSON解析错误掩盖。探测10秒连接/30秒总计，显示脱敏HTTP/远端/CONNECT状态；不关闭TLS。Python/uv的HTTP401/403/404也明确拒绝切源。
- tpl/info/knowledge/investment × backend/web/admin共12选择统一到同一build.yaml。APP参数选择，sources.yaml固定4父仓及12子提交；capacity_operation按app+component隔离。原生application-source-plan只检查干净源码、父gitlink/后代关系、实际配方及配置，不构建。12项实际均ok8 changed0 failed0。
- 镜像结果锁按完整组件仓名隔离，原模板三个锁经id核对更名tpl-*-images.lock.json，不留旧入口；三个模板重复发布均ok20 changed0 failed0，Harbor既有摘要不变，无需归档、不重复上传。
- 6份实例前端Dockerfile对齐已验证Node24.21.0固定Debian构建/精简运行镜像、保留Corepack签名，pnpm和业务锁不变；.nvmrc/README同步。只保留一条新体系构建入口，旧启动脚本没改。后端Dockerfile原有参数直接复用，无业务源码/数据库改动。
- 8项回归通过：5项Python投影（含四后端往返）、2项Make应用选择/非法选择拒绝、1项直接运行实际Ansible分类任务（9类错误输入）；Ansible语法、Python AST、YAML解析、git diff --check通过。

## 真实下载证据（均在infrastructure/.build/applications，不进Git）

| 批次 | 覆盖 |
| --- | --- |
| rehearsal-7347735a6fc9 | 国内成功1次、自动官方成功2次、代理未设/不可达均1次后退出；该批重试耗尽用例因代理探测失败未覆盖，下批补齐 |
| rehearsal-af95c969bf07 | 官方重试耗尽，2次后非零退出 |
| rehearsal-56ad07560b5c | 编译失败注入，1次，不切源 |
| rehearsal-bb96454ba03c | 完整性错误消息注入，1次，不切源；不是实际损坏包下载 |
| rehearsal-b316b15e32df | Python两阶段真实下载/冻结安装成功，2次构建 |
| source-plans-20261003 | 12源码计划和3模板镜像重复发布日志 |

更早rehearsal-38c48797677d官方下载成功但清理失败，不算整次通过；后续修复清理Buildx生成的auth子目录。Python的537be0a6efff（可选size误拒绝）、0cd324d7c6a4（fixture零重试隐藏网络原因）、7eddce520585/08614dadbe60/2d23f56b015e/f5355123bf4e（官方探测curl28/35）保留失败。测试只使用固定基础镜像、隔离上下文和未监听回环端口制造下载失败，不改宿主DNS/代理。

测试镜像标签及context/auth目录已按确切归属清理；缓存仍保留，不执行prune。每次小型演练预检512MiB、常规50GiB底线；真实业务构建仍按原4/6GiB预算。最终三次重复发布预留16MiB并计数据盘未来增长后余55,213,707,264字节，高于50GiB；不等于后续6GiB构建预算必然满足。之前40GiB例外未恢复。

## 本地子仓交付（父仓不提交未推送gitlink）

| 仓 | 固定提交 |
| --- | --- |
| tpl-web-frontend（前单元） | 0be8020ca14dc28123c8e212cf7f8f660ed16e99 |
| tpl-admin-frontend（前单元） | 9cce66c90d0b720867a318a45b4ca0c19adc1b16 |
| info-web-frontend | c7e19a41bb6eba03dc9a5021ee6de14f4e005922 |
| info-admin-frontend | 38d5b05aaca851a268f369b36bd4d2e7468b297b |
| knowledge-web-frontend | b1b45963723bdc9299bf3391afc8eeabab428927 |
| knowledge-admin-frontend | 0e1edbf534048518e03bc6654447dfce6cb9ac97 |
| investment-web-frontend | 745dfe697eca3d7aee746b782024d8f454f44c78 |
| investment-admin-frontend | ac58e290acba0822eef9ba84df9cf1387ca564d5 |

4父仓保持原提交，各有两前端子模块位置变化，是sources.yaml已固定的本单元/前单元本地提交，不要清除。交付须带这些子仓提交。规则对应C-T4/T5/T6及C-R1/R2/R3：不悬空父gitlink、明确跨仓来源、共用不可变产物发布。

## 下一步与未完成

网络策略接入及依赖演练完成，不等于12个完整业务镜像构建成功：仅模板原有三镜像已完整构建/发布；其余应用完整编译/运行未验。继续原部署顺序：模板独立身份/运行配置 → 独立迁移Job → API/worker/scheduler/Web/Admin → 业务链；再其余平台与应用。统一启停/开机恢复、WSL/KIND重启及删除重建Harbor持久化、长期空间管理和最终清理仍未完成，云上仍未实机验证。日常命令见infrastructure/applications/README.md。

---

# 前序状态：模板三组件镜像齐备，下载失败采用非交互回退（2026-10-03）

本节优先于下方历史。工作树/分支platform-kind-v1；本单元k8s基线41c8c16985254ddd70ae7ba89bc25d8178f30dd2。所有者最终确认：默认国内在线；依赖下载网络失败后，本次自动切官方源并探测HTTPS_PROXY，可用才重试一次，不可用或重试失败非零退出。无人交互、不改Windows网络、不改日常默认、Harbor直连。此前“失败只提示、禁止自动切源”的决定已被本条替代。

## 已完成与实际结果

- build.yaml扩展backend/web/admin并复用原应用Dockerfile；build-attempt.yaml是同一原生Ansible流程的单次尝试，最多调用两次，没有新增CLI/兼容入口。config.yaml、download-modes.json及Python临时锁地址选择与实现同处；模式配套切npm/Python和代理，保留依赖版本与哈希。
- 原生发布先核远端摘要；同摘要远端已存在时无需本地归档。应用归档仅在.build/applications/transfer暂存，发布并由独立puller核对后清理；基础引导物料不受影响。
- Web已在前一次官方源/代理构建成功，manifest sha256:7747a9fa70b49c2b1c6936c5a9e1e45afda48acd4b4e6bd6a241ef76e96f7293，Node24.21.0、nextjs。上传归档106,503,168字节已删除；不能拿它证明国内下载通过。
- Admin国内首次Corepack请求https://registry.npmmirror.com/pnpm/10.24.0失败。现场DNS返回198.18.0.72，直连连接超时；代理配置含fake-ip。所有者关闭代理后，同地址与清华Python源直连HTTP200、TLS校验通过、解析为真实IP。Admin随后完整构建ok43 changed15 failed0，固定pnpm安装与生产构建完成，Node24.21.0、nextjs。
- Admin manifest sha256:830a9e382927264850656694430b289404cfd2708ba402e3279785176e0961ec；上传归档106,353,152字节。首次发布ok35 changed2 failed0；默认50GiB再次发布核对ok20 changed0 failed0，没有重新构建、没有本地tar依赖。pnpm报告忽略@parcel/watcher、@swc/core、msw安装脚本，未放宽执行权限；构建通过不代表这些包的业务功能已验。
- 后端既有manifest sha256:5b38d39836dc6fe5e6d9d17eaa537d4ba52dd5db342dd95be0397e4c4e928ef0保留，本轮重复发布也确认不依赖上传目录中的tar；此前正式物料根中的后端归档暂未删除。

## 源码与交付边界

- tpl-app父基线3317c84d984fdd6dbeb4ab490685f9fcdff569a3不变；Web子仓提交0be8020ca14dc28123c8e212cf7f8f660ed16e99，Admin子仓提交9cce66c90d0b720867a318a45b4ca0c19adc1b16，均在本地platform-kind-v1且干净。只改Dockerfile/.nvmrc/说明，不改业务逻辑。backend仍6674125cd1c14d9700c707b0b0f4b5d422d42f05。
- sources.yaml显式锁定前端覆盖及其父gitlink。因不push，tpl-app不提交指向未推送子提交的gitlink；父仓两个子模块M是本单元已知位置变化，不清除。后续交付须带两个子仓提交。其他业务仓未修改。
- 最终自动回退编排在Admin成功后加入，只做YAML/Python静态解析及git diff检查，没有新建/运行测试套件或人为故障演练。自动回退、无代理退出、重试耗尽分支尚未真实演练；Python临时锁地址选择及最终编排下的后端重建也未运行。不能把先前成功结果扩大为所有新分支已验证。
- 镜像构建不等于业务上线：应用数据库/消息/Redis/Casdoor独立身份、迁移Job、API/worker/scheduler及前端运行声明仍待完成。Flux源、现有平台与旧应用入口未改。

## 预算与证据

Admin曾批准仅本批40GiB门槛/总新增最多6GiB，以minimum_remaining_bytes=50919301120限制累计增长。重试前按复用Node基础内容预留5GiB，扣未来增长与预算后51988549632字节；发布前扣归档预算55824043520字节。最后默认50GiB、预留16MiB时剩55693717504字节（约51.87GiB）。这些是不同时间与预算的读数，不当作准确释放量。active例外已删除，未把40写入日常配置；历史例外JSON仅是证据，不得重新套用。

17份日志/回执及摘要索引在/data/kind-clusters/sunmoon-kind/bootstrap/evidence/application-frontends-20261003，共137646字节。8份本轮/tmp日志逐字节对比归档后删除；构建context/auth/export/scratch由原生always清理，上传目录为空。未清理构建缓存、原始/新集群节点或卷，未访问东京。

下一步仍按顺序：模板独立身份与运行配置 → 独立迁移Job → 各角色与前端 → 真实业务链；随后其余平台/应用、整套一键/统一启停/开机恢复、WSL与KIND重启/重建Harbor持久化、长期空间管理及最终清理。云上实机未验。

规则：C-T4/T5不提交悬空父gitlink，跨仓明确提交；C-R1/R2来源和镜像摘要绑定；C-R3发布复用产物；C-D3/D8未来身份与迁移继续独立。日常操作见infrastructure/applications/README.md。

---

# 当前优先状态：模板后端镜像已构建并发布（2026-10-03）

本节优先于下方历史。所有者要求长期沿用“配置、实现、说明同处；共享字段单一来源”并继续部署。原则已加入AGENTS.md，仍在platform-kind-v1工作树/分支；本单元基线dba3766353413445f37c2918834c343a46115f87，仅修改k8s，无push。

- 原生cluster-status/registry-status/flux-source-status通过。现有平台命名空间与Flux源保持；未发布新GitOps源、未启动业务服务或切换应用入口。
- 基础镜像Python3.13.15-slim-trixie、Node24.21.0-trixie及trixie-slim已正式归档并发布Harbor，使用此前版本锁。prepare ok75 changed15 failed0；publish ok63 changed3 failed0。没有使用东京。
- 模板父仓3317c84d984fdd6dbeb4ab490685f9fcdff569a3与本地fable相同；backend6674125cd1c14d9700c707b0b0f4b5d422d42f05，web45ceed1a147cadb6dfd1b8a72b79ff5a266854bd，adminee1f542220386e15c8f97c6e40e317caf3c2e9e7均干净；未fetch、未修改四业务父仓或子模块。
- infrastructure/applications下config、sources、build和README同处。后端从已提交Git树导出，检查父仓gitlink/干净HEAD，复用应用Dockerfile并覆盖固定Python基镜像。实际运行版本Python3.13.15、用户appuser；构建ok37 changed13 failed0。
- 后端完整OCI归档82,363,392字节，manifest sha256:5b38d39836dc6fe5e6d9d17eaa537d4ba52dd5db342dd95be0397e4c4e928ef0。正式位置releases/platform-kind-v1/images/tpl-backend-<digest>.tar及JSON来源记录。发布到harbor.sunmoonai.com:30443/platform/tpl-backend，同摘要独立puller核对通过；初次发布ok29 changed1，重复发布ok21 changed0。重复构建manifest相同，不等于所有依赖已支持断网构建。
- services/materials.yaml移动为artifacts/publish.yaml；平台/应用基础镜像/新建应用镜像共用原生物料发布，不留转接副本。原services-plan ok3 changed0；第一次在沙箱内因Ansible家目录临时文件受限退出，提权后通过。
- 实际修复三个构建编排问题：Buildx token客户端未信任Harbor CA（仅构建进程SSL_CERT_FILE）；无capabilities的root无法写其他UID的0700输出目录（专属root目录）；只读skopeo的/var/tmp不可写（专属临时挂载）。未关闭TLS或重启Docker，未修改全局CA。
- 继续常规50GiB门槛，后端每次4GiB预算；最后构建预检计未来增长及4GiB后余57,839,878,144字节，发布重复预检计16MiB后余62,118,965,248字节。不同预算不能当成释放量。没有继承40GiB例外或清理缓存。
- 11份最小日志/回执在/data/kind-clusters/sunmoon-kind/bootstrap/evidence/application-backend-20261003，含SHA256索引。临时context/auth/export/scratch由always移除；本轮8份/tmp日志及1份草稿在校验归档后移除。正式镜像、物料、构建缓存与现有节点/卷均保留。

下一步固定顺序：模板前端构建适配 → 应用独立数据库/消息身份和Casdoor配置 → 独立迁移Job → API/worker/scheduler及两个前端 → 实际业务链验收。模板直接依赖PG/Redis/Rabbit/Casdoor已在新集群；Info需要的对象存储/ES排在其后，不应拿未运行的后端宣称应用已交付。

边界：Python依赖从网络按uv.lock获取，uv工具下载哈希及全离线依赖闭包未实现；前端Dockerfile仍引用旧Alpine且禁用了Corepack签名校验，需在业务源仓正确适配，不能只换基镜像参数。原应用入口仍转旧worker。整套一键/生命周期、开机恢复、重启重建持久化、长期空间策略与云实机仍未完成。
规则C-T3四角色一镜像、C-T5/T6本单元仅k8s/五仓并列，C-R1/R2构建绑定源码和摘要，C-R3发布同一归档不重新构建。没有新增/运行测试套件；实际构建、归档校验、镜像发布和git diff检查按部署范围执行。

---

# 当前优先状态：配置与实现归拢已完成（2026-10-03）

本节优先于下方历史。所有者确认这是一项覆盖整个新体系的原则，并授权实施。基线8927f27f35dbbe8c0a57b167355b48c67addec55，工作树/分支platform-kind-v1，仅k8s、无push。

- Casdoor代码集中在gitops/components/app-platform/casdoor（database/init/主服务），建库Job仍运行data-platform-dev，初始化和主服务仍app-platform-dev；没有数据迁移。
- PG/Redis/Rabbit/Traefik各自配置、模板、声明与说明同处。宿主、KIND、Harbor、入口、Flux和服务公共流程均有对应config.yaml。跨模块环境字段唯一存于environments/kind/site.yaml；版本锁和秘密位置不变。
- 非components补齐：host/registry/entry/cluster/flux/services六模块各自README覆盖全部38个config顶层字段，config旁加用途注释；environment README解释7项共享字段与源/公钥，artifacts/tools解释现有锁与安装参数。没有重复创建版本配置，没有改字段值或运行代码。本次只文档/注释，未运行测试或发布新OCI，现有gitops摘要保持。
- 追加字段边界核对：services.md逐项列出用户名/密码、固定内部端口、宿主映射及其他配置的修改条件。本轮只补说明；Casdoor域名/入口验收固定值、已有证书不自动重签、Casdoor卷node未贯通主服务/init、资源规格用户入口和统一凭据轮换均为未完成。不能把config.yaml存在等同于任意值可用；下方上轮目录归拢完成结论只覆盖已部署值不变。
- 原生Make通过明确CONFIG_FILES传递参数，无新CLI/加载器/兼容转发。make config列出真实输入；render引用同处模板，Flux只读取Kustomization显式列出的生成声明。
- 56项原配置值保持，12份输入无重复顶层字段；三份拆分数据模板生成对象与旧版一致；76个资源身份/内容保持，只有casdoor-db与casdoor-init的Flux路径变化。
- 29份Ansible原生语法、13个Kustomize根构建通过；services-render ok103 changed3 failed0，使用常规50GiB门槛。15个旧候选逐文件与Git基线比对后移动，保留密文，不重置凭据。
- 声明提交1de5f6bdbbc8cae55e02b2e27e1cd0087057ff8f，正式OCI摘要sha256:255728911c9e141b614fa55ac1b3d750dbe1c3ea711dc67f92bb6fd545fdb6f9。五Flux阶段当前generation Ready且应用同一摘要；七个Pod的UID/重启数与四PV的UID/spec均与发布前完全一致。原生release ok30 changed8 failed0；最终source-apply ok24 changed0 failed0；候选/解密内容校验ok119 changed0 failed0。
- 晋级首次失败于前次迁移的源摘要Update/Apply归属冲突。同名manager不代表同一操作归属；两次受保护预览未写入，最终只对原bootstrap已拥有的源字段做一次性带UID/resourceVersion约束的SSA接管，只有新摘要改变，其他spec与其他管理者归属保持。原生入口未增加force或通用恢复代码；旧操作卡纠正，失败日志保留。
- 边界：无新组件/版本、停机/数据删除、业务入口切换、旧集群操作；长期空间管理与生命周期缺项未由目录整理完成。服务公共凭据/加密仍集中复用，不为目录形式复制共享实现。
- 证据在/data/kind-clusters/sunmoon-kind/bootstrap/evidence/config-colocation-20261003，25份临时脚本/日志逐字节归档并记录SHA256后从/tmp移除，另清理本轮pyc与空Ansible临时目录。它们不是部署依赖。长期原则见architecture.md，各模块README和services.md说明日常方法。

规则对应：C-T5/T6仅自己的k8s分支，五仓并列；C-D3原独立库与Secret保持；C-R1/R2发布依旧从已提交Git对象构造固定摘要OCI。未运行新增测试套件；语法、渲染及发布前结构核对是本单元原生检查，业务链路验收仍沿用既有范围。

---

# 当前优先状态：目录与命名空间迁移完成（2026-10-03）

本节优先于下方历史。新部署根是 `infrastructure/`，旧 `platform/` 路径及旧GitOps services分类已退役，无转发入口。工作树/分支仍为platform-kind-v1，只改k8s、无push。基线c49dc6e430ba1c4db0eafeac341f3a9ad6757e02；目录准备87a248be1507d2e59030a8e4fed59d1b437c9da1，初始新声明947ee03a1a4b5743d94b608734d358a776d128d7，Rabbit修复声明447fceddf6eb8416bd5a475ef6d6fef6d1ca3e99；最终实现见HEAD。

- Casdoor在app-platform-dev，PG/Redis及Casdoor建库Job在data-platform-dev，Rabbit在messaging-platform-dev，Traefik在ingress-platform-dev；Flux保持flux-system。platform-system只留引导基础，ops没有组件时不创建。
- 最终OCI源sha256:9d231384742cc015f19793f7748117871cd154d3895af4e454cb1aa0cf7a12f0，五Kustomization及HelmRelease当前generation Ready。五常驻服务Ready、零重启；两个Job完成；四PV Bound/Retain、原PV UID与宿主路径保留。Kube-system UID仍67d27d4a-f9ad-4f01-a37f-225144cacaef，kubeconfig ~/.kube/sunmoon-kind.config，kubectl在infrastructure/.tools/bin。
- 所有者明确批准20分钟维护、失败恢复另10分钟、四旧PVC对象保数据重绑定及40GiB/新增最多1GiB例外；898秒内取得协议通过回执，没有运行回退。容量例外已撤销，归档参数标记过期；最终统一入口按默认50GiB完整通过。
- 冷归档71,198,720字节，SHA256895b072a527e2d65f8c19e6d321ad35a5c3f3d07075cd694f01fd9992de96c4e；独立解包的1,619项内容/权限/属主与冷源一致。不是独立数据库业务恢复演练；原数据重绑定后真实登录与读写通过。保留tar及证据，临时解包副本核对后清理。
- 修复了Rabbit已有cookie被fsGroup变成0660（现在每次init校正0600且比较值）、渲染器重复重置卷根权限、临时patch的source摘要字段管理冲突、原生无diff apply未等待当前摘要、旧Ingress与新Ingress同域名造成503。失败日志与修正结果均保留。Rabbit内部持久节点名不改，单节点hostAliases解析自身，客户端只用新namespace Service；未来多节点需要另设计发现，不能复制回环映射。
- 原生services-bootstrap九段failed0；配置/秘密/声明无持久变更，chart临时目录changed2、验收回执changed1。services-check通过PG事务、Redis键、Rabbit管理API消息路由/取回、Casdoor TLS登录/会话，以及app→PG DNS和有/无客户端标签的允许/拒绝。探测Pod均精确清理；AMQP业务客户端仍未验。
- 旧同域名Ingress、四旧PVC及两旧Job退役后，另逐对象核对归属/UID清理27项，删除已核空的ingress-system；清理后再次验收通过。Harbor十容器healthy，两宿主systemd active，原kind控制面停止、两worker运行。30443业务路由仍原worker，新Casdoor仅以connect-to回环29443验收，未切换正式应用入口。
- 04:39:10Z扣数据盘增长与16MiB后预留61,735,886,848字节，约57.49GiB。C空闲增加来源未查，不计成本轮释放量；本轮临时冷备份+解包已识别峰值约134MiB，归档自身约68MiB，物料版本/节点镜像缓存复用。后续每单元重新预算，不继承例外。
- 最终引用审计另修正credentials.yaml的旧Secret路径；原生credentials默认50GiB重复运行ok21 changed0 failed0。25份临时脚本/日志逐字节归档后删除，两个/tmp目录和已核对的冷备份解包副本删除；冷tar保留，active容量例外不存在。
- 证据：/data/kind-clusters/sunmoon-kind/bootstrap/evidence/namespace-layout-20261003，协议最新回执相邻services/latest.json。日常入口/配置见docs/platform-kind-v1/services.md，迁移结果和经验见namespace-layout.md；Ansible入口已用缓存重建，旧绝对路径不再依赖。

下一步回到原顺序：模板应用依赖及剩余平台组件 → 业务应用链 → 完整一键/生命周期/开机恢复 → WSL/KIND重启、删除重建Harbor持久化 → 长期空间管理与最终清理。全部业务跑通、服务级灾备/机器外备份、云端实机均未由本轮完成。规则C-D3保持独立库/身份，C-R1/R2提交与不可变OCI/image一致，C-T5/T6五仓并列、本轮只改k8s。

---

# 新部署体系交接

## 当前状态：首批数据、入口和身份服务完成（2026-10-03）

本节优先于下方历史现场。继续在 `platform-kind-v1` 工作树，只改 k8s、无 push；本单元基线 `7f535709c17a6c9a2b74c189e263f8c1f40c4ca8`，当前实现提交见 HEAD。操作见 [首批平台服务](docs/platform-kind-v1/services.md)。

- 所有者仅为本批 Traefik、存储、PostgreSQL、Redis、RabbitMQ、Casdoor 批准40GiB门槛、最多新增5GiB。默认50GiB始终未改；本批结束撤销临时参数，后续单元不能沿用。
- 实际源：`sha256:bbf06e3c5cf779e394c7eece654c3361e8b4632356b029900ad785fd06e8a438`，声明提交 `7468cd01d939e10dc612f81a0e5cbb780b3dc2d7`。根与四个子Kustomization、Traefik HelmRelease均Ready。
- Traefik3.7.13/chart41.6.0，PostgreSQL18.6-trixie，Redis8.10.2-trixie，RabbitMQ4.3.6-management，Casdoor4.12.0：五个服务Pod Ready、零重启，两初始化Job Complete；实际imageID均匹配锁定的Harbor manifest。Helm4.3.0的包、成员摘要已锁定；chart从官方索引校验SHA256，发布Harbor后完整拉回字节一致。
- 四个静态PV/PVC Bound、Retain、显式节点亲和性。新组件数据根分别在 worker/static/{postgresql,casdoor}、worker2/static/{redis,rabbitmq}，当前数据约65.65MiB。PVC声明15GiB不是即时物理分配或目录限额。
- 六项原配置字面字段一次性导入新的root0600输入；新Casdoor管理员独立生成。运行入口不调用旧配置/脚本。输入和TLS在 `/etc/sunmoon/services/sunmoon-kind`，独立数据盘副本在 `/mnt/sunmoon-data/backups/services/sunmoon-kind`；SOPS密文入Git。备份丢失且环境已有声明时拒绝重新随机生成口令。机器外副本和数据一致性备份仍待后续落实。
- `services-bootstrap`完整重复执行九段全部failed0；材料、工具、私有输入、声明生成/比较、Flux均无持久资源变更，仅chart临时工作目录及验收回执写入。最新强化的 `services-check` 为ok28 changed1 failed0：PostgreSQL事务读写、Redis临时键读写删除、RabbitMQ管理API真实发布/取回、Casdoor经新TLS入口的管理员登录和会话核验全部通过。Rabbit检查不是业务客户端AMQP全链路验收。
- 新应用入口仅验宿主回环29443，TLS域名仍casdoor.sunmoonai.com:30443，curl connect-to保持SNI/Host。正式30443应用分流仍指原worker；原kind控制面停止、原worker运行，新三节点Ready，新Harbor/入口active。没有停旧应用或切换入口。
- 实际修正：Traefik新chart日志键为log/accessLog，versionOverride在根；Casdoor导出模式不导入init_data，改隔离初始化服务成功后持久标记，正式服务不重复导入；RabbitMQ4.3默认禁止非持久非独占队列，验收用durable classic+TTL，未开废弃兼容开关。候选路径规范化、YAML跨阶段解析、字典values字段检查的失败同样保留记录。
- 03:34:48 UTC容量：C空闲114,329,325,568字节，数据盘未来增长66,936,897,536字节，再扣16MiB验收预算余47,375,650,816字节（44.12GiB），仍未达常规50GiB。识别的归档+仓库+节点压缩/展开内容、Helm工具和初始数据估算2,807,963,623字节（2.62GiB），未扣共享层/复用硬链接；不是整机df严格差分，文件系统元数据/无关写入不在此估计内。容量门禁另外限制相对本批开始的增长余额，未触及5GiB上限。
- 证据：`/data/kind-clusters/sunmoon-kind/bootstrap/evidence/services/latest.json`；本批成功/失败日志与文件摘要归档在相邻 `services-20261003/`。仓库不存运行日志、私有输入、口令或密钥。临时材料清理后正式离线包保留。

规则核对：C-D2/D3为Casdoor独立库/角色/Secret；C-R1/R2以提交和固定OCI/image摘要发布；C-T5/T6五仓并列、本单元只改k8s。第三方Casdoor仍有官方内置schema初始化，本期没有声称业务应用C-D8迁移链已完成。

**下一步按原顺序**：核对模板应用依赖、补齐剩余必需平台服务与应用构建/声明，再业务链路；随后全平台一键/统一启停、开机恢复和Harbor重启/重建持久化验收、长期空间管理与最终清理。当前对象存储和业务应用尚未部署，AMQP客户端、OAuth应用注册、etcd静态加密、数据库一致性备份、云端实机均未由本单元覆盖。新批次先准备依赖和容量计划，不继承已撤销的40GiB例外。

## 前序状态：SOPS 与平台基础声明已实际部署（2026-10-03）

本节优先于下方历史进度。仍在 `platform-kind-v1` 新工作树开发，只改k8s，无push。Flux实现已本地提交 `54a7b1dd`；基础声明提交 `4a993aabed47cd4565887f1b18321da4ab21b9f2`，实现与验收提交见本分支日志。日常入口见 [SOPS与基础平台](docs/platform-kind-v1/secrets-foundations.md)。

- 实际源摘要已提升至 `sha256:19f2aa4849577eb383263727e32d8d110c2967f6d545e6bdf56a8dc0e1c1255b`。三节点Ready，Flux四控制器及源/根协调Ready；基础平台包含restricted命名空间、默认禁API令牌的服务账号、LimitRange、默认拒绝与DNS放行网络策略。
- SOPS3.13.3/age1.3.2来自已锁定本地包，原始物料未搬走。主解密身份在 `/etc/sunmoon/flux/sunmoon-kind/age.agekey`，独立副本在 `/mnt/sunmoon-data/backups/flux/sunmoon-kind/age.agekey`，root0600/目录0700；Git只有公钥与密文。机器外副本、etcd静态加密尚未落实，不声称完成灾难恢复或完整安全基线。
- 只读Harbor凭据由Flux实际解密并创建。验收对照备份解密结果、实际Secret和kustomize-controller字段所有权；临时非root Job通过Always认证拉取、指定imageID、集群DNS、无API令牌挂载及跨命名空间TCP拒绝，ok24 changed4 failed0；专属Job/Pod已清理。
- 实际暂存主密钥，由 `secrets-prepare` 从独立备份恢复，逐字节一致后移除临时原件；原生恢复ok40 changed1 failed0。不是仅做目录/摘要检查。没有停Harbor或集群服务。
- `make foundations-bootstrap` 整段重复执行五段ok21/18/39/34/26，changed0、failed0。根发布标记不变；SOPS关闭时拒绝requires_sops源，避免以无解密配置破坏既有声明。
- 三次检查问题均保留记录：候选文件误写字面换行，已修正；公钥注解JSONPath转义导致读空，改读注解map；kubectl默认省略managedFields，验收显式请求该字段。密钥未重新生成，没有以失败记录充当成功。
- 证据在新集群 `bootstrap/evidence/foundations/` 与 `bootstrap/evidence/sops-foundations-20261003/`。运行日志含失败及通过记录，秘密不入Git，临时工具参数在结束时撤销。
- 本次所有者只为SOPS/基础声明授权40GiB、预算256MiB，没有部署数据库或新常驻应用。新增工具及解包副本已识别占用74,207,232字节（约70.77MiB）；声明与验收记录另占少量空间。02:43 UTC整机容量读数计数据盘未来增长后余49,212,723,200字节（45.83GiB）；50GiB默认规则未改。整机VHDX/Windows变化不能等同于本单元文件增量；后续大组件必须重测并确认容量安排。

**下一步**：先按已选版本准备入口/数据与身份服务的声明及容量清单，再实际部署，随后应用链路；全平台一键、开机顺序、重启/重建持久化、长期空间管理仍按此前顺序收尾。此前40GiB例外不延伸到下一单元。

## 前序状态：Flux 引导与实际协调完成（2026-10-03）

本节优先于下方历史现场。目标为 `sunmoon-kind`，kubeconfig `~/.kube/sunmoon-kind.config`，工具 `platform/.tools/bin/{kubectl,flux}`。原生操作见 [Flux 操作](docs/platform-kind-v1/flux.md)。源码基线为 `37eaf574b26d9fc5d21ffc97332260e42e2cf887`；首批声明提交 `3ace2fdec6b9b04d69f2672f7ba225c4ad95497c`，实现提交见 Git 日志，无 push。

- 新集群三节点 Ready/v1.36.5；新 Harbor 十服务 healthy、入口 active。原 `kind-control-plane` 已按本次批准停回，原两个 worker 保持运行，继续承载过渡应用入口。当前 Docker 节点仅原 `kind` 与新 `sunmoon-kind`；下文 main/136 的保留记录属于历史状态。
- 三个宿主镜像副本（prepare、exporter、skopeo）缺失，已由完好的正式离线物料补回；没有证据指认具体清理命令。OCI 匿名导入的工具执行改按锁定 manifest digest 查找，避免依赖不存在的仓库别名。
- 30443 入口恢复及真实认证推拉通过；Harbor SNI 指向 11443，其他域名仍指向旧 worker。应用证书摘要与恢复前一致，只证明 TLS 入口身份，不代表业务验收。
- Flux CLI 2.9.5、四个配套控制器 Ready。控制器归档已验证并发布 Harbor，OCIRepository 与根 Kustomization 当前 generation Ready。根源 `oci://harbor.sunmoonai.com:30443/platform/deployments-kind` 固定摘要 `sha256:0d905e584d24f4692502d00a59363fa4e3141bd56ba2897929ccaaf05e7eb640`；实际创建平台命名空间与发布标记。
- 最终 `make flux-bootstrap` 五段均 failed=0、changed=0（ok22/29/50/41/25）；声明受控偏离后实际恢复；三节点私有拉取/DNS验收 ok36 changed6 failed0，临时验收资源已移除。过期容量例外和错误集群目标均在写入前拒绝。没有新增测试套件。
- 首次控制器安装失败原因：节点重启后 `/etc/hosts` 中 Harbor 映射丢失；已通过原生 cluster-deploy 恢复，Flux 前置检查现会识别该条件。**自动重启后的持久修复仍待生命周期单元，不以本次就绪替代重启验收。**
- 运行证据：`/data/kind-clusters/sunmoon-kind/bootstrap/evidence/flux-20261003/`，包含入口、首次失败、修复、重复部署、漂移和负向检查，文件清单带 SHA256。秘密不入 Git。
- 02:08 UTC 容量：Windows C 空闲116,758,441,984字节；数据盘未来增长66,970,451,968字节；计增长后余49,787,990,016字节（46.37GiB），**未达到常规50GiB**。本单元结束删除 Harbor/Flux 临时40GiB参数；站点默认50GiB一直未改。下一单元不得继承此前例外。
- 东京两个历史下载目录尚未删除：后续 SSH 超时；保留旧 cloud 参考目录。总体清理、原 private 逐项核对尚不能宣称全部完成。

下一步严格依序：SOPS/平台基础声明 → 数据、身份及应用 → 全平台一键与生命周期/开机编排 → WSL/KIND重启与KIND重建持久化验收 → 长期空间管理及最终清理。SOPS、本期平台应用、开机自动恢复、重建持久化和云端实机当前均未完成。

规则核对：C-T5/T6 保持五仓并列，本单元只改k8s并本地提交；C-R1/R2 以提交及OCI摘要发布，镜像固定digest；C-D9/C-I类秘密只经私有文件或Secret引导，本单元不发布业务秘密。

## 2026-10-03 恢复前盘点（历史记录）

所有者要求本单元先复核清理，再继续 Flux。已只读核对：`/data/kind-clusters/.rebuilds` 不存在；新物料锁中的 24 个文件（files/bootstrap/host）大小与 SHA256 全部匹配，官方 Harbor 解包文件 6 项摘要通过，KIND/kubectl/kubeadm/Compose 已安装工具摘要通过，三个 sunmoon-kind 节点 ID 与建群回执相同，两类持久目录挂载保留。SOPS 安装包存在且摘要通过，尚未安装到 .tools/bin；Flux 尚未部署。没有发现上述物料被清理误删。

东京只读复核：六个已知目录中四个不存在，`/home/zym/trivy-db-20260927-v1`（约1.1 GiB）和 `/home/zym/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64`（约909 MiB）仍存在；新 platform 与设计文档没有运行时引用这些目录。本地 `legacy/cloud` 按所有者要求保留参考。此前清理总额仅为历史估计，不能当成此次 df 实测增量。

本次 WSL 启动后出现未完成的启动编排问题：旧 kind-control-plane 正在运行并占用宿主30443；新控制面因 systemd/cgroup scope 创建错误退出128，两个新 worker 运行；新 Harbor/入口 systemd 单元 inactive，此前明确未启用 boot。容器与数据仍在。此记录不把启动失败归咎于清理，也不把历史 Running 当作当前健康。

**所有者确认的最终交付要求**：旧集群默认停用、按需人工启动；确认数据盘 UUID/绑定与 Docker 可见后启动新 Harbor、新集群和入口，规定失败重试及报错；实际做 Windows/WSL 重启验收，验证原集群不抢端口、新集群自动就绪、Harbor 数据/镜像摘要完整和节点真实拉取。另做 KIND 删除重建持久化验收。当前只记录要求，开机编排尚未实现/验收，不能宣称已完成。

部署主线继续保持 Flux → 平台/应用 → 统一生命周期和开机顺序 → 重启/重建验收 → 长期空间管理。服务恢复与 Flux 实施结果须据实际更新。

## 目标、工作区与授权

从零建立长期维护的部署代码，第一期KIND，原生Make/Ansible、官方Harbor Compose、KIND、Flux/SOPS；不调用旧sunmoonai/utils/luna部署链。五仓在 `/home/zymun/worktrees/platform-kind-v1`，各自分支platform-kind-v1，从本地master建，基线见[输入盘点](docs/platform-kind-v1/inventory.md)。原luna仅参考。

已确认采用新版本、不迁移旧业务数据/旧 Harbor 镜像，应用可以修改重建，业务 Python 3.13.15。旧 `kind`、`sunmoon-kind-136`、备份与他人 local-integration 受保护；`sunmoon-kind-main` 和旧 18443 Harbor 已经所有者决定退役并于 2026-10-01 删除。日志3×20MiB已批准，其他删除策略仍须具体决定。本轮只改k8s，四个应用仓均干净，无push。

前序提交：独立Harbor `f3573d511c78cb9b68cc7f4605ef151896f7321b`、节点构建 `e280a3850953584853a4717945a8183baf18e5ec`、离线镜像 `eef098e272932a0ac3e279bfc002e1ea0ef1b9a0`、入口/认证及Docker物料 `c1917447b814884b5b32d81ddc08ceb42daf0b93`、失败与恢复记录 `b3c44e1e30a0ca566b5b8addabcb2ff08da1e1a3`。当前交付提交见HEAD，最终须报完整SHA。

## 后续维护：删除 sunmoon-kind-main 与旧 18443 Harbor（2026-10-01）

所有者认为无用的旧主集群及其 Harbor 可删除。只读盘点确认 `sunmoon-kind-main` 没有业务 Pod、PV/PVC 或 Harbor 工作负载；三个节点目录下的 static/local-path 数据目录均为空。KIND 官方命令删除了这个精确集群的三个节点、对应 `/var` 卷和上下文。节点卷原约8.4 GiB。数据根 `/data/kind-clusters/sunmoon-kind-main` 不存在。

该集群里没有“对应 Harbor”。经实例名、端口和卷路径核对，所有者所指旧外置实例按 18443 项处置：`sunmoon-harbor-cutover-20260930-v1`，仅回环监听18443，registry目录约17 GiB；八个专属容器和两个专用网络均已停除，再删除该实例的精确目录。此前 Docker Compose 留下一个未启动的 Created jobservice 容器，另行按其精确项目名删除。18443现已无监听。

**新 Harbor 未删**：独立 `sunmoon-registry` 仍在127.0.0.1:11443，正式入口30443健康，10服务healthy，数据目录 `/data/harbor/platform-kind-v1/data` 约3.0 GiB。保留旧 Harbor 的冷备份、`/data/harbor/backups`、其它 Harbor 实例、候选及 `sunmoon-kind-136/harbor-restore-20260926` 中副本0且PVC/PV仍Bound的恢复演练。没有清理其它旧节点、卷、PV或备份。

删除前 `/data/harbor/instances` 约130 GiB、数据盘Avail约72 GiB；之后实例目录约113 GiB、数据盘Avail约90 GiB。释放的约17 GiB实例层和8.4 GiB节点卷容量已回到WSL各自文件系统，但 VHDX没有压缩，Windows上的VHDX分配大小不会等量下降。11:50检查 C 盘空闲121,495,732,224字节；计入230 GiB数据盘长满后的剩余为54,525,280,256字节（约50.78 GiB），高于50 GiB底线约0.78 GiB。剩余空间很紧，应用平台部署前必须重新测算预算。

最终集群列表为 `kind`（旧控制面仍停止）、`sunmoon-kind-136`、`sunmoon-kind`。新 `sunmoon-kind` 三节点Ready；新Harbor正式健康接口返回healthy。应用入口未切换，旧 main 的80、19443、30444–30446与17443端口映射已随节点删除释放。

## 最新现场：sunmoon-kind 建群与三节点拉取通过（2026-10-01）

本单元基于 `b27046183f39190da1411d96c966d1c5adafb913`，提交见 HEAD。所有者明确指定新名称 **sunmoon-kind**。操作与完整边界见 [新 KIND 集群](docs/platform-kind-v1/cluster.md)。

- 原生 Make/Ansible 新增 cluster-plan/deploy/status/pull-check；官方 KIND 建群、containerd 离线导入、Kustomize CNI；没有调用旧代码或增加统一 CLI。
- 三节点 Ready/**v1.36.5**，Calico3.32.2，14基础 Pod Running/Ready；API127.0.0.1:27443，预留入口127.0.0.1:29443，Pod10.247/16、Service10.99/16。kubeconfig `~/.kube/sunmoon-kind.config`，kubectl `platform/.tools/bin/kubectl`。
- 数据 `/data/kind-clusters/sunmoon-kind/<role>/{static,dynamic}`，分别挂静态固定路径与 local-path 动态路径；真实 bind 和 device/inode 比对通过。kube-system UID `67d27d4a-f9ad-4f01-a37f-225144cacaef`，所有权回执在其 bootstrap/identity.json。
- 最终重复部署 **ok80 changed0 failed0**；三节点私有拉取+受限容器运行+内外 DNS 验收 **ok32 changed6 failed0**。镜像manifest `5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`；成功回执 bootstrap/bootstrap-pull-rhc28.json，临时 namespace/Secret 已删除。
- 实际修正：OCI匿名导入名导致 containerd checkpoint检测找不到引用，正式导入改显式完整 --base-name，本次新节点别名/CRI索引已修复；CoreDNS生成的字面换行改为多行变量。初次无缓存拉取成功但DNS Job失败，第二次Always拉取复用缓存后完整成功。不得声称修正代码已完成删除重建冷建验收。
- 新建群前 main/136 六节点曾Ready；main及其旧Harbor随后按所有者决定删除（见后续维护记录）。`sunmoon-kind-136`仍在，旧`kind`控制面保持停止、两worker运行；新Harbor10服务healthy，应用入口仍未切换。
- 11:50Z计230GiB数据盘长满后C仍余55,029,702,656字节（51.25GiB）；仅1.25GiB额外预算空间，下一阶段须重新预算。全部运行证据在 bootstrap/evidence 与 verification-20261001.json。
- 下一步顺序仍是 **Flux→平台/应用→整套入口与启停→重启/删除重建持久化验收→长期空间管理及最终清理**。开机顺序、独立冷建复现、企业生产安全门禁和云端实机均未完成。本轮未新增/运行测试套件，执行了授权的实际部署验收、语法及diff检查。

## 当前现场：离线扫描与独立恢复通过（2026-10-01）

在前序提交 `7c2068d5cf3bc67d51ffeeaf14bab87656c0ac76` 上完成本单元；真实入口与既有集群保持运行。详情和日常命令见 [扫描与恢复](docs/platform-kind-v1/scanning-recovery.md)。本单元提交见 HEAD。

- 新增原生 Make/Ansible 的 scanner-db-plan/install/verify、registry-scan-check、registry-recovery-plan/check。`prepare-recovery.py` 仅校验冷备份和生成隔离的官方 Compose 副本，不管理部署生命周期；没有新通用 CLI，也不调用旧部署代码。
- 两个数据库归档纳入 `files.lock.json` 的独立 database 类型和 `databases/`。漏洞库 2026-10-01 01:24 UTC/schema2，Java 索引 2026-09-27 01:08 UTC/schema1；压缩共1,098,440,570字节，解包共3,008,844,062字节。Java不是今天最新版：两官方链路大文件只有几十KiB/s，东京SSH超时；官方GHCR不可变manifest重新核验后，以硬链接复用完整旧公共缓存，和旧脚本没有调用依赖。扫描入口要求两库均不超过七天。
- 初装数据库 ok52 changed8 failed0；修正为仅预算缺失库后重复安装 ok35 changed0 failed0。没有覆盖运行中的数据库；定期换版/回退和到期告警仍须补齐。
- Harbor真实扫描 ok48 changed4 failed0，Trivy v0.72.0，状态Success；报告 `/data/harbor/platform-kind-v1/scan-reports/haproxy-cud54j28.json`。验收镜像仍为固定HAProxy manifest `sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`。
- **安全待办**：201条包/CVE记录、86个不同CVE；High50条/11个不同CVE，Medium84、Low65、Unknown2，无Critical记录。OpenSSL/PCRE2相关包已有报告中的修复版本，而且入口进程实际加载这些库，不能一概解释为未使用；漏洞路径是否触达和官方镜像修复仍待评估。本单元只验扫描链路，不放行生产安全门禁，不自制补丁镜像；继续优先建群。
- 既有一致性冷备份 SHA256 `68f0f80957a655bdc1773f47af4ef223c92005190ac245f6957c0bc3d4ea0e96` 已实际恢复：1,625个普通文件逐一比对；16个registry数据文件在完整拉取后仍全部摘要一致；6层/8blob及config摘要一致。备份中的管理员、puller、加密密钥和证书可用；独立12443 token realm验证通过，没有借用正式仓库认证。
- 恢复入口 ok40 changed5 failed0。成功回执 `/data/harbor/platform-kind-v1/recovery/rehearsal-20261001061625045631223/verified.json`，结束状态同目录final-state.json。演练已停，正式Harbor仍healthy。备份早于本轮扫描情报和扫描报告，不能声称包含这些新数据；新备份创建与轮换仍待原生入口实现。
- 三次前置尝试分别被副本相对挂载路径识别、internal-only网络未发布宿主端口、realm检查请求缺少域名Host头拦住，均已修正。后端继续internal隔离，只有proxy另接access网络。两次已启动失败演练均停回；首次未创建容器。失败不冒充通过。
- 本轮原156容器的身份、挂载、完整restart策略和切换后的运行状态已只读复核。当前总186、运行26；新增30个演练容器全部停止。main/136共六节点Ready、仍v1.36.4，未在本轮新建集群。此前Docker29.8.1/正式入口状态维持。

### 本单元网络、空间、检查与清理队列

网络配置检查通过，无代理配置修改。GHCR最初EOF，默认mirror可读；大Java索引下载慢，保留458,883,072字节后接入原生curl续传（180秒连接上限、有限重试、最终SHA256+原子发布），实际续传增加字节，但本次最新Java归档没有下完，已停止。完整.part的验证/发布分支用已验漏洞库实操通过：ok26 changed1 failed0。两个最终归档离线核验 ok8 changed0 failed0；语法检查、Python AST、git diff检查通过，未加/跑测试套件。

06:26:21Z容量检查：C盘空闲127,469,379,584字节，230GiB盘尚可增长66,970,451,968字节，再扣250,027,436字节预算仍余60,248,900,180字节，高于50GiB；不代表全套部署已有充足预算。

最终清理务必包含：

- 本实例 recovery 下四目录：`rehearsal-20261001060549318303881`（无容器）、`rehearsal-20261001060643337524207`、`rehearsal-20261001061221251867522`、`rehearsal-20261001061625045631223`（后三者各10停止容器和专用网络）。先保留验收回执，按精确归属清理；不得波及正式实例、原节点/卷或源冷备份。
- 未选用的下载残片 `packages-to-be-installed/releases/platform-kind-v1/databases/trivy-java-db-76d004c32044.tar.gz.part`，不是正式物料。东京探测超时，无本轮远程下载文件。
- 本轮编写用 `/tmp/platform-*` 临时文件在提交前精确删除；不泛删其他人的 `/tmp` 文件。

历史下一步已推进到本页最新现场：sunmoon-kind 创建和节点拉取通过，接下来 Flux 和平台。开机/WSL重启、KIND删除重建、统一一键与生命周期、长期空间策略、应用全链路、云端实机均未完成。

## 前序现场：Docker升级及新Harbor正式入口通过（7c2068d）

所有者分别批准最初Docker维护、临时旧控制面恢复、遗留数据库缩容，以及修正后的第二个20分钟维护窗口（失败另15分钟）。第二个窗口已成功结束，不延伸为其他停机的无限授权。

- Docker客户端/服务端及三个包已 **29.8.1**；仅docker-ce/docker-ce-cli/docker-ce-rootless-extras升级，宿主containerd.io **2.2.3**保持。存储后端/目录不变，临时policy-rc.d已移除，rootless-extras原auto标记恢复。
- 正式 **0.0.0.0:30443 → 新HAProxy**。Harbor域名→新Harbor **127.0.0.1:11443**；其他域名→保留kind-worker **172.18.0.5:30443**。候选32443已退出监听。旧代理sunmoon-sni-transition-main-20260928停止并保留；旧Harbor仍在18443保留。
- 新Harbor2.15.2官方10服务healthy，unit sunmoon-registry.service；HAProxy3.4.6固定摘要，unit sunmoon-entry.service。两unit active、**boot disabled**，开机/WSL启动顺序尚未验收。systemd唯一重启管理者、Docker restart=no。
- 数据 `/data/harbor/platform-kind-v1/data`，秘密 `/etc/sunmoon/registry`，独立运行文件 `/opt/sunmoon/registry`；入口 `/etc/sunmoon/entry` 与 `/opt/sunmoon/entry`。数据盘230GiB，UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`。服务器证书1825天，2031-09-29 UTC到期，CA3650天。
- 私有platform项目，publisher仅pull/push、puller仅pull，均无删除权限，有效期90天。秘密在registry/private下root0600；自动轮换/到期告警尚未实现。新CA追加到宿主仓库专用certs.d，保留旧CA，未关闭TLS校验/改变全局信任或代理。
- 原 **156个容器身份和全部Docker卷保留**。原27运行容器中，仅旧代理按切换要求停止，现26运行。原挂载内容、restart策略、八个原运行KIND节点的IPv4/IPv6均核对。main、136两个既有集群共六节点Ready，仍是v1.36.4；**尚未用新体系建1.36.5集群**。

## 本轮证据与限制

最新私有记录 `/data/harbor/maintenance/docker-20261001T053018Z/`，root0700/文件0600；包含window、前后快照、dpkg日志、upgrade-result、cutover-result、publisher-repeat及final-state。前轮失败和恢复证据在 `docker-20260930T234941Z/`，不能覆盖成成功。凭据/备份不入Git、不公开。

1. 新窗口冷备份151,726,080字节，tar逐文件比较通过，SHA256 `68f0f80957a655bdc1773f47af4ef223c92005190ac245f6957c0bc3d4ea0e96`。此前冷备份151,715,840字节/1725项也保留。**字节比对不是独立服务恢复演练**。
2. 第二次升级及恢复检查通过，正式切换05:35:42Z通过，最终状态05:36:55Z核对通过，正式入口重复部署ok20 changed0 failed0；均在新20分钟窗口内。
3. Docker通过候选32443及正式30443、私有CA和只读身份实际pull；原token CA报错未再出现。registry-publish-check **ok28 changed3 failed0 skipped1**；已有相同manifest使发布步骤按幂等逻辑跳过。随后另以publisher向现有同摘要标签真实重复push并复核，publisher-repeat通过，不覆盖不同镜像。
4. 独立skopeo完整拉回 **6层、8blob**，manifest `sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`，config `sha256:c6f9accb39104d084a2e8012cdfc52f2a69db18790bf04e981cd6bbc8ea7c624`；只读push被拒。镜像地址 `harbor.sunmoonai.com:30443/platform/haproxy:3.4.6-trixie` 或上述digest。临时拉回/auth目录由正式入口清除。
5. 新Harbor TLS/管理员认证/健康通过；应用SNI证书与维护前、直接旧worker一致：`a0c60b64911e69797bc8832be22e0a9eae96f9488a80ff6d59158b199842834d`。这证明入口身份恢复，**不是业务登录/完整链路测试**。

### 已处理的维护错误和仍存在的过渡依赖

首次APT --no-download未取得本地归档，未安装；随后dpkg安装成功，但维护脚本直接比较Mounts列表顺序，误触回退。修正为按Destination排序比较完整字段。不能把维护检查错误说成29.8.1不兼容。

第一次daemon恢复意外启动原停止kind-control-plane，抢80端口并造成节点动态IP漂移及main端点缺失。保留原容器，八节点已按原IPv4/IPv6显式重连；这是实际IPAM配置变化。后续先暂时抑制全部restart策略再恢复原值，不能靠启动顺序保证动态IP。

旧worker重启后需要旧API重新提供Pod配置，原本停止的旧控制面导致Traefik无法恢复。第一次授权临时启动时出现遗留Harbor数据库Pod，按保护条件停止；随后所有者明确批准暂停两worker kubelet，核PVC保留和owner，再把 `cicd-platform-dev/sunmoonai-harbor-postgresql`、`sunmoonai-harbor-redis-master` 两个StatefulSet由1设0。原PVC/PV UID保留，原对象私有备份；两worker kubelet已恢复，旧控制面最终停回。

**后续Docker/旧worker重启仍有此过渡依赖**：临时启动旧API→核两个遗留数据库仍0→恢复Traefik→停旧控制面→恢复main/代理。此次新窗口已按此顺序实测通过。两个控制面以及代理存在宿主端口竞争，不能同时盲目启动。旧Harbor外置jobservice原本created未启动，聚合unhealthy，其他七组件healthy；没有擅自启动旧jobservice。

## 已准备的新体系代码与物料

原生Make/Ansible、官方Harbor生成器/Compose及有限override、HAProxy SNI分流、镜像验证与发布；不新增Python统一CLI。一次性维护编排不成为部署依赖。站点保留开关；正式entry地址/端口已写回site.yaml。

Ansible2.21.4、Compose5.5.1；KIND0.33.0、kubectl/kubeadm1.36.5。官方KIND构建节点sunmoon-kind-node:v1.36.5-kind0.33.0，manifest `676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b`，内含containerd2.3.4/runc1.4.3；节点+Calico3.32.2四归档641,355,776字节已核验，尚未创建新集群。

物料 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/{bin,packages,manifests,images}`。上游镜像锁56项，offline_ready=false；文件锁16项，含六个Docker新旧deb共98,306,132字节（回退包先保留）。Harbor官方包177blob/12镜像已核验；归档与上游压缩manifest不同，运行使用archive_reference。HAProxy/skopeo归档136,100,352字节；官方skopeo容器1.22.3，manifest `9182497536bb5485b4f0bdbad5dbab24cd0df7259c33005a1e732a34f5d78a99`，与源码最新版本的差异已有记录。

## 下一步（保持顺序）

1. 离线扫描与已有冷备份独立恢复已通过；后续补数据库定期更新、原生备份创建/轮换与扫描风险收敛。
2. 新KIND创建/配置与节点私有拉取已通过；接入 Flux，再平台和模板/应用部署。`sunmoon-kind-main` 已于2026-10-01删除；`sunmoon-kind-136` 和旧 `kind` 节点/卷仍受保护。
3. 单组件与整套一键、统一启停、开机附盘与服务顺序；WSL/KIND重启、KIND删除重建后的Harbor数据/摘要/新节点pull验收。
4. 长期容量监控、Harbor保留/GC、缓存/日志/备份轮换与统一预览/执行；除日志外删除策略具体确认。结束时清理本次全部临时物料/东京下载，受保护旧资源达到退出条件后再清理。

最近容量：05:35:37Z，计数据盘长到230GiB及本次512MiB拉回预算后C盘剩59,966,734,336字节，高于50GiB。后续重测，不表示全套部署均有足够空间。

当前Docker升级/正式仓库认证单元完成；新架构全量部署、重启/重建验收、云端实机验证未完成。没有新增或运行测试套件；实际部署验收、Python AST和git diff检查按用户授权执行。本轮未改Windows附盘/计划任务/执行策略，未连东京。

本轮9个一次性运维脚本已从/tmp移除，只在最新私有维护记录的script-audit中保留非执行文本副本及SHA256；4个临时文档/提交编辑文件已删除。旧luna任务的/tmp文件未混删，整体重整的最终清理仍列在后续步骤。
