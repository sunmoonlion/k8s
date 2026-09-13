# B6b：Knowledge 非阻塞解析源码验收记录

2026-09-13，单人 Luna 实施/自测，无独立多家评审。承接
[B6a 公共定时](v5-backlog-scheduling-luna.md)，归属[处置清单](v5-backlog-disposition-luna.md)。
当前是源码验证，不是实际部署或真实业务 RAGFlow 验收。

## 1. 旧任务的处置

M1-203 的“每次查询后释放 Worker”保留；旧 Celery countdown 换为已集成的公共持久
Outbox not_before，避免只在 broker/Worker 内保存下一次时间。M1-202 已有上传回执与
未知副作用阻断继续保留，超时或换代不能当成重传许可。

新消息携带 job id/generation/step，沿用 upload_identity 对应的同一个资源租约。
prepare 可提交前、后各观察一次；后续 poll 每条只 GET 一次文档状态，另查 provider 租户，
不 sleep、不重复取源文件、不上传或 POST parse。DONE 才落 indexed；FAIL/CANCEL 分类
失败；未完成持久安排后继。原循环 helper 保留兼容测试，但生产摄入服务不再调用。

## 2. 架构与事务决定

| 事项 | 决定及边界 |
| --- | --- |
| 执行状态主档 | 既有 job.metadata_json.ingestion_execution_v1，原请求留在 payload；无新表或迁移 |
| 可信来源 | 首条受理历史的服务端协议标记；客户端/Admin 禁写保留项；旧无标记任务调查后受控迁入 |
| 上传真源 | Provider 操作账的已确认意图/回执；任务仅保存核对引用，不以游标取代操作账 |
| 解析时间 | DB 时钟固定 deadline/interval，首次 POST 前持久化；退避上限 60 秒且不越过 deadline |
| 事务接续 | 游标推进 + 后继 Outbox + 当前 Inbox 同事务；领域成功或确定失败 + Inbox 同事务 |
| 必须保留的中间提交 | running、网络写入前的 executing、外部写入回执；当前 Inbox 此时未确认 |
| 进程/重放安全 | 旧 step/generation 无副作用确认；未来游标、错误资源键、无代次旧消息失败关闭 |
| 新旧 Worker 竞争 | 公共执行租约 + 领域 generation 的 before_commit/before_flush 检查；retry 行锁强制刷新 ORM 缓存 |
| 配置变化 | 复核准入/租户/上传回执/文档身份；已开始解析不得降级成 artifact-only；不承诺即时撤权广播 |

解析配置边界：timeout 1～86400 秒（默认 120），初始 interval 0.1～60 秒（默认 1），
拒绝 NaN/Infinity。重放/重启/设置变化不会重置既有时间；显式 retry 才有新代次。
已确认上传的 retry 仍复用同一文档，结果未知的 parse 在所有代次间继续阻止盲目重提。
首次上传尚无已验证游标时可能需要重读源文件以核实回执，这不是普通 poll。

源码边界仅 Knowledge 领域文件、配置、测试和说明；公共 B6a 文件没有修改，Info/模板/
Investment 源码及跨 App schema 没有修改。保留 metadata 的新增 403 语义测试了两面
实际 ASGI 响应，并由 Info 真客户端在独立子进程消费，不靠复制一份客户端冒充配对测试。

## 3. 证据

候选完整测试 **235 passed / 0 skipped**（20.62 秒），Ruff/Pyright 通过。
其中新增轮询/故障用例 45 项，两面保留 metadata 拒绝变体 2 项；原 188 项回归全部保留。
提交绑定的最终结果将在固定版本复跑后回填。

真实 PostgreSQL 隔离 schema 执行现有整条迁移链；Provider、HTTP、身份和故障为注入。
覆盖：

- 每条 poll 文档查询计数恰好 1，无 sleep/源文件读取/上传/再次提交解析，Worker 租约释放。
- deadline/backoff 持久、上限、配置变化、挂起 HTTP 的剩余时间限制；数字 0～5，DONE/
  FAIL/CANCEL，未知/瞬态读取错误及原有 parse POST 丢回执。
- 最终成功事务、后继消息事务的提交失败，RuntimeError/ValueError 入队失败均不误写 Inbox。
- 旧代次、旧游标、未来游标、错误资源键；用户 retry_count 与保留状态不具控制权。
- HTTP 挂起时并发新 retry 能完成，旧 Worker 的后续 ORM 写入被拒；缓存里的旧终态
  不能再发起一次相同重试或重置新代次。
- 任务取消、租约失效，以及实际启动 Worker 子进程、在 poll 中 kill，再由过期租约后
  的新 Worker 重放完成；原 deadline/上传回执不丢失。
- 丢 broker 提示后的公共死信/重放，准入撤销、租户/文档身份冲突、凭据移除后的阻断。

测试中的 make_due 仅提前可丢弃消息的传输定时，用于快速走完长轮询；原始 deadline
保持，真实 not_before 语义已由 B6a 的独立数据库用例验证。不能把故障注入称为真实
RAGFlow 负载、网络分区或跨机时钟验证。没有改业务数据、Secret 或部署。

## 4. 仍需 B7/后续计划接收

1. 实际任务与旧无 generation/step 消息盘点、旧 Provider 未知回执调查、受控迁入。
   不能从客户端 metadata 猜旧代次，也不能只添加协议标记就说迁入成功。
2. 先停止/排空旧运行角色，再一致切换 B5/B6 配置及代码；回滚前停止新生产者、排空/
   对账新协议消息。不得清空 Outbox、Inbox 或 Provider 操作账来回滚。
3. 真实 RAGFlow、broker、容量、网络/身份、部署恢复与运行态回滚门禁。
4. M1-203 的 SQL/HTTP 日志降噪：当前共享 PostgreSQL 在 development 下 echo，公共
   setup_logging 无 SQL/HTTP 专属策略。本包不改公共模板日志；该子项进入 B7 统一核验，
   本记录不将 M1-203 整体销账。
5. Admin 任意状态更新仍非正式取消/审批协议，本包没有用代次栅栏冒充产品权限工作流。

后端实现说明随源码位于 docs/ingestion-polling.md。固定提交、父仓锁定、两端同步和
测试容器清理回执在完成相应动作后追加。

## 5. 固定源码证据

knowledge-backend@2212e461ef7428fc4f4b321b6f3deb92ea4630af，
tree aae97b4d73950ba3f35ae1e93c84e64d2b880f1b；9 个精确文件。
固定提交复跑 **235 passed / 0 skipped**（21.78 秒），Ruff/Pyright 通过。
Info 固定源码 6a2be5768c524a985ddcde3bec5ae28e01ff0606 的分发/契约回归
另跑 **6 passed**（0.70 秒）；未改 Info 源码或契约真源。
部署及 B7 子项保持未验收；下一步仅集成/同步父仓，不执行应用部署。
