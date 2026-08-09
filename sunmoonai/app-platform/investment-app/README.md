# Investment Architecture v2 部署入口

本目录只保留 Architecture v2 的生成入口和锁定发布输入。旧 Investment v1 的 Admin/Web
双 Backend、NodeBull/Celery 独立清单已删除，禁止从历史 YAML 恢复或机械改名。

唯一部署模型：

```text
investment-admin-frontend (Next.js) ─┐
                                     ├─ investment-backend (FastAPI)
investment-web-frontend   (Next.js) ─┘       ├─ API
                                             ├─ Celery Worker
                                             └─ Celery Scheduler
```

Kubernetes 清单必须由 `/home/zymun/tpl-app/k8s-scaffold-v2` 生成；镜像只能使用
`repository@sha256:digest`。R4 候选的锁定输入见 `release-inputs.json`，完整隔离门禁入口为：

```bash
bash /home/zymun/k8s/sunmoonai/docs/architecture-v2/scripts/run_r4_investment_gate.sh
```

该门禁创建独立 namespace、数据库、Redis 和 Casdoor Client，验收后自动清理。现有
`app-platform-dev` 中的 Research 资源是 R5/R7 前的只读回滚基线，不属于本目录的部署目标，
禁止由本入口修改或删除。

R4 不是正式发布，禁止将候选摘要标记为 `2.0.0`。真实数据迁移和切流属于 R5。
