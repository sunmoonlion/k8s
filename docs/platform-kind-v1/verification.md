# 验收边界与待交付项

维护手册说明现在怎样操作；本页区分代码具备的能力、过去实际验证的范围及尚未完成的目标。整理日期2026-10-05，依据重构前提交d869c637及其中的代码/记录；历史运行记录沿用原结果，后续检查范围在对应小节注明；文档整理时没有重新执行部署或扫描；后续实际执行的单元在下文注明日期与范围。历史结果不能当作当前机器实时健康证明。

## 整套入口与开机恢复（2026-10-05）

新增`platform-deploy`实际跑过从Harbor/入口/KIND到Flux、平台及四个应用的原生入口，全部退出0；各阶段部署资源未报告变更，写入包括模块选择、临时目录和验收回执。首次把多模块import到同一Ansible进程的候选在Flux工具变量污染处失败（此前changed0），已移除；最终由Make分别调用独立原生进程。统一公共入口platform-check也实际退出0（10段），覆盖Kibana、平台及四应用协议；最终3节点Ready、57个Running Pod全部Ready、0 Failed、51个Flux阶段当前代次Ready、13 PV Bound/Retain，旧控制面仍停。使用已有数据与已晋级声明，不代表从空主机/删群冷建已通过。日志私有保存在`/data/kind-clusters/sunmoon-kind/bootstrap/evidence/lifecycle-20261005/`。

开机/启停代码及管理员任务已安装；真实任务返回0、六个新旧节点restart=no，旧附盘单元停用、新单次恢复启用。已实际停止并恢复新平台，最终统一启动退出0；未关闭WSL。恢复前后40仓库/103摘要标签、13 PV/PVC及Job身份、六节点ID/挂载/运行态、Docker卷集合一致。冷态registry全文件摘要、真实WSL/Windows重启及删群重建仍未验证，不能报告完整持久化通过。实际重启发现ES证书只读副本无法重复复制，临时恢复后57 Pod Ready；永久修复实际镜像重复复制通过，模板/生成候选已暂存、尚未发布。原2小时窗口过期后发现已进入停服，随即恢复并停止新增停服；下一窗口另批并在停服前核对时间。维护方法及回退见[整套生命周期](../../infrastructure/host/lifecycle.md)。DNS、真实浏览器及机器外备份仍未完成。

## 当前实现与证据来源

职责与流程见[架构](architecture.md)，日常入口见[导航](../README.md)。版本/镜像唯一事实源为物料锁及组件image.lock，配置当前值留config.yaml，避免在本页复制第二套BOM。

| 能力 | 实现/实际验证范围 | 日常归属 |
|---|---|---|
| KIND | 三节点、原生建群、固定节点与Calico物料、独立宿主static/dynamic路径、三节点认证拉取/DNS检查 | [cluster](../../infrastructure/cluster/README.md) |
| 平台与应用部署 | Make/Ansible生成候选，审阅提交，发布候选，显式晋级固定OCI源，由Flux执行；已有晋级声明的services/application bootstrap重复执行已验证 | [Flux](../../infrastructure/flux/README.md)、[应用](../../infrastructure/applications/README.md) |
| 秘密 | 主备非覆盖、逐字节一致、已有身份丢失停止、SOPS/age解密、权限隔离 | [secrets](../../infrastructure/flux/secrets.md) |
| 公开入口 | TLS直通SNI分流，Harbor独立后端，应用指新Traefik；预览/备份/限定切换和真实TLS登录已分单元验证 | [entry](../../infrastructure/entry/README.md) |
| 构建网络 | 四应用后端/Web/Admin统一在线依赖下载；国内直连失败分类后一次官方代理回退；Harbor直连 | [applications](../../infrastructure/applications/README.md) |

历史构建演练覆盖国内成功、有效代理回退、未配置/不可达代理、回退耗尽，以及编译/完整性失败不回退和Python锁URL投影。它不是所有网络环境永远成功的证明；失败保留脱敏分类结果，不自动循环/交互等待。

## 仓库与扫描

2026-10-01记录验证了官方Harbor2.15.2独立运行、真实push/pull、TLS/token认证及限定扫描。Docker29.4.3相关认证链问题修正后，以29.8.1实际拉取验证；不能因此把所有拉取失败归因版本或免检CA。

同版本冷备恢复演练核对1625个目录文件及16个registry文件、指定镜像配置/6层/8个blob，并验证恢复实例登录、只读身份、TLS realm与拉取。该演练验证限定备份，不代表WSL重启、删群重建后的全目录/所有当前镜像验收；后者仍待完成。

当次Trivy扫描Success产生201个包漏洞条目、86个独立CVE：High50条（11个独立CVE）、Medium84、Low65、Unknown2，无Critical。Success仅代表扫描链工作，不代表镜像安全合格；数据库更新时间属当时记录，不能当今天的新鲜度。系统包问题按所有者决定等待官方例行修复，不自制扫描器补丁。

当时HAProxy进程映射包含PCRE2、libssl与libcrypto；加载不能证明漏洞可达，也不能记为全部未调用。安全门禁与官方修复跟踪仍待交付。操作与范围见[扫描](../../infrastructure/registry/scanning.md)、[恢复](../../infrastructure/registry/recovery.md)。

## 平台组件

历史记录截至2026-10-04：三节点、平台及应用运行/Flux阶段已逐单元核验，之后仍可能变化。本次不凭旧数量声称在线状态。

| 组件 | 实际验证 | 尚不能据此宣称 |
|---|---|---|
| PostgreSQL/Casdoor | 独立数据库/迁移与runtime权限、初始化、实际浏览器身份 | 数据库完整备份恢复、HA、自动秘密轮换 |
| Redis | 独立ACL及拒绝、真实替换Pod后账号/ACL摘要/PVC保持、主进程0077和ACL SAVE文件0600 | WSL重启/删群恢复已验 |
| RabbitMQ | 持久拓扑、应用消息发布消费确认、vhost/管理拒绝及Celery兼容 | 单节点HA、全量消息灾备 |
| 对象存储 | 有效许可实际S3读写、版本/hash、跨桶/策略拒绝 | 对象历史生命周期、灾备恢复 |
| 文本向量 | CPU中文模型真实向量、维度/归一化/原生TEI一致与中文相似检查 | 性能容量基准、外部模型切换 |
| RAGFlow/Infinity/Valkey | 最小派生镜像权限守卫、独立身份、内部TLS/API、中文实际摄入检索 | 所有UI/PDF、HA、完整灾备 |
| ELK/采集/Kibana | 三节点实际CRI日志、角色标签/源日志核对、TLS/权限；已有data view采用分支；Kibana公共30443登录/会话/只读权限与注销 | 零丢失/零重复、保留GC、首次空data view创建、宿主DNS与实际浏览器界面 |
| Neo4j | TLS/认证、图提交/读取/回滚与受控失败rollout恢复 | 四应用图身份、完整Bolt驱动业务、HA/灾备 |
| MongoDB | TLS单成员replica set、CRUD/事务提交回滚/拒绝、真实Pod替换nonce读回 | 四应用接入、整机/删群恢复、HA/完整备份 |

详细限制在[组件手册](../../gitops/components/README.md)所属目录，不能以Pod Running替代协议或业务检查。PV Retain与目录挂载正确也不能证明恢复成功。

## Kibana入口的实际范围（2026-10-05）

已执行原生services-stage→本地提交→固定OCI发布/显式晋级→services-bootstrap，并限定切换宿主入口。独立人工只读账号由组件配置指定；密码、TLS主副本已逐字节核对。只允许default空间只读功能与应用日志索引读取，管理员/日志写入/外国索引拒绝由初始化和实际请求核验。日常参数与身份读取位置见[UI维护](../../gitops/components/data-platform/elk/kibana/ui/README.md)，不在此复制口令或第二套参数。

公开30443实际HTTPS校验CA与域名，登录HTML、匿名/错误密码401、读视图200、管理/保存视图403、Secure/HttpOnly/SameSite会话、会话读取以及注销后旧cookie401通过。TLS直通分流没有改变Harbor或四应用既有域名；Harbor真实token/完整镜像摘要拉取和只读写入拒绝、四应用原生public检查均通过。

同一最终固定源的完整services-bootstrap连续两次成功；第二次Pod/Job/PV身份与重启计数不变。首次仅计划内滚动Traefik和Kibana，其他55个原Running Pod、32个既有初始化Job与13个Retain PV保持；当前3节点Ready、57个Running Pod全部Ready、51个Flux阶段当前代次及同一固定源Ready。证据与原始失败保存在infrastructure/.build/models/kibana-ui，最终unit-receipt.json；它们是作者执行证据，不替代独立验收。

验收程序最初漏内部登录来源标记，又把退出页面当注销接口，并遗漏注销导航须去掉AJAX标记的要求；三次原始失败保留。按当前固定官方镜像核对并修正请求后重验，未关闭内部API限制、TLS或扩大账号权限；两条失败探针会话在公开切换前仅按新账号/提供者注销。已有Job输入未改变，不重复创建账号或重置口令。

宿主域名解析目前尚未配置：WSL解析kibana.sunmoonai.com失败，Windows hosts没有该域名。因此本单元以实际loopback、目标SNI/Host及证书完成协议验收，不能宣称浏览器直接输入地址可用。Windows/WSL DNS与证书信任、实际界面渲染在宿主统一控制单元继续验；本单元未验证WSL/KIND重启或删除重建后的持久化。

## 应用与业务链路

| 应用 | 历史实际范围 | 待验/未实现边界 |
|---|---|---|
| tpl | 数据库CRUD/DDL拒绝，持久Redis，RabbitMQ真实消息、Scheduler/Worker、Web/Admin PKCE/回调/SSR/session/退出/CSRF及公共入口 | 模板provider未配置明确503；不宣称业务功能全集 |
| info | 基础登录/消息/运行与公共入口；真实ObjectStorage两版本/hash/隔离；独立服务身份HTTPS摄入 | 完整爬取、发布、搜索与分发业务 |
| knowledge | Info原文VersionId/hash、服务身份日记、真实Scheduler/Outbox/Worker中文解析、关系/租户/数据集拒绝 | PDF/其它格式与浏览器全集、完整爬取来源、恢复演练 |
| investment | 基础登录/消息/运行与公共入口；实际领域Port以独立身份HTTPS取得Knowledge中文证据与原文引用 | 外部模型Key、执行环境、Agent工具、信息查询完整业务 |

tpl/info公共入口在2026-10-03验证，knowledge/investment在2026-10-04验证；真实跨应用链也在既有单元验证。验收探针采用UUID及原文指定版本，仅清本轮对象；失败日记和Worker仍使用输入不得删除。维护见[provider](../../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md)。

## 物料目录维护

2026-10-05完成组件归属分类：批次中的99个文件、26,035,136,526字节（约24.25GiB）在同一文件系统迁移；逐文件核对迁移前后SHA256、大小、inode、属主和权限，全部一致。文件锁与归档锁的path、镜像锁的material_owner同步调整，版本/来源/摘要保持原身份。该迁移步骤没有删除物料；当时旧版本与未完成下载保留并由inventory明确显示。后续清理见下面的复核结论。

新增只读`material-inventory`，从锁展示归属、本地路径、Harbor目标及配置/部署代码；按完整归属或平台前缀筛选。存在状态不证明内容校验或Harbor已发布，未接入的组件声明明确标出，未被当前锁引用不等于可删除。

相关十个原生入口通过Ansible语法检查；plan-artifacts、plan-bootstrap-images、flux-plan、application-plan、services-plan通过实际只读预览。文件/镜像/工具安装、Flux与RAGFlow的路径消费已同步修改，临时应用传输路径与在线依赖下载方式保留。日常方法见[物料维护](../../infrastructure/artifacts/README.md#日常查看与目录归属)。

2026-10-05完成物料分离后的复核和限定清理：新根为`~/k8s-packages`，旧根为`~/packages-to-be-installed`，新体系配置/脚本/维护文档没有旧批次路径引用；空releases目录已移除。精确删除旧tpl后端归档/回执、两份旧RAGFlow派生归档/回执和一份过期Java DB部分下载，共7文件、8,595,448,846字节。删除前核对文件inode/大小、归档SHA与回执、当前版本锁、运行中的新集群镜像、宿主挂载与打开句柄；所有候选单链接且未打开。当前安装文件锁、建群/宿主归档锁以及RAGFlow替代归档的完整SHA核对通过。

候选实际分配块合计8,595,476,480字节；删除并sync前后文件系统空闲实测增加8,595,402,752字节（约8.01GiB，运行服务期间有并发写入）。余下100文件、17,495,514,757字节（约16.29GiB），路径、inode、大小、mtime、属主与权限相对清理前保持；没有触碰Harbor镜像、容器、数据卷或备份，没有压缩VHDX，不能将本轮释放量当作Windows C盘物理回收量。Traefik辅助整包8文件约53.24MiB因冻结云流程仍引用而明确保留，参见[物料维护](../../infrastructure/artifacts/README.md)。

清理后重新运行material-inventory和五个原生只读plan入口，检查结果见本次提交说明。这些核对没有执行联网下载、镜像构建/发布、重新安装、重建集群或重启服务，不能替代下表的一键部署与持久化验收。

## 未完成项

这些是此前所有者明确要求的交付目标，文档归并不等于功能已完成。后续按依赖顺序落实，不为填满手册添加假的统一入口。

| 顺序 | 目标 | 退出条件 |
|---|---|---|
| 1 | 整套一键部署、统一启停与开机恢复 | 首次管理员附盘可单独，其余由统一入口；已晋级环境从宿主到平台/四App实演，保留配置开关与单组件操作；重启不让旧kind夺入口，不重复UAC/分钟提权 |
| 2 | Harbor独立持久化 | 分别实际WSL/KIND重启与KIND删除重建；Harbor全目录/镜像摘要完整、新节点认证真实拉取；保护其它集群与数据 |
| 3 | 长期空间管理 | 容量持续查看/告警，统一查看/预览/执行；Harbor保留/GC、构建缓存、日志轮转与索引、备份轮换；区分自动/人工，删除策略先审批，保护在用/回退镜像与必要备份 |
| 4 | 数据与身份灾备 | 各数据库、对象原文、私有输入完整备份及恢复实演；机器外落点由所有者选定，同盘备份不防硬件故障 |
| 5 | 生产安全与业务补齐 | 组件安全门禁/官方修复跟踪、按需要轮换、Kibana宿主访问/界面及各应用上表业务边界逐项验收 |
| 6 | 云端建群验证 | 统一声明/流程的云建群适配另定设计并经实机验证；当前KIND不能证明kubeadm/OS离线包路径。Ubuntu虚拟机想法排KIND验收后、另批准 |

目前底线为10GiB、维护窗口2小时；此前40/50GiB临时审批及短窗口已不作为当前操作规则。数据盘未来长满230GiB仍计入预算，进入对外服务前再确定资源、可用性与安全要求。

## 如何追溯历史

十五份阶段卡的有用维护内容已归所属模块，开发细节留Git，不在日常目录保留副本。批准的逐份方案保存在提交2898162f；原始67份Markdown及全部代码基线为d869c637。

只读示例（k8s根）：

```sh
git show d869c637:docs/platform-kind-v1/scanning-recovery.md
git show d869c637:docs/platform-kind-v1/tpl-redis-maintenance.md
git show 2898162f:docs/maintenance-docs-file-disposition.md
```

历史运行记录目录可能已按批准清理，不作为现在恢复入口依赖。当前状态用各模块status/计划查看，重新验收用所属check并记录真实结果；检查本身可能有精确探针写入，先读副作用说明。
