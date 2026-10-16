# 待办 31 回传：对象存储控制台放行回连自己

时间：2026-10-07 11:18。没有退回。没有贴口令。

## 一、核对与暂存

头是 `62f2043b`，工作区干净。`platform-stage OBJECT=data-platform/object-storage/ui` 退出 0，29 秒。只改了 `ui/workload.yaml`，多了 `object-storage-console-self`：这个 Pod 进出自己的 9000。提交 `86f77602`。

## 二、发布、晋级、应用

`flux-release` 退出 0，26 秒。候选：

```yaml
digest: sha256:992d41dffe7140ac043ed62461bef4fd8cddf5a81bdc86849a19dc22d24f027b
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 86f77602026fb47a458c775be22c4b50f23e3027
```

diff 只有 digest 和 revision。提交 `67745949`，消息 `release(kind): 晋级到 86f77602（待办 31）`。`flux-source-apply` 退出 0，164 秒。`flux-source-status` 退出 0，2 秒。`object-storage-0` 仍是昨天 `2026-10-06T09:45:41Z` 启动的那个 Pod，没有重启。策略 `object-storage-console-self` 已在集群里。

## 三、检查

错误口令登录 `https://aistor.sunmoonai.com:30443/api/v1/login` 返回 `401`。

`platform-check OBJECT=all` 退出 2，73 秒。对象存储控制台那一项过了（`bad_password_denied: true`，`console_login: true`，`passed: true`）。停在后面：

- 任务：`Require sandbox provisioner acceptance`（`infrastructure/services/verify.yaml:403`）
- 断言：`sandbox_provisioner_acceptance.rc == 0`
- fail_msg：`{"passed": false, "reason": "sh: 1: curl: not found\ncommand terminated with exit code 127"}`
- 它前面最后一个通过的 `Report only …`：`Report only the credential-free relay result`（`healthz: true`，`passed: true`）。Mongo Express 那几项是跳过，不是通过。

## 结论

控制台回连放行已经生效，错误口令被拒绝。整套 `platform-check` 不通过，停在沙箱供给器健康检查：容器里没有 `curl`。
