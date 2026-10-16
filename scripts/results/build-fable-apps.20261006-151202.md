# 待办 23：构建 fable 的 12 个镜像并暂存

- 工位：`~/worktrees/fable/k8s`
- HEAD：`26d2c25b`
- 时间：2026-10-06 14:15–14:21 +0800
- 结论：**不通过**。knowledge 的构建在选择阶段就退出 2。按待办，第三节起没有做，也没有做第六节的提交。没有 flux-release、没有晋级、没有部署。

## 一、核对源码

四个父仓和 `sources.yaml` 一致，子仓工作树没有未提交改动：

| 应用 | 父仓 | backend | web | admin |
| --- | --- | --- | --- | --- |
| tpl | `6579f30` | `834dff5` | `a398a63` | `3a0c88f` |
| info | `6729dd0` | `89d6598` | `58f01b6` | `27bc4c9` |
| knowledge | `116930f` | `f75996b` | `e61eff3` | `ee6b897` |
| investment | `8bb0a42` | `a49577a` | `c7c955d` | `469cadc` |

`make -C infrastructure application-verify-materials` 退出 **0**。PLAY RECAP：`ok=20 changed=0 failed=0 skipped=52`。

## 二、构建

| 应用 | 退出码 | 用时 |
| --- | --- | --- |
| tpl | 0 | 101 秒（14:15:30–14:17:11） |
| info | 0 | 121 秒（14:17:11–14:19:12） |
| knowledge | 2 | 1 秒（14:19:12–14:19:13） |
| investment | 0 | 106 秒（14:19:13–14:20:59） |

knowledge 没有进入镜像构建，`.build/applications/` 里没有这次的构建日志。失败原文：

```
TASK [Compute selection and dependency closure from the unique phase graph]
fatal: Disabled dependency: investment-service-identity
Origin: infrastructure/host/deployment.yaml:30
PLAY RECAP: ok=3 changed=0 failed=1
make: *** [Makefile:377: platform-selection] Error 2
```

`knowledge-backend/stage.yaml` 在 `knowledge_service_receiver` 打开时依赖 `investment-service-identity`。这个阶段当前是关的，选择把关着的依赖判失败。

三次退出 0 的构建没有改工作树。`git status` 是干净的。12 个 `image.lock.yaml` 的 digest 前 12 位和 `source_revision` 仍是原来的，对不上 `sources.yaml` 里的 fable 提交：

| 锁 | digest 前 12 位 | source_revision |
| --- | --- | --- |
| tpl-backend | `36c393be91ae` | `e907b65` |
| tpl-web-frontend | `7747a9fa70b4` | `0be8020` |
| tpl-admin-frontend | `830a9e382927` | `9cce66c` |
| info-backend | `2443d576ab1b` | `a4b6f59` |
| info-web-frontend | `9a7d97068a31` | `c7e19a4` |
| info-admin-frontend | `830a02d932de` | `38d5b05` |
| knowledge-backend | `e65abcf5f8d3` | `5732eab` |
| knowledge-web-frontend | `7527cb90817f` | `b1b4596` |
| knowledge-admin-frontend | `9828df053f96` | `0e1edbf` |
| investment-backend | `72c1ad421254` | `13539aa` |
| investment-web-frontend | `0f5f4b183b7b` | `745dfe6` |
| investment-admin-frontend | `afd78c56dcef` | `ac58e29` |

## 三至六

没有做。没有 tpl 暂存差异、没有三个应用的暂存、没有部署计划、没有把 `gitops/` 或 `infrastructure/applications` 提交进去。
