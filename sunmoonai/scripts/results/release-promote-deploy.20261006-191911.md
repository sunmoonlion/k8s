# 待办 27 回传续八：直接应用已晋级的源，再检查

时间：2026-10-06 19:19。没有重跑整套 `platform-deploy`。没有退回。

## 一、核对

头是 `2a0f9993`，工作区干净。指针：

- digest `sha256:5ffeae565d55eba5f29d6846135655ed18c140a9a198fd950989c83945fdd973`
- revision `084a3085081080e44a3d1986183ae3287359dfab`

## 二、应用源

`flux-source-apply` 退出 0，190 秒（到 19:13:31）。`flux-source-status` 退出 0。

71 个 Kustomization 全是 True。`platform` Ready 是 True / ReconciliationSucceeded，`lastAppliedRevision` 是 `sha256:5ffeae56…`。

ops 里的新 Pod：

- `flower-7d7c858498-crzqd` 1/1 Running，命令是 `["celery","flower"]`
- `pgadmin-56fdc986c5-6m64m` 1/1 Running，挂了 `/var/log/pgadmin`
- `redisinsight` 仍是原来的 Running

没有非 Running/Completed 的 Pod。带摘要的 identity、redis、rabbitmq Job 都是 Complete `1/1`。

## 三、第六节

`platform-check OBJECT=all` 退出 2。失败任务 `Reject an unverified or redirected management client`（`infrastructure/services/verify.yaml:163`）。断言 `storage_client.stat.isreg` 不成立：`.tools/bin/mc` 不是一个普通文件。

| 检查 | 退出 |
| --- | --- |
| application-check tpl | 0 |
| application-check info | 0 |
| application-check knowledge | 2 |
| application-check investment | 0 |
| application-check-public tpl | 0 |
| application-check-public info | 0 |
| application-check-public knowledge | 2 |
| application-check-public investment | 0 |

info 这次过了。knowledge 的检查和 public 都停在 `Preserve private integration outcome for diagnosis`（`infrastructure/applications/verify.yaml:484`）。前面的 `Exercise existing Knowledge domain services and actual asynchronous worker` 是 ok。失败正文被 `no_log` 藏住了，任务自己打出来的是：目标目录 `/home/zymun/worktrees/fable/k8s/infrastructure/.build/models` 不存在。

`investment-runner` 1/1。`sandbox-provisioner` 和 `relay` 的 Deployment、Service 都在，Deployment 都是 1/1。

## 结论

控制台这一段通过：新源已应用，flower 和 pgAdmin 换成新 Pod 并且在跑，71 个阶段全 True。整份第六节不通过：`platform-check` 缺已校验的 `mc`，knowledge 的检查写诊断结果时目录不存在。
