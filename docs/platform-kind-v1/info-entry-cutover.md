# 信息应用域名接入新集群

状态：2026-10-03所有者明确批准后，两个域名已切换并通过正式30443验收。维护按所有者当前开发阶段2小时，容量底线10GiB；公共入口短断需要按此前约定单独确认。

候选只新增info.sunmoonai.com和info-admin.sunmoonai.com两个精确SNI→新集群127.0.0.1:29443，域名唯一读取两个前端config。Harbor仍→11443，Casdoor/tpl/tpl-admin维持新29443，其余域名维持旧172.18.0.5:30443。HAProxy不终止TLS、不保存私钥。

## 实施条件

- 原生application-bootstrap APP=info成功：schema20260913_0009、独立数据库/Redis/AMQP/Casdoor身份、API/worker/scheduler/Web/Admin。
- 真实TLS、API readiness、镜像身份、Worker消息、Scheduler tick、两surface PKCE/SSR、会话隔离/CSRF/退出通过；重复bootstrap零变更。
- tpl正式入口复验通过，现有Pod UID/重启计数不变。
- entry-preview用固定HAProxy镜像实际校验通过；只读挂载与容量检查通过。
- 运行haproxy.cfg、compose.yaml、systemd unit已完整备份并cmp/SHA256核对；记录当前入口active。

## 执行与验收

批准后从同一工作树运行原生entry-stop、entry-deploy。仅入口代理短断数秒至1分钟，不重启数据库、不删除节点/卷。两小时窗口内完成真实application-check-public APP=info，再复验APP=tpl和registry-publish-check；其余域名证书/默认路由核对，entry-deploy重复零变更。

失败先停止本轮入口，将本轮备份的三文件恢复原路径，systemctl daemon-reload，原生entry-start；核对Harbor健康与原路由。回退不需要启动旧控制面。公开验收前不能宣称切换通过，所有结果/日志保存在私有证据目录，不入Git。

## 验收边界

上述证明运行与身份/基础消息，不等于爬取、原文对象存储、搜索索引或knowledge分发通过。信息应用明确STORAGE_BACKEND=s3，尚未配置原文S3身份；不回退容器本地目录。搜索当前disabled，管理员业务scope未配置，未放宽权限以制造通过。后续原生平台依赖与业务验收继续完成。

## 本轮实际结果

源实现7dc4a4db2263eb40da4e7bb939b8373784e1cda3，晋级1005a677；入口候选b0159509f17ddb3dde376f31150eddc60391644b。当前Flux源sha256:090fd75634d8dbe8ae348d614803dd1304534ec75d33a591708464aa6be555b7。

14:11:12Z完成切换，14:11:55Z正式验收后关闭维护。备份/mnt/sunmoon-data/backups/entry/sunmoon-kind/info-cutover-20261003T140617Z，三份文件已逐字节+SHA256核对，before/window/result私有记录保留。

application-check-public APP=info和APP=tpl均ok37 changed0 failed0；registry-publish-check完成真实认证推拉及全镜像层/manifest/config核对，entry-deploy重复零变更。证据在infrastructure/.build/applications/runtime-unit-20261003/info-entry-*、info-public-check.log、tpl-after-info-cutover-public-check.log、info-cutover-registry-check.log。没有删除容器/卷、重启数据库或放宽权限。业务依赖仍按本卡边界继续完成。
