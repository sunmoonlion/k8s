# 四对象恢复已执行；部署前身份验证进行中

本文件是本轮尚未交回时的续接检查点，不代表部署完成。

## 已执行的唯一业务写入

本机 kind-kind，UID `5d71ab3a-ea5a-4535-adc6-d7698d820249`，Info 自有桶
`development-info-originals`，仅上一轮批准目录的四个缺失文件。
2026-09-19 先只读核引用和内容，再 `IfNoneMatch=*` PUT、GET 精确返回版本复核；
四项全部通过，未改数据库行、未覆盖同名对象、未重放任务。

执行载荷 SHA-256：`d1462be76bf88fff9535995d858ff0a2a8f35381d0f13f0c7737c1f08d7b38fb`。

| 文件 | 新增 S3 版本 |
| --- | --- |
| raw.html | 3c1b8df4-64af-465a-aa7e-c1fdb24d3ba3 |
| clean.md | d9c803b4-444c-442b-9b52-55b147204467 |
| text.txt | c666395f-3e30-4299-920a-15bf80ac443d |
| headers.json | b5f686fd-7bf7-4ff4-93ab-6edfe4f977dd |

原内容摘要和大小见 [授权对象](../../0012-none/others/preparation.md)。
私有执行回执：`.local/kind-cutover-20260919/info-recovery-apply-01/{execution.json,stdout.json}`，
路径根为 `/home/zymun/worktrees/luna`。仅本轮创建这些对象版本，没有删除操作。
若任何后续核查失败，保留对象及回执，不擅自删除已恢复文件。

## 完整对象备份与隔离恢复

`info-objects-03/objects.private.tar`：189 引用全部通过，56 个去重内容块，
SHA-256 `a34ea6117e5e290ab69f89078dcedb469ee8edad92f390ebce7c15130ba6d22a`。
`info-object-restore-02`：在网络 none 的一次性 MinIO 中实际恢复 119 个对象版本，
逐版本读回核对内容/metadata，未版本化引用按其备份时 latest 最后恢复并校验。
临时容器及自有匿名卷已清理；业务 MinIO 未受此演练写入。

第一次恢复因镜像 appuser UID 无法读宿主 0600 备份失败；已确认 PermissionError，
改用宿主 UID/GID 的非 root 客户端，仍保留 0600，第二次成功。
S3 会生成新版本 ID，新旧映射保存在 `restore.private.json`。**数据库引用重映射未测试**，
不把这次 S3 恢复说成完整灾难迁移；现有业务 S3 及版本仍保留，部署回滚不删除对象。
这些仍是在线准备材料，不是停机切换回执。

## 数据库身份演练（不是业务切换）

公共事务编译器先放 `tpl-app/k8s-deployment/runtime_database_cutover.py`，
新身份准备与旧身份撤销分开；不提前 NOLOGIN，不自动终止任意连接。
既有表/列 grant 仍来自模板与各领域已验 overlay；调用者仍负责真实所有权、继承、
PUBLIC/列 ACL、默认 ACL 盘点、旧消费者排空与备份绑定，编译器不是在线供给器。

`isolated_database_identity_rehearsal.py` 只读上一轮备份，在无网络临时 PG 中两次恢复/迁移、
创建三新账号、真实连接验证允许/42501 拒绝、测试未来表 default ACL、再撤旧账号，
最后重核全部原业务列/行。没有 kubectl 或在线数据库写入口。

| App | 最终脚本演练目录 | 每次探针数 | 两次结果 |
| --- | --- | --- | --- |
| Info | info-identity-rehearsal-02 | 29 | passed |
| Knowledge | knowledge-identity-rehearsal-01 | 27 | passed |
| Investment | investment-identity-rehearsal-01 | 27 | passed |

Info 最初 `info-identity-rehearsal-01` 也通过；之后增加最终数据对账、API 投递内容更新拒绝、
代码摘要留存，所以重跑 02，不以旧记录代替最终脚本验证。每目录有 `sources.json`、
`identity-rehearsal.json`，私有日志和备份均不进 Git。
Info 旧库 `uuid_generate_v4()` 默认值依赖 uuid-ossp 旧 owner：撤 PUBLIC 函数访问后
显式授 API/Worker/Migration 这一函数，不给 Scheduler。没有迁移旧函数所有权。
未覆盖业务环境 broker 或跨数据库连接边界，不称安全验收完成。

## Broker 与余下工作

模板新增 `runtime_broker_cutover.py`：精确合并三新用户/拓扑，保留非目标条目；
只撤指定旧用户在目标 vhost 的 permission，不删用户/队列。单元测试已通过。
真实一次性 broker 测试第一轮：新 hash 认证、生产者不能消费、Worker 消费、
精确撤权均走过；最终枚举默认 vhost `/` 的 URL 未编码导致 404。修正编码后完整重跑，
`test_runtime_broker_cutover.py` 为 1 passed（15.80 秒），未删减任何权限核对项。
重要实测：definitions import 是增量合并，省掉旧 permission 不会撤销在线权限，
切换器须同时精确 DELETE permission 并核旧连接排空。

新发现的发布入口风险：`deploy-rabbitmq.sh` 的旧 development values 使用 extraSecrets
生成整份共享 definitions，后续 Helm upgrade 可能覆盖新身份；旧 Investment broker
helper 同样整包覆盖并有删除逻辑。尚未执行或修改这些入口；必须先补受控保护/接入。

尚未停业务副本、未创建业务新账号/Secret、未撤旧业务权限、未执行业务迁移/新部署。
尚需：业务 broker 现场精确核对与在线窄供给入口、Investment 开发 apply 消除旧身份副作用、
最终 source lock/bundle/conf 与身份/备份门禁、同步所有仓和工位、停机新备份、
Info→Knowledge→Investment 串行部署及真实运行验收。不要把准备脚本测试当作部署通过。

## 本轮最终机械门禁

`tpl-app` 根：`python3 -B -m unittest discover -s k8s-deployment/tests -q`，25 tests，退出 0。
`k8s` 根：`python3 -B -m unittest discover -s sunmoonai/app-platform/scripts/tests -q`，64 tests，退出 0。
另外实际隔离数据库身份演练六轮、对象恢复一轮成功、真实 broker 合并/权限测试一例成功。
所有合成权限测试均不代表业务账号已切换。私有备份不随 Git 同步。

模板准备代码已提交 `tpl-app/luna@9f6d003d57031943a17d153e1d4c65aa7edb5f68`；
没有新 Backend 子仓提交，因此已有候选镜像不需要因此重建。模板与本轮 k8s 准备代码
暂只在 luna，尚未合入 master、推送或 -all 同步，最终部署之前仍需完成既定同步步骤。
交回前重新核三 App API 2/Worker 1/Scheduler 1、前端各 2 全部 ready；未切新镜像。
