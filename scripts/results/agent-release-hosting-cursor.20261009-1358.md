# Cursor 回执：投资电脑代理安装包托管

时间：2026-10-09 13:58（UTC+8）。停在 A 之前。没有构建、没有改 `download_available`、没有上传、没有改 Flux 源或镜像锁。没有 push，没有移动本待办。

完成到：前提核对。A、B、C 都没有开始。不需要回退，因为没有发布动作。回退材料已只读保存，未使用。

## 已核对且符合的项

工作区干净。提交与本卡一致：

| 仓 | HEAD |
| --- | --- |
| k8s | `1e2bdcb63b508d8a3020441c5640030773d50db5`（基线 `723d637d47ec3b5690c26f59795c38e657e01cb8` 是其祖先） |
| investment-app | `231f305de2e0b72edb3d7cdd7c880151f8e3aaaf` |
| investment-backend | `a01db6f10f22d11116ba4421309ca676e2790f18` |
| investment-web-frontend | `2095c04927a1510efc54bef5ffd28e0c52d25558` |

`sources.yaml` 的 investment 锁与上表一致，admin 锁仍是 `b0f4c5de8450e6e17bb8d5ef846dcb76f4d01093`。固定 ZIP 大小 174243923，SHA256 `2d5421627198b9cf2eccf15d88b726c80d46f4180e2db30606120f5bd52aea5a`。集群名 `kind-sunmoon-kind`，三个节点 Ready。C 盘剩余约 115 GiB。SOPS age 主身份与数据盘副本都在。没有维护标记。

## 停止原因

71 个 Flux Kustomization 里有 23 个不是 Ready。投资 API 与 Worker 的 Deployment 都是 0/1 Available。

`investment-api-c9f7597db-ztqnz` 在 13:45 因 `Pod sandbox changed` 被重建，随后一直未就绪。最近事件是 Readiness probe HTTP 503。日志反复是 `readiness_failed type=TimeoutError`（就绪检查在超时内没有完成 Redis ping 或 Postgres schema 核对）。`investment-worker-6d7c9cbc8-22ntx` 同样重建，Deployment 仍不可用；进程日志里已有任务成功，但不能把它当成阶段 Ready。

postgresql-0、redis-0、rabbitmq-0 都是 Running，且都在约 11 分钟前重启过。OCIRepository `platform` Ready，摘要仍是当前源 `sha256:ed2e004657e99435027e32d37c0a824ef270384af99b0c97cd0b6be30e35cb3d`。

按本卡「状态不健康即停止」，没有执行 source plan 或构建。

## 回退点（未使用）

目录：`infrastructure/.build/agent-release-hosting-20261009-135823`（不入库）。

| 对象 | 当前值 |
| --- | --- |
| Flux revision | `f6e9aa0b09ee222699eb6bf6b55473a202030663` |
| Flux digest | `sha256:ed2e004657e99435027e32d37c0a824ef270384af99b0c97cd0b6be30e35cb3d` |
| investment-backend | `sha256:0c75cb542efbe02989f56e804c6a4452d601d2347fcdb0b510792dc0787b751d`，source `db96b401944b43fc2541704b165951eaac808e84` |
| investment-web-frontend | `sha256:f2e2e6a1d9b646b124751694fa5e6e89451527fa10c742b811ca016838f40581`，source `9c47e303de255a357703a26ec6d818f037c6e9af` |

运行中的 API imageID 仍是上述后端摘要。没有删除桶、对象或卷。

## 命令

本段没有调用构建、暂存、`flux-release`、上传或下载检查。退出码不适用。失败原文是 API 就绪日志 `readiness_failed type=TimeoutError`，以及 Deployment `investment-api` / `investment-worker` `0 of 1 updated replicas are available`。

exit=1
