# 待办 32 回传：账 54/55/56 上现网

时间：2026-10-07 15:48。没有退回。没有贴口令。第七节页面没有点。

## 一、核对

头当时工作区干净。investment 是 `migration_job_revision: v4`、`expected_schema_revision: '20261007_0013'`。knowledge 的 `KNOWLEDGE_CATALOG_RATE_PER_MINUTE` 计数是 0。investment 管理端第 12 行有 `INFO_ADMIN_URL`。`platform-status` 退出 0，15 秒。

## 二、构建

| 对象 | 退出码 | 用时 |
| --- | --- | --- |
| knowledge-app（三个镜像） | 0 | 137 秒 |
| info-web-frontend | 0 | 38 秒 |
| investment-app（三个镜像） | 0 | 107 秒 |

七个锁的 `source_revision`：

| 锁 | source_revision |
| --- | --- |
| knowledge 后端 | `c2ba6ff020e89e3afaca2541976d1717d619d5fe` |
| knowledge 网页 | `71e5b2e3d5a46b097a9666149c473363253d0bd3` |
| knowledge 管理 | `df64aa5d6781c22404697eedab943792f3ddfc80` |
| info 网页 | `0ac00faf431adb6d7a31ad41f11168bbf144a65b` |
| investment 后端 | `05277e192ce6e3e95f01214da0623d43f1f07d8f` |
| investment 网页 | `624df4f1c0783e8131c7d3be6ece636b2b7d17d1` |
| investment 管理 | `b0f4c5de8450e6e17bb8d5ef846dcb76f4d01093` |

info 后端和管理端的锁没有变。

## 三、暂存与计划

knowledge 暂存退出 0，70 秒。info 退出 0，68 秒。investment 退出 0，67 秒。没有 PEM，没有 sops 变化。

- 迁移 Job 从 `investment-migrate-e9d7ddde9d7f-v3` 换成 `investment-migrate-ac5bdcd5ea53-v4`。后端镜像换成 `sha256:ac5bdcd5…`
- knowledge 删掉 `KNOWLEDGE_CATALOG_RATE_PER_MINUTE: "120"`，镜像换成 `sha256:71aad8b4…`
- investment 管理端镜像换成 `sha256:7d8e65f6…`，多了 `INFO_ADMIN_URL=https://info-admin.sunmoonai.com:30443`

三个计划都退出 0（3–4 秒），`failed=0`。schema：knowledge `20260927_0007`，info `20260929_0013`，investment `20261007_0013`。

## 四、提交

`97b5f352`，23 个文件。

## 五、发布、晋级、应用

`flux-release` 退出 0，27 秒。候选：

```yaml
digest: sha256:22d295de5e541b1eb7607dce3570c0788e53b6d05528d08975f0853750926c27
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 97b5f3527d21cc31b39983c2909b3e7e21191b79
```

diff 只有 digest 和 revision。提交 `d2a9db18`。`flux-source-apply` 退出 0，263 秒。`flux-source-status` 退出 0，4 秒。

## 六、检查

`investment-migrate-ac5bdcd5ea53-v4` 创建于 `2026-10-07T06:23:24Z`，Complete 1/1。没有非 Running/Completed 的应用 Pod。换了镜像的进程都是新 Pod、Running（约 14:24–14:26 启动）。info 的 api、admin、worker、scheduler 没重建，仍是旧 Pod。

| 检查 | 退出码 | 用时 |
| --- | --- | --- |
| knowledge application-check | 0 | 48 秒 |
| knowledge application-check-public | 0 | 37 秒 |
| info application-check | 0 | 26 秒 |
| info application-check-public | 0 | 25 秒 |
| investment application-check | 0 | 24 秒 |
| investment application-check-public | 0 | 29 秒 |
| platform-check OBJECT=all | 0 | 210 秒 |

investment-api 最近 10 分钟没有 traceback，也没有 alembic 报错。日志里的 `application_error` 是检查自己打出来的 401/403。

## 七、页面

没点。四行都判断不了：investment 网页端侧栏和结果边栏、investment 管理端「缺数据的需求」、knowledge 管理端「数据目录」、knowledge 与 info 网页端登录后的说明页。

## 结论

机器上的构建、暂存、发布、应用和检查通过。页面四项没看，整单判断不了。
