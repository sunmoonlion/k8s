# Investment Architecture v2 R4 验收结果

结果：`PASSED`。本结果不是正式 `2.0.0` 发布，不包含真实数据迁移或流量切换。

## 已验收

- Research 三个活动仓在保留 Git 历史的前提下原地迁移为 Investment；旧 Web Backend 只读归档。
- Admin/Web 均为独立 Next.js 表面，共用一个 FastAPI `investment-backend`。
- 同一 Backend 摘要分别运行 API、Celery Worker、Celery Scheduler；数据库身份按角色隔离。
- 连续执行四段 Alembic migration，迁移 Job 完成后清理。
- Admin/Web 分别使用独立 Casdoor Client，通过严格 TLS 的真实登录、退出和撤销会话验证。
- 旧 Research Web 摘要通过 Kubernetes 原生 Deployment undo 回滚，再前滚至 Investment 候选。
- Calico 正向报文 200，未标记 Pod 到 Backend 的报文被拒绝。
- Backend、Admin、Web 模板同步稳态均为 `writes=0, deletes=0, prohibited-drift=0`。
- R4 临时 namespace、身份 Secret 和 Calico 集群在退出后均无残留。
- 旧 Research 运行拓扑的脱敏规范化 SHA-256 前后一致：
  `d54eec11d4af1e5d425b595e7f5b25ca1273dc7a75ee5a52b593ee670f18dbd9`。

## 门禁发现并修复的问题

Celery 在容器中继承节点 CPU 数，默认启动 12 个 prefork 子进程，导致 768Mi Worker OOMKilled。
修复进入模板提交 `7f2942c`：默认并发显式设为 2，Kubernetes 以水平扩容为主。随后完整门禁从零重跑通过。

## 锁定对象

- Backend：`investment-backend@sha256:abab9895b9323430fa357a01c4ad796ea3130b76853c7206306be54d3307834d`
- Admin：`investment-admin-frontend@sha256:15d8253d2125045f38ea8bd159df77642250214b3bd72e8733cedbd50464f41d`
- Web：`investment-web-frontend@sha256:d3ac86bdea887ed3be4ab2b61a8928bdf23086e20137c02e0ec2ca520ae51a0a`

GitHub 四个正式仓均已创建为私有仓，且本地、GitHub、Gitee 的 `architecture-v2` SHA 一致。
Gitee Backend 仍由旧仓名 `investment-admin-backend` 承载候选分支；由于当前无 Gitee 仓库管理 API
凭据，服务器端改名为 `investment-backend` 是唯一受控外部操作。该别名不影响源码、镜像、K8s
身份或 GitHub 正式仓名，且旧 `master` 未被改写。

## 下一门

R5 才执行真实 Research 数据迁移、对账、切读、切写和旧写入封锁。R7 观察窗结束前不得删除旧
Research 仓、数据库、Deployment、Secret、PVC 或镜像。
