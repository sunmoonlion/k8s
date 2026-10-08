# 本机权限报告接口

提供方真源：[local-permission-v1.json](local-permission-v1.json)。消费者在 runtime/agent/contracts
和 investment-backend/app/contracts 锁定规范化 JSON 的 SHA-256；改字段必须同时更新并验证两端。
本轮为第 2 段候选，镜像发布及真实工作台联调见 switch-test/inbox，不能据此判断现网已支持。

## 调用顺序

1. relay 的 agent welcome 宣告 `local-permission-v1` 和 `pairing-notice-v1`。
2. 代理在本机完成确认，通过**控制通道**发送 `{type:"permission_report", report:{…}}`。
   report 字段：id、conn、threadId、requestDigest、permissionDigest、decision、scope、expiresAt。
   UUID/摘要均小写；摘要为排序键、无空白 JSON 的 SHA-256。不给云端命令、路径、环境或凭据。
3. relay 只核严格形状、当前代理、有效配对 conn、机器信息及期限；生成随机 receipt，
   放入有界内存队列。既有 `agents` 管理查询附带 `permission_reports:[{receipt,report}]`。
4. 工作台 MachineSync 核对 relay 身份对应用户、机器、thread 对应 Session，并锁该 Session；
   在既有账本以 `kind=record,type=agent/localPermission` 幂等写入，并在同一事务创建 outbox。
5. **事务提交之后**，工作台发送管理消息
   `{type:"permission_receipts", receipts:[{receipt,status:"recorded"|"rejected"}]}`。
   relay 只向仍持有该 receipt 的当前代理回 `{type:"permission_receipt",id,status}`。
6. 代理收到 recorded 且本机已同意、连接/会话/有效期仍匹配，才转发原请求。

`approved` 表示本机决定，不是执行成功；`recorded` 表示审计持久化，不是云端授予权限。
Windows 必须保留内层沙箱；`scope.sandbox=danger-full-access` 只允许 `decision=denied`。
没有本机同意、旧服务无能力声明、丢回执或 DB 回滚，都不能执行升级请求。
旧代理/沙箱无需新字段；Codex 数据通道仍逐消息透传，不塞自定义审批消息。

## 限额、恢复与排障

每代理最多 32 待回执，全 relay 最多 1024，排队 TTL 60 秒；报告有效期最多 2 小时。
当前代理授权只保留 30 分钟，回执等待最多 30 秒。这些是上限，不因网络迟缓延长。
队列满返回 rejected，非法字段/伪造 conn 关闭控制连接；关闭配对、替换代理或重启 relay 丢弃旧队列。
同 id 同报告幂等，改内容重放被拒。丢失 DB 提交后的回执可再次轮询，不能重复写审计。
队列不写 token 持久文件；机密和原命令不落入报告。

Codex 错配时仍拒绝沙箱配对，同时给代理非致命 notice `codex_version_mismatch`；
代理继续在线等待兼容端。token revoked / newer agent 仍沿用关闭码 4003 / 4000。

部署先更新工作台消费者，再更新 relay 提供方，最后启用新代理。旧消费者不会发回执，
升级请求会保守失败；不能把 relay welcome 当作工作台已完成部署的证据。
回退只需恢复本次维护前保存的固定镜像/Flux 源，无数据库迁移；已有审计记录保留。
