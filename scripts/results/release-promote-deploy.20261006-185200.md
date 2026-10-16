# 待办 27 回传续六：下载并发布三个控制台镜像，再发布晋级部署

时间：2026-10-06 18:52。没有退回晋级指针。根调和超时后没有重跑部署。

## 一、核对

工作区干净。头里有 `deb9a22c`（平台镜像先发布到 Harbor，再让 Flux 应用源）。四应用重新暂存那笔在变基后是 `eb92a541`，和 `f8673ff5` 是同一份 Job 名改动，父提交换成了 `deb9a22c`。当时头：

- `68aeb0fd` test(local): 2026-10-06-27-release-promote-deploy.md 结果
- `eb92a541` deploy(apps): 身份 Job 名带后端镜像摘要（第 27 轮续五）
- `deb9a22c` fix(deploy): 平台镜像先发布到 Harbor，再让 Flux 应用源（账 47）

## 二、三个控制台镜像

`services-materials` 退出 0，292 秒。`services-verify-materials` 退出 0，5 秒。`services-publish` 退出 0，21 秒，`changed=3 failed=0`。三个镜像都推到了 `platform/`。

## 三、发布与晋级

`flux-release` 退出 0，29 秒。候选整份：

```yaml
digest: sha256:60450a676624385df4dabe34a022ab31021d3a04996051f21ca4169cacfc9f9d
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 68aeb0fdb2b7f705b233bab41649c2e209ff4e81
```

`revision` 等于当时的 HEAD。diff 只有 `digest` 和 `revision`。提交 `5c09389f`，消息 `release(kind): 晋级到 68aeb0fd（0010 第 5 步，第二次）`。

## 四、部署

`platform-deploy OBJECT=all` 退出 2，844 秒（18:28:28–18:42:32）。日志 `infrastructure/.build/platform-deploy-20261006-182828.log`。失败任务仍是 `Wait for root reconciliation`：`flux reconcile kustomization platform --timeout=600s` 从 18:32:31 等到 18:42:31，`context deadline exceeded`。`flux-source-status` 退出 2。

没有重跑部署。18:45 再看：71 个阶段里 3 个不是 True，这是明确报错，没有再隔 5 分钟空等。

- `flower`：HealthCheckFailed。Pod CrashLoopBackOff，上次退出 128，`exec: "--port=5555": executable file not found in $PATH`。
- `pgadmin`：HealthCheckFailed。Pod CrashLoopBackOff，退出 3，`OSError: [Errno 30] Read-only file system: '/var/log/pgadmin'`。
- `platform`：Ready 仍是 Unknown / Progressing。`lastAppliedRevision` 还是旧包 `sha256:e26d2a19…`。`lastAttemptedRevision` 已是新包 `sha256:60450a67…`（`68aeb0fd`）。历史里这一包 HealthCheckFailed，耗时 10 分钟。
- `redisinsight` 是 Running，阶段已是 True。

四个应用带摘要的新 Job 都是 Complete `1/1`（约 12–13 分钟前）：tpl/info/knowledge/investment 的 identity、redis、rabbitmq。没有名字里带 `migration` 的 Job。旧的 database / identity / redis / rabbitmq Job 仍是 Complete。

## 五、第六节

`platform-check OBJECT=all` 退出 2，因为根阶段还没 Ready。

| 检查 | 退出 |
| --- | --- |
| application-check tpl | 0 |
| application-check info | 2 |
| application-check knowledge | 2 |
| application-check investment | 0 |
| application-check-public tpl | 0 |
| application-check-public info | 2 |
| application-check-public knowledge | 2 |
| application-check-public investment | 0 |

info 的失败是 `s3_runtime_check.rc == 0` 不成立，桶 `info-originals` 上列出的检查项都是 true，最后 `passed: false`，`error: FileNotFoundError`。knowledge 的失败输出被 `no_log` 藏起来了，没有看到明文。

`investment-runner` 1/1，年龄约 15 分钟。`sandbox-provisioner` 和 `relay` 的 Deployment、Service 都在，Deployment 都是 1/1。非 Running/Completed 的 Pod 就是 flower 和 pgadmin。

## 结论

不通过。三个镜像已经下载并发布，声明包已晋级到 `68aeb0fd` / `sha256:60450a67…`，带摘要的身份 Job 已跑完。根阶段等了 10 分钟仍未 Ready：flower 把 `--port=5555` 当成了可执行文件，pgadmin 写不了 `/var/log/pgadmin`。
