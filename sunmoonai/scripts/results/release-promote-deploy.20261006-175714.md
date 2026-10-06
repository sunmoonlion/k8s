# 待办 27 回传续四：拉回集群后再部署

时间：2026-10-06 17:57。没有退回晋级指针。第六节后半没有做。

## 一、拉回集群

`platform-start` 退出 0，184 秒（到 17:40:58）。`platform-status` 退出 0，17 秒（到 17:41:15）。

3 个节点 Ready：`sunmoon-kind-control-plane`、`sunmoon-kind-worker`、`sunmoon-kind-worker2`。Kustomization 63 个，不是 True 的 0 个。没有非 Running/Completed 的 Pod。入口和 Harbor 容器仍在，Harbor 十个都是 healthy。

## 二、部署

`platform-deploy OBJECT=all` 退出 2，759 秒（17:42:33–17:55:12）。日志 `infrastructure/.build/platform-deploy-20261006-174233.log`。

入口这一段 `changed=0 failed=0`。Harbor、集群、Flux 控制器、SOPS 这几段也都是 `failed=0`。失败在发布/调和这一段：`ok=33 changed=2 failed=1`。任务 `Wait for root reconciliation`（`infrastructure/flux/source.yaml:259`）。`flux reconcile kustomization platform --timeout=600s` 从 17:45:12 等到 17:55:12，stderr 是 `context deadline exceeded`。

`flux-source-status` 退出 2（17:55:20）。根 Kustomization `platform` 的 Ready 是 Unknown / Progressing。`lastAppliedRevision` 仍是旧包 `sha256:e26d2a19932686a64a7226cbf64666c457d797450fdf92f462b184a1ca7a2aef`。`lastAttemptedRevision` 已是新包 `sha256:ba81d7d9eff670441811ad7ae06caf56533c54a43b7e66af33adf83408310e70`（revision `b5b9658e`）。

## 三、第六节前三条

Kustomization 71 个，不是 True 的 30 个。`head` 只打出前几条，完整名字如下。

健康检查失败，Pod 是 ImagePullBackOff，镜像在 `harbor.sunmoonai.com:30443/platform/` 里 not found：

- `flower`
- `pgadmin`
- `redisinsight`

已有 Job 拒绝改 `spec.template`（dry-run Invalid，field is immutable）：

- `info-redis-v2`、`investment-redis-v2`、`knowledge-redis-v2`、`tpl-redis-v3`
- `info-service-identity-v1`、`investment-service-identity-v1`

其余是依赖还没就绪：四个应用的 admin、runtime、web、identity、rabbitmq，以及 `knowledge` 没有单独的 service-identity 失败行。非 Running/Completed 的 Pod 就是上面三个 ImagePullBackOff。四条应用的旧 migration / redis / rabbitmq / identity Job 仍是 Complete `1/1`（年龄 46 小时到 2 天多），没有新的成功迁移。

后面的 `platform-check` 和八个 application-check 没有跑。

## 结论

不通过。集群已经拉回，入口这次 `changed=0` 过了。部署停在根 Kustomization 等了 10 分钟还没 Ready：三个控制台镜像拉不下来，四个应用的 Redis Job 和两个 service-identity Job 改不了已有模板。
