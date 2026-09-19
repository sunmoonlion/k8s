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
