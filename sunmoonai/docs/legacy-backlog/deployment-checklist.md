# 当前重构的部署与运行验收清单

本清单承接旧 B7/B9 的未闭合运行工作，不定义新产品架构。
2026-09-20：业务 KIND 已切换 `kind-b7-20260919` 固定候选和独立运行身份，三个 App
均已恢复就绪，旧 DB 登录与旧 vhost 权限已退出并实测拒绝。
停写备份/实际恢复、精确摘要与边界见
[本次记录](../tasks/B7-B9-closeout/thread/0001-imp-none/0015-none/others/preparation.md)。
完整浏览器及跨 App 业务 UAT、故障回滚/前滚和独立网络包级验收仍未闭合；不能把下面
历史快照或前置检查列表误读为当前全部待做，也不能把上线就绪当作完整验收。

入口分工：[待新架构接收的旧任务](README.md)、[验证与历史索引](verification-index.md)。
按用户决定，先完成文档清理与指南更新，再集成 master、同步五仓，最后部署。

## 1. 源码与同步

- 核五父仓、实际子模块、两端各工位的分支、干净状态、独有提交及远端引用；保留本地
  k8s master 已有的 question-data-demo 提交。不能用 Luna 强制覆盖 master。
- 有子模块新提交时先推子仓，再集成父仓 gitlink；没有新子仓提交也须核其远端可达。
- master 集成后用 `five-repos-sync` 的 `-all` 普通同步；它只同步同名分支，
  **不会自动把 master 合入其它工位**。工位更新先检查独有提交和改动，只做获准的快进。
- GitHub/Gitee 推送与本地/云服务器拉取分别核验；失败保留现场，不 force/realign。
  本地 Opus 工作树可同步，不启动 Opus 助手。源码同步不等于 Harbor 或运行态同步。

## 2. 发布对象与环境

当前目标是**本地 KIND**，不是远端云集群或 production。采用新开发 release_id、固定
源码提交、Harbor 不可变镜像 digest、source lock 和 bundle；保留原发布及回滚制品，
不覆盖正式 tag/历史 manifest。实际部署需绑定精确版本、配置和回滚方案。
三 App 的当前 bundle `formal_release=false`；production profile 仍禁用。

现场基线来自 [2026-09-19 只读核对](../tasks/B7-B9-closeout/thread/0001-imp-none/0001-none/others/kind-cutover-preflight.md)：
三 App 的 API/Worker/Scheduler 仍引用旧共用凭据键，Worker 缺 release-id 注解；
broker 启动定义来自共享 Secret `rabbitmq-app-definitions`。该核对未读取凭据值或业务行。
执行前重查 namespace/Deployment/StatefulSet UID、generation、imageID、revision、队列与
连接，不能拿过期快照直接执行。显式 kubeconfig/context，不改用户全局 context。

## 3. 数据与身份切换的必要前置

| 范围 | 尚须完成或现场复核 | 不可使用的捷径 |
| --- | --- | --- |
| Info | 0008 canonical identity 与 0009 逻辑分发身份的实际存量预检、重复/冲突分类、备份恢复；9 月 13 日曾只读观测业务库为 0007，现状须重查 | 不自动合并、删除、重键；不让旧写者与新约束迁移并行 |
| Knowledge | 明确批准的 `INGESTION_DATASET_BINDINGS`；旧受理标记、generation/step、绑定快照、旧上传与解析回执的处置 | 检索 allowlist 不授摄入权；不自动给旧任务补授权/协议标记，不因本地无回执盲重传 |
| Investment | 核 Agent 租约/checkpoint/恢复令牌/副作用账与旧归档的兼容性；审查 deploy.py 的 LOGIN/NOLOGIN 额外副作用 | 不把它当“仅换镜像”；不禁用旧归档触发器来完成迁移或清理 |
| 数据库身份 | 四角色真实独立登录和密码；正确 owner、继承/SET、PUBLIC、列权限、creator 的 default ACL；Migration 凭据不注入运行 Pod | 不能给旧账号追加 GRANT 后称权限已收敛；不能往三个新键复制同一个旧 URL |
| broker 身份 | API/Worker/Scheduler 独立用户；先预建 durable 交换机/队列/绑定，再启用预声明模式；保留 Worker 控制/事件/探针需要的精确资源权限 | 不能给生产者队列 read 后声称禁止消费；不能用 `.*` 兜底；资源 ACL 不等于消息内容审批 |
| 启动 definitions | 活跃配置与共享启动 Secret 同步，保留所有非目标 App 条目；重启后不恢复旧账号/宽权限 | 禁止拿单 App 测试定义覆盖共享 Secret；不要直接重跑旧供给脚本 |
| 撤权与排空 | 核完整身份及旧消费者归属，定义停止受理/调度、新旧观察/撤销窗口，核旧连接消失及新登录拒绝 | PG NOLOGIN/改密码不自动终止旧连接；不先撤旧凭据制造停机 |

历史盘点仅供制定核查项：2026-09-13 Knowledge 有 54 条 job，均属当时源码终态；
5 条旧格式 ingest Outbox 均有 Inbox，Provider operation 为 0。**这些不是最新计数，
也不证明没有远端副作用**，不得据此批量重放或删账。
同日九运行角色目录显示全表 CRUD（包括版本表），broker 三角色同用户；B7o～B7v
已验证隔离候选，但未替业务身份实施撤权。最新结果必须现场获取。

只读数据库目录工具：`sunmoonai/app-platform/scripts/audit_runtime_database_permissions.py`。
它输出 `permission_acceptance=not_evaluated`，不等于实际拒绝试验或完整权限安全验收。
不要执行旧 `provision_r5_*_database_roles_kind.sh`、`prepare-investment-broker-kind.sh`
代替新供给方案；后者涉及共享定义、删除和重启，且有历史开发凭据风险，须受控处置。

## 4. 备份、迁移、观察与回滚

1. 每 App 冻结表/约束/索引/触发器/revision/owner/行数、对象存储版本及实际消费者。
   备份含 DB、必要对象及独立身份/ACL/配置恢复材料；只读清单不代替备份。
2. 实际导出并在隔离目标恢复，核计数、业务不变量、去重、引用及权限。B7v 的合成
   Outbox/Inbox 恢复不是业务数据演练，也不覆盖对象存储、外部回执或 RPO/RTO。
3. 排空旧 API/Worker/Scheduler、确认旧 Pod 消失，按开发发布门禁再迁移、启动一致版本。
   `app-platform/scripts/development_release.py` 的 cluster/release 备份回执和排空要求
   不得绕过。保持网络策略先于 migration 的正式 apply 顺序。
4. 模板先验，Info→Knowledge→Investment 串行切换；一项失败停止下一个 App。
   核 schema ready、Worker 本节点队列/注册、Beat 活动、真实 Inbox 与业务结果，
   再验证 Info→Knowledge→Investment、服务/浏览器身份拒绝、故障恢复与回滚。
5. 回滚绑定兼容的源码/镜像、DB revision、Secret、default ACL 和 broker 定义；
   不能用旧镜像直连不兼容的新 schema。恢复旧备份不会撤销备份后已发生的远端写入，
   恢复环境发送任务前必须隔离旧执行者并对账 executing/unknown/legacy_unknown 回执。
6. KIND kindnet 不执行 NetworkPolicy；包级 allow/deny 需要独立 Calico 门禁，不能由
   Pod Ready 或清单存在代替。历史门禁只为对应版本背书，不自动覆盖新发布。

迁移、凭据撤销、删除和实际部署均需精确对象及批准；“同步完成”不是这些动作的授权。
真实 RAGFlow 或其他 Provider 回执、浏览器完整旅程仍需与本次发布绑定的实测。

## 5. 保留、归档与清理的保护条件

当前未冻结业务保留天数；这不阻塞文档清理，但**禁止据年龄直接删业务账本**：

- Outbox 的 deduplication_key 和意图用于相同请求复用；Inbox 未必有 Outbox FK，
  删除回执可能允许重做。dead-letter、execution/epoch 墓碑仍参与阻断与迟到执行保护。
- Info 旧分发表包含迁移/回滚映射，不会自动收集新消息；“legacy”名称不证明数据库
  强制只读。Artifact 本域只读对账不覆盖历史分发、Knowledge 引用或 Citation。
- Knowledge 的上传身份跨 job/代次；Provider operation 无 job FK 也可能被逻辑引用。
  删除 unknown 记录会把不确定写入误变成“从未执行”；0006 downgrade 不允许清账绕门禁。
- Investment 的 resume 幂等会读取原命令；副作用依赖 epoch、run 和 tool_call_id；
  checkpoint 按 execution_id 隔离。旧归档只读触发器可能连 FK 的隐式 DELETE 也拒绝，
  不能禁用触发器、删 FK 或改变 session_replication_role 来清理。

后续归档必须先定重试/重放/恢复/回滚/调查保护窗口、盘点完整引用、保证归档读路径或
在线去重记录、关闭新增引用并发窗口、导出并恢复验证，再单独批准精确删除批次。
未知 topic、查不到、权限不足、归档损坏或未结算外部写均保留保护；跨域引用走契约，
不跨库 SQL。产品级统一生命周期归旧任务 N4；现存业务保护继续有效。
Prometheus/Alertmanager 仍归 [N4-OPS-01](../tasks/N4-OPS-01/thread/0001-imp/0001/user-message.md)，
本清单不扩大为安装或发送外部告警的授权。
