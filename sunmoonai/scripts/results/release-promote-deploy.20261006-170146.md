# 待办 27 回传：release-promote-deploy

时间：2026-10-06 17:01。开始时 HEAD `b5b9658e`。工作区干净，stash 为空。现网指针当时是 `revision: e59bdc006a2eaca8c7b3af367ad7e801a6136547`，`digest: sha256:e26d2a19932686a64a7226cbf64666c457d797450fdf92f462b184a1ca7a2aef`。部署失败后停下，没有退回。

## 一、核对

- `platform-status` 退出 0，17 秒。
- `platform-plan OBJECT=all` 退出 0，1 秒。
- `platform-check OBJECT=all` 退出 2，38 秒。失败项都是 NotFound：`neo4j-ui`、`object-storage-ui`、`rabbitmq-ui`、`flower`、`pgadmin`、`redisinsight`、`relay`、`sandbox-provisioner`。
- Kustomization 63 个，非 True 为 0。没有非 Running/Completed 的 Pod。

## 二、备份

`TS=20261006-165838`。指针副本 `infrastructure/.build/flux/flux-source.before-20261006-165838.yaml`，复制退出 0。Postgres 在 `data-platform-dev`。`pg_dumpall` 管道退出 0，1 秒。文件 `/mnt/sunmoon-data/backups/postgresql/sunmoon-kind/pre-step5-20261006-165838.sql.gz`，840K，`CREATE DATABASE` 6 条。内容不贴。

## 三、发布

`flux-release` 退出 0，26 秒（16:58:56–16:59:22）。候选：

```yaml
digest: sha256:ba81d7d9eff670441811ad7ae06caf56533c54a43b7e66af33adf83408310e70
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: b5b9658eb717909e8b419eb593a834b92c6d7d45
```

`git rev-parse HEAD` 当时也是 `b5b9658eb717909e8b419eb593a834b92c6d7d45`。

## 四、晋级

diff 只有两行：

- digest `sha256:e26d2a19…` → `sha256:ba81d7d9…`
- revision `e59bdc00…` → `b5b9658e…`

`repository`、`path`、`requires_sops` 没变。提交 `e76da7ff release(kind): 晋级到 b5b9658e（0010 第 5 步：fable 的应用第一次上新体系）`。提交后工作区干净。

## 五、部署

`platform-deploy OBJECT=all` 退出 2，39 秒（16:59:56–17:00:35）。日志 `infrastructure/.build/platform-deploy-20261006-165956.log`。失败任务：`Require verified tools before configuring services`（`registry/service.yaml:87`）。`infrastructure/.tools/bin/docker-compose` 不存在（`stat.exists: false`），同目录的 `docker` 也不在。PLAY RECAP：`ok=17 changed=0 failed=1`。前面几段 RECAP 是 `failed=0`。源还没应用。

`flux-source-status` 退出 2。现网 `OCIRepository/platform` 的 spec 仍是 `sha256:e26d2a19…`，Ready。`source-apply` 被跳过。

## 六、停下前的三条

- Kustomization 仍是 63，非 True 为 0。
- 非 Running/Completed 的 Pod 为 0。
- 四个应用能列到的 Job 都是 Complete `1/1`：identity、database、redis、rabbitmq。这条命令没有列出 migration Job。

`platform-check` 和八个 application-check 没有做。

## 结论

不通过。发布和晋级提交已经完成，现网没有切到新包。部署停在 Harbor 工具校验：本工位 `.tools/bin/docker-compose` 缺失。没有退回。
