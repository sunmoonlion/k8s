# 在线身份供给与迁移后授权接入记录

目标仍为本机 KIND，候选 `kind-b7-20260919`；业务组件与九镜像 digest 沿用
[0011 候选](../../0011-none/others/image-candidate.json)，不部署云端。

## 本轮实现

- 模板增加新身份目录前置核验、保留非目标条目的 broker 窄范围供给计划、只建立连接的
  AMQP 登录/跨 vhost 拒绝验证；不发布、消费或声明队列。
- `kind_identity_prepare.py` 默认只生成 Git 外私有计划。执行要求完整计划摘要、源码和
  release 一致、集群 UID 正确、全新名称；先独占创建运行 Secret，再以 uid/resourceVersion/
  原值 CAS 更新 definitions 的一个键，再执行六个定点 PUT。每步先落意图，异常停止，
  不重试覆盖、不自动删除现场。旧用户和全部消息保留。
- `kind_database_activation.py` 接入三个部署入口的 Migration Job 之后、Runtime 之前。
  只创建全新角色，核对 owner/head/表列/角色属性/ACL/default ACL/函数/活动连接，
  加锁后在同一 SQL 事务内重查目录指纹，再执行已审查策略。真实 TCP 登录正反例通过
  才允许继续启动。成功重试要求同源/同计划/同权限目录；半成品不自动修复。
- `kind_database_rehearsal.py --cutover-release` 新增真实停写备份回执：检查精确角色副本、
  无标签遗留 Pod/Job、暂停 CronJob 和数据库连接，两次实际隔离恢复后，重新核对运行
  声明、全部原业务行与目录未变化。普通在线演练不出具该回执。部署门禁绑定完整候选
  内容摘要、数据库镜像/head、恢复结果与 dump SHA，不接受旧式布尔回执。
- 三份完整 bundle 已重新生成比对，仅 renderer 输入摘要变化，15 份资源清单和镜像不变。

## 失败根因与验证

Info 的真实迁移新增了 canonical/distribution 标识不可变触发器；原先只有 uuid-ossp 的
允许清单，故主动拒绝。逐字对照后端 0008/0009 源码，将精确函数定义放入 Info overlay。
Investment 0007 的 archive 只读触发器同样精确登记。Knowledge 的 uuid-ossp 函数实际
归 postgres；隔离 pg_restore 也会由 postgres 创建扩展。只接受已核对的扩展/owner；
未知函数、不同定义、SECURITY DEFINER 仍拒绝，没有删除或关闭触发器。

最终实际隔离演练（每项两次独立恢复，无外网）：

| App | 私有目录后缀 | head | 每次认证/权限探针 |
| --- | --- | --- | --- |
| Info | info-activation-rehearsal-04 | 20260913_0009 | 29 |
| Knowledge | knowledge-activation-rehearsal-02 | 20260911_0006 | 27 |
| Investment | investment-activation-rehearsal-02 | 20260911_0007 | 27 |

均验证完整恢复原目录/原业务行、原子目录漂移拒绝、授权 SQL 最后阶段注入故障后的完整
目录回滚、新登录及拒绝越权、默认 ACL 封闭、验证新身份后旧登录拒绝；原有业务行不变。
这是隔离验证，尚不代表线上切换或跨数据库隔离验收。

私有材料根：`/home/zymun/worktrees/luna/.local/kind-cutover-20260919`，不入 Git。
RabbitMQ 一次性容器集成测试 2 项通过，包含实际密码哈希登录、窄 PUT、旧权限定点
撤销以及旧用户仍存；共享业务 RabbitMQ 未在这些测试中写入。

两个仓同时收集 pytest 时遇到同名 `test_deployment_config` 模块导入冲突；按仓分别运行
解决收集冲突，不删除缓存或跳过测试。最终数字和同步/实机动作在后续检查点记录。

## 发布前状态与剩余

截至本记录初稿，API/Worker/Scheduler 三 App 全部 Ready；Info 遗留 scanner CronJob
已经 suspend 且无活动任务。未停服务，未更改业务库/线上 broker/运行 Secret。
已生成但未执行 Info 私有计划 `info-preparation-01`，摘要
`1528eaa5d4f4566666496110541442883bfad6f7ec7a1a017af99dd82f24a213`。
计划不是批准或执行回执；任何源码/候选/共享定义漂移必须重新生成。

剩余仍按顺序：固定提交并同步 → 定点准备新运行身份及实机 AMQP 验证 → 停旧写者/排空 →
静止窗口新备份和实际恢复（Info 还需对象材料核验）→ Migration/授权/Runtime →
业务和新身份验收 → 精确停用旧 DB 登录及旧 vhost 权限。旧账号退役不在授权入口内
自动执行；实际回滚必须按旧镜像/schema/ACL/Secret/definitions 与外部回执一起核对。
任何部分失败保留现场，不能把新角色存在或 rollout Ready 当业务验收成功。

## 首次实机准备与隧道故障修复

准备代码提交：tpl-app `5135af9d19f969dc4371d6bd737c6e64c1ca149e`，
k8s `4c573007cab56a88c77e703c8f668e7938d10558`。均合入 master，五仓脚本
`to-remote -all` 退出 0；两机各 30 父仓全部干净且等于各自 master，子模块由脚本对齐。
没有 force、realign、新建分支或启动 Opus 助手。未变化的三 App 父仓分别为
Info `25959b677b6930de1b6a5c9bbbb7fb77cc90f8d2`、
Knowledge `b3d5dda05adee2d62df3cc0e6fdb913799a96347`、
Investment `3b3c9381aa9d204a5e9cf1eb11def667cbac5762`。

Info 上述精确计划已执行：运行 Secret 独占创建、共享定义 CAS、六个定点 PUT 和
HTTP 读回均成功。首次 AMQP 验证时，API 正登录和未授权 vhost 拒绝均正确，但
后续 Worker 连接失败。逐层定位发现负例握手导致服务端 reset，kubectl port-forward
随之退出 1（`read: connection reset by peer; lost connection to pod`）；并非密码错误。

修复为每个角色一条独立隧道，保留真正的拒绝检查。新增显式 `--verify-prepared`：
核对原摘要、六步意图/成功日志、Secret UID/data、共享启动定义和线上精确权限后，
仅重做认证验收；不包含任何服务器 PUT/PATCH/CREATE，不重放原计划，不改原日志。
成功才创建新的私有 `amqp-proof.json` 和 `applied.json`，另记本次验证源码摘要。

实机只读恢复验收已通过：三个新角色各登录成功、各跨 vhost 被拒绝，没有消息操作。
`database_activated=false`、`old_identities_retired=false` 仍明确保留；旧业务服务未停。
最终回归：k8s **95 passed / 176 subtests**，模板 **31 passed / 27 subtests**，
真实隔离 broker 集成 **2 passed**。

同步期间重新读取 Info 对象，`info-objects-04` 仍为 189 引用/56 内容，archive SHA
`a34ea6117e5e290ab69f89078dcedb469ee8edad92f390ebce7c15130ba6d22a`，
与已做真实 S3 恢复的 `info-objects-03` 逐字一致。Info 旧 Worker 定点检查
active/reserved/scheduled 均为 0，只代表该采样，不替代停写后的核验。

## 真实串行维护切换

隧道修复固定于 k8s `64e636d3561bd2482472af79eadab2ec5983e1d0`、
tpl-app `b095aac2f6df483541d744719312ae5f23b84f39`；第二次五仓
`to-remote -all` 全部成功后才进入维护。三个 App 按 Info → Knowledge → Investment
逐一停止 API/Scheduler、确认 Worker active/reserved/scheduled 与队列 ready/unacked
均为零后停止 Worker；未清队列、未重放历史任务、未重启共享基础设施。

每个 App 停写后分别生成新备份、完成两次实际隔离恢复、复核业务行未变化，才部署：

| App | 身份准备计划 SHA256 | 停写备份 SHA256 |
| --- | --- | --- |
| Info | `1528eaa5d4f4566666496110541442883bfad6f7ec7a1a017af99dd82f24a213` | `0b8943115ed20365cf0bf56bfd17ca9d9529d50d460a302e2c534e24cfddb0a6` |
| Knowledge | `b3f7ca30ead298b1c82797924f2f7a3f915e812b43d54ef2938a0e06e4f8c467` | `e618b268611bf636722420215da96d728c55d315fecea4fc82bc12f6aa013e98` |
| Investment | `aaea2a1640a357bd2edb107c918effe87f36e083a44f59f1af467cc25e549d05` | `b69d14761185eece60e058d6e3b7c67f1047e084860b10f80b6bffcd79b38079` |

原始材料分别在私有根的 `<app>-preparation-01`、`<app>-cutover-01` 和
`<app>-maintenance-01`。真实部署使用 `cutover-receipt.json`，不是同目录仅表示
准备演练的 `rehearsal.json`。Info 停写数据库的 189 个对象引用与已恢复验证的对象包
逐项一致，见 `info-maintenance-01/objects-match.json`；本轮未再写 S3。

三次部署均退出 0；每个 App 完成新 DB 身份 18 项实际 TCP 权限探针，迁移 head 分别为
`20260913_0009`、`20260911_0006`、`20260911_0007`。三个 App 的 API 2、Worker 1、
Scheduler 1、两个前端各 2 均 Ready，固定 digest 与候选一致，drift 均为 false。
就绪接口均返回 ready，deploymentId 均为 `kind-b7-20260919`。

Info/Knowledge 的 HTTPS 首页 TLS 校验通过、未认证返回 307；本机缺域名解析，测试
使用仅限单次请求的 `--resolve`，未改 hosts。API 就绪请求必须带正确 Host；默认
localhost Host 返回 400 是现有允许列表生效，没有放宽允许列表。

已知未完成：三 App 的版本接口显示 `0+unknown`，Info 镜像内 pyproject 有版本但
distribution metadata 未安装（项目无 build-system），接口走现有缺失元数据回退。
实际镜像 digest 与 deploymentId 正确；本轮不在容器内补丁或修改已固定候选掩盖问题。
旧 DB 登录与旧 broker 权限此检查点尚未撤销；完整业务 UAT、跨库拒绝和旧身份退役
仍待后续核验，Ready 与部署成功不代表这些已完成。未触发付费模型、外部通知或历史摄入。

## 旧身份退役与跨库拒绝（2026-09-20）

上述检查点之后，重新取得三个 App 的完整权限目录，与激活后目录逐项一致；新角色
54 项 DB 探针及 18 项 AMQP 正反例再次通过。9 个新 DB 角色分别连接另外两个 App
数据库，18 次均被数据库权限明确拒绝。三个旧 backend 角色均无连接、无角色成员关系、
无其他数据库或非本域对象依赖；Info/Knowledge 的旧 admin grantee 也无本库连接。
三个旧 broker 用户均无活动连接且仅有对应单一 vhost 权限。

按 0012 的既有授权，生成并逐个执行以下精确计划，原始载荷和结果在私有根
`retirement-01`，不入 Git：

| App | 退役计划 SHA256 |
| --- | --- |
| Info | `413eecd6b7bc90bde7dbb3ddc9d73ea100bf83400c099e2fdc4357995dbaaf94` |
| Knowledge | `3a9d295a1b14f04624fdeda2d45116ecd6685c4094412cd32f60cbc69a3e0741` |
| Investment | `1570e5c6adecdd2e9f6ef8e946587f561a42097fbe21d860c28eed97fa91d4a9` |

DB 使用已隔离验证的模板 `retirement_sql`，事务内再次检查目录指纹、旧连接、成员
关系与跨库依赖，撤销精确旧 grantee 的本域权限、将旧 backend 角色设为 NOLOGIN。
没有删除角色、业务行或终止连接。新角色又完成每 App 18 项真实登录/权限探针，
三个旧密码的 TCP 连接均被明确拒绝。

RabbitMQ 先以 UID/resourceVersion/原数据 CAS 更新共享启动 Secret，再定点 DELETE
每个旧用户的对应 vhost 权限；没有整包导入、删除用户/队列或重启共享设施。三个旧
AMQP 连接均得到 NotAllowed，新三角色各正登录/跨 vhost 拒绝仍通过。实际 definitions
前后比较证明仅移除这三条权限，其他用户、vhost、队列、交换机、绑定及策略保持不变。
相关旧用户和私有恢复材料全部保留。Investment HTTPS 也验证 TLS 成功、首页返回 307。

原 `database-activation/complete.json` 的 `old_logins_retired=false` 是激活时事实，
没有覆盖它；退役以追加的 `retirement-01/*-result.json`、`*-old-amqp-proof.json`、
`broker-final-proof.json` 为准。既有激活入口仍是一次性 bootstrap：退役后目录改变，
不能拿退役前目录回执盲目重跑，不能改旧证明绕过检查。后续版本发布需显式处理既有
身份和新发布回执，不应再创建同名角色或恢复旧权限。

撤权后重新读取三个 head、旧连接数（均 0）、新服务 readiness 与近 20 分钟日志：
九运行角色各 ready、日志均无 ERROR/CRITICAL/Traceback 标记；每个队列有一个消费者。
采样时 Info ready/unacked 均 0，另两 App 各有一个 unacked，尚需观察其完成，不能
把单次在途计数当失败或宣称队列永久为空。详见 `runtime-final-readonly.json`。
随后对三个新 Worker 分别定点 inspect：active/reserved/scheduled 均为空，三个队列
ready/unacked 均恢复为 0、消费者各 1，见 `worker-resample.json`；未取消或重放任务。
三 App 镜像内均确认 pyproject 声明 2.0.0、无 build-system、未安装项目 distribution
metadata，版本回退原因已定位。部署脚本最终回归仍为 95 passed / 176 subtests。
模板部署套件最终回归 31 passed / 27 subtests；文档全量门禁 76 份通过，89 份按
既有规则豁免，29 个 turn 编号/字段检查通过；豁免不冒充内容验收。测试按真实目录
收集，期间一次误写不存在的单测文件名导致未收集，纠正为整个模板 tests 目录后全过。

这完成的是本机 KIND 固定开发候选的部署及运行身份切换，不是 production 晋级，
也不是本次版本的完整业务 UAT。剩余包括真实登录浏览器旅程、跨 App Provider 回执、
完整故障/回滚前滚验收、独立 Calico 包级门禁、版本接口元数据修复；历史未知摄入仍
不得自动重放，Prometheus/Alertmanager 仍属 N4-OPS-01。
