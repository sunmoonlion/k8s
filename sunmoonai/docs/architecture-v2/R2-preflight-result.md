# Architecture v2 R2 Preflight 结果

日期：2026-08-01

结果：`PASSED`

适用分支：`architecture-v2`

## 1. 旧拓扑 Redis 健康恢复

R1 盘点时，Info/Knowledge API 因 Redis ACL 认证失败处于 `CrashLoopBackOff`。根因不是
Architecture v2 代码，而是旧拓扑存在两个凭据事实源：应用 Secret 已轮换，Redis Pod 重建时却
从静态 Helm values 恢复了旧 ACL，导致 Secret 与 Redis 用户口令漂移。Celery Worker 使用独立
broker URL，因此 Worker 健康没有暴露 API session Redis 的失败。

执行脚本：

```text
architecture-v2/scripts/reconcile_pre_v2_redis_acls.sh
```

脚本以当前应用 Secret 为恢复依据，通过临时 Kubernetes Secret 和一次性 Job 对账 ACL，不解码、
不打印凭据。Info 与 Knowledge 均完成：

- 当前凭据 `PING`；
- 允许 key 的 `SET/GET/DEL`；
- 越权 key 写入必须被拒绝；
- `ACL SAVE`；
- 临时 Job 与 Secret 删除；
- API 滚动重启。

实测结果：

```text
redis_acl_reconciled app=info positive=passed negative=passed
redis_acl_reconciled app=knowledge positive=passed negative=passed
info-admin-backend                     ready=1/1 unavailable=0
knowledge-admin-backend                ready=1/1 unavailable=0
celeryworker-info-admin-backend        ready=1/1 unavailable=0
celeryworker-knowledge-admin-backend   ready=1/1 unavailable=0
architecture_v2_r2_redis_preflight=passed
```

两个 API 启动日志均确认 Redis 初始化成功。旧候选镜像未配置 Kubernetes startup/liveness/readiness
probe，且没有可用的 HTTP health endpoint；因此本次没有伪造 HTTP readiness 结论。R2 规范模板
必须实现 `/health/live`、`/health/ready` 和兼容 alias，R3 部署必须配置三类探针。

静态 Helm ACL 与应用 Secret 的双真相源仍是待移除的旧基础设施债务。进入任何 R2/R3 KIND 验证
前先运行上述对账门禁；R3 平台清单必须改为 Secret 驱动的唯一事实源，未完成前不得发布 `2.0.0`。

## 2. 模板 Backend 能力封存

权威清单：`tpl-backend-capability-manifest.json`。

验证器：`architecture-v2/scripts/verify_tpl_backend_capability_manifest.py`。

校验结果：

```json
{
  "task": "architecture-v2-tpl-backend-capability-manifest",
  "result": "passed",
  "capabilities": 9,
  "admin_only": 1,
  "web_only": 9,
  "common_different": 22,
  "credentials_printed": false
}
```

清单把每个仅存在于 Admin、仅存在于 Web、以及同路径但实现不同的受版本控制文件映射到保留、
迁入、拆分、合并或废弃决策，并定义目标路径和验收条件。验证器还校验两个源 commit 是当前历史
祖先，防止后续新增能力未进入矩阵。

## 3. Gate 决策

允许进入模板仓库事务：

```text
tpl-admin-backend -> tpl-backend
```

仍禁止：

- 修改 Info/Knowledge/Research 实例 Backend；
- 删除或归档 `tpl-web-backend`；
- 合并两条 Alembic root；
- 在健康端点、双 auth surface 和能力清单测试完成前构建候选发布镜像。
