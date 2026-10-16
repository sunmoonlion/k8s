# 待办 34 回传：investment 后端 Windows 目录不放顶层 cwd

时间：2026-10-08 17:05。没有退回。没有贴口令。

待办 33 已在 `42651574` 交过，这次没有重跑。

## 一、核对、构建、暂存、提交

头：`f14dbc1e`，工作区干净。investment-backend 检出 `7ac05d2ab2188b866336e92875fe25d170bf5ded`，与 `sources.yaml` 钉的 `backend_revision` 相同。

| 步 | 退出码 | 用时 |
| --- | --- | --- |
| `platform-status` | 0 | 16 秒 |
| `platform-build OBJECT=app-platform/investment-app/investment-backend` | 0 | 36 秒 |
| `platform-stage OBJECT=app-platform/investment-app` | 0 | 72 秒 |

锁两行（等于清单钉的提交）：

```yaml
digest: sha256:99a94820e35c22164aee97a2eb95ef6e3d7fccfbfa1f41705375bc1d9caf503b
source_revision: 7ac05d2ab2188b866336e92875fe25d170bf5ded
```

旧摘要 `sha256:ac5bdcd5…`，旧源 `05277e19…`。变的只有 investment 后端的锁和六个 workload（镜像摘要、Job 名里的摘要、`DEPLOYMENT_ID`）。迁移 Job 从 `investment-migrate-ac5bdcd5ea53-v4` 换成 `investment-migrate-99a94820e35c-v4`，revision 仍是 v4。没有 sops 文件。

提交 `ee0b19a9`。

## 二、发布、晋级、应用

`flux-release` 退出 0，33 秒。候选整份：

```yaml
digest: sha256:4615fc1ab69c89b9b609bd15ad59f57600f7ff5aaaebc86ad376d7daf6ad4608
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: ee0b19a94c41f22f5860f82f40cc8813fb605e0c
```

`revision` 等于部署提交 `ee0b19a9`。晋级 diff 只有 `digest` 和 `revision`。提交 `747de940`。

`flux-source-apply` 退出 0，224 秒。`flux-source-status` 退出 0，4 秒。

## 三、检查

`application-check APP=investment` 退出 0，26 秒。`PLAY RECAP` `failed=0`。诊断任务由 API 发出、worker 消费并完成同一任务身份。入口 29443 的协议检查（登录回调、跨端拒绝、CSRF、登出吊销、安全 cookie、管理端未授权诊断拒绝）均为通过。

`application-check-public APP=investment` 退出 0，25 秒。`PLAY RECAP` `failed=0`。同一条诊断任务完成。入口 30443 的协议检查同样通过。

## 结论

通过。后端锁的 `source_revision` 是 `7ac05d2a`，两项检查退出 0。

exit=0
