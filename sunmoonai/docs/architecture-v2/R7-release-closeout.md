# Architecture v2 R7 发布收口

状态：`IN_PROGRESS`

日期：2026-08-11

适用分支：`architecture-v2`

上游基线：Info R5、Knowledge R5、Investment R5、R6 真实跨 App 竖线均为 `DONE`

## 1. R7 的职责

R7 把 Architecture v2 从“已完成迁移并跑通真实竖线”提升为可追溯、可复验、可回滚的
`2.0.0` 正式发布。R7 不再新增业务能力，只闭合以下发布事实：

1. 模板 Backend、Admin、Web 三角色以当前源码重新通过完整隔离门禁；
2. Info、Knowledge、Investment 的正式声明式 bundle 重复 apply 后零漂移；
3. 三个 App 的 Admin/Web 都通过严格 TLS 与真实 Casdoor 登录、注销和撤销门禁；
4. R6 跨 App 真实竖线在最终 reconcile 后再次通过；
5. 所有正式镜像以同一不可变 digest 晋级 `2.0.0`，不重新构建、不覆盖历史 v1 标签；
6. 源码、镜像、bundle、迁移头和证据进入一份机器可读发布清单；
7. GitHub 与 Gitee 的 `architecture-v2` 分支和 `2.0.0` 标签完全一致。

## 2. 既定发布边界

- `2.0.0` 表示 Architecture v2 正式基线，不表示全部产品业务开发完成；
- v1 数据库、Secret、PVC、零副本 Deployment 和历史镜像继续作为受保护回滚资产；
- 旧 Research 公网 Ingress 已删除，旧工作负载保持零副本，不再承接流量；
- 不在 R7 删除回滚资产。不可逆退休必须经过独立观察期关闭决策；
- 旧 v5 任务、Handoff 和实施计划在 R7 完成前不得改写为 v6。

## 3. 施工与验收矩阵

| 步骤 | 状态 | 门禁 |
|---|---|---|
| R7-1 三个实例正式 bundle 重复 apply/零漂移 | DONE | formal apply + drift=false |
| R7-2 三 App Admin/Web 真实浏览器 | DONE | strict TLS、真实 Casdoor、client isolation |
| R7-3 跨 App 真实竖线复验 | DONE | 真实 S3、Outbox、RAGFlow、Investment citation、幂等重放 |
| R7-4 模板源码静态与组件测试 | DONE | Backend + 两前端全部门禁通过 |
| R7-5 模板隔离全门禁 | PENDING | KIND、真实 Casdoor、rollback/forward、Calico NetworkPolicy |
| R7-6 镜像精确晋级 | PARTIAL | 九个实例镜像已晋级；模板三镜像待 R7-5 |
| R7-7 发布清单与机器门禁 | IN_PROGRESS | `verify_r7_release_kind.py` |
| R7-8 源码标签及双远端一致性 | PENDING | GitHub/Gitee branch/tag SHA 一致 |

## 4. R7 机器门禁

最终命令：

```bash
cd /home/zymun/k8s
python sunmoonai/docs/architecture-v2/scripts/verify_r7_release_kind.py \
  --kubeconfig "$HOME/.kube/kind-config" \
  --namespace app-platform-dev \
  --output sunmoonai/docs/architecture-v2/evidence/R7-release/result.json
```

门禁必须同时验证：

- 15 个正式 Deployment 副本全部 Ready、镜像为 bundle 中精确 digest；
- 每个 Pod template 都有 64 位配置指纹；
- Info/Knowledge/Investment 数据库迁移头分别为 `20260811_0006`、`20260811_0005`、
  `20260811_0005`；
- Info 领域投递 Outbox 与通用传输 Outbox 都没有未完成记录；
- bundle 文件 hash 与 release.json 一致；
- 旧 Deployment 全部为零副本，旧 Research Ingress 和临时模板 Ingress 不存在；
- 没有 active Job、candidate/smoke/R3/R4 临时资源；
- 三份浏览器证据和最终跨 App 证据均为 passed，且没有 mock 或跨库读取。

## 5. 退出条件

只有 R7-1～R7-8 全部完成，才可把本文件状态改为 `DONE` 并宣布 Architecture v2 重构完成。
此后立即暂停；下一次工作从“把旧 v5 任务、Handoff 和实施计划重新设计为 v6”开始。
